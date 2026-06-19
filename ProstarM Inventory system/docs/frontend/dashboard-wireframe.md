# Main Dashboard UI Wireframe

Frontend recommendation: React or Next.js, Tailwind CSS, TanStack Query, React Hook Form, Zod, shadcn/ui or Headless UI primitives, and lucide-react icons.

## App Shell

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Top Bar                                                                     │
│ ProstarM Info System Ltd.        Branch: [ All Locations v ]   User menu    │
├───────────────┬─────────────────────────────────────────────────────────────┤
│ Sidebar       │ Dashboard                                                   │
│               │                                                             │
│ Dashboard     │ ┌─────────────┐ ┌──────────────┐ ┌─────────────┐ ┌────────┐ │
│ Materials     │ │ Total Items │ │ Low Stock    │ │ Valuation   │ │ Recent │ │
│ Inward Stock  │ │ 1,248       │ │ 14 alerts    │ │ ₹42.8L      │ │ 32     │ │
│ Outward Stock │ └─────────────┘ └──────────────┘ └─────────────┘ └────────┘ │
│ Dispositions  │                                                             │
│ Reports       │ ┌───────────────────────────┐ ┌───────────────────────────┐ │
│ Imports       │ │ Stock by Condition         │ │ Low Stock Alerts          │ │
│ Settings      │ │ Good/Damaged/Scrap chart   │ │ SKU, branch, available    │ │
│               │ └───────────────────────────┘ └───────────────────────────┘ │
│               │                                                             │
│               │ ┌─────────────────────────────────────────────────────────┐ │
│               │ │ Current Stock Table                                      │ │
│               │ │ Search, category filter, condition tabs, export button   │ │
│               │ └─────────────────────────────────────────────────────────┘ │
└───────────────┴─────────────────────────────────────────────────────────────┘
```

## Primary Components

```tsx
type StockCondition = "GOOD" | "REJECTED" | "DAMAGED" | "BUYBACK" | "SCRAP";

type DashboardFilters = {
  branchId: string | "all";
  categoryId?: string;
  condition?: StockCondition | "ALL";
};

type MetricCardProps = {
  label: string;
  value: string;
  helper?: string;
  tone?: "neutral" | "warning" | "success" | "danger";
  icon: React.ComponentType<{ className?: string }>;
};
```

Component tree:

```text
<AuthenticatedAppShell>
  <SidebarNav />
  <TopBar>
    <BranchLocationSelect />
    <UserMenu />
  </TopBar>
  <DashboardPage>
    <DashboardFilterBar />
    <MetricGrid>
      <MetricCard label="Total Items" />
      <MetricCard label="Low Stock Alerts" tone="warning" />
      <MetricCard label="Total Valuation" />
      <MetricCard label="Recent Activity" />
    </MetricGrid>
    <DashboardPanels>
      <StockConditionChart />
      <LowStockAlertsTable />
    </DashboardPanels>
    <InventorySnapshotTable />
    <RecentActivityTimeline />
  </DashboardPage>
</AuthenticatedAppShell>
```

## Dashboard Layout Details

### Top Bar

- Left: company name, current module title.
- Center/right: branch dropdown with `All Locations`, individual branches, and warehouses.
- Right: notifications, user name, role badge, logout.
- Store managers should only see branches they are authorized to access.

### Sidebar

Navigation:

- Dashboard
- Material Master
- Inward Stock
- Outward Stock
- Dispositions
- Reports
- Excel Import
- Settings

Viewer role:

- Hide create buttons.
- Keep Dashboard, Material Master read-only, Dispositions read-only, Reports, and Export.

### Metric Cards

Cards:

- `Total Items`: count of active SKUs or SKU-location rows depending on selected filter.
- `Low Stock Alerts`: count where `GOOD` quantity is less than or equal to minimum stock level.
- `Total Valuation`: sum of `quantity_on_hand * average_unit_cost`, filter-aware.
- `Recent Activity`: count of stock transactions in the last 7 days.

### Stock by Condition Panel

Use a bar or doughnut chart with:

- Good
- Rejected
- Damaged
- Buyback
- Scrap

The visual purpose is to make it obvious that non-good stock exists but is not usable stock.

### Inventory Snapshot Table

Columns:

- SKU
- Item Name
- Category
- Branch
- Condition
- Available Qty
- UOM
- Minimum Level
- Average Cost
- Stock Value
- Status

Controls:

- Search by SKU or item name.
- Category dropdown.
- Condition segmented control.
- Export current view.
- Row click opens material ledger drawer.

Status rules:

- `Low Stock`: only when condition is `GOOD` and available quantity <= minimum level.
- `Unavailable`: non-good condition.
- `Healthy`: good stock above minimum level.

## Inward Modal Layout

```text
Receive Stock
PO Number            Supplier
Branch               Received Date

Line Items
Material Search      Qty       Unit Price       Condition
[SKU autocomplete]   [number]  [currency]       [Good/Rejected]

[Add Line]                                      [Cancel] [Receive Stock]
```

Validation:

- Disable submit until every line has material, quantity > 0, unit price >= 0.
- Show server conflict or validation errors inline.

## Outward Modal Layout

```text
Dispatch Stock
Requisition No.      Department/Client
Branch               Dispatch Date

Line Items
Material Search      Available Good Qty       Dispatch Qty
[SKU autocomplete]   12 PCS                   [number]

[Add Line]                                      [Cancel] [Dispatch]
```

Validation:

- Material search displays only active materials.
- Available quantity preview must be `GOOD` stock only.
- If dispatch quantity exceeds available quantity, block before submit and still handle server-side `409`.

## Disposition Screen Layout

```text
Disposition Ledger
[Branch v] [From Condition v] [To Condition v] [Date Range] [Export]

Move Stock
From: GOOD        To: DAMAGED
Material          Qty         Reason
```

Condition movement examples:

- `GOOD` to `DAMAGED`
- `GOOD` to `SCRAP`
- `GOOD` to `BUYBACK`
- `GOOD` or `REJECTED` to `SCRAP`

Restoring non-good stock to `GOOD` should require Admin approval if implemented.

## Suggested Routes

```text
/login
/dashboard
/materials
/stock/inward
/stock/outward
/stock/dispositions
/reports/stock
/imports
/settings/categories
/settings/branches
/settings/users
```

## API Hooks

```tsx
useDashboardSummary(filters)
useInventoryBalances(filters)
useLowStockAlerts(filters)
useRecentActivity(filters)
useCreateInward()
useCreateOutward()
useCreateDisposition()
useValidateMaterialImport()
useCommitImport()
useExportStockReport()
```

## Tailwind Styling Direction

- Use a restrained admin palette: white surfaces, slate text, zinc borders, amber for warnings, red for blocked/error states, emerald for healthy stock.
- Keep dashboard density moderate: tables should be scannable and not oversized.
- Use sticky table headers for long inventory lists.
- Use dialogs or side drawers for transaction creation, not separate full pages unless the form becomes complex.
- Use tabs or segmented controls for stock condition filters.
