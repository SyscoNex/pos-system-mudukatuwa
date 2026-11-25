using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Conex360.Api.Serialization;

// Financial quantities travel as exact decimal strings. Module-specific scale and
// business limits belong in the relevant DTO/use case, not in this wire converter.
public sealed partial class DecimalStringConverter : JsonConverter<decimal>
{
    public override decimal Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType != JsonTokenType.String)
        {
            throw new JsonException("An exact decimal string is required.");
        }

        var text = reader.GetString()!;
        if (text.Length > 128 || !DecimalPattern().IsMatch(text)
            || !decimal.TryParse(text, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint,
                CultureInfo.InvariantCulture, out var value)
            || Normalize(text) != Normalize(Format(value)))
        {
            throw new JsonException("The decimal string is invalid or exceeds exact decimal precision.");
        }

        return value;
    }

    public override void Write(Utf8JsonWriter writer, decimal value, JsonSerializerOptions options)
        => writer.WriteStringValue(Format(value));

    private static string Format(decimal value) => value.ToString("0.############################", CultureInfo.InvariantCulture);

    private static string Normalize(string text)
    {
        var normalized = text.Contains('.') ? text.TrimEnd('0').TrimEnd('.') : text;
        return normalized == "-0" ? "0" : normalized;
    }

    [GeneratedRegex(@"^-?(0|[1-9][0-9]*)(\.[0-9]+)?$", RegexOptions.CultureInvariant)]
    private static partial Regex DecimalPattern();
}
