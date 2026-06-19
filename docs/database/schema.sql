-- ProstarM Info System Ltd. Inventory Management System
-- PostgreSQL 15+ schema
-- Design notes:
-- 1. Stock is isolated by branch, material, and stock_condition.
-- 2. "GOOD" stock is the only dispatchable condition for normal outward issues.
-- 3. Rejected, damaged, buyback, and scrap stock remain in separate balances and ledgers.
-- 4. Transaction tables are append-only. Current stock is maintained in inventory_balances.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TYPE user_role AS ENUM ('ADMIN', 'STORE_MANAGER', 'VIEWER');
CREATE TYPE branch_type AS ENUM ('BRANCH', 'WAREHOUSE', 'SERVICE_CENTER', 'HQ');
CREATE TYPE stock_condition AS ENUM ('GOOD', 'REJECTED', 'DAMAGED', 'BUYBACK', 'SCRAP');
CREATE TYPE transaction_type AS ENUM (
  'INWARD',
  'OUTWARD',
  'TRANSFER_OUT',
  'TRANSFER_IN',
  'ADJUSTMENT',
  'CONDITION_MOVE'
);
CREATE TYPE import_status AS ENUM ('PENDING', 'VALIDATED', 'FAILED', 'COMMITTED');

CREATE TABLE branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(32) NOT NULL UNIQUE,
  name varchar(160) NOT NULL,
  type branch_type NOT NULL DEFAULT 'WAREHOUSE',
  address text,
  city varchar(100),
  state varchar(100),
  country varchar(100) NOT NULL DEFAULT 'India',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name varchar(160) NOT NULL,
  email citext NOT NULL UNIQUE,
  password_hash text NOT NULL,
  role user_role NOT NULL DEFAULT 'VIEWER',
  branch_id uuid REFERENCES branches(id),
  is_active boolean NOT NULL DEFAULT true,
  last_login_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE refresh_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(120) NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sub_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  name varchar(120) NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_sub_categories_category_name UNIQUE (category_id, name)
);

