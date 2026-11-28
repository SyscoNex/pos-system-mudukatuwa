using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Conex360.Application.Catalog;
using Conex360.Application.Identity;
using Conex360.Application.Organization;
using Conex360.Domain.Catalog;
using Microsoft.Extensions.DependencyInjection;
using MySqlConnector;

namespace Conex360.IntegrationTests;

public sealed partial class MySqlIdentityTests
{
    [MySqlFact]
    public async Task CatalogPrecisionIsolationDefaultsBarcodesAndSuppliers()
    {
        var setting = f.App.Services.GetRequiredService<CatalogSettings>(); setting.Enabled = true;
        var orgSetting = f.App.Services.GetRequiredService<OrganizationSettings>(); var previousOrg = orgSetting.Enabled; orgSetting.Enabled = true;
        try
        {
            var store = f.App.Services.GetRequiredService<ICatalogStore>(); var admin = (await f.Login()).Data;
            await store.InitializeUnitsAsync(admin, "test", default); await store.InitializeUnitsAsync(admin, "test", default);
            var units = await store.UnitsAsync(admin, default); Assert.Equal(9, units.Count); var piece = units.Single(x => x.Code == "EA"); var carton = units.Single(x => x.Code == "CARTON");
            var category = await store.SaveCategoryAsync(admin, null, new("PACK", "Packaging", null, null, true, 0, "Create category"), "test", default);
            var child = await store.SaveCategoryAsync(admin, null, new("BOTTLES", "Bottles", null, category.Id, true, 0, "Create child"), "test", default);
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveCategoryAsync(admin, category.Id, new(category.Code, category.Name, null, child.Id, true, category.Version, "Reject cycle"), "test", default));
            var request = new ProductEdit("BOTTLE-TEST", "Empty bottle", null, child.Id, piece.Id, "PACKAGING", true, true, false, "NONE", false, true, 0, "Create product", [
                new(null,piece.Id,1,42.123456m,0,true,true,true,0,[new(null,"0000123456789",true,0)]),
                new(null,carton.Id,24,null,240,false,false,true,0,[new(null,"CARTON-0001",true,0)])]);
            var product = await store.SaveProductAsync(admin, null, request, "test", default);
            Assert.True(product.CanReadPurchasePrices);
            Assert.NotNull(await f.Sql("SELECT currency_locked_at FROM companies WHERE tenant_id=@tenant AND id=@company", ("tenant", admin.Selected!.TenantId), ("company", admin.Selected.CompanyId)));
            var evidence = Convert.ToString(await f.Sql("SELECT details_json FROM audit_events WHERE tenant_id=@tenant AND entity_id=@item AND action='PRODUCT_SAVED' ORDER BY id DESC LIMIT 1", ("tenant", admin.Selected.TenantId), ("item", product.Product.Id)))!;
            Assert.Contains("42.123456", evidence); Assert.Contains("0000123456789", evidence);
            Assert.Equal(48m, await store.ConvertAsync(admin, product.Product.Id, new(product.Units.Single(x => x.UnitId == carton.Id).Id, 2), default));
            await Assert.ThrowsAsync<AppFailure>(() => store.ConvertAsync(admin, product.Product.Id, new(product.Units[0].Id, 0.5m), default));
            Assert.Equal(product.Product.Id, (await store.BarcodeAsync(admin, "0000123456789", default)).Product.Id);
            await Assert.ThrowsAsync<AppFailure>(() => store.BarcodeAsync(admin, "123456789", default));
            var audit = Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM audit_events WHERE tenant_id=@tenant", ("tenant", admin.Selected!.TenantId)));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveProductAsync(admin, null, request with { Sku = "ROLLBACK-PRODUCT" }, "test", default));
            Assert.Equal(0UL, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM items WHERE tenant_id=@tenant AND sku='ROLLBACK-PRODUCT'", ("tenant", admin.Selected.TenantId))));
            Assert.Equal(audit, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM audit_events WHERE tenant_id=@tenant", ("tenant", admin.Selected.TenantId))));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveProductAsync(admin, null, request with { Sku = "BAD-EXPIRY", ExpiryRequired = true }, "test", default));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveProductAsync(admin, null, request with { Sku = "BAD-PRICE", Units = [request.Units[0] with { PurchasePrice = 1.1234567m }] }, "test", default));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveProductAsync(admin, null, request with { Sku = "BAD-DEFAULT", Units = [request.Units[0] with { IsSaleDefault = false }] }, "test", default));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveUnitAsync(admin, piece.Id, new(piece.Code, piece.Name, piece.Dimension, piece.IsDiscrete, false, piece.Version, "Reject used-unit deactivation"), "test", default));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveCategoryAsync(admin, child.Id, new(child.Code, child.Name, null, child.ParentId, false, child.Version, "Reject used category deactivation"), "test", default));
            var edited = request with { ExpectedVersion = product.Product.Version, Name = "Bottle revised", Units = product.Units.Select(u => new ItemUnitEdit(u.Id, u.UnitId, u.ToBaseFactor, u.PurchasePrice, u.SellingPrice, u.IsPurchaseDefault, u.IsSaleDefault, u.IsActive, u.Version, product.Barcodes.Where(b => b.ItemUnitId == u.Id).Select(b => new BarcodeEdit(b.Id, b.Value, b.IsActive, b.Version)).ToArray())).ToArray() };
            var revised = await store.SaveProductAsync(admin, product.Product.Id, edited, "test", default);
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveProductAsync(admin, product.Product.Id, edited, "test", default));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveProductAsync(admin, product.Product.Id, edited with { ExpectedVersion = revised.Product.Version }, "test", default));
            var tenantB = Convert.ToUInt64(await f.Sql("SELECT tenant_id FROM tenant_memberships WHERE id=@id", ("id", f.B.MembershipId)));
            var companyB = Convert.ToUInt64(await f.Sql("SELECT id FROM companies WHERE tenant_id=@tenant", ("tenant", tenantB)));
            await f.Sql("INSERT INTO units(tenant_id,company_id,code,name,dimension,is_discrete,created_at,updated_at) VALUES(@tenant,@company,'EA','Other tenant piece','COUNT',1,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))", ("tenant", tenantB), ("company", companyB));
            var foreignUnit = Convert.ToUInt64(await f.Sql("SELECT id FROM units WHERE tenant_id=@tenant AND code='EA'", ("tenant", tenantB)));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveProductAsync(admin, null, request with { Sku = "FOREIGN", BaseUnitId = foreignUnit }, "test", default));
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("INSERT INTO item_categories(tenant_id,company_id,code,name,parent_id,created_at,updated_at) VALUES(@tenant,@company,'BAD-PARENT','Invalid relationship',@parent,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))", ("tenant", tenantB), ("company", companyB), ("parent", category.Id)));
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("INSERT INTO item_barcodes(tenant_id,company_id,item_id,item_unit_id,barcode,created_at,updated_at) VALUES(@tenant,@company,@item,@unit,'BAD-LINK',UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))", ("tenant", tenantB), ("company", companyB), ("item", product.Product.Id), ("unit", product.Units[0].Id)));
            var supplier = await store.SaveSupplierAsync(admin, null, new("COCO", "Synthetic supplier", "+94 11 000 0000", "supplier@example.invalid", null, "Delivery contact", "INTERNAL_ONLY", true, 0, "Create supplier"), "test", default);
            audit = Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM audit_events WHERE tenant_id=@tenant", ("tenant", admin.Selected.TenantId)));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveSupplierAsync(admin, null, new("COCO", "Duplicate supplier", null, null, null, null, null, true, 0, "Duplicate rollback"), "test", default));
            Assert.Equal(audit, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM audit_events WHERE tenant_id=@tenant", ("tenant", admin.Selected.TenantId))));
            await f.Sql("UPDATE tenant_memberships SET role='STAFF',row_version=row_version+1 WHERE id=@id", ("id", admin.Selected.Id));
            try
            {
                var staleRole = await store.ProductAsync(admin, product.Product.Id, default);
                Assert.False(staleRole.CanReadPurchasePrices); Assert.All(staleRole.Units, u => Assert.Null(u.PurchasePrice));
                Assert.All(await store.SuppliersAsync(admin, default), p => Assert.Null(p.Notes));
            }
            finally { await f.Sql("UPDATE tenant_memberships SET role='ADMINISTRATOR',row_version=row_version+1 WHERE id=@id", ("id", admin.Selected.Id)); }
            var org = f.App.Services.GetRequiredService<IOrganizationStore>(); var staff = await org.CreateStaffAsync(admin, new(Guid.NewGuid().ToString("N") + "@example.invalid", "Catalogue Staff", [], "Read-only staff"), "test", default);
            using var client = f.App.CreateClient(); Assert.Equal(HttpStatusCode.OK, (await MySqlFixture.Send(client, HttpMethod.Post, "/api/v1/auth/login", new { email = staff.Email, password = staff.TemporaryPassword })).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await MySqlFixture.Send(client, HttpMethod.Post, "/api/v1/auth/password", new { currentPassword = staff.TemporaryPassword, newPassword = SessionSecrets.Create() })).StatusCode); client.DefaultRequestHeaders.Add("X-Conex360-Context", "1");
            var detail = await client.GetAsync("/api/v1/catalog/products/" + product.Product.Id); Assert.Equal(HttpStatusCode.OK, detail.StatusCode); var json = await detail.Content.ReadAsStringAsync(); Assert.DoesNotContain("purchasePrice", json); Assert.DoesNotContain("42.123456", json); Assert.Contains("sellingPrice", json);
            var lookup = await client.GetFromJsonAsync<JsonElement>("/api/v1/catalog/barcode?value=0000123456789"); Assert.Equal(product.Units[0].Id.ToString(), lookup.GetProperty("matchedItemUnitId").GetString());
            Assert.DoesNotContain("INTERNAL_ONLY", await client.GetStringAsync("/api/v1/catalog/suppliers"));
            Assert.Equal(HttpStatusCode.Forbidden, (await MySqlFixture.Send(client, HttpMethod.Post, "/api/v1/catalog/products", request)).StatusCode);
            Assert.Empty((await client.GetFromJsonAsync<JsonElement>("/api/v1/organization/outlets")).EnumerateArray());
            var inactive = await store.SaveProductAsync(admin, product.Product.Id, edited with { ExpectedVersion = revised.Product.Version, IsActive = false, Units = revised.Units.Select(u => new ItemUnitEdit(u.Id, u.UnitId, u.ToBaseFactor, u.PurchasePrice, u.SellingPrice, u.IsPurchaseDefault, u.IsSaleDefault, u.IsActive, u.Version, revised.Barcodes.Where(b => b.ItemUnitId == u.Id).Select(b => new BarcodeEdit(b.Id, b.Value, b.IsActive, b.Version)).ToArray())).ToArray() }, "test", default);
            Assert.False(inactive.Product.IsActive); Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/api/v1/catalog/products/" + product.Product.Id)).StatusCode);
            var disabled = await store.SaveSupplierAsync(admin, supplier.Id, new(supplier.Code, supplier.Name, null, null, null, null, null, false, supplier.Version, "Deactivate supplier"), "test", default); Assert.False(disabled.IsActive);
            Assert.DoesNotContain(supplier.Code, await client.GetStringAsync("/api/v1/catalog/suppliers"));
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("DELETE FROM items WHERE id=0"));
        }
        finally { setting.Enabled = false; orgSetting.Enabled = previousOrg; }
    }
}
