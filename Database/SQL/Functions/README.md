# SmartPOS Database — Functions

Common, reusable functions live in `17_Shared/functions.sql` and are created
before any procedure or trigger that references them.

## Function Map

| Function | Purpose |
|----------|---------|
| `FN_SmartPOS_Setting` | Read a setting with a fallback default |
| `FN_StockStatus` | Classify `IN_STOCK` / `LOW_STOCK` / `OUT_OF_STOCK` |
| `FN_HasPermission` | RBAC check: does a user hold a permission code? |
| `FN_HashToken` | SHA-256 hex hash for session/reset tokens at rest |
| `FN_CalculateLineTotal` | Line total with discount rate (0..1), rounded 4dp |
| `FN_GetUserDisplayName` | Display name for a user (NULL-safe) |
| `FN_CurrencySymbol` | Configured currency symbol (default `$`) |

## Naming

- Scalar functions are prefixed `FN_`.
- No `sp_` prefix (avoids master-db resolution overhead).
- No `fn_` reserved conflicts; all are schema-qualified (`dbo.FN_...`).

See `../17_Shared/functions.sql` for implementations.