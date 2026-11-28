using Conex360.Application.Catalog;
using Conex360.Domain.Identity;

namespace Conex360.Api.Identity;

public static class CatalogEndpoints
{
    // Explicit DTO allowlist: Staff never receives purchase-price or supplier-note fields.
    private static object View(ProductDetail detail) => new
    {
        detail.Product,
        detail.CurrencyCode,
        units = detail.Units.Select(u => detail.CanReadPurchasePrices ? (object)new { u.Id, u.UnitId, u.ToBaseFactor, u.PurchasePrice, u.SellingPrice, u.IsPurchaseDefault, u.IsSaleDefault, u.IsActive, u.Version }
            : new { u.Id, u.UnitId, u.ToBaseFactor, u.SellingPrice, u.IsPurchaseDefault, u.IsSaleDefault, u.IsActive, u.Version }),
        detail.Barcodes
    };
    public static void MapCatalog(this WebApplication app)
    {
        var g = app.MapGroup("/api/v1/catalog").RequireAuthorization("Business").AddEndpointFilter<CsrfFilter>().AddEndpointFilter<BusinessContextFilter>();
        g.MapGet("/units", async (HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(await store.UnitsAsync(IdentitySetup.Session(h), ct)));
        g.MapPost("/units", async (UnitEdit input, HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(await store.SaveUnitAsync(IdentitySetup.Session(h), null, input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        g.MapPut("/units/{id}", async (ulong id, UnitEdit input, HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(await store.SaveUnitAsync(IdentitySetup.Session(h), id, input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        g.MapPost("/units/defaults", async (HttpContext h, ICatalogStore store, CancellationToken ct) => { await store.InitializeUnitsAsync(IdentitySetup.Session(h), h.TraceIdentifier, ct); return Results.NoContent(); }).RequireAuthorization("Administrator");
        g.MapGet("/categories", async (HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(await store.CategoriesAsync(IdentitySetup.Session(h), ct)));
        g.MapPost("/categories", async (CategoryEdit input, HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(await store.SaveCategoryAsync(IdentitySetup.Session(h), null, input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        g.MapPut("/categories/{id}", async (ulong id, CategoryEdit input, HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(await store.SaveCategoryAsync(IdentitySetup.Session(h), id, input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        g.MapGet("/products", async (HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(await store.ProductsAsync(IdentitySetup.Session(h), ct)));
        g.MapGet("/products/{id}", async (ulong id, HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(View(await store.ProductAsync(IdentitySetup.Session(h), id, ct))));
        g.MapPost("/products", async (ProductEdit input, HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(View(await store.SaveProductAsync(IdentitySetup.Session(h), null, input, h.TraceIdentifier, ct)))).RequireAuthorization("Administrator");
        g.MapPut("/products/{id}", async (ulong id, ProductEdit input, HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(View(await store.SaveProductAsync(IdentitySetup.Session(h), id, input, h.TraceIdentifier, ct)))).RequireAuthorization("Administrator");
        g.MapGet("/barcode", async (string value, HttpContext h, ICatalogStore store, CancellationToken ct) =>
        {
            var detail = await store.BarcodeAsync(IdentitySetup.Session(h), value, ct);
            return Results.Ok(new { matchedItemUnitId = detail.Barcodes.Single(b => b.IsActive && string.Equals(b.Value, value, StringComparison.Ordinal)).ItemUnitId, detail = View(detail) });
        });
        g.MapPost("/products/{id}/convert", async (ulong id, ConversionInput input, HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(new { baseQuantity = await store.ConvertAsync(IdentitySetup.Session(h), id, input, ct) }));
        g.MapGet("/suppliers", async (HttpContext h, ICatalogStore store, CancellationToken ct) =>
        {
            var all = await store.SuppliersAsync(IdentitySetup.Session(h), ct);
            return Results.Ok(IdentitySetup.Session(h).Selected!.Role == MembershipRoles.Administrator ? (object)all : all.Select(p => new { p.Id, p.Code, p.Name, p.Phone, p.Email, p.Address, p.ContactPerson, p.IsActive, p.Version }));
        });
        g.MapPost("/suppliers", async (SupplierEdit input, HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(await store.SaveSupplierAsync(IdentitySetup.Session(h), null, input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        g.MapPut("/suppliers/{id}", async (ulong id, SupplierEdit input, HttpContext h, ICatalogStore store, CancellationToken ct) => Results.Ok(await store.SaveSupplierAsync(IdentitySetup.Session(h), id, input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        if (!app.Services.GetRequiredService<CatalogSettings>().Enabled) g.ExcludeFromDescription();
    }
}
