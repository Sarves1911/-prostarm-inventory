# Backend API Roadmap

Recommended stack: Node.js, Express, TypeScript, PostgreSQL, Prisma or Kysely, Zod validation, bcrypt, JWT access tokens, HTTP-only refresh-token cookies, and worker-backed Excel import processing.

## Architecture

Use a layered backend:

- `routes`: HTTP paths, request parsing, auth guards.
- `controllers`: request orchestration and response shape.
- `services`: business rules such as stock validation, import validation, and report filters.
- `repositories`: database access and transaction boundaries.
- `jobs`: async Excel parsing, report exports, backup generation.
- `middleware`: JWT authentication, RBAC, request logging, error handling, upload limits.

Critical write flows must run inside database transactions. Inward, outward, condition moves, and imports should rely on row-level locking through the database trigger/function in `schema.sql`, or through equivalent service-level SQL with `SELECT ... FOR UPDATE`.

## Auth and RBAC

| Method | Endpoint | Roles | Purpose |
|---|---|---:|---|
| POST | `/api/auth/login` | Public | Validate email/password, return access token, set refresh cookie. |
| POST | `/api/auth/refresh` | Authenticated refresh | Issue a new access token. |
| POST | `/api/auth/logout` | Any | Revoke refresh token. |
| GET | `/api/auth/me` | Any | Current user, role, and branch scope. |
| GET | `/api/users` | Admin | List users. |
| POST | `/api/users` | Admin | Create user with role and branch. |
| PATCH | `/api/users/:id` | Admin | Update profile, role, branch, active state. |

RBAC baseline:

- `ADMIN`: full access, settings, users, imports, backups, all branches.
- `STORE_MANAGER`: create inward/outward/condition transactions for assigned branch or allowed branches.
- `VIEWER`: read dashboards, reports, exports only.

## Master Data

| Method | Endpoint | Roles | Purpose |
|---|---|---:|---|
| GET | `/api/branches` | Any | Branch dropdowns and filters. |
| POST | `/api/branches` | Admin | Add branch or warehouse. |
| PATCH | `/api/branches/:id` | Admin | Update branch. |
| GET | `/api/materials` | Any | Search/filter material master. |
| POST | `/api/materials` | Admin, Store Manager | Create SKU. |
| PATCH | `/api/materials/:id` | Admin, Store Manager | Update SKU details and minimum stock. |
| GET | `/api/categories` | Any | List categories/sub-categories. |
| POST | `/api/categories` | Admin | Create category. |
| PATCH | `/api/categories/:id` | Admin | Update category. |
| DELETE | `/api/categories/:id` | Admin | Soft-delete category if unused. |
| GET | `/api/asset-types` | Any | List asset types. |
| POST | `/api/asset-types` | Admin | Create asset type. |

## Inventory Queries

| Method | Endpoint | Roles | Purpose |
|---|---|---:|---|
| GET | `/api/inventory/balances` | Any | Current stock by branch, material, category, condition. |
| GET | `/api/inventory/low-stock` | Any | Good stock at or below minimum stock level. |
| GET | `/api/inventory/materials/:id/ledger` | Any | Complete movement history for one material. |
| GET | `/api/dashboard/summary` | Any | Metric cards: total items, low stock, valuation, recent activity. |
| GET | `/api/dashboard/recent-activity` | Any | Latest stock transactions. |

Example filters:

```http
GET /api/inventory/balances?branchId=...&categoryId=...&condition=GOOD&search=laptop
GET /api/dashboard/summary?branchId=all
```

## Inward Flow

| Method | Endpoint | Roles | Purpose |
|---|---|---:|---|
| POST | `/api/stock/inward` | Admin, Store Manager | Receive stock against PO/supplier. |
| GET | `/api/stock/inward` | Any | List inward entries. |
| GET | `/api/stock/inward/:id` | Any | Inward detail with line items. |

Request shape:

```json
{
  "poNumber": "PO-2026-001",
  "supplierName": "ABC Suppliers",
  "branchId": "uuid",
  "receivedDate": "2026-06-19",
  "remarks": "Initial receipt",
  "lines": [
    {
      "materialId": "uuid",
      "quantity": 10,
      "unitPrice": 1250,
      "conditionTo": "GOOD"
    }
  ]
}
```

Rules:

- Quantity must be positive.
- `conditionTo` can be `GOOD` or `REJECTED` for arrival/QC flows.
- Creates `stock_transactions` with type `INWARD`.
- Creates line rows with `condition_to`.
- The database increments the isolated balance for that branch/material/condition.

## Outward Flow

| Method | Endpoint | Roles | Purpose |
|---|---|---:|---|
| POST | `/api/stock/outward` | Admin, Store Manager | Dispatch usable stock. |
| GET | `/api/stock/outward` | Any | List outward entries. |
| GET | `/api/stock/outward/:id` | Any | Outward detail with line items. |

Request shape:

```json
{
  "requisitionNumber": "REQ-2026-010",
  "departmentOrClient": "Networking Team",
  "branchId": "uuid",
  "dispatchDate": "2026-06-19",
  "lines": [
    {
      "materialId": "uuid",
      "quantity": 2
    }
  ]
}
```

