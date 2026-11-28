-- Idempotent existing-company initialization only; no client outlet is invented.
INSERT INTO warehouses(tenant_id,company_id,branch_id,code,name,kind,is_active,is_default,created_at,updated_at)
SELECT tenant_id,id,NULL,'SYS-TRANSIT','Internal transit','TRANSIT',TRUE,FALSE,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6)
FROM companies c WHERE NOT EXISTS(SELECT 1 FROM warehouses w WHERE w.tenant_id=c.tenant_id AND w.company_id=c.id AND w.kind='TRANSIT');
-- statement-break
INSERT INTO locations(tenant_id,company_id,warehouse_id,warehouse_kind,code,name,kind,created_at,updated_at)
SELECT tenant_id,company_id,id,'TRANSIT','TRANSIT','In transit','TRANSIT',UTC_TIMESTAMP(6),UTC_TIMESTAMP(6)
FROM warehouses w WHERE w.kind='TRANSIT' AND NOT EXISTS(SELECT 1 FROM locations l WHERE l.tenant_id=w.tenant_id AND l.company_id=w.company_id AND l.warehouse_id=w.id AND l.kind='TRANSIT');
-- statement-break
INSERT INTO audit_events(tenant_id,company_id,operator_reference,action,entity_type,entity_id,reason,correlation_id,occurred_at)
SELECT w.tenant_id,w.company_id,'migration-0005','TRANSIT_INITIALIZED','WAREHOUSE',w.id,'P1-03 internal storage initialization','migration-0005',UTC_TIMESTAMP(6)
FROM warehouses w WHERE w.kind='TRANSIT' AND NOT EXISTS(SELECT 1 FROM audit_events a WHERE a.tenant_id=w.tenant_id AND a.company_id=w.company_id AND a.action='TRANSIT_INITIALIZED' AND a.entity_id=w.id);
