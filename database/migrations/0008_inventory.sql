ALTER TABLE locations ADD UNIQUE KEY uq_inventory_location (tenant_id,company_id,warehouse_id,id,kind);
-- statement-break
CREATE TABLE document_sequences (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 document_type VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 series SMALLINT UNSIGNED NOT NULL,
 next_value BIGINT UNSIGNED NOT NULL,
 PRIMARY KEY (tenant_id,company_id,document_type,series),
 FOREIGN KEY (tenant_id,company_id) REFERENCES companies(tenant_id,id),
 CHECK (next_value > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE documents (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 document_type VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 document_number VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 warehouse_id BIGINT UNSIGNED NOT NULL,
 actor_membership_id BIGINT UNSIGNED NOT NULL,
 warehouse_name VARCHAR(200) NOT NULL,
 warehouse_code VARCHAR(60) NOT NULL,
 business_date DATE NOT NULL,
 posted_at DATETIME(6) NOT NULL,
 currency_code CHAR(3) NOT NULL,
 currency_minor_units TINYINT UNSIGNED NOT NULL,
 notes VARCHAR(700) NULL,
 operational_total DECIMAL(24,6) NOT NULL,
 UNIQUE KEY uq_doc_scope(tenant_id,company_id,id),
 UNIQUE KEY uq_doc_warehouse(tenant_id,company_id,id,warehouse_id),
 UNIQUE KEY uq_doc_kind(tenant_id,company_id,id,document_type),
 UNIQUE KEY uq_document_number(tenant_id,company_id,document_number),
 KEY ix_doc_warehouse (tenant_id,company_id,warehouse_id,id),
 FOREIGN KEY (tenant_id,company_id,warehouse_id) REFERENCES warehouses(tenant_id,company_id,id),
 FOREIGN KEY (tenant_id,actor_membership_id) REFERENCES tenant_memberships(tenant_id,id),
 CHECK (operational_total >= 0 AND currency_minor_units <= 6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE lots (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 item_id BIGINT UNSIGNED NOT NULL,
 lot_code VARCHAR(128) COLLATE utf8mb4_0900_bin NOT NULL,
 tracking_mode VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 supplier_lot VARCHAR(128) COLLATE utf8mb4_0900_bin NULL,
 manufactured_on DATE NULL,
 expires_on DATE NULL,
 is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
 UNIQUE KEY uq_lot_item(tenant_id,company_id,item_id,id),
 UNIQUE KEY uq_lot_code(tenant_id,company_id,item_id,lot_code),
 FOREIGN KEY (tenant_id,company_id,item_id) REFERENCES items(tenant_id,company_id,id),
 CHECK (is_blocked IN (0,1)),
 CHECK (manufactured_on IS NULL OR expires_on IS NULL OR manufactured_on <= expires_on),
 CHECK ((tracking_mode='NONE' AND lot_code='SYSTEM' AND supplier_lot IS NULL AND manufactured_on IS NULL AND expires_on IS NULL) OR (tracking_mode='LOT' AND lot_code<>'SYSTEM' AND CHAR_LENGTH(lot_code)>0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE document_lines (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 document_id BIGINT UNSIGNED NOT NULL,
 warehouse_id BIGINT UNSIGNED NOT NULL,
 item_id BIGINT UNSIGNED NOT NULL,
 item_unit_id BIGINT UNSIGNED NOT NULL,
 lot_id BIGINT UNSIGNED NOT NULL,
 line_number SMALLINT UNSIGNED NOT NULL,
 sku VARCHAR(60) NOT NULL,
 item_name VARCHAR(200) NOT NULL,
 unit_code VARCHAR(20) NOT NULL,
 unit_name VARCHAR(100) NOT NULL,
 lot_code VARCHAR(128) NOT NULL,
 supplier_lot VARCHAR(128) NULL,
 manufactured_on DATE NULL,
 expires_on DATE NULL,
 stock_condition VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 entered_quantity DECIMAL(24,9) NOT NULL,
 conversion_factor DECIMAL(24,9) NOT NULL,
 base_quantity DECIMAL(24,9) NOT NULL,
 entered_unit_cost DECIMAL(24,6) NOT NULL,
 base_unit_cost DECIMAL(24,6) NOT NULL,
 carried_value DECIMAL(24,6) NOT NULL,
 UNIQUE KEY uq_doc_line_number(tenant_id,company_id,document_id,line_number),
 UNIQUE KEY uq_line_stock_scope(tenant_id,company_id,document_id,id,warehouse_id,item_id,lot_id,stock_condition),
 FOREIGN KEY (tenant_id,company_id,document_id,warehouse_id) REFERENCES documents(tenant_id,company_id,id,warehouse_id),
 FOREIGN KEY (tenant_id,company_id,item_id,item_unit_id) REFERENCES item_units(tenant_id,company_id,item_id,id),
 FOREIGN KEY (tenant_id,company_id,item_id,lot_id) REFERENCES lots(tenant_id,company_id,item_id,id),
 CHECK (entered_quantity>0 AND conversion_factor>0 AND base_quantity>0 AND entered_unit_cost>=0 AND base_unit_cost>=0 AND carried_value>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE goods_receipts (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 document_id BIGINT UNSIGNED NOT NULL,
 supplier_id BIGINT UNSIGNED NOT NULL,
 document_type VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'GRN',
 supplier_name VARCHAR(200) NOT NULL,
 supplier_reference VARCHAR(120) NULL,
 PRIMARY KEY (tenant_id,company_id,document_id),
 KEY ix_receipt_supplier_reference(tenant_id,company_id,supplier_id,supplier_reference),
 FOREIGN KEY (tenant_id,company_id,document_id,document_type) REFERENCES documents(tenant_id,company_id,id,document_type),
 FOREIGN KEY (tenant_id,company_id,supplier_id) REFERENCES parties(tenant_id,company_id,id),
 CHECK (document_type='GRN')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE stock_buckets (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 warehouse_id BIGINT UNSIGNED NOT NULL,
 location_id BIGINT UNSIGNED NOT NULL,
 item_id BIGINT UNSIGNED NOT NULL,
 lot_id BIGINT UNSIGNED NOT NULL,
 location_kind VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 stock_condition VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 UNIQUE KEY uq_bucket_key(tenant_id,company_id,lot_id,location_id,stock_condition),
 UNIQUE KEY uq_bucket_scope(tenant_id,company_id,id),
 UNIQUE KEY uq_bucket_stock_scope(tenant_id,company_id,id,warehouse_id,item_id,lot_id,stock_condition),
 KEY ix_bucket_warehouse(tenant_id,company_id,warehouse_id,id),
 FOREIGN KEY (tenant_id,company_id,item_id,lot_id) REFERENCES lots(tenant_id,company_id,item_id,id),
 FOREIGN KEY (tenant_id,company_id,warehouse_id,location_id,location_kind) REFERENCES locations(tenant_id,company_id,warehouse_id,id,kind),
 CHECK ((location_kind='STORAGE' AND stock_condition='AVAILABLE') OR (location_kind='HOLD' AND stock_condition='HOLD') OR (location_kind='DAMAGED' AND stock_condition='DAMAGED'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE stock_entries (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 document_id BIGINT UNSIGNED NOT NULL,
 line_id BIGINT UNSIGNED NOT NULL,
 bucket_id BIGINT UNSIGNED NOT NULL,
 warehouse_id BIGINT UNSIGNED NOT NULL,
 item_id BIGINT UNSIGNED NOT NULL,
 lot_id BIGINT UNSIGNED NOT NULL,
 stock_condition VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 quantity_base DECIMAL(24,9) NOT NULL,
 value_delta DECIMAL(24,6) NOT NULL,
 UNIQUE KEY uq_entry_scope(tenant_id,company_id,bucket_id,id),
 UNIQUE KEY uq_entry_line_bucket(tenant_id,company_id,document_id,line_id,bucket_id),
 FOREIGN KEY (tenant_id,company_id,bucket_id,warehouse_id,item_id,lot_id,stock_condition) REFERENCES stock_buckets(tenant_id,company_id,id,warehouse_id,item_id,lot_id,stock_condition),
 FOREIGN KEY (tenant_id,company_id,document_id,line_id,warehouse_id,item_id,lot_id,stock_condition) REFERENCES document_lines(tenant_id,company_id,document_id,id,warehouse_id,item_id,lot_id,stock_condition),
 CHECK (quantity_base<>0 AND (value_delta=0 OR SIGN(quantity_base)=SIGN(value_delta)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE stock_balances (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 bucket_id BIGINT UNSIGNED NOT NULL,
 last_entry_id BIGINT UNSIGNED NOT NULL,
 row_version BIGINT UNSIGNED NOT NULL,
 on_hand_base DECIMAL(24,9) NOT NULL,
 operational_value DECIMAL(24,6) NOT NULL,
 PRIMARY KEY (tenant_id,company_id,bucket_id),
 FOREIGN KEY (tenant_id,company_id,bucket_id,last_entry_id) REFERENCES stock_entries(tenant_id,company_id,bucket_id,id),
 CHECK (on_hand_base>=0 AND operational_value>=0 AND row_version>0 AND (on_hand_base>0 OR operational_value=0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE idempotency_keys (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 actor_membership_id BIGINT UNSIGNED NOT NULL,
 document_id BIGINT UNSIGNED NOT NULL,
 command VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 operation_key BINARY(16) NOT NULL,
 request_hash BINARY(32) NOT NULL,
 PRIMARY KEY (tenant_id,company_id,actor_membership_id,command,operation_key),
 UNIQUE KEY uq_operation_document(tenant_id,company_id,document_id),
 FOREIGN KEY (tenant_id,actor_membership_id) REFERENCES tenant_memberships(tenant_id,id),
 FOREIGN KEY (tenant_id,company_id,document_id,command) REFERENCES documents(tenant_id,company_id,id,document_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
