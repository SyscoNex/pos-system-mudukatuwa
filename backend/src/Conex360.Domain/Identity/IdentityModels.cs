namespace Conex360.Domain.Identity;

public static class MembershipRoles
{
    public const string Administrator = "ADMINISTRATOR";
    public const string Staff = "STAFF";
}

public sealed record UserAccount(ulong Id, Guid PublicId, string Email, string DisplayName,
    string PasswordHash, Guid SecurityStamp, bool IsEnabled, bool MustChangePassword,
    uint FailedAccessCount, DateTimeOffset? LockoutUntil, ulong Version);

public sealed record Membership(ulong Id, ulong TenantId, ulong CompanyId, string BusinessName, string Role);

public sealed record SessionRecord(Guid PublicId, byte[] KeyHash, ulong UserId, Guid SecurityStamp,
    ulong? SelectedMembershipId, ulong ContextVersion, DateTimeOffset CreatedAt,
    DateTimeOffset LastActivityAt, DateTimeOffset AbsoluteExpiresAt, DateTimeOffset? RevokedAt);

public sealed record SessionData(UserAccount User, SessionRecord Session, IReadOnlyList<Membership> Memberships)
{
    public Membership? Selected => Memberships.SingleOrDefault(m => m.Id == Session.SelectedMembershipId);
    public bool IsValid(DateTimeOffset now, TimeSpan idle) => User.IsEnabled
        && User.SecurityStamp == Session.SecurityStamp && Session.RevokedAt is null
        && now < Session.AbsoluteExpiresAt && now < Session.LastActivityAt + idle;
}

public sealed record LoginFailure(uint Count, DateTimeOffset? LockoutUntil);

public static class LoginRules
{
    public static LoginFailure Failed(UserAccount user, DateTimeOffset now, uint limit, TimeSpan lockout)
    {
        var count = user.LockoutUntil is { } until && until <= now ? 1 : user.FailedAccessCount + 1;
        return count >= limit ? new(limit, now + lockout) : new(count, null);
    }
}
