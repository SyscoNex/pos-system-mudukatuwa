-- P1-03: prepared for review; never run automatically on API startup.
CREATE TABLE branches (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, tenant_id BIGINT UNSIGNED NOT NULL, company_id BIGINT UNSIGNED NOT NULL,
 code VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 name VARCHAR(200) NOT NULL, address VARCHAR(700) NULL, phone VARCHAR(50) NULL, description VARCHAR(500) NULL,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, row_version BIGINT UNSIGNED NOT NULL DEFAULT 1, CHECK(row_version>0),
 UNIQUE KEY uq_branches_code(tenant_id,company_id,code),
 UNIQUE KEY uq_branches_scope(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id) REFERENCES companies(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CHECK(is_active IN (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE membership_branches (
 tenant_id BIGINT UNSIGNED NOT NULL, company_id BIGINT UNSIGNED NOT NULL, membership_id BIGINT UNSIGNED NOT NULL, branch_id BIGINT UNSIGNED NOT NULL,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, row_version BIGINT UNSIGNED NOT NULL DEFAULT 1, CHECK(row_version>0),
 PRIMARY KEY(tenant_id,company_id,membership_id,branch_id),
 KEY ix_grants_branch(tenant_id,company_id,branch_id,is_active),
 FOREIGN KEY(tenant_id,membership_id) REFERENCES tenant_memberships(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 FOREIGN KEY(tenant_id,company_id,branch_id) REFERENCES branches(tenant_id,company_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CHECK(is_active IN(0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE warehouses (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, tenant_id BIGINT UNSIGNED NOT NULL, company_id BIGINT UNSIGNED NOT NULL, branch_id BIGINT UNSIGNED NULL,
 code VARCHAR(60) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, name VARCHAR(200) NOT NULL, description VARCHAR(500) NULL,
 kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, is_default BOOLEAN NOT NULL DEFAULT FALSE,
 default_branch_id BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN is_default=1 THEN branch_id ELSE NULL END) STORED,
 transit_company_id BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN kind='TRANSIT' THEN company_id ELSE NULL END) STORED,
 created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, row_version BIGINT UNSIGNED NOT NULL DEFAULT 1, CHECK(row_version>0),
 UNIQUE KEY uq_warehouses_code(tenant_id,company_id,code),
 UNIQUE KEY uq_warehouses_scope(tenant_id,company_id,id),
 UNIQUE KEY uq_warehouses_kind(tenant_id,company_id,id,kind),
 UNIQUE KEY uq_warehouses_default(tenant_id,company_id,default_branch_id),
 UNIQUE KEY uq_warehouses_transit(tenant_id,transit_company_id),
 FOREIGN KEY(tenant_id,company_id) REFERENCES companies(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 FOREIGN KEY(tenant_id,company_id,branch_id) REFERENCES branches(tenant_id,company_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CHECK(is_active IN(0,1) AND is_default IN(0,1)),
 CHECK((kind='ORDINARY' AND branch_id IS NOT NULL) OR (kind='TRANSIT' AND branch_id IS NULL AND is_active=1 AND is_default=0 AND code='SYS-TRANSIT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE locations (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, tenant_id BIGINT UNSIGNED NOT NULL, company_id BIGINT UNSIGNED NOT NULL, warehouse_id BIGINT UNSIGNED NOT NULL,
 warehouse_kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 code VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, name VARCHAR(100) NOT NULL,
 kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, row_version BIGINT UNSIGNED NOT NULL DEFAULT 1, CHECK(row_version>0),
 UNIQUE KEY uq_locations_code(tenant_id,company_id,warehouse_id,code),
 UNIQUE KEY uq_locations_kind(tenant_id,company_id,warehouse_id,kind),
 UNIQUE KEY uq_locations_scope(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,warehouse_id,warehouse_kind) REFERENCES warehouses(tenant_id,company_id,id,kind) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CHECK((warehouse_kind='ORDINARY' AND kind IN('STORAGE','HOLD','DAMAGED')) OR (warehouse_kind='TRANSIT' AND kind='TRANSIT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
ALTER TABLE auth_sessions
 ADD selected_branch_id BIGINT UNSIGNED NULL,
 ADD selected_branch_tenant_id BIGINT UNSIGNED NULL,
 ADD selected_branch_company_id BIGINT UNSIGNED NULL,
 ADD CONSTRAINT fk_session_branch FOREIGN KEY(selected_branch_tenant_id,selected_branch_company_id,selected_branch_id) REFERENCES branches(tenant_id,company_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 ADD CONSTRAINT fk_session_branch_member FOREIGN KEY(selected_branch_tenant_id,selected_membership_id) REFERENCES tenant_memberships(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 ADD CONSTRAINT ck_session_branch_scope CHECK(
 (selected_branch_id IS NULL AND selected_branch_tenant_id IS NULL AND selected_branch_company_id IS NULL)
 OR (selected_branch_id IS NOT NULL AND selected_branch_tenant_id IS NOT NULL AND selected_branch_company_id IS NOT NULL AND selected_membership_id IS NOT NULL));
