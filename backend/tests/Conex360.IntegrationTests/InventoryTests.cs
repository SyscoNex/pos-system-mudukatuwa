using Conex360.Application.Catalog;
using Conex360.Application.Identity;
using Conex360.Application.Inventory;
using Conex360.Application.Organization;
using Conex360.Domain.Identity;
using Microsoft.Extensions.DependencyInjection;
using MySqlConnector;

namespace Conex360.IntegrationTests;

public sealed class InventoryMySqlFactAttribute : FactAttribute
{
    public InventoryMySqlFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("CONEX360_MYSQL_APPROVED") != "1" ||
            Environment.GetEnvironmentVariable("CONEX360_INVENTORY_MYSQL_APPROVED") != "1")
            Skip = "Requires separately approved P1-05 migrations and synthetic MySQL target.";
    }
}

public sealed partial class MySqlIdentityTests
{
    [InventoryMySqlFact]
    public async Task InventoryPostingReplaysAndReconcilesWithScopedVisibility()
    {
        var services = f.App.Services;
        var inventorySettings = services.GetRequiredService<InventorySettings>();
        var catalogSettings = services.GetRequiredService<CatalogSettings>();
        var orgSettings = services.GetRequiredService<OrganizationSettings>();
        var flags = (inventorySettings.Enabled, catalogSettings.Enabled, orgSettings.Enabled);
        inventorySettings.Enabled = catalogSettings.Enabled = orgSettings.Enabled = true;
        try
        {
            var inv = services.GetRequiredService<IInventoryStore>();
            var catalogue = services.GetRequiredService<ICatalogStore>();
            var org = services.GetRequiredService<IOrganizationStore>();
            var owner = (await f.Login()).Data;
            var tenant = owner.Selected!.TenantId;
            var outlet = await org.SaveOutletAsync(owner, null, new("RECEIVING", "Inventory Test", null, null, null, true, 0, "Synthetic test"), "test", default);
            var warehouse = Assert.Single(await org.WarehousesAsync(owner, outlet.Id, default));
            var otherOutlet = await org.SaveOutletAsync(owner, null, new("RECEIVING-OTHER", "Other Inventory Test", null, null, null, true, 0, "Synthetic test"), "test", default);
            var otherWarehouse = Assert.Single(await org.WarehousesAsync(owner, otherOutlet.Id, default));
            await catalogue.InitializeUnitsAsync(owner, "test", default);
            var units = await catalogue.UnitsAsync(owner, default);
            var piece = units.Single(u => u.Code == "EA");
            var carton = units.Single(u => u.Code == "CARTON");
            var edit = new ProductEdit("INV-LOT", "Inventory Test Product", null, null, piece.Id, "RAW", true, false, false, "LOT", true, true,
                0, "Synthetic test", [new(null, piece.Id, 1, null, null, true, false, true, 0, []), new(null, carton.Id, 24, null, null, false, false, true, 0, [])]);
            var product = await catalogue.SaveProductAsync(owner, null, edit, "test", default);
            var baseUnit = product.Units.Single(u => u.UnitId == piece.Id);
            var alt = product.Units.Single(u => u.UnitId == carton.Id);
            var supplier = await catalogue.SaveSupplierAsync(owner, null,
                new("INV-SUP", "Inventory Test Supplier", null, null, null, null, null, true, 0, "Synthetic test"), "test", default);
            var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("Asia/Colombo")).DateTime);
            var line = new ReceiptLine(product.Product.Id, alt.Id, product.Product.Version, alt.Version, 1, 1, false, "AVAILABLE", "TEST", null, today, today.AddDays(1));
            var opening = new ReceiptInput(Guid.NewGuid(), warehouse.Id, warehouse.Version, "LKR", today, null, null, null, [line]);
            var opened = await inv.PostAsync(owner, true, opening, "test", default);
            Assert.StartsWith("OPEN-", opened.Number);
            await Assert.ThrowsAsync<AppFailure>(() => inv.PostAsync(owner, true, opening with { OperationId = Guid.NewGuid() }, "test", default));

            var held = line with { LotCode = "EXPIRED", Condition = "HOLD", ManufacturedOn = today.AddDays(-2), ExpiresOn = today.AddDays(-1) };
            var receipt = opening with { OperationId = Guid.NewGuid(), SupplierId = supplier.Id, Lines = [line, held] };
            await Assert.ThrowsAsync<AppFailure>(() => inv.PreviewAsync(owner, false, receipt with { Lines = [held with { Condition = "AVAILABLE" }] }, default));
            await Assert.ThrowsAsync<AppFailure>(() => inv.PreviewAsync(owner, false, receipt with { Lines = [line with { ExpiresOn = null }] }, default));
            await Assert.ThrowsAsync<AppFailure>(() => inv.PreviewAsync(owner, false, receipt with { Lines = [line with { ExpiresOn = today }] }, default));
            var same = await Task.WhenAll(inv.PostAsync(owner, false, receipt, "test", default), inv.PostAsync(owner, false, receipt, "test", default));
            Assert.Equal(same[0], same[1]);
            await Assert.ThrowsAsync<AppFailure>(() => inv.PostAsync(owner, false, receipt with { Notes = "Changed" }, "test", default));

