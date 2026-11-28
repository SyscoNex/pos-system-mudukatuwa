CREATE TRIGGER units_identity_guard BEFORE UPDATE ON units FOR EACH ROW
BEGIN
 IF NEW.id<>OLD.id OR NEW.tenant_id<>OLD.tenant_id OR NEW.company_id<>OLD.company_id OR NEW.created_at<>OLD.created_at THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Catalog identity/ownership is immutable'; END IF;
END;
-- statement-break
CREATE TRIGGER units_no_delete BEFORE DELETE ON units FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use audited deactivation';
-- statement-break
CREATE TRIGGER item_categories_identity_guard BEFORE UPDATE ON item_categories FOR EACH ROW
BEGIN
 IF NEW.id<>OLD.id OR NEW.tenant_id<>OLD.tenant_id OR NEW.company_id<>OLD.company_id OR NEW.created_at<>OLD.created_at THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Catalog identity/ownership is immutable'; END IF;
END;
-- statement-break
CREATE TRIGGER item_categories_no_delete BEFORE DELETE ON item_categories FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use audited deactivation';
-- statement-break
CREATE TRIGGER items_identity_guard BEFORE UPDATE ON items FOR EACH ROW
BEGIN
 IF NEW.id<>OLD.id OR NEW.tenant_id<>OLD.tenant_id OR NEW.company_id<>OLD.company_id OR NEW.created_at<>OLD.created_at OR NEW.base_unit_id<>OLD.base_unit_id THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Catalog identity/ownership is immutable'; END IF;
END;
-- statement-break
CREATE TRIGGER items_no_delete BEFORE DELETE ON items FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use audited deactivation';
-- statement-break
CREATE TRIGGER item_units_identity_guard BEFORE UPDATE ON item_units FOR EACH ROW
BEGIN
 IF NEW.id<>OLD.id OR NEW.tenant_id<>OLD.tenant_id OR NEW.company_id<>OLD.company_id OR NEW.created_at<>OLD.created_at OR NEW.item_id<>OLD.item_id OR NEW.unit_id<>OLD.unit_id OR NEW.base_unit_id<>OLD.base_unit_id THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Catalog identity/ownership is immutable'; END IF;
END;
-- statement-break
CREATE TRIGGER item_units_no_delete BEFORE DELETE ON item_units FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use audited deactivation';
-- statement-break
CREATE TRIGGER item_barcodes_identity_guard BEFORE UPDATE ON item_barcodes FOR EACH ROW
BEGIN
 IF NEW.id<>OLD.id OR NEW.tenant_id<>OLD.tenant_id OR NEW.company_id<>OLD.company_id OR NEW.created_at<>OLD.created_at OR NEW.item_id<>OLD.item_id THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Catalog identity/ownership is immutable'; END IF;
END;
-- statement-break
CREATE TRIGGER item_barcodes_no_delete BEFORE DELETE ON item_barcodes FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use audited deactivation';
-- statement-break
CREATE TRIGGER parties_identity_guard BEFORE UPDATE ON parties FOR EACH ROW
BEGIN
 IF NEW.id<>OLD.id OR NEW.tenant_id<>OLD.tenant_id OR NEW.company_id<>OLD.company_id OR NEW.created_at<>OLD.created_at THEN
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Catalog identity/ownership is immutable'; END IF;
END;
-- statement-break
CREATE TRIGGER parties_no_delete BEFORE DELETE ON parties FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use audited deactivation';
