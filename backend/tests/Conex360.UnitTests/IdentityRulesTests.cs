using Conex360.Application.Identity;
using Conex360.Domain.Identity;
using Conex360.Infrastructure.Identity;
using SkiaSharp;

namespace Conex360.UnitTests;

public sealed class IdentityRulesTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.UtcNow;
    private static UserAccount User => new(1, Guid.NewGuid(), "A@EXAMPLE.INVALID", "Synthetic", "hash", Guid.NewGuid(), true, false, 0, null, 1);
    [Fact]
    public void SessionsEnforceIdleAbsoluteStampAndRevocation()
    {
        var u = User;
        var record = new SessionRecord(Guid.NewGuid(), new byte[32], u.Id, u.SecurityStamp, 1, 1, Now, Now, Now.AddHours(8), null);
        var s = new SessionData(u, record, []);
        Assert.True(s.IsValid(Now.AddMinutes(29), TimeSpan.FromMinutes(30)));
        Assert.False(s.IsValid(Now.AddMinutes(30), TimeSpan.FromMinutes(30)));
        Assert.False((s with { Session = record with { AbsoluteExpiresAt = Now } }).IsValid(Now, TimeSpan.FromMinutes(30)));
        Assert.False((s with { Session = record with { RevokedAt = Now } }).IsValid(Now, TimeSpan.FromMinutes(30)));
        Assert.False((s with { User = u with { IsEnabled = false } }).IsValid(Now, TimeSpan.FromMinutes(30)));
        Assert.False((s with { User = u with { SecurityStamp = Guid.NewGuid() } }).IsValid(Now, TimeSpan.FromMinutes(30)));
    }
    [Fact]
    public void LockoutBackoffResetsAfterWindow()
    {
        var u = User with { FailedAccessCount = 4 };
        Assert.Equal(new LoginFailure(5, Now.AddMinutes(15)), LoginRules.Failed(u, Now, 5, TimeSpan.FromMinutes(15)));
        Assert.Equal(new LoginFailure(1, null), LoginRules.Failed(u with { LockoutUntil = Now.AddSeconds(-1) }, Now, 5, TimeSpan.FromMinutes(15)));
    }
    [Fact]
    public void PasswordHasherUsesSaltAndVerifiesWithoutPlaintextStorage()
    {
        var p = new PasswordService(new());
        var input = SessionSecrets.Create();
        var a = p.Hash("A", input);
        Assert.NotEqual(a, p.Hash("A", input));
        Assert.True(p.Verify("A", a, input).Valid);
        Assert.False(p.Verify("A", a, "incorrect").Valid);
        Assert.DoesNotContain(input, a);
    }
    [Theory]
    [InlineData("<svg><script>alert(1)</script></svg>")]
    [InlineData("not an image")]
    public void LogosRejectUnsafeFormats(string input) => Assert.Throws<AppFailure>(() => LogoStore.Sanitize(System.Text.Encoding.UTF8.GetBytes(input)));
    [Fact]
    public void LogoDecoderReencodesAndRejectsOversizedDimensions()
    {
        using var bitmap = new SKBitmap(20, 20);
        bitmap.Erase(SKColors.Blue);
        using var image = SKImage.FromBitmap(bitmap);
        using var png = image.Encode(SKEncodedImageFormat.Png, 100);
        Assert.NotEmpty(LogoStore.Sanitize(png.ToArray()));
        using var large = new SKBitmap(2049, 1);
        using var largeImage = SKImage.FromBitmap(large);
        using var encoded = largeImage.Encode(SKEncodedImageFormat.Png, 100);
        Assert.Throws<AppFailure>(() => LogoStore.Sanitize(encoded.ToArray()));
        Assert.Throws<AppFailure>(() => LogoStore.Sanitize(new byte[LogoStore.MaximumBytes + 1]));
    }
    [Fact]
    public void SessionSecretHasFullRandomCapabilityAndHashOnlyStorageShape()
    {
        var a = SessionSecrets.Create();
        Assert.True(SessionSecrets.HasValidShape(a));
        Assert.NotEqual(a, SessionSecrets.Create());
        Assert.Equal(32, SessionSecrets.Hash(a).Length);
        Assert.False(SessionSecrets.HasValidShape("../unsafe"));
    }
    [Theory]
    [InlineData(" Person@Example.Invalid ", "PERSON@EXAMPLE.INVALID")]
    public void EmailNormalizationIsExplicit(string input, string expected) => Assert.Equal(expected, IdentityService.NormalizeEmail(input));
    [Fact]
    public void MigrationPackageContainsOnlyReviewedIncrementAndWholeTriggers()
    {
        var m = Migrations.Read();
        Assert.Equal(new[] { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }, m.Select(x => x.Version));
        Assert.Equal(7, m[1].Statements.Length);
        Assert.Contains(m[2].Statements, s => s.Contains("BEGIN", StringComparison.Ordinal) && s.Contains("END;", StringComparison.Ordinal));
    }
}
