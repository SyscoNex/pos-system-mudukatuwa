using Conex360.Application.Inventory;

namespace Conex360.Api.Identity;

public static class InventoryEndpoints
{
    public static void MapInventory(this WebApplication app)
    {
        var group = app.MapGroup("/api/v1/inventory").RequireAuthorization("Business")
            .AddEndpointFilter<CsrfFilter>().AddEndpointFilter<BusinessContextFilter>();
        group.MapGet("/warehouses", (HttpContext h, IInventoryStore store, CancellationToken ct) =>
            store.WarehousesAsync(IdentitySetup.Session(h), ct));
        group.MapGet("/stock", (ulong? warehouseId, ulong? itemId, ulong? categoryId, string? batch, string? expiry,
            ulong? after, HttpContext h, IInventoryStore store, CancellationToken ct) =>
            store.StockAsync(IdentitySetup.Session(h), new(warehouseId, itemId, categoryId, batch, expiry, after), ct));
        group.MapGet("/movements", (ulong? warehouseId, ulong? before, HttpContext h, IInventoryStore store, CancellationToken ct) =>
            store.MovementsAsync(IdentitySetup.Session(h), warehouseId, before, ct));
        group.MapGet("/documents", (ulong? warehouseId, string? type, ulong? before, HttpContext h, IInventoryStore store, CancellationToken ct) =>
            store.DocumentsAsync(IdentitySetup.Session(h), warehouseId, type, before, ct));
        group.MapGet("/documents/{id}", (ulong id, HttpContext h, IInventoryStore store, CancellationToken ct) =>
            store.DocumentAsync(IdentitySetup.Session(h), id, ct));
        group.MapGet("/reconcile", (ulong? warehouseId, ulong? after, HttpContext h, IInventoryStore store, CancellationToken ct) =>
            store.ReconcileAsync(IdentitySetup.Session(h), warehouseId, after, ct)).RequireAuthorization("Administrator");

        foreach (var opening in new[] { true, false })
        {
            var path = opening ? "/opening-stock" : "/goods-receipts";
            var preview = group.MapPost(path + "/preview", (ReceiptInput input, HttpContext h, IInventoryStore store, CancellationToken ct) =>
                store.PreviewAsync(IdentitySetup.Session(h), opening, input, ct));
            var post = group.MapPost(path, (ReceiptInput input, HttpContext h, IInventoryStore store, CancellationToken ct) =>
                store.PostAsync(IdentitySetup.Session(h), opening, input, h.TraceIdentifier, ct));
            if (opening)
            {
                preview.RequireAuthorization("Administrator");
                post.RequireAuthorization("Administrator");
            }
        }

        if (!app.Services.GetRequiredService<InventorySettings>().Enabled) group.ExcludeFromDescription();
        group.MapStockOperations(app.Services.GetRequiredService<InventorySettings>().StockOperationsEnabled);
    }
}
