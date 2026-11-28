using System.Numerics;

namespace Conex360.Domain.Catalog;

public static class CatalogNumbers
{
    private static readonly BigInteger Scale = BigInteger.Pow(10, 9);
    private static readonly BigInteger MaximumScaled = BigInteger.Pow(10, 24) - 1;
    public static bool Fits(decimal value, int scale) => value >= 0 && decimal.Round(value, scale) == value
        && value < (scale == 9 ? 1_000_000_000_000_000m : 1_000_000_000_000_000_000m);
    private static BigInteger Scaled(decimal value)
    {
        var bits = decimal.GetBits(value);
        var n = (BigInteger)(uint)bits[0] + ((BigInteger)(uint)bits[1] << 32) + ((BigInteger)(uint)bits[2] << 64);
        var decimals = (bits[3] >> 16) & 0xff;
        return decimals <= 9 ? n * BigInteger.Pow(10, 9 - decimals) : n / BigInteger.Pow(10, decimals - 9);
    }
    // Reject rounding: both inputs and the result must fit the authoritative scale.
    public static decimal ToBase(decimal quantity, decimal factor, bool inputDiscrete, bool baseDiscrete)
    {
        if (!Fits(quantity, 9) || !Fits(factor, 9) || factor <= 0 || inputDiscrete && quantity != decimal.Truncate(quantity))
            throw new ArgumentException("Invalid quantity or conversion precision.");
        var product = Scaled(quantity) * Scaled(factor);
        var result = BigInteger.DivRem(product, Scale, out var remainder);
        if (remainder != 0 || result > MaximumScaled || baseDiscrete && result % Scale != 0)
            throw new ArgumentException("Conversion exceeds exact base quantity precision or whole-unit restrictions.");
        return (decimal)result / 1_000_000_000m;
    }
}
