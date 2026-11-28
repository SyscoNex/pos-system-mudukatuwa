using Conex360.Application.Catalog;
using Conex360.Application.Identity;
using Conex360.Application.Inventory;
using Conex360.Application.Organization;
using Conex360.Domain.Identity;
using Microsoft.Extensions.DependencyInjection;
using MySqlConnector;

namespace Conex360.IntegrationTests;

public sealed class StockOperationMySqlFactAttribute : FactAttribute
{
    public StockOperationMySqlFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("CONEX360_MYSQL_APPROVED") != "1" ||
            Environment.GetEnvironmentVariable("CONEX360_STOCK_OPERATIONS_MYSQL_APPROVED") != "1")
            Skip = "Requires separately approved P1-06 migrations and synthetic MySQL target.";
    }
}

public sealed partial class MySqlIdentityTests
{
    [StockOperationMySqlFact]
    public async Task StockOperationsConserveAllocationsAndFreezeAllPosting()
    {
        var services = f.App.Services;
        var inventorySettings = services.GetRequiredService<InventorySettings>();
        var catalogueSettings = services.GetRequiredService<CatalogSettings>();
        var orgSettings = services.GetRequiredService<OrganizationSettings>();
        var flags = (inventorySettings.Enabled, inventorySettings.StockOperationsEnabled, catalogueSettings.Enabled, orgSettings.Enabled);
        inventorySettings.Enabled = inventorySettings.StockOperationsEnabled = catalogueSettings.Enabled = orgSettings.Enabled = true;
        try
        {
            var ops = services.GetRequiredService<IStockOperations>();
            var inv = services.GetRequiredService<IInventoryStore>();
            var catalogue = services.GetRequiredService<ICatalogStore>();
            var org = services.GetRequiredService<IOrganizationStore>();
            var admin = (await f.Login()).Data;
            var tenant = admin.Selected!.TenantId;
            var sourceOutlet = await org.SaveOutletAsync(admin, null, new("P106-SOURCE", "Transfer Source", null, null, null, true, 0, "Fixture"), "test", default);
            var destinationOutlet = await org.SaveOutletAsync(admin, null, new("P106-DEST", "Transfer Destination", null, null, null, true, 0, "Fixture"), "test", default);
            var source = Assert.Single(await org.WarehousesAsync(admin, sourceOutlet.Id, default));
            var destination = Assert.Single(await org.WarehousesAsync(admin, destinationOutlet.Id, default));
            await catalogue.InitializeUnitsAsync(admin, "test", default);
            var piece = (await catalogue.UnitsAsync(admin, default)).Single(x => x.Code == "EA");
            var product = await catalogue.SaveProductAsync(admin, null, new("P106-ITEM", "Transfer Fixture", null, null, piece.Id,
                "RAW", true, false, false, "LOT", true, true, 0, "Fixture",
                [new(null, piece.Id, 1, null, null, true, false, true, 0, [])]), "test", default);
            var unit = Assert.Single(product.Units);
            var supplier = await catalogue.SaveSupplierAsync(admin, null, new("P106-SUP", "Transfer Fixture Supplier", null, null, null,
                null, null, true, 0, "Fixture"), "test", default);
            var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, TimeZoneInfo.FindSystemTimeZoneById("Asia/Colombo")).DateTime);
            var seed = new ReceiptLine(product.Product.Id, unit.Id, product.Product.Version, unit.Version, 100, 2, false, "AVAILABLE",
                "P106-LOT", null, today, today.AddDays(1));
            var opening = new ReceiptInput(Guid.NewGuid(), source.Id, source.Version, "LKR", today, null, null, null, [seed]);
            await inv.PostAsync(admin, true, opening, "test", default);
            await inv.PostAsync(admin, true, opening with
            {
                OperationId = Guid.NewGuid(),
                WarehouseId = destination.Id,
                WarehouseVersion = destination.Version,
                Lines = [seed with { Quantity = 20, EnteredUnitCost = 3 }]
            }, "test", default);
            var transit = Convert.ToUInt64(await f.Sql("SELECT id FROM warehouses WHERE tenant_id=@tenant AND kind='TRANSIT'", ("tenant", tenant)));
            Assert.DoesNotContain(await inv.WarehousesAsync(admin, default), w => w.Id == transit);
            Assert.Empty(await inv.StockAsync(admin, new(transit, null, null, null, null, null), default));

