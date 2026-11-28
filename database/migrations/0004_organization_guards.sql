CREATE TRIGGER branches_scope_guard BEFORE UPDATE ON branches FOR EACH ROW
BEGIN
 IF NEW.id<>OLD.id OR NEW.tenant_id<>OLD.tenant_id OR NEW.company_id<>OLD.company_id OR NEW.created_at<>OLD.created_at THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Organization identity is immutable'; END IF;
 
END;
-- statement-break
CREATE TRIGGER branches_no_delete BEFORE DELETE ON branches FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use audited deactivation';
-- statement-break
CREATE TRIGGER warehouses_scope_guard BEFORE UPDATE ON warehouses FOR EACH ROW
BEGIN
 IF NEW.id<>OLD.id OR NEW.tenant_id<>OLD.tenant_id OR NEW.company_id<>OLD.company_id OR NOT(NEW.branch_id <=> OLD.branch_id) OR NEW.kind<>OLD.kind OR NEW.created_at<>OLD.created_at THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Organization identity is immutable'; END IF;
 IF OLD.kind='TRANSIT' THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Canonical transit is immutable'; END IF;
END;
-- statement-break
CREATE TRIGGER warehouses_no_delete BEFORE DELETE ON warehouses FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use audited deactivation';
-- statement-break
CREATE TRIGGER locations_scope_guard BEFORE UPDATE ON locations FOR EACH ROW
BEGIN
 IF NEW.id<>OLD.id OR NEW.tenant_id<>OLD.tenant_id OR NEW.company_id<>OLD.company_id OR NEW.warehouse_id<>OLD.warehouse_id OR NEW.warehouse_kind<>OLD.warehouse_kind OR NEW.kind<>OLD.kind OR NEW.created_at<>OLD.created_at THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Organization identity is immutable'; END IF;
 
END;
-- statement-break
CREATE TRIGGER locations_no_delete BEFORE DELETE ON locations FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use audited deactivation';
-- statement-break
CREATE TRIGGER membership_branches_scope_guard BEFORE UPDATE ON membership_branches FOR EACH ROW
BEGIN
 IF NEW.tenant_id<>OLD.tenant_id OR NEW.company_id<>OLD.company_id OR NEW.membership_id<>OLD.membership_id OR NEW.branch_id<>OLD.branch_id OR NEW.created_at<>OLD.created_at THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Organization identity is immutable'; END IF;
 
END;
-- statement-break
CREATE TRIGGER membership_branches_no_delete BEFORE DELETE ON membership_branches FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Use audited deactivation';
