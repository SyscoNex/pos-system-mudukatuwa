CREATE TRIGGER audit_events_no_update BEFORE UPDATE ON audit_events FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit events are immutable';
-- statement-break
CREATE TRIGGER audit_events_no_delete BEFORE DELETE ON audit_events FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit events are immutable';
-- statement-break
CREATE TRIGGER security_events_no_update BEFORE UPDATE ON security_events FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Security events are immutable';
-- statement-break
CREATE TRIGGER security_events_no_delete BEFORE DELETE ON security_events FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Security events are immutable';
-- statement-break
CREATE TRIGGER companies_identity_guard BEFORE UPDATE ON companies FOR EACH ROW
BEGIN
  IF NEW.id <> OLD.id OR NEW.tenant_id <> OLD.tenant_id OR NEW.created_at <> OLD.created_at THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Company identity is immutable';
  END IF;
  IF OLD.currency_locked_at IS NOT NULL AND (NEW.currency_code <> OLD.currency_code OR NEW.currency_minor_units <> OLD.currency_minor_units OR NEW.currency_locked_at IS NULL) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Used currency cannot be changed';
  END IF;
END;
-- statement-break
CREATE TRIGGER memberships_identity_guard BEFORE UPDATE ON tenant_memberships FOR EACH ROW
BEGIN
  IF NEW.id <> OLD.id OR NEW.tenant_id <> OLD.tenant_id OR NEW.user_id <> OLD.user_id OR NEW.created_at <> OLD.created_at THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Membership identity is immutable';
  END IF;
END;
-- statement-break
CREATE TRIGGER sessions_identity_guard BEFORE UPDATE ON auth_sessions FOR EACH ROW
BEGIN
  IF NEW.id <> OLD.id OR NEW.public_id <> OLD.public_id OR NEW.session_key_hash <> OLD.session_key_hash OR NEW.user_id <> OLD.user_id OR NEW.user_security_stamp <> OLD.user_security_stamp OR NEW.absolute_expires_at <> OLD.absolute_expires_at OR NEW.created_at <> OLD.created_at THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Session identity and absolute expiry are immutable';
  END IF;
  IF OLD.revoked_at IS NOT NULL AND (NEW.revoked_at IS NULL OR NEW.revoked_at <> OLD.revoked_at) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Revoked sessions cannot be restored';
  END IF;
END;
-- statement-break
CREATE TRIGGER tenants_identity_guard BEFORE UPDATE ON tenants FOR EACH ROW
BEGIN
  IF NEW.id <> OLD.id OR NEW.public_id <> OLD.public_id OR NEW.provisioning_operation_id <> OLD.provisioning_operation_id OR NEW.code <> OLD.code OR NEW.created_at <> OLD.created_at THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tenant identity is immutable';
  END IF;
END;
-- statement-break
CREATE TRIGGER users_identity_guard BEFORE UPDATE ON users FOR EACH ROW
BEGIN
  IF NEW.id <> OLD.id OR NEW.public_id <> OLD.public_id OR NEW.email_normalized <> OLD.email_normalized OR NEW.created_at <> OLD.created_at THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User identity is immutable';
  END IF;
END;
