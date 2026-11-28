using Conex360.Application.Inventory;
using Conex360.Domain.Catalog;
using Conex360.Domain.Identity;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed partial class InventoryStore
{
    private const string TransferSelect = """
        SELECT t.request_id,d.document_number,t.source_warehouse_id,t.source_name,t.destination_warehouse_id,t.destination_name,
          t.reference,t.confirmation_id IS NOT NULL,t.cancellation_id IS NOT NULL,
          (@admin=1 OR (gs.membership_id IS NOT NULL AND sw.is_active=1 AND sb.is_active=1)) AND (@branch IS NULL OR sw.branch_id=@branch) AS source_access,
          (@admin=1 OR (gd.membership_id IS NOT NULL AND dw.is_active=1 AND db.is_active=1)) AND (@branch IS NULL OR dw.branch_id=@branch) AS destination_access
        FROM stock_transfers t JOIN documents d ON d.tenant_id=t.tenant_id AND d.company_id=t.company_id AND d.id=t.request_id
        JOIN warehouses sw ON sw.tenant_id=t.tenant_id AND sw.company_id=t.company_id AND sw.id=t.source_warehouse_id
        JOIN warehouses dw ON dw.tenant_id=t.tenant_id AND dw.company_id=t.company_id AND dw.id=t.destination_warehouse_id
        JOIN branches sb ON sb.tenant_id=sw.tenant_id AND sb.company_id=sw.company_id AND sb.id=sw.branch_id
        JOIN branches db ON db.tenant_id=dw.tenant_id AND db.company_id=dw.company_id AND db.id=dw.branch_id
        LEFT JOIN membership_branches gs ON gs.tenant_id=t.tenant_id AND gs.company_id=t.company_id AND gs.branch_id=sw.branch_id AND gs.membership_id=@actor AND gs.is_active=1
        LEFT JOIN membership_branches gd ON gd.tenant_id=t.tenant_id AND gd.company_id=t.company_id AND gd.branch_id=dw.branch_id AND gd.membership_id=@actor AND gd.is_active=1
        WHERE t.tenant_id=@tenant AND t.company_id=@company
        """;
    private static TransferSummary ReadTransfer(MySqlDataReader r) =>
        new(r.GetUInt64(0), r.GetString(1), r.GetUInt64(2), r.GetString(3), r.GetUInt64(4), r.GetString(5),
            Sql.Text(r, "reference"), r.GetBoolean(7), r.GetBoolean(8), r.GetBoolean(9), r.GetBoolean(10));
    private static async Task<TransferSummary> FindTransfer(Scope s, ulong id)
    {
        var result = await s.One(TransferSelect + " AND t.request_id=@id HAVING source_access OR destination_access",
            ReadTransfer, ("id", id));
        return result ?? throw Missing();
    }

    public Task<IReadOnlyList<TransferSummary>> TransfersAsync(SessionData session, ulong? before, CancellationToken ct) =>
        Operate(session, false, s => s.List(TransferSelect + """
             AND (@before IS NULL OR t.request_id<@before) HAVING source_access OR destination_access ORDER BY t.request_id DESC LIMIT 50
            """, ReadTransfer, ("before", before)), ct);

    public Task<IReadOnlyList<TransferWarehouse>> TransferWarehousesAsync(SessionData session, CancellationToken ct) =>
        Operate(session, false, s => s.List("""
            SELECT w.id,w.name,b.name,(@branch IS NULL OR b.id=@branch) AND (@admin=1 OR g.membership_id IS NOT NULL)
            FROM warehouses w JOIN branches b ON b.tenant_id=w.tenant_id AND b.company_id=w.company_id AND b.id=w.branch_id
            LEFT JOIN membership_branches g ON g.tenant_id=w.tenant_id AND g.company_id=w.company_id
              AND g.branch_id=w.branch_id AND g.membership_id=@actor AND g.is_active=1
            WHERE w.tenant_id=@tenant AND w.company_id=@company AND w.kind='ORDINARY' AND w.is_active=1 AND b.is_active=1
              AND (@admin=1 OR EXISTS (
                SELECT 1 FROM membership_branches a JOIN branches active_branch
                  ON active_branch.tenant_id=a.tenant_id AND active_branch.company_id=a.company_id AND active_branch.id=a.branch_id
                WHERE a.tenant_id=w.tenant_id AND a.company_id=w.company_id AND a.membership_id=@actor
                  AND a.is_active=1 AND active_branch.is_active=1 AND (@branch IS NULL OR a.branch_id=@branch)
              ))
            ORDER BY b.name,w.name,w.id LIMIT 250
            """, r => new TransferWarehouse(r.GetUInt64(0), r.GetString(1), r.GetString(2), r.GetBoolean(3))), ct);

    private sealed record RequestLine(ulong Id, ulong Item, string Sku, string Unit, decimal Quantity);
    private static Task<IReadOnlyList<RequestLine>> RequestLines(Scope s, ulong id) =>
        s.List("""
            SELECT dl.id,dl.item_id,dl.sku,u.code,dl.base_quantity
            FROM document_lines dl JOIN items i ON i.tenant_id=dl.tenant_id AND i.company_id=dl.company_id AND i.id=dl.item_id
            JOIN units u ON u.tenant_id=i.tenant_id AND u.company_id=i.company_id AND u.id=i.base_unit_id
            WHERE dl.tenant_id=@tenant AND dl.company_id=@company AND dl.document_id=@request ORDER BY dl.id
            """, r => new RequestLine(r.GetUInt64(0), r.GetUInt64(1), r.GetString(2), r.GetString(3), r.GetDecimal(4)), ("request", id));

    private sealed record Reservation(ulong Id, ulong Line, ulong Bucket, string Lot, decimal Remaining);
    private static Task<IReadOnlyList<Reservation>> Reservations(Scope s, ulong id) =>
        s.List("""
            SELECT r.id,r.request_line_id,r.bucket_id,l.lot_code,r.reserved_quantity-r.consumed_quantity-r.released_quantity
            FROM stock_reservations r JOIN stock_buckets b ON b.tenant_id=r.tenant_id AND b.company_id=r.company_id AND b.id=r.bucket_id
            JOIN lots l ON l.tenant_id=b.tenant_id AND l.company_id=b.company_id AND l.item_id=b.item_id AND l.id=b.lot_id
            WHERE r.tenant_id=@tenant AND r.company_id=@company AND r.request_id=@request ORDER BY r.id
            """, r => new Reservation(r.GetUInt64(0), r.GetUInt64(1), r.GetUInt64(2), r.GetString(3), r.GetDecimal(4)), ("request", id));

    private sealed record Allocation(ulong Id, ulong Line, ulong Bucket, string Lot, DateOnly? Expiry, decimal Shipped, decimal Value,
        decimal Received, decimal Lost, decimal Returned, decimal UsedValue)
    {
        public decimal Outstanding => Shipped - Received - Lost - Returned;
        public decimal OutstandingValue => Value - UsedValue;
    }

    private static async Task<IReadOnlyList<Allocation>> Allocations(Scope s, ulong id)
    {
        var rows = await s.List("""
            SELECT a.id,r.request_line_id,a.transit_bucket_id,l.lot_code,l.expires_on,a.quantity,a.carried_value,
              COALESCE((SELECT SUM(x.quantity) FROM transfer_receipt_allocations x WHERE x.tenant_id=a.tenant_id AND x.company_id=a.company_id AND x.dispatch_allocation_id=a.id),0),
              COALESCE((SELECT SUM(x.quantity) FROM transfer_resolution_allocations x WHERE x.tenant_id=a.tenant_id AND x.company_id=a.company_id AND x.dispatch_allocation_id=a.id AND x.disposition='LOSS'),0),
              COALESCE((SELECT SUM(x.quantity) FROM transfer_resolution_allocations x WHERE x.tenant_id=a.tenant_id AND x.company_id=a.company_id AND x.dispatch_allocation_id=a.id AND x.disposition='RETURN'),0),
              COALESCE((SELECT SUM(x.carried_value) FROM transfer_receipt_allocations x WHERE x.tenant_id=a.tenant_id AND x.company_id=a.company_id AND x.dispatch_allocation_id=a.id),0)
              + COALESCE((SELECT SUM(x.carried_value) FROM transfer_resolution_allocations x WHERE x.tenant_id=a.tenant_id AND x.company_id=a.company_id AND x.dispatch_allocation_id=a.id),0)
            FROM transfer_dispatch_allocations a
            JOIN stock_reservations r ON r.tenant_id=a.tenant_id AND r.company_id=a.company_id AND r.id=a.reservation_id
            JOIN stock_buckets b ON b.tenant_id=a.tenant_id AND b.company_id=a.company_id AND b.id=a.transit_bucket_id
            JOIN lots l ON l.tenant_id=b.tenant_id AND l.company_id=b.company_id AND l.item_id=b.item_id AND l.id=b.lot_id
            WHERE a.tenant_id=@tenant AND a.company_id=@company AND r.request_id=@request ORDER BY a.id
            """, r => new Allocation(r.GetUInt64(0), r.GetUInt64(1), r.GetUInt64(2), r.GetString(3), Day(r, "expires_on"),
                r.GetDecimal(5), r.GetDecimal(6), r.GetDecimal(7), r.GetDecimal(8), r.GetDecimal(9), r.GetDecimal(10)), ("request", id));
        return rows;
    }

    public Task<TransferDetail> TransferAsync(SessionData session, ulong id, CancellationToken ct) =>
        Operate(session, false, async s =>
        {
            var transfer = await FindTransfer(s, id);
            var lines = await RequestLines(s, id);
            var reservations = await Reservations(s, id);
            var dispatches = await Allocations(s, id);
            var progress = lines.Select(line =>
            {
                var facts = dispatches.Where(x => x.Line == line.Id).ToArray();
                var shipped = facts.Sum(x => x.Shipped);
                return new TransferProgress(line.Id, line.Sku, line.Unit, line.Quantity,
                    reservations.Where(x => x.Line == line.Id).Sum(x => x.Remaining), shipped, facts.Sum(x => x.Received),
                    facts.Sum(x => x.Lost), facts.Sum(x => x.Returned), transfer.Cancelled ? line.Quantity - shipped : 0, facts.Sum(x => x.Outstanding));
            }).ToArray();
            string Sku(ulong line) => lines.Single(x => x.Id == line).Sku;
            return new TransferDetail(transfer, progress,
                transfer.SourceAccess ? reservations.Where(x => x.Remaining > 0).Select(x => new ReservationView(x.Id, Sku(x.Line), x.Lot, x.Remaining)).ToArray() : [],
                dispatches.Select(x => new DispatchView(x.Id, Sku(x.Line), x.Lot, x.Expiry, x.Shipped, x.Outstanding, s.Admin ? x.OutstandingValue : null)).ToArray());
        }, ct);

    public Task<PostedReceipt> RequestAsync(SessionData session, TransferRequestInput input, string correlation, CancellationToken ct) =>
        Operate(session, false, async s =>
        {
            if (input.SourceWarehouseId == input.DestinationWarehouseId || input.Lines is null ||
                input.Lines.Count is < 1 or > 50 || input.Lines.Any(x => x is null) ||
                input.Lines.Select(x => x.ItemId).Distinct().Count() != input.Lines.Count)
                throw Invalid("Choose two different warehouses and one line per product.");
            var destination = await Ordinary(s, input.DestinationWarehouseId);
            var source = await Ordinary(s, input.SourceWarehouseId, false);
            input = input with { Reference = Clean(input.Reference, 120), Notes = Clean(input.Notes, 700) };
            var hash = OperationHash(0, input);
            var replay = await OperationReplay(s, "XREQ", input.OperationId, hash);
            if (replay is not null) return replay;
            var doc = await Document(s, source, "XREQ", input.Notes);
            await s.Execute("""
                INSERT INTO stock_transfers(tenant_id,company_id,request_id,source_warehouse_id,destination_warehouse_id,source_name,destination_name,reference)
                VALUES(@tenant,@company,@request,@source,@target,@sourceName,@targetName,@reference)
                """, ("request", doc.Id), ("source", source.Id), ("target", destination.Id), ("sourceName", source.Name),
                ("targetName", destination.Name), ("reference", input.Reference));
            var index = 0;
            foreach (var line in input.Lines)
            {
                var unit = await SelectUnit(s, line.ItemId, line.ItemUnitId, line.ItemVersion, line.UnitVersion);
                await MakeLine(s, doc.Id, source.Id, ++index, unit, null, "AVAILABLE", line.Quantity, ConvertQuantity(unit, line.Quantity), 0);
            }
            await CompleteOperation(s, doc, "XREQ", input.OperationId, hash, "Transfer requested", correlation);
            return doc;
        }, ct);

    public Task<PostedReceipt> TransferStepAsync(SessionData session, ulong id, string action, StockStep input, string correlation, CancellationToken ct) =>
        Operate(session, false, async s =>
        {
            var transfer = await FindTransfer(s, id);
            if (!transfer.SourceAccess) throw Missing();
            var source = await Ordinary(s, transfer.SourceId);
            var confirm = action == "confirm";
            if (!confirm && action != "cancel") throw Invalid("Unknown transfer step.");
            var command = confirm ? "XCONF" : "XCANCEL";
            var reason = confirm ? Clean(input.Reason, 300) ?? "Transfer confirmed" : Reason(input.Reason);
            var hash = OperationHash(id, input with { Reason = reason });
            var replay = await OperationReplay(s, command, input.OperationId, hash);
            if (replay is not null) return replay;
            if (transfer.Cancelled || (confirm && transfer.Confirmed)) throw Conflict("This transfer step is already closed.");
            await RequireUnfrozen(s, source.Id, transfer.DestinationId);
            var doc = await Document(s, source, command, reason);
            if (confirm)
            {
                var today = (await Business(s)).Today;
                foreach (var line in await RequestLines(s, id))
                {
                    await SelectUnit(s, line.Item, null);
                    var remaining = line.Quantity;
                    var buckets = await s.List(BucketSelect + """
                         AND k.warehouse_id=@warehouse AND k.item_id=@item AND k.stock_condition='AVAILABLE' AND b.on_hand_base>0
                         AND l.is_blocked=0 AND (l.expires_on IS NULL OR l.expires_on>=@today)
                         ORDER BY l.expires_on IS NULL,l.expires_on,l.id,k.id
                        """, ReadBucket, ("warehouse", source.Id), ("item", line.Item), ("today", today));
                    foreach (var bucket in buckets)
                    {
                        var take = Math.Min(remaining, bucket.Quantity - await Reserved(s, bucket.Id));
                        if (take <= 0) continue;
                        await s.Execute("""
                            INSERT INTO stock_reservations(tenant_id,company_id,request_id,request_line_id,item_id,bucket_id,reserved_quantity)
                            VALUES(@tenant,@company,@request,@line,@item,@bucket,@quantity)
                            """, ("request", id), ("line", line.Id), ("item", line.Item), ("bucket", bucket.Id), ("quantity", take));
                        remaining -= take;
                        if (remaining == 0) break;
                    }
                    if (remaining > 0) throw Conflict($"Insufficient eligible stock for {line.Sku}.");
                }
                await s.Execute("UPDATE stock_transfers SET confirmation_id=@doc WHERE tenant_id=@tenant AND company_id=@company AND request_id=@request",
                    ("doc", doc.Id), ("request", id));
            }
            else
            {
                var dispatched = await Allocations(s, id);
                if ((await RequestLines(s, id)).All(line => dispatched.Where(x => x.Line == line.Id).Sum(x => x.Shipped) == line.Quantity))
                    throw Conflict("All requested quantities have already been dispatched.");
                await s.Execute("""
                    UPDATE stock_reservations SET released_quantity=reserved_quantity-consumed_quantity
                    WHERE tenant_id=@tenant AND company_id=@company AND request_id=@request
                    """, ("request", id));
                await s.Execute("UPDATE stock_transfers SET cancellation_id=@doc WHERE tenant_id=@tenant AND company_id=@company AND request_id=@request",
                    ("doc", doc.Id), ("request", id));
            }
            await CompleteOperation(s, doc, command, input.OperationId, hash, reason, correlation);
            return doc;
        }, ct);

    public Task<PostedReceipt> AllocationAsync(SessionData session, ulong id, string action, AllocationInput input, string correlation, CancellationToken ct) =>
        Operate(session, action is "loss" or "return", async s =>
        {
            var transfer = await FindTransfer(s, id);
            var command = action switch
            {
                "dispatch" when transfer.SourceAccess => "XSHIP",
                "receive" when transfer.DestinationAccess => "XREC",
                "loss" => "XLOSS",
                "return" => "XRETURN",
                _ => throw Missing()
            };
            if (input.Lines is null || input.Lines.Count is < 1 or > 100 || input.Lines.Any(x => x is null) ||
                input.Lines.Select(x => x.Id).Distinct().Count() != input.Lines.Count ||
                input.Lines.Any(x => x.Quantity <= 0 || !CatalogNumbers.Fits(x.Quantity, 9)))
                throw Invalid("Supply distinct allocations with positive exact quantities.");
            var reason = action is "loss" or "return" ? Reason(input.Reason) : Clean(input.Reason, 300) ?? command;
            input = input with { Reason = reason, Lines = input.Lines.OrderBy(x => x.Id).ToArray() };
            var hash = OperationHash(id, input);
            var replay = await OperationReplay(s, command, input.OperationId, hash);
            if (replay is not null) return replay;
            if (!transfer.Confirmed || (action == "dispatch" && transfer.Cancelled))
                throw Conflict("This transfer is not open for that step.");
            var ordinary = await Ordinary(s, action == "receive" ? transfer.DestinationId : transfer.SourceId,
                action is "receive" or "dispatch");
            await RequireUnfrozen(s, action == "dispatch" ? transfer.SourceId : ordinary.Id);
            var transit = await Transit(s);
            var doc = await Document(s, action == "loss" ? transit : ordinary, command, reason);
            if (action == "dispatch")
                await Dispatch(s, id, ordinary, transit, doc, input.Lines);
            else
                await Settle(s, id, ordinary, transit, doc, action, input.Lines);
            await CompleteOperation(s, doc, command, input.OperationId, hash, reason, correlation);
            return doc;
        }, ct);

    private static async Task Dispatch(Scope s, ulong request, Warehouse source, Warehouse transit, PostedReceipt doc,
        IReadOnlyList<AllocationQuantity> inputs)
    {
        var mirror = await Document(s, transit, "XIN", doc.Number);
        var reservations = await Reservations(s, request);
        var today = (await Business(s)).Today;
        var index = 0;
        foreach (var input in inputs)
        {
            var reservation = reservations.SingleOrDefault(x => x.Id == input.Id) ?? throw Missing();
            if (input.Quantity > reservation.Remaining || input.Condition is not null)
                throw Conflict("Dispatch exceeds the outstanding reservation.");
            var bucket = await GetBucket(s, reservation.Bucket);
            if (bucket.Warehouse != source.Id || bucket.Condition != "AVAILABLE" || !Eligible(bucket.Lot, today))
                throw Conflict("The reserved lot is no longer eligible. Cancel its undisbursed remainder.");
            var unit = await SelectUnit(s, bucket.Item, null);
            var quantity = ConvertQuantity(unit, input.Quantity);
            var value = Carry(quantity, bucket.Quantity, bucket.Value);
            var target = await LocateBucket(s, transit.Id, bucket.Item, bucket.Lot, "TRANSIT");
            index++;
            var issued = await MoveLine(s, doc.Id, source.Id, index, bucket.Id, unit, bucket.Lot, bucket.Condition, quantity, value, true);
            var carried = await MoveLine(s, mirror.Id, transit.Id, index, target, unit, bucket.Lot, "TRANSIT", quantity, value, false);
            await s.Execute("""
                UPDATE stock_reservations SET consumed_quantity=consumed_quantity+@quantity WHERE tenant_id=@tenant AND company_id=@company AND id=@id
                """, ("id", reservation.Id), ("quantity", quantity));
            await s.Execute("""
                INSERT INTO transfer_dispatch_allocations(tenant_id,company_id,reservation_id,dispatch_id,source_entry_id,transit_entry_id,transit_bucket_id,quantity,carried_value)
                VALUES(@tenant,@company,@reserved,@doc,@source,@transitEntry,@bucket,@quantity,@value)
                """, ("reserved", reservation.Id), ("doc", doc.Id), ("source", issued), ("transitEntry", carried), ("bucket", target),
                ("quantity", quantity), ("value", value));
        }
    }

    private static async Task Settle(Scope s, ulong request, Warehouse ordinary, Warehouse transit, PostedReceipt doc,
        string action, IReadOnlyList<AllocationQuantity> inputs)
    {
        var loss = action == "loss";
        var receipt = action == "receive";
        var mirror = loss ? doc : await Document(s, transit, "XOUT", doc.Number);
        var allocations = await Allocations(s, request);
        var today = (await Business(s)).Today;
        var index = 0;
        foreach (var input in inputs)
        {
            var allocation = allocations.SingleOrDefault(x => x.Id == input.Id) ?? throw Missing();
            var bucket = await GetBucket(s, allocation.Bucket);
            if (bucket.Warehouse != transit.Id || bucket.Condition != "TRANSIT") throw Conflict("The transit allocation is inconsistent.");
            var unit = await SelectUnit(s, bucket.Item, null, active: false);
            var quantity = ConvertQuantity(unit, input.Quantity);
            var value = Carry(quantity, allocation.Outstanding, allocation.OutstandingValue);
            var disposition = receipt ? input.Condition : "HOLD";
            if (disposition is not ("AVAILABLE" or "HOLD" or "DAMAGED") ||
                (disposition == "AVAILABLE" && !Eligible(bucket.Lot, today)))
                throw Invalid("Choose an eligible receipt condition. Expired or blocked lots must be held or damaged.");
            index++;
            var issued = await MoveLine(s, mirror.Id, transit.Id, index, bucket.Id, unit, bucket.Lot, "TRANSIT", quantity, value, true);
            ulong? received = null;
            if (!loss)
            {
                var target = await LocateBucket(s, ordinary.Id, bucket.Item, bucket.Lot, disposition);
                received = await MoveLine(s, doc.Id, ordinary.Id, index, target, unit, bucket.Lot, disposition, quantity, value, false);
            }
            if (receipt)
                await s.Execute("""
                    INSERT INTO transfer_receipt_allocations(tenant_id,company_id,dispatch_allocation_id,receipt_id,transit_entry_id,destination_entry_id,quantity,carried_value)
                    VALUES(@tenant,@company,@allocation,@doc,@transitEntry,@destination,@quantity,@value)
                    """, ("allocation", allocation.Id), ("doc", doc.Id), ("transitEntry", issued), ("destination", received), ("quantity", quantity), ("value", value));
            else
                await s.Execute("""
                    INSERT INTO transfer_resolution_allocations(tenant_id,company_id,dispatch_allocation_id,resolution_id,transit_entry_id,destination_entry_id,disposition,quantity,carried_value)
                    VALUES(@tenant,@company,@allocation,@doc,@transitEntry,@destination,@disposition,@quantity,@value)
                    """, ("allocation", allocation.Id), ("doc", doc.Id), ("transitEntry", issued), ("destination", received),
                    ("disposition", loss ? "LOSS" : "RETURN"), ("quantity", quantity), ("value", value));
        }
    }
}
