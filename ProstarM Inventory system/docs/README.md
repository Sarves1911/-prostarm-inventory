# ProstarM Inventory Architecture Pack

Generated first-pass architecture artifacts for the ProstarM Info System Ltd. Inventory Management System.

Files:

- `database/schema.sql`: PostgreSQL schema with RBAC, material master, branch-wise stock balances, stock transactions, disposition ledgers, Excel imports, reports view, and stock mutation triggers.
- `database/erd.md`: Mermaid ERD and relationship rules.
- `backend/api-roadmap.md`: Backend endpoint roadmap for auth, master data, inward/outward stock, dispositions, Excel import/export, backups, and reports.
- `frontend/dashboard-wireframe.md`: Main dashboard wireframe, component tree, UI behavior, and route/component plan.

Implementation recommendation:

- Backend: Node.js, Express, TypeScript, PostgreSQL.
- Frontend: Next.js or React with Tailwind CSS.
- Database: PostgreSQL.
