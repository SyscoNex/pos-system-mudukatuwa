CREATE TRIGGER p106_transfer_dispatch_allocations_update BEFORE UPDATE ON transfer_dispatch_allocations FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transfer allocation facts are immutable';
-- statement-break
CREATE TRIGGER p106_transfer_dispatch_allocations_delete BEFORE DELETE ON transfer_dispatch_allocations FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transfer allocation facts are immutable';
-- statement-break
CREATE TRIGGER p106_transfer_receipt_allocations_update BEFORE UPDATE ON transfer_receipt_allocations FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transfer allocation facts are immutable';
-- statement-break
CREATE TRIGGER p106_transfer_receipt_allocations_delete BEFORE DELETE ON transfer_receipt_allocations FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transfer allocation facts are immutable';
-- statement-break
CREATE TRIGGER p106_transfer_resolution_allocations_update BEFORE UPDATE ON transfer_resolution_allocations FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transfer allocation facts are immutable';
-- statement-break
CREATE TRIGGER p106_transfer_resolution_allocations_delete BEFORE DELETE ON transfer_resolution_allocations FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transfer allocation facts are immutable';
-- statement-break
CREATE TRIGGER p106_stock_transfers_delete BEFORE DELETE ON stock_transfers FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Stock operation history cannot be deleted';
-- statement-break
CREATE TRIGGER p106_stock_reservations_delete BEFORE DELETE ON stock_reservations FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Stock operation history cannot be deleted';
-- statement-break
CREATE TRIGGER p106_stock_counts_delete BEFORE DELETE ON stock_counts FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Stock operation history cannot be deleted';
-- statement-break
CREATE TRIGGER p106_stock_count_lines_delete BEFORE DELETE ON stock_count_lines FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Stock operation history cannot be deleted';
-- statement-break
CREATE TRIGGER p106_transfer_update BEFORE UPDATE ON stock_transfers FOR EACH ROW
BEGIN
 IF NOT (NEW.tenant_id=OLD.tenant_id AND NEW.company_id=OLD.company_id AND NEW.request_id=OLD.request_id
 AND NEW.source_warehouse_id=OLD.source_warehouse_id AND NEW.destination_warehouse_id=OLD.destination_warehouse_id
 AND BINARY NEW.source_name=BINARY OLD.source_name AND BINARY NEW.destination_name=BINARY OLD.destination_name
 AND (BINARY NEW.reference <=> BINARY OLD.reference)
 AND (OLD.confirmation_id IS NULL OR NEW.confirmation_id <=> OLD.confirmation_id)
 AND (OLD.cancellation_id IS NULL OR NEW.cancellation_id <=> OLD.cancellation_id))
 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Transfer facts cannot be rewritten'; END IF;
END;
-- statement-break
CREATE TRIGGER p106_reservation_update BEFORE UPDATE ON stock_reservations FOR EACH ROW
BEGIN
 IF NOT (NEW.id=OLD.id AND NEW.tenant_id=OLD.tenant_id AND NEW.company_id=OLD.company_id AND NEW.request_id=OLD.request_id
 AND NEW.request_line_id=OLD.request_line_id AND NEW.item_id=OLD.item_id AND NEW.bucket_id=OLD.bucket_id
 AND NEW.reserved_quantity=OLD.reserved_quantity AND NEW.consumed_quantity>=OLD.consumed_quantity AND NEW.released_quantity>=OLD.released_quantity)
 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Reservation identity and original allocation are immutable'; END IF;
END;
-- statement-break
CREATE TRIGGER p106_count_update BEFORE UPDATE ON stock_counts FOR EACH ROW
BEGIN
 IF NOT (OLD.status='COUNTING' AND NEW.tenant_id=OLD.tenant_id AND NEW.company_id=OLD.company_id
 AND NEW.count_id=OLD.count_id AND NEW.warehouse_id=OLD.warehouse_id AND NEW.row_version=OLD.row_version+1)
 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Count identity and terminal state are immutable'; END IF;
END;
-- statement-break
CREATE TRIGGER p106_count_line_update BEFORE UPDATE ON stock_count_lines FOR EACH ROW
BEGIN
 IF NOT (NEW.tenant_id=OLD.tenant_id AND NEW.company_id=OLD.company_id AND NEW.count_id=OLD.count_id
 AND NEW.warehouse_id=OLD.warehouse_id AND NEW.bucket_id=OLD.bucket_id AND NEW.item_id=OLD.item_id AND NEW.lot_id=OLD.lot_id
 AND NEW.stock_condition=OLD.stock_condition AND NEW.expected_quantity=OLD.expected_quantity AND NEW.expected_value=OLD.expected_value
 AND EXISTS (SELECT 1 FROM stock_counts c WHERE c.tenant_id=OLD.tenant_id AND c.company_id=OLD.company_id AND c.count_id=OLD.count_id AND c.status='COUNTING'))
 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Count snapshot or terminal count is immutable'; END IF;
END;
