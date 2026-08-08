"""Business information, currencies and tax rate endpoints (Feature 05)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user, require_permission
from app.api.dependencies.database import get_db_session
from app.api.schemas.business import (
    BusinessInfoRead,
    BusinessInfoUpdate,
    CurrencyRead,
    TaxRateCreate,
    TaxRateRead,
    TaxRateUpdate,
)
from app.core.constants import PermissionCode
from app.models.users import User
from app.repositories.catalog_repo import CurrencyRepository
from app.services.business_service import BusinessService
from app.utils.response import success_response

router = APIRouter(prefix="/business", tags=["Business"])


@router.get("/info", response_model=dict)
def get_business_info(
    user: Annotated[User, Depends(require_permission(PermissionCode.SETTINGS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(BusinessInfoRead.model_validate(BusinessService(db).get_business_info()).model_dump())


@router.put("/info", response_model=dict)
def update_business_info(
    payload: BusinessInfoUpdate,
    user: Annotated[User, Depends(require_permission(PermissionCode.SETTINGS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        BusinessInfoRead.model_validate(
            BusinessService(db).update_business_info(payload, user)
        ).model_dump()
    )


@router.get("/currencies", response_model=dict)
def list_currencies(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    currencies = CurrencyRepository(db).list_all()
    return success_response([CurrencyRead.model_validate(c).model_dump() for c in currencies])


@router.get("/tax-rates", response_model=dict)
def list_tax_rates(
    user: Annotated[User, Depends(get_current_user)],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        [TaxRateRead.model_validate(t).model_dump() for t in BusinessService(db).list_tax_rates()]
    )


@router.post("/tax-rates", response_model=dict, status_code=status.HTTP_201_CREATED)
def create_tax_rate(
    payload: TaxRateCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.SETTINGS_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(TaxRateRead.model_validate(BusinessService(db).create_tax_rate(payload, user)).model_dump())


@router.put("/tax-rates/{tax_rate_id}", response_model=dict)
def update_tax_rate(
    tax_rate_id: int,
    payload: TaxRateUpdate,
    user: Annotated[User, Depends(require_permission(PermissionCode.SETTINGS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(
        TaxRateRead.model_validate(
            BusinessService(db).update_tax_rate(tax_rate_id, payload, user)
        ).model_dump()
    )


@router.delete("/tax-rates/{tax_rate_id}", status_code=200)
def delete_tax_rate(
    tax_rate_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.SETTINGS_DELETE))],
    db: Session = Depends(get_db_session),
) -> dict:
    BusinessService(db).delete_tax_rate(tax_rate_id, user)
    return success_response({"message": "Tax rate deleted successfully."})