            var staff = await org.CreateStaffAsync(owner, new(Guid.NewGuid().ToString("N") + "@example.invalid", "Inventory Test Staff", [outlet.Id], "Synthetic test"), "test", default);
            var initial = await f.Service.LoginAsync(staff.Email, staff.TemporaryPassword, "test", default);
            var staffSession = (await f.Service.ChangePasswordAsync(initial.Data, staff.TemporaryPassword, SessionSecrets.Create(), "test", default)).Data;
            await Task.WhenAll(
                inv.PostAsync(owner, false, receipt with { OperationId = Guid.NewGuid(), Lines = [line] }, "test", default),
                inv.PostAsync(staffSession, false, receipt with { OperationId = Guid.NewGuid(), Lines = [line] }, "test", default));
            var query = new StockQuery(warehouse.Id, product.Product.Id, null, null, null, null);
            var stock = await inv.StockAsync(owner, query, default);
            Assert.Contains(stock, x => x.Lot == "TEST" && x.OnHand == 96 && x.OperationalValue == 4 && x.Available == 96);
            Assert.Contains(stock, x => x.Lot == "EXPIRED" && x.OnHand == 24 && x.Available == 0 && x.Expired);
            Assert.Empty(await inv.ReconcileAsync(owner, warehouse.Id, null, default));
            Assert.All(await inv.StockAsync(staffSession, query, default), x => { Assert.Null(x.OperationalValue); Assert.Null(x.AverageCost); });
            Assert.All((await inv.DocumentAsync(staffSession, same[0].Id, default)).Lines, x => Assert.Null(x.EnteredUnitCost));
            await Assert.ThrowsAsync<AppFailure>(() => inv.PreviewAsync(staffSession, false, receipt with { WarehouseId = otherWarehouse.Id, WarehouseVersion = otherWarehouse.Version }, default));
            var foreign = (await f.Login(f.Shared.MembershipId)).Data;
            await Assert.ThrowsAsync<AppFailure>(() => inv.DocumentAsync(foreign, same[0].Id, default));

            var documents = await f.Sql("SELECT COUNT(*) FROM documents WHERE tenant_id=@tenant", ("tenant", tenant));
            var audit = await f.Sql("SELECT COUNT(*) FROM audit_events WHERE tenant_id=@tenant", ("tenant", tenant));
            // The first line appends to a different bucket. The second crosses the balance bound.
            var overflow = line with
            {
                ItemUnitId = baseUnit.Id,
                UnitVersion = baseUnit.Version,
                Quantity = 999999999999999m,
                EnteredUnitCost = 0,
                ConfirmZeroCost = true
            };
            var first = held with { Condition = "DAMAGED", LotCode = "A-ROLLBACK" };
            await Assert.ThrowsAsync<AppFailure>(() => inv.PostAsync(owner, false,
                receipt with { OperationId = Guid.NewGuid(), Lines = [first, overflow] }, "test", default));
            Assert.Equal(documents, await f.Sql("SELECT COUNT(*) FROM documents WHERE tenant_id=@tenant", ("tenant", tenant)));
            Assert.Equal(audit, await f.Sql("SELECT COUNT(*) FROM audit_events WHERE tenant_id=@tenant", ("tenant", tenant)));
            Assert.Equal(stock, await inv.StockAsync(owner, query, default));
            Assert.Empty(await inv.ReconcileAsync(owner, warehouse.Id, null, default));
            Assert.Equal(0UL, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM lots WHERE tenant_id=@tenant AND lot_code='A-ROLLBACK'", ("tenant", tenant))));

            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("UPDATE documents SET notes='rewrite' WHERE id=@id", ("id", same[0].Id)));
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("DELETE FROM stock_entries WHERE tenant_id=@tenant", ("tenant", tenant)));
            await Assert.ThrowsAsync<AppFailure>(() => org.SaveOutletAsync(owner, outlet.Id,
                new(outlet.Code, outlet.Name, null, null, null, false, outlet.Version, "Physical stock"), "test", default));
            var updates = product.Units.Select(u => new ItemUnitEdit(u.Id, u.UnitId, u.ToBaseFactor, null, null,
                u.IsPurchaseDefault, u.IsSaleDefault, true, u.Version, [])).ToArray();
            await Assert.ThrowsAsync<AppFailure>(() => catalogue.SaveProductAsync(owner, product.Product.Id,
                edit with { TrackingMode = "NONE", ExpiryRequired = false, ExpectedVersion = product.Product.Version, Units = updates }, "test", default));
        }
        finally
        {
            (inventorySettings.Enabled, catalogSettings.Enabled, orgSettings.Enabled) = flags;
        }
    }
}
