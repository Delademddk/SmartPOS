"""Business information, tax rates and application settings service (Feature 05)."""

from __future__ import annotations

from app.api.schemas.business import (
    BusinessInfoUpdate,
    TaxRateCreate,
    TaxRateUpdate,
)
from app.api.schemas.settings import SettingCreate, SettingUpdate
from app.core.constants import SettingDataType
from app.core.currency import (
    DEFAULT_CURRENCY_CODE,
    DEFAULT_CURRENCY_DECIMAL_PLACES,
    DEFAULT_CURRENCY_LOCALE,
    DEFAULT_CURRENCY_SYMBOL,
    locale_for_currency,
)
from app.exceptions import (
    BadRequestError,
    CannotDeleteInUseError,
    DuplicateResourceError,
    NotFoundError,
    ValidationError_,
)
from app.models.business import BusinessInformation, Currency, TaxRate
from app.models.settings import Setting
from app.models.users import User
from app.repositories.catalog_repo import (
    BusinessInfoRepository,
    CurrencyRepository,
    TaxRateRepository,
)
from app.repositories.system_repo import SettingRepository
from app.services.audit_service import AuditService
from app.services.base import BaseService

_JSON_SCHEMA_TYPES = {SettingDataType.STRING.value, SettingDataType.JSON.value}

_CURRENCY_SETTING_DESCRIPTIONS = {
    "currency_symbol": "Symbol displayed next to amounts across the UI and receipts",
    "currency_code": "ISO currency code used across the entire application",
    "currency_locale": "Locale used for currency formatting",
}

_CURRENCY_MIRROR_KEYS = frozenset(_CURRENCY_SETTING_DESCRIPTIONS)


def _validate_setting_value(data_type: str, value: str | None) -> None:
    if value is None:
        return
    if data_type == SettingDataType.INT.value:
        try:
            int(value)
        except ValueError as exc:
            raise ValidationError_(
                "Setting value must be an integer.",
                [{"field": "setting_value", "message": "Expected an integer"}],
            ) from exc
    elif data_type == SettingDataType.DECIMAL.value:
        try:
            float(value)
        except ValueError as exc:
            raise ValidationError_(
                "Setting value must be a decimal.",
                [{"field": "setting_value", "message": "Expected a decimal"}],
            ) from exc
    elif data_type == SettingDataType.BOOL.value:
        if value.lower() not in ("true", "false", "1", "0"):
            raise ValidationError_(
                "Setting value must be a boolean.",
                [{"field": "setting_value", "message": "Expected true or false"}],
            )