            var staff = await org.CreateStaffAsync(admin, new(Guid.NewGuid().ToString("N") + "@example.invalid", "Receiving Staff", [destinationOutlet.Id], "Fixture"), "test", default);
            var login = await f.Service.LoginAsync(staff.Email, staff.TemporaryPassword, "test", default);
            var receiver = (await f.Service.ChangePasswordAsync(login.Data, staff.TemporaryPassword, SessionSecrets.Create(), "test", default)).Data;

            TransferRequestInput Request(ulong from, ulong to, decimal amount) => new(Guid.NewGuid(), from, to, "Fixture", null,
                [new(product.Product.Id, unit.Id, product.Product.Version, unit.Version, amount)]);
            StockStep Step() => new(Guid.NewGuid(), "Fixture");
            AllocationInput Part(ulong id, decimal quantity, string? condition = null) => new(Guid.NewGuid(), [new(id, quantity, condition)], "Fixture");
            Task<TransferDetail> Detail(ulong id) => ops.TransferAsync(admin, id, default);
            async Task<StockRow> Balance(ulong warehouse, string condition = "AVAILABLE") =>
                Assert.Single((await inv.StockAsync(admin, new(warehouse, product.Product.Id, null, "P106-LOT", null, null), default)), x => x.Condition == condition);
            async Task<bool> Try(Func<Task> operation)
            {
                try { await operation(); return true; }
                catch (AppFailure) { return false; }
            }

            var input = Request(source.Id, destination.Id, 30);
            var requests = await Task.WhenAll(ops.RequestAsync(receiver, input, "test", default), ops.RequestAsync(receiver, input, "test", default));
            var request = requests[0];
            Assert.Equal(request, requests[1]);
            await Assert.ThrowsAsync<AppFailure>(() => ops.RequestAsync(receiver, input with { Notes = "Altered" }, "test", default));
            await Assert.ThrowsAsync<AppFailure>(() => ops.TransferStepAsync(receiver, request.Id, "confirm", Step(), "test", default));
            var foreign = (await f.Login(f.Shared.MembershipId)).Data;
            await Assert.ThrowsAsync<AppFailure>(() => ops.TransferAsync(foreign, request.Id, default));

            var competing = await ops.RequestAsync(receiver, Request(source.Id, destination.Id, 90), "test", default);
            await ops.TransferStepAsync(admin, request.Id, "confirm", Step(), "test", default);
            var reserveAttempt = ops.TransferStepAsync(admin, competing.Id, "confirm", Step(), "test", default);
            await Assert.ThrowsAsync<AppFailure>(() => reserveAttempt);
            await ops.TransferStepAsync(admin, competing.Id, "cancel", Step(), "test", default);
            var before = await Balance(source.Id);
            Assert.Equal(100m, before.OnHand);
            Assert.Equal(30m, before.Reserved);
            Assert.Equal(70m, before.Available);
            var sourceIssue = new StockChangeInput(Guid.NewGuid(), source.Id, source.Version, "LKR", "Disposal", null, null,
                before.Id, unit.Id, product.Product.Version, unit.Version, 71);
            await Assert.ThrowsAsync<AppFailure>(() => ops.ChangeAsync(admin, true, sourceIssue, "test", default));

            var reservation = Assert.Single((await Detail(request.Id)).Reservations);
            var rollback = new AllocationInput(Guid.NewGuid(), [new(reservation.Id, 1, null), new(ulong.MaxValue, 1, null)], "Fixture");
            await Assert.ThrowsAsync<AppFailure>(() => ops.AllocationAsync(admin, request.Id, "dispatch", rollback, "test", default));
            Assert.Equal(before, await Balance(source.Id));
            var dispatches = await Task.WhenAll(
                Try(() => ops.AllocationAsync(admin, request.Id, "dispatch", Part(reservation.Id, 30), "test", default)),
                Try(() => ops.AllocationAsync(admin, request.Id, "dispatch", Part(reservation.Id, 30), "test", default)));
            Assert.Single(dispatches, x => x);
            var allocation = Assert.Single((await Detail(request.Id)).Dispatches);
            Assert.Equal(60m, allocation.OutstandingValue);
            var manifest = await ops.TransferAsync(receiver, request.Id, default);
            Assert.Null(Assert.Single(manifest.Dispatches).OutstandingValue);
            Assert.Empty(manifest.Reservations);

