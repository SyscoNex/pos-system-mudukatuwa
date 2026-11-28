using System.Text.Json.Serialization;
using Conex360.Domain.Identity;

namespace Conex360.Application.Inventory;

public sealed class InventorySettings
{
    public bool ManufacturingEnabled { get; set; }
    public bool StockOperationsEnabled { get; set; }
    public bool Enabled { get; set; }
}

public sealed record ReceiptLine(ulong ItemId, ulong ItemUnitId, ulong ItemVersion, ulong UnitVersion,
    decimal Quantity, decimal? EnteredUnitCost, bool ConfirmZeroCost, string Condition,
    string? LotCode, string? SupplierLot, DateOnly? ManufacturedOn, DateOnly? ExpiresOn);

public sealed record ReceiptInput(Guid OperationId, ulong WarehouseId, ulong WarehouseVersion, string ExpectedCurrency,
    DateOnly BusinessDate, ulong? SupplierId, string? SupplierReference, string? Notes, IReadOnlyList<ReceiptLine> Lines);

public sealed record ReceiptPreviewLine(string Sku, string Name, decimal BaseQuantity, decimal BaseUnitCost, decimal CarriedValue);
public sealed record ReceiptPreview(IReadOnlyList<ReceiptPreviewLine> Lines, decimal DisplayTotal, string Currency);
public sealed record PostedReceipt(ulong Id, string Number);
public sealed record InventoryWarehouse(ulong Id, ulong BranchId, string Name, ulong Version);

public sealed record StockRow(ulong Id, ulong WarehouseId, string Warehouse, string Sku, string Product,
    string BaseUnit, string Lot, DateOnly? ManufacturedOn, DateOnly? ExpiresOn, string Condition,
    bool Blocked, bool Expired, decimal OnHand, decimal Available,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? OperationalValue,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? AverageCost)
{
    public decimal Reserved { get; init; }
    public ulong ItemId { get; init; }
}

public sealed record StockMovement(ulong Id, ulong DocumentId, string Number, string Warehouse, string Sku,
    string Lot, string Condition, DateTimeOffset PostedAt, decimal Quantity,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? Value);

public sealed record ReceiptSummary(ulong Id, string Number, string Type, string Warehouse, DateOnly BusinessDate,
    DateTimeOffset PostedAt, string Currency, string? Supplier, string? SupplierReference,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? DisplayTotal);

public sealed record PostedLine(string Sku, string Name, string Unit, string Lot, string? SupplierLot,
    DateOnly? ManufacturedOn, DateOnly? ExpiresOn, string Condition, decimal Quantity, decimal Factor, decimal BaseQuantity,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? EnteredUnitCost,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? CarriedValue);

public sealed record ReceiptDetail(ReceiptSummary Document, string? Notes, IReadOnlyList<PostedLine> Lines);
public sealed record BalanceDifference(ulong BucketId, decimal LedgerQuantity, decimal? ProjectedQuantity, decimal LedgerValue, decimal? ProjectedValue);

public sealed record StockQuery(ulong? WarehouseId, ulong? ItemId, ulong? CategoryId, string? Batch, string? Expiry, ulong? After);

public interface IInventoryStore
{
    Task<IReadOnlyList<InventoryWarehouse>> WarehousesAsync(SessionData session, CancellationToken ct);
    Task<ReceiptPreview> PreviewAsync(SessionData session, bool opening, ReceiptInput input, CancellationToken ct);
    Task<PostedReceipt> PostAsync(SessionData session, bool opening, ReceiptInput input, string correlation, CancellationToken ct);
    Task<IReadOnlyList<StockRow>> StockAsync(SessionData session, StockQuery query, CancellationToken ct);
    Task<IReadOnlyList<StockMovement>> MovementsAsync(SessionData session, ulong? warehouseId, ulong? before, CancellationToken ct);
    Task<IReadOnlyList<ReceiptSummary>> DocumentsAsync(SessionData session, ulong? warehouseId, string? type, ulong? before, CancellationToken ct);
    Task<ReceiptDetail> DocumentAsync(SessionData session, ulong id, CancellationToken ct);
    Task<IReadOnlyList<BalanceDifference>> ReconcileAsync(SessionData session, ulong? warehouseId, ulong? after, CancellationToken ct);
}
