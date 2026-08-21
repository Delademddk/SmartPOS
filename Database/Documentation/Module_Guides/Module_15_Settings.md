# Module 15 — Settings

**SQL source:** `Database/SQL/15_Settings/`
**Purpose:** Key-value application and user configuration.

## Tables

| Table | Purpose |
|-------|---------|
| `settings` | System config: unique `setting_key`; `data_type` in `string`/`int`/`decimal`/`bool`/`json`; `category` grouping. |
| `user_settings` | Per-user preferences; unique on `(user_id, setting_key)`. |

## Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `SP_GetSettings` | List settings (optionally by category). |
| `SP_GetSetting` | Fetch one setting by key. |
| `SP_UpsertSetting` | Insert or update a system setting (typed cast by `data_type`). |
| `SP_DeleteSetting` | Remove a setting. |
| `SP_GetUserSettings` | List a user's preferences. |
| `SP_UpsertUserSetting` | Insert or update a user preference. |

## Dependencies

- Module 02 (`users`).
- `FN_SmartPOS_Setting` (Module 17) reads settings with a fallback default across the schema.
- `TRG_settings_audit` writes `audit_logs`.

## Notes

- `schema_version` is stored here for deployment tracking (see [`DeploymentGuide.md`](../DeploymentGuide.md) §5.3).
- `data_type` drives coercion — a `decimal` setting rejects non-numeric input at the procedure boundary.
