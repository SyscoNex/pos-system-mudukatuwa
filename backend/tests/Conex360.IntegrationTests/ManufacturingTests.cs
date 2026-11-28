using System.Text.Json;
using Conex360.Application.Catalog;
using Conex360.Application.Identity;
using Conex360.Application.Inventory;
using Conex360.Application.Organization;
using Conex360.Domain.Identity;
using Microsoft.Extensions.DependencyInjection;
using MySqlConnector;

namespace Conex360.IntegrationTests;

public sealed class ManufacturingMySqlFactAttribute : FactAttribute
{
    public ManufacturingMySqlFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("CONEX360_MYSQL_APPROVED") != "1" ||
            Environment.GetEnvironmentVariable("CONEX360_MANUFACTURING_MYSQL_APPROVED") != "1")
            Skip = "Requires separately approved P1-07 schema and synthetic MySQL target.";
    }
}

public sealed partial class MySqlIdentityTests
{
    [ManufacturingMySqlFact]
    public async Task ManufacturingConservesValueAndTracesBulkLots()
    {
        var services = f.App.Services;
        var settings = services.GetRequiredService<InventorySettings>();
        var catalogSettings = services.GetRequiredService<CatalogSettings>();
        var orgSettings = services.GetRequiredService<OrganizationSettings>();
        var previous = (settings.Enabled, settings.StockOperationsEnabled, settings.ManufacturingEnabled, catalogSettings.Enabled, orgSettings.Enabled);
        settings.Enabled = settings.StockOperationsEnabled = settings.ManufacturingEnabled = catalogSettings.Enabled = orgSettings.Enabled = true;
        try
        {
            var production = services.GetRequiredService<IManufacturingStore>();
            var inventory = services.GetRequiredService<IInventoryStore>();
            var ops = services.GetRequiredService<IStockOperations>();
            var catalog = services.GetRequiredService<ICatalogStore>();
            var org = services.GetRequiredService<IOrganizationStore>();
            var owner = (await f.Login()).Data;
            var member = owner.Selected!;
            var plant = await org.SaveOutletAsync(owner, null, new("P107-PLANT", "Production Plant", null, null, null, true, 0, "Fixture"), "test", default);
            var other = await org.SaveOutletAsync(owner, null, new("P107-OTHER", "Other Outlet", null, null, null, true, 0, "Fixture"), "test", default);
            var warehouse = Assert.Single(await org.WarehousesAsync(owner, plant.Id, default));
            var outside = Assert.Single(await org.WarehousesAsync(owner, other.Id, default));
            await catalog.InitializeUnitsAsync(owner, "test", default);
            var units = await catalog.UnitsAsync(owner, default);
            var litre = units.Single(x => x.Code == "L").Id;
            var piece = units.Single(x => x.Code == "EA").Id;

            Task<ProductDetail> Product(string code, string name, string kind, ulong unit, bool manufacture, bool tracked) =>
                catalog.SaveProductAsync(owner, null, new(code, name, null, null, unit, kind, false, false, manufacture,
                    tracked ? "LOT" : "NONE", tracked, true, 0, "Fixture", [new(null, unit, 1, null, null, false, false, true, 0, [])]), "test", default);
            var raw = await Product("P107-RAW", "Synthetic raw oil", "RAW", litre, false, true);
            var bulk = await Product("P107-BULK", "Synthetic bulk oil", "INTERMEDIATE", litre, true, true);
            var bottle = await Product("P107-BOTTLE", "Synthetic bottle", "PACKAGING", piece, false, false);
            var finished = await Product("P107-FINISHED", "Synthetic bottled oil", "FINISHED", piece, true, true);
            var max = await Product("P107-LIMIT", "Synthetic overflow output", "FINISHED", piece, true, false);
            var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow,
                TimeZoneInfo.FindSystemTimeZoneById("Asia/Colombo")).DateTime);
            var expiry = today.AddDays(10);

            ProductionMaterial Input(ProductDetail p, decimal qty, ulong? bucket = null) =>
                new(p.Product.Id, p.Units[0].Id, p.Product.Version, p.Units[0].Version, qty, bucket);
            ProductionOutput Output(ProductDetail p, decimal qty, string? lot) =>
                new(p.Product.Id, p.Units[0].Id, p.Product.Version, p.Units[0].Version, qty, lot, lot is null ? null : expiry);
            ReceiptLine Seed(ProductDetail p, decimal qty, decimal cost, string? lot = null, DateOnly? expires = null, string condition = "AVAILABLE") =>
                new(p.Product.Id, p.Units[0].Id, p.Product.Version, p.Units[0].Version, qty, cost, cost == 0, condition,
                    lot, null, lot is null ? null : today.AddDays(-2), expires);
            ProductionInput Run(ProductionOutput output, params ProductionMaterial[] lines) =>
                new(Guid.NewGuid(), warehouse.Id, warehouse.Version, "LKR", today, "Synthetic production", null, lines, output);
            Task<IReadOnlyList<StockRow>> Stock(ProductDetail p) =>
                inventory.StockAsync(owner, new(warehouse.Id, p.Product.Id, null, null, null, null), default);
            Task<PostedReceipt> Post(ProductionInput request) => production.PostProductionAsync(owner, request, "test", default);
            async Task<bool> Race(ProductionInput request)
            {
                try { await Post(request); return true; }
                catch (AppFailure) { return false; }
            }

