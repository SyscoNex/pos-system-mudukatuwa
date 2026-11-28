using Conex360.Application.Inventory;

namespace Conex360.Api.Identity;

public static class StockOperationEndpoints
{
    public static void MapStockOperations(this RouteGroupBuilder inventory, bool enabled)
    {
        var g = inventory.MapGroup("/operations");
        g.MapGet("/transfer-warehouses", (HttpContext h, IStockOperations s, CancellationToken c) => s.TransferWarehousesAsync(IdentitySetup.Session(h), c));
        g.MapGet("/transfers", (ulong? before, HttpContext h, IStockOperations s, CancellationToken c) => s.TransfersAsync(IdentitySetup.Session(h), before, c));
        g.MapGet("/transfers/{id}", (ulong id, HttpContext h, IStockOperations s, CancellationToken c) => s.TransferAsync(IdentitySetup.Session(h), id, c));
        g.MapPost("/transfers", (TransferRequestInput input, HttpContext h, IStockOperations s, CancellationToken c) =>
            s.RequestAsync(IdentitySetup.Session(h), input, h.TraceIdentifier, c));
        foreach (var action in new[] { "confirm", "cancel" })
            g.MapPost("/transfers/{id}/" + action, (ulong id, StockStep input, HttpContext h, IStockOperations s, CancellationToken c) =>
                s.TransferStepAsync(IdentitySetup.Session(h), id, action, input, h.TraceIdentifier, c));
        foreach (var action in new[] { "dispatch", "receive", "loss", "return" })
        {
            var route = g.MapPost("/transfers/{id}/" + action, (ulong id, AllocationInput input, HttpContext h, IStockOperations s, CancellationToken c) =>
                s.AllocationAsync(IdentitySetup.Session(h), id, action, input, h.TraceIdentifier, c));
            if (action is "loss" or "return") route.RequireAuthorization("Administrator");
        }
        foreach (var waste in new[] { false, true })
            g.MapPost(waste ? "/waste" : "/adjustments", (StockChangeInput input, HttpContext h, IStockOperations s, CancellationToken c) =>
                s.ChangeAsync(IdentitySetup.Session(h), waste, input, h.TraceIdentifier, c)).RequireAuthorization("Administrator");

        g.MapGet("/counts", (ulong? before, HttpContext h, IStockOperations s, CancellationToken c) => s.CountsAsync(IdentitySetup.Session(h), before, c));
        g.MapGet("/counts/{id}", (ulong id, HttpContext h, IStockOperations s, CancellationToken c) => s.CountAsync(IdentitySetup.Session(h), id, c));
        g.MapPost("/counts", (CountStart input, HttpContext h, IStockOperations s, CancellationToken c) => s.StartCountAsync(IdentitySetup.Session(h), input, h.TraceIdentifier, c));
        g.MapPut("/counts/{id}", (ulong id, CountSave input, HttpContext h, IStockOperations s, CancellationToken c) =>
            s.SaveCountAsync(IdentitySetup.Session(h), id, input, h.TraceIdentifier, c));
        foreach (var cancel in new[] { false, true })
            g.MapPost("/counts/{id}/" + (cancel ? "cancel" : "complete"), (ulong id, CountFinish input, HttpContext h, IStockOperations s, CancellationToken c) =>
                s.FinishCountAsync(IdentitySetup.Session(h), id, cancel, input, h.TraceIdentifier, c)).RequireAuthorization("Administrator");

        g.MapGet("/reconcile", (HttpContext h, IStockOperations s, CancellationToken c) =>
            s.ReconcileOperationsAsync(IdentitySetup.Session(h), c)).RequireAuthorization("Administrator");
        if (!enabled) g.ExcludeFromDescription();
    }
}