            var received = Part(allocation.Id, 20, "AVAILABLE");
            var receipt = await ops.AllocationAsync(receiver, request.Id, "receive", received, "test", default);
            Assert.Equal(receipt, await ops.AllocationAsync(receiver, request.Id, "receive", received, "test", default));
            Assert.Equal(40m, Convert.ToDecimal(await f.Sql("SELECT carried_value FROM transfer_receipt_allocations WHERE receipt_id=@id", ("id", receipt.Id))));
            var receiptRace = await Task.WhenAll(
                Try(() => ops.AllocationAsync(receiver, request.Id, "receive", Part(allocation.Id, 8, "AVAILABLE"), "test", default)),
                Try(() => ops.AllocationAsync(receiver, request.Id, "receive", Part(allocation.Id, 8, "AVAILABLE"), "test", default)));
            Assert.Single(receiptRace, x => x);
            Assert.Equal(4m, Assert.Single((await Detail(request.Id)).Dispatches).OutstandingValue);
            await ops.AllocationAsync(admin, request.Id, "loss", Part(allocation.Id, 2), "test", default);
            Assert.Equal(70m, (await Balance(source.Id)).OnHand);
            Assert.Equal(48m, (await Balance(destination.Id)).OnHand);
            Assert.Equal(116m, (await Balance(destination.Id)).OperationalValue);
            Assert.Equal(0m, Assert.Single((await Detail(request.Id)).Lines).InTransit);
            Assert.Empty(await ops.ReconcileOperationsAsync(admin, default));

            var reverse = await ops.RequestAsync(admin, Request(destination.Id, source.Id, 3), "test", default);
            var partial = await ops.RequestAsync(admin, Request(source.Id, destination.Id, 3), "test", default);
            foreach (var x in new[] { reverse, partial })
            {
                await ops.TransferStepAsync(admin, x.Id, "confirm", Step(), "test", default);
                var r = Assert.Single((await Detail(x.Id)).Reservations);
                await ops.AllocationAsync(admin, x.Id, "dispatch", Part(r.Id, 3), "test", default);
            }
            var a = Assert.Single((await Detail(reverse.Id)).Dispatches);
            var b = Assert.Single((await Detail(partial.Id)).Dispatches);
            Assert.Equal(7.25m, a.OutstandingValue);
            Assert.Equal(6m, b.OutstandingValue);
            await ops.AllocationAsync(admin, reverse.Id, "receive", Part(a.Id, 1, "DAMAGED"), "test", default);
            await ops.AllocationAsync(admin, reverse.Id, "return", Part(a.Id, 2), "test", default);
            await ops.AllocationAsync(admin, partial.Id, "receive", Part(b.Id, 3, "HOLD"), "test", default);
            Assert.Equal(2.416667m, (await Balance(source.Id, "DAMAGED")).OperationalValue);
            Assert.Equal(10.833333m, (await Balance(destination.Id, "HOLD")).OperationalValue);

            var activeRequest = await ops.RequestAsync(admin, Request(source.Id, destination.Id, 2), "test", default);
            await ops.TransferStepAsync(admin, activeRequest.Id, "confirm", Step(), "test", default);
            var count = await ops.StartCountAsync(admin, new(Guid.NewGuid(), source.Id), "test", default);
            var grn = opening with { OperationId = Guid.NewGuid(), SupplierId = supplier.Id, Lines = [seed with { Quantity = 1 }] };
            await Assert.ThrowsAsync<AppFailure>(() => inv.PostAsync(admin, false, grn, "test", default));
            await Assert.ThrowsAsync<AppFailure>(() => ops.TransferStepAsync(admin, activeRequest.Id, "cancel", Step(), "test", default));
            var counted = await ops.CountAsync(admin, count.Id, default);
            await Assert.ThrowsAsync<AppFailure>(() => ops.FinishCountAsync(admin, count.Id, false,
                new(Guid.NewGuid(), counted.Count.Version, "Review", "LKR", null), "test", default));
            var recorded = await ops.SaveCountAsync(admin, count.Id, new(counted.Count.Version,
                counted.Lines.Select(x => new CountActual(x.BucketId, x.Condition == "AVAILABLE" ? 0 : x.Expected, null, false)).ToArray()), "test", default);
            var tooLow = await Assert.ThrowsAsync<AppFailure>(() => ops.FinishCountAsync(admin, count.Id, false,
                new(Guid.NewGuid(), recorded.Version, "Review", "LKR", null), "test", default));
            Assert.Contains(activeRequest.Number, tooLow.Message);
            await ops.FinishCountAsync(admin, count.Id, true, new(Guid.NewGuid(), recorded.Version, "Recount", "LKR", null), "test", default);
            await ops.TransferStepAsync(admin, activeRequest.Id, "cancel", Step(), "test", default);

