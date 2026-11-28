using Conex360.Application.Inventory;
using Conex360.Domain.Catalog;
using Conex360.Domain.Identity;
using Conex360.Domain.Inventory;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed partial class InventoryStore
{
    private static ReceiptInput AdjustmentInput(Warehouse warehouse, string currency, DateOnly date,
        Guid operation, IReadOnlyList<ReceiptLine> lines) =>
        Normalize(new ReceiptInput(operation, warehouse.Id, warehouse.Version, currency, date, null, null, null, lines));

    public Task<PostedReceipt> ChangeAsync(SessionData session, bool waste, StockChangeInput input, string correlation, CancellationToken ct) =>
        Operate(session, true, async s =>
        {
            var reason = Reason(input.Reason);
            input = input with { Reason = reason, Notes = Clean(input.Notes, 700) };
            var warehouse = await Ordinary(s, input.WarehouseId);
            var command = waste ? "WASTE" : "ADJUST";
            var hash = OperationHash(0, input);
            var replay = await OperationReplay(s, command, input.OperationId, hash);
            if (replay is not null) return replay;
            if (warehouse.Version != input.WarehouseVersion) throw Conflict("The warehouse configuration changed.");
            var business = await Business(s);
            if (business.Currency != input.ExpectedCurrency) throw Conflict("The business currency changed.");
            await RequireUnfrozen(s, warehouse.Id);

            PostedReceipt doc;
            if (input.Incoming is { } incoming && !waste && input.BucketId is null && input.Quantity is null)
            {
                var receipt = AdjustmentInput(warehouse, input.ExpectedCurrency, business.Today, input.OperationId, [incoming]);
                var prepared = await Prepare(s, warehouse, false, receipt, adjustment: true);
                doc = await Document(s, warehouse, command, input.Notes, prepared.Total);
                await Append(s, doc.Id, warehouse.Id, 1, prepared.Lines[0]);
                await LockInventoryCurrency(s);
            }
            else
            {
                if (input.Incoming is not null || input.BucketId is not { } bucketId || input.ItemUnitId is not { } unitId ||
                    input.Quantity is not { } entered || input.ItemVersion is null || input.UnitVersion is null)
                    throw Invalid("Choose the stock bucket, configured unit and positive quantity to remove.");
                var bucket = await GetBucket(s, bucketId);
                if (bucket.Warehouse != warehouse.Id) throw Missing();
                var unit = await SelectUnit(s, bucket.Item, unitId, input.ItemVersion, input.UnitVersion);
                var quantity = ConvertQuantity(unit, entered);
                await RequireUnreserved(s, bucket, quantity);
                var value = Carry(quantity, bucket.Quantity, bucket.Value);
                doc = await Document(s, warehouse, command, input.Notes, value);
                await MoveLine(s, doc.Id, warehouse.Id, 1, bucket.Id, unit, bucket.Lot, bucket.Condition, quantity, value, true, entered);
            }
            await CompleteOperation(s, doc, command, input.OperationId, hash, reason, correlation);
            return doc;
        }, ct);

    private static Task<int> LockInventoryCurrency(Scope s) => s.Execute("""
        UPDATE companies SET currency_locked_at=@now,updated_at=@now,row_version=row_version+1
        WHERE tenant_id=@tenant AND id=@company AND currency_locked_at IS NULL
        """, ("now", s.Now));

    private static async Task RequireUnreserved(Scope s, Bucket bucket, decimal remove)
    {
        if (bucket.Quantity >= remove && bucket.Quantity - remove >= await Reserved(s, bucket.Id)) return;
        var numbers = await s.List("""
            SELECT DISTINCT d.document_number FROM stock_reservations r JOIN documents d
              ON d.tenant_id=r.tenant_id AND d.company_id=r.company_id AND d.id=r.request_id
            WHERE r.tenant_id=@tenant AND r.company_id=@company AND r.bucket_id=@bucket
              AND r.reserved_quantity>r.consumed_quantity+r.released_quantity ORDER BY d.document_number LIMIT 20
            """, r => r.GetString(0), ("bucket", bucket.Id));
        throw Conflict(numbers.Count == 0 ? "The decrease exceeds physical stock." :
            "The decrease would breach reservations: " + string.Join(", ", numbers) + ". Resolve them before proceeding.");
    }

    private const string CountSelect = """
        SELECT c.count_id,c.warehouse_id,d.document_number,d.warehouse_name,c.status,c.row_version
        FROM stock_counts c JOIN documents d ON d.tenant_id=c.tenant_id AND d.company_id=c.company_id AND d.id=c.count_id
        JOIN warehouses w ON w.tenant_id=c.tenant_id AND w.company_id=c.company_id AND w.id=c.warehouse_id
        WHERE
        """;
    private static CountSummary ReadCount(MySqlDataReader r) =>
        new(r.GetUInt64(0), r.GetUInt64(1), r.GetString(2), r.GetString(3), r.GetString(4), r.GetUInt64(5));
    private static async Task<CountSummary> FindCount(Scope s, ulong id) =>
        await s.One(CountSelect + WarehouseAccess + " AND c.count_id=@id", ReadCount, ("id", id)) ?? throw Missing();

    public Task<IReadOnlyList<CountSummary>> CountsAsync(SessionData session, ulong? before, CancellationToken ct) =>
        Operate(session, false, s => s.List(CountSelect + WarehouseAccess +
            " AND (@before IS NULL OR c.count_id<@before) ORDER BY c.count_id DESC LIMIT 50", ReadCount, ("before", before)), ct);

    private sealed record CountLine(ulong Bucket, ulong Item, string Sku, string Lot, string Unit, string Condition,
        decimal Expected, decimal ExpectedValue, decimal? Actual, decimal? Cost);
    private static Task<IReadOnlyList<CountLine>> CountLines(Scope s, ulong id) =>
        s.List("""
            SELECT cl.bucket_id,cl.item_id,i.sku,l.lot_code,u.code,cl.stock_condition,
              cl.expected_quantity,cl.expected_value,cl.actual_quantity,cl.positive_unit_cost
            FROM stock_count_lines cl JOIN items i ON i.tenant_id=cl.tenant_id AND i.company_id=cl.company_id AND i.id=cl.item_id
            JOIN units u ON u.tenant_id=i.tenant_id AND u.company_id=i.company_id AND u.id=i.base_unit_id
            JOIN lots l ON l.tenant_id=cl.tenant_id AND l.company_id=cl.company_id AND l.item_id=cl.item_id AND l.id=cl.lot_id
            WHERE cl.tenant_id=@tenant AND cl.company_id=@company AND cl.count_id=@id ORDER BY cl.bucket_id
            """, r => new CountLine(r.GetUInt64(0), r.GetUInt64(1), r.GetString(2), r.GetString(3), r.GetString(4), r.GetString(5),
                r.GetDecimal(6), r.GetDecimal(7), Amount(r, "actual_quantity"), Amount(r, "positive_unit_cost")), ("id", id));

    public Task<CountDetail> CountAsync(SessionData session, ulong id, CancellationToken ct) =>
        Operate(session, false, async s =>
        {
            var count = await FindCount(s, id);
            var lines = await CountLines(s, id);
            return new CountDetail(count, lines.Select(x => new CountLineView(x.Bucket, x.Sku, x.Lot, x.Unit,
                x.Condition, x.Expected, x.Actual, x.Actual - x.Expected, s.Admin ? x.Cost : null)).ToArray());
        }, ct);

    public Task<PostedReceipt> StartCountAsync(SessionData session, CountStart input, string correlation, CancellationToken ct) =>
        Operate(session, false, async s =>
        {
            var warehouse = await Ordinary(s, input.WarehouseId);
            const string command = "COUNT";
            var hash = OperationHash(0, input);
            var replay = await OperationReplay(s, command, input.OperationId, hash);
            if (replay is not null) return replay;
            await RequireUnfrozen(s, warehouse.Id);
            var doc = await Document(s, warehouse, command, null);
            await s.Execute("""
                INSERT INTO stock_counts(tenant_id,company_id,count_id,warehouse_id) VALUES(@tenant,@company,@id,@warehouse)
                """, ("id", doc.Id), ("warehouse", warehouse.Id));
            await s.Execute("""
                INSERT INTO stock_count_lines(tenant_id,company_id,count_id,warehouse_id,bucket_id,item_id,lot_id,stock_condition,expected_quantity,expected_value)
                SELECT k.tenant_id,k.company_id,@id,k.warehouse_id,k.id,k.item_id,k.lot_id,k.stock_condition,b.on_hand_base,b.operational_value
                FROM stock_buckets k JOIN stock_balances b ON b.tenant_id=k.tenant_id AND b.company_id=k.company_id AND b.bucket_id=k.id
                WHERE k.tenant_id=@tenant AND k.company_id=@company AND k.warehouse_id=@warehouse AND b.on_hand_base>0
                """, ("id", doc.Id), ("warehouse", warehouse.Id));
            await CompleteOperation(s, doc, command, input.OperationId, hash, "Warehouse stock take started", correlation);
            return doc;
        }, ct);

    private static void CheckCount(CountSummary count, ulong version)
    {
        if (count.Status != "COUNTING" || count.Version != version)
            throw Conflict("This count is closed or changed. Reload it before continuing.");
    }

    public Task<CountSummary> SaveCountAsync(SessionData session, ulong id, CountSave input, string correlation, CancellationToken ct) =>
        Operate(session, false, async s =>
        {
            var count = await FindCount(s, id);
            await Ordinary(s, count.WarehouseId);
            CheckCount(count, input.Version);
            if (input.Lines is null || input.Lines.Count is < 1 or > 1000 || input.Lines.Any(x => x is null) ||
                input.Lines.Select(x => x.BucketId).Distinct().Count() != input.Lines.Count)
                throw Invalid("Provide distinct affected count lines.");
            var snapshot = (await CountLines(s, id)).ToDictionary(x => x.Bucket);
            foreach (var entered in input.Lines.OrderBy(x => x.BucketId))
            {
                if (!snapshot.TryGetValue(entered.BucketId, out var line)) throw Missing();
                var unit = await SelectUnit(s, line.Item, null, active: false);
                if (!CatalogNumbers.Fits(entered.Quantity, 9) || (unit.BaseDiscrete && entered.Quantity != decimal.Truncate(entered.Quantity)))
                    throw Invalid("Invalid counted quantity.");
                if (!s.Admin && entered.PositiveUnitCost is not null) throw Invalid("An Administrator must confirm variance costs.");
                if (entered.PositiveUnitCost is { } cost && (!CatalogNumbers.Fits(cost, 6) || (cost == 0 && !entered.ConfirmZeroCost) || entered.Quantity <= line.Expected))
                    throw Invalid("Confirm an explicit cost for a positive variance.");
                await s.Execute("""
                    UPDATE stock_count_lines SET actual_quantity=@actual,positive_unit_cost=@cost
                    WHERE tenant_id=@tenant AND company_id=@company AND count_id=@id AND bucket_id=@bucket
                    """, ("actual", entered.Quantity), ("cost", entered.PositiveUnitCost), ("id", id), ("bucket", entered.BucketId));
            }
            await s.Execute("UPDATE stock_counts SET row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND count_id=@id", ("id", id));
            await IdentityStore.Audit(s.Connection, s.Transaction, s.Member, "COUNT_ACTUALS", "DOCUMENT", id, "Count quantities recorded",
                s.Now, correlation, s.Ct);
            return count with { Version = count.Version + 1 };
        }, ct);

    public Task<PostedReceipt> FinishCountAsync(SessionData session, ulong id, bool cancel, CountFinish input, string correlation, CancellationToken ct) =>
        Operate(session, true, async s =>
        {
            var count = await FindCount(s, id);
            var warehouse = await Ordinary(s, count.WarehouseId);
            var reason = Reason(input.Reason);
            input = input with { Reason = reason };
            var command = cancel ? "COUNTCANCEL" : "COUNTPOST";
            var hash = OperationHash(id, input);
            var replay = await OperationReplay(s, command, input.OperationId, hash);
            if (replay is not null) return replay;
            CheckCount(count, input.Version);
            var doc = await Document(s, warehouse, command, reason);
            if (!cancel)
            {
                var business = await Business(s);
                if (input.ExpectedCurrency != business.Currency) throw Conflict("The business currency changed.");
                var lines = await CountLines(s, id);
                if (lines.Any(x => x.Actual is null)) throw Conflict("Enter every counted quantity, including explicitly counted zeroes.");
                var index = 0;
                foreach (var line in lines)
                {
                    var variance = line.Actual!.Value - line.Expected;
                    var bucket = await GetBucket(s, line.Bucket);
                    if (bucket.Quantity != line.Expected || bucket.Value != line.ExpectedValue || bucket.Warehouse != warehouse.Id)
                        throw Conflict("The warehouse snapshot changed. Investigate before finalizing.");
                    if (variance == 0) continue;
                    var unit = await SelectUnit(s, line.Item, null, active: false);
                    decimal value;
                    if (variance < 0)
                    {
                        await RequireUnreserved(s, bucket, -variance);
                        value = Carry(-variance, bucket.Quantity, bucket.Value);
                    }
                    else
                    {
                        if (line.Cost is not { } cost) throw Invalid($"Confirm positive variance costs for {line.Sku}.");
                        if (bucket.Condition == "AVAILABLE" && !Eligible(bucket.Lot, business.Today))
                            throw Conflict("An expired or blocked lot cannot gain sellable stock. Record the excess in non-sellable storage.");
                        try { value = ReceiptMath.Calculate(variance, 1, cost, unit.BaseDiscrete, unit.BaseDiscrete).Value; }
                        catch (ArgumentException e) { throw Invalid(e.Message); }
                    }
                    var entry = await MoveLine(s, doc.Id, warehouse.Id, ++index, bucket.Id, unit, bucket.Lot, bucket.Condition,
                        Math.Abs(variance), value, variance < 0, unitCost: variance > 0 ? line.Cost!.Value : 0);
                    await s.Execute("""
                        UPDATE stock_count_lines SET variance_entry_id=@entry WHERE tenant_id=@tenant AND company_id=@company AND count_id=@id AND bucket_id=@bucket
                        """, ("entry", entry), ("id", id), ("bucket", line.Bucket));
                }
                if (input.Unexpected is { Count: > 0 } unexpected)
                {
                    var request = AdjustmentInput(warehouse, business.Currency, business.Today, input.OperationId, unexpected);
                    var prepared = await Prepare(s, warehouse, false, request, adjustment: true, completingCount: true);
                    foreach (var incoming in prepared.Lines)
                    {
                        var (bucket, entry, lot) = await Append(s, doc.Id, warehouse.Id, ++index, incoming);
                        if (lines.Any(x => x.Bucket == bucket))
                            throw Conflict("A counted bucket already exists for this unexpected line. Update its actual count.");
                        var exists = await s.Scalar("""
                            SELECT 1 FROM stock_count_lines WHERE tenant_id=@tenant AND company_id=@company AND count_id=@id AND bucket_id=@bucket
                            """, ("id", id), ("bucket", bucket));
                        if (exists is not null) throw Invalid("Combine duplicate unexpected bucket lines.");
                        await s.Execute("""
                            INSERT INTO stock_count_lines(tenant_id,company_id,count_id,warehouse_id,bucket_id,item_id,lot_id,stock_condition,
                              expected_quantity,expected_value,actual_quantity,positive_unit_cost,variance_entry_id)
                            VALUES(@tenant,@company,@id,@warehouse,@bucket,@item,@lot,@condition,0,0,@actual,@cost,@entry)
                            """, ("id", id), ("warehouse", warehouse.Id), ("bucket", bucket), ("item", incoming.Input.ItemId),
                            ("lot", lot), ("condition", incoming.Input.Condition), ("actual", incoming.BaseQuantity), ("cost", incoming.BaseCost), ("entry", entry));
                    }
                }
                if (index > 0) await LockInventoryCurrency(s);
            }
            await s.Execute("""
                UPDATE stock_counts SET status=@status,terminal_id=@doc,row_version=row_version+1
                WHERE tenant_id=@tenant AND company_id=@company AND count_id=@id
                """, ("status", cancel ? "CANCELLED" : "COMPLETED"), ("doc", doc.Id), ("id", id));
            await CompleteOperation(s, doc, command, input.OperationId, hash, reason, correlation);
            return doc;
        }, ct);
}
