using System.Text.Json.Serialization;
using Conex360.Domain.Identity;

namespace Conex360.Application.Inventory;

public sealed record TransferLineInput(ulong ItemId, ulong ItemUnitId, ulong ItemVersion, ulong UnitVersion, decimal Quantity);
public sealed record TransferRequestInput(Guid OperationId, ulong SourceWarehouseId, ulong DestinationWarehouseId,
    string? Reference, string? Notes, IReadOnlyList<TransferLineInput> Lines);
public sealed record StockStep(Guid OperationId, string? Reason);
public sealed record AllocationQuantity(ulong Id, decimal Quantity, string? Condition);
public sealed record AllocationInput(Guid OperationId, IReadOnlyList<AllocationQuantity> Lines, string? Reason);
public sealed record TransferWarehouse(ulong Id, string Name, string Outlet, bool Authorized);
public sealed record TransferSummary(ulong Id, string Number, ulong SourceId, string Source, ulong DestinationId,
    string Destination, string? Reference, bool Confirmed, bool Cancelled, bool SourceAccess, bool DestinationAccess);
public sealed record TransferProgress(ulong Id, string Sku, string Unit, decimal Requested, decimal Reserved, decimal Dispatched,
    decimal Received, decimal Lost, decimal Returned, decimal Cancelled, decimal InTransit);
public sealed record ReservationView(ulong Id, string Sku, string Lot, decimal Remaining);
public sealed record DispatchView(ulong Id, string Sku, string Lot, DateOnly? ExpiresOn, decimal Shipped, decimal Outstanding,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? OutstandingValue);
public sealed record TransferDetail(TransferSummary Transfer, IReadOnlyList<TransferProgress> Lines,
    IReadOnlyList<ReservationView> Reservations, IReadOnlyList<DispatchView> Dispatches);
public sealed record StockChangeInput(Guid OperationId, ulong WarehouseId, ulong WarehouseVersion, string ExpectedCurrency,
    string Reason, string? Notes, ReceiptLine? Incoming, ulong? BucketId, ulong? ItemUnitId, ulong? ItemVersion, ulong? UnitVersion, decimal? Quantity);
public sealed record CountStart(Guid OperationId, ulong WarehouseId);
public sealed record CountActual(ulong BucketId, decimal Quantity, decimal? PositiveUnitCost, bool ConfirmZeroCost);
public sealed record CountSave(ulong Version, IReadOnlyList<CountActual> Lines);
public sealed record CountFinish(Guid OperationId, ulong Version, string Reason, string ExpectedCurrency, IReadOnlyList<ReceiptLine>? Unexpected);
public sealed record CountSummary(ulong Id, ulong WarehouseId, string Number, string Warehouse, string Status, ulong Version);
public sealed record CountLineView(ulong BucketId, string Sku, string Lot, string Unit, string Condition, decimal Expected, decimal? Actual,
    decimal? Variance, [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] decimal? PositiveUnitCost);
public sealed record CountDetail(CountSummary Count, IReadOnlyList<CountLineView> Lines);
public sealed record StockOperationDifference(string Kind, ulong Id);

public interface IStockOperations
{
    Task<IReadOnlyList<TransferWarehouse>> TransferWarehousesAsync(SessionData session, CancellationToken ct);
    Task<IReadOnlyList<TransferSummary>> TransfersAsync(SessionData session, ulong? before, CancellationToken ct);
    Task<TransferDetail> TransferAsync(SessionData session, ulong id, CancellationToken ct);
    Task<PostedReceipt> RequestAsync(SessionData session, TransferRequestInput input, string correlation, CancellationToken ct);
    Task<PostedReceipt> TransferStepAsync(SessionData session, ulong id, string action, StockStep input, string correlation, CancellationToken ct);
    Task<PostedReceipt> AllocationAsync(SessionData session, ulong id, string action, AllocationInput input, string correlation, CancellationToken ct);
    Task<PostedReceipt> ChangeAsync(SessionData session, bool waste, StockChangeInput input, string correlation, CancellationToken ct);
    Task<IReadOnlyList<CountSummary>> CountsAsync(SessionData session, ulong? before, CancellationToken ct);
    Task<CountDetail> CountAsync(SessionData session, ulong id, CancellationToken ct);
    Task<PostedReceipt> StartCountAsync(SessionData session, CountStart input, string correlation, CancellationToken ct);
    Task<CountSummary> SaveCountAsync(SessionData session, ulong id, CountSave input, string correlation, CancellationToken ct);
    Task<PostedReceipt> FinishCountAsync(SessionData session, ulong id, bool cancel, CountFinish input, string correlation, CancellationToken ct);
    Task<IReadOnlyList<StockOperationDifference>> ReconcileOperationsAsync(SessionData session, CancellationToken ct);
}
