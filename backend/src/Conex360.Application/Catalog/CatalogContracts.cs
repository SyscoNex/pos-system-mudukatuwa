using System.ComponentModel.DataAnnotations;
using Conex360.Domain.Identity;

namespace Conex360.Application.Catalog;

public sealed class CatalogSettings { public bool Enabled { get; set; } }
public sealed record Unit(ulong Id, string Code, string Name, string Dimension, bool IsDiscrete, bool IsActive, ulong Version);
public sealed record Category(ulong Id, string Code, string Name, string? Description, ulong? ParentId, bool IsActive, ulong Version);
public sealed record Supplier(ulong Id, string Code, string Name, string? Phone, string? Email, string? Address, string? ContactPerson, string? Notes, bool IsActive, ulong Version);
public sealed record Product(ulong Id, string Sku, string Name, string? Description, ulong? CategoryId, ulong BaseUnitId, string Kind, bool PurchaseEnabled, bool SaleEnabled, bool ManufactureEnabled, string TrackingMode, bool ExpiryRequired, bool IsActive, ulong Version);
public sealed record ItemUnit(ulong Id, ulong UnitId, decimal ToBaseFactor, decimal? PurchasePrice, decimal? SellingPrice, bool IsPurchaseDefault, bool IsSaleDefault, bool IsActive, ulong Version);
public sealed record Barcode(ulong Id, ulong ItemUnitId, string Value, bool IsActive, ulong Version);
public sealed record ProductDetail(Product Product, IReadOnlyList<ItemUnit> Units, IReadOnlyList<Barcode> Barcodes, string CurrencyCode, bool CanReadPurchasePrices);
public sealed record UnitEdit([Required, MaxLength(20)] string Code, [Required, MaxLength(100)] string Name, [Required] string Dimension, bool IsDiscrete, bool IsActive, ulong ExpectedVersion, [Required, MaxLength(300)] string Reason);
public sealed record CategoryEdit([Required, MaxLength(60)] string Code, [Required, MaxLength(150)] string Name, [MaxLength(500)] string? Description, ulong? ParentId, bool IsActive, ulong ExpectedVersion, [Required, MaxLength(300)] string Reason);
public sealed record SupplierEdit([Required, MaxLength(60)] string Code, [Required, MaxLength(200)] string Name, [MaxLength(50)] string? Phone, [MaxLength(254)] string? Email, [MaxLength(700)] string? Address, [MaxLength(120)] string? ContactPerson, [MaxLength(700)] string? Notes, bool IsActive, ulong ExpectedVersion, [Required, MaxLength(300)] string Reason);
public sealed record BarcodeEdit(ulong? Id, [Required, MaxLength(128)] string Value, bool IsActive, ulong ExpectedVersion);
public sealed record ItemUnitEdit(ulong? Id, ulong UnitId, decimal ToBaseFactor, decimal? PurchasePrice, decimal? SellingPrice, bool IsPurchaseDefault, bool IsSaleDefault, bool IsActive, ulong ExpectedVersion, [Required] IReadOnlyList<BarcodeEdit> Barcodes);
public sealed record ProductEdit([Required, MaxLength(60)] string Sku, [Required, MaxLength(200)] string Name, [MaxLength(700)] string? Description, ulong? CategoryId, ulong BaseUnitId, [Required] string Kind, bool PurchaseEnabled, bool SaleEnabled, bool ManufactureEnabled, [Required] string TrackingMode, bool ExpiryRequired, bool IsActive, ulong ExpectedVersion, [Required, MaxLength(300)] string Reason, [Required] IReadOnlyList<ItemUnitEdit> Units);
public sealed record ConversionInput(ulong ItemUnitId, decimal Quantity);
public interface ICatalogStore
{
    Task<IReadOnlyList<Unit>> UnitsAsync(SessionData session, CancellationToken ct);
    Task<Unit> SaveUnitAsync(SessionData session, ulong? id, UnitEdit edit, string correlation, CancellationToken ct);
    Task InitializeUnitsAsync(SessionData session, string correlation, CancellationToken ct);
    Task<IReadOnlyList<Category>> CategoriesAsync(SessionData session, CancellationToken ct);
    Task<Category> SaveCategoryAsync(SessionData session, ulong? id, CategoryEdit edit, string correlation, CancellationToken ct);
    Task<IReadOnlyList<Product>> ProductsAsync(SessionData session, CancellationToken ct);
    Task<ProductDetail> ProductAsync(SessionData session, ulong id, CancellationToken ct);
    Task<ProductDetail> SaveProductAsync(SessionData session, ulong? id, ProductEdit edit, string correlation, CancellationToken ct);
    Task<ProductDetail> BarcodeAsync(SessionData session, string value, CancellationToken ct);
    Task<decimal> ConvertAsync(SessionData session, ulong productId, ConversionInput input, CancellationToken ct);
    Task<IReadOnlyList<Supplier>> SuppliersAsync(SessionData session, CancellationToken ct);
    Task<Supplier> SaveSupplierAsync(SessionData session, ulong? id, SupplierEdit edit, string correlation, CancellationToken ct);
}
