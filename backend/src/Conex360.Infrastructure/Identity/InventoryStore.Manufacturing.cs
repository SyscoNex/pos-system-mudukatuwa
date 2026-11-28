using Conex360.Application.Identity;
using Conex360.Application.Inventory;
using Conex360.Domain.Catalog;
using Conex360.Domain.Identity;

namespace Conex360.Infrastructure.Identity;

public sealed partial class InventoryStore
{
    private const string ProductionCommand = "PROD";

    private Task<T> Manufacture<T>(SessionData session, bool admin, Func<Scope, Task<T>> action, CancellationToken ct) =>
        InScope(session, admin, s =>
        {
            if (!settings.ManufacturingEnabled)
                throw new AppFailure(503, "MANUFACTURING_DISABLED", "Manufacturing is not enabled.");
            return action(s);
        }, ct);

    private sealed record ProductionIssue(int Group, StockUnit Unit, StockLot Lot, ulong Bucket,
        decimal Entered, decimal Quantity, decimal Value);
    private sealed record ProductionPlan(StockUnit Unit, StockLot? ExistingLot, string LotCode, string Tracking,
        decimal Quantity, decimal Value, string Currency, IReadOnlyList<ProductionIssue> Issues);

    private static ProductionInput NormalizeProduction(ProductionInput input)
    {
        if (input.OperationId == Guid.Empty || input.Output is null || input.Materials is null ||
            input.Materials.Count is < 1 or > 50 || input.Materials.Any(x => x is null))
            throw Invalid("Provide an operation ID, one output and between one and 50 material lines.");
        if (input.Materials.Any(x => x.ItemId == input.Output.ItemId))
            throw Invalid("The output SKU cannot also be consumed in this run.");
        return input with
        {
            Reference = Clean(input.Reference, 120),
            Notes = Clean(input.Notes, 700),
            Output = input.Output with { LotCode = Clean(input.Output.LotCode, 128) }
        };
    }

