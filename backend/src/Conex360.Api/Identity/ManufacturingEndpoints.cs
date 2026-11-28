using Conex360.Application.Inventory;

namespace Conex360.Api.Identity;

public static class ManufacturingEndpoints
{
    public static void MapManufacturing(this RouteGroupBuilder inventory, bool enabled)
    {
        var g = inventory.MapGroup("/manufacturing");
        g.MapGet("/runs", (ulong? warehouseId, ulong? inputLot, ulong? outputLot, ulong? before, HttpContext h,
            IManufacturingStore store, CancellationToken ct) =>
            store.ProductionRunsAsync(IdentitySetup.Session(h), warehouseId, inputLot, outputLot, before, ct));
        g.MapGet("/runs/{id}", (ulong id, HttpContext h, IManufacturingStore store, CancellationToken ct) =>
            store.ProductionAsync(IdentitySetup.Session(h), id, ct));
        g.MapPost("/preview", (ProductionInput input, HttpContext h, IManufacturingStore store, CancellationToken ct) =>
            store.PreviewProductionAsync(IdentitySetup.Session(h), input, ct));
        g.MapPost("/runs", (ProductionInput input, HttpContext h, IManufacturingStore store, CancellationToken ct) =>
            store.PostProductionAsync(IdentitySetup.Session(h), input, h.TraceIdentifier, ct));
        g.MapGet("/reconcile", (HttpContext h, IManufacturingStore store, CancellationToken ct) =>
            store.ReconcileProductionAsync(IdentitySetup.Session(h), ct)).RequireAuthorization("Administrator");
        if (!enabled) g.ExcludeFromDescription();
    }
}