            var priorPhysical = (await Balance(source.Id)).OnHand;
            var newCountTask = ops.StartCountAsync(admin, new(Guid.NewGuid(), source.Id), "test", default);
            var incomingTask = Try(() => inv.PostAsync(admin, false, grn, "test", default));
            var secondCount = await newCountTask;
            var receiptWon = await incomingTask;
            var snapshot = await ops.CountAsync(admin, secondCount.Id, default);
            Assert.Equal(priorPhysical + (receiptWon ? 1 : 0), snapshot.Lines.Single(x => x.Condition == "AVAILABLE").Expected);
            var actual = await ops.SaveCountAsync(admin, secondCount.Id, new(snapshot.Count.Version, snapshot.Lines.Select(x =>
                new CountActual(x.BucketId, x.Expected - (x.Condition == "AVAILABLE" ? 1 : 0), null, false)).ToArray()), "test", default);
            var finish = new CountFinish(Guid.NewGuid(), actual.Version, "Variance verified", "LKR", null);
            var posted = await ops.FinishCountAsync(admin, secondCount.Id, false, finish, "test", default);
            Assert.Equal(posted, await ops.FinishCountAsync(admin, secondCount.Id, false, finish, "test", default));
            Assert.Equal(1UL, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM stock_entries WHERE document_id=@id", ("id", posted.Id))));

            await ops.ChangeAsync(admin, false, sourceIssue with
            {
                OperationId = Guid.NewGuid(),
                BucketId = null,
                ItemUnitId = null,
                Quantity = null,
                Incoming = seed with { Quantity = 2, EnteredUnitCost = 4 }
            }, "test", default);
            var damaged = await Balance(source.Id, "DAMAGED");
            await ops.ChangeAsync(admin, true, sourceIssue with { OperationId = Guid.NewGuid(), BucketId = damaged.Id, Quantity = 1 }, "test", default);
            Assert.Equal(0m, (await Balance(source.Id, "DAMAGED")).OperationalValue);

            var earliestZone = TimeZoneInfo.FindSystemTimeZoneById("Etc/GMT+12");
            var expiry = DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, earliestZone).DateTime);
            // Advance the business date using only this synthetic company's timezone.
            await f.Sql("UPDATE companies SET timezone=@zone WHERE tenant_id=@tenant", ("zone", earliestZone.Id), ("tenant", tenant));
            try
            {
                await ops.ChangeAsync(admin, false, sourceIssue with
                {
                    OperationId = Guid.NewGuid(),
                    BucketId = null,
                    ItemUnitId = null,
                    Quantity = null,
                    Incoming = seed with { Quantity = 1, LotCode = "P106-EXPIRING", ManufacturedOn = null, ExpiresOn = expiry }
                }, "test", default);
                var expiring = await ops.RequestAsync(admin, Request(source.Id, destination.Id, 1), "test", default);
                await ops.TransferStepAsync(admin, expiring.Id, "confirm", Step(), "test", default);
                var expiringReservation = Assert.Single((await Detail(expiring.Id)).Reservations);
                Assert.Equal("P106-EXPIRING", expiringReservation.Lot);
                await ops.AllocationAsync(admin, expiring.Id, "dispatch", Part(expiringReservation.Id, 1), "test", default);
                await f.Sql("UPDATE companies SET timezone='Pacific/Kiritimati' WHERE tenant_id=@tenant", ("tenant", tenant));
                var expiringAllocation = Assert.Single((await Detail(expiring.Id)).Dispatches);
                await Assert.ThrowsAsync<AppFailure>(() => ops.AllocationAsync(receiver, expiring.Id, "receive", Part(expiringAllocation.Id, 1, "AVAILABLE"), "test", default));
                await ops.AllocationAsync(receiver, expiring.Id, "receive", Part(expiringAllocation.Id, 1, "HOLD"), "test", default);
                var expired = Assert.Single(await inv.StockAsync(admin, new(destination.Id, product.Product.Id, null, "P106-EXPIRING", null, null), default));
                Assert.True(expired.Expired);
                Assert.Equal(0m, expired.Available);
            }
            finally
            {
                await f.Sql("UPDATE companies SET timezone='Asia/Colombo' WHERE tenant_id=@tenant", ("tenant", tenant));
            }
            Assert.Empty(await ops.ReconcileOperationsAsync(admin, default));
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("UPDATE transfer_dispatch_allocations SET quantity=1 WHERE id=@id", ("id", allocation.Id)));
        }
        finally
        {
            (inventorySettings.Enabled, inventorySettings.StockOperationsEnabled, catalogueSettings.Enabled, orgSettings.Enabled) = flags;
        }
    }
}
