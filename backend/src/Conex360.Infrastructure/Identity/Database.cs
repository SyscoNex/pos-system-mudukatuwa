using Conex360.Application.Identity;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed class DatabaseSettings
{
    public bool Enabled { get; set; }
    public int MinimumSchemaVersion { get; set; } = 2;
    public bool AllowUnverifiedDevelopmentTls { get; set; }
    public string ConnectionFile { get; set; } = "";
    public string MigrationConnectionFile { get; set; } = "";
}

public sealed class Database(DatabaseSettings settings) : IDatabaseReadiness
{
    public bool Enabled => settings.Enabled;
    public async Task<MySqlConnection> OpenAsync(CancellationToken ct, bool migration = false)
    {
        if (!Enabled) throw new AppFailure(503, "DATABASE_UNAVAILABLE", "Business services are not configured.");
        var path = migration ? settings.MigrationConnectionFile : settings.ConnectionFile;
        if (string.IsNullOrEmpty(path) || !File.Exists(path))
            throw new AppFailure(503, "DATABASE_UNAVAILABLE", "Business services are unavailable.");
        var builder = new MySqlConnectionStringBuilder((await File.ReadAllTextAsync(path, ct)).Trim())
        {
            AllowUserVariables = false,
            AllowLoadLocalInfile = false,
            AllowPublicKeyRetrieval = false,
            DateTimeKind = MySqlDateTimeKind.Utc,
            ConnectionTimeout = 5,
            DefaultCommandTimeout = 10,
            PersistSecurityInfo = false
        };
        if (builder.SslMode is MySqlSslMode.None or MySqlSslMode.Preferred)
            throw new AppFailure(503, "DATABASE_UNAVAILABLE", "Database transport protection is required.");
        if (!settings.AllowUnverifiedDevelopmentTls && builder.SslMode != MySqlSslMode.VerifyFull)
            throw new AppFailure(503, "DATABASE_UNAVAILABLE", "Verified database transport protection is required.");
        var connection = new MySqlConnection(builder.ConnectionString);
        try
        {
            await connection.OpenAsync(ct);
            await Sql.Execute(connection, null, "SET time_zone = '+00:00', SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'", ct);
            return connection;
        }
        catch { await connection.DisposeAsync(); throw; }
    }
    public async Task<bool> CheckAsync(CancellationToken ct)
    {
        try
        {
            await using var connection = await OpenAsync(ct);
            return Convert.ToInt32(await Sql.Scalar(connection, null,
                "SELECT COUNT(*) FROM schema_migrations WHERE version = @version", ct, ("version", settings.MinimumSchemaVersion.ToString(System.Globalization.CultureInfo.InvariantCulture)))) == 1;
        }
        catch (Exception e) when (e is MySqlException or AppFailure or IOException) { return false; }
    }
}

internal static class Sql
{
    internal static MySqlCommand Command(MySqlConnection c, MySqlTransaction? t, string sql, params (string Key, object? Value)[] values)
    {
        var command = new MySqlCommand(sql, c, t);
        foreach (var (key, value) in values)
            command.Parameters.AddWithValue(key, value switch { null => DBNull.Value, Guid g => g.ToByteArray(true), DateTimeOffset d => d.UtcDateTime, _ => value });
        return command;
    }
    internal static async Task<int> Execute(MySqlConnection c, MySqlTransaction? t, string sql, CancellationToken ct, params (string, object?)[] values)
    {
        await using var command = Command(c, t, sql, values);
        return await command.ExecuteNonQueryAsync(ct);
    }
    internal static async Task<object?> Scalar(MySqlConnection c, MySqlTransaction? t, string sql, CancellationToken ct, params (string, object?)[] values)
    {
        await using var command = Command(c, t, sql, values);
        return await command.ExecuteScalarAsync(ct);
    }
    internal static async Task<T?> One<T>(MySqlConnection c, MySqlTransaction? t, string sql, Func<MySqlDataReader, T> read, CancellationToken ct, params (string, object?)[] values) where T : class
    {
        await using var command = Command(c, t, sql, values);
        await using var reader = await command.ExecuteReaderAsync(ct);
        return await reader.ReadAsync(ct) ? read(reader) : null;
    }
    internal static DateTimeOffset? Date(MySqlDataReader r, string name) => r[name] is DBNull ? null : new DateTimeOffset(r.GetDateTime(name), TimeSpan.Zero);
    internal static string? Text(MySqlDataReader r, string name) => r[name] is DBNull ? null : r.GetString(name);
    internal static Guid Guid(MySqlDataReader r, string name) => new((byte[])r[name], true);
}
