# Inventory ERD

```mermaid
erDiagram
  BRANCHES ||--o{ USERS : assigned_to
  BRANCHES ||--o{ INVENTORY_BALANCES : stores
  BRANCHES ||--o{ STOCK_TRANSACTIONS : records

  USERS ||--o{ STOCK_TRANSACTIONS : creates
  USERS ||--o{ REFRESH_TOKENS : owns
  USERS ||--o{ EXCEL_IMPORT_BATCHES : uploads
  USERS ||--o{ AUDIT_LOG : acts

  CATEGORIES ||--o{ SUB_CATEGORIES : contains
  CATEGORIES ||--o{ MATERIALS : classifies
  SUB_CATEGORIES ||--o{ MATERIALS : classifies
  ASSET_TYPES ||--o{ MATERIALS : types
  UOMS ||--o{ MATERIALS : measures

  MATERIALS ||--o{ INVENTORY_BALANCES : has
  MATERIALS ||--o{ STOCK_TRANSACTION_LINES : moved
  MATERIALS ||--o{ STOCK_DISPOSITION_LEDGER : logged

  STOCK_TRANSACTIONS ||--o{ STOCK_TRANSACTION_LINES : contains
  STOCK_TRANSACTION_LINES ||--o| STOCK_DISPOSITION_LEDGER : creates

  EXCEL_IMPORT_BATCHES ||--o{ EXCEL_IMPORT_ROWS : contains

  BRANCHES {
    uuid id PK
    varchar code UK
    varchar name
    branch_type type
    boolean is_active
  }

  USERS {
    uuid id PK
    citext email UK
    text password_hash
    user_role role
    uuid branch_id FK
  }

  MATERIALS {
    uuid id PK
    varchar sku UK
    varchar item_name
    uuid category_id FK
    uuid sub_category_id FK
    uuid asset_type_id FK
    uuid uom_id FK
    numeric minimum_stock_level
  }

  INVENTORY_BALANCES {
    uuid id PK
    uuid material_id FK
    uuid branch_id FK
    stock_condition condition
    numeric quantity_on_hand
    numeric average_unit_cost
  }

  STOCK_TRANSACTIONS {
    uuid id PK
    varchar transaction_no UK
    transaction_type transaction_type
    uuid branch_id FK
    varchar reference_no
    date transaction_date
    uuid created_by FK
  }

  STOCK_TRANSACTION_LINES {
    uuid id PK
    uuid transaction_id FK
    uuid material_id FK
    numeric quantity
    numeric unit_price
    stock_condition condition_from
    stock_condition condition_to
  }

  STOCK_DISPOSITION_LEDGER {
    uuid id PK
    uuid transaction_line_id FK
    uuid material_id FK
    uuid branch_id FK
    stock_condition condition
    numeric quantity
  }
```

## Core Relationship Rules

- `inventory_balances` has exactly one row per `material_id`, `branch_id`, and `condition`.
- Normal usable stock is `condition = GOOD`.
- Non-good stock is isolated under `REJECTED`, `DAMAGED`, `BUYBACK`, or `SCRAP`.
- Inward transactions increment `condition_to`.
- Outward transactions decrement `condition_from = GOOD`.
- Disposition transactions decrement `condition_from` and increment `condition_to`.
- Transaction lines are immutable; corrections must be reversal or adjustment transactions.
