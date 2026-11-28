using System.Numerics;
using Conex360.Domain.Catalog;

namespace Conex360.Domain.Inventory;

public static class ReceiptMath
{
    public static decimal IssueValue(decimal quantity, decimal remaining, decimal value)
    {
        if (quantity <= 0 || quantity > remaining || !CatalogNumbers.Fits(quantity, 9) ||
            !CatalogNumbers.Fits(remaining, 9) || !CatalogNumbers.Fits(value, 6))
            throw new ArgumentException("Issue exceeds the available quantity or precision.");
        return quantity == remaining ? value :
            RoundValue(Scaled(quantity, 9) * Scaled(value, 6), Scaled(remaining, 9));
    }

    private static BigInteger Scaled(decimal value, int scale) =>
        new(value * (scale == 9 ? 1_000_000_000m : 1_000_000m));

    private static decimal RoundValue(BigInteger numerator, BigInteger denominator)
    {
        var units = BigInteger.DivRem(numerator, denominator, out var remainder);
        if (remainder * 2 >= denominator) units++;
        if (units >= BigInteger.Pow(10, 24))
            throw new ArgumentException("Operational cost exceeds supported precision.");
        return (decimal)units / 1_000_000m;
    }

    public static (decimal BaseQuantity, decimal BaseCost, decimal Value) Calculate(
        decimal quantity, decimal factor, decimal cost, bool inputDiscrete, bool baseDiscrete)
    {
        if (quantity <= 0 || !CatalogNumbers.Fits(cost, 6))
            throw new ArgumentException("Enter a positive quantity and an explicit nonnegative cost with up to six decimal places.");
        var baseQuantity = CatalogNumbers.ToBase(quantity, factor, inputDiscrete, baseDiscrete);
        var costUnits = Scaled(cost, 6);
        return (baseQuantity,
            RoundValue(costUnits * 1_000_000_000, Scaled(factor, 9)),
            RoundValue(costUnits * Scaled(quantity, 9), 1_000_000_000));
    }
}
