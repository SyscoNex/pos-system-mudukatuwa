using System.ComponentModel.DataAnnotations;
using System.Security.Cryptography;
using System.Text;
using Conex360.Domain.Identity;

namespace Conex360.Application.Identity;

public sealed class AuthPolicy
{
    public bool Enabled { get; set; }
    public bool AllowInsecureDevelopmentCookies { get; set; }
    public int IdleMinutes { get; set; } = 30;
    public int AbsoluteHours { get; set; } = 8;
    public uint FailedAttempts { get; set; } = 5;
    public int LockoutMinutes { get; set; } = 15;
    public int MinimumPasswordLength { get; set; } = 15;
    public int PasswordIterations { get; set; } = 210_000;
    public string[] AllowedOrigins { get; set; } = [];
    public TimeSpan Idle => TimeSpan.FromMinutes(IdleMinutes);
}

public sealed class BusinessPolicy
{
    public Dictionary<string, byte> Currencies { get; set; } = new()
    {
        ["LKR"] = 2,
        ["USD"] = 2,
        ["EUR"] = 2,
        ["GBP"] = 2,
        ["AUD"] = 2,
        ["INR"] = 2
    };
}

public sealed class AppFailure(int status, string code, string safeMessage) : Exception(safeMessage)
{
    public int Status { get; } = status;
    public string Code { get; } = code;
}

public sealed record PasswordCheck(bool Valid, bool NeedsRehash);
public interface IPasswordService
{
    string Hash(string normalizedEmail, string password);
    PasswordCheck Verify(string normalizedEmail, string hash, string password);
}

public sealed record IssuedSession(string Secret, SessionData Data);
public sealed record LoginCommit(UserAccount Observed, bool PasswordValid, string? RehashedPassword,
    SessionRecord NewSession, DateTimeOffset Now, string CorrelationId);
public sealed record BusinessProfile(ulong Id, ulong TenantId, string BusinessName, string DisplayName,
    string? Phone, string? Email, string? Address, string Timezone, string CurrencyCode,
    byte CurrencyMinorUnits, string? LogoKey, ulong Version);
public sealed record BusinessEdit([Required, MaxLength(200)] string BusinessName, [Required, MaxLength(200)] string DisplayName,
    [MaxLength(50)] string? Phone, [MaxLength(254)] string? Email, [MaxLength(700)] string? Address,
    [Required, MaxLength(64)] string Timezone, [Required, StringLength(3, MinimumLength = 3)] string CurrencyCode, ulong ExpectedVersion);
public sealed record ProvisionBusiness(Guid OperationId, string TenantCode, string BusinessName,
    string DisplayName, string AdministratorEmail, string AdministratorName, string Timezone,
    string CurrencyCode, byte CurrencyMinorUnits, string OperatorReference, string Reason);
public sealed record ProvisionResult(Guid TenantPublicId, Guid UserPublicId, ulong MembershipId, bool Replayed);

// Focused command adapters: implementations own SQL/locks, never arbitrary CRUD.
public interface IIdentityStore
{
    Task<UserAccount?> FindUserAsync(string normalizedEmail, CancellationToken ct);
    Task<SessionData?> CommitLoginAsync(LoginCommit command, AuthPolicy policy, CancellationToken ct);
    Task RecordUnknownFailureAsync(DateTimeOffset now, string correlation, CancellationToken ct);
    Task<SessionData?> FindSessionAsync(byte[] hash, CancellationToken ct);
    Task TouchAsync(SessionData session, DateTimeOffset now, AuthPolicy policy, CancellationToken ct);
    Task RevokeAsync(ulong userId, Guid sessionPublicId, DateTimeOffset now, string correlation, CancellationToken ct);
    Task<SessionData> SelectMembershipAsync(SessionData session, ulong membershipId, DateTimeOffset now, AuthPolicy policy, string correlation, CancellationToken ct);
    Task<SessionData> ChangePasswordAsync(SessionData session, string expectedHash, string newHash,
        SessionRecord replacement, DateTimeOffset now, AuthPolicy policy, string correlation, CancellationToken ct);
    Task<BusinessProfile> GetBusinessAsync(SessionData session, AuthPolicy policy, DateTimeOffset now, CancellationToken ct);
    Task<BusinessProfile> UpdateBusinessAsync(SessionData session, BusinessEdit edit, byte minorUnits,
        DateTimeOffset now, AuthPolicy policy, string correlation, CancellationToken ct);
    Task<BusinessProfile> SetLogoAsync(SessionData session, string key, ulong expectedVersion,
        DateTimeOffset now, AuthPolicy policy, string correlation, CancellationToken ct);
    Task<ProvisionResult> ProvisionAsync(ProvisionBusiness input, string normalizedEmail,
        string initialHash, UserAccount? verifiedExisting, DateTimeOffset now, CancellationToken ct);
    Task RecoverAsync(Guid publicUserId, string? passwordHash, bool disable, string operatorReference,
        string reason, DateTimeOffset now, CancellationToken ct);
    Task DisableMembershipAsync(ulong tenantId, ulong membershipId, string operatorReference,
        string reason, DateTimeOffset now, CancellationToken ct);
}

public interface IDatabaseReadiness
{
    bool Enabled { get; }
    Task<bool> CheckAsync(CancellationToken ct);
}
public interface ILogoStore
{
    Task<string> SaveAsync(ulong tenantId, ulong companyId, Stream input, CancellationToken ct);
    Task<byte[]?> ReadAsync(ulong tenantId, ulong companyId, string key, CancellationToken ct);
    Task RemoveNewAsync(ulong tenantId, ulong companyId, string key, CancellationToken ct);
}

public static class SessionSecrets
{
    public static string Create() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    public static byte[] Hash(string secret) => SHA256.HashData(Encoding.UTF8.GetBytes(secret));
    public static bool HasValidShape(string secret) => secret.Length == 43 && secret.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_');
}
