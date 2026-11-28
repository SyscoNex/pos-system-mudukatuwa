CREATE TRIGGER p105_documents_no_update
 BEFORE UPDATE ON documents FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_documents_no_delete
 BEFORE DELETE ON documents FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_document_lines_no_update
 BEFORE UPDATE ON document_lines FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_document_lines_no_delete
 BEFORE DELETE ON document_lines FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_goods_receipts_no_update
 BEFORE UPDATE ON goods_receipts FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_goods_receipts_no_delete
 BEFORE DELETE ON goods_receipts FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_lots_no_update
 BEFORE UPDATE ON lots FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_lots_no_delete
 BEFORE DELETE ON lots FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_stock_buckets_no_update
 BEFORE UPDATE ON stock_buckets FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_stock_buckets_no_delete
 BEFORE DELETE ON stock_buckets FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_stock_entries_no_update
 BEFORE UPDATE ON stock_entries FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_stock_entries_no_delete
 BEFORE DELETE ON stock_entries FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_idempotency_keys_no_update
 BEFORE UPDATE ON idempotency_keys FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
-- statement-break
CREATE TRIGGER p105_idempotency_keys_no_delete
 BEFORE DELETE ON idempotency_keys FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Inventory facts and identities cannot be rewritten';
