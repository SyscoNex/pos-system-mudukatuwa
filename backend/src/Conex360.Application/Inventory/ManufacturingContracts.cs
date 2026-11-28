using System.Text.Json.Serialization;
using Conex360.Domain.Identity;

namespace Conex360.Application.Inventory;

public sealed record ProductionMaterial(ulong ItemId, ulong ItemUnitId, ulong ItemVersion, ulong UnitVersion,
    decimal Quantity, ulong? BucketId = null);
public sealed record ProductionOutput(ulong ItemId, ulong ItemUnitId, ulong ItemVersion, ulong UnitVersion,
    decimal Quantity, string? LotCode, DateOnly? ExpiresOn);
public sealed record ProductionInput(Guid OperationId, ulong WarehouseId, ulong WarehouseVersion, string ExpectedCurrency,
    DateOnly ProductionDate, string? Reference, string? Notes, IReadOnlyList<ProductionMaterial> Materials, ProductionOutput Output);
public sealed record ProductionAllocation(int Group, string Sku, string Product, string Unit, decimal EnteredQuantity, decimal Factor,
    decimal BaseQuantity, ulong LotId, string Lot, DateOnly? ExpiresOn,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? CarriedValue);
public sealed record ProductionPreview(IReadOnlyList<ProductionAllocation> Materials, decimal BaseOutputQuantity, string OutputSku, string Lot,
    string Currency, [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? TotalCost,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? OutputBaseUnitCost);
public sealed record ProductionRun(ulong Id, string Number, ulong WarehouseId, string Warehouse, DateOnly ProductionDate,
    string? Reference, string OutputSku, string OutputName, decimal OutputQuantity, string OutputUnit, decimal BaseOutputQuantity,
    ulong OutputLotId, string OutputLot, bool Tracked, DateOnly? ExpiresOn, string Currency,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? TotalCost,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? OutputBaseUnitCost);
public sealed record ProductionDetail(ProductionRun Run, string Operator, string? Notes, IReadOnlyList<ProductionAllocation> Materials);

public interface IManufacturingStore
{
    Task<ProductionPreview> PreviewProductionAsync(SessionData session, ProductionInput input, CancellationToken ct);
    Task<PostedReceipt> PostProductionAsync(SessionData session, ProductionInput input, string correlation, CancellationToken ct);
    Task<IReadOnlyList<ProductionRun>> ProductionRunsAsync(SessionData session, ulong? warehouse, ulong? inputLot, ulong? outputLot, ulong? before, CancellationToken ct);
    Task<ProductionDetail> ProductionAsync(SessionData session, ulong id, CancellationToken ct);
    Task<IReadOnlyList<StockOperationDifference>> ReconcileProductionAsync(SessionData session, CancellationToken ct);
}
