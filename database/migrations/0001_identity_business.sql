-- P1-02 only. Separate review/target execution approval is mandatory.
-- Each statement-break delimits ONE command, including compound triggers in later files.
CREATE TABLE tenants (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  public_id BINARY(16) NOT NULL,
  provisioning_operation_id BINARY(16) NOT NULL,
  code VARCHAR(60) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  name VARCHAR(200) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  row_version BIGINT UNSIGNED NOT NULL DEFAULT 1,
  UNIQUE KEY uq_tenants_public (public_id),
  UNIQUE KEY uq_tenants_operation (provisioning_operation_id),
  UNIQUE KEY uq_tenants_code (code),
  CONSTRAINT ck_tenants_status CHECK (status IN ('ACTIVE','SUSPENDED')),
  CONSTRAINT ck_tenants_version CHECK (row_version > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  public_id BINARY(16) NOT NULL,
  email_normalized VARCHAR(254) COLLATE utf8mb4_0900_as_cs NOT NULL,
  display_name VARCHAR(120) NOT NULL,
  password_hash VARCHAR(512) NOT NULL,
  security_stamp BINARY(16) NOT NULL,
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  must_change_password BOOLEAN NOT NULL DEFAULT TRUE,
  failed_access_count INT UNSIGNED NOT NULL DEFAULT 0,
  lockout_until DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  row_version BIGINT UNSIGNED NOT NULL DEFAULT 1,
  UNIQUE KEY uq_users_public (public_id),
  UNIQUE KEY uq_users_email (email_normalized),
  CONSTRAINT ck_users_flags CHECK (is_enabled IN (0,1) AND must_change_password IN (0,1)),
  CONSTRAINT ck_users_version CHECK (row_version > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE companies (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  tenant_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(30) NOT NULL DEFAULT 'DEFAULT',
  business_name VARCHAR(200) NOT NULL,
  display_name VARCHAR(200) NOT NULL,
  phone VARCHAR(50) NULL,
  email VARCHAR(254) NULL,
  address VARCHAR(700) NULL,
  timezone VARCHAR(64) NOT NULL,
  currency_code CHAR(3) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  currency_minor_units TINYINT UNSIGNED NOT NULL,
  currency_locked_at DATETIME(6) NULL,
  logo_key VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  row_version BIGINT UNSIGNED NOT NULL DEFAULT 1,
  UNIQUE KEY uq_companies_one_per_tenant (tenant_id),
  UNIQUE KEY uq_companies_scope (tenant_id,id),
  CONSTRAINT fk_companies_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_companies_minor_units CHECK (currency_minor_units <= 6),
  CONSTRAINT ck_companies_currency CHECK (currency_code REGEXP '^[A-Z]{3}$'),
  CONSTRAINT ck_companies_version CHECK (row_version > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE tenant_memberships (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  tenant_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  role VARCHAR(20) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  row_version BIGINT UNSIGNED NOT NULL DEFAULT 1,
  UNIQUE KEY uq_memberships_user_tenant (tenant_id,user_id),
  UNIQUE KEY uq_memberships_scope (tenant_id,id),
  UNIQUE KEY uq_memberships_user_id (user_id,id),
  CONSTRAINT fk_memberships_tenant FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_memberships_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_memberships_role CHECK (role IN ('ADMINISTRATOR','STAFF')),
  CONSTRAINT ck_memberships_status CHECK (status IN ('ACTIVE','DISABLED')),
  CONSTRAINT ck_memberships_version CHECK (row_version > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE auth_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  public_id BINARY(16) NOT NULL,
  session_key_hash BINARY(32) NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  user_security_stamp BINARY(16) NOT NULL,
  selected_membership_id BIGINT UNSIGNED NULL,
  context_version BIGINT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(6) NOT NULL,
  last_activity_at DATETIME(6) NOT NULL,
  absolute_expires_at DATETIME(6) NOT NULL,
  revoked_at DATETIME(6) NULL,
  revocation_reason VARCHAR(40) NULL,
  row_version BIGINT UNSIGNED NOT NULL DEFAULT 1,
  UNIQUE KEY uq_sessions_public (public_id),
  UNIQUE KEY uq_sessions_hash (session_key_hash),
  KEY ix_sessions_user (user_id,revoked_at,absolute_expires_at),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_sessions_membership_user FOREIGN KEY (user_id,selected_membership_id) REFERENCES tenant_memberships(user_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_sessions_time CHECK (absolute_expires_at > created_at AND last_activity_at >= created_at AND last_activity_at <= absolute_expires_at),
  CONSTRAINT ck_sessions_version CHECK (context_version > 0 AND row_version > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE audit_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  tenant_id BIGINT UNSIGNED NOT NULL,
  company_id BIGINT UNSIGNED NOT NULL,
  actor_membership_id BIGINT UNSIGNED NULL,
  operator_reference VARCHAR(100) NULL,
  action VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  entity_type VARCHAR(40) NOT NULL,
  entity_id BIGINT UNSIGNED NOT NULL,
  reason VARCHAR(300) NOT NULL,
  details_json JSON NULL,
  correlation_id VARCHAR(100) NOT NULL,
  occurred_at DATETIME(6) NOT NULL,
  KEY ix_audit_scope_time (tenant_id,company_id,occurred_at,id),
  CONSTRAINT fk_audit_company FOREIGN KEY (tenant_id,company_id) REFERENCES companies(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_audit_member FOREIGN KEY (tenant_id,actor_membership_id) REFERENCES tenant_memberships(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_audit_actor CHECK ((actor_membership_id IS NOT NULL AND operator_reference IS NULL) OR (actor_membership_id IS NULL AND operator_reference IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE security_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  event_code VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  operator_reference VARCHAR(100) NULL,
  correlation_id VARCHAR(100) NOT NULL,
  occurred_at DATETIME(6) NOT NULL,
  KEY ix_security_user_time (user_id,occurred_at,id),
  CONSTRAINT fk_security_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