class BusinessService(BaseService):
    service_name = "business"

    def __init__(self, session) -> None:  # noqa: ANN001
        super().__init__(session)
        self.business = BusinessInfoRepository(session)
        self.taxes = TaxRateRepository(session)
        self.settings = SettingRepository(session)
        self.audit = AuditService(session)

    # ------------------------------------------------------------------
    # Business profile
    # ------------------------------------------------------------------
    def get_business_info(self) -> BusinessInformation:
        info = self.business.get_single()
        if info is None:
            raise NotFoundError("Business information has not been configured yet.")
        return info

    def update_business_info(self, payload: BusinessInfoUpdate, actor: User) -> BusinessInformation:
        info = self.business.get_single()
        if info is None:
            info = BusinessInformation(business_name="SmartPOS Store")
            self.business.add(info)
        data = payload.model_dump(exclude_unset=True)
        if "currency_code" in data and data["currency_code"]:
            data["currency_code"] = self._ensure_currency(data["currency_code"]).currency_code
        for field, value in data.items():
            if value is not None:
                setattr(info, field, value)
        info.updated_by = actor.user_id
        self._sync_display_settings(info, data, actor)
        self.audit.record(
            action_type="UPDATE",
            resource_type="Business",
            resource_id=info.business_info_id,
            user_id=actor.user_id,
            new_values=data,
        )
        self.session.commit()
        return self.business.get_single()

    def _sync_display_settings(
        self, info: BusinessInformation, data: dict, actor: User
    ) -> None:
        """Keep the display settings in sync with the business profile.

        The business profile is the canonical source for the business name and
        currency; the ``settings`` table mirrors them so the display layer
        (header, POS, receipts) consumes a single, consistent value.
        """
        if "business_name" in data and data["business_name"]:
            setting = self.settings.get_by_key("business_name")
            if setting is not None:
                setting.setting_value = data["business_name"]
                setting.updated_by = actor.user_id
        if "currency_code" in data and data["currency_code"]:
            currency = CurrencyRepository(self.session).get_by_code(data["currency_code"])
            if currency is not None:
                self._sync_currency_settings(currency, actor)

    # ------------------------------------------------------------------
    # Currency configuration
    # ------------------------------------------------------------------
    def get_currency_config(self) -> dict[str, object]:
        """Return the active application currency configuration.

        The authoritative currency is ``business_information.currency_code``.
        The symbol/decimal places come from the ``currencies`` catalogue and
        the locale from the centralized currency configuration module.
        """
        info = self.business.get_single()
        code = (info.currency_code if info else DEFAULT_CURRENCY_CODE) or DEFAULT_CURRENCY_CODE
        currency = CurrencyRepository(self.session).get_by_code(code)
        if currency is None or not currency.is_active:
            currency = CurrencyRepository(self.session).get_by_code(DEFAULT_CURRENCY_CODE)
        if currency is None:
            return {
                "currency_code": DEFAULT_CURRENCY_CODE,
                "currency_symbol": DEFAULT_CURRENCY_SYMBOL,
                "currency_locale": DEFAULT_CURRENCY_LOCALE,
                "decimal_places": DEFAULT_CURRENCY_DECIMAL_PLACES,
            }
        return {
            "currency_code": currency.currency_code,
            "currency_symbol": currency.symbol,
            "currency_locale": locale_for_currency(currency.currency_code),
            "decimal_places": currency.decimal_places,
        }

    def _ensure_currency(self, currency_code: str) -> Currency:
        """Validate a requested currency and return the active catalogue row."""
        code = currency_code.strip().upper()
        if len(code) != 3:
            raise ValidationError_(
                "Currency code must be a 3-letter ISO code.",
                [{"field": "currency_code", "message": "Expected a 3-letter ISO code"}],
            )
        currency = CurrencyRepository(self.session).get_by_code(code)
        if currency is None or not currency.is_active:
            raise ValidationError_(
                f"Unsupported currency code '{code}'.",
                [{"field": "currency_code", "message": "Currency is not supported"}],
            )
        return currency

    def _sync_currency_settings(self, currency: Currency, actor: User) -> None:
        """Mirror the canonical currency into the display ``settings`` rows."""
        rows = {
            "currency_symbol": currency.symbol,
            "currency_code": currency.currency_code,
            "currency_locale": locale_for_currency(currency.currency_code),
        }
        for key, value in rows.items():
            setting = self.settings.get_by_key(key)
            if setting is None:
                setting = Setting(
                    setting_key=key,
                    setting_value=value,
                    data_type=SettingDataType.STRING.value,
                    category="general",
                    description=_CURRENCY_SETTING_DESCRIPTIONS.get(key),
                    created_by=actor.user_id,
                    updated_by=actor.user_id,
                )
                self.settings.add(setting)
            else:
                setting.setting_value = value
                setting.updated_by = actor.user_id

    def update_currency(self, currency_code: str, actor: User) -> dict[str, object]:
        """Set the global application currency and persist it to the database."""
        currency = self._ensure_currency(currency_code)
        info = self.business.get_single()
        if info is None:
            info = BusinessInformation(
                business_name="SmartPOS Store",
                currency_code=currency.currency_code,
            )
            self.business.add(info)
        info.currency_code = currency.currency_code
        info.updated_by = actor.user_id
        self._sync_currency_settings(currency, actor)
        self.audit.activity(
            activity_type="CURRENCY_UPDATED",
            activity_desc=f"Application currency changed to {currency.currency_code}",
            entity_type="Currency",
            entity_id=currency.currency_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.get_currency_config()

    # ------------------------------------------------------------------
    # Tax rates
    # ------------------------------------------------------------------
    def list_tax_rates(self) -> list[TaxRate]:
        return self.taxes.list_all()

    def get_tax_rate(self, tax_rate_id: int) -> TaxRate:
        tax = self.taxes.get(tax_rate_id)
        if tax is None:
            raise NotFoundError("Tax rate not found.")
        return tax

    def create_tax_rate(self, payload: TaxRateCreate, actor: User) -> TaxRate:
        if self.taxes.count(self.taxes.model.tax_code == payload.tax_code) > 0:
            raise DuplicateResourceError("Tax code already exists.", resource_type="TaxRate")
        tax = TaxRate(**payload.model_dump())
        if payload.is_default:
            self._clear_default_tax()
        self.taxes.add(tax)
        self.audit.activity(
            activity_type="TAX_RATE_CREATED",
            activity_desc=f"Created tax rate {tax.tax_code}",
            entity_type="TaxRate",
            entity_id=tax.tax_rate_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.taxes.get(tax.tax_rate_id)

    def update_tax_rate(self, tax_rate_id: int, payload: TaxRateUpdate, actor: User) -> TaxRate:
        tax = self.get_tax_rate(tax_rate_id)
        data = payload.model_dump(exclude_unset=True)
        for field, value in data.items():
            if value is not None:
                setattr(tax, field, value)
        if data.get("is_default") is True:
            self._clear_default_tax()
            tax.is_default = True
        self.audit.activity(
            activity_type="TAX_RATE_UPDATED",
            activity_desc=f"Updated tax rate {tax.tax_code}",
            entity_type="TaxRate",
            entity_id=tax.tax_rate_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.taxes.get(tax.tax_rate_id)

    def delete_tax_rate(self, tax_rate_id: int, actor: User) -> None:
        tax = self.get_tax_rate(tax_rate_id)
        self.taxes.delete(tax)
        self.audit.activity(
            activity_type="TAX_RATE_DELETED",
            activity_desc=f"Deleted tax rate {tax.tax_code}",
            entity_type="TaxRate",
            entity_id=tax_rate_id,
            user_id=actor.user_id,
        )
        self.session.commit()

    def _clear_default_tax(self) -> None:
        for tax in self.taxes.list_all():
            tax.is_default = False

    # ------------------------------------------------------------------
    # Settings
    # ------------------------------------------------------------------
    def list_settings(self, category: str | None = None) -> list[Setting]:
        settings = self.settings.list_all()
        if category:
            return [s for s in settings if s.category == category]
        return settings

    def get_setting(self, key: str) -> Setting:
        setting = self.settings.get_by_key(key)
        if setting is None:
            raise NotFoundError(f"Setting '{key}' not found.")
        return setting

    def create_setting(self, payload: SettingCreate, actor: User) -> Setting:
        if payload.setting_key in _CURRENCY_MIRROR_KEYS:
            raise ValidationError_(
                f"'{payload.setting_key}' is managed by the application currency and cannot be created directly.",
                [{"field": "setting_key", "message": "Setting is managed by the application currency"}],
            )
        if self.settings.get_by_key(payload.setting_key):
            raise DuplicateResourceError("Setting key already exists.", resource_type="Setting")
        _validate_setting_value(payload.data_type, payload.setting_value)
        setting = Setting(
            setting_key=payload.setting_key,
            setting_value=payload.setting_value,
            data_type=payload.data_type,
            category=payload.category,
            description=payload.description,
            created_by=actor.user_id,
            updated_by=actor.user_id,
        )
        self.settings.add(setting)
        self.audit.activity(
            activity_type="SETTING_CREATED",
            activity_desc=f"Created setting {setting.setting_key}",
            entity_type="Setting",
            entity_id=setting.setting_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.settings.get(setting.setting_id)

    def update_setting(self, key: str, payload: SettingUpdate, actor: User) -> Setting:
        if key in _CURRENCY_MIRROR_KEYS:
            return self._update_currency_setting(key, payload, actor)
        setting = self.get_setting(key)
        data = payload.model_dump(exclude_unset=True)
        data_type = data.get("data_type") or setting.data_type
        if "setting_value" in data:
            _validate_setting_value(data_type, data["setting_value"])
            setting.setting_value = data["setting_value"]
        for field in ("data_type", "category", "description", "is_active"):
            if field in data and data[field] is not None:
                setattr(setting, field, data[field])
        setting.updated_by = actor.user_id
        self._sync_business_profile(key, data, actor)
        self.audit.activity(
            activity_type="SETTING_UPDATED",
            activity_desc=f"Updated setting {setting.setting_key}",
            entity_type="Setting",
            entity_id=setting.setting_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.settings.get(setting.setting_id)

    def _update_currency_setting(self, key: str, payload: SettingUpdate, actor: User) -> Setting:
        """Route generic edits of currency mirror settings through the canonical
        application currency flow so the single source of truth is preserved."""
        if key == "currency_code":
            value = payload.setting_value
            if value is None or not value.strip():
                raise ValidationError_(
                    "Currency code is required.",
                    [{"field": "setting_value", "message": "Expected a currency code"}],
                )
            self.update_currency(value, actor)
            return self.get_setting(key)
        raise ValidationError_(
            f"'{key}' is derived from the application currency and cannot be edited directly. "
            "Use the Currency setting instead.",
            [{"field": "setting_value", "message": "Setting is managed by the application currency"}],
        )

    def _sync_business_profile(self, key: str, data: dict, actor: User) -> None:
        """Mirror display settings edited in the Settings page back to the
        business profile so the two storage locations stay consistent."""
        if key != "business_name" or "setting_value" not in data:
            return
        info = self.business.get_single()
        if info is not None:
            info.business_name = data["setting_value"]
            info.updated_by = actor.user_id

    def delete_setting(self, key: str, actor: User) -> None:
        if key in _CURRENCY_MIRROR_KEYS:
            raise ValidationError_(
                f"'{key}' is managed by the application currency and cannot be deleted.",
                [{"field": "setting_key", "message": "Setting is managed by the application currency"}],
            )
        setting = self.get_setting(key)
        self.settings.delete(setting)
        self.audit.activity(
            activity_type="SETTING_DELETED",
            activity_desc=f"Deleted setting {setting.setting_key}",
            entity_type="Setting",
            entity_id=setting.setting_id,
            user_id=actor.user_id,
        )
        self.session.commit()
