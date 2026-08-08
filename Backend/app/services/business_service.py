"""Business information, tax rates and application settings service (Feature 05)."""

from __future__ import annotations

from app.api.schemas.business import (
    BusinessInfoUpdate,
    TaxRateCreate,
    TaxRateUpdate,
)
from app.api.schemas.settings import SettingCreate, SettingUpdate
from app.core.constants import SettingDataType
from app.exceptions import (
    BadRequestError,
    CannotDeleteInUseError,
    DuplicateResourceError,
    NotFoundError,
    ValidationError_,
)
from app.models.business import BusinessInformation, TaxRate
from app.models.settings import Setting
from app.models.users import User
from app.repositories.catalog_repo import BusinessInfoRepository, TaxRateRepository
from app.repositories.system_repo import SettingRepository
from app.services.audit_service import AuditService
from app.services.base import BaseService

_JSON_SCHEMA_TYPES = {SettingDataType.STRING.value, SettingDataType.JSON.value}


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
        for field, value in data.items():
            if value is not None:
                setattr(info, field, value)
        info.updated_by = actor.user_id
        self.audit.record(
            action_type="UPDATE",
            resource_type="Business",
            resource_id=info.business_info_id,
            user_id=actor.user_id,
            new_values=data,
        )
        self.session.commit()
        return self.business.get_single()

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
        self.audit.activity(
            activity_type="SETTING_UPDATED",
            activity_desc=f"Updated setting {setting.setting_key}",
            entity_type="Setting",
            entity_id=setting.setting_id,
            user_id=actor.user_id,
        )
        self.session.commit()
        return self.settings.get(setting.setting_id)

    def delete_setting(self, key: str, actor: User) -> None:
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
