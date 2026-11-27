using System.Net.Mail;
using System.Text;
using Conex360.Domain.Identity;

namespace Conex360.Application.Identity;

public sealed class IdentityService(IIdentityStore store, IPasswordService passwords,
    AuthPolicy policy, BusinessPolicy businessPolicy, TimeProvider clock)
{
    private readonly string dummyHash = passwords.Hash("DUMMY", SessionSecrets.Create());
    public const string LoginMessage = "Sign-in was unsuccessful. Check your details or try again later.";

    public static string NormalizeEmail(string input)
    {
        var value = input.Trim().Normalize(NormalizationForm.FormC);
        if (value.Length > 254 || !MailAddress.TryCreate(value, out var parsed) || parsed.Address != value)
            throw new AppFailure(400, "INVALID_EMAIL", "Enter a valid email address.");
        return value.ToUpperInvariant();
    }

    public void ValidateNewPassword(string password)
    {
        if (password.Length < policy.MinimumPasswordLength || password.Length > 128
            || string.IsNullOrWhiteSpace(password) || password.Any(char.IsControl)
            || password.Distinct().Count() < 5)
            throw new AppFailure(400, "PASSWORD_POLICY", $"Use a password or passphrase of {policy.MinimumPasswordLength}–128 characters with enough variety.");
    }

    private SessionRecord NewSession(UserAccount user, string secret, DateTimeOffset now) =>
        new(Guid.NewGuid(), SessionSecrets.Hash(secret), user.Id, user.SecurityStamp, null, 1,
            now, now, now.AddHours(policy.AbsoluteHours), null);

    public async Task<IssuedSession> LoginAsync(string email, string password, string correlation, CancellationToken ct)
    {
        string normalized;
        try { normalized = NormalizeEmail(email); }
        catch (AppFailure) { normalized = "INVALID"; }
        var user = await store.FindUserAsync(normalized, ct);
        var verified = passwords.Verify(normalized, user?.PasswordHash ?? dummyHash, password);
        if (user is null)
        {
            await store.RecordUnknownFailureAsync(clock.GetUtcNow(), correlation, ct);
            throw new AppFailure(401, "SIGN_IN_FAILED", LoginMessage);
        }
        var secret = SessionSecrets.Create();
        var now = clock.GetUtcNow();
        var result = await store.CommitLoginAsync(new(user, verified.Valid,
            verified.Valid && verified.NeedsRehash ? passwords.Hash(normalized, password) : null,
            NewSession(user, secret, now), now, correlation), policy, ct);
        return result is null ? throw new AppFailure(401, "SIGN_IN_FAILED", LoginMessage) : new(secret, result);
    }

    public async Task<SessionData?> ValidateSessionAsync(string secret, CancellationToken ct)
    {
        if (!SessionSecrets.HasValidShape(secret)) return null;
        var session = await store.FindSessionAsync(SessionSecrets.Hash(secret), ct);
        return session?.IsValid(clock.GetUtcNow(), policy.Idle) == true && session.Memberships.Count > 0 ? session : null;
    }

    public Task TouchAsync(SessionData session, CancellationToken ct) => store.TouchAsync(session, clock.GetUtcNow(), policy, ct);
    public Task LogoutAsync(SessionData session, string correlation, CancellationToken ct) =>
        store.RevokeAsync(session.User.Id, session.Session.PublicId, clock.GetUtcNow(), correlation, ct);
    public Task<SessionData> SelectAsync(SessionData session, ulong membershipId, string correlation, CancellationToken ct) =>
        store.SelectMembershipAsync(session, membershipId, clock.GetUtcNow(), policy, correlation, ct);

    public async Task<IssuedSession> ChangePasswordAsync(SessionData session, string currentPassword,
        string newPassword, string correlation, CancellationToken ct)
    {
        ValidateNewPassword(newPassword);
        if (!passwords.Verify(session.User.Email, session.User.PasswordHash, currentPassword).Valid)
            throw new AppFailure(400, "PASSWORD_CHANGE_FAILED", "The password could not be changed. Check your current password.");
        if (passwords.Verify(session.User.Email, session.User.PasswordHash, newPassword).Valid)
            throw new AppFailure(400, "PASSWORD_POLICY", "Choose a different new password.");
        var secret = SessionSecrets.Create();
        var now = clock.GetUtcNow();
        var newRecord = NewSession(session.User with { SecurityStamp = Guid.NewGuid() }, secret, now)
            with
        { SelectedMembershipId = session.Session.SelectedMembershipId };
        var changed = await store.ChangePasswordAsync(session, session.User.PasswordHash,
            passwords.Hash(session.User.Email, newPassword), newRecord, now, policy, correlation, ct);
        return new(secret, changed);
    }

    public BusinessEdit ValidateBusiness(BusinessEdit edit)
    {
        if (string.IsNullOrWhiteSpace(edit.BusinessName) || edit.BusinessName.Trim().Length > 200
            || string.IsNullOrWhiteSpace(edit.DisplayName) || edit.DisplayName.Trim().Length > 200
            || edit.Phone?.Length > 50 || edit.Email?.Length > 254 || edit.Address?.Length > 700)
            throw new AppFailure(400, "INVALID_BUSINESS", "Check the business names and contact field lengths.");
        if (!string.IsNullOrWhiteSpace(edit.Email)) _ = NormalizeEmail(edit.Email);
        if (!(edit.Timezone == "UTC" || edit.Timezone.Contains('/'))
            || !TimeZoneInfo.TryFindSystemTimeZoneById(edit.Timezone, out _))
            throw new AppFailure(400, "INVALID_TIMEZONE", "Enter a valid IANA timezone, such as Region/City, or UTC.");
        if (!businessPolicy.Currencies.ContainsKey(edit.CurrencyCode))
            throw new AppFailure(400, "INVALID_CURRENCY", "Select a configured currency.");
        return edit with
        {
            BusinessName = edit.BusinessName.Trim(),
            DisplayName = edit.DisplayName.Trim(),
            Phone = NullIfEmpty(edit.Phone),
            Email = NullIfEmpty(edit.Email),
            Address = NullIfEmpty(edit.Address)
        };
    }

    private static string? NullIfEmpty(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    public Task<BusinessProfile> BusinessAsync(SessionData session, CancellationToken ct) =>
        store.GetBusinessAsync(session, policy, clock.GetUtcNow(), ct);
    public Task<BusinessProfile> UpdateBusinessAsync(SessionData session, BusinessEdit edit, string correlation, CancellationToken ct)
    {
        edit = ValidateBusiness(edit);
        return store.UpdateBusinessAsync(session, edit, businessPolicy.Currencies[edit.CurrencyCode], clock.GetUtcNow(), policy, correlation, ct);
    }
    public Task<BusinessProfile> SetLogoAsync(SessionData session, string key, ulong version, string correlation, CancellationToken ct) =>
        store.SetLogoAsync(session, key, version, clock.GetUtcNow(), policy, correlation, ct);

    public async Task<ProvisionResult> ProvisionAsync(ProvisionBusiness request, string password,
        bool linkExisting, CancellationToken ct)
    {
        _ = ValidateBusiness(new(request.BusinessName, request.DisplayName, null, null, null, request.Timezone, request.CurrencyCode, 1));
        if (request.OperationId == Guid.Empty || request.TenantCode.Length is < 3 or > 60
            || !request.TenantCode.All(c => char.IsAsciiLetterLower(c) || char.IsAsciiDigit(c) || c == '-')
            || string.IsNullOrWhiteSpace(request.OperatorReference) || request.OperatorReference.Length > 100
            || string.IsNullOrWhiteSpace(request.Reason) || request.Reason.Length > 300
            || string.IsNullOrWhiteSpace(request.AdministratorName) || request.AdministratorName.Length > 120)
            throw new AppFailure(400, "INVALID_PROVISIONING", "Check the provisioning data and operator reason.");
        var email = NormalizeEmail(request.AdministratorEmail);
        var existing = await store.FindUserAsync(email, ct);
        if (existing is not null && (!existing.IsEnabled || (linkExisting && existing.MustChangePassword)
            || existing.LockoutUntil > clock.GetUtcNow() || !passwords.Verify(email, existing.PasswordHash, password).Valid))
            throw new AppFailure(409, "PROVISIONING_CONFLICT", "Provisioning could not be completed. Existing identity linkage needs verified consent and the existing password.");
        if (existing is null && linkExisting) throw new AppFailure(409, "PROVISIONING_CONFLICT", "The verified identity is unavailable.");
        if (existing is null) ValidateNewPassword(password);
        return await store.ProvisionAsync(request with { CurrencyMinorUnits = businessPolicy.Currencies[request.CurrencyCode] },
            email, existing?.PasswordHash ?? passwords.Hash(email, password), linkExisting ? existing : null, clock.GetUtcNow(), ct);
    }

    public async Task RecoverAsync(Guid publicId, string email, string? password, bool disable,
        string operatorReference, string reason, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(operatorReference) || operatorReference.Length > 100 || string.IsNullOrWhiteSpace(reason) || reason.Length > 300)
            throw new AppFailure(400, "OPERATOR_REQUIRED", "Verified operator and recovery reason are required.");
        if (!disable) ValidateNewPassword(password ?? "");
        var user = await store.FindUserAsync(NormalizeEmail(email), ct);
        if (user?.PublicId != publicId) throw new AppFailure(404, "NOT_FOUND", "The identity is unavailable.");
        await store.RecoverAsync(publicId, disable ? null : passwords.Hash(user.Email, password!), disable,
            operatorReference, reason, clock.GetUtcNow(), ct);
    }
}
