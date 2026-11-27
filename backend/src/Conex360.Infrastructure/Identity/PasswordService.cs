using Conex360.Application.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;

namespace Conex360.Infrastructure.Identity;

public sealed class PasswordService(AuthPolicy policy) : IPasswordService
{
    private readonly PasswordHasher<string> hasher = new(Options.Create(new PasswordHasherOptions
    {
        CompatibilityMode = PasswordHasherCompatibilityMode.IdentityV3,
        IterationCount = policy.PasswordIterations
    }));
    public string Hash(string normalizedEmail, string password) => hasher.HashPassword(normalizedEmail, password);
    public PasswordCheck Verify(string normalizedEmail, string hash, string password)
    {
        try
        {
            var result = hasher.VerifyHashedPassword(normalizedEmail, hash, password);
            return new(result != PasswordVerificationResult.Failed, result == PasswordVerificationResult.SuccessRehashNeeded);
        }
        catch (FormatException) { return new(false, false); }
    }
}
