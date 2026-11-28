using System.Text;
using System.Text.Json;
using Conex360.Application.Identity;
using Conex360.Infrastructure.Identity;

namespace Conex360.Api.Identity;

// OS-controlled commands, never exposed as HTTP endpoints. Input JSON contains no password.
public static class AdministrativeCommands
{
    private sealed record RecoveryInput(Guid UserPublicId, string Email, string OperatorReference, string Reason);
    private sealed record DisableInput(ulong TenantId, ulong MembershipId, string OperatorReference, string Reason);
    private sealed record TransitInput(Guid TenantPublicId, string OperatorReference, string Reason);
    public static async Task<int> RunAsync(IServiceProvider services, IConfiguration config, string[] args)
    {
        string Value(string name) => args.SkipWhile(a => a != name).Skip(1).FirstOrDefault() ?? "";
        try
        {
            if (args.Contains("--admin-validate-migrations"))
            {
                foreach (var m in Migrations.Read()) Console.WriteLine($"{m.Version:D4} {m.Name} {m.Statements.Length} statements SHA256 {m.Hash}");
                return 0;
            }
            if (!config.GetValue<bool>("Operations:Enabled")) throw new AppFailure(403, "OPERATIONS_DISABLED", "Controlled operations require explicit operator configuration.");
            if (args.Contains("--admin-migrate"))
            {
                await services.GetRequiredService<Migrations>().ApplyAsync(Value("--expected-database"), CancellationToken.None);
                return 0;
            }
            var path = Value("--input");
            if (string.IsNullOrWhiteSpace(path)) throw new AppFailure(400, "INPUT_REQUIRED", "A non-secret operator JSON file is required.");
            var json = await File.ReadAllTextAsync(path);
            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            var identity = services.GetRequiredService<IdentityService>();
            if (args.Contains("--admin-link-membership"))
            {
                var input = JsonSerializer.Deserialize<Conex360.Application.Organization.LinkExistingMembership>(json, options) ?? throw new JsonException();
                var password = await ReadSecret(args.Contains("--password-stdin"));
                await ((OrganizationStore)services.GetRequiredService<Conex360.Application.Organization.IOrganizationStore>()).LinkExistingAsync(input, password, CancellationToken.None);
                Console.WriteLine("Verified identity linked; Staff outlet grants require explicit assignment."); return 0;
            }
            if (args.Contains("--admin-initialize-transit"))
            {
                var input = JsonSerializer.Deserialize<TransitInput>(json, options) ?? throw new JsonException();
                await ((OrganizationStore)services.GetRequiredService<Conex360.Application.Organization.IOrganizationStore>()).InitializeTransitAsync(input.TenantPublicId, input.OperatorReference, input.Reason, CancellationToken.None);
                Console.WriteLine("Canonical internal transit initialized or already present."); return 0;
            }
            if (args.Contains("--admin-provision"))
            {
                var input = JsonSerializer.Deserialize<ProvisionBusiness>(json, options) ?? throw new JsonException();
                var password = await ReadSecret(args.Contains("--password-stdin"));
                var result = await identity.ProvisionAsync(input, password, args.Contains("--link-existing"), CancellationToken.None);
                Console.WriteLine(JsonSerializer.Serialize(new { result.TenantPublicId, result.UserPublicId, MembershipId = result.MembershipId.ToString(System.Globalization.CultureInfo.InvariantCulture), result.Replayed }));
                return 0;
            }
            if (args.Contains("--admin-recover") || args.Contains("--admin-disable-user"))
            {
                var input = JsonSerializer.Deserialize<RecoveryInput>(json, options) ?? throw new JsonException();
                var disable = args.Contains("--admin-disable-user");
                var password = disable ? null : await ReadSecret(args.Contains("--password-stdin"));
                await identity.RecoverAsync(input.UserPublicId, input.Email, password, disable, input.OperatorReference, input.Reason, CancellationToken.None);
                Console.WriteLine("Controlled identity operation completed; all existing sessions revoked.");
                return 0;
            }
            if (args.Contains("--admin-disable-membership"))
            {
                var input = JsonSerializer.Deserialize<DisableInput>(json, options) ?? throw new JsonException();
                await services.GetRequiredService<IIdentityStore>().DisableMembershipAsync(input.TenantId, input.MembershipId,
                    input.OperatorReference, input.Reason, services.GetRequiredService<TimeProvider>().GetUtcNow(), CancellationToken.None);
                Console.WriteLine("Membership disabled; other tenant memberships remain unchanged.");
                return 0;
            }
            throw new AppFailure(400, "UNKNOWN_COMMAND", "Unknown administrative command.");
        }
        catch (Exception e)
        {
            // Never print connection strings, passwords, SQL or untrusted exception content.
            Console.Error.WriteLine(e is AppFailure f ? $"{f.Code}: {f.Message}" : e is MySqlConnector.MySqlException sql ? $"Controlled SQL operation failed (number {sql.Number}, state {sql.SqlState}). Inspect configuration and approved target; no automatic repair." : $"Controlled operation failed ({e.GetType().Name}). Inspect configuration and approved target.");
            return 1;
        }
    }
    private static async Task<string> ReadSecret(bool stdin)
    {
        if (stdin) return await Console.In.ReadLineAsync() ?? "";
        if (Console.IsInputRedirected) throw new AppFailure(400, "SECRET_HANDOFF", "Use a masked terminal prompt or explicit --password-stdin over a protected pipe.");
        Console.Write("Password (hidden; minimum 15 characters): ");
        var buffer = new StringBuilder();
        while (true)
        {
            var key = Console.ReadKey(true);
            if (key.Key == ConsoleKey.Enter) break;
            if (key.Key == ConsoleKey.Backspace) { if (buffer.Length > 0) buffer.Length--; }
            else if (!char.IsControl(key.KeyChar) && buffer.Length < 129) buffer.Append(key.KeyChar);
        }
        Console.WriteLine();
        return buffer.ToString();
    }
}
