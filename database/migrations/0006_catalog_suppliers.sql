-- P1-04 review package. No automatic startup execution.
CREATE TABLE units (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, tenant_id BIGINT UNSIGNED NOT NULL, company_id BIGINT UNSIGNED NOT NULL,
 code VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, name VARCHAR(100) NOT NULL,
 dimension VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, is_discrete BOOLEAN NOT NULL,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, row_version BIGINT UNSIGNED NOT NULL DEFAULT 1, CHECK(is_active IN(0,1) AND row_version>0), UNIQUE KEY uq_units_scope(tenant_id,company_id,id), FOREIGN KEY(tenant_id,company_id) REFERENCES companies(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT, UNIQUE KEY uq_units_code(tenant_id,company_id,code),
 CHECK(dimension IN('COUNT','MASS','VOLUME','OTHER') AND is_discrete IN(0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE item_categories (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, tenant_id BIGINT UNSIGNED NOT NULL, company_id BIGINT UNSIGNED NOT NULL,
 code VARCHAR(60) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, name VARCHAR(150) NOT NULL,
 description VARCHAR(500) NULL, parent_id BIGINT UNSIGNED NULL, is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, row_version BIGINT UNSIGNED NOT NULL DEFAULT 1, CHECK(is_active IN(0,1) AND row_version>0),
 UNIQUE KEY uq_categories_scope(tenant_id,company_id,id), FOREIGN KEY(tenant_id,company_id) REFERENCES companies(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT, UNIQUE KEY uq_categories_code(tenant_id,company_id,code),
 FOREIGN KEY(tenant_id,company_id,parent_id) REFERENCES item_categories(tenant_id,company_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE items (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, tenant_id BIGINT UNSIGNED NOT NULL, company_id BIGINT UNSIGNED NOT NULL,
 sku VARCHAR(60) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, name VARCHAR(200) NOT NULL, description VARCHAR(700) NULL,
 category_id BIGINT UNSIGNED NULL, base_unit_id BIGINT UNSIGNED NOT NULL,
 kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 purchase_enabled BOOLEAN NOT NULL, sale_enabled BOOLEAN NOT NULL, manufacture_enabled BOOLEAN NOT NULL,
 tracking_mode VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, expiry_required BOOLEAN NOT NULL,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, row_version BIGINT UNSIGNED NOT NULL DEFAULT 1, CHECK(is_active IN(0,1) AND row_version>0), UNIQUE KEY uq_items_scope(tenant_id,company_id,id), FOREIGN KEY(tenant_id,company_id) REFERENCES companies(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT, UNIQUE KEY uq_items_sku(tenant_id,company_id,sku),
 UNIQUE KEY uq_items_base(tenant_id,company_id,id,base_unit_id),
 FOREIGN KEY(tenant_id,company_id,category_id) REFERENCES item_categories(tenant_id,company_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 FOREIGN KEY(tenant_id,company_id,base_unit_id) REFERENCES units(tenant_id,company_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CHECK(kind IN('RAW','PACKAGING','INTERMEDIATE','FINISHED')),
 CHECK(purchase_enabled IN(0,1) AND sale_enabled IN(0,1) AND manufacture_enabled IN(0,1) AND expiry_required IN(0,1)),
 CHECK(tracking_mode IN('NONE','LOT') AND (expiry_required=0 OR tracking_mode='LOT'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE item_units (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, tenant_id BIGINT UNSIGNED NOT NULL, company_id BIGINT UNSIGNED NOT NULL,
 item_id BIGINT UNSIGNED NOT NULL, unit_id BIGINT UNSIGNED NOT NULL, base_unit_id BIGINT UNSIGNED NOT NULL,
 to_base_factor DECIMAL(24,9) NOT NULL, purchase_price DECIMAL(24,6) NULL, selling_price DECIMAL(24,6) NULL,
 is_purchase_default BOOLEAN NOT NULL, is_sale_default BOOLEAN NOT NULL,
 purchase_default_item BIGINT UNSIGNED GENERATED ALWAYS AS(CASE WHEN is_active=1 AND is_purchase_default=1 THEN item_id ELSE NULL END) STORED,
 sale_default_item BIGINT UNSIGNED GENERATED ALWAYS AS(CASE WHEN is_active=1 AND is_sale_default=1 THEN item_id ELSE NULL END) STORED,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, row_version BIGINT UNSIGNED NOT NULL DEFAULT 1, CHECK(is_active IN(0,1) AND row_version>0), UNIQUE KEY uq_item_units_scope(tenant_id,company_id,id), FOREIGN KEY(tenant_id,company_id) REFERENCES companies(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT, UNIQUE KEY uq_item_units_pair(tenant_id,company_id,item_id,unit_id),
 UNIQUE KEY uq_item_units_item(tenant_id,company_id,item_id,id),
 UNIQUE KEY uq_item_units_purchase_default(tenant_id,company_id,purchase_default_item),
 UNIQUE KEY uq_item_units_sale_default(tenant_id,company_id,sale_default_item),
 FOREIGN KEY(tenant_id,company_id,item_id,base_unit_id) REFERENCES items(tenant_id,company_id,id,base_unit_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 FOREIGN KEY(tenant_id,company_id,unit_id) REFERENCES units(tenant_id,company_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CHECK(to_base_factor>0 AND (unit_id<>base_unit_id OR to_base_factor=1)),
 CHECK(purchase_price IS NULL OR purchase_price>=0), CHECK(selling_price IS NULL OR selling_price>=0),
 CHECK(is_purchase_default IN(0,1) AND is_sale_default IN(0,1)),
 CHECK(is_active=1 OR (is_purchase_default=0 AND is_sale_default=0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE item_barcodes (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, tenant_id BIGINT UNSIGNED NOT NULL, company_id BIGINT UNSIGNED NOT NULL,
 item_id BIGINT UNSIGNED NOT NULL, item_unit_id BIGINT UNSIGNED NOT NULL,
 barcode VARCHAR(128) COLLATE utf8mb4_0900_bin NOT NULL,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, row_version BIGINT UNSIGNED NOT NULL DEFAULT 1, CHECK(is_active IN(0,1) AND row_version>0), UNIQUE KEY uq_barcodes_scope(tenant_id,company_id,id), FOREIGN KEY(tenant_id,company_id) REFERENCES companies(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT, UNIQUE KEY uq_barcodes_value(tenant_id,company_id,barcode),
 FOREIGN KEY(tenant_id,company_id,item_id,item_unit_id) REFERENCES item_units(tenant_id,company_id,item_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 CHECK(CHAR_LENGTH(barcode)>0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE parties (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, tenant_id BIGINT UNSIGNED NOT NULL, company_id BIGINT UNSIGNED NOT NULL,
 code VARCHAR(60) CHARACTER SET ascii COLLATE ascii_bin NOT NULL, name VARCHAR(200) NOT NULL,
 phone VARCHAR(50) NULL, email VARCHAR(254) NULL, address VARCHAR(700) NULL, contact_person VARCHAR(120) NULL, notes VARCHAR(700) NULL,
 is_supplier BOOLEAN NOT NULL DEFAULT TRUE, is_customer BOOLEAN NOT NULL DEFAULT FALSE,
 is_active BOOLEAN NOT NULL DEFAULT TRUE, created_at DATETIME(6) NOT NULL, updated_at DATETIME(6) NOT NULL, row_version BIGINT UNSIGNED NOT NULL DEFAULT 1, CHECK(is_active IN(0,1) AND row_version>0), UNIQUE KEY uq_parties_scope(tenant_id,company_id,id), FOREIGN KEY(tenant_id,company_id) REFERENCES companies(tenant_id,id) ON DELETE RESTRICT ON UPDATE RESTRICT, UNIQUE KEY uq_parties_code(tenant_id,company_id,code),
 CHECK(is_supplier IN(0,1) AND is_customer IN(0,1) AND (is_supplier=1 OR is_customer=1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
