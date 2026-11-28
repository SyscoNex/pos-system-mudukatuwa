ALTER TABLE document_lines
 ADD production_role VARCHAR(6) CHARACTER SET ascii COLLATE ascii_bin NULL,
 ADD production_input_group SMALLINT UNSIGNED NULL,
 ADD production_output_slot TINYINT GENERATED ALWAYS AS (CASE WHEN production_role='OUTPUT' THEN 1 END) STORED,
 ADD UNIQUE KEY uq_production_output_slot(tenant_id,company_id,document_id,production_output_slot),
 ADD UNIQUE KEY uq_production_line(tenant_id,company_id,document_id,id,warehouse_id,item_id,lot_id,production_role),
 ADD KEY ix_production_trace(tenant_id,company_id,lot_id,production_role,document_id),
 ADD CONSTRAINT ck_production_line_role CHECK ((production_role IS NULL AND production_input_group IS NULL)
  OR (production_role IS NOT NULL AND lot_id IS NOT NULL AND stock_condition='AVAILABLE' AND
    ((production_role='INPUT' AND production_input_group IS NOT NULL AND production_input_group>0)
    OR (production_role='OUTPUT' AND production_input_group IS NULL))));
-- statement-break
ALTER TABLE stock_entries ADD UNIQUE KEY uq_entry_production_line(tenant_id,company_id,document_id,line_id,id);
-- statement-break
CREATE TABLE production_events (
 tenant_id BIGINT UNSIGNED NOT NULL,
 company_id BIGINT UNSIGNED NOT NULL,
 document_id BIGINT UNSIGNED NOT NULL,
 document_type VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'PROD',
 warehouse_id BIGINT UNSIGNED NOT NULL,
 output_line_id BIGINT UNSIGNED NOT NULL,
 output_entry_id BIGINT UNSIGNED NOT NULL,
 output_item_id BIGINT UNSIGNED NOT NULL,
 output_lot_id BIGINT UNSIGNED NOT NULL,
 output_role VARCHAR(6) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'OUTPUT',
 production_reference VARCHAR(120) NULL,
 PRIMARY KEY(tenant_id,company_id,document_id),
 UNIQUE KEY uq_production_entry(tenant_id,company_id,output_entry_id),
 KEY ix_production_warehouse(tenant_id,company_id,warehouse_id,document_id),
 KEY ix_production_origin(tenant_id,company_id,output_lot_id,document_id),
 FOREIGN KEY(tenant_id,company_id,document_id,document_type) REFERENCES documents(tenant_id,company_id,id,document_type),
 FOREIGN KEY(tenant_id,company_id,document_id,warehouse_id) REFERENCES documents(tenant_id,company_id,id,warehouse_id),
 FOREIGN KEY(tenant_id,company_id,document_id,output_line_id,warehouse_id,output_item_id,output_lot_id,output_role)
  REFERENCES document_lines(tenant_id,company_id,document_id,id,warehouse_id,item_id,lot_id,production_role),
 FOREIGN KEY(tenant_id,company_id,document_id,output_line_id,output_entry_id)
  REFERENCES stock_entries(tenant_id,company_id,document_id,line_id,id),
 CONSTRAINT ck_production_event_type CHECK(document_type='PROD' AND output_role='OUTPUT')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
-- statement-break
CREATE TRIGGER p107_production_no_update BEFORE UPDATE ON production_events FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Posted production events are immutable';
-- statement-break
CREATE TRIGGER p107_production_no_delete BEFORE DELETE ON production_events FOR EACH ROW
 SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Posted production events cannot be deleted';
