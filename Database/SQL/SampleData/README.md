# SmartPOS Database — Sample Data

Optional, illustrative data for development and testing. **Not required at
runtime** — skip in production.

**File:** `SampleData/SampleData.sql`

| Table | Rows | Notes |
|-------|------|-------|
| `categories` | +3 | Soft Drinks, Snacks, Peripherals (children) |
| `products` | 15 | Realistic SKUs (BEV-001..CLN-001), prices, costs, thresholds |
| `inventory` | 15 | quantity_on_hand per product |
| `supplier_contacts` | 4 | |
| `customers` | 3 | CUST-001..003 with credit limits |
| `sales` | 3 | via `SP_CreateSale` (CASH, CARD, CREDIT) |
| `returns` | 1 | via `SP_ProcessReturn` |
| `settings` | +2 | overrides |
| `notifications` | 3 | |
| audit/activity/security/error logs | 10 | sample entries |

## Why sales/returns go through stored procedures

`SP_CreateSale` and `SP_ProcessReturn` are used instead of raw `INSERT`s so the
sample data keeps inventory, `sale_items`, `inventory_transactions`, and credit
balances perfectly consistent — no orphaned or contradictory rows.

## Running

Sample data is applied automatically when the setup scripts run with
`RUN_SAMPLE_DATA=true` (see `Configuration/database.env`). In production,
leave it off.