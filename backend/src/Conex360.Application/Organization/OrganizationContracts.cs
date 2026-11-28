using System.ComponentModel.DataAnnotations;
using Conex360.Domain.Identity;

namespace Conex360.Application.Organization;

public sealed class OrganizationSettings { public bool Enabled { get; set; } }
public sealed record Outlet(ulong Id, string Code, string Name, string? Address, string? Phone, string? Description, bool IsActive, ulong Version);
public sealed record Warehouse(ulong Id, ulong BranchId, string Code, string Name, string? Description, bool IsActive, bool IsDefault, ulong Version);
public sealed record StorageLocation(ulong Id, ulong WarehouseId, string Code, string Name, string Kind);
public sealed record ManagedUser(ulong MembershipId, string DisplayName, string Email, string Role, bool IsActive, bool IdentityEnabled, bool MustChangePassword, ulong Version, IReadOnlyList<ulong> BranchIds);
public sealed record OutletEdit([Required, MaxLength(40)] string Code, [Required, MaxLength(200)] string Name, [MaxLength(700)] string? Address,
    [MaxLength(50)] string? Phone, [MaxLength(500)] string? Description, bool IsActive, ulong ExpectedVersion, [Required, MaxLength(300)] string Reason);
public sealed record WarehouseEdit(ulong BranchId, [Required, MaxLength(60)] string Code, [Required, MaxLength(200)] string Name,
    [MaxLength(500)] string? Description, bool IsActive, bool IsDefault, ulong? ReplacementWarehouseId, ulong ExpectedVersion, [Required, MaxLength(300)] string Reason);
public sealed record CreateStaff([Required, MaxLength(254)] string Email, [Required, MaxLength(120)] string DisplayName,
    IReadOnlyList<ulong> BranchIds, [Required, MaxLength(300)] string Reason);
public sealed record MemberEdit([Required] string Role, bool IsActive, IReadOnlyList<ulong> BranchIds, ulong ExpectedVersion, [Required, MaxLength(300)] string Reason);
public sealed record InitialCredential(ulong MembershipId, string Email, string TemporaryPassword);
public sealed record LinkExistingMembership(Guid TenantPublicId, Guid UserPublicId, string Email, string Role, string OperatorReference, string ConsentReference);
public sealed record OutletContext(ulong? SelectedBranchId, ulong ContextVersion, IReadOnlyList<Outlet> Outlets);
public interface IOrganizationStore
{
    Task<IReadOnlyList<Outlet>> OutletsAsync(SessionData session, CancellationToken ct);
    Task<Outlet> SaveOutletAsync(SessionData session, ulong? id, OutletEdit edit, string correlation, CancellationToken ct);
    Task<IReadOnlyList<Warehouse>> WarehousesAsync(SessionData session, ulong? branchId, CancellationToken ct);
    Task<Warehouse> SaveWarehouseAsync(SessionData session, ulong? id, WarehouseEdit edit, string correlation, CancellationToken ct);
    Task<IReadOnlyList<StorageLocation>> LocationsAsync(SessionData session, ulong warehouseId, CancellationToken ct);
    Task<IReadOnlyList<ManagedUser>> UsersAsync(SessionData session, CancellationToken ct);
    Task<InitialCredential> CreateStaffAsync(SessionData session, CreateStaff input, string correlation, CancellationToken ct);
    Task UpdateMemberAsync(SessionData session, ulong membershipId, MemberEdit edit, string correlation, CancellationToken ct);
    Task<OutletContext> ContextAsync(SessionData session, CancellationToken ct);
    Task<OutletContext> SelectOutletAsync(SessionData session, ulong? branchId, string correlation, CancellationToken ct);
}
