using System.Globalization;
using System.Text.Json;
using Conex360.Api.Serialization;

namespace Conex360.UnitTests;

public sealed class JsonContractTests
{
    private static JsonSerializerOptions Options => new(JsonSerializerDefaults.Web)
    {
        Converters = { new DecimalStringConverter(), new UInt64StringConverter() }
    };

    [Theory]
    [InlineData("0")]
    [InlineData("-0.0000000000000000000000000001")]
    [InlineData("123456789012345.123456789")]
    [InlineData("79228162514264337593543950335")]
    [InlineData("-79228162514264337593543950335")]
    public void ExactDecimalsRoundTripAsStrings(string exact)
    {
        var value = JsonSerializer.Deserialize<decimal>($"\"{exact}\"", Options);
        Assert.Equal(decimal.Parse(exact, CultureInfo.InvariantCulture), value);
        Assert.Equal(value, JsonSerializer.Deserialize<decimal>(JsonSerializer.Serialize(value, Options), Options));
        Assert.StartsWith("\"", JsonSerializer.Serialize(value, Options));
    }

    [Theory]
    [InlineData("1.5")]
    [InlineData("\"1e2\"")]
    [InlineData("\"1,5\"")]
    [InlineData("\" 1.5\"")]
    [InlineData("\"+1.5\"")]
    [InlineData("\"01.5\"")]
    [InlineData("\"0.12345678901234567890123456789\"")]
    [InlineData("\"79228162514264337593543950336\"")]
    public void NumericTokensInvalidSyntaxAndPrecisionLossAreRejected(string json)
        => Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<decimal>(json, Options));

    [Fact]
    public void FormattingDoesNotFollowServerCulture()
    {
        var previous = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("fr-FR");
            Assert.Equal("\"1234.5\"", JsonSerializer.Serialize(1234.5m, Options));
        }
        finally
        {
            CultureInfo.CurrentCulture = previous;
        }
    }

    [Fact]
    public void MaximumUnsignedIdNeverBecomesAJavaScriptNumber()
    {
        const string encoded = "\"18446744073709551615\"";
        Assert.Equal(encoded, JsonSerializer.Serialize(ulong.MaxValue, Options));
        Assert.Equal(ulong.MaxValue, JsonSerializer.Deserialize<ulong>(encoded, Options));
    }

    [Theory]
    [InlineData("18446744073709551615")]
    [InlineData("\"-1\"")]
    [InlineData("\"18446744073709551616\"")]
    public void InvalidIdRepresentationsAreRejected(string json)
        => Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<ulong>(json, Options));
}