    private static async Task<ProductionPlan> PlanProduction(Scope s, Warehouse warehouse, ProductionInput input)
    {
        if (warehouse.Version != input.WarehouseVersion) throw Conflict("The warehouse configuration changed.");
        await RequireUnfrozen(s, warehouse.Id);
        var business = await Business(s);
        if (!string.Equals(input.ExpectedCurrency, business.Currency, StringComparison.Ordinal))
            throw Conflict("The business currency changed.");
        if (input.ProductionDate.Year < 1000 || input.ProductionDate > business.Today)
            throw Invalid("Enter a production date on or before the current company date.");

        var output = input.Output;
        var outputUnit = await SelectUnit(s, output.ItemId, output.ItemUnitId, output.ItemVersion, output.UnitVersion);
        var outputQuantity = ConvertQuantity(outputUnit, output.Quantity);
        var config = await s.One("""
            SELECT tracking_mode,expiry_required
            FROM items WHERE tenant_id=@tenant AND company_id=@company AND id=@id
              AND manufacture_enabled=1 AND kind IN ('FINISHED','INTERMEDIATE')
            """, r => new { Tracking = r.GetString(0), ExpiryRequired = r.GetBoolean(1) }, ("id", output.ItemId))
            ?? throw Invalid("Choose an active, manufacture-enabled finished or intermediate output.");

        var tracked = config.Tracking == "LOT";
        if (tracked && (output.LotCode is null || output.LotCode.Equals("SYSTEM", StringComparison.OrdinalIgnoreCase) ||
            (config.ExpiryRequired && output.ExpiresOn is null)))
            throw Invalid("Enter a new output lot code and any required expiry date.");
        if (!tracked && (output.LotCode is not null || output.ExpiresOn is not null))
            throw Invalid("Untracked products use the SYSTEM lot without batch dates.");
        if (output.ExpiresOn < business.Today || output.ExpiresOn < input.ProductionDate)
            throw Invalid("Output expiry cannot be earlier than the production or current company date.");

        var code = tracked ? output.LotCode! : "SYSTEM";
        var existing = await s.One("""
            SELECT id,lot_code,supplier_lot,manufactured_on,expires_on,is_blocked
            FROM lots WHERE tenant_id=@tenant AND company_id=@company AND item_id=@item AND lot_code=@code
            """, r => new StockLot(r.GetUInt64(0), r.GetString(1), Sql.Text(r, "supplier_lot"),
                Day(r, "manufactured_on"), Day(r, "expires_on"), r.GetBoolean(5)), ("item", output.ItemId), ("code", code));
        if (tracked && existing is not null) throw Conflict("The production lot code already exists for this item.");
        if (existing?.Blocked == true) throw Conflict("The output SYSTEM lot is blocked.");

        var plans = new List<ProductionIssue>();
        var residuals = new Dictionary<ulong, (decimal Quantity, decimal Value, decimal Reserved)>();
        var candidates = new Dictionary<ulong, IReadOnlyList<Bucket>>();
        var materialKinds = new HashSet<ulong>();
        decimal total = 0;
        // Explicit allocations take priority. Original input order is kept in the immutable group number.
        foreach (var row in input.Materials.Select((line, index) => (Line: line, Group: index + 1))
            .OrderBy(x => x.Line.BucketId is null).ThenBy(x => x.Group))
        {
            var material = row.Line;
            var unit = await SelectUnit(s, material.ItemId, material.ItemUnitId, material.ItemVersion, material.UnitVersion);
            if (materialKinds.Add(material.ItemId) && await s.Scalar("""
                SELECT 1 FROM items WHERE tenant_id=@tenant AND company_id=@company AND id=@item
                  AND kind IN ('RAW','PACKAGING','INTERMEDIATE')
                """, ("item", material.ItemId)) is null)
                throw Invalid("Use raw, packaging or intermediate products as production materials.");
            var needed = ConvertQuantity(unit, material.Quantity);
            IReadOnlyList<Bucket> buckets;
            if (material.BucketId is { } bucketId)
                buckets = [await s.One(BucketSelect + " AND k.id=@id AND k.warehouse_id=@warehouse AND k.item_id=@item FOR UPDATE OF b",
                    ReadBucket, ("id", bucketId), ("warehouse", warehouse.Id), ("item", material.ItemId)) ?? throw Missing()];
            else if (!candidates.TryGetValue(material.ItemId, out buckets!))
            {
                buckets = await s.List(BucketSelect + """
                     AND k.warehouse_id=@warehouse AND k.item_id=@item AND k.stock_condition='AVAILABLE' AND b.on_hand_base>0
                     AND l.is_blocked=0 AND (l.expires_on IS NULL OR l.expires_on>=@today)
                     AND (l.manufactured_on IS NULL OR l.manufactured_on<=@date)
                     ORDER BY l.expires_on IS NULL,l.expires_on,l.id,k.id FOR UPDATE OF b
                    """, ReadBucket, ("warehouse", warehouse.Id), ("item", material.ItemId), ("today", business.Today), ("date", input.ProductionDate));
                candidates.Add(material.ItemId, buckets);
            }

            foreach (var bucket in buckets)
            {
                if (bucket.Warehouse != warehouse.Id || bucket.Item != material.ItemId || bucket.Condition != "AVAILABLE" ||
                    !Eligible(bucket.Lot, business.Today) || bucket.Lot.Manufactured > input.ProductionDate)
                {
                    if (material.BucketId.HasValue) throw Conflict("The selected material lot is unavailable for this run.");
                    continue;
                }
                if (!residuals.TryGetValue(bucket.Id, out var residual))
                    residual = (bucket.Quantity, bucket.Value, await Reserved(s, bucket.Id));
                var take = Math.Min(needed, residual.Quantity - residual.Reserved);
                if (take <= 0) continue;
                if (unit.BaseDiscrete && take != decimal.Truncate(take))
                    throw Conflict("The selected stock cannot be consumed in whole base units.");
                var value = Carry(take, residual.Quantity, residual.Value);
                residuals[bucket.Id] = (residual.Quantity - take, residual.Value - value, residual.Reserved);
                total += value;
                if (!CatalogNumbers.Fits(total, 6) || plans.Count >= 500)
                    throw Invalid("The production run exceeds supported posting limits.");
                plans.Add(new(row.Group, unit, bucket.Lot, bucket.Id, material.Quantity, take, value));
                needed -= take;
                if (needed == 0) break;
            }
            if (needed > 0) throw Conflict($"Insufficient eligible unreserved stock for {unit.Sku}.");
        }
        return new(outputUnit, existing, code, config.Tracking, outputQuantity, total, business.Currency, plans);
    }

