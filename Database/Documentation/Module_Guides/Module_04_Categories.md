# Module 04 — Categories

**SQL source:** `Database/SQL/04_Categories/`
**Purpose:** Hierarchical product categories.

## Tables

| Table | Purpose |
|-------|---------|
| `categories` | Self-referencing hierarchy: `parent_id` → `categories.category_id`. Name unique within the same parent. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_GetCategories` | List all categories. |
| `SP_GetCategoryTree` | Return the hierarchy as a tree/JSON structure. |
| `SP_CreateCategory` | Insert a category (validates parent exists). |
| `SP_UpdateCategory` | Update name/parent; **rejects** cycles (cannot become own ancestor). |
| `SP_DeleteCategory` | Soft-delete; refuses when the category still has children. |
| `SP_GetCategory` | Fetch one category. |

## Dependencies

- Module 05 (`products.category_id`).
- `TRG_categories_audit` writes `audit_logs` on INSERT/UPDATE/DELETE.

## Notes

- `is_deleted` soft-delete keeps historical products valid.
- Cycle protection lives in `SP_UpdateCategory` (walk up ancestors).
