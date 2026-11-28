using Conex360.Domain.Inventory;

namespace Conex360.UnitTests;

public sealed class ReceiptMathTests
{
    [Fact]
    public void ValueUsesEnteredQuantityAndCostWithoutReroundingFromBaseCost()
    {
        Assert.Equal((48m, 0.041667m, 2m), ReceiptMath.Calculate(2m, 24m, 1m, true, true));
        Assert.Equal((0.5m, 0.000001m, 0.000001m), ReceiptMath.Calculate(0.5m, 1m, 0.000001m, false, false));
        Assert.Throws<ArgumentException>(() => ReceiptMath.Calculate(1m, 0.000000001m, 999999999999999999m, false, false));
        Assert.Throws<ArgumentException>(() => ReceiptMath.Calculate(1m, 1m, 0.0000001m, false, false));
    }
}
