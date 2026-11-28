using Conex360.Domain.Catalog;
namespace Conex360.UnitTests;

public sealed class CatalogNumbersTests
{
    [Fact]
    public void ConversionsAreExactBoundedAndRespectDiscreteUnits()
    {
        Assert.Equal(2000m, CatalogNumbers.ToBase(2, 1000, false, false));
        Assert.Equal(0.000000001m, CatalogNumbers.ToBase(0.000000001m, 1, false, false));
        Assert.Throws<ArgumentException>(() => CatalogNumbers.ToBase(0.000000001m, 0.1m, false, false));
        Assert.Throws<ArgumentException>(() => CatalogNumbers.ToBase(0.5m, 24, true, true));
        Assert.Throws<ArgumentException>(() => CatalogNumbers.ToBase(999999999999999.999999999m, 2, false, false));
        Assert.False(CatalogNumbers.Fits(1.0000001m, 6)); Assert.True(CatalogNumbers.Fits(0, 6));
    }
}