CREATE TABLE asset_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(120) NOT NULL UNIQUE,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE uoms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(24) NOT NULL UNIQUE,
  name varchar(80) NOT NULL,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE materials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sku varchar(64) NOT NULL UNIQUE,
  item_name varchar(200) NOT NULL,
  description text,
  category_id uuid NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  sub_category_id uuid REFERENCES sub_categories(id) ON DELETE RESTRICT,
  asset_type_id uuid REFERENCES asset_types(id) ON DELETE RESTRICT,
  uom_id uuid NOT NULL REFERENCES uoms(id) ON DELETE RESTRICT,
  minimum_stock_level numeric(14,3) NOT NULL DEFAULT 0 CHECK (minimum_stock_level >= 0),
  standard_unit_price numeric(14,2) NOT NULL DEFAULT 0 CHECK (standard_unit_price >= 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE suppliers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(180) NOT NULL UNIQUE,
  contact_name varchar(160),
  phone varchar(40),
  email citext,
  gstin varchar(32),
  address text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE inventory_balances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  material_id uuid NOT NULL REFERENCES materials(id) ON DELETE RESTRICT,
  branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  condition stock_condition NOT NULL DEFAULT 'GOOD',
  quantity_on_hand numeric(14,3) NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
  average_unit_cost numeric(14,2) NOT NULL DEFAULT 0 CHECK (average_unit_cost >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_inventory_balance UNIQUE (material_id, branch_id, condition)
);

CREATE INDEX ix_inventory_balances_branch_condition ON inventory_balances(branch_id, condition);
CREATE INDEX ix_inventory_balances_material ON inventory_balances(material_id);

CREATE TABLE stock_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_no varchar(64) NOT NULL UNIQUE,
  transaction_type transaction_type NOT NULL,
  branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  reference_no varchar(100),
  counterparty_name varchar(180),
  department_or_client varchar(180),
  transaction_date date NOT NULL,
  remarks text,
  created_by uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_stock_transactions_branch_date ON stock_transactions(branch_id, transaction_date);
CREATE INDEX ix_stock_transactions_type_date ON stock_transactions(transaction_type, transaction_date);

CREATE TABLE stock_transaction_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id uuid NOT NULL REFERENCES stock_transactions(id) ON DELETE CASCADE,
  material_id uuid NOT NULL REFERENCES materials(id) ON DELETE RESTRICT,
  quantity numeric(14,3) NOT NULL CHECK (quantity > 0),
  unit_price numeric(14,2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
  condition_from stock_condition,
  condition_to stock_condition,
  line_total numeric(16,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ck_condition_required CHECK (
    (condition_from IS NOT NULL) OR (condition_to IS NOT NULL)
  )
);

CREATE INDEX ix_stock_transaction_lines_material ON stock_transaction_lines(material_id);

CREATE TABLE stock_disposition_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_line_id uuid NOT NULL UNIQUE REFERENCES stock_transaction_lines(id) ON DELETE CASCADE,
  material_id uuid NOT NULL REFERENCES materials(id) ON DELETE RESTRICT,
  branch_id uuid NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  condition stock_condition NOT NULL CHECK (condition IN ('REJECTED', 'DAMAGED', 'BUYBACK', 'SCRAP')),
  quantity numeric(14,3) NOT NULL CHECK (quantity > 0),
  reason text,
  recorded_by uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_disposition_ledger_condition_branch ON stock_disposition_ledger(condition, branch_id);

CREATE TABLE excel_import_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  original_file_name varchar(255) NOT NULL,
  import_target varchar(60) NOT NULL CHECK (import_target IN ('MATERIAL_MASTER', 'INVENTORY_COUNTS')),
  status import_status NOT NULL DEFAULT 'PENDING',
  uploaded_by uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  committed_at timestamptz,
  error_summary text
);

CREATE TABLE excel_import_rows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL REFERENCES excel_import_batches(id) ON DELETE CASCADE,
  row_number integer NOT NULL,
  raw_payload jsonb NOT NULL,
  normalized_payload jsonb,
  validation_errors jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_valid boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_import_batch_row UNIQUE (batch_id, row_number)
);

CREATE TABLE audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action varchar(80) NOT NULL,
  entity_type varchar(80) NOT NULL,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE VIEW active_stock_report AS
SELECT
  b.code AS branch_code,
  b.name AS branch_name,
  m.sku,
  m.item_name,
  c.name AS category_name,
  sc.name AS sub_category_name,
  u.code AS uom,
  ib.condition,
  ib.quantity_on_hand,
  ib.average_unit_cost,
  (ib.quantity_on_hand * ib.average_unit_cost) AS stock_value,
  m.minimum_stock_level,
  (ib.condition = 'GOOD' AND ib.quantity_on_hand <= m.minimum_stock_level) AS is_low_stock
FROM inventory_balances ib
JOIN materials m ON m.id = ib.material_id
JOIN branches b ON b.id = ib.branch_id
JOIN categories c ON c.id = m.category_id
LEFT JOIN sub_categories sc ON sc.id = m.sub_category_id
JOIN uoms u ON u.id = m.uom_id
WHERE m.is_active = true
  AND b.is_active = true;

CREATE OR REPLACE VIEW rejected_stock_ledger AS
SELECT * FROM stock_disposition_ledger WHERE condition = 'REJECTED';

CREATE OR REPLACE VIEW damaged_stock_ledger AS
SELECT * FROM stock_disposition_ledger WHERE condition = 'DAMAGED';

CREATE OR REPLACE VIEW buyback_stock_ledger AS
SELECT * FROM stock_disposition_ledger WHERE condition = 'BUYBACK';

CREATE OR REPLACE VIEW scrap_stock_ledger AS
SELECT * FROM stock_disposition_ledger WHERE condition = 'SCRAP';