    private static decimal AverageProductionCost(decimal value, decimal quantity) =>
        decimal.Round(value / quantity, 6, MidpointRounding.AwayFromZero);

    public Task<ProductionPreview> PreviewProductionAsync(SessionData session, ProductionInput input, CancellationToken ct) =>
        Manufacture(session, false, async s =>
        {
            input = NormalizeProduction(input);
            var warehouse = await Ordinary(s, input.WarehouseId);
            var plan = await PlanProduction(s, warehouse, input);
            return new ProductionPreview(plan.Issues.OrderBy(x => x.Group).Select(x => new ProductionAllocation(x.Group,
                x.Unit.Sku, x.Unit.ItemName, x.Unit.Code, x.Entered, x.Unit.Factor, x.Quantity, x.Lot.Id, x.Lot.Code, x.Lot.Expiry,
                s.Admin ? x.Value : null)).ToArray(), plan.Quantity, plan.Unit.Sku, plan.LotCode, plan.Currency,
                s.Admin ? plan.Value : null, s.Admin ? AverageProductionCost(plan.Value, plan.Quantity) : null);
        }, ct);

    public Task<PostedReceipt> PostProductionAsync(SessionData session, ProductionInput input, string correlation, CancellationToken ct) =>
        Manufacture(session, false, async s =>
        {
            input = NormalizeProduction(input);
            var warehouse = await Ordinary(s, input.WarehouseId);
            var hash = OperationHash(warehouse.Id, input);
            var replay = await OperationReplay(s, ProductionCommand, input.OperationId, hash);
            if (replay is not null) return replay;

            var plan = await PlanProduction(s, warehouse, input);
            var doc = await Document(s, warehouse, ProductionCommand, input.Notes, plan.Value, input.ProductionDate);
            var index = 0;
            foreach (var issue in plan.Issues)
            {
                var line = await MakeLine(s, doc.Id, warehouse.Id, ++index, issue.Unit, issue.Lot, "AVAILABLE",
                    issue.Entered, issue.Quantity, issue.Value, production: new("INPUT", issue.Group));
                await WriteMovement(s, doc.Id, line, issue.Bucket, warehouse.Id, issue.Unit.ItemId, issue.Lot.Id, "AVAILABLE",
                    -issue.Quantity, -issue.Value);
            }

            var lot = plan.ExistingLot;
            if (lot is null)
            {
                DateOnly? made = plan.Tracking == "LOT" ? input.ProductionDate : null;
                var id = await s.Insert("""
                    INSERT INTO lots(tenant_id,company_id,item_id,lot_code,tracking_mode,manufactured_on,expires_on)
                    VALUES(@tenant,@company,@item,@lot,@tracking,@manufactured,@expiry)
                    """, ("item", plan.Unit.ItemId), ("lot", plan.LotCode), ("tracking", plan.Tracking),
                    ("manufactured", made), ("expiry", input.Output.ExpiresOn));
                lot = new(id, plan.LotCode, null, made, input.Output.ExpiresOn, false);
            }

            var bucket = await LocateBucket(s, warehouse.Id, plan.Unit.ItemId, lot, "AVAILABLE");
            var outputLine = await MakeLine(s, doc.Id, warehouse.Id, ++index, plan.Unit, lot, "AVAILABLE",
                input.Output.Quantity, plan.Quantity, plan.Value, production: new("OUTPUT", null));
            var entry = await WriteMovement(s, doc.Id, outputLine, bucket, warehouse.Id, plan.Unit.ItemId, lot.Id, "AVAILABLE",
                plan.Quantity, plan.Value);
            await s.Execute("""
                INSERT INTO production_events(tenant_id,company_id,document_id,warehouse_id,output_line_id,output_entry_id,output_item_id,output_lot_id,production_reference)
                VALUES(@tenant,@company,@doc,@warehouse,@line,@entry,@item,@lot,@reference)
                """, ("doc", doc.Id), ("warehouse", warehouse.Id), ("line", outputLine), ("entry", entry),
                ("item", plan.Unit.ItemId), ("lot", lot.Id), ("reference", input.Reference));
            await LockInventoryCurrency(s);
            await CompleteOperation(s, doc, ProductionCommand, input.OperationId, hash, "Completed production run", correlation);
            return doc;
        }, ct);
}
