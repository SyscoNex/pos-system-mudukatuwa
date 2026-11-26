-- POS manufacturing SaaS schema 1.0, 23 November 2026
-- Target MySQL 8.4 LTS. Run against a NEW EMPTY database selected by the operator.
-- No DROP statements. DDL auto commits. Do not run this as an application account.
-- Reference data and posting services are required before business use.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION time_zone = '+00:00';
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- Platform: Independent subscribing business and isolation boundary
CREATE TABLE `tenants` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `code` VARCHAR(60) NOT NULL COMMENT 'Immutable tenant identifier',
  `name` VARCHAR(200) NOT NULL COMMENT 'Display name',
  `status` VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' COMMENT 'Tenant access state',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tenants_code` (`code`),
  CONSTRAINT `ck_tenants_1` CHECK (`status` IN ('ACTIVE', 'SUSPENDED', 'CLOSED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Identity: Global login principal without business data
CREATE TABLE `users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `public_id` BINARY(16) NOT NULL COMMENT 'UUID exposed in APIs',
  `email_normalized` VARCHAR(254) NOT NULL COMMENT 'Normalized login email',
  `password_hash` VARCHAR(512) NULL COMMENT 'Identity provider hash only',
  `identity_subject` VARCHAR(200) NULL COMMENT 'External identity subject',
  `is_enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Whether login is allowed',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_public_id` (`public_id`),
  UNIQUE KEY `uq_users_email_normalized` (`email_normalized`),
  CONSTRAINT `ck_users_1` CHECK (`is_enabled` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Identity: Explicit user access to a tenant
CREATE TABLE `tenant_memberships` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to users',
  `status` VARCHAR(32) NOT NULL COMMENT 'Membership state',
  `joined_at` DATETIME(6) NULL COMMENT 'Accepted timestamp',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tenant_memberships_tenant_id_id` (`tenant_id`, `id`),
  UNIQUE KEY `uq_tenant_memberships_tenant_id_user_id` (`tenant_id`, `user_id`),
  CONSTRAINT `ck_tenant_memberships_1` CHECK (`status` IN ('INVITED', 'ACTIVE', 'DISABLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Identity: Tenant configurable roles
CREATE TABLE `roles` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `code` VARCHAR(60) NOT NULL COMMENT 'Role code',
  `name` VARCHAR(100) NOT NULL COMMENT 'Role name',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_roles_tenant_id_id` (`tenant_id`, `id`),
  UNIQUE KEY `uq_roles_tenant_id_code` (`tenant_id`, `code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Identity: Global permission vocabulary
CREATE TABLE `permissions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `code` VARCHAR(100) NOT NULL COMMENT 'Permission such as sale.post or payroll.view',
  `description` VARCHAR(255) NOT NULL COMMENT 'Meaning',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_permissions_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Identity: Role permission assignment
CREATE TABLE `role_permissions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `role_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to roles',
  `permission_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to permissions',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_role_permissions_tenant_id_id` (`tenant_id`, `id`),
  UNIQUE KEY `uq_role_permissions_tenant_id_role_id_permission_id` (`tenant_id`, `role_id`, `permission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Identity: Explicit tenant wide role grants
CREATE TABLE `membership_roles` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `membership_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenant_memberships',
  `role_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to roles',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_membership_roles_tenant_id_id` (`tenant_id`, `id`),
  UNIQUE KEY `uq_membership_roles_tenant_id_membership_id_role_id` (`tenant_id`, `membership_id`, `role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Organization: Legal entity inside a tenant
CREATE TABLE `companies` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `code` VARCHAR(30) NOT NULL COMMENT 'Legal entity code',
  `legal_name` VARCHAR(200) NOT NULL COMMENT 'Registered name',
  `base_currency_code` VARCHAR(3) NOT NULL COMMENT 'Functional currency ISO code',
  `timezone` VARCHAR(64) NOT NULL COMMENT 'IANA business timezone',
  `country_code` VARCHAR(2) NOT NULL COMMENT 'ISO country',
  `registration_number` VARCHAR(80) NULL COMMENT 'Registration identifier',
  `tax_number` VARCHAR(80) NULL COMMENT 'Tax registration identifier',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_companies_tenant_id_id` (`tenant_id`, `id`),
  UNIQUE KEY `uq_companies_tenant_id_code` (`tenant_id`, `code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Organization: Factory shop office or distribution branch
CREATE TABLE `branches` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(30) NOT NULL COMMENT 'Branch code',
  `name` VARCHAR(150) NOT NULL COMMENT 'Branch name',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Branch purpose',
  `address` VARCHAR(500) NULL COMMENT 'Business address',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_branches_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_branches_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_branches_1` CHECK (`kind` IN ('FACTORY', 'STORE', 'WAREHOUSE', 'OFFICE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Identity: Explicit branch access grants
CREATE TABLE `membership_branches` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `membership_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenant_memberships',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_membership_branches_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_membership_branches_tenant_id_company_id_mem_881d75d536` (`tenant_id`, `company_id`, `membership_id`, `branch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Identity: Company restricted role grants
CREATE TABLE `company_role_grants` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `membership_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenant_memberships',
  `role_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to roles',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_company_role_grants_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_company_role_grants_tenant_id_company_id_mem_f3a03902d7` (`tenant_id`, `company_id`, `membership_id`, `role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Organization: Warehouse under a branch
CREATE TABLE `warehouses` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `code` VARCHAR(30) NOT NULL COMMENT 'Warehouse code',
  `name` VARCHAR(100) NOT NULL COMMENT 'Warehouse name',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_warehouses_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_warehouses_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Organization: Stock bin including transit quarantine WIP and scrap
CREATE TABLE `locations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `warehouse_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to warehouses',
  `parent_location_id` BIGINT UNSIGNED NULL COMMENT 'Reference to locations',
  `code` VARCHAR(50) NOT NULL COMMENT 'Bin code',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Bin purpose',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_locations_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_locations_tenant_id_company_id_warehouse_id_code` (`tenant_id`, `company_id`, `warehouse_id`, `code`),
  CONSTRAINT `ck_locations_1` CHECK (`kind` IN ('STORAGE', 'TRANSIT', 'QUARANTINE', 'WIP', 'SCRAP'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Platform: Enabled product modules per tenant
CREATE TABLE `tenant_features` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `feature_code` VARCHAR(60) NOT NULL COMMENT 'Feature identifier',
  `is_enabled` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Feature access',
  `settings_json` JSON NULL COMMENT 'Non financial configuration',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tenant_features_tenant_id_id` (`tenant_id`, `id`),
  UNIQUE KEY `uq_tenant_features_tenant_id_feature_code` (`tenant_id`, `feature_code`),
  CONSTRAINT `ck_tenant_features_1` CHECK (`is_enabled` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Platform: Subscription metadata and external billing references
CREATE TABLE `subscriptions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `plan_code` VARCHAR(60) NOT NULL COMMENT 'Plan identifier',
  `status` VARCHAR(32) NOT NULL COMMENT 'Subscription state',
  `starts_at` DATETIME(6) NOT NULL COMMENT 'Start',
  `ends_at` DATETIME(6) NULL COMMENT 'End',
  `provider_reference` VARCHAR(200) COLLATE utf8mb4_bin NULL COMMENT 'Billing provider reference',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_subscriptions_tenant_id_id` (`tenant_id`, `id`),
  CONSTRAINT `ck_subscriptions_1` CHECK (`status` IN ('TRIAL', 'ACTIVE', 'PAST_DUE', 'CANCELLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Reference: Supported currency precision
CREATE TABLE `currencies` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `code` VARCHAR(3) NOT NULL COMMENT 'ISO currency code',
  `minor_units` TINYINT UNSIGNED NOT NULL COMMENT 'Number of currency decimal places',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_currencies_code` (`code`),
  CONSTRAINT `ck_currencies_1` CHECK (minor_units <= 6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Catalog: Units and physical dimensions
CREATE TABLE `units` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(20) NOT NULL COMMENT 'Unit code',
  `name` VARCHAR(80) NOT NULL COMMENT 'Unit name',
  `dimension` VARCHAR(32) NOT NULL COMMENT 'Dimension prevents invalid generic conversions',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_units_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_units_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_units_1` CHECK (`dimension` IN ('MASS', 'VOLUME', 'COUNT', 'LENGTH', 'TIME', 'OTHER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Catalog: Hierarchical product categories
CREATE TABLE `item_categories` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `parent_id` BIGINT UNSIGNED NULL COMMENT 'Reference to item_categories',
  `code` VARCHAR(50) NOT NULL COMMENT 'Category code',
  `name` VARCHAR(150) NOT NULL COMMENT 'Category label',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_item_categories_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_item_categories_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Catalog: Raw material packaging intermediate finished good byproduct or service
CREATE TABLE `items` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `sku` VARCHAR(80) NOT NULL COMMENT 'Internal company unique SKU',
  `name` VARCHAR(200) NOT NULL COMMENT 'Item name',
  `category_id` BIGINT UNSIGNED NULL COMMENT 'Reference to item_categories',
  `base_uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Item business role',
  `is_stocked` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Track inventory',
  `is_purchasable` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Allow purchasing',
  `is_sellable` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Allow sale',
  `is_manufactured` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Has manufacturing recipes',
  `tracking` VARCHAR(32) NOT NULL DEFAULT 'LOT' COMMENT 'Traceability level',
  `shelf_life_days` INT UNSIGNED NULL COMMENT 'Suggested shelf life',
  `expiry_required` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Expiry mandatory',
  `is_active` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Selectable for new transactions',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_items_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_items_tenant_id_company_id_sku` (`tenant_id`, `company_id`, `sku`),
  CONSTRAINT `ck_items_1` CHECK (`kind` IN ('RAW', 'PACKAGING', 'INTERMEDIATE', 'FINISHED', 'BYPRODUCT', 'SERVICE')),
  CONSTRAINT `ck_items_2` CHECK (`is_stocked` IN (0, 1)),
  CONSTRAINT `ck_items_3` CHECK (`is_purchasable` IN (0, 1)),
  CONSTRAINT `ck_items_4` CHECK (`is_sellable` IN (0, 1)),
  CONSTRAINT `ck_items_5` CHECK (`is_manufactured` IN (0, 1)),
  CONSTRAINT `ck_items_6` CHECK (`tracking` IN ('NONE', 'LOT', 'SERIAL')),
  CONSTRAINT `ck_items_7` CHECK (`expiry_required` IN (0, 1)),
  CONSTRAINT `ck_items_8` CHECK (`is_active` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Catalog: Item specific UOM packaging and density conversions
CREATE TABLE `item_units` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `to_base_factor` DECIMAL(24,9) NOT NULL COMMENT 'Base quantity per unit; density conversions specific to this item',
  `is_purchase_default` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Preferred purchase unit',
  `is_sale_default` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Preferred sale unit',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_item_units_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_item_units_tenant_id_company_id_item_id_uom_id` (`tenant_id`, `company_id`, `item_id`, `uom_id`),
  UNIQUE KEY `uq_item_units_tenant_id_company_id_item_id_id` (`tenant_id`, `company_id`, `item_id`, `id`),
  CONSTRAINT `ck_item_units_1` CHECK (to_base_factor > 0),
  CONSTRAINT `ck_item_units_2` CHECK (`is_purchase_default` IN (0, 1)),
  CONSTRAINT `ck_item_units_3` CHECK (`is_sale_default` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Catalog: Multiple GTIN pack and supplier barcodes
CREATE TABLE `item_barcodes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `item_unit_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to item_units',
  `barcode` VARCHAR(100) COLLATE utf8mb4_bin NOT NULL COMMENT 'Scanned identifier',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Barcode format',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_item_barcodes_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_item_barcodes_tenant_id_company_id_barcode` (`tenant_id`, `company_id`, `barcode`),
  CONSTRAINT `ck_item_barcodes_1` CHECK (`kind` IN ('GTIN', 'INTERNAL', 'SUPPLIER', 'SCALE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Catalog: Defined non transactional attributes
CREATE TABLE `item_attributes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(60) NOT NULL COMMENT 'Attribute code',
  `name` VARCHAR(100) NOT NULL COMMENT 'Attribute name',
  `value_kind` VARCHAR(32) NOT NULL COMMENT 'Value interpretation',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_item_attributes_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_item_attributes_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_item_attributes_1` CHECK (`value_kind` IN ('TEXT', 'NUMBER', 'BOOLEAN', 'DATE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Catalog: Flexible product metadata without changing stock schema
CREATE TABLE `item_attribute_values` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `attribute_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to item_attributes',
  `value_text` VARCHAR(500) NOT NULL COMMENT 'Validated attribute value',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_item_attribute_values_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_item_attribute_values_tenant_id_company_id_i_81c95cc064` (`tenant_id`, `company_id`, `item_id`, `attribute_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Contacts: Customer supplier or other external party master
CREATE TABLE `parties` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(50) NOT NULL COMMENT 'Party code',
  `name` VARCHAR(200) NOT NULL COMMENT 'Party name',
  `tax_number` VARCHAR(80) NULL COMMENT 'Tax identifier',
  `phone` VARCHAR(50) NULL COMMENT 'Phone',
  `email` VARCHAR(254) NULL COMMENT 'Email',
  `is_active` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Active party',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_parties_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_parties_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_parties_1` CHECK (`is_active` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Contacts: A party can be both customer and supplier
CREATE TABLE `party_roles` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `party_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `role` VARCHAR(32) NOT NULL COMMENT 'Party role',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_party_roles_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_party_roles_tenant_id_company_id_party_id_role` (`tenant_id`, `company_id`, `party_id`, `role`),
  CONSTRAINT `ck_party_roles_1` CHECK (`role` IN ('CUSTOMER', 'SUPPLIER', 'CARRIER', 'SUBCONTRACTOR', 'OTHER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Contacts: Billing delivery and registered addresses
CREATE TABLE `party_addresses` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `party_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Address use',
  `address_text` VARCHAR(700) NOT NULL COMMENT 'Full address',
  `country_code` VARCHAR(2) NOT NULL COMMENT 'Country',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_party_addresses_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  KEY `ix_party_addresses_tenant_id_company_id_party_id` (`tenant_id`, `company_id`, `party_id`),
  CONSTRAINT `ck_party_addresses_1` CHECK (`kind` IN ('BILLING', 'SHIPPING', 'REGISTERED', 'OTHER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Contacts: Company credit limit and payment terms
CREATE TABLE `party_credit_policies` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `party_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `credit_limit_base` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Approved functional currency limit',
  `payment_days` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Allowed days',
  `credit_hold` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Block new credit',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_party_credit_policies_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_party_credit_policies_tenant_id_company_id_party_id` (`tenant_id`, `company_id`, `party_id`),
  CONSTRAINT `ck_party_credit_policies_1` CHECK (`credit_hold` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Supplier specific item code lead time and MOQ
CREATE TABLE `supplier_items` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `party_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `supplier_sku` VARCHAR(100) NULL COMMENT 'Supplier code',
  `lead_days` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Lead time',
  `minimum_order_base` DECIMAL(24,9) NOT NULL DEFAULT 0 COMMENT 'Minimum quantity',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_items_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_supplier_items_tenant_id_company_id_party_id_item_id` (`tenant_id`, `company_id`, `party_id`, `item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Tax: Tax definitions without hardcoded statutory rates
CREATE TABLE `tax_codes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(40) NOT NULL COMMENT 'Tax code',
  `name` VARCHAR(100) NOT NULL COMMENT 'Tax name',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Tax treatment',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tax_codes_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_tax_codes_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_tax_codes_1` CHECK (`kind` IN ('SALES', 'PURCHASE', 'BOTH', 'WITHHOLDING'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Tax: Effective dated tax rates
CREATE TABLE `tax_rates` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `tax_code_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tax_codes',
  `valid_from` DATE NOT NULL COMMENT 'Start date',
  `valid_to` DATE NULL COMMENT 'End date',
  `rate` DECIMAL(24,9) NOT NULL COMMENT 'Fraction such as 0.18',
  `is_recoverable` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Recoverable purchase input tax',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_tax_rates_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_tax_rates_tenant_id_company_id_tax_code_id_valid_from` (`tenant_id`, `company_id`, `tax_code_id`, `valid_from`),
  CONSTRAINT `ck_tax_rates_1` CHECK (rate >= 0),
  CONSTRAINT `ck_tax_rates_2` CHECK (valid_to IS NULL OR valid_to >= valid_from),
  CONSTRAINT `ck_tax_rates_3` CHECK (`is_recoverable` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Tax: Tax selection by item direction and effective date
CREATE TABLE `item_tax_rules` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `tax_code_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tax_codes',
  `direction` VARCHAR(32) NOT NULL COMMENT 'Direction',
  `valid_from` DATE NOT NULL COMMENT 'Effective start',
  `valid_to` DATE NULL COMMENT 'Effective end',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_item_tax_rules_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_item_tax_rules_tenant_id_company_id_item_id__3e273b89d1` (`tenant_id`, `company_id`, `item_id`, `tax_code_id`, `direction`, `valid_from`),
  CONSTRAINT `ck_item_tax_rules_1` CHECK (`direction` IN ('SALE', 'PURCHASE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Pricing: Retail wholesale and contract price lists
CREATE TABLE `price_lists` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(40) NOT NULL COMMENT 'Price list code',
  `name` VARCHAR(100) NOT NULL COMMENT 'Price list name',
  `currency_code` VARCHAR(3) NOT NULL COMMENT 'ISO currency',
  `tax_inclusive` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Whether display includes tax',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_price_lists_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_price_lists_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_price_lists_1` CHECK (`tax_inclusive` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Pricing: Quantity breaks effective dates and prices
CREATE TABLE `price_list_lines` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `price_list_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to price_lists',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `minimum_quantity` DECIMAL(24,9) NOT NULL DEFAULT 1 COMMENT 'Quantity break',
  `unit_price` DECIMAL(24,6) NOT NULL COMMENT 'Unit price',
  `valid_from` DATETIME(6) NOT NULL COMMENT 'Effective start',
  `valid_to` DATETIME(6) NULL COMMENT 'Effective end',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_price_list_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_price_list_lines_tenant_id_company_id_price__e7076e7ffd` (`tenant_id`, `company_id`, `price_list_id`, `item_id`, `uom_id`, `minimum_quantity`, `valid_from`),
  CONSTRAINT `ck_price_list_lines_1` CHECK (unit_price >= 0),
  CONSTRAINT `ck_price_list_lines_2` CHECK (minimum_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Pricing: Versioned rule definitions for promotions
CREATE TABLE `promotions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(50) NOT NULL COMMENT 'Promotion code',
  `name` VARCHAR(150) NOT NULL COMMENT 'Promotion name',
  `valid_from` DATETIME(6) NOT NULL COMMENT 'Start',
  `valid_to` DATETIME(6) NOT NULL COMMENT 'End',
  `priority` INT NOT NULL DEFAULT 0 COMMENT 'Evaluation order',
  `rule_json` JSON NOT NULL COMMENT 'Validated versioned rule DSL',
  `is_enabled` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Enabled',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_promotions_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_promotions_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_promotions_1` CHECK (`is_enabled` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Documents: Locked counters for company branch document type and fiscal year
CREATE TABLE `document_sequences` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `document_type` VARCHAR(40) NOT NULL COMMENT 'Document type',
  `fiscal_year` SMALLINT UNSIGNED NOT NULL COMMENT 'Business year',
  `next_value` BIGINT UNSIGNED NOT NULL COMMENT 'Next number',
  `prefix` VARCHAR(40) NOT NULL COMMENT 'Receipt or document prefix',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_document_sequences_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_document_sequences_tenant_id_company_id_bran_34a9e2b625` (`tenant_id`, `company_id`, `branch_id`, `document_type`, `fiscal_year`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Documents: Common lifecycle and currency root for all business documents
CREATE TABLE `documents` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `public_id` BINARY(16) NOT NULL COMMENT 'UUID for external references',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `document_type` VARCHAR(40) NOT NULL COMMENT 'Discriminator checked by posting service',
  `document_number` VARCHAR(80) NOT NULL COMMENT 'Allocated immutable business number',
  `business_date` DATE NOT NULL COMMENT 'Local accounting date',
  `occurred_at` DATETIME(6) NOT NULL COMMENT 'UTC actual event time',
  `currency_code` VARCHAR(3) NOT NULL COMMENT 'Document currency',
  `exchange_rate` DECIMAL(24,9) NOT NULL COMMENT 'Functional currency per document unit',
  `status` VARCHAR(32) NOT NULL DEFAULT 'DRAFT' COMMENT 'Lifecycle',
  `source_document_id` BIGINT UNSIGNED NULL COMMENT 'Reference to documents',
  `created_by_membership_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenant_memberships',
  `posted_at` DATETIME(6) NULL COMMENT 'UTC posting time',
  `notes` VARCHAR(1000) NULL COMMENT 'Document notes',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_documents_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_documents_tenant_id_company_id_public_id` (`tenant_id`, `company_id`, `public_id`),
  UNIQUE KEY `uq_documents_tenant_id_company_id_document_type_eec73570d7` (`tenant_id`, `company_id`, `document_type`, `document_number`),
  KEY `ix_documents_tenant_id_company_id_branch_id_business_date_id` (`tenant_id`, `company_id`, `branch_id`, `business_date`, `id`),
  KEY `ix_documents_tenant_id_company_id_status_business_date_id` (`tenant_id`, `company_id`, `status`, `business_date`, `id`),
  CONSTRAINT `ck_documents_1` CHECK (exchange_rate > 0),
  CONSTRAINT `ck_documents_2` CHECK (`status` IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'POSTED', 'REVERSED', 'VOID'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Documents: Stable source line identity for inventory finance and tax links
CREATE TABLE `document_lines` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `line_number` INT UNSIGNED NOT NULL COMMENT 'Display order',
  `description` VARCHAR(500) NULL COMMENT 'Historic description',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_document_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_document_lines_tenant_id_company_id_document_6cb092c959` (`tenant_id`, `company_id`, `document_id`, `line_number`),
  UNIQUE KEY `uq_document_lines_tenant_id_company_id_document_id_id` (`tenant_id`, `company_id`, `document_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Documents: Many to many document relationships
CREATE TABLE `document_links` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `from_document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `to_document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `relation` VARCHAR(40) NOT NULL COMMENT 'FULFILLS RETURNS REVERSES etc',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_document_links_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_document_links_tenant_id_company_id_from_doc_0b209c0b4b` (`tenant_id`, `company_id`, `from_document_id`, `to_document_id`, `relation`),
  CONSTRAINT `ck_document_links_1` CHECK (from_document_id <> to_document_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Tax: Frozen per line per tax component basis rate and amount
CREATE TABLE `document_taxes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `document_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to document_lines',
  `tax_code_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tax_codes',
  `rate_snapshot` DECIMAL(24,9) NOT NULL COMMENT 'Applied tax fraction',
  `taxable_amount` DECIMAL(24,6) NOT NULL COMMENT 'Frozen tax base',
  `tax_amount` DECIMAL(24,6) NOT NULL COMMENT 'Frozen tax amount',
  `tax_amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Functional currency tax',
  `is_inclusive` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Inclusive pricing snapshot',
  `is_recoverable` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Recoverability snapshot',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_document_taxes_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_document_taxes_1` CHECK (`is_inclusive` IN (0, 1)),
  CONSTRAINT `ck_document_taxes_2` CHECK (`is_recoverable` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Documents: Approval history for spend discounts writeoffs and production
CREATE TABLE `document_approvals` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `membership_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenant_memberships',
  `step_number` INT UNSIGNED NOT NULL COMMENT 'Approval step',
  `decision` VARCHAR(32) NOT NULL COMMENT 'Decision',
  `decided_at` DATETIME(6) NOT NULL COMMENT 'Decision time',
  `reason` VARCHAR(500) NULL COMMENT 'Decision notes',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_document_approvals_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_document_approvals_1` CHECK (`decision` IN ('APPROVE', 'REJECT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Documents: Object storage metadata with private access checks
CREATE TABLE `attachments` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NULL COMMENT 'Reference to documents',
  `object_key` VARCHAR(400) NOT NULL COMMENT 'Private object key',
  `file_name` VARCHAR(255) NOT NULL COMMENT 'Original name',
  `mime_type` VARCHAR(100) NOT NULL COMMENT 'MIME',
  `size_bytes` BIGINT UNSIGNED NOT NULL COMMENT 'Size',
  `sha256` BINARY(32) NOT NULL COMMENT 'Integrity digest',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_attachments_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Supplier order with delivery and payment terms
CREATE TABLE `purchase_orders` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `supplier_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `expected_date` DATE NULL COMMENT 'Expected delivery',
  `payment_days` INT UNSIGNED NOT NULL COMMENT 'Frozen payment term',
  `supplier_address_snapshot` VARCHAR(1000) NOT NULL COMMENT 'Historic supplier details',
  `total_amount` DECIMAL(24,6) NOT NULL COMMENT 'Frozen total',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_purchase_orders_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Ordered items and agreed prices
CREATE TABLE `purchase_order_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to purchase_orders',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive quantity in transaction unit',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Quantity in item base unit',
  `uom_factor` DECIMAL(24,9) NOT NULL COMMENT 'Frozen base units per transaction unit',
  `unit_price` DECIMAL(24,6) NOT NULL COMMENT 'Price before tax in document currency',
  `discount_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Allocated line discount',
  `net_amount` DECIMAL(24,6) NOT NULL COMMENT 'Line value after discount before tax',
  `tax_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Rounded tax total',
  `gross_amount` DECIMAL(24,6) NOT NULL COMMENT 'Net plus tax',
  `item_name_snapshot` VARCHAR(200) NOT NULL COMMENT 'Historic item label',
  `sku_snapshot` VARCHAR(80) NOT NULL COMMENT 'Historic SKU',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_purchase_order_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_purchase_order_lines_1` CHECK (quantity > 0),
  CONSTRAINT `ck_purchase_order_lines_2` CHECK (base_quantity > 0),
  CONSTRAINT `ck_purchase_order_lines_3` CHECK (uom_factor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Physical receipt against one or more purchase orders
CREATE TABLE `goods_receipts` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `supplier_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `supplier_delivery_number` VARCHAR(100) NULL COMMENT 'Supplier delivery note',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_goods_receipts_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Received quantities including rejected material
CREATE TABLE `goods_receipt_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to goods_receipts',
  `purchase_order_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to purchase_order_lines',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `quantity` DECIMAL(24,9) NOT NULL COMMENT 'Received transaction quantity',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Received base quantity',
  `uom_factor` DECIMAL(24,9) NOT NULL COMMENT 'Frozen conversion',
  `provisional_unit_cost_base` DECIMAL(24,6) NOT NULL COMMENT 'Initial base unit cost pending invoice',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_goods_receipt_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_goods_receipt_lines_1` CHECK (quantity > 0),
  CONSTRAINT `ck_goods_receipt_lines_2` CHECK (base_quantity > 0),
  CONSTRAINT `ck_goods_receipt_lines_3` CHECK (uom_factor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Supplier financial invoice independent of stock receipt
CREATE TABLE `supplier_invoices` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `supplier_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `supplier_invoice_number` VARCHAR(100) NOT NULL COMMENT 'External invoice',
  `due_date` DATE NOT NULL COMMENT 'Due date',
  `supplier_snapshot` VARCHAR(1000) NOT NULL COMMENT 'Historic supplier identity',
  `total_amount` DECIMAL(24,6) NOT NULL COMMENT 'Invoice total',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_invoices_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_supplier_invoices_tenant_id_company_id_suppl_75ebb73c6d` (`tenant_id`, `company_id`, `supplier_id`, `supplier_invoice_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Invoice cost and tax details
CREATE TABLE `supplier_invoice_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to supplier_invoices',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive quantity in transaction unit',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Quantity in item base unit',
  `uom_factor` DECIMAL(24,9) NOT NULL COMMENT 'Frozen base units per transaction unit',
  `unit_price` DECIMAL(24,6) NOT NULL COMMENT 'Price before tax in document currency',
  `discount_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Allocated line discount',
  `net_amount` DECIMAL(24,6) NOT NULL COMMENT 'Line value after discount before tax',
  `tax_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Rounded tax total',
  `gross_amount` DECIMAL(24,6) NOT NULL COMMENT 'Net plus tax',
  `item_name_snapshot` VARCHAR(200) NOT NULL COMMENT 'Historic item label',
  `sku_snapshot` VARCHAR(80) NOT NULL COMMENT 'Historic SKU',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_invoice_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_supplier_invoice_lines_1` CHECK (quantity > 0),
  CONSTRAINT `ck_supplier_invoice_lines_2` CHECK (base_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Many to many receipt invoice match for partial billing
CREATE TABLE `purchase_matches` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `invoice_line_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to supplier_invoice_lines',
  `receipt_line_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to goods_receipt_lines',
  `matched_base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Matched quantity',
  `matched_amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Matched value',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_purchase_matches_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_purchase_matches_tenant_id_company_id_invoic_752b48f206` (`tenant_id`, `company_id`, `invoice_line_id`, `receipt_line_id`),
  CONSTRAINT `ck_purchase_matches_1` CHECK (matched_base_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Physical supplier returns tied to receipt lots
CREATE TABLE `supplier_returns` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `supplier_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `reason` VARCHAR(500) NOT NULL COMMENT 'Return reason',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_returns_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Supplier return item quantities
CREATE TABLE `supplier_return_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to supplier_returns',
  `receipt_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to goods_receipt_lines',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive quantity returned',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_return_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_supplier_return_lines_1` CHECK (base_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Supplier financial credits separate from physical returns
CREATE TABLE `supplier_credits` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `supplier_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `original_invoice_id` BIGINT UNSIGNED NULL COMMENT 'Reference to supplier_invoices',
  `credit_number` VARCHAR(100) NOT NULL COMMENT 'Supplier credit number',
  `total_amount` DECIMAL(24,6) NOT NULL COMMENT 'Positive credited amount',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_credits_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Credit amounts and optional original invoice line
CREATE TABLE `supplier_credit_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to supplier_credits',
  `original_invoice_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to supplier_invoice_lines',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive quantity in transaction unit',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Quantity in item base unit',
  `uom_factor` DECIMAL(24,9) NOT NULL COMMENT 'Frozen base units per transaction unit',
  `unit_price` DECIMAL(24,6) NOT NULL COMMENT 'Price before tax in document currency',
  `discount_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Allocated line discount',
  `net_amount` DECIMAL(24,6) NOT NULL COMMENT 'Line value after discount before tax',
  `tax_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Rounded tax total',
  `gross_amount` DECIMAL(24,6) NOT NULL COMMENT 'Net plus tax',
  `item_name_snapshot` VARCHAR(200) NOT NULL COMMENT 'Historic item label',
  `sku_snapshot` VARCHAR(80) NOT NULL COMMENT 'Historic SKU',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_credit_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_supplier_credit_lines_1` CHECK (quantity > 0),
  CONSTRAINT `ck_supplier_credit_lines_2` CHECK (gross_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Freight duty and overhead allocation to received stock
CREATE TABLE `landed_costs` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `supplier_invoice_id` BIGINT UNSIGNED NULL COMMENT 'Reference to supplier_invoices',
  `amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Total cost to allocate',
  `basis` VARCHAR(32) NOT NULL COMMENT 'Allocation basis',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_landed_costs_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_landed_costs_1` CHECK (`basis` IN ('QUANTITY', 'VALUE', 'WEIGHT', 'MANUAL'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Landed cost split with rounding residual assigned once
CREATE TABLE `landed_cost_allocations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `landed_cost_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to landed_costs',
  `receipt_line_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to goods_receipt_lines',
  `amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Allocated functional cost',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_landed_cost_allocations_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_landed_cost_allocations_tenant_id_company_id_fe2423df89` (`tenant_id`, `company_id`, `landed_cost_id`, `receipt_line_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Internal lot per item including system lot for untracked items
CREATE TABLE `lots` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `lot_number` VARCHAR(100) NOT NULL COMMENT 'Internal lot identifier',
  `supplier_lot_number` VARCHAR(100) NULL COMMENT 'Supplier printed lot',
  `manufactured_on` DATE NULL COMMENT 'Manufacture date',
  `expires_on` DATE NULL COMMENT 'Expiry date',
  `kind` VARCHAR(32) NOT NULL COMMENT 'System lot only for untracked items',
  `release_status` VARCHAR(32) NOT NULL DEFAULT 'QUARANTINED' COMMENT 'Quality disposition',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_lots_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_lots_tenant_id_company_id_item_id_lot_number` (`tenant_id`, `company_id`, `item_id`, `lot_number`),
  UNIQUE KEY `uq_lots_tenant_id_company_id_item_id_id` (`tenant_id`, `company_id`, `item_id`, `id`),
  KEY `ix_lots_tenant_id_company_id_expires_on_id` (`tenant_id`, `company_id`, `expires_on`, `id`),
  CONSTRAINT `ck_lots_1` CHECK (expires_on IS NULL OR manufactured_on IS NULL OR expires_on >= manufactured_on),
  CONSTRAINT `ck_lots_2` CHECK (`kind` IN ('PURCHASED', 'PRODUCED', 'SYSTEM')),
  CONSTRAINT `ck_lots_3` CHECK (`release_status` IN ('QUARANTINED', 'RELEASED', 'REJECTED', 'RECALLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Explicit owner avoids nullable ownership key
CREATE TABLE `inventory_owners` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Owned or consigned stock',
  `party_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `code` VARCHAR(60) NOT NULL COMMENT 'Owner code',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_inventory_owners_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_inventory_owners_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_inventory_owners_1` CHECK ((kind = 'COMPANY' AND party_id IS NULL) OR (kind = 'THIRD_PARTY' AND party_id IS NOT NULL)),
  CONSTRAINT `ck_inventory_owners_2` CHECK (`kind` IN ('COMPANY', 'THIRD_PARTY'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Unique physical lot location owner and stock condition
CREATE TABLE `stock_buckets` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `lot_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to lots',
  `location_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to locations',
  `inventory_owner_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to inventory_owners',
  `condition_code` VARCHAR(32) NOT NULL COMMENT 'Condition',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_buckets_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_stock_buckets_tenant_id_company_id_lot_id_lo_53f4ae3b53` (`tenant_id`, `company_id`, `lot_id`, `location_id`, `inventory_owner_id`, `condition_code`),
  CONSTRAINT `ck_stock_buckets_1` CHECK (`condition_code` IN ('AVAILABLE', 'QUARANTINE', 'DAMAGED', 'BLOCKED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Rebuildable locked physical balance projection
CREATE TABLE `stock_balances` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `bucket_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_buckets',
  `on_hand_base` DECIMAL(24,9) NOT NULL DEFAULT 0 COMMENT 'Physical balance',
  `last_entry_id` BIGINT UNSIGNED NULL COMMENT 'Last applied inventory ledger id',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_balances_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_stock_balances_tenant_id_company_id_bucket_id` (`tenant_id`, `company_id`, `bucket_id`),
  CONSTRAINT `ck_stock_balances_1` CHECK (on_hand_base >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Reservations for sales production and offline device allocation
CREATE TABLE `stock_reservations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `bucket_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_buckets',
  `document_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to document_lines',
  `device_id` BIGINT UNSIGNED NULL COMMENT 'Reference to devices',
  `quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Reserved quantity',
  `consumed_base` DECIMAL(24,9) NOT NULL DEFAULT 0 COMMENT 'Consumed reservation',
  `status` VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' COMMENT 'Reservation state',
  `expires_at` DATETIME(6) NULL COMMENT 'Online expiry only; offline allocations do not auto release',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_reservations_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_stock_reservations_1` CHECK (quantity_base > 0),
  CONSTRAINT `ck_stock_reservations_2` CHECK (consumed_base >= 0 AND consumed_base <= quantity_base),
  CONSTRAINT `ck_stock_reservations_3` CHECK (`status` IN ('ACTIVE', 'CONSUMED', 'RELEASED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Immutable signed physical inventory movements
CREATE TABLE `stock_entries` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `document_line_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to document_lines',
  `bucket_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_buckets',
  `quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Signed movement quantity',
  `occurred_at` DATETIME(6) NOT NULL COMMENT 'UTC physical event',
  `movement_group` BINARY(16) NOT NULL COMMENT 'Pairs transfer movements',
  `reverses_entry_id` BIGINT UNSIGNED NULL COMMENT 'Reference to stock_entries',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_entries_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_stock_entries_tenant_id_company_id_reverses_entry_id` (`tenant_id`, `company_id`, `reverses_entry_id`),
  KEY `ix_stock_entries_tenant_id_company_id_bucket_id_id` (`tenant_id`, `company_id`, `bucket_id`, `id`),
  KEY `ix_stock_entries_tenant_id_company_id_document_id_id` (`tenant_id`, `company_id`, `document_id`, `id`),
  CONSTRAINT `ck_stock_entries_1` CHECK (quantity_base <> 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Costing: FIFO cost layers separate from FEFO physical picking
CREATE TABLE `stock_cost_layers` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `receipt_entry_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_entries',
  `original_quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Inbound layer quantity',
  `original_value_base` DECIMAL(24,6) NOT NULL COMMENT 'Inbound functional value',
  `remaining_quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Locked remaining quantity',
  `remaining_value_base` DECIMAL(24,6) NOT NULL COMMENT 'Locked residual value',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_cost_layers_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_stock_cost_layers_tenant_id_company_id_receipt_entry_id` (`tenant_id`, `company_id`, `receipt_entry_id`),
  CONSTRAINT `ck_stock_cost_layers_1` CHECK (original_quantity_base > 0),
  CONSTRAINT `ck_stock_cost_layers_2` CHECK (remaining_quantity_base >= 0),
  CONSTRAINT `ck_stock_cost_layers_3` CHECK (remaining_quantity_base <= original_quantity_base),
  CONSTRAINT `ck_stock_cost_layers_4` CHECK (original_value_base >= 0),
  CONSTRAINT `ck_stock_cost_layers_5` CHECK (remaining_value_base >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Costing: Issue allocations against one or more FIFO layers
CREATE TABLE `stock_cost_consumptions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `issue_entry_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_entries',
  `cost_layer_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_cost_layers',
  `quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Allocated issue quantity',
  `value_base` DECIMAL(24,6) NOT NULL COMMENT 'Allocated functional cost',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_cost_consumptions_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_stock_cost_consumptions_tenant_id_company_id_1be48fddd9` (`tenant_id`, `company_id`, `issue_entry_id`, `cost_layer_id`),
  CONSTRAINT `ck_stock_cost_consumptions_1` CHECK (quantity_base > 0),
  CONSTRAINT `ck_stock_cost_consumptions_2` CHECK (value_base >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Costing: Append only cost changes for invoice variance landed cost and revaluation
CREATE TABLE `stock_value_adjustments` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `cost_layer_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_cost_layers',
  `inventory_delta_base` DECIMAL(24,6) NOT NULL COMMENT 'Change attributable to remaining inventory',
  `consumed_delta_base` DECIMAL(24,6) NOT NULL COMMENT 'Change attributable to consumed or sold inventory',
  `reason` VARCHAR(250) NOT NULL COMMENT 'Variance reason',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_value_adjustments_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Unique serial identity for tracked pieces
CREATE TABLE `serial_numbers` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `lot_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to lots',
  `serial_number` VARCHAR(150) COLLATE utf8mb4_bin NOT NULL COMMENT 'Serial code',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_serial_numbers_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_serial_numbers_tenant_id_company_id_serial_number` (`tenant_id`, `company_id`, `serial_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: One serial assignment per physical movement
CREATE TABLE `serial_movements` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `serial_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to serial_numbers',
  `stock_entry_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_entries',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_serial_movements_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_serial_movements_tenant_id_company_id_serial_5ad1319719` (`tenant_id`, `company_id`, `serial_id`, `stock_entry_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Dispatch and receive through a transit location
CREATE TABLE `stock_transfers` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `from_warehouse_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to warehouses',
  `to_warehouse_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to warehouses',
  `stage` VARCHAR(32) NOT NULL COMMENT 'One posted document per physical stage',
  `dispatch_document_id` BIGINT UNSIGNED NULL COMMENT 'Reference to documents',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_transfers_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_stock_transfers_1` CHECK (`stage` IN ('REQUEST', 'DISPATCH', 'RECEIPT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Transfer quantities per lot handled by stock entries
CREATE TABLE `stock_transfer_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_transfers',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `dispatch_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to stock_transfer_lines',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive transferred quantity',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_transfer_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_stock_transfer_lines_1` CHECK (base_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Cycle count with frozen ledger cut and blind entry
CREATE TABLE `stock_counts` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `warehouse_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to warehouses',
  `count_cutoff_at` DATETIME(6) NOT NULL COMMENT 'Cutoff time',
  `cutoff_entry_id` BIGINT UNSIGNED NOT NULL COMMENT 'Ledger watermark',
  `count_mode` VARCHAR(32) NOT NULL COMMENT 'Movement handling policy',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_counts_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_stock_counts_1` CHECK (`count_mode` IN ('FREEZE', 'ROLL_FORWARD'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Expected counted and variance quantities
CREATE TABLE `stock_count_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_counts',
  `bucket_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_buckets',
  `observed_at` DATETIME(6) NOT NULL COMMENT 'UTC instant of physical observation',
  `observed_entry_id` BIGINT UNSIGNED NOT NULL COMMENT 'Bucket ledger watermark at observation for roll forward',
  `expected_base` DECIMAL(24,9) NOT NULL COMMENT 'Expected at observation watermark',
  `counted_base` DECIMAL(24,9) NOT NULL COMMENT 'Observed quantity',
  `variance_base` DECIMAL(24,9) NOT NULL COMMENT 'Counted less expected',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_count_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_stock_count_lines_1` CHECK (counted_base >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Approved damage writeoff opening balance or count variance
CREATE TABLE `stock_adjustments` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `reason_code` VARCHAR(50) NOT NULL COMMENT 'Reason code',
  `count_id` BIGINT UNSIGNED NULL COMMENT 'Reference to stock_counts',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_adjustments_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Inventory: Signed adjustment per bucket with valuation
CREATE TABLE `stock_adjustment_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_adjustments',
  `bucket_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_buckets',
  `quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Signed adjustment',
  `unit_cost_base` DECIMAL(24,6) NOT NULL COMMENT 'Required cost for positive adjustments',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stock_adjustment_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_stock_adjustment_lines_1` CHECK (quantity_base <> 0),
  CONSTRAINT `ck_stock_adjustment_lines_2` CHECK (unit_cost_base >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Planning: Item location reorder safety stock and supply planning
CREATE TABLE `reorder_policies` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `warehouse_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to warehouses',
  `reorder_point_base` DECIMAL(24,9) NOT NULL COMMENT 'Trigger',
  `target_stock_base` DECIMAL(24,9) NOT NULL COMMENT 'Target',
  `safety_stock_base` DECIMAL(24,9) NOT NULL COMMENT 'Safety stock',
  `lead_days` INT UNSIGNED NOT NULL COMMENT 'Lead time',
  `supply_method` VARCHAR(32) NOT NULL COMMENT 'Supply source',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_reorder_policies_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_reorder_policies_tenant_id_company_id_item_i_88280dada2` (`tenant_id`, `company_id`, `item_id`, `warehouse_id`),
  CONSTRAINT `ck_reorder_policies_1` CHECK (`supply_method` IN ('BUY', 'MAKE', 'TRANSFER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Recipe family producing one primary output
CREATE TABLE `recipes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(60) NOT NULL COMMENT 'Recipe family code',
  `primary_item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `name` VARCHAR(150) NOT NULL COMMENT 'Recipe label',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_recipes_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_recipes_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Immutable approved formula versions and yield basis
CREATE TABLE `recipe_versions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `recipe_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to recipes',
  `version_number` INT UNSIGNED NOT NULL COMMENT 'Version',
  `basis_quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Primary output basis',
  `status` VARCHAR(32) NOT NULL DEFAULT 'DRAFT' COMMENT 'Approval lifecycle',
  `valid_from` DATETIME(6) NULL COMMENT 'Effective start',
  `valid_to` DATETIME(6) NULL COMMENT 'Effective end',
  `approved_by_id` BIGINT UNSIGNED NULL COMMENT 'Reference to tenant_memberships',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_recipe_versions_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_recipe_versions_tenant_id_company_id_recipe__f553b12825` (`tenant_id`, `company_id`, `recipe_id`, `version_number`),
  CONSTRAINT `ck_recipe_versions_1` CHECK (basis_quantity_base > 0),
  CONSTRAINT `ck_recipe_versions_2` CHECK (`status` IN ('DRAFT', 'APPROVED', 'RETIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Ingredients packaging and allowed loss per recipe
CREATE TABLE `recipe_inputs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `recipe_version_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to recipe_versions',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Quantity per recipe basis',
  `normal_loss_fraction` DECIMAL(24,9) NOT NULL DEFAULT 0 COMMENT 'Expected loss fraction',
  `is_optional` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Optional component',
  `sequence_number` INT UNSIGNED NOT NULL COMMENT 'Addition order',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_recipe_inputs_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_recipe_inputs_1` CHECK (quantity_base > 0),
  CONSTRAINT `ck_recipe_inputs_2` CHECK (normal_loss_fraction >= 0 AND normal_loss_fraction < 1),
  CONSTRAINT `ck_recipe_inputs_3` CHECK (`is_optional` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Approved substitute ingredients with equivalence factors
CREATE TABLE `recipe_substitutions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `recipe_input_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to recipe_inputs',
  `substitute_item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `equivalence_factor` DECIMAL(24,9) NOT NULL COMMENT 'Substitute base quantity per original base quantity',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_recipe_substitutions_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_recipe_substitutions_tenant_id_company_id_re_7640b41784` (`tenant_id`, `company_id`, `recipe_input_id`, `substitute_item_id`),
  CONSTRAINT `ck_recipe_substitutions_1` CHECK (equivalence_factor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Co products byproducts and scrap outputs
CREATE TABLE `recipe_outputs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `recipe_version_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to recipe_versions',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `output_kind` VARCHAR(32) NOT NULL COMMENT 'Output role',
  `expected_quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Expected yield',
  `cost_share` DECIMAL(24,9) NOT NULL COMMENT 'Fraction of joint cost assigned',
  `byproduct_credit_base` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Optional net realizable value credit',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_recipe_outputs_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_recipe_outputs_tenant_id_company_id_recipe_v_32ef29e412` (`tenant_id`, `company_id`, `recipe_version_id`, `item_id`),
  CONSTRAINT `ck_recipe_outputs_1` CHECK (expected_quantity_base >= 0),
  CONSTRAINT `ck_recipe_outputs_2` CHECK (cost_share >= 0 AND cost_share <= 1),
  CONSTRAINT `ck_recipe_outputs_3` CHECK (byproduct_credit_base >= 0),
  CONSTRAINT `ck_recipe_outputs_4` CHECK (`output_kind` IN ('PRIMARY', 'COPRODUCT', 'BYPRODUCT', 'SCRAP'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Production machines lines and work areas
CREATE TABLE `work_centers` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `code` VARCHAR(50) NOT NULL COMMENT 'Work center code',
  `name` VARCHAR(100) NOT NULL COMMENT 'Work center',
  `hourly_overhead_base` DECIMAL(24,6) NOT NULL COMMENT 'Default overhead rate',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_work_centers_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_work_centers_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Versioned operation steps
CREATE TABLE `routing_steps` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `recipe_version_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to recipe_versions',
  `work_center_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to work_centers',
  `sequence_number` INT UNSIGNED NOT NULL COMMENT 'Step order',
  `name` VARCHAR(100) NOT NULL COMMENT 'Operation',
  `standard_minutes` DECIMAL(24,9) NOT NULL COMMENT 'Planned run time',
  `instructions` VARCHAR(2000) NULL COMMENT 'Instructions',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_routing_steps_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_routing_steps_tenant_id_company_id_recipe_ve_9a363b1d44` (`tenant_id`, `company_id`, `recipe_version_id`, `sequence_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Planned batch with frozen approved recipe version
CREATE TABLE `production_orders` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `recipe_version_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to recipe_versions',
  `warehouse_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to warehouses',
  `planned_output_base` DECIMAL(24,9) NOT NULL COMMENT 'Planned primary output',
  `planned_start` DATETIME(6) NULL COMMENT 'Planned start',
  `planned_end` DATETIME(6) NULL COMMENT 'Planned end',
  `production_status` VARCHAR(32) NOT NULL DEFAULT 'PLANNED' COMMENT 'Execution state',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_production_orders_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_production_orders_1` CHECK (`production_status` IN ('PLANNED', 'RELEASED', 'RUNNING', 'COMPLETED', 'CLOSED', 'CANCELLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Snapshot of exploded multi level BOM and approved substitutions
CREATE TABLE `production_material_plans` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `production_order_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to production_orders',
  `recipe_input_id` BIGINT UNSIGNED NULL COMMENT 'Reference to recipe_inputs',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `planned_base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Frozen required quantity',
  `source_recipe_path` VARCHAR(500) NOT NULL COMMENT 'Explosion path for diagnosis',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_production_material_plans_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_production_material_plans_1` CHECK (planned_base_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Order specific operation execution snapshot
CREATE TABLE `production_operations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `production_order_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to production_orders',
  `work_center_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to work_centers',
  `sequence_number` INT UNSIGNED NOT NULL COMMENT 'Operation order',
  `name` VARCHAR(100) NOT NULL COMMENT 'Frozen operation name',
  `started_at` DATETIME(6) NULL COMMENT 'Actual start',
  `completed_at` DATETIME(6) NULL COMMENT 'Actual completion',
  `status` VARCHAR(32) NOT NULL COMMENT 'Operation state',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_production_operations_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_production_operations_tenant_id_company_id_p_2bfc7bd9d5` (`tenant_id`, `company_id`, `production_order_id`, `sequence_number`),
  CONSTRAINT `ck_production_operations_1` CHECK (`status` IN ('PENDING', 'RUNNING', 'COMPLETE', 'SKIPPED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Separate posted documents for issue return output waste and rework
CREATE TABLE `production_events` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `production_order_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to production_orders',
  `event_kind` VARCHAR(32) NOT NULL COMMENT 'Manufacturing movement event',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_production_events_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_production_events_1` CHECK (`event_kind` IN ('ISSUE', 'RETURN', 'OUTPUT', 'WASTE', 'REWORK'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Actual batch material and output quantities
CREATE TABLE `production_event_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to production_events',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `material_plan_id` BIGINT UNSIGNED NULL COMMENT 'Reference to production_material_plans',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive event quantity',
  `output_kind` VARCHAR(32) NOT NULL COMMENT 'Input or output classification',
  `cost_share_snapshot` DECIMAL(24,9) NOT NULL DEFAULT 0 COMMENT 'Allocation fraction',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_production_event_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_production_event_lines_1` CHECK (base_quantity > 0),
  CONSTRAINT `ck_production_event_lines_2` CHECK (cost_share_snapshot >= 0 AND cost_share_snapshot <= 1),
  CONSTRAINT `ck_production_event_lines_3` CHECK (`output_kind` IN ('INPUT', 'PRIMARY', 'COPRODUCT', 'BYPRODUCT', 'SCRAP'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Actual direct labour machine energy and overhead charges
CREATE TABLE `production_costs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `production_order_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to production_orders',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `operation_id` BIGINT UNSIGNED NULL COMMENT 'Reference to production_operations',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Cost type',
  `amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Actual or approved applied cost',
  `description` VARCHAR(500) NOT NULL COMMENT 'Basis',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_production_costs_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_production_costs_1` CHECK (amount_base >= 0),
  CONSTRAINT `ck_production_costs_2` CHECK (`kind` IN ('LABOUR', 'MACHINE', 'ENERGY', 'OVERHEAD', 'SUBCONTRACT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: WIP settlement to individual output stock entries
CREATE TABLE `production_cost_allocations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `production_order_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to production_orders',
  `output_entry_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_entries',
  `amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Final allocated output cost',
  `settlement_document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_production_cost_allocations_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_production_cost_allocations_tenant_id_compan_72a4db4d03` (`tenant_id`, `company_id`, `settlement_document_id`, `output_entry_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Traceability: Actual input lot to output lot links through production events
CREATE TABLE `lot_genealogy` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `production_order_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to production_orders',
  `input_entry_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_entries',
  `output_entry_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_entries',
  `input_quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Allocated input quantity for trace report',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_lot_genealogy_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_lot_genealogy_tenant_id_company_id_input_ent_de89b1ce37` (`tenant_id`, `company_id`, `input_entry_id`, `output_entry_id`),
  CONSTRAINT `ck_lot_genealogy_1` CHECK (input_quantity_base > 0),
  CONSTRAINT `ck_lot_genealogy_2` CHECK (input_entry_id <> output_entry_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Quality: Versioned quality specification per item
CREATE TABLE `quality_specs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `version_number` INT UNSIGNED NOT NULL COMMENT 'Specification version',
  `name` VARCHAR(100) NOT NULL COMMENT 'Specification',
  `status` VARCHAR(32) NOT NULL COMMENT 'Approval state',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_quality_specs_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_quality_specs_tenant_id_company_id_item_id_version_number` (`tenant_id`, `company_id`, `item_id`, `version_number`),
  CONSTRAINT `ck_quality_specs_1` CHECK (`status` IN ('DRAFT', 'APPROVED', 'RETIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Quality: Numeric or text quality acceptance criteria
CREATE TABLE `quality_spec_tests` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `quality_spec_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to quality_specs',
  `test_code` VARCHAR(60) NOT NULL COMMENT 'Test code',
  `result_kind` VARCHAR(32) NOT NULL COMMENT 'Result kind',
  `minimum_value` DECIMAL(24,9) NULL COMMENT 'Minimum allowed',
  `maximum_value` DECIMAL(24,9) NULL COMMENT 'Maximum allowed',
  `expected_text` VARCHAR(250) NULL COMMENT 'Text criterion',
  `uom_id` BIGINT UNSIGNED NULL COMMENT 'Reference to units',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_quality_spec_tests_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_quality_spec_tests_tenant_id_company_id_qual_d861ec980b` (`tenant_id`, `company_id`, `quality_spec_id`, `test_code`),
  CONSTRAINT `ck_quality_spec_tests_1` CHECK (`result_kind` IN ('NUMBER', 'TEXT', 'BOOLEAN'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Quality: Lot receipt or production inspection
CREATE TABLE `quality_inspections` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `lot_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to lots',
  `quality_spec_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to quality_specs',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `inspector_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenant_memberships',
  `status` VARCHAR(32) NOT NULL COMMENT 'Inspection outcome',
  `inspected_at` DATETIME(6) NULL COMMENT 'Test timestamp',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_quality_inspections_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_quality_inspections_1` CHECK (`status` IN ('PENDING', 'PASSED', 'FAILED', 'CONDITIONAL'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Quality: Recorded measurements and accepted tolerance snapshots
CREATE TABLE `quality_results` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `inspection_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to quality_inspections',
  `spec_test_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to quality_spec_tests',
  `numeric_value` DECIMAL(24,9) NULL COMMENT 'Measurement',
  `text_value` VARCHAR(500) NULL COMMENT 'Text result',
  `passed` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Test outcome',
  `criteria_snapshot` VARCHAR(500) NOT NULL COMMENT 'Acceptance criterion at test time',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_quality_results_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_quality_results_tenant_id_company_id_inspect_5fa47b1046` (`tenant_id`, `company_id`, `inspection_id`, `spec_test_id`),
  CONSTRAINT `ck_quality_results_1` CHECK (`passed` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Quality: Append only quality release rejection and recall history
CREATE TABLE `lot_status_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `lot_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to lots',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `new_status` VARCHAR(32) NOT NULL COMMENT 'Disposition',
  `authorized_by_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenant_memberships',
  `reason` VARCHAR(700) NOT NULL COMMENT 'Reason',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_lot_status_events_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_lot_status_events_1` CHECK (`new_status` IN ('QUARANTINED', 'RELEASED', 'REJECTED', 'RECALLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Traceability: Recall case and investigation
CREATE TABLE `recalls` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `case_number` VARCHAR(60) NOT NULL COMMENT 'Case reference',
  `reason` VARCHAR(1500) NOT NULL COMMENT 'Reason',
  `status` VARCHAR(32) NOT NULL COMMENT 'Case state',
  `opened_at` DATETIME(6) NOT NULL COMMENT 'Opened',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_recalls_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_recalls_tenant_id_company_id_case_number` (`tenant_id`, `company_id`, `case_number`),
  CONSTRAINT `ck_recalls_1` CHECK (`status` IN ('OPEN', 'CONTAINED', 'CLOSED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Traceability: Lots included in recall and action state
CREATE TABLE `recall_lots` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `recall_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to recalls',
  `lot_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to lots',
  `action` VARCHAR(32) NOT NULL COMMENT 'Action status',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_recall_lots_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_recall_lots_tenant_id_company_id_recall_id_lot_id` (`tenant_id`, `company_id`, `recall_id`, `lot_id`),
  CONSTRAINT `ck_recall_lots_1` CHECK (`action` IN ('BLOCKED', 'NOTIFIED', 'RECOVERED', 'DESTROYED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Wholesale retail preorder and quotation converted to order
CREATE TABLE `sales_orders` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `customer_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `order_kind` VARCHAR(32) NOT NULL COMMENT 'Commercial intent',
  `requested_date` DATE NULL COMMENT 'Requested delivery',
  `customer_snapshot` VARCHAR(1000) NULL COMMENT 'Historic customer identity',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sales_orders_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_sales_orders_1` CHECK (`order_kind` IN ('QUOTE', 'ORDER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Ordered goods and agreed price snapshots
CREATE TABLE `sales_order_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to sales_orders',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive quantity in transaction unit',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Quantity in item base unit',
  `uom_factor` DECIMAL(24,9) NOT NULL COMMENT 'Frozen base units per transaction unit',
  `unit_price` DECIMAL(24,6) NOT NULL COMMENT 'Price before tax in document currency',
  `discount_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Allocated line discount',
  `net_amount` DECIMAL(24,6) NOT NULL COMMENT 'Line value after discount before tax',
  `tax_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Rounded tax total',
  `gross_amount` DECIMAL(24,6) NOT NULL COMMENT 'Net plus tax',
  `item_name_snapshot` VARCHAR(200) NOT NULL COMMENT 'Historic item label',
  `sku_snapshot` VARCHAR(80) NOT NULL COMMENT 'Historic SKU',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sales_order_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_sales_order_lines_1` CHECK (quantity > 0),
  CONSTRAINT `ck_sales_order_lines_2` CHECK (base_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Physical dispatch without recognizing invoice twice
CREATE TABLE `deliveries` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `customer_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `carrier_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `tracking_number` VARCHAR(100) NULL COMMENT 'Delivery tracking',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_deliveries_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Physical delivery by order line
CREATE TABLE `delivery_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to deliveries',
  `sales_order_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to sales_order_lines',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Dispatched quantity',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_delivery_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_delivery_lines_1` CHECK (base_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Retail or wholesale financial sale including immediate POS
CREATE TABLE `sales_invoices` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `customer_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `pos_session_id` BIGINT UNSIGNED NULL COMMENT 'Reference to pos_sessions',
  `device_id` BIGINT UNSIGNED NULL COMMENT 'Reference to devices',
  `fulfillment_mode` VARCHAR(32) NOT NULL COMMENT 'Immediate mode issues stock here; separate mode uses delivery',
  `channel` VARCHAR(32) NOT NULL COMMENT 'Sales channel',
  `due_date` DATE NULL COMMENT 'Credit due date',
  `customer_snapshot` VARCHAR(1000) NULL COMMENT 'Historic billing details',
  `net_amount` DECIMAL(24,6) NOT NULL COMMENT 'Net before tax',
  `tax_amount` DECIMAL(24,6) NOT NULL COMMENT 'Tax total',
  `rounding_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Cash rounding residual',
  `total_amount` DECIMAL(24,6) NOT NULL COMMENT 'Invoice total',
  `offline_receipt_number` VARCHAR(100) NULL COMMENT 'Device issued receipt',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sales_invoices_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_sales_invoices_tenant_id_company_id_device_i_0c6b4180a2` (`tenant_id`, `company_id`, `device_id`, `offline_receipt_number`),
  CONSTRAINT `ck_sales_invoices_1` CHECK (`fulfillment_mode` IN ('IMMEDIATE', 'SEPARATE')),
  CONSTRAINT `ck_sales_invoices_2` CHECK (`channel` IN ('POS', 'WHOLESALE', 'WEB', 'OTHER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Priced item snapshots with optional order fulfillment
CREATE TABLE `sales_invoice_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to sales_invoices',
  `sales_order_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to sales_order_lines',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive quantity in transaction unit',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Quantity in item base unit',
  `uom_factor` DECIMAL(24,9) NOT NULL COMMENT 'Frozen base units per transaction unit',
  `unit_price` DECIMAL(24,6) NOT NULL COMMENT 'Price before tax in document currency',
  `discount_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Allocated line discount',
  `net_amount` DECIMAL(24,6) NOT NULL COMMENT 'Line value after discount before tax',
  `tax_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Rounded tax total',
  `gross_amount` DECIMAL(24,6) NOT NULL COMMENT 'Net plus tax',
  `item_name_snapshot` VARCHAR(200) NOT NULL COMMENT 'Historic item label',
  `sku_snapshot` VARCHAR(80) NOT NULL COMMENT 'Historic SKU',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sales_invoice_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_sales_invoice_lines_1` CHECK (quantity > 0),
  CONSTRAINT `ck_sales_invoice_lines_2` CHECK (base_quantity > 0),
  CONSTRAINT `ck_sales_invoice_lines_3` CHECK (uom_factor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Links invoice lines to separately issued deliveries
CREATE TABLE `sales_delivery_matches` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `invoice_line_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to sales_invoice_lines',
  `delivery_line_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to delivery_lines',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Quantity invoiced for shipment',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sales_delivery_matches_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_sales_delivery_matches_tenant_id_company_id__77e715c5eb` (`tenant_id`, `company_id`, `invoice_line_id`, `delivery_line_id`),
  CONSTRAINT `ck_sales_delivery_matches_1` CHECK (base_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Physical return and quality assessment independent of credit
CREATE TABLE `customer_returns` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `customer_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `reason` VARCHAR(500) NOT NULL COMMENT 'Return reason',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_customer_returns_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Returned item original invoice and physical quantities
CREATE TABLE `customer_return_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to customer_returns',
  `original_invoice_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to sales_invoice_lines',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive returned quantity',
  `disposition` VARCHAR(32) NOT NULL COMMENT 'Return disposition',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_customer_return_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_customer_return_lines_1` CHECK (base_quantity > 0),
  CONSTRAINT `ck_customer_return_lines_2` CHECK (`disposition` IN ('QUARANTINE', 'RESTOCK', 'SCRAP'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Financial credit and tax reversal independent of cash refund
CREATE TABLE `sales_credits` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `customer_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `original_invoice_id` BIGINT UNSIGNED NULL COMMENT 'Reference to sales_invoices',
  `total_amount` DECIMAL(24,6) NOT NULL COMMENT 'Positive credit total',
  `reason` VARCHAR(500) NOT NULL COMMENT 'Credit reason',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sales_credits_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Sales: Credit pricing and original invoice link
CREATE TABLE `sales_credit_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to sales_credits',
  `original_invoice_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to sales_invoice_lines',
  `return_line_id` BIGINT UNSIGNED NULL COMMENT 'Reference to customer_return_lines',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive quantity in transaction unit',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Quantity in item base unit',
  `uom_factor` DECIMAL(24,9) NOT NULL COMMENT 'Frozen base units per transaction unit',
  `unit_price` DECIMAL(24,6) NOT NULL COMMENT 'Price before tax in document currency',
  `discount_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Allocated line discount',
  `net_amount` DECIMAL(24,6) NOT NULL COMMENT 'Line value after discount before tax',
  `tax_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Rounded tax total',
  `gross_amount` DECIMAL(24,6) NOT NULL COMMENT 'Net plus tax',
  `item_name_snapshot` VARCHAR(200) NOT NULL COMMENT 'Historic item label',
  `sku_snapshot` VARCHAR(80) NOT NULL COMMENT 'Historic SKU',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sales_credit_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_sales_credit_lines_1` CHECK (quantity > 0),
  CONSTRAINT `ck_sales_credit_lines_2` CHECK (gross_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Pricing: Applied promotion or authorized manual discount audit
CREATE TABLE `sale_discounts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `invoice_line_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to sales_invoice_lines',
  `promotion_id` BIGINT UNSIGNED NULL COMMENT 'Reference to promotions',
  `amount` DECIMAL(24,6) NOT NULL COMMENT 'Applied discount',
  `authorized_by_id` BIGINT UNSIGNED NULL COMMENT 'Reference to tenant_memberships',
  `rule_snapshot` VARCHAR(1000) NOT NULL COMMENT 'Frozen rule and reason',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sale_discounts_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- POS: Physical tills and cash drawers
CREATE TABLE `pos_registers` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `code` VARCHAR(40) NOT NULL COMMENT 'Register code',
  `name` VARCHAR(100) NOT NULL COMMENT 'Register name',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pos_registers_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_pos_registers_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- POS: Cashier shift opening closing and counted cash
CREATE TABLE `pos_sessions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `register_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to pos_registers',
  `cashier_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenant_memberships',
  `opened_at` DATETIME(6) NOT NULL COMMENT 'Open UTC',
  `closed_at` DATETIME(6) NULL COMMENT 'Close UTC',
  `opening_float` DECIMAL(24,6) NOT NULL COMMENT 'Opening cash',
  `counted_cash` DECIMAL(24,6) NULL COMMENT 'Closing physical count',
  `status` VARCHAR(32) NOT NULL DEFAULT 'OPEN' COMMENT 'Session state',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pos_sessions_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  KEY `ix_pos_sessions_tenant_id_company_id_register_id_status` (`tenant_id`, `company_id`, `register_id`, `status`),
  CONSTRAINT `ck_pos_sessions_1` CHECK (`status` IN ('OPEN', 'CLOSED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- POS: Float cash in cash out and bank drops
CREATE TABLE `cash_movements` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `pos_session_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to pos_sessions',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Cash event',
  `signed_amount` DECIMAL(24,6) NOT NULL COMMENT 'Signed drawer movement',
  `reason` VARCHAR(500) NOT NULL COMMENT 'Reason',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_cash_movements_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_cash_movements_1` CHECK (`kind` IN ('FLOAT', 'PAID_IN', 'PAID_OUT', 'BANK_DROP'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- POS: Raw scale reading with tare and calibration trace
CREATE TABLE `weighing_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_line_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to document_lines',
  `device_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to devices',
  `gross_weight` DECIMAL(24,9) NOT NULL COMMENT 'Measured gross',
  `tare_weight` DECIMAL(24,9) NOT NULL COMMENT 'Tare',
  `net_weight` DECIMAL(24,9) NOT NULL COMMENT 'Gross less tare',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `scale_identifier` VARCHAR(100) NOT NULL COMMENT 'Scale ID',
  `calibration_reference` VARCHAR(150) NULL COMMENT 'Calibration reference',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_weighing_events_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_weighing_events_1` CHECK (gross_weight >= tare_weight),
  CONSTRAINT `ck_weighing_events_2` CHECK (tare_weight >= 0),
  CONSTRAINT `ck_weighing_events_3` CHECK (net_weight = gross_weight - tare_weight)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Accounting: Chart of accounts per legal entity
CREATE TABLE `accounts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(30) NOT NULL COMMENT 'Account code',
  `name` VARCHAR(150) NOT NULL COMMENT 'Account name',
  `parent_account_id` BIGINT UNSIGNED NULL COMMENT 'Reference to accounts',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Account class',
  `control_kind` VARCHAR(32) NOT NULL DEFAULT 'NONE' COMMENT 'Control account purpose',
  `is_active` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Active',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_accounts_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_accounts_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_accounts_1` CHECK (`kind` IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
  CONSTRAINT `ck_accounts_2` CHECK (`control_kind` IN ('NONE', 'AR', 'AP', 'STOCK', 'WIP', 'TAX', 'BANK', 'CASH', 'PAYROLL')),
  CONSTRAINT `ck_accounts_3` CHECK (`is_active` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Accounting: Explicit open and closed financial periods
CREATE TABLE `accounting_periods` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(30) NOT NULL COMMENT 'Period code',
  `starts_on` DATE NOT NULL COMMENT 'First business date',
  `ends_on` DATE NOT NULL COMMENT 'Last business date',
  `status` VARCHAR(32) NOT NULL DEFAULT 'OPEN' COMMENT 'Posting access',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_accounting_periods_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_accounting_periods_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_accounting_periods_1` CHECK (ends_on >= starts_on),
  CONSTRAINT `ck_accounting_periods_2` CHECK (`status` IN ('OPEN', 'CLOSED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Accounting: Validated rule mappings for automatic posting
CREATE TABLE `account_mappings` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `posting_rule` VARCHAR(80) NOT NULL COMMENT 'Rule identifier',
  `account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to accounts',
  `item_category_id` BIGINT UNSIGNED NULL COMMENT 'Reference to item_categories',
  `tax_code_id` BIGINT UNSIGNED NULL COMMENT 'Reference to tax_codes',
  `priority` INT NOT NULL COMMENT 'Deterministic matching order',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_account_mappings_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Accounting: One immutable double entry journal per posting document
CREATE TABLE `journal_entries` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `period_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to accounting_periods',
  `currency_code` VARCHAR(3) NOT NULL COMMENT 'Transaction currency',
  `exchange_rate` DECIMAL(24,9) NOT NULL COMMENT 'Functional units per currency unit',
  `reverses_journal_id` BIGINT UNSIGNED NULL COMMENT 'Reference to journal_entries',
  `description` VARCHAR(500) NOT NULL COMMENT 'Posting narrative',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_journal_entries_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_journal_entries_tenant_id_company_id_document_id` (`tenant_id`, `company_id`, `document_id`),
  UNIQUE KEY `uq_journal_entries_tenant_id_company_id_reverses_journal_id` (`tenant_id`, `company_id`, `reverses_journal_id`),
  CONSTRAINT `ck_journal_entries_1` CHECK (exchange_rate > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Accounting: Immutable debits and credits with optional party and branch dimensions
CREATE TABLE `journal_lines` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `journal_entry_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to journal_entries',
  `line_number` INT UNSIGNED NOT NULL COMMENT 'Line order',
  `account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to accounts',
  `party_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `debit` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Transaction debit',
  `credit` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Transaction credit',
  `debit_base` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Functional debit',
  `credit_base` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Functional credit',
  `description` VARCHAR(500) NULL COMMENT 'Narrative',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_journal_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_journal_lines_tenant_id_company_id_journal_e_d3f8976dd5` (`tenant_id`, `company_id`, `journal_entry_id`, `line_number`),
  KEY `ix_journal_lines_tenant_id_company_id_account_id_id` (`tenant_id`, `company_id`, `account_id`, `id`),
  KEY `ix_journal_lines_tenant_id_company_id_party_id_id` (`tenant_id`, `company_id`, `party_id`, `id`),
  CONSTRAINT `ck_journal_lines_1` CHECK (debit >= 0 AND credit >= 0 AND debit_base >= 0 AND credit_base >= 0),
  CONSTRAINT `ck_journal_lines_2` CHECK ((debit = 0 OR credit = 0) AND (debit_base = 0 OR credit_base = 0)),
  CONSTRAINT `ck_journal_lines_3` CHECK (debit + credit + debit_base + credit_base > 0),
  CONSTRAINT `ck_journal_lines_4` CHECK (NOT (debit > 0 AND credit_base > 0) AND NOT (credit > 0 AND debit_base > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Accounting: AR AP and advances with signed functional and document amount
CREATE TABLE `open_items` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `party_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `control_account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to accounts',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Subledger kind',
  `currency_code` VARCHAR(3) NOT NULL COMMENT 'Item currency',
  `signed_amount` DECIMAL(24,6) NOT NULL COMMENT 'Positive invoice negative credit or advance',
  `signed_amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Original functional amount',
  `due_date` DATE NULL COMMENT 'Maturity',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_open_items_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_open_items_tenant_id_company_id_document_id_kind_party_id` (`tenant_id`, `company_id`, `document_id`, `kind`, `party_id`),
  CONSTRAINT `ck_open_items_1` CHECK (`kind` IN ('AR', 'AP', 'CUSTOMER_ADVANCE', 'SUPPLIER_ADVANCE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Accounting: Append only allocation of opposite signed open items
CREATE TABLE `settlements` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `debit_open_item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to open_items',
  `credit_open_item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to open_items',
  `debit_currency_amount` DECIMAL(24,6) NOT NULL COMMENT 'Positive amount in debit item currency',
  `credit_currency_amount` DECIMAL(24,6) NOT NULL COMMENT 'Positive amount in credit item currency',
  `settled_base` DECIMAL(24,6) NOT NULL COMMENT 'Functional value settled',
  `realized_fx_base` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Realized exchange gain or loss',
  `reverses_settlement_id` BIGINT UNSIGNED NULL COMMENT 'Reference to settlements',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_settlements_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_settlements_tenant_id_company_id_reverses_settlement_id` (`tenant_id`, `company_id`, `reverses_settlement_id`),
  CONSTRAINT `ck_settlements_1` CHECK (debit_open_item_id <> credit_open_item_id),
  CONSTRAINT `ck_settlements_2` CHECK (debit_currency_amount > 0 AND credit_currency_amount > 0 AND settled_base > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Payments: Cash card bank mobile cheque tender methods
CREATE TABLE `payment_methods` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(40) NOT NULL COMMENT 'Tender code',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Tender type',
  `clearing_account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to accounts',
  `offline_allowed` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Permitted while disconnected',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_payment_methods_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_payment_methods_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_payment_methods_1` CHECK (`kind` IN ('CASH', 'CARD', 'BANK', 'MOBILE', 'CHEQUE', 'OTHER')),
  CONSTRAINT `ck_payment_methods_2` CHECK (`offline_allowed` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Payments: Incoming outgoing and refund payment root
CREATE TABLE `payments` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `party_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `direction` VARCHAR(32) NOT NULL COMMENT 'Cash flow direction',
  `purpose` VARCHAR(32) NOT NULL COMMENT 'Payment purpose',
  `pos_session_id` BIGINT UNSIGNED NULL COMMENT 'Reference to pos_sessions',
  `amount` DECIMAL(24,6) NOT NULL COMMENT 'Total non negative payment',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_payments_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_payments_1` CHECK (`direction` IN ('IN', 'OUT')),
  CONSTRAINT `ck_payments_2` CHECK (`purpose` IN ('SALE', 'PURCHASE', 'REFUND', 'ADVANCE', 'OTHER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Payments: Split payments one row per tender with cash change
CREATE TABLE `payment_tenders` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `payment_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to payments',
  `payment_method_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to payment_methods',
  `tendered_amount` DECIMAL(24,6) NOT NULL COMMENT 'Amount received or sent',
  `change_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Cash returned',
  `applied_amount` DECIMAL(24,6) NOT NULL COMMENT 'Tendered less change',
  `provider_reference` VARCHAR(200) COLLATE utf8mb4_bin NULL COMMENT 'External transaction identifier',
  `status` VARCHAR(32) NOT NULL COMMENT 'Provider status',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_payment_tenders_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_payment_tenders_tenant_id_company_id_payment_7d5e918abb` (`tenant_id`, `company_id`, `payment_method_id`, `provider_reference`),
  CONSTRAINT `ck_payment_tenders_1` CHECK (tendered_amount >= 0 AND change_amount >= 0 AND applied_amount >= 0),
  CONSTRAINT `ck_payment_tenders_2` CHECK (applied_amount = tendered_amount - change_amount),
  CONSTRAINT `ck_payment_tenders_3` CHECK (`status` IN ('PENDING', 'CAPTURED', 'FAILED', 'REFUNDED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Payments: External authorization and callback state outside stock transaction
CREATE TABLE `payment_intents` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `payment_method_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to payment_methods',
  `provider` VARCHAR(60) NOT NULL COMMENT 'Provider code',
  `provider_intent_id` VARCHAR(200) COLLATE utf8mb4_bin NOT NULL COMMENT 'External intent',
  `amount` DECIMAL(24,6) NOT NULL COMMENT 'Requested amount',
  `status` VARCHAR(32) NOT NULL COMMENT 'Intent state',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_payment_intents_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_payment_intents_tenant_id_company_id_provide_4ffefc6cfb` (`tenant_id`, `company_id`, `provider`, `provider_intent_id`),
  CONSTRAINT `ck_payment_intents_1` CHECK (`status` IN ('CREATED', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'CANCELLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Banking: Bank account linked to general ledger
CREATE TABLE `bank_accounts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(40) NOT NULL COMMENT 'Bank account code',
  `bank_name` VARCHAR(100) NOT NULL COMMENT 'Bank',
  `masked_number` VARCHAR(80) NOT NULL COMMENT 'Masked account reference',
  `account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to accounts',
  `currency_code` VARCHAR(3) NOT NULL COMMENT 'Currency',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bank_accounts_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_bank_accounts_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Banking: Imported bank movements with deduplication
CREATE TABLE `bank_statement_lines` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `bank_account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to bank_accounts',
  `import_reference` VARCHAR(150) NOT NULL COMMENT 'Deterministic statement row key',
  `value_date` DATE NOT NULL COMMENT 'Bank value date',
  `signed_amount` DECIMAL(24,6) NOT NULL COMMENT 'Signed bank amount',
  `description` VARCHAR(700) NOT NULL COMMENT 'Bank narrative',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bank_statement_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_bank_statement_lines_tenant_id_company_id_ba_c4abbd25c1` (`tenant_id`, `company_id`, `bank_account_id`, `import_reference`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Banking: Many to many bank to journal reconciliation
CREATE TABLE `bank_matches` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `statement_line_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to bank_statement_lines',
  `journal_line_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to journal_lines',
  `amount` DECIMAL(24,6) NOT NULL COMMENT 'Matched amount',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bank_matches_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_bank_matches_tenant_id_company_id_statement__72a8a7f49f` (`tenant_id`, `company_id`, `statement_line_id`, `journal_line_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Expenses: Business overhead petty cash and employee claims
CREATE TABLE `expenses` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `party_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `description` VARCHAR(700) NOT NULL COMMENT 'Expense reason',
  `total_amount` DECIMAL(24,6) NOT NULL COMMENT 'Expense total',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_expenses_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Expenses: Expense account cost and recoverable tax
CREATE TABLE `expense_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to expenses',
  `account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to accounts',
  `net_amount` DECIMAL(24,6) NOT NULL COMMENT 'Expense before tax',
  `tax_amount` DECIMAL(24,6) NOT NULL COMMENT 'Tax amount',
  `gross_amount` DECIMAL(24,6) NOT NULL COMMENT 'Gross cost',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_expense_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_expense_lines_1` CHECK (gross_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Accounting: Account and branch budgets by period
CREATE TABLE `budgets` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `period_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to accounting_periods',
  `account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to accounts',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Budget allocation',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_budgets_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_budgets_tenant_id_company_id_period_id_accou_3281b683ad` (`tenant_id`, `company_id`, `period_id`, `account_id`, `branch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Workforce: Employee identity separately secured from customer contacts
CREATE TABLE `employees` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `employee_number` VARCHAR(50) NOT NULL COMMENT 'Staff number',
  `display_name` VARCHAR(200) NOT NULL COMMENT 'Employee name',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `membership_id` BIGINT UNSIGNED NULL COMMENT 'Reference to tenant_memberships',
  `joined_on` DATE NOT NULL COMMENT 'Employment start',
  `left_on` DATE NULL COMMENT 'Employment end',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_employees_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_employees_tenant_id_company_id_employee_number` (`tenant_id`, `company_id`, `employee_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Workforce: Effective dated salary and employment terms
CREATE TABLE `employment_terms` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `employee_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to employees',
  `valid_from` DATE NOT NULL COMMENT 'Start',
  `valid_to` DATE NULL COMMENT 'End',
  `pay_basis` VARCHAR(32) NOT NULL COMMENT 'Salary basis',
  `rate_base` DECIMAL(24,6) NOT NULL COMMENT 'Functional currency rate',
  `standard_hours` DECIMAL(24,9) NOT NULL COMMENT 'Expected hours',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_employment_terms_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_employment_terms_tenant_id_company_id_employ_25bb92813a` (`tenant_id`, `company_id`, `employee_id`, `valid_from`),
  CONSTRAINT `ck_employment_terms_1` CHECK (`pay_basis` IN ('MONTH', 'DAY', 'HOUR', 'PIECE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Workforce: Attendance overtime and manufacturing labour time
CREATE TABLE `time_entries` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `employee_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to employees',
  `production_operation_id` BIGINT UNSIGNED NULL COMMENT 'Reference to production_operations',
  `started_at` DATETIME(6) NOT NULL COMMENT 'Clock in',
  `ended_at` DATETIME(6) NULL COMMENT 'Clock out',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Time type',
  `status` VARCHAR(32) NOT NULL COMMENT 'Approval',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_time_entries_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_time_entries_1` CHECK (`kind` IN ('REGULAR', 'OVERTIME', 'LEAVE', 'ABSENCE')),
  CONSTRAINT `ck_time_entries_2` CHECK (`status` IN ('DRAFT', 'APPROVED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Workforce: Leave approval and dates
CREATE TABLE `leave_requests` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `employee_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to employees',
  `leave_type` VARCHAR(50) NOT NULL COMMENT 'Leave code',
  `starts_on` DATE NOT NULL COMMENT 'First date',
  `ends_on` DATE NOT NULL COMMENT 'Last date',
  `days` DECIMAL(24,9) NOT NULL COMMENT 'Requested days',
  `status` VARCHAR(32) NOT NULL COMMENT 'Request state',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_leave_requests_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_leave_requests_1` CHECK (`status` IN ('REQUESTED', 'APPROVED', 'REJECTED', 'CANCELLED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Workforce: Configurable earnings deductions and employer contributions
CREATE TABLE `pay_components` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `code` VARCHAR(50) NOT NULL COMMENT 'Component code',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Component type',
  `expense_account_id` BIGINT UNSIGNED NULL COMMENT 'Reference to accounts',
  `liability_account_id` BIGINT UNSIGNED NULL COMMENT 'Reference to accounts',
  `rule_json` JSON NOT NULL COMMENT 'Effective payroll rule metadata',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pay_components_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_pay_components_tenant_id_company_id_code` (`tenant_id`, `company_id`, `code`),
  CONSTRAINT `ck_pay_components_1` CHECK (`kind` IN ('EARNING', 'DEDUCTION', 'EMPLOYER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Workforce: Payroll calculation period and posting approval
CREATE TABLE `payroll_runs` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `starts_on` DATE NOT NULL COMMENT 'Period start',
  `ends_on` DATE NOT NULL COMMENT 'Period end',
  `calculation_status` VARCHAR(32) NOT NULL COMMENT 'Payroll state',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_payroll_runs_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_payroll_runs_1` CHECK (`calculation_status` IN ('DRAFT', 'CALCULATED', 'APPROVED', 'PAID'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Workforce: Employee result per payroll run
CREATE TABLE `payslips` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `payroll_run_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to payroll_runs',
  `employee_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to employees',
  `gross_base` DECIMAL(24,6) NOT NULL COMMENT 'Gross earnings',
  `deductions_base` DECIMAL(24,6) NOT NULL COMMENT 'Employee deductions',
  `net_base` DECIMAL(24,6) NOT NULL COMMENT 'Net pay',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_payslips_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_payslips_tenant_id_company_id_payroll_run_id_employee_id` (`tenant_id`, `company_id`, `payroll_run_id`, `employee_id`),
  CONSTRAINT `ck_payslips_1` CHECK (net_base = gross_base - deductions_base)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Workforce: Frozen calculated payroll components
CREATE TABLE `payslip_lines` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `payslip_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to payslips',
  `pay_component_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to pay_components',
  `amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Calculated amount',
  `calculation_snapshot` JSON NOT NULL COMMENT 'Inputs rates and rule version',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_payslip_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Assets: Capital equipment and machinery register
CREATE TABLE `assets` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `asset_number` VARCHAR(60) NOT NULL COMMENT 'Asset ID',
  `name` VARCHAR(200) NOT NULL COMMENT 'Asset name',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `work_center_id` BIGINT UNSIGNED NULL COMMENT 'Reference to work_centers',
  `acquisition_document_id` BIGINT UNSIGNED NULL COMMENT 'Reference to documents',
  `acquired_on` DATE NOT NULL COMMENT 'Acquired date',
  `cost_base` DECIMAL(24,6) NOT NULL COMMENT 'Capitalized cost',
  `residual_value_base` DECIMAL(24,6) NOT NULL COMMENT 'Residual value',
  `useful_life_months` INT UNSIGNED NOT NULL COMMENT 'Useful life',
  `status` VARCHAR(32) NOT NULL COMMENT 'Lifecycle',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_assets_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_assets_tenant_id_company_id_asset_number` (`tenant_id`, `company_id`, `asset_number`),
  CONSTRAINT `ck_assets_1` CHECK (`status` IN ('ACTIVE', 'DISPOSED', 'RETIRED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Assets: Posted period depreciation schedule and actuals
CREATE TABLE `asset_depreciations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `asset_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to assets',
  `period_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to accounting_periods',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Depreciation amount',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_asset_depreciations_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_asset_depreciations_tenant_id_company_id_ass_1cff8bb5f5` (`tenant_id`, `company_id`, `asset_id`, `period_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Assets: Preventive or corrective maintenance work
CREATE TABLE `maintenance_orders` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `asset_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to assets',
  `work_number` VARCHAR(60) NOT NULL COMMENT 'Maintenance reference',
  `scheduled_at` DATETIME(6) NULL COMMENT 'Due',
  `completed_at` DATETIME(6) NULL COMMENT 'Completed',
  `description` VARCHAR(1500) NOT NULL COMMENT 'Work details',
  `status` VARCHAR(32) NOT NULL COMMENT 'Execution',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_maintenance_orders_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_maintenance_orders_tenant_id_company_id_work_number` (`tenant_id`, `company_id`, `work_number`),
  CONSTRAINT `ck_maintenance_orders_1` CHECK (`status` IN ('OPEN', 'IN_PROGRESS', 'CLOSED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Assets: Maintenance material expense and labour source documents
CREATE TABLE `maintenance_costs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `maintenance_order_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to maintenance_orders',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `amount_base` DECIMAL(24,6) NOT NULL COMMENT 'Cost contribution',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Cost classification',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_maintenance_costs_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_maintenance_costs_1` CHECK (`kind` IN ('MATERIAL', 'LABOUR', 'SERVICE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- CRM: Customer loyalty membership
CREATE TABLE `loyalty_accounts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `party_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `membership_number` VARCHAR(80) NOT NULL COMMENT 'Loyalty card',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_loyalty_accounts_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_loyalty_accounts_tenant_id_company_id_party_id` (`tenant_id`, `company_id`, `party_id`),
  UNIQUE KEY `uq_loyalty_accounts_tenant_id_company_id_membership_number` (`tenant_id`, `company_id`, `membership_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- CRM: Append only points earned redeemed expired and reversed
CREATE TABLE `loyalty_entries` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `loyalty_account_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to loyalty_accounts',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to documents',
  `signed_points` DECIMAL(24,9) NOT NULL COMMENT 'Signed points',
  `kind` VARCHAR(32) NOT NULL COMMENT 'Reason',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_loyalty_entries_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  KEY `ix_loyalty_entries_tenant_id_company_id_loyalty_5cac42f832` (`tenant_id`, `company_id`, `loyalty_account_id`, `id`),
  CONSTRAINT `ck_loyalty_entries_1` CHECK (`kind` IN ('EARN', 'REDEEM', 'EXPIRE', 'REVERSE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- CRM: Customer complaint and product quality follow up
CREATE TABLE `service_cases` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `party_id` BIGINT UNSIGNED NULL COMMENT 'Reference to parties',
  `lot_id` BIGINT UNSIGNED NULL COMMENT 'Reference to lots',
  `invoice_id` BIGINT UNSIGNED NULL COMMENT 'Reference to sales_invoices',
  `case_number` VARCHAR(60) NOT NULL COMMENT 'Case number',
  `description` VARCHAR(2000) NOT NULL COMMENT 'Complaint',
  `status` VARCHAR(32) NOT NULL COMMENT 'State',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_service_cases_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_service_cases_tenant_id_company_id_case_number` (`tenant_id`, `company_id`, `case_number`),
  CONSTRAINT `ck_service_cases_1` CHECK (`status` IN ('OPEN', 'IN_PROGRESS', 'RESOLVED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Offline: Registered till or scale integration with revocable identity
CREATE TABLE `devices` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `branch_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to branches',
  `register_id` BIGINT UNSIGNED NULL COMMENT 'Reference to pos_registers',
  `public_id` BINARY(16) NOT NULL COMMENT 'Device UUID',
  `name` VARCHAR(100) NOT NULL COMMENT 'Device label',
  `receipt_prefix` VARCHAR(40) COLLATE utf8mb4_bin NOT NULL COMMENT 'Globally unique company device receipt prefix',
  `public_key` VARBINARY(512) NULL COMMENT 'Verification public key',
  `status` VARCHAR(32) NOT NULL DEFAULT 'ACTIVE' COMMENT 'Access state',
  `last_sequence` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Last accepted device sequence',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_devices_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_devices_tenant_id_company_id_public_id` (`tenant_id`, `company_id`, `public_id`),
  UNIQUE KEY `uq_devices_tenant_id_company_id_receipt_prefix` (`tenant_id`, `company_id`, `receipt_prefix`),
  CONSTRAINT `ck_devices_1` CHECK (`status` IN ('ACTIVE', 'REVOKED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Offline: Durable inbox of immutable device submissions and conflict decisions
CREATE TABLE `offline_operations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `device_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to devices',
  `operation_uuid` BINARY(16) NOT NULL COMMENT 'Client generated UUID',
  `device_sequence` BIGINT UNSIGNED NOT NULL COMMENT 'Monotonic sequence',
  `payload_hash` BINARY(32) NOT NULL COMMENT 'Canonical payload SHA256',
  `payload_json` JSON NOT NULL COMMENT 'Immutable submitted payload; redact card secrets',
  `occurred_at` DATETIME(6) NOT NULL COMMENT 'Client UTC event',
  `received_at` DATETIME(6) NOT NULL COMMENT 'Server UTC reception',
  `status` VARCHAR(32) NOT NULL DEFAULT 'RECEIVED' COMMENT 'Reconciliation state',
  `result_document_id` BIGINT UNSIGNED NULL COMMENT 'Reference to documents',
  `conflict_reason` VARCHAR(1000) NULL COMMENT 'Resolution reason',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_offline_operations_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_offline_operations_tenant_id_company_id_operation_uuid` (`tenant_id`, `company_id`, `operation_uuid`),
  UNIQUE KEY `uq_offline_operations_tenant_id_company_id_devi_d83a790650` (`tenant_id`, `company_id`, `device_id`, `device_sequence`),
  KEY `ix_offline_operations_tenant_id_company_id_stat_7d3c1a2baa` (`tenant_id`, `company_id`, `status`, `received_at`, `id`),
  CONSTRAINT `ck_offline_operations_1` CHECK (`status` IN ('RECEIVED', 'ACCEPTED', 'POSTED', 'CONFLICT', 'REJECTED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Offline: Exclusive non expiring bucket reservations for disconnected devices
CREATE TABLE `offline_stock_allocations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `device_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to devices',
  `reservation_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to stock_reservations',
  `allocation_uuid` BINARY(16) NOT NULL COMMENT 'Allocation identity',
  `acknowledged_consumed_base` DECIMAL(24,9) NOT NULL DEFAULT 0 COMMENT 'Server reconciled consumption',
  `status` VARCHAR(32) NOT NULL COMMENT 'Release only after acknowledged reconciliation',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_offline_stock_allocations_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_offline_stock_allocations_tenant_id_company__9b926c67d2` (`tenant_id`, `company_id`, `reservation_id`),
  UNIQUE KEY `uq_offline_stock_allocations_tenant_id_company__a4ae91e1de` (`tenant_id`, `company_id`, `allocation_uuid`),
  CONSTRAINT `ck_offline_stock_allocations_1` CHECK (`status` IN ('ACTIVE', 'RECONCILING', 'CLOSED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Offline: Per device ordered change feed checkpoint
CREATE TABLE `sync_cursors` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `device_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to devices',
  `stream` VARCHAR(60) NOT NULL COMMENT 'Catalog prices stock etc',
  `last_change_id` BIGINT UNSIGNED NOT NULL COMMENT 'Last acknowledged change',
  `acknowledged_at` DATETIME(6) NOT NULL COMMENT 'Server checkpoint time',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sync_cursors_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_sync_cursors_tenant_id_company_id_device_id_stream` (`tenant_id`, `company_id`, `device_id`, `stream`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Offline: Ordered company scoped invalidation and tombstone feed written by a serialized relay
CREATE TABLE `change_feed` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `entity_type` VARCHAR(60) NOT NULL COMMENT 'Entity type',
  `entity_id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal entity ID serialized as a string',
  `operation` VARCHAR(32) NOT NULL COMMENT 'Change type',
  `entity_version` BIGINT UNSIGNED NOT NULL COMMENT 'Optimistic version',
  `occurred_at` DATETIME(6) NOT NULL COMMENT 'Change UTC',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_change_feed_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  KEY `ix_change_feed_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_change_feed_1` CHECK (`operation` IN ('UPSERT', 'DELETE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Operations: Atomic command deduplication including request hash and response
CREATE TABLE `idempotency_keys` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `actor_scope` VARCHAR(100) NOT NULL COMMENT 'Membership or device namespace',
  `command_name` VARCHAR(100) NOT NULL COMMENT 'Command route',
  `key_value` VARCHAR(150) COLLATE utf8mb4_bin NOT NULL COMMENT 'Client idempotency key',
  `request_hash` BINARY(32) NOT NULL COMMENT 'Canonical request hash',
  `result_document_id` BIGINT UNSIGNED NULL COMMENT 'Reference to documents',
  `response_json` JSON NULL COMMENT 'Committed response body',
  `status` VARCHAR(32) NOT NULL COMMENT 'Command state',
  `expires_at` DATETIME(6) NULL COMMENT 'Cleanup after retry horizon',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_idempotency_keys_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_idempotency_keys_tenant_id_company_id_actor__ed4377b411` (`tenant_id`, `company_id`, `actor_scope`, `command_name`, `key_value`),
  CONSTRAINT `ck_idempotency_keys_1` CHECK (`status` IN ('IN_PROGRESS', 'COMPLETED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Operations: Transactional event outbox with leased worker delivery
CREATE TABLE `outbox_messages` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `event_uuid` BINARY(16) NOT NULL COMMENT 'Stable event UUID',
  `event_type` VARCHAR(100) NOT NULL COMMENT 'Versioned event type',
  `payload_json` JSON NOT NULL COMMENT 'Minimal domain payload',
  `available_at` DATETIME(6) NOT NULL COMMENT 'Retry scheduling',
  `leased_until` DATETIME(6) NULL COMMENT 'Worker lease',
  `processed_at` DATETIME(6) NULL COMMENT 'Successful delivery',
  `attempt_count` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Delivery attempts',
  `last_error` VARCHAR(1000) NULL COMMENT 'Truncated sanitized failure',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_outbox_messages_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_outbox_messages_tenant_id_company_id_event_uuid` (`tenant_id`, `company_id`, `event_uuid`),
  KEY `ix_outbox_messages_tenant_id_company_id_process_10b9547b9d` (`tenant_id`, `company_id`, `processed_at`, `available_at`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Operations: Deduplicate external provider callbacks and consumers
CREATE TABLE `integration_inbox` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `provider` VARCHAR(60) NOT NULL COMMENT 'Provider namespace',
  `event_key` VARCHAR(200) COLLATE utf8mb4_bin NOT NULL COMMENT 'External stable event ID',
  `payload_hash` BINARY(32) NOT NULL COMMENT 'Event content hash',
  `received_at` DATETIME(6) NOT NULL COMMENT 'Receipt',
  `processed_at` DATETIME(6) NULL COMMENT 'Processing complete',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_integration_inbox_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_integration_inbox_tenant_id_company_id_provider_event_key` (`tenant_id`, `company_id`, `provider`, `event_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Operations: Append only access and business action audit without secrets
CREATE TABLE `audit_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `membership_id` BIGINT UNSIGNED NULL COMMENT 'Reference to tenant_memberships',
  `action` VARCHAR(100) NOT NULL COMMENT 'Action code',
  `entity_type` VARCHAR(60) NOT NULL COMMENT 'Entity type',
  `entity_id` BIGINT UNSIGNED NULL COMMENT 'Entity internal ID',
  `correlation_uuid` BINARY(16) NOT NULL COMMENT 'Request trace ID',
  `details_json` JSON NULL COMMENT 'Redacted before after metadata',
  `occurred_at` DATETIME(6) NOT NULL COMMENT 'UTC action time',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_audit_events_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  KEY `ix_audit_events_tenant_id_company_id_occurred_at_id` (`tenant_id`, `company_id`, `occurred_at`, `id`),
  KEY `ix_audit_events_tenant_id_company_id_entity_typ_6261c4dce9` (`tenant_id`, `company_id`, `entity_type`, `entity_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Operations: Hashed revocable integration key scopes
CREATE TABLE `api_credentials` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `name` VARCHAR(100) NOT NULL COMMENT 'Integration name',
  `key_hash` BINARY(32) NOT NULL COMMENT 'Hash only',
  `permission_scopes` JSON NOT NULL COMMENT 'Allowed permissions',
  `expires_at` DATETIME(6) NULL COMMENT 'Expiration',
  `revoked_at` DATETIME(6) NULL COMMENT 'Revocation',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_api_credentials_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  UNIQUE KEY `uq_api_credentials_tenant_id_company_id_key_hash` (`tenant_id`, `company_id`, `key_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Planning: Reproducible material requirements planning snapshots
CREATE TABLE `planning_runs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `warehouse_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to warehouses',
  `as_of_at` DATETIME(6) NOT NULL COMMENT 'Input snapshot time',
  `horizon_end` DATE NOT NULL COMMENT 'Planning horizon',
  `status` VARCHAR(32) NOT NULL COMMENT 'Planning run state',
  `input_watermark` BIGINT UNSIGNED NOT NULL COMMENT 'Stock ledger snapshot watermark',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_planning_runs_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_planning_runs_1` CHECK (`status` IN ('RUNNING', 'COMPLETE', 'FAILED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Planning: Time phased shortage and suggested procurement production or transfer
CREATE TABLE `supply_suggestions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `planning_run_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to planning_runs',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `required_on` DATE NOT NULL COMMENT 'Required date',
  `required_quantity_base` DECIMAL(24,9) NOT NULL COMMENT 'Net shortage',
  `method` VARCHAR(32) NOT NULL COMMENT 'Suggested supply',
  `converted_document_id` BIGINT UNSIGNED NULL COMMENT 'Reference to documents',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supply_suggestions_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_supply_suggestions_1` CHECK (required_quantity_base > 0),
  CONSTRAINT `ck_supply_suggestions_2` CHECK (`method` IN ('BUY', 'MAKE', 'TRANSFER'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Internal approved request before supplier selection
CREATE TABLE `purchase_requisitions` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `requested_by_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenant_memberships',
  `required_on` DATE NOT NULL COMMENT 'Need date',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_purchase_requisitions_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Requested item quantities and planning source
CREATE TABLE `purchase_requisition_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to purchase_requisitions',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Requested quantity',
  `supply_suggestion_id` BIGINT UNSIGNED NULL COMMENT 'Reference to supply_suggestions',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_purchase_requisition_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_purchase_requisition_lines_1` CHECK (base_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Supplier offer for quote comparison before ordering
CREATE TABLE `supplier_quotes` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `supplier_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `requisition_id` BIGINT UNSIGNED NULL COMMENT 'Reference to purchase_requisitions',
  `valid_until` DATE NOT NULL COMMENT 'Quote validity',
  `quote_reference` VARCHAR(100) NOT NULL COMMENT 'Supplier quote reference',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_quotes_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Purchasing: Quoted prices quantities and lead times
CREATE TABLE `supplier_quote_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to supplier_quotes',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `uom_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to units',
  `quantity` DECIMAL(24,9) NOT NULL COMMENT 'Positive quantity in transaction unit',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Quantity in item base unit',
  `uom_factor` DECIMAL(24,9) NOT NULL COMMENT 'Frozen base units per transaction unit',
  `unit_price` DECIMAL(24,6) NOT NULL COMMENT 'Price before tax in document currency',
  `discount_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Allocated line discount',
  `net_amount` DECIMAL(24,6) NOT NULL COMMENT 'Line value after discount before tax',
  `tax_amount` DECIMAL(24,6) NOT NULL DEFAULT 0 COMMENT 'Rounded tax total',
  `gross_amount` DECIMAL(24,6) NOT NULL COMMENT 'Net plus tax',
  `item_name_snapshot` VARCHAR(200) NOT NULL COMMENT 'Historic item label',
  `sku_snapshot` VARCHAR(80) NOT NULL COMMENT 'Historic SKU',
  `lead_days` INT UNSIGNED NOT NULL COMMENT 'Quoted lead time',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supplier_quote_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_supplier_quote_lines_1` CHECK (quantity > 0),
  CONSTRAINT `ck_supplier_quote_lines_2` CHECK (base_quantity > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Outsourced processing with company owned stock at supplier
CREATE TABLE `subcontract_orders` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `supplier_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to parties',
  `production_order_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to production_orders',
  `expected_on` DATE NOT NULL COMMENT 'Expected return',
  `agreed_service_amount` DECIMAL(24,6) NOT NULL COMMENT 'Processing fee excluding tax',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_subcontract_orders_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Manufacturing: Material sent and expected output for subcontract processing
CREATE TABLE `subcontract_order_lines` (
  `id` BIGINT UNSIGNED NOT NULL COMMENT 'Internal primary key; subtype shares root ID',
  `tenant_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to tenants',
  `company_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to companies',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to subcontract_orders',
  `item_id` BIGINT UNSIGNED NOT NULL COMMENT 'Reference to items',
  `role` VARCHAR(32) NOT NULL COMMENT 'Outsource line role',
  `base_quantity` DECIMAL(24,9) NOT NULL COMMENT 'Expected quantity',
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC creation timestamp',
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC mutable row update timestamp',
  `row_version` BIGINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Application incremented optimistic version',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_subcontract_order_lines_tenant_id_company_id_id` (`tenant_id`, `company_id`, `id`),
  CONSTRAINT `ck_subcontract_order_lines_1` CHECK (base_quantity > 0),
  CONSTRAINT `ck_subcontract_order_lines_2` CHECK (`role` IN ('MATERIAL_SENT', 'OUTPUT_EXPECTED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Foreign keys added after creation to resolve forward references. Never disable FK checks.
ALTER TABLE `tenant_memberships` ADD CONSTRAINT `fk_tenant_memberships_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `tenant_memberships` ADD CONSTRAINT `fk_tenant_memberships_user_id_users` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `roles` ADD CONSTRAINT `fk_roles_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `role_permissions` ADD CONSTRAINT `fk_role_permissions_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `role_permissions` ADD CONSTRAINT `fk_role_permissions_tenant_id_role_id_roles` FOREIGN KEY (`tenant_id`, `role_id`) REFERENCES `roles` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `role_permissions` ADD CONSTRAINT `fk_role_permissions_permission_id_permissions` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `membership_roles` ADD CONSTRAINT `fk_membership_roles_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `membership_roles` ADD CONSTRAINT `fk_membership_roles_tenant_id_membership_id_ten_9839195aa4` FOREIGN KEY (`tenant_id`, `membership_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `membership_roles` ADD CONSTRAINT `fk_membership_roles_tenant_id_role_id_roles` FOREIGN KEY (`tenant_id`, `role_id`) REFERENCES `roles` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `companies` ADD CONSTRAINT `fk_companies_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `companies` ADD CONSTRAINT `fk_companies_base_currency_code_currencies` FOREIGN KEY (`base_currency_code`) REFERENCES `currencies` (`code`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `branches` ADD CONSTRAINT `fk_branches_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `branches` ADD CONSTRAINT `fk_branches_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `membership_branches` ADD CONSTRAINT `fk_membership_branches_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `membership_branches` ADD CONSTRAINT `fk_membership_branches_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `membership_branches` ADD CONSTRAINT `fk_membership_branches_tenant_id_membership_id__536dd9cecc` FOREIGN KEY (`tenant_id`, `membership_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `membership_branches` ADD CONSTRAINT `fk_membership_branches_tenant_id_company_id_bra_d536f58d46` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `company_role_grants` ADD CONSTRAINT `fk_company_role_grants_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `company_role_grants` ADD CONSTRAINT `fk_company_role_grants_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `company_role_grants` ADD CONSTRAINT `fk_company_role_grants_tenant_id_membership_id__ce76dbe4a6` FOREIGN KEY (`tenant_id`, `membership_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `company_role_grants` ADD CONSTRAINT `fk_company_role_grants_tenant_id_role_id_roles` FOREIGN KEY (`tenant_id`, `role_id`) REFERENCES `roles` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `warehouses` ADD CONSTRAINT `fk_warehouses_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `warehouses` ADD CONSTRAINT `fk_warehouses_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `warehouses` ADD CONSTRAINT `fk_warehouses_tenant_id_company_id_branch_id_branches` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `locations` ADD CONSTRAINT `fk_locations_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `locations` ADD CONSTRAINT `fk_locations_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `locations` ADD CONSTRAINT `fk_locations_tenant_id_company_id_warehouse_id_warehouses` FOREIGN KEY (`tenant_id`, `company_id`, `warehouse_id`) REFERENCES `warehouses` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `locations` ADD CONSTRAINT `fk_locations_tenant_id_company_id_parent_locati_5b0569c8a8` FOREIGN KEY (`tenant_id`, `company_id`, `parent_location_id`) REFERENCES `locations` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `tenant_features` ADD CONSTRAINT `fk_tenant_features_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subscriptions` ADD CONSTRAINT `fk_subscriptions_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `units` ADD CONSTRAINT `fk_units_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `units` ADD CONSTRAINT `fk_units_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_categories` ADD CONSTRAINT `fk_item_categories_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_categories` ADD CONSTRAINT `fk_item_categories_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_categories` ADD CONSTRAINT `fk_item_categories_tenant_id_company_id_parent__29569a438b` FOREIGN KEY (`tenant_id`, `company_id`, `parent_id`) REFERENCES `item_categories` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `items` ADD CONSTRAINT `fk_items_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `items` ADD CONSTRAINT `fk_items_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `items` ADD CONSTRAINT `fk_items_tenant_id_company_id_category_id_item_categories` FOREIGN KEY (`tenant_id`, `company_id`, `category_id`) REFERENCES `item_categories` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `items` ADD CONSTRAINT `fk_items_tenant_id_company_id_base_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `base_uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_units` ADD CONSTRAINT `fk_item_units_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_units` ADD CONSTRAINT `fk_item_units_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_units` ADD CONSTRAINT `fk_item_units_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_units` ADD CONSTRAINT `fk_item_units_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_barcodes` ADD CONSTRAINT `fk_item_barcodes_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_barcodes` ADD CONSTRAINT `fk_item_barcodes_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_barcodes` ADD CONSTRAINT `fk_item_barcodes_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_barcodes` ADD CONSTRAINT `fk_item_barcodes_tenant_id_company_id_item_unit_5f1e88c829` FOREIGN KEY (`tenant_id`, `company_id`, `item_unit_id`) REFERENCES `item_units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_barcodes` ADD CONSTRAINT `fk_item_barcodes_tenant_id_company_id_item_id_i_02b4025669` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`, `item_unit_id`) REFERENCES `item_units` (`tenant_id`, `company_id`, `item_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_attributes` ADD CONSTRAINT `fk_item_attributes_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_attributes` ADD CONSTRAINT `fk_item_attributes_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_attribute_values` ADD CONSTRAINT `fk_item_attribute_values_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_attribute_values` ADD CONSTRAINT `fk_item_attribute_values_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_attribute_values` ADD CONSTRAINT `fk_item_attribute_values_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_attribute_values` ADD CONSTRAINT `fk_item_attribute_values_tenant_id_company_id_a_42fab00583` FOREIGN KEY (`tenant_id`, `company_id`, `attribute_id`) REFERENCES `item_attributes` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `parties` ADD CONSTRAINT `fk_parties_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `parties` ADD CONSTRAINT `fk_parties_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `party_roles` ADD CONSTRAINT `fk_party_roles_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `party_roles` ADD CONSTRAINT `fk_party_roles_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `party_roles` ADD CONSTRAINT `fk_party_roles_tenant_id_company_id_party_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `party_addresses` ADD CONSTRAINT `fk_party_addresses_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `party_addresses` ADD CONSTRAINT `fk_party_addresses_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `party_addresses` ADD CONSTRAINT `fk_party_addresses_tenant_id_company_id_party_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `party_credit_policies` ADD CONSTRAINT `fk_party_credit_policies_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `party_credit_policies` ADD CONSTRAINT `fk_party_credit_policies_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `party_credit_policies` ADD CONSTRAINT `fk_party_credit_policies_tenant_id_company_id_p_c4b67566b0` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_items` ADD CONSTRAINT `fk_supplier_items_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_items` ADD CONSTRAINT `fk_supplier_items_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_items` ADD CONSTRAINT `fk_supplier_items_tenant_id_company_id_party_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_items` ADD CONSTRAINT `fk_supplier_items_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `tax_codes` ADD CONSTRAINT `fk_tax_codes_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `tax_codes` ADD CONSTRAINT `fk_tax_codes_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `tax_rates` ADD CONSTRAINT `fk_tax_rates_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `tax_rates` ADD CONSTRAINT `fk_tax_rates_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `tax_rates` ADD CONSTRAINT `fk_tax_rates_tenant_id_company_id_tax_code_id_tax_codes` FOREIGN KEY (`tenant_id`, `company_id`, `tax_code_id`) REFERENCES `tax_codes` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_tax_rules` ADD CONSTRAINT `fk_item_tax_rules_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_tax_rules` ADD CONSTRAINT `fk_item_tax_rules_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_tax_rules` ADD CONSTRAINT `fk_item_tax_rules_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `item_tax_rules` ADD CONSTRAINT `fk_item_tax_rules_tenant_id_company_id_tax_code_id_tax_codes` FOREIGN KEY (`tenant_id`, `company_id`, `tax_code_id`) REFERENCES `tax_codes` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `price_lists` ADD CONSTRAINT `fk_price_lists_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `price_lists` ADD CONSTRAINT `fk_price_lists_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `price_lists` ADD CONSTRAINT `fk_price_lists_currency_code_currencies` FOREIGN KEY (`currency_code`) REFERENCES `currencies` (`code`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `price_list_lines` ADD CONSTRAINT `fk_price_list_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `price_list_lines` ADD CONSTRAINT `fk_price_list_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `price_list_lines` ADD CONSTRAINT `fk_price_list_lines_tenant_id_company_id_price__d50218c0be` FOREIGN KEY (`tenant_id`, `company_id`, `price_list_id`) REFERENCES `price_lists` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `price_list_lines` ADD CONSTRAINT `fk_price_list_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `price_list_lines` ADD CONSTRAINT `fk_price_list_lines_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `promotions` ADD CONSTRAINT `fk_promotions_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `promotions` ADD CONSTRAINT `fk_promotions_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_sequences` ADD CONSTRAINT `fk_document_sequences_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_sequences` ADD CONSTRAINT `fk_document_sequences_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_sequences` ADD CONSTRAINT `fk_document_sequences_tenant_id_company_id_bran_b759f0c534` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `documents` ADD CONSTRAINT `fk_documents_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `documents` ADD CONSTRAINT `fk_documents_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `documents` ADD CONSTRAINT `fk_documents_tenant_id_company_id_branch_id_branches` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `documents` ADD CONSTRAINT `fk_documents_currency_code_currencies` FOREIGN KEY (`currency_code`) REFERENCES `currencies` (`code`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `documents` ADD CONSTRAINT `fk_documents_tenant_id_company_id_source_docume_240b59e3c9` FOREIGN KEY (`tenant_id`, `company_id`, `source_document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `documents` ADD CONSTRAINT `fk_documents_tenant_id_created_by_membership_id_daeeb6e910` FOREIGN KEY (`tenant_id`, `created_by_membership_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_lines` ADD CONSTRAINT `fk_document_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_lines` ADD CONSTRAINT `fk_document_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_lines` ADD CONSTRAINT `fk_document_lines_tenant_id_company_id_document_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_links` ADD CONSTRAINT `fk_document_links_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_links` ADD CONSTRAINT `fk_document_links_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_links` ADD CONSTRAINT `fk_document_links_tenant_id_company_id_from_doc_a4db8a5b47` FOREIGN KEY (`tenant_id`, `company_id`, `from_document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_links` ADD CONSTRAINT `fk_document_links_tenant_id_company_id_to_docum_3c8014f3c0` FOREIGN KEY (`tenant_id`, `company_id`, `to_document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_taxes` ADD CONSTRAINT `fk_document_taxes_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_taxes` ADD CONSTRAINT `fk_document_taxes_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_taxes` ADD CONSTRAINT `fk_document_taxes_tenant_id_company_id_document_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_taxes` ADD CONSTRAINT `fk_document_taxes_tenant_id_company_id_document_8630045350` FOREIGN KEY (`tenant_id`, `company_id`, `document_line_id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_taxes` ADD CONSTRAINT `fk_document_taxes_tenant_id_company_id_tax_code_id_tax_codes` FOREIGN KEY (`tenant_id`, `company_id`, `tax_code_id`) REFERENCES `tax_codes` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_taxes` ADD CONSTRAINT `fk_document_taxes_tenant_id_company_id_document_464d3c9935` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `document_line_id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_approvals` ADD CONSTRAINT `fk_document_approvals_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_approvals` ADD CONSTRAINT `fk_document_approvals_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_approvals` ADD CONSTRAINT `fk_document_approvals_tenant_id_company_id_docu_9b888a15b7` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `document_approvals` ADD CONSTRAINT `fk_document_approvals_tenant_id_membership_id_t_c192bfea41` FOREIGN KEY (`tenant_id`, `membership_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `attachments` ADD CONSTRAINT `fk_attachments_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `attachments` ADD CONSTRAINT `fk_attachments_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `attachments` ADD CONSTRAINT `fk_attachments_tenant_id_company_id_document_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_orders` ADD CONSTRAINT `fk_purchase_orders_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_orders` ADD CONSTRAINT `fk_purchase_orders_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_orders` ADD CONSTRAINT `fk_purchase_orders_tenant_id_company_id_supplier_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `supplier_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_orders` ADD CONSTRAINT `fk_purchase_orders_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_order_lines` ADD CONSTRAINT `fk_purchase_order_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_order_lines` ADD CONSTRAINT `fk_purchase_order_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_order_lines` ADD CONSTRAINT `fk_purchase_order_lines_tenant_id_company_id_do_6e8e70138c` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `purchase_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_order_lines` ADD CONSTRAINT `fk_purchase_order_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_order_lines` ADD CONSTRAINT `fk_purchase_order_lines_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_order_lines` ADD CONSTRAINT `fk_purchase_order_lines_tenant_id_company_id_do_e3ac4c3674` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipts` ADD CONSTRAINT `fk_goods_receipts_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipts` ADD CONSTRAINT `fk_goods_receipts_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipts` ADD CONSTRAINT `fk_goods_receipts_tenant_id_company_id_supplier_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `supplier_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipts` ADD CONSTRAINT `fk_goods_receipts_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipt_lines` ADD CONSTRAINT `fk_goods_receipt_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipt_lines` ADD CONSTRAINT `fk_goods_receipt_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipt_lines` ADD CONSTRAINT `fk_goods_receipt_lines_tenant_id_company_id_doc_becb9d57c2` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `goods_receipts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipt_lines` ADD CONSTRAINT `fk_goods_receipt_lines_tenant_id_company_id_pur_5e25961ab3` FOREIGN KEY (`tenant_id`, `company_id`, `purchase_order_line_id`) REFERENCES `purchase_order_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipt_lines` ADD CONSTRAINT `fk_goods_receipt_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipt_lines` ADD CONSTRAINT `fk_goods_receipt_lines_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `goods_receipt_lines` ADD CONSTRAINT `fk_goods_receipt_lines_tenant_id_company_id_doc_fd950f894c` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_invoices` ADD CONSTRAINT `fk_supplier_invoices_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_invoices` ADD CONSTRAINT `fk_supplier_invoices_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_invoices` ADD CONSTRAINT `fk_supplier_invoices_tenant_id_company_id_suppl_50000e35f5` FOREIGN KEY (`tenant_id`, `company_id`, `supplier_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_invoices` ADD CONSTRAINT `fk_supplier_invoices_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_invoice_lines` ADD CONSTRAINT `fk_supplier_invoice_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_invoice_lines` ADD CONSTRAINT `fk_supplier_invoice_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_invoice_lines` ADD CONSTRAINT `fk_supplier_invoice_lines_tenant_id_company_id__6f111689c5` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `supplier_invoices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_invoice_lines` ADD CONSTRAINT `fk_supplier_invoice_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_invoice_lines` ADD CONSTRAINT `fk_supplier_invoice_lines_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_invoice_lines` ADD CONSTRAINT `fk_supplier_invoice_lines_tenant_id_company_id__6e6cb464da` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_matches` ADD CONSTRAINT `fk_purchase_matches_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_matches` ADD CONSTRAINT `fk_purchase_matches_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_matches` ADD CONSTRAINT `fk_purchase_matches_tenant_id_company_id_invoic_097c81e518` FOREIGN KEY (`tenant_id`, `company_id`, `invoice_line_id`) REFERENCES `supplier_invoice_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_matches` ADD CONSTRAINT `fk_purchase_matches_tenant_id_company_id_receip_b558ab9906` FOREIGN KEY (`tenant_id`, `company_id`, `receipt_line_id`) REFERENCES `goods_receipt_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_returns` ADD CONSTRAINT `fk_supplier_returns_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_returns` ADD CONSTRAINT `fk_supplier_returns_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_returns` ADD CONSTRAINT `fk_supplier_returns_tenant_id_company_id_supplier_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `supplier_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_returns` ADD CONSTRAINT `fk_supplier_returns_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_return_lines` ADD CONSTRAINT `fk_supplier_return_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_return_lines` ADD CONSTRAINT `fk_supplier_return_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_return_lines` ADD CONSTRAINT `fk_supplier_return_lines_tenant_id_company_id_d_1ba23b6aab` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `supplier_returns` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_return_lines` ADD CONSTRAINT `fk_supplier_return_lines_tenant_id_company_id_r_4607a28e0a` FOREIGN KEY (`tenant_id`, `company_id`, `receipt_line_id`) REFERENCES `goods_receipt_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_return_lines` ADD CONSTRAINT `fk_supplier_return_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_return_lines` ADD CONSTRAINT `fk_supplier_return_lines_tenant_id_company_id_d_13fb666574` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credits` ADD CONSTRAINT `fk_supplier_credits_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credits` ADD CONSTRAINT `fk_supplier_credits_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credits` ADD CONSTRAINT `fk_supplier_credits_tenant_id_company_id_supplier_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `supplier_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credits` ADD CONSTRAINT `fk_supplier_credits_tenant_id_company_id_origin_6b68d44279` FOREIGN KEY (`tenant_id`, `company_id`, `original_invoice_id`) REFERENCES `supplier_invoices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credits` ADD CONSTRAINT `fk_supplier_credits_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credit_lines` ADD CONSTRAINT `fk_supplier_credit_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credit_lines` ADD CONSTRAINT `fk_supplier_credit_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credit_lines` ADD CONSTRAINT `fk_supplier_credit_lines_tenant_id_company_id_d_98ea58b2ee` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `supplier_credits` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credit_lines` ADD CONSTRAINT `fk_supplier_credit_lines_tenant_id_company_id_o_d3756576df` FOREIGN KEY (`tenant_id`, `company_id`, `original_invoice_line_id`) REFERENCES `supplier_invoice_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credit_lines` ADD CONSTRAINT `fk_supplier_credit_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credit_lines` ADD CONSTRAINT `fk_supplier_credit_lines_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_credit_lines` ADD CONSTRAINT `fk_supplier_credit_lines_tenant_id_company_id_d_e8b397077f` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `landed_costs` ADD CONSTRAINT `fk_landed_costs_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `landed_costs` ADD CONSTRAINT `fk_landed_costs_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `landed_costs` ADD CONSTRAINT `fk_landed_costs_tenant_id_company_id_supplier_i_fc6b09edbe` FOREIGN KEY (`tenant_id`, `company_id`, `supplier_invoice_id`) REFERENCES `supplier_invoices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `landed_costs` ADD CONSTRAINT `fk_landed_costs_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `landed_cost_allocations` ADD CONSTRAINT `fk_landed_cost_allocations_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `landed_cost_allocations` ADD CONSTRAINT `fk_landed_cost_allocations_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `landed_cost_allocations` ADD CONSTRAINT `fk_landed_cost_allocations_tenant_id_company_id_41ce1e481b` FOREIGN KEY (`tenant_id`, `company_id`, `landed_cost_id`) REFERENCES `landed_costs` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `landed_cost_allocations` ADD CONSTRAINT `fk_landed_cost_allocations_tenant_id_company_id_a0da7eb72f` FOREIGN KEY (`tenant_id`, `company_id`, `receipt_line_id`) REFERENCES `goods_receipt_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lots` ADD CONSTRAINT `fk_lots_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lots` ADD CONSTRAINT `fk_lots_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lots` ADD CONSTRAINT `fk_lots_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `inventory_owners` ADD CONSTRAINT `fk_inventory_owners_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `inventory_owners` ADD CONSTRAINT `fk_inventory_owners_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `inventory_owners` ADD CONSTRAINT `fk_inventory_owners_tenant_id_company_id_party_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_buckets` ADD CONSTRAINT `fk_stock_buckets_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_buckets` ADD CONSTRAINT `fk_stock_buckets_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_buckets` ADD CONSTRAINT `fk_stock_buckets_tenant_id_company_id_lot_id_lots` FOREIGN KEY (`tenant_id`, `company_id`, `lot_id`) REFERENCES `lots` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_buckets` ADD CONSTRAINT `fk_stock_buckets_tenant_id_company_id_location_id_locations` FOREIGN KEY (`tenant_id`, `company_id`, `location_id`) REFERENCES `locations` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_buckets` ADD CONSTRAINT `fk_stock_buckets_tenant_id_company_id_inventory_19005e04b0` FOREIGN KEY (`tenant_id`, `company_id`, `inventory_owner_id`) REFERENCES `inventory_owners` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_balances` ADD CONSTRAINT `fk_stock_balances_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_balances` ADD CONSTRAINT `fk_stock_balances_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_balances` ADD CONSTRAINT `fk_stock_balances_tenant_id_company_id_bucket_i_de4c94d471` FOREIGN KEY (`tenant_id`, `company_id`, `bucket_id`) REFERENCES `stock_buckets` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_reservations` ADD CONSTRAINT `fk_stock_reservations_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_reservations` ADD CONSTRAINT `fk_stock_reservations_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_reservations` ADD CONSTRAINT `fk_stock_reservations_tenant_id_company_id_buck_a8038faf30` FOREIGN KEY (`tenant_id`, `company_id`, `bucket_id`) REFERENCES `stock_buckets` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_reservations` ADD CONSTRAINT `fk_stock_reservations_tenant_id_company_id_docu_d65eab7622` FOREIGN KEY (`tenant_id`, `company_id`, `document_line_id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_reservations` ADD CONSTRAINT `fk_stock_reservations_tenant_id_company_id_device_id_devices` FOREIGN KEY (`tenant_id`, `company_id`, `device_id`) REFERENCES `devices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_entries` ADD CONSTRAINT `fk_stock_entries_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_entries` ADD CONSTRAINT `fk_stock_entries_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_entries` ADD CONSTRAINT `fk_stock_entries_tenant_id_company_id_document_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_entries` ADD CONSTRAINT `fk_stock_entries_tenant_id_company_id_document__fa8f5b326c` FOREIGN KEY (`tenant_id`, `company_id`, `document_line_id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_entries` ADD CONSTRAINT `fk_stock_entries_tenant_id_company_id_bucket_id_ca9635f8a5` FOREIGN KEY (`tenant_id`, `company_id`, `bucket_id`) REFERENCES `stock_buckets` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_entries` ADD CONSTRAINT `fk_stock_entries_tenant_id_company_id_reverses__d4f00108c3` FOREIGN KEY (`tenant_id`, `company_id`, `reverses_entry_id`) REFERENCES `stock_entries` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_entries` ADD CONSTRAINT `fk_stock_entries_tenant_id_company_id_document__b0046948fd` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `document_line_id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_cost_layers` ADD CONSTRAINT `fk_stock_cost_layers_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_cost_layers` ADD CONSTRAINT `fk_stock_cost_layers_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_cost_layers` ADD CONSTRAINT `fk_stock_cost_layers_tenant_id_company_id_recei_47ef995950` FOREIGN KEY (`tenant_id`, `company_id`, `receipt_entry_id`) REFERENCES `stock_entries` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_cost_consumptions` ADD CONSTRAINT `fk_stock_cost_consumptions_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_cost_consumptions` ADD CONSTRAINT `fk_stock_cost_consumptions_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_cost_consumptions` ADD CONSTRAINT `fk_stock_cost_consumptions_tenant_id_company_id_0db5b3c571` FOREIGN KEY (`tenant_id`, `company_id`, `issue_entry_id`) REFERENCES `stock_entries` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_cost_consumptions` ADD CONSTRAINT `fk_stock_cost_consumptions_tenant_id_company_id_a162ce8e2d` FOREIGN KEY (`tenant_id`, `company_id`, `cost_layer_id`) REFERENCES `stock_cost_layers` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_value_adjustments` ADD CONSTRAINT `fk_stock_value_adjustments_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_value_adjustments` ADD CONSTRAINT `fk_stock_value_adjustments_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_value_adjustments` ADD CONSTRAINT `fk_stock_value_adjustments_tenant_id_company_id_083c1d9e42` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_value_adjustments` ADD CONSTRAINT `fk_stock_value_adjustments_tenant_id_company_id_71c3dba924` FOREIGN KEY (`tenant_id`, `company_id`, `cost_layer_id`) REFERENCES `stock_cost_layers` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `serial_numbers` ADD CONSTRAINT `fk_serial_numbers_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `serial_numbers` ADD CONSTRAINT `fk_serial_numbers_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `serial_numbers` ADD CONSTRAINT `fk_serial_numbers_tenant_id_company_id_lot_id_lots` FOREIGN KEY (`tenant_id`, `company_id`, `lot_id`) REFERENCES `lots` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `serial_movements` ADD CONSTRAINT `fk_serial_movements_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `serial_movements` ADD CONSTRAINT `fk_serial_movements_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `serial_movements` ADD CONSTRAINT `fk_serial_movements_tenant_id_company_id_serial_49b375bb34` FOREIGN KEY (`tenant_id`, `company_id`, `serial_id`) REFERENCES `serial_numbers` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `serial_movements` ADD CONSTRAINT `fk_serial_movements_tenant_id_company_id_stock__16bdc64620` FOREIGN KEY (`tenant_id`, `company_id`, `stock_entry_id`) REFERENCES `stock_entries` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfers` ADD CONSTRAINT `fk_stock_transfers_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfers` ADD CONSTRAINT `fk_stock_transfers_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfers` ADD CONSTRAINT `fk_stock_transfers_tenant_id_company_id_from_wa_2fa079cb8e` FOREIGN KEY (`tenant_id`, `company_id`, `from_warehouse_id`) REFERENCES `warehouses` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfers` ADD CONSTRAINT `fk_stock_transfers_tenant_id_company_id_to_ware_cffcb0bd6f` FOREIGN KEY (`tenant_id`, `company_id`, `to_warehouse_id`) REFERENCES `warehouses` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfers` ADD CONSTRAINT `fk_stock_transfers_tenant_id_company_id_dispatc_41c02ce0ec` FOREIGN KEY (`tenant_id`, `company_id`, `dispatch_document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfers` ADD CONSTRAINT `fk_stock_transfers_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfer_lines` ADD CONSTRAINT `fk_stock_transfer_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfer_lines` ADD CONSTRAINT `fk_stock_transfer_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfer_lines` ADD CONSTRAINT `fk_stock_transfer_lines_tenant_id_company_id_do_d97e079fdc` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `stock_transfers` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfer_lines` ADD CONSTRAINT `fk_stock_transfer_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfer_lines` ADD CONSTRAINT `fk_stock_transfer_lines_tenant_id_company_id_di_10d2a0ea4a` FOREIGN KEY (`tenant_id`, `company_id`, `dispatch_line_id`) REFERENCES `stock_transfer_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_transfer_lines` ADD CONSTRAINT `fk_stock_transfer_lines_tenant_id_company_id_do_175a7b54ca` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_counts` ADD CONSTRAINT `fk_stock_counts_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_counts` ADD CONSTRAINT `fk_stock_counts_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_counts` ADD CONSTRAINT `fk_stock_counts_tenant_id_company_id_warehouse_id_warehouses` FOREIGN KEY (`tenant_id`, `company_id`, `warehouse_id`) REFERENCES `warehouses` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_counts` ADD CONSTRAINT `fk_stock_counts_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_count_lines` ADD CONSTRAINT `fk_stock_count_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_count_lines` ADD CONSTRAINT `fk_stock_count_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_count_lines` ADD CONSTRAINT `fk_stock_count_lines_tenant_id_company_id_docum_afc52daa5a` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `stock_counts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_count_lines` ADD CONSTRAINT `fk_stock_count_lines_tenant_id_company_id_bucke_eab9774bc3` FOREIGN KEY (`tenant_id`, `company_id`, `bucket_id`) REFERENCES `stock_buckets` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_count_lines` ADD CONSTRAINT `fk_stock_count_lines_tenant_id_company_id_docum_65f9272c33` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_adjustments` ADD CONSTRAINT `fk_stock_adjustments_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_adjustments` ADD CONSTRAINT `fk_stock_adjustments_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_adjustments` ADD CONSTRAINT `fk_stock_adjustments_tenant_id_company_id_count_a34646c254` FOREIGN KEY (`tenant_id`, `company_id`, `count_id`) REFERENCES `stock_counts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_adjustments` ADD CONSTRAINT `fk_stock_adjustments_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_adjustment_lines` ADD CONSTRAINT `fk_stock_adjustment_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_adjustment_lines` ADD CONSTRAINT `fk_stock_adjustment_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_adjustment_lines` ADD CONSTRAINT `fk_stock_adjustment_lines_tenant_id_company_id__aaa5d459c4` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `stock_adjustments` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_adjustment_lines` ADD CONSTRAINT `fk_stock_adjustment_lines_tenant_id_company_id__1b09a528dc` FOREIGN KEY (`tenant_id`, `company_id`, `bucket_id`) REFERENCES `stock_buckets` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `stock_adjustment_lines` ADD CONSTRAINT `fk_stock_adjustment_lines_tenant_id_company_id__d6ef412b88` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `reorder_policies` ADD CONSTRAINT `fk_reorder_policies_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `reorder_policies` ADD CONSTRAINT `fk_reorder_policies_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `reorder_policies` ADD CONSTRAINT `fk_reorder_policies_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `reorder_policies` ADD CONSTRAINT `fk_reorder_policies_tenant_id_company_id_wareho_969571ea4a` FOREIGN KEY (`tenant_id`, `company_id`, `warehouse_id`) REFERENCES `warehouses` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipes` ADD CONSTRAINT `fk_recipes_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipes` ADD CONSTRAINT `fk_recipes_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipes` ADD CONSTRAINT `fk_recipes_tenant_id_company_id_primary_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `primary_item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_versions` ADD CONSTRAINT `fk_recipe_versions_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_versions` ADD CONSTRAINT `fk_recipe_versions_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_versions` ADD CONSTRAINT `fk_recipe_versions_tenant_id_company_id_recipe_id_recipes` FOREIGN KEY (`tenant_id`, `company_id`, `recipe_id`) REFERENCES `recipes` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_versions` ADD CONSTRAINT `fk_recipe_versions_tenant_id_approved_by_id_ten_8b482f58cc` FOREIGN KEY (`tenant_id`, `approved_by_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_inputs` ADD CONSTRAINT `fk_recipe_inputs_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_inputs` ADD CONSTRAINT `fk_recipe_inputs_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_inputs` ADD CONSTRAINT `fk_recipe_inputs_tenant_id_company_id_recipe_ve_00277ab6c4` FOREIGN KEY (`tenant_id`, `company_id`, `recipe_version_id`) REFERENCES `recipe_versions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_inputs` ADD CONSTRAINT `fk_recipe_inputs_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_substitutions` ADD CONSTRAINT `fk_recipe_substitutions_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_substitutions` ADD CONSTRAINT `fk_recipe_substitutions_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_substitutions` ADD CONSTRAINT `fk_recipe_substitutions_tenant_id_company_id_re_4767e3b2ad` FOREIGN KEY (`tenant_id`, `company_id`, `recipe_input_id`) REFERENCES `recipe_inputs` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_substitutions` ADD CONSTRAINT `fk_recipe_substitutions_tenant_id_company_id_su_0b19bf1ed1` FOREIGN KEY (`tenant_id`, `company_id`, `substitute_item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_outputs` ADD CONSTRAINT `fk_recipe_outputs_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_outputs` ADD CONSTRAINT `fk_recipe_outputs_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_outputs` ADD CONSTRAINT `fk_recipe_outputs_tenant_id_company_id_recipe_v_82b5676a38` FOREIGN KEY (`tenant_id`, `company_id`, `recipe_version_id`) REFERENCES `recipe_versions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recipe_outputs` ADD CONSTRAINT `fk_recipe_outputs_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `work_centers` ADD CONSTRAINT `fk_work_centers_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `work_centers` ADD CONSTRAINT `fk_work_centers_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `work_centers` ADD CONSTRAINT `fk_work_centers_tenant_id_company_id_branch_id_branches` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `routing_steps` ADD CONSTRAINT `fk_routing_steps_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `routing_steps` ADD CONSTRAINT `fk_routing_steps_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `routing_steps` ADD CONSTRAINT `fk_routing_steps_tenant_id_company_id_recipe_ve_9913eda929` FOREIGN KEY (`tenant_id`, `company_id`, `recipe_version_id`) REFERENCES `recipe_versions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `routing_steps` ADD CONSTRAINT `fk_routing_steps_tenant_id_company_id_work_cent_6246c4f738` FOREIGN KEY (`tenant_id`, `company_id`, `work_center_id`) REFERENCES `work_centers` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_orders` ADD CONSTRAINT `fk_production_orders_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_orders` ADD CONSTRAINT `fk_production_orders_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_orders` ADD CONSTRAINT `fk_production_orders_tenant_id_company_id_recip_06589959e9` FOREIGN KEY (`tenant_id`, `company_id`, `recipe_version_id`) REFERENCES `recipe_versions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_orders` ADD CONSTRAINT `fk_production_orders_tenant_id_company_id_wareh_f8cbe8a416` FOREIGN KEY (`tenant_id`, `company_id`, `warehouse_id`) REFERENCES `warehouses` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_orders` ADD CONSTRAINT `fk_production_orders_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_material_plans` ADD CONSTRAINT `fk_production_material_plans_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_material_plans` ADD CONSTRAINT `fk_production_material_plans_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_material_plans` ADD CONSTRAINT `fk_production_material_plans_tenant_id_company__6ddee88c4c` FOREIGN KEY (`tenant_id`, `company_id`, `production_order_id`) REFERENCES `production_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_material_plans` ADD CONSTRAINT `fk_production_material_plans_tenant_id_company__30e9cb9159` FOREIGN KEY (`tenant_id`, `company_id`, `recipe_input_id`) REFERENCES `recipe_inputs` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_material_plans` ADD CONSTRAINT `fk_production_material_plans_tenant_id_company__8973f2b581` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_operations` ADD CONSTRAINT `fk_production_operations_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_operations` ADD CONSTRAINT `fk_production_operations_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_operations` ADD CONSTRAINT `fk_production_operations_tenant_id_company_id_p_4d36784cd1` FOREIGN KEY (`tenant_id`, `company_id`, `production_order_id`) REFERENCES `production_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_operations` ADD CONSTRAINT `fk_production_operations_tenant_id_company_id_w_29cbc94757` FOREIGN KEY (`tenant_id`, `company_id`, `work_center_id`) REFERENCES `work_centers` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_events` ADD CONSTRAINT `fk_production_events_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_events` ADD CONSTRAINT `fk_production_events_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_events` ADD CONSTRAINT `fk_production_events_tenant_id_company_id_produ_cb0afbfead` FOREIGN KEY (`tenant_id`, `company_id`, `production_order_id`) REFERENCES `production_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_events` ADD CONSTRAINT `fk_production_events_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_event_lines` ADD CONSTRAINT `fk_production_event_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_event_lines` ADD CONSTRAINT `fk_production_event_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_event_lines` ADD CONSTRAINT `fk_production_event_lines_tenant_id_company_id__117d853a15` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `production_events` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_event_lines` ADD CONSTRAINT `fk_production_event_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_event_lines` ADD CONSTRAINT `fk_production_event_lines_tenant_id_company_id__6a063351f9` FOREIGN KEY (`tenant_id`, `company_id`, `material_plan_id`) REFERENCES `production_material_plans` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_event_lines` ADD CONSTRAINT `fk_production_event_lines_tenant_id_company_id__247298c744` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_costs` ADD CONSTRAINT `fk_production_costs_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_costs` ADD CONSTRAINT `fk_production_costs_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_costs` ADD CONSTRAINT `fk_production_costs_tenant_id_company_id_produc_4628d19d67` FOREIGN KEY (`tenant_id`, `company_id`, `production_order_id`) REFERENCES `production_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_costs` ADD CONSTRAINT `fk_production_costs_tenant_id_company_id_docume_be77d7ca38` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_costs` ADD CONSTRAINT `fk_production_costs_tenant_id_company_id_operat_c4a7079772` FOREIGN KEY (`tenant_id`, `company_id`, `operation_id`) REFERENCES `production_operations` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_cost_allocations` ADD CONSTRAINT `fk_production_cost_allocations_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_cost_allocations` ADD CONSTRAINT `fk_production_cost_allocations_tenant_id_compan_7aa3c0b36a` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_cost_allocations` ADD CONSTRAINT `fk_production_cost_allocations_tenant_id_compan_81d4fe2573` FOREIGN KEY (`tenant_id`, `company_id`, `production_order_id`) REFERENCES `production_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_cost_allocations` ADD CONSTRAINT `fk_production_cost_allocations_tenant_id_compan_30c458cf06` FOREIGN KEY (`tenant_id`, `company_id`, `output_entry_id`) REFERENCES `stock_entries` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `production_cost_allocations` ADD CONSTRAINT `fk_production_cost_allocations_tenant_id_compan_70e46ff3c8` FOREIGN KEY (`tenant_id`, `company_id`, `settlement_document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lot_genealogy` ADD CONSTRAINT `fk_lot_genealogy_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lot_genealogy` ADD CONSTRAINT `fk_lot_genealogy_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lot_genealogy` ADD CONSTRAINT `fk_lot_genealogy_tenant_id_company_id_productio_5b20cf6e47` FOREIGN KEY (`tenant_id`, `company_id`, `production_order_id`) REFERENCES `production_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lot_genealogy` ADD CONSTRAINT `fk_lot_genealogy_tenant_id_company_id_input_ent_9b521e86db` FOREIGN KEY (`tenant_id`, `company_id`, `input_entry_id`) REFERENCES `stock_entries` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lot_genealogy` ADD CONSTRAINT `fk_lot_genealogy_tenant_id_company_id_output_en_01abc20f8b` FOREIGN KEY (`tenant_id`, `company_id`, `output_entry_id`) REFERENCES `stock_entries` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_specs` ADD CONSTRAINT `fk_quality_specs_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_specs` ADD CONSTRAINT `fk_quality_specs_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_specs` ADD CONSTRAINT `fk_quality_specs_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_spec_tests` ADD CONSTRAINT `fk_quality_spec_tests_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_spec_tests` ADD CONSTRAINT `fk_quality_spec_tests_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_spec_tests` ADD CONSTRAINT `fk_quality_spec_tests_tenant_id_company_id_qual_325efb28cb` FOREIGN KEY (`tenant_id`, `company_id`, `quality_spec_id`) REFERENCES `quality_specs` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_spec_tests` ADD CONSTRAINT `fk_quality_spec_tests_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_inspections` ADD CONSTRAINT `fk_quality_inspections_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_inspections` ADD CONSTRAINT `fk_quality_inspections_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_inspections` ADD CONSTRAINT `fk_quality_inspections_tenant_id_company_id_lot_id_lots` FOREIGN KEY (`tenant_id`, `company_id`, `lot_id`) REFERENCES `lots` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_inspections` ADD CONSTRAINT `fk_quality_inspections_tenant_id_company_id_qua_ff627e8c25` FOREIGN KEY (`tenant_id`, `company_id`, `quality_spec_id`) REFERENCES `quality_specs` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_inspections` ADD CONSTRAINT `fk_quality_inspections_tenant_id_company_id_doc_ae4b2369ad` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_inspections` ADD CONSTRAINT `fk_quality_inspections_tenant_id_inspector_id_t_73de1ea902` FOREIGN KEY (`tenant_id`, `inspector_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_results` ADD CONSTRAINT `fk_quality_results_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_results` ADD CONSTRAINT `fk_quality_results_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_results` ADD CONSTRAINT `fk_quality_results_tenant_id_company_id_inspect_3d95858abc` FOREIGN KEY (`tenant_id`, `company_id`, `inspection_id`) REFERENCES `quality_inspections` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `quality_results` ADD CONSTRAINT `fk_quality_results_tenant_id_company_id_spec_te_d4ae8f01f5` FOREIGN KEY (`tenant_id`, `company_id`, `spec_test_id`) REFERENCES `quality_spec_tests` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lot_status_events` ADD CONSTRAINT `fk_lot_status_events_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lot_status_events` ADD CONSTRAINT `fk_lot_status_events_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lot_status_events` ADD CONSTRAINT `fk_lot_status_events_tenant_id_company_id_lot_id_lots` FOREIGN KEY (`tenant_id`, `company_id`, `lot_id`) REFERENCES `lots` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lot_status_events` ADD CONSTRAINT `fk_lot_status_events_tenant_id_company_id_docum_db529e8b6f` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `lot_status_events` ADD CONSTRAINT `fk_lot_status_events_tenant_id_authorized_by_id_a7c3fbf7db` FOREIGN KEY (`tenant_id`, `authorized_by_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recalls` ADD CONSTRAINT `fk_recalls_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recalls` ADD CONSTRAINT `fk_recalls_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recall_lots` ADD CONSTRAINT `fk_recall_lots_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recall_lots` ADD CONSTRAINT `fk_recall_lots_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recall_lots` ADD CONSTRAINT `fk_recall_lots_tenant_id_company_id_recall_id_recalls` FOREIGN KEY (`tenant_id`, `company_id`, `recall_id`) REFERENCES `recalls` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `recall_lots` ADD CONSTRAINT `fk_recall_lots_tenant_id_company_id_lot_id_lots` FOREIGN KEY (`tenant_id`, `company_id`, `lot_id`) REFERENCES `lots` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_orders` ADD CONSTRAINT `fk_sales_orders_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_orders` ADD CONSTRAINT `fk_sales_orders_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_orders` ADD CONSTRAINT `fk_sales_orders_tenant_id_company_id_customer_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `customer_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_orders` ADD CONSTRAINT `fk_sales_orders_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_order_lines` ADD CONSTRAINT `fk_sales_order_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_order_lines` ADD CONSTRAINT `fk_sales_order_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_order_lines` ADD CONSTRAINT `fk_sales_order_lines_tenant_id_company_id_docum_ab27521c27` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `sales_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_order_lines` ADD CONSTRAINT `fk_sales_order_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_order_lines` ADD CONSTRAINT `fk_sales_order_lines_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_order_lines` ADD CONSTRAINT `fk_sales_order_lines_tenant_id_company_id_docum_3cc8cf9253` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `deliveries` ADD CONSTRAINT `fk_deliveries_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `deliveries` ADD CONSTRAINT `fk_deliveries_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `deliveries` ADD CONSTRAINT `fk_deliveries_tenant_id_company_id_customer_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `customer_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `deliveries` ADD CONSTRAINT `fk_deliveries_tenant_id_company_id_carrier_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `carrier_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `deliveries` ADD CONSTRAINT `fk_deliveries_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `delivery_lines` ADD CONSTRAINT `fk_delivery_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `delivery_lines` ADD CONSTRAINT `fk_delivery_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `delivery_lines` ADD CONSTRAINT `fk_delivery_lines_tenant_id_company_id_document_25f9bf9e44` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `deliveries` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `delivery_lines` ADD CONSTRAINT `fk_delivery_lines_tenant_id_company_id_sales_or_33712726d0` FOREIGN KEY (`tenant_id`, `company_id`, `sales_order_line_id`) REFERENCES `sales_order_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `delivery_lines` ADD CONSTRAINT `fk_delivery_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `delivery_lines` ADD CONSTRAINT `fk_delivery_lines_tenant_id_company_id_document_eab87090ce` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoices` ADD CONSTRAINT `fk_sales_invoices_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoices` ADD CONSTRAINT `fk_sales_invoices_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoices` ADD CONSTRAINT `fk_sales_invoices_tenant_id_company_id_customer_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `customer_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoices` ADD CONSTRAINT `fk_sales_invoices_tenant_id_company_id_pos_sess_7e830e64e5` FOREIGN KEY (`tenant_id`, `company_id`, `pos_session_id`) REFERENCES `pos_sessions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoices` ADD CONSTRAINT `fk_sales_invoices_tenant_id_company_id_device_id_devices` FOREIGN KEY (`tenant_id`, `company_id`, `device_id`) REFERENCES `devices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoices` ADD CONSTRAINT `fk_sales_invoices_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoice_lines` ADD CONSTRAINT `fk_sales_invoice_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoice_lines` ADD CONSTRAINT `fk_sales_invoice_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoice_lines` ADD CONSTRAINT `fk_sales_invoice_lines_tenant_id_company_id_doc_acedb2dc97` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `sales_invoices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoice_lines` ADD CONSTRAINT `fk_sales_invoice_lines_tenant_id_company_id_sal_d920794724` FOREIGN KEY (`tenant_id`, `company_id`, `sales_order_line_id`) REFERENCES `sales_order_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoice_lines` ADD CONSTRAINT `fk_sales_invoice_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoice_lines` ADD CONSTRAINT `fk_sales_invoice_lines_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_invoice_lines` ADD CONSTRAINT `fk_sales_invoice_lines_tenant_id_company_id_doc_5a8a0bde6b` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_delivery_matches` ADD CONSTRAINT `fk_sales_delivery_matches_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_delivery_matches` ADD CONSTRAINT `fk_sales_delivery_matches_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_delivery_matches` ADD CONSTRAINT `fk_sales_delivery_matches_tenant_id_company_id__fadeb5f3f7` FOREIGN KEY (`tenant_id`, `company_id`, `invoice_line_id`) REFERENCES `sales_invoice_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_delivery_matches` ADD CONSTRAINT `fk_sales_delivery_matches_tenant_id_company_id__66cc3055cc` FOREIGN KEY (`tenant_id`, `company_id`, `delivery_line_id`) REFERENCES `delivery_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `customer_returns` ADD CONSTRAINT `fk_customer_returns_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `customer_returns` ADD CONSTRAINT `fk_customer_returns_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `customer_returns` ADD CONSTRAINT `fk_customer_returns_tenant_id_company_id_customer_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `customer_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `customer_returns` ADD CONSTRAINT `fk_customer_returns_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `customer_return_lines` ADD CONSTRAINT `fk_customer_return_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `customer_return_lines` ADD CONSTRAINT `fk_customer_return_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `customer_return_lines` ADD CONSTRAINT `fk_customer_return_lines_tenant_id_company_id_d_790a1945a8` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `customer_returns` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `customer_return_lines` ADD CONSTRAINT `fk_customer_return_lines_tenant_id_company_id_o_b41529835b` FOREIGN KEY (`tenant_id`, `company_id`, `original_invoice_line_id`) REFERENCES `sales_invoice_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `customer_return_lines` ADD CONSTRAINT `fk_customer_return_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `customer_return_lines` ADD CONSTRAINT `fk_customer_return_lines_tenant_id_company_id_d_ad6910da8d` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credits` ADD CONSTRAINT `fk_sales_credits_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credits` ADD CONSTRAINT `fk_sales_credits_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credits` ADD CONSTRAINT `fk_sales_credits_tenant_id_company_id_customer_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `customer_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credits` ADD CONSTRAINT `fk_sales_credits_tenant_id_company_id_original__339e559d2b` FOREIGN KEY (`tenant_id`, `company_id`, `original_invoice_id`) REFERENCES `sales_invoices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credits` ADD CONSTRAINT `fk_sales_credits_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credit_lines` ADD CONSTRAINT `fk_sales_credit_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credit_lines` ADD CONSTRAINT `fk_sales_credit_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credit_lines` ADD CONSTRAINT `fk_sales_credit_lines_tenant_id_company_id_docu_5c390e7c8c` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `sales_credits` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credit_lines` ADD CONSTRAINT `fk_sales_credit_lines_tenant_id_company_id_orig_01fee3a85d` FOREIGN KEY (`tenant_id`, `company_id`, `original_invoice_line_id`) REFERENCES `sales_invoice_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credit_lines` ADD CONSTRAINT `fk_sales_credit_lines_tenant_id_company_id_retu_e65c3ec038` FOREIGN KEY (`tenant_id`, `company_id`, `return_line_id`) REFERENCES `customer_return_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credit_lines` ADD CONSTRAINT `fk_sales_credit_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credit_lines` ADD CONSTRAINT `fk_sales_credit_lines_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sales_credit_lines` ADD CONSTRAINT `fk_sales_credit_lines_tenant_id_company_id_docu_ede22f3696` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sale_discounts` ADD CONSTRAINT `fk_sale_discounts_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sale_discounts` ADD CONSTRAINT `fk_sale_discounts_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sale_discounts` ADD CONSTRAINT `fk_sale_discounts_tenant_id_company_id_invoice__a583c6fe8d` FOREIGN KEY (`tenant_id`, `company_id`, `invoice_line_id`) REFERENCES `sales_invoice_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sale_discounts` ADD CONSTRAINT `fk_sale_discounts_tenant_id_company_id_promotio_09c0952afa` FOREIGN KEY (`tenant_id`, `company_id`, `promotion_id`) REFERENCES `promotions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sale_discounts` ADD CONSTRAINT `fk_sale_discounts_tenant_id_authorized_by_id_te_0229b730d1` FOREIGN KEY (`tenant_id`, `authorized_by_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pos_registers` ADD CONSTRAINT `fk_pos_registers_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pos_registers` ADD CONSTRAINT `fk_pos_registers_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pos_registers` ADD CONSTRAINT `fk_pos_registers_tenant_id_company_id_branch_id_branches` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pos_sessions` ADD CONSTRAINT `fk_pos_sessions_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pos_sessions` ADD CONSTRAINT `fk_pos_sessions_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pos_sessions` ADD CONSTRAINT `fk_pos_sessions_tenant_id_company_id_register_i_2c22c94cfe` FOREIGN KEY (`tenant_id`, `company_id`, `register_id`) REFERENCES `pos_registers` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pos_sessions` ADD CONSTRAINT `fk_pos_sessions_tenant_id_cashier_id_tenant_memberships` FOREIGN KEY (`tenant_id`, `cashier_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `cash_movements` ADD CONSTRAINT `fk_cash_movements_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `cash_movements` ADD CONSTRAINT `fk_cash_movements_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `cash_movements` ADD CONSTRAINT `fk_cash_movements_tenant_id_company_id_pos_sess_0005e3d964` FOREIGN KEY (`tenant_id`, `company_id`, `pos_session_id`) REFERENCES `pos_sessions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `cash_movements` ADD CONSTRAINT `fk_cash_movements_tenant_id_company_id_document_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `weighing_events` ADD CONSTRAINT `fk_weighing_events_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `weighing_events` ADD CONSTRAINT `fk_weighing_events_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `weighing_events` ADD CONSTRAINT `fk_weighing_events_tenant_id_company_id_documen_cfc7506b14` FOREIGN KEY (`tenant_id`, `company_id`, `document_line_id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `weighing_events` ADD CONSTRAINT `fk_weighing_events_tenant_id_company_id_device_id_devices` FOREIGN KEY (`tenant_id`, `company_id`, `device_id`) REFERENCES `devices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `weighing_events` ADD CONSTRAINT `fk_weighing_events_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `accounts` ADD CONSTRAINT `fk_accounts_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `accounts` ADD CONSTRAINT `fk_accounts_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `accounts` ADD CONSTRAINT `fk_accounts_tenant_id_company_id_parent_account_id_accounts` FOREIGN KEY (`tenant_id`, `company_id`, `parent_account_id`) REFERENCES `accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `accounting_periods` ADD CONSTRAINT `fk_accounting_periods_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `accounting_periods` ADD CONSTRAINT `fk_accounting_periods_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `account_mappings` ADD CONSTRAINT `fk_account_mappings_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `account_mappings` ADD CONSTRAINT `fk_account_mappings_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `account_mappings` ADD CONSTRAINT `fk_account_mappings_tenant_id_company_id_account_id_accounts` FOREIGN KEY (`tenant_id`, `company_id`, `account_id`) REFERENCES `accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `account_mappings` ADD CONSTRAINT `fk_account_mappings_tenant_id_company_id_item_c_4a2dfbff36` FOREIGN KEY (`tenant_id`, `company_id`, `item_category_id`) REFERENCES `item_categories` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `account_mappings` ADD CONSTRAINT `fk_account_mappings_tenant_id_company_id_tax_co_04d3f86a7f` FOREIGN KEY (`tenant_id`, `company_id`, `tax_code_id`) REFERENCES `tax_codes` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_entries` ADD CONSTRAINT `fk_journal_entries_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_entries` ADD CONSTRAINT `fk_journal_entries_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_entries` ADD CONSTRAINT `fk_journal_entries_tenant_id_company_id_documen_a61e2f7e30` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_entries` ADD CONSTRAINT `fk_journal_entries_tenant_id_company_id_period__b156f59b58` FOREIGN KEY (`tenant_id`, `company_id`, `period_id`) REFERENCES `accounting_periods` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_entries` ADD CONSTRAINT `fk_journal_entries_currency_code_currencies` FOREIGN KEY (`currency_code`) REFERENCES `currencies` (`code`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_entries` ADD CONSTRAINT `fk_journal_entries_tenant_id_company_id_reverse_38161849a7` FOREIGN KEY (`tenant_id`, `company_id`, `reverses_journal_id`) REFERENCES `journal_entries` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_lines` ADD CONSTRAINT `fk_journal_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_lines` ADD CONSTRAINT `fk_journal_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_lines` ADD CONSTRAINT `fk_journal_lines_tenant_id_company_id_journal_e_6e51e0ab77` FOREIGN KEY (`tenant_id`, `company_id`, `journal_entry_id`) REFERENCES `journal_entries` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_lines` ADD CONSTRAINT `fk_journal_lines_tenant_id_company_id_account_id_accounts` FOREIGN KEY (`tenant_id`, `company_id`, `account_id`) REFERENCES `accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_lines` ADD CONSTRAINT `fk_journal_lines_tenant_id_company_id_party_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `journal_lines` ADD CONSTRAINT `fk_journal_lines_tenant_id_company_id_branch_id_branches` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `open_items` ADD CONSTRAINT `fk_open_items_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `open_items` ADD CONSTRAINT `fk_open_items_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `open_items` ADD CONSTRAINT `fk_open_items_tenant_id_company_id_document_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `open_items` ADD CONSTRAINT `fk_open_items_tenant_id_company_id_party_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `open_items` ADD CONSTRAINT `fk_open_items_tenant_id_company_id_control_acco_99c0473697` FOREIGN KEY (`tenant_id`, `company_id`, `control_account_id`) REFERENCES `accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `open_items` ADD CONSTRAINT `fk_open_items_currency_code_currencies` FOREIGN KEY (`currency_code`) REFERENCES `currencies` (`code`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `settlements` ADD CONSTRAINT `fk_settlements_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `settlements` ADD CONSTRAINT `fk_settlements_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `settlements` ADD CONSTRAINT `fk_settlements_tenant_id_company_id_document_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `settlements` ADD CONSTRAINT `fk_settlements_tenant_id_company_id_debit_open__65e92b7274` FOREIGN KEY (`tenant_id`, `company_id`, `debit_open_item_id`) REFERENCES `open_items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `settlements` ADD CONSTRAINT `fk_settlements_tenant_id_company_id_credit_open_54fc2ab0a9` FOREIGN KEY (`tenant_id`, `company_id`, `credit_open_item_id`) REFERENCES `open_items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `settlements` ADD CONSTRAINT `fk_settlements_tenant_id_company_id_reverses_se_40e978f626` FOREIGN KEY (`tenant_id`, `company_id`, `reverses_settlement_id`) REFERENCES `settlements` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_methods` ADD CONSTRAINT `fk_payment_methods_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_methods` ADD CONSTRAINT `fk_payment_methods_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_methods` ADD CONSTRAINT `fk_payment_methods_tenant_id_company_id_clearin_7e6fc5a704` FOREIGN KEY (`tenant_id`, `company_id`, `clearing_account_id`) REFERENCES `accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payments` ADD CONSTRAINT `fk_payments_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payments` ADD CONSTRAINT `fk_payments_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payments` ADD CONSTRAINT `fk_payments_tenant_id_company_id_party_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payments` ADD CONSTRAINT `fk_payments_tenant_id_company_id_pos_session_id_pos_sessions` FOREIGN KEY (`tenant_id`, `company_id`, `pos_session_id`) REFERENCES `pos_sessions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payments` ADD CONSTRAINT `fk_payments_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_tenders` ADD CONSTRAINT `fk_payment_tenders_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_tenders` ADD CONSTRAINT `fk_payment_tenders_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_tenders` ADD CONSTRAINT `fk_payment_tenders_tenant_id_company_id_payment_id_payments` FOREIGN KEY (`tenant_id`, `company_id`, `payment_id`) REFERENCES `payments` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_tenders` ADD CONSTRAINT `fk_payment_tenders_tenant_id_company_id_payment_5c9780415f` FOREIGN KEY (`tenant_id`, `company_id`, `payment_method_id`) REFERENCES `payment_methods` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_intents` ADD CONSTRAINT `fk_payment_intents_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_intents` ADD CONSTRAINT `fk_payment_intents_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_intents` ADD CONSTRAINT `fk_payment_intents_tenant_id_company_id_documen_3c397a0868` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payment_intents` ADD CONSTRAINT `fk_payment_intents_tenant_id_company_id_payment_3706c9382d` FOREIGN KEY (`tenant_id`, `company_id`, `payment_method_id`) REFERENCES `payment_methods` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_accounts` ADD CONSTRAINT `fk_bank_accounts_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_accounts` ADD CONSTRAINT `fk_bank_accounts_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_accounts` ADD CONSTRAINT `fk_bank_accounts_tenant_id_company_id_account_id_accounts` FOREIGN KEY (`tenant_id`, `company_id`, `account_id`) REFERENCES `accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_accounts` ADD CONSTRAINT `fk_bank_accounts_currency_code_currencies` FOREIGN KEY (`currency_code`) REFERENCES `currencies` (`code`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_statement_lines` ADD CONSTRAINT `fk_bank_statement_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_statement_lines` ADD CONSTRAINT `fk_bank_statement_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_statement_lines` ADD CONSTRAINT `fk_bank_statement_lines_tenant_id_company_id_ba_435a2461a6` FOREIGN KEY (`tenant_id`, `company_id`, `bank_account_id`) REFERENCES `bank_accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_matches` ADD CONSTRAINT `fk_bank_matches_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_matches` ADD CONSTRAINT `fk_bank_matches_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_matches` ADD CONSTRAINT `fk_bank_matches_tenant_id_company_id_statement__263e699195` FOREIGN KEY (`tenant_id`, `company_id`, `statement_line_id`) REFERENCES `bank_statement_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `bank_matches` ADD CONSTRAINT `fk_bank_matches_tenant_id_company_id_journal_li_0bd10b623a` FOREIGN KEY (`tenant_id`, `company_id`, `journal_line_id`) REFERENCES `journal_lines` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `expenses` ADD CONSTRAINT `fk_expenses_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `expenses` ADD CONSTRAINT `fk_expenses_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `expenses` ADD CONSTRAINT `fk_expenses_tenant_id_company_id_party_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `expenses` ADD CONSTRAINT `fk_expenses_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `expense_lines` ADD CONSTRAINT `fk_expense_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `expense_lines` ADD CONSTRAINT `fk_expense_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `expense_lines` ADD CONSTRAINT `fk_expense_lines_tenant_id_company_id_document_id_expenses` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `expenses` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `expense_lines` ADD CONSTRAINT `fk_expense_lines_tenant_id_company_id_account_id_accounts` FOREIGN KEY (`tenant_id`, `company_id`, `account_id`) REFERENCES `accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `expense_lines` ADD CONSTRAINT `fk_expense_lines_tenant_id_company_id_document__df01e981a1` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `budgets` ADD CONSTRAINT `fk_budgets_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `budgets` ADD CONSTRAINT `fk_budgets_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `budgets` ADD CONSTRAINT `fk_budgets_tenant_id_company_id_period_id_accounting_periods` FOREIGN KEY (`tenant_id`, `company_id`, `period_id`) REFERENCES `accounting_periods` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `budgets` ADD CONSTRAINT `fk_budgets_tenant_id_company_id_account_id_accounts` FOREIGN KEY (`tenant_id`, `company_id`, `account_id`) REFERENCES `accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `budgets` ADD CONSTRAINT `fk_budgets_tenant_id_company_id_branch_id_branches` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `employees` ADD CONSTRAINT `fk_employees_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `employees` ADD CONSTRAINT `fk_employees_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `employees` ADD CONSTRAINT `fk_employees_tenant_id_company_id_branch_id_branches` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `employees` ADD CONSTRAINT `fk_employees_tenant_id_membership_id_tenant_memberships` FOREIGN KEY (`tenant_id`, `membership_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `employment_terms` ADD CONSTRAINT `fk_employment_terms_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `employment_terms` ADD CONSTRAINT `fk_employment_terms_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `employment_terms` ADD CONSTRAINT `fk_employment_terms_tenant_id_company_id_employ_83984f9ad9` FOREIGN KEY (`tenant_id`, `company_id`, `employee_id`) REFERENCES `employees` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `time_entries` ADD CONSTRAINT `fk_time_entries_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `time_entries` ADD CONSTRAINT `fk_time_entries_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `time_entries` ADD CONSTRAINT `fk_time_entries_tenant_id_company_id_employee_id_employees` FOREIGN KEY (`tenant_id`, `company_id`, `employee_id`) REFERENCES `employees` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `time_entries` ADD CONSTRAINT `fk_time_entries_tenant_id_company_id_production_afc07bdc7d` FOREIGN KEY (`tenant_id`, `company_id`, `production_operation_id`) REFERENCES `production_operations` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `leave_requests` ADD CONSTRAINT `fk_leave_requests_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `leave_requests` ADD CONSTRAINT `fk_leave_requests_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `leave_requests` ADD CONSTRAINT `fk_leave_requests_tenant_id_company_id_employee_id_employees` FOREIGN KEY (`tenant_id`, `company_id`, `employee_id`) REFERENCES `employees` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pay_components` ADD CONSTRAINT `fk_pay_components_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pay_components` ADD CONSTRAINT `fk_pay_components_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pay_components` ADD CONSTRAINT `fk_pay_components_tenant_id_company_id_expense__76b90472b2` FOREIGN KEY (`tenant_id`, `company_id`, `expense_account_id`) REFERENCES `accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `pay_components` ADD CONSTRAINT `fk_pay_components_tenant_id_company_id_liabilit_994801da0a` FOREIGN KEY (`tenant_id`, `company_id`, `liability_account_id`) REFERENCES `accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payroll_runs` ADD CONSTRAINT `fk_payroll_runs_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payroll_runs` ADD CONSTRAINT `fk_payroll_runs_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payroll_runs` ADD CONSTRAINT `fk_payroll_runs_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payslips` ADD CONSTRAINT `fk_payslips_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payslips` ADD CONSTRAINT `fk_payslips_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payslips` ADD CONSTRAINT `fk_payslips_tenant_id_company_id_payroll_run_id_payroll_runs` FOREIGN KEY (`tenant_id`, `company_id`, `payroll_run_id`) REFERENCES `payroll_runs` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payslips` ADD CONSTRAINT `fk_payslips_tenant_id_company_id_employee_id_employees` FOREIGN KEY (`tenant_id`, `company_id`, `employee_id`) REFERENCES `employees` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payslip_lines` ADD CONSTRAINT `fk_payslip_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payslip_lines` ADD CONSTRAINT `fk_payslip_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payslip_lines` ADD CONSTRAINT `fk_payslip_lines_tenant_id_company_id_payslip_id_payslips` FOREIGN KEY (`tenant_id`, `company_id`, `payslip_id`) REFERENCES `payslips` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `payslip_lines` ADD CONSTRAINT `fk_payslip_lines_tenant_id_company_id_pay_compo_7626ad27bc` FOREIGN KEY (`tenant_id`, `company_id`, `pay_component_id`) REFERENCES `pay_components` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `assets` ADD CONSTRAINT `fk_assets_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `assets` ADD CONSTRAINT `fk_assets_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `assets` ADD CONSTRAINT `fk_assets_tenant_id_company_id_branch_id_branches` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `assets` ADD CONSTRAINT `fk_assets_tenant_id_company_id_work_center_id_work_centers` FOREIGN KEY (`tenant_id`, `company_id`, `work_center_id`) REFERENCES `work_centers` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `assets` ADD CONSTRAINT `fk_assets_tenant_id_company_id_acquisition_docu_5f11b17c79` FOREIGN KEY (`tenant_id`, `company_id`, `acquisition_document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `asset_depreciations` ADD CONSTRAINT `fk_asset_depreciations_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `asset_depreciations` ADD CONSTRAINT `fk_asset_depreciations_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `asset_depreciations` ADD CONSTRAINT `fk_asset_depreciations_tenant_id_company_id_asset_id_assets` FOREIGN KEY (`tenant_id`, `company_id`, `asset_id`) REFERENCES `assets` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `asset_depreciations` ADD CONSTRAINT `fk_asset_depreciations_tenant_id_company_id_per_572742374e` FOREIGN KEY (`tenant_id`, `company_id`, `period_id`) REFERENCES `accounting_periods` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `asset_depreciations` ADD CONSTRAINT `fk_asset_depreciations_tenant_id_company_id_doc_c848c3cb48` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `maintenance_orders` ADD CONSTRAINT `fk_maintenance_orders_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `maintenance_orders` ADD CONSTRAINT `fk_maintenance_orders_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `maintenance_orders` ADD CONSTRAINT `fk_maintenance_orders_tenant_id_company_id_asset_id_assets` FOREIGN KEY (`tenant_id`, `company_id`, `asset_id`) REFERENCES `assets` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `maintenance_costs` ADD CONSTRAINT `fk_maintenance_costs_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `maintenance_costs` ADD CONSTRAINT `fk_maintenance_costs_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `maintenance_costs` ADD CONSTRAINT `fk_maintenance_costs_tenant_id_company_id_maint_1a717b0109` FOREIGN KEY (`tenant_id`, `company_id`, `maintenance_order_id`) REFERENCES `maintenance_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `maintenance_costs` ADD CONSTRAINT `fk_maintenance_costs_tenant_id_company_id_docum_1e78cca0bb` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `loyalty_accounts` ADD CONSTRAINT `fk_loyalty_accounts_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `loyalty_accounts` ADD CONSTRAINT `fk_loyalty_accounts_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `loyalty_accounts` ADD CONSTRAINT `fk_loyalty_accounts_tenant_id_company_id_party_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `loyalty_entries` ADD CONSTRAINT `fk_loyalty_entries_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `loyalty_entries` ADD CONSTRAINT `fk_loyalty_entries_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `loyalty_entries` ADD CONSTRAINT `fk_loyalty_entries_tenant_id_company_id_loyalty_4a91d65a4b` FOREIGN KEY (`tenant_id`, `company_id`, `loyalty_account_id`) REFERENCES `loyalty_accounts` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `loyalty_entries` ADD CONSTRAINT `fk_loyalty_entries_tenant_id_company_id_documen_84e01814e3` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `service_cases` ADD CONSTRAINT `fk_service_cases_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `service_cases` ADD CONSTRAINT `fk_service_cases_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `service_cases` ADD CONSTRAINT `fk_service_cases_tenant_id_company_id_party_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `party_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `service_cases` ADD CONSTRAINT `fk_service_cases_tenant_id_company_id_lot_id_lots` FOREIGN KEY (`tenant_id`, `company_id`, `lot_id`) REFERENCES `lots` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `service_cases` ADD CONSTRAINT `fk_service_cases_tenant_id_company_id_invoice_i_5bb3260037` FOREIGN KEY (`tenant_id`, `company_id`, `invoice_id`) REFERENCES `sales_invoices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `devices` ADD CONSTRAINT `fk_devices_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `devices` ADD CONSTRAINT `fk_devices_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `devices` ADD CONSTRAINT `fk_devices_tenant_id_company_id_branch_id_branches` FOREIGN KEY (`tenant_id`, `company_id`, `branch_id`) REFERENCES `branches` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `devices` ADD CONSTRAINT `fk_devices_tenant_id_company_id_register_id_pos_registers` FOREIGN KEY (`tenant_id`, `company_id`, `register_id`) REFERENCES `pos_registers` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `offline_operations` ADD CONSTRAINT `fk_offline_operations_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `offline_operations` ADD CONSTRAINT `fk_offline_operations_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `offline_operations` ADD CONSTRAINT `fk_offline_operations_tenant_id_company_id_device_id_devices` FOREIGN KEY (`tenant_id`, `company_id`, `device_id`) REFERENCES `devices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `offline_operations` ADD CONSTRAINT `fk_offline_operations_tenant_id_company_id_resu_c23d624994` FOREIGN KEY (`tenant_id`, `company_id`, `result_document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `offline_stock_allocations` ADD CONSTRAINT `fk_offline_stock_allocations_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `offline_stock_allocations` ADD CONSTRAINT `fk_offline_stock_allocations_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `offline_stock_allocations` ADD CONSTRAINT `fk_offline_stock_allocations_tenant_id_company__90a7dc42e2` FOREIGN KEY (`tenant_id`, `company_id`, `device_id`) REFERENCES `devices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `offline_stock_allocations` ADD CONSTRAINT `fk_offline_stock_allocations_tenant_id_company__5d6c6a06a9` FOREIGN KEY (`tenant_id`, `company_id`, `reservation_id`) REFERENCES `stock_reservations` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sync_cursors` ADD CONSTRAINT `fk_sync_cursors_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sync_cursors` ADD CONSTRAINT `fk_sync_cursors_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `sync_cursors` ADD CONSTRAINT `fk_sync_cursors_tenant_id_company_id_device_id_devices` FOREIGN KEY (`tenant_id`, `company_id`, `device_id`) REFERENCES `devices` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `change_feed` ADD CONSTRAINT `fk_change_feed_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `change_feed` ADD CONSTRAINT `fk_change_feed_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `idempotency_keys` ADD CONSTRAINT `fk_idempotency_keys_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `idempotency_keys` ADD CONSTRAINT `fk_idempotency_keys_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `idempotency_keys` ADD CONSTRAINT `fk_idempotency_keys_tenant_id_company_id_result_f087dac366` FOREIGN KEY (`tenant_id`, `company_id`, `result_document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `outbox_messages` ADD CONSTRAINT `fk_outbox_messages_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `outbox_messages` ADD CONSTRAINT `fk_outbox_messages_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `integration_inbox` ADD CONSTRAINT `fk_integration_inbox_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `integration_inbox` ADD CONSTRAINT `fk_integration_inbox_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `audit_events` ADD CONSTRAINT `fk_audit_events_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `audit_events` ADD CONSTRAINT `fk_audit_events_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `audit_events` ADD CONSTRAINT `fk_audit_events_tenant_id_membership_id_tenant_memberships` FOREIGN KEY (`tenant_id`, `membership_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `api_credentials` ADD CONSTRAINT `fk_api_credentials_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `api_credentials` ADD CONSTRAINT `fk_api_credentials_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `planning_runs` ADD CONSTRAINT `fk_planning_runs_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `planning_runs` ADD CONSTRAINT `fk_planning_runs_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `planning_runs` ADD CONSTRAINT `fk_planning_runs_tenant_id_company_id_warehouse_0ef9333494` FOREIGN KEY (`tenant_id`, `company_id`, `warehouse_id`) REFERENCES `warehouses` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supply_suggestions` ADD CONSTRAINT `fk_supply_suggestions_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supply_suggestions` ADD CONSTRAINT `fk_supply_suggestions_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supply_suggestions` ADD CONSTRAINT `fk_supply_suggestions_tenant_id_company_id_plan_afe42f5ee9` FOREIGN KEY (`tenant_id`, `company_id`, `planning_run_id`) REFERENCES `planning_runs` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supply_suggestions` ADD CONSTRAINT `fk_supply_suggestions_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supply_suggestions` ADD CONSTRAINT `fk_supply_suggestions_tenant_id_company_id_conv_2513de655d` FOREIGN KEY (`tenant_id`, `company_id`, `converted_document_id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_requisitions` ADD CONSTRAINT `fk_purchase_requisitions_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_requisitions` ADD CONSTRAINT `fk_purchase_requisitions_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_requisitions` ADD CONSTRAINT `fk_purchase_requisitions_tenant_id_requested_by_ffb6965a3c` FOREIGN KEY (`tenant_id`, `requested_by_id`) REFERENCES `tenant_memberships` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_requisitions` ADD CONSTRAINT `fk_purchase_requisitions_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_requisition_lines` ADD CONSTRAINT `fk_purchase_requisition_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_requisition_lines` ADD CONSTRAINT `fk_purchase_requisition_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_requisition_lines` ADD CONSTRAINT `fk_purchase_requisition_lines_tenant_id_company_469f566406` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `purchase_requisitions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_requisition_lines` ADD CONSTRAINT `fk_purchase_requisition_lines_tenant_id_company_633095a818` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_requisition_lines` ADD CONSTRAINT `fk_purchase_requisition_lines_tenant_id_company_e16fb1dd71` FOREIGN KEY (`tenant_id`, `company_id`, `supply_suggestion_id`) REFERENCES `supply_suggestions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `purchase_requisition_lines` ADD CONSTRAINT `fk_purchase_requisition_lines_tenant_id_company_d0d3e31099` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quotes` ADD CONSTRAINT `fk_supplier_quotes_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quotes` ADD CONSTRAINT `fk_supplier_quotes_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quotes` ADD CONSTRAINT `fk_supplier_quotes_tenant_id_company_id_supplier_id_parties` FOREIGN KEY (`tenant_id`, `company_id`, `supplier_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quotes` ADD CONSTRAINT `fk_supplier_quotes_tenant_id_company_id_requisi_983205f492` FOREIGN KEY (`tenant_id`, `company_id`, `requisition_id`) REFERENCES `purchase_requisitions` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quotes` ADD CONSTRAINT `fk_supplier_quotes_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quote_lines` ADD CONSTRAINT `fk_supplier_quote_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quote_lines` ADD CONSTRAINT `fk_supplier_quote_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quote_lines` ADD CONSTRAINT `fk_supplier_quote_lines_tenant_id_company_id_do_04a833c128` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `supplier_quotes` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quote_lines` ADD CONSTRAINT `fk_supplier_quote_lines_tenant_id_company_id_item_id_items` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quote_lines` ADD CONSTRAINT `fk_supplier_quote_lines_tenant_id_company_id_uom_id_units` FOREIGN KEY (`tenant_id`, `company_id`, `uom_id`) REFERENCES `units` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `supplier_quote_lines` ADD CONSTRAINT `fk_supplier_quote_lines_tenant_id_company_id_do_12017af205` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subcontract_orders` ADD CONSTRAINT `fk_subcontract_orders_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subcontract_orders` ADD CONSTRAINT `fk_subcontract_orders_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subcontract_orders` ADD CONSTRAINT `fk_subcontract_orders_tenant_id_company_id_supp_69c1b754a6` FOREIGN KEY (`tenant_id`, `company_id`, `supplier_id`) REFERENCES `parties` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subcontract_orders` ADD CONSTRAINT `fk_subcontract_orders_tenant_id_company_id_prod_48f2ee1759` FOREIGN KEY (`tenant_id`, `company_id`, `production_order_id`) REFERENCES `production_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subcontract_orders` ADD CONSTRAINT `fk_subcontract_orders_tenant_id_company_id_id_documents` FOREIGN KEY (`tenant_id`, `company_id`, `id`) REFERENCES `documents` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subcontract_order_lines` ADD CONSTRAINT `fk_subcontract_order_lines_tenant_id_tenants` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subcontract_order_lines` ADD CONSTRAINT `fk_subcontract_order_lines_tenant_id_company_id_companies` FOREIGN KEY (`tenant_id`, `company_id`) REFERENCES `companies` (`tenant_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subcontract_order_lines` ADD CONSTRAINT `fk_subcontract_order_lines_tenant_id_company_id_b96a788bc7` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`) REFERENCES `subcontract_orders` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subcontract_order_lines` ADD CONSTRAINT `fk_subcontract_order_lines_tenant_id_company_id_6f7afc8113` FOREIGN KEY (`tenant_id`, `company_id`, `item_id`) REFERENCES `items` (`tenant_id`, `company_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE `subcontract_order_lines` ADD CONSTRAINT `fk_subcontract_order_lines_tenant_id_company_id_c4bc852f12` FOREIGN KEY (`tenant_id`, `company_id`, `document_id`, `id`) REFERENCES `document_lines` (`tenant_id`, `company_id`, `document_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;