Rules:

- Normal outward dispatch always decrements `GOOD` stock.
- Reject request with HTTP `409 Conflict` when stock is insufficient.
- Use a single transaction for header and lines.
- Transaction lines use `condition_from: "GOOD"` and no `condition_to`.

## Specialized Dispositions

| Method | Endpoint | Roles | Purpose |
|---|---|---:|---|
| POST | `/api/stock/dispositions` | Admin, Store Manager | Move stock between conditions, for example GOOD to DAMAGED. |
| GET | `/api/stock/dispositions` | Any | Filter disposition ledger. |
| GET | `/api/stock/rejected` | Any | Rejected stock ledger. |
| GET | `/api/stock/damaged` | Any | Damaged stock ledger. |
| GET | `/api/stock/buyback` | Any | Buyback stock ledger. |
| GET | `/api/stock/scrap` | Any | Scrap stock ledger. |

Request shape:

```json
{
  "branchId": "uuid",
  "movementDate": "2026-06-19",
  "fromCondition": "GOOD",
  "toCondition": "DAMAGED",
  "reason": "Damaged during storage",
  "lines": [
    {
      "materialId": "uuid",
      "quantity": 1
    }
  ]
}
```

Rules:

- `toCondition` must be one of `REJECTED`, `DAMAGED`, `BUYBACK`, `SCRAP` unless implementing restoration approval.
- The disposition ledger is automatically populated when a transaction line moves into a non-good condition.
- Reports must include condition filters so non-good stock never inflates usable inventory.

## Excel Upload and Backup

| Method | Endpoint | Roles | Purpose |
|---|---|---:|---|
| POST | `/api/imports/materials/validate` | Admin, Store Manager | Upload `.xlsx`/`.csv`, parse, validate, return row errors. |
| POST | `/api/imports/materials/commit` | Admin | Commit validated material master import. |
| POST | `/api/imports/inventory/validate` | Admin, Store Manager | Validate branch/material/condition counts. |
| POST | `/api/imports/inventory/commit` | Admin | Commit inventory overwrite as adjustment transactions. |
| GET | `/api/imports/:batchId` | Admin, Store Manager | Batch status and row-level errors. |
| GET | `/api/exports/active-stock.xlsx` | Any | Download active stock state. |
| GET | `/api/exports/stock-report.xlsx` | Any | Download filtered stock report. |
| GET | `/api/exports/stock-report.pdf` | Any | Download PDF report. |
| POST | `/api/backups/sql-dump` | Admin | Start SQL dump job. |
| GET | `/api/backups/:jobId/download` | Admin | Download completed dump. |

Material import expected columns:

| Column | Required | Notes |
|---|---:|---|
| `sku` | Yes | Unique material ID. |
| `item_name` | Yes | Human-readable name. |
| `description` | No | Free text. |
| `category` | Yes | Must exist or be created by admin import mode. |
| `sub_category` | No | Must belong to category. |
| `asset_type` | No | Optional. |
| `uom` | Yes | Must match UOM code. |
| `minimum_stock_level` | Yes | Number >= 0. |
| `standard_unit_price` | No | Number >= 0. |

Inventory count import expected columns:

| Column | Required | Notes |
|---|---:|---|
| `branch_code` | Yes | Must exist and be active. |
| `sku` | Yes | Must exist and be active. |
| `condition` | Yes | `GOOD`, `REJECTED`, `DAMAGED`, `BUYBACK`, or `SCRAP`. |
| `quantity_on_hand` | Yes | Number >= 0. |
| `average_unit_cost` | No | Number >= 0. |

Commit strategy:

- Material imports upsert master data.
- Inventory overwrite imports should create auditable `ADJUSTMENT` transactions for deltas rather than directly replacing balances.
- Failed rows stay in `excel_import_rows.validation_errors`.

## Reporting

| Method | Endpoint | Roles | Purpose |
|---|---|---:|---|
| GET | `/api/reports/stock` | Any | Filterable stock report. |
| GET | `/api/reports/movements` | Any | Transaction movement report. |
| GET | `/api/reports/valuation` | Any | Valuation by branch/category/condition. |
| GET | `/api/reports/low-stock` | Any | Low stock report. |

Filters:

```http
GET /api/reports/stock?from=2026-06-01&to=2026-06-19&branchId=...&categoryId=...&condition=DAMAGED
```

## Error Contract

Use consistent errors:

```json
{
  "error": {
    "code": "INSUFFICIENT_STOCK",
    "message": "Insufficient GOOD stock for SKU LAP-001 at Mumbai Warehouse.",
    "details": {
      "available": 3,
      "requested": 5
    }
  }
}
```

Suggested status codes:

- `400`: validation error.
- `401`: missing/invalid token.
- `403`: role or branch scope violation.
- `404`: entity not found.
- `409`: stock conflict, duplicate SKU, commit conflict.
- `422`: import validation failed.
- `500`: unexpected server error.
