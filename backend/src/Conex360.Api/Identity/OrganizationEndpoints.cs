using Conex360.Application.Organization;

namespace Conex360.Api.Identity;

public sealed record OutletSelection(ulong? BranchId);
public static class OrganizationEndpoints
{
    public static void MapOrganization(this WebApplication app)
    {
        var group = app.MapGroup("/api/v1/organization").RequireAuthorization("Business").AddEndpointFilter<CsrfFilter>().AddEndpointFilter<BusinessContextFilter>();
        group.MapGet("/context", async (HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.ContextAsync(IdentitySetup.Session(h), ct)));
        group.MapPost("/context", async (OutletSelection input, HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.SelectOutletAsync(IdentitySetup.Session(h), input.BranchId, h.TraceIdentifier, ct)));
        group.MapGet("/outlets", async (HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.OutletsAsync(IdentitySetup.Session(h), ct)));
        group.MapPost("/outlets", async (OutletEdit input, HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.SaveOutletAsync(IdentitySetup.Session(h), null, input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        group.MapPut("/outlets/{id}", async (ulong id, OutletEdit input, HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.SaveOutletAsync(IdentitySetup.Session(h), id, input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        group.MapGet("/warehouses", async (ulong? branchId, HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.WarehousesAsync(IdentitySetup.Session(h), branchId, ct)));
        group.MapPost("/warehouses", async (WarehouseEdit input, HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.SaveWarehouseAsync(IdentitySetup.Session(h), null, input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        group.MapPut("/warehouses/{id}", async (ulong id, WarehouseEdit input, HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.SaveWarehouseAsync(IdentitySetup.Session(h), id, input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        group.MapGet("/warehouses/{id}/locations", async (ulong id, HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.LocationsAsync(IdentitySetup.Session(h), id, ct)));
        group.MapGet("/users", async (HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.UsersAsync(IdentitySetup.Session(h), ct))).RequireAuthorization("Administrator");
        group.MapPost("/users", async (CreateStaff input, HttpContext h, IOrganizationStore store, CancellationToken ct) => Results.Ok(await store.CreateStaffAsync(IdentitySetup.Session(h), input, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        group.MapPut("/users/{id}", async (ulong id, MemberEdit input, HttpContext h, IOrganizationStore store, CancellationToken ct) =>
        {
            await store.UpdateMemberAsync(IdentitySetup.Session(h), id, input, h.TraceIdentifier, ct); return Results.NoContent();
        }).RequireAuthorization("Administrator");
        if (!app.Services.GetRequiredService<OrganizationSettings>().Enabled) group.ExcludeFromDescription();
    }
}