CREATE OR REPLACE FUNCTION touch_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_branches_touch
BEFORE UPDATE ON branches
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER trg_users_touch
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER trg_categories_touch
BEFORE UPDATE ON categories
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER trg_sub_categories_touch
BEFORE UPDATE ON sub_categories
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER trg_asset_types_touch
BEFORE UPDATE ON asset_types
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER trg_materials_touch
BEFORE UPDATE ON materials
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TRIGGER trg_suppliers_touch
BEFORE UPDATE ON suppliers
FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE OR REPLACE FUNCTION apply_stock_transaction_line()
RETURNS trigger AS $$
DECLARE
  tx stock_transactions%ROWTYPE;
  from_balance inventory_balances%ROWTYPE;
  weighted_cost numeric(14,2);
BEGIN
  SELECT * INTO tx FROM stock_transactions WHERE id = NEW.transaction_id;

  IF NEW.condition_from IS NOT NULL THEN
    SELECT * INTO from_balance
    FROM inventory_balances
    WHERE material_id = NEW.material_id
      AND branch_id = tx.branch_id
      AND condition = NEW.condition_from
    FOR UPDATE;

    IF NOT FOUND OR from_balance.quantity_on_hand < NEW.quantity THEN
      RAISE EXCEPTION 'Insufficient stock for material %, branch %, condition %',
        NEW.material_id, tx.branch_id, NEW.condition_from;
    END IF;

    UPDATE inventory_balances
    SET quantity_on_hand = quantity_on_hand - NEW.quantity,
        updated_at = now()
    WHERE id = from_balance.id;
  END IF;

  IF NEW.condition_to IS NOT NULL THEN
    INSERT INTO inventory_balances (material_id, branch_id, condition, quantity_on_hand, average_unit_cost)
    VALUES (NEW.material_id, tx.branch_id, NEW.condition_to, NEW.quantity, NEW.unit_price)
    ON CONFLICT (material_id, branch_id, condition)
    DO UPDATE SET
      average_unit_cost = CASE
        WHEN inventory_balances.quantity_on_hand + EXCLUDED.quantity_on_hand = 0 THEN inventory_balances.average_unit_cost
        ELSE ROUND(
          ((inventory_balances.quantity_on_hand * inventory_balances.average_unit_cost)
          + (EXCLUDED.quantity_on_hand * EXCLUDED.average_unit_cost))
          / (inventory_balances.quantity_on_hand + EXCLUDED.quantity_on_hand),
          2
        )
      END,
      quantity_on_hand = inventory_balances.quantity_on_hand + EXCLUDED.quantity_on_hand,
      updated_at = now();
  END IF;

  IF NEW.condition_to IN ('REJECTED', 'DAMAGED', 'BUYBACK', 'SCRAP') THEN
    INSERT INTO stock_disposition_ledger (
      transaction_line_id,
      material_id,
      branch_id,
      condition,
      quantity,
      reason,
      recorded_by
    )
    VALUES (
      NEW.id,
      NEW.material_id,
      tx.branch_id,
      NEW.condition_to,
      NEW.quantity,
      tx.remarks,
      tx.created_by
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_apply_stock_transaction_line
AFTER INSERT ON stock_transaction_lines
FOR EACH ROW EXECUTE FUNCTION apply_stock_transaction_line();

CREATE OR REPLACE FUNCTION prevent_stock_line_mutation()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'Stock transaction lines are immutable. Create a reversal or adjustment transaction instead.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_stock_line_update
BEFORE UPDATE OR DELETE ON stock_transaction_lines
FOR EACH ROW EXECUTE FUNCTION prevent_stock_line_mutation();

INSERT INTO uoms (code, name) VALUES
  ('PCS', 'Pieces'),
  ('NOS', 'Numbers'),
  ('MTR', 'Meters'),
  ('BOX', 'Box')
ON CONFLICT (code) DO NOTHING;
