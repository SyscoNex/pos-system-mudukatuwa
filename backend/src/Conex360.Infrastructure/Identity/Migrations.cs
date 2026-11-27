using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using Conex360.Application.Identity;

namespace Conex360.Infrastructure.Identity;

public sealed record Migration(int Version, string Name, string Hash, string[] Statements);
public sealed class Migrations(Database database)
{
    public static IReadOnlyList<Migration> Read()
    {
        var assembly = typeof(Migrations).Assembly;
        return assembly.GetManifestResourceNames().Where(n => n.EndsWith(".sql", StringComparison.Ordinal)).Order().Select(name =>
        {
            using var stream = assembly.GetManifestResourceStream(name)!;
            using var buffer = new MemoryStream();
            stream.CopyTo(buffer);
            var bytes = buffer.ToArray();
            var file = name.Split('.').Reverse().Skip(1).First();
            var sql = Encoding.UTF8.GetString(bytes).TrimStart('\uFEFF').Replace("\r\n", "\n", StringComparison.Ordinal);
            return new Migration(int.Parse(file[..4], System.Globalization.CultureInfo.InvariantCulture), file,
                Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(sql))), sql.Split("-- statement-break", StringSplitOptions.RemoveEmptyEntries).Where(s => !string.IsNullOrWhiteSpace(s)).ToArray());
        }).ToArray();
    }
    public async Task ApplyAsync(string expectedDatabase, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(expectedDatabase)) throw new AppFailure(400, "TARGET_REQUIRED", "An explicitly approved database name is required.");
        await using var c = await database.OpenAsync(ct, true);
        if (c.Database != expectedDatabase || !(await Sql.Scalar(c, null, "SELECT VERSION()", ct))!.ToString()!.StartsWith("8.4.", StringComparison.Ordinal))
            throw new AppFailure(400, "WRONG_DATABASE", "Database target/version does not match the explicit migration target.");
        if (Convert.ToInt32(await Sql.Scalar(c, null, "SELECT GET_LOCK(@lock, 5)", ct, ("lock", "conex360:migrate:" + expectedDatabase))) != 1)
            throw new AppFailure(409, "MIGRATION_BUSY", "Another migration is active.");
        try
        {
            var migrations = Read();
            await Sql.Execute(c, null, migrations.Single(m => m.Version == 0).Statements[0], ct);
            foreach (var m in migrations)
            {
                var hash = await Sql.Scalar(c, null, "SELECT sha256 FROM schema_migrations WHERE version=@version", ct, ("version", m.Version));
                if (hash is not null)
                {
                    if (!string.Equals(hash.ToString(), m.Hash, StringComparison.OrdinalIgnoreCase)) throw new AppFailure(409, "MIGRATION_CHANGED", "A previously applied migration changed. Stop and investigate.");
                    continue;
                }
                if (m.Version > 0) foreach (var sql in m.Statements) await Sql.Execute(c, null, sql, ct);
                await Sql.Execute(c, null, "INSERT INTO schema_migrations(version,name,sha256,applied_at) VALUES(@version,@name,@hash,UTC_TIMESTAMP(6))", ct,
                    ("version", m.Version), ("name", m.Name), ("hash", m.Hash));
                Console.WriteLine($"Applied {m.Version:D4}: {m.Name}");
            }
        }
        finally { await Sql.Scalar(c, null, "SELECT RELEASE_LOCK(@lock)", CancellationToken.None, ("lock", "conex360:migrate:" + expectedDatabase)); }
    }
}