            await f.Sql("""
                INSERT INTO lots(tenant_id,company_id,item_id,lot_code,tracking_mode,manufactured_on,expires_on,is_blocked)
                VALUES(@tenant,@company,@item,'P107-BLOCKED','LOT',@made,@expiry,1)
                """, ("tenant", member.TenantId), ("company", member.CompanyId), ("item", raw.Product.Id), ("made", today.AddDays(-2)), ("expiry", expiry));
            await inventory.PostAsync(owner, true, new(Guid.NewGuid(), warehouse.Id, warehouse.Version, "LKR", today, null, null, null,
                [Seed(raw, 12, 500, "P107-EARLY", today.AddDays(2)), Seed(raw, 28, 500, "P107-LATER", expiry),
                Seed(raw, 3, 500, "P107-EXPIRED", today.AddDays(-1), "HOLD"), Seed(raw, 3, 500, "P107-BLOCKED", expiry, "HOLD"),
                Seed(bottle, 40, 60), Seed(max, 999999999999999m, 0)]), "test", default);

            var staffUser = await org.CreateStaffAsync(owner, new(Guid.NewGuid().ToString("N") + "@example.invalid", "Synthetic Production Staff",
                [plant.Id], "Fixture"), "test", default);
            var login = await f.Service.LoginAsync(staffUser.Email, staffUser.TemporaryPassword, "test", default);
            var staff = (await f.Service.ChangePasswordAsync(login.Data, staffUser.TemporaryPassword, SessionSecrets.Create(), "test", default)).Data;

            var bulkRequest = Run(Output(bulk, 20, "P107-BULK-01"), Input(raw, 5), Input(raw, 15));
            var preview = await production.PreviewProductionAsync(owner, bulkRequest, default);
            Assert.Equal(10000m, preview.TotalCost);
            Assert.Equal(3, preview.Materials.Count);
            Assert.Equal(12m, preview.Materials.Where(x => x.Lot == "P107-EARLY").Sum(x => x.BaseQuantity));
            Assert.DoesNotContain("CarriedValue", JsonSerializer.Serialize(await production.PreviewProductionAsync(staff, bulkRequest, default)));
            Assert.DoesNotContain("TotalCost", JsonSerializer.Serialize(await production.PreviewProductionAsync(staff, bulkRequest, default)));
            var root = await production.PostProductionAsync(staff, bulkRequest, "test", default);
            Assert.Equal(root, await production.PostProductionAsync(staff, bulkRequest, "test", default));
            await Assert.ThrowsAsync<AppFailure>(() => production.PostProductionAsync(staff, bulkRequest with { Notes = "Changed" }, "test", default));
            await Assert.ThrowsAsync<AppFailure>(() => Post(bulkRequest with { OperationId = Guid.NewGuid() }));
            Assert.Equal(20m, (await Stock(raw)).Where(x => x.Condition == "AVAILABLE").Sum(x => x.OnHand));
            Assert.Equal(10000m, Assert.Single(await Stock(bulk)).OperationalValue);
            Assert.DoesNotContain("TotalCost", JsonSerializer.Serialize(await production.ProductionAsync(staff, root.Id, default)));
            Assert.DoesNotContain("OutputBaseUnitCost", JsonSerializer.Serialize(await production.ProductionRunsAsync(staff, null, null, null, null, default)));

            var packagingRequest = Run(Output(finished, 20, "P107-PACK-01"), Input(bulk, 20), Input(bottle, 20));
            var packaged = await Post(packagingRequest);
            var detail = await production.ProductionAsync(owner, packaged.Id, default);
            Assert.Equal(11200m, detail.Run.TotalCost);
            Assert.Equal(560m, detail.Run.OutputBaseUnitCost);
            Assert.Equal(11200m, Assert.Single(await Stock(finished)).OperationalValue);
            Assert.Equal(0m, Assert.Single(await Stock(bulk)).OnHand);
            Assert.Equal(20m, Assert.Single(await Stock(bottle)).OnHand);
            var intermediateLot = detail.Materials.Single(x => x.Sku == bulk.Product.Sku).LotId;
            Assert.Equal(root.Id, Assert.Single(await production.ProductionRunsAsync(owner, warehouse.Id, null, intermediateLot, null, default)).Id);
            Assert.Equal(packaged.Id, Assert.Single(await production.ProductionRunsAsync(owner, warehouse.Id, intermediateLot, null, null, default)).Id);
            var system = detail.Materials.Single(x => x.Sku == bottle.Product.Sku).LotId;
            Assert.Empty(await production.ProductionRunsAsync(owner, warehouse.Id, system, null, null, default));

