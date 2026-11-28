ALTER TABLE stock_buckets DROP CHECK stock_buckets_chk_1,
 ADD CONSTRAINT ck_bucket_disposition_106 CHECK (
 (location_kind='STORAGE' AND stock_condition='AVAILABLE') OR
 (location_kind='HOLD' AND stock_condition='HOLD') OR
 (location_kind='DAMAGED' AND stock_condition='DAMAGED') OR
 (location_kind='TRANSIT' AND stock_condition='TRANSIT')
 ),
 ADD UNIQUE KEY uq_bucket_106_item(tenant_id,company_id,id,item_id);
-- statement-break
ALTER TABLE document_lines MODIFY lot_id BIGINT UNSIGNED NULL,
 ADD UNIQUE KEY uq_transfer_line_item(tenant_id,company_id,document_id,id,item_id);
-- statement-break
ALTER TABLE stock_entries ADD UNIQUE KEY uq_entry_106_scope(tenant_id,company_id,id);
-- statement-break
CREATE TABLE stock_transfers (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 request_id BIGINT UNSIGNED NOT NULL,
 source_warehouse_id BIGINT UNSIGNED NOT NULL,
 destination_warehouse_id BIGINT UNSIGNED NOT NULL,
 source_name VARCHAR(200) NOT NULL,
 destination_name VARCHAR(200) NOT NULL,
 reference VARCHAR(120) NULL,
 confirmation_id BIGINT UNSIGNED NULL,
 cancellation_id BIGINT UNSIGNED NULL,
 PRIMARY KEY(tenant_id,company_id,request_id),
 FOREIGN KEY(tenant_id,company_id,request_id,source_warehouse_id) REFERENCES documents(tenant_id,company_id,id,warehouse_id),
 FOREIGN KEY(tenant_id,company_id,destination_warehouse_id) REFERENCES warehouses(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,confirmation_id) REFERENCES documents(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,cancellation_id) REFERENCES documents(tenant_id,company_id,id),
 UNIQUE KEY uq_transfer_confirmation(tenant_id,company_id,confirmation_id),
 UNIQUE KEY uq_transfer_cancellation(tenant_id,company_id,cancellation_id),
 KEY ix_transfer_source(tenant_id,company_id,source_warehouse_id,request_id),
 KEY ix_transfer_dest(tenant_id,company_id,destination_warehouse_id,request_id),
 CHECK(source_warehouse_id<>destination_warehouse_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE stock_reservations (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 request_id BIGINT UNSIGNED NOT NULL,
 request_line_id BIGINT UNSIGNED NOT NULL,
 item_id BIGINT UNSIGNED NOT NULL,
 bucket_id BIGINT UNSIGNED NOT NULL,
 reserved_quantity DECIMAL(24,9) NOT NULL,
 consumed_quantity DECIMAL(24,9) NOT NULL DEFAULT 0,
 released_quantity DECIMAL(24,9) NOT NULL DEFAULT 0,
 UNIQUE KEY uq_reservation_scope(tenant_id,company_id,id),
 UNIQUE KEY uq_reservation_line_bucket(tenant_id,company_id,request_id,request_line_id,bucket_id),
 KEY ix_reservation_bucket(tenant_id,company_id,bucket_id),
 FOREIGN KEY(tenant_id,company_id,request_id) REFERENCES stock_transfers(tenant_id,company_id,request_id),
 FOREIGN KEY(tenant_id,company_id,request_id,request_line_id,item_id) REFERENCES document_lines(tenant_id,company_id,document_id,id,item_id),
 FOREIGN KEY(tenant_id,company_id,bucket_id,item_id) REFERENCES stock_buckets(tenant_id,company_id,id,item_id),
 CHECK(reserved_quantity>0 AND consumed_quantity>=0 AND released_quantity>=0 AND consumed_quantity+released_quantity<=reserved_quantity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE transfer_dispatch_allocations (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
 reservation_id BIGINT UNSIGNED NOT NULL,
 dispatch_id BIGINT UNSIGNED NOT NULL,
 source_entry_id BIGINT UNSIGNED NOT NULL,
 transit_entry_id BIGINT UNSIGNED NOT NULL,
 transit_bucket_id BIGINT UNSIGNED NOT NULL,
 quantity DECIMAL(24,9) NOT NULL,
 carried_value DECIMAL(24,6) NOT NULL,
 UNIQUE KEY uq_dispatch_allocation_scope(tenant_id,company_id,id),
 UNIQUE KEY uq_dispatch_source_entry(tenant_id,company_id,source_entry_id),
 UNIQUE KEY uq_dispatch_transit_entry(tenant_id,company_id,transit_entry_id),
 FOREIGN KEY(tenant_id,company_id,reservation_id) REFERENCES stock_reservations(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,dispatch_id) REFERENCES documents(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,source_entry_id) REFERENCES stock_entries(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,transit_bucket_id,transit_entry_id) REFERENCES stock_entries(tenant_id,company_id,bucket_id,id),
 CHECK(quantity>0 AND carried_value>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE transfer_receipt_allocations (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 dispatch_allocation_id BIGINT UNSIGNED NOT NULL,
 receipt_id BIGINT UNSIGNED NOT NULL,
 transit_entry_id BIGINT UNSIGNED NOT NULL,
 destination_entry_id BIGINT UNSIGNED NOT NULL,
 quantity DECIMAL(24,9) NOT NULL,
 carried_value DECIMAL(24,6) NOT NULL,
 PRIMARY KEY(tenant_id,company_id,dispatch_allocation_id,receipt_id),
 UNIQUE KEY uq_receipt_transit_entry(tenant_id,company_id,transit_entry_id),
 UNIQUE KEY uq_receipt_destination_entry(tenant_id,company_id,destination_entry_id),
 FOREIGN KEY(tenant_id,company_id,dispatch_allocation_id) REFERENCES transfer_dispatch_allocations(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,receipt_id) REFERENCES documents(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,transit_entry_id) REFERENCES stock_entries(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,destination_entry_id) REFERENCES stock_entries(tenant_id,company_id,id),
 CHECK(quantity>0 AND carried_value>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE transfer_resolution_allocations (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 dispatch_allocation_id BIGINT UNSIGNED NOT NULL,
 resolution_id BIGINT UNSIGNED NOT NULL,
 transit_entry_id BIGINT UNSIGNED NOT NULL,
 destination_entry_id BIGINT UNSIGNED NULL,
 disposition VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 CHECK((disposition='LOSS' AND destination_entry_id IS NULL) OR (disposition='RETURN' AND destination_entry_id IS NOT NULL)),
 quantity DECIMAL(24,9) NOT NULL,
 carried_value DECIMAL(24,6) NOT NULL,
 PRIMARY KEY(tenant_id,company_id,dispatch_allocation_id,resolution_id),
 UNIQUE KEY uq_resolution_transit_entry(tenant_id,company_id,transit_entry_id),
 UNIQUE KEY uq_resolution_destination_entry(tenant_id,company_id,destination_entry_id),
 FOREIGN KEY(tenant_id,company_id,dispatch_allocation_id) REFERENCES transfer_dispatch_allocations(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,resolution_id) REFERENCES documents(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,transit_entry_id) REFERENCES stock_entries(tenant_id,company_id,id),
 FOREIGN KEY(tenant_id,company_id,destination_entry_id) REFERENCES stock_entries(tenant_id,company_id,id),
 CHECK(quantity>0 AND carried_value>=0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE stock_counts (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 count_id BIGINT UNSIGNED NOT NULL,
 warehouse_id BIGINT UNSIGNED NOT NULL,
 terminal_id BIGINT UNSIGNED NULL,
 status VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'COUNTING',
 active_warehouse_id BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN status='COUNTING' THEN warehouse_id END) STORED,
 row_version BIGINT UNSIGNED NOT NULL DEFAULT 1,
 PRIMARY KEY(tenant_id,company_id,count_id),
 UNIQUE KEY uq_active_count(tenant_id,company_id,active_warehouse_id),
 UNIQUE KEY uq_count_warehouse(tenant_id,company_id,count_id,warehouse_id),
 UNIQUE KEY uq_count_terminal(tenant_id,company_id,terminal_id),
 FOREIGN KEY(tenant_id,company_id,count_id,warehouse_id) REFERENCES documents(tenant_id,company_id,id,warehouse_id),
 FOREIGN KEY(tenant_id,company_id,terminal_id,warehouse_id) REFERENCES documents(tenant_id,company_id,id,warehouse_id),
 CHECK((status='COUNTING' AND terminal_id IS NULL) OR (status IN ('COMPLETED','CANCELLED') AND terminal_id IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TABLE stock_count_lines (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 count_id BIGINT UNSIGNED NOT NULL,
 warehouse_id BIGINT UNSIGNED NOT NULL,
 bucket_id BIGINT UNSIGNED NOT NULL,
 item_id BIGINT UNSIGNED NOT NULL,
 lot_id BIGINT UNSIGNED NOT NULL,
 stock_condition VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
 expected_quantity DECIMAL(24,9) NOT NULL,
 expected_value DECIMAL(24,6) NOT NULL,
 actual_quantity DECIMAL(24,9) NULL,
 positive_unit_cost DECIMAL(24,6) NULL,
 variance_entry_id BIGINT UNSIGNED NULL,
 PRIMARY KEY(tenant_id,company_id,count_id,bucket_id),
 UNIQUE KEY uq_count_variance_entry(tenant_id,company_id,variance_entry_id),
 FOREIGN KEY(tenant_id,company_id,count_id,warehouse_id) REFERENCES stock_counts(tenant_id,company_id,count_id,warehouse_id),
 FOREIGN KEY(tenant_id,company_id,bucket_id,warehouse_id,item_id,lot_id,stock_condition) REFERENCES stock_buckets(tenant_id,company_id,id,warehouse_id,item_id,lot_id,stock_condition),
 FOREIGN KEY(tenant_id,company_id,bucket_id,variance_entry_id) REFERENCES stock_entries(tenant_id,company_id,bucket_id,id),
 CHECK(expected_quantity>=0 AND expected_value>=0 AND (actual_quantity IS NULL OR actual_quantity>=0) AND (positive_unit_cost IS NULL OR positive_unit_cost>=0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