            var rejected = Run(Output(finished, 1, "P107-REJECTED"), Input(raw, 1));
            await Assert.ThrowsAsync<AppFailure>(() => production.PostProductionAsync(staff,
                rejected with { WarehouseId = outside.Id, WarehouseVersion = outside.Version }, "test", default));
            var foreign = (await f.Login(f.Shared.MembershipId)).Data;
            await Assert.ThrowsAsync<AppFailure>(() => production.ProductionAsync(foreign, packaged.Id, default));
            await Assert.ThrowsAsync<AppFailure>(() => production.ReconcileProductionAsync(staff, default));
            await Assert.ThrowsAsync<AppFailure>(() => Post(rejected with { Output = rejected.Output with { LotCode = null } }));
            await Assert.ThrowsAsync<AppFailure>(() => Post(rejected with { Output = rejected.Output with { ExpiresOn = null } }));
            await Assert.ThrowsAsync<AppFailure>(() => Post(rejected with { Output = rejected.Output with { Quantity = 0 } }));
            await Assert.ThrowsAsync<AppFailure>(() => Post(rejected with { Materials = [] }));
            await Assert.ThrowsAsync<AppFailure>(() => Post(rejected with { Materials = [Input(finished, 1)] }));
            foreach (var row in (await Stock(raw)).Where(x => x.Lot is "P107-EXPIRED" or "P107-BLOCKED"))
                await Assert.ThrowsAsync<AppFailure>(() => Post(rejected with { Materials = [Input(raw, 1, row.Id)] }));

            var beforeRollback = await Stock(raw);
            var entries = await f.Sql("SELECT COUNT(*) FROM stock_entries WHERE tenant_id=@tenant", ("tenant", member.TenantId));
            await Assert.ThrowsAsync<AppFailure>(() => Post(Run(Output(max, 1, null), Input(raw, 1))));
            Assert.Equal(beforeRollback.ToArray(), (await Stock(raw)).ToArray());
            Assert.Equal(entries, await f.Sql("SELECT COUNT(*) FROM stock_entries WHERE tenant_id=@tenant", ("tenant", member.TenantId)));
            Assert.Equal(2, (await production.ProductionRunsAsync(owner, null, null, null, null, default)).Count);

            var reservedInput = Input(raw, 15);
            var transfer = await ops.RequestAsync(owner, new(Guid.NewGuid(), warehouse.Id, outside.Id, null, null,
                [new(reservedInput.ItemId, reservedInput.ItemUnitId, reservedInput.ItemVersion, reservedInput.UnitVersion, reservedInput.Quantity)]), "test", default);
            await ops.TransferStepAsync(owner, transfer.Id, "confirm", new(Guid.NewGuid(), null), "test", default);
            await Assert.ThrowsAsync<AppFailure>(() => Post(rejected with { Materials = [Input(raw, 3), Input(raw, 3)] }));
            var outcomes = await Task.WhenAll(
                Race(Run(Output(finished, 1, "P107-RACE-A"), Input(raw, 5))),
                Race(Run(Output(finished, 1, "P107-RACE-B"), Input(raw, 5))));
            Assert.Single(outcomes, x => x);
            Assert.Equal(15m, Assert.Single(await Stock(raw), x => x.Lot == "P107-LATER").Reserved);

            var count = await ops.StartCountAsync(owner, new(Guid.NewGuid(), warehouse.Id), "test", default);
            await Assert.ThrowsAsync<AppFailure>(() => Post(rejected));
            var snapshot = await ops.CountAsync(owner, count.Id, default);
            await ops.FinishCountAsync(owner, count.Id, true, new(Guid.NewGuid(), snapshot.Count.Version, "Fixture", "LKR", null), "test", default);
            await ops.TransferStepAsync(owner, transfer.Id, "cancel", new(Guid.NewGuid(), "Fixture"), "test", default);
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("UPDATE production_events SET production_reference='changed' WHERE document_id=@id", ("id", packaged.Id)));
            Assert.Empty(await production.ReconcileProductionAsync(owner, default));
        }
        finally
        {
            (settings.Enabled, settings.StockOperationsEnabled, settings.ManufacturingEnabled, catalogSettings.Enabled, orgSettings.Enabled) = previous;
        }
    }
}
