"""Product endpoints (Feature 07)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request, status
from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError as PydanticValidationError
from sqlalchemy.orm import Session
from starlette.datastructures import UploadFile

from app.api.dependencies.auth import require_permission
from app.api.dependencies.database import get_db_session, get_pagination
from app.api.schemas.products import (
    PriceUpdate,
    ProductCreate,
    ProductImageCreate,
    ProductImageRead,
    ProductRead,
    ProductUpdate,
)
from app.core.constants import PermissionCode
from app.exceptions import ValidationError_
from app.models.users import User
from app.repositories.catalog_repo import ProductImageRepository
from app.services.products_service import ProductService
from app.utils.pagination import PageParams
from app.utils.response import pagination_meta, success_response

router = APIRouter(prefix="/products", tags=["Products"])


def _parse_schema_payload(schema: type[ProductCreate] | type[ProductUpdate], raw: bytes | str) -> ProductCreate | ProductUpdate:
    """Validate a product payload, translating pydantic errors into HTTP 422."""
    try:
        return schema.model_validate_json(raw)
    except PydanticValidationError as exc:
        raise RequestValidationError(exc.errors()) from exc


async def _parse_product_request(
    request: Request,
    schema: type[ProductCreate] | type[ProductUpdate],
) -> tuple[ProductCreate | ProductUpdate, UploadFile | None, bool]:
    """Parse a product create/update request body.

    Two content types are supported on the same endpoint:

    * ``application/json`` - the existing JSON contract (``image_url`` string
      may be set directly; no file upload).
    * ``multipart/form-data`` - a ``data`` field containing the JSON payload
      plus an optional ``image`` file and an optional ``remove_image`` flag.

    This keeps existing JSON consumers working while allowing image uploads.
    """
    content_type = (request.headers.get("content-type") or "").lower()
    if content_type.startswith("multipart/form-data") or content_type.startswith(
        "application/x-www-form-urlencoded"
    ):
        form = await request.form()
        data_value = form.get("data")
        if data_value is None or str(data_value).strip() == "":
            raise ValidationError_(
                "Multipart product requests must include a 'data' field containing the JSON payload.",
                [{"field": "data", "message": "Missing JSON payload."}],
            )
        payload = _parse_schema_payload(schema, str(data_value))
        image_part = form.get("image")
        image = image_part if isinstance(image_part, UploadFile) and image_part.filename else None
        remove_image = str(form.get("remove_image") or "").strip().lower() in {
            "1",
            "true",
            "yes",
            "on",
        }
        return payload, image, remove_image

    body = await request.body()
    if not body or not body.strip():
        raise ValidationError_(
            "Request body is required.",
            [{"field": "body", "message": "Empty request body."}],
        )
    payload = _parse_schema_payload(schema, body)
    return payload, None, False


@router.get("", response_model=dict)
def list_products(
    user: Annotated[User, Depends(require_permission(PermissionCode.PRODUCTS_VIEW))],
    db: Session = Depends(get_db_session),
    page: PageParams = Depends(get_pagination),
    search: str | None = Query(default=None),
    category_id: int | None = Query(default=None),
    supplier_id: int | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    min_price: float | None = Query(default=None),
    max_price: float | None = Query(default=None),
    stock_status: str | None = Query(default=None),
) -> dict:
    rows, total = ProductService(db).list(
        page,
        search,
        category_id,
        supplier_id,
        is_active,
        min_price,
        max_price,
        stock_status,
    )
    return success_response(
        [ProductRead.model_validate(p).model_dump() for p in rows],
        meta=pagination_meta(page.page, page.page_size, total),
    )


@router.post("", response_model=dict, status_code=status.HTTP_201_CREATED)
async def create_product(
    request: Request,
    user: Annotated[User, Depends(require_permission(PermissionCode.PRODUCTS_CREATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    payload, image, _ = await _parse_product_request(request, ProductCreate)
    product = ProductService(db).create(payload, user, image=image)
    return success_response(ProductRead.model_validate(product).model_dump())


@router.get("/by-sku/{sku}", response_model=dict)
def get_product_by_sku(
    sku: str,
    user: Annotated[User, Depends(require_permission(PermissionCode.PRODUCTS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(ProductRead.model_validate(ProductService(db).get_by_sku(sku)).model_dump())


@router.get("/{product_id}", response_model=dict)
def get_product(
    product_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.PRODUCTS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(ProductRead.model_validate(ProductService(db).get(product_id)).model_dump())


@router.put("/{product_id}", response_model=dict)
async def update_product(
    product_id: int,
    request: Request,
    user: Annotated[User, Depends(require_permission(PermissionCode.PRODUCTS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    payload, image, remove_image = await _parse_product_request(request, ProductUpdate)
    product = ProductService(db).update(
        product_id,
        payload,
        user,
        image=image,
        remove_image=remove_image,
    )
    return success_response(ProductRead.model_validate(product).model_dump())


@router.put("/{product_id}/price", response_model=dict)
def update_product_price(
    product_id: int,
    payload: PriceUpdate,
    user: Annotated[User, Depends(require_permission(PermissionCode.PRODUCTS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(ProductRead.model_validate(ProductService(db).update_price(product_id, payload, user)).model_dump())


@router.post("/{product_id}/archive", response_model=dict)
def archive_product(
    product_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.PRODUCTS_DELETE))],
    db: Session = Depends(get_db_session),
) -> dict:
    return success_response(ProductRead.model_validate(ProductService(db).archive(product_id, user)).model_dump())


@router.delete("/{product_id}", status_code=200)
def delete_product(
    product_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.PRODUCTS_DELETE))],
    db: Session = Depends(get_db_session),
) -> dict:
    ProductService(db).delete(product_id, user)
    return success_response({"message": "Product archived successfully."})


@router.get("/{product_id}/images", response_model=dict)
def list_product_images(
    product_id: int,
    user: Annotated[User, Depends(require_permission(PermissionCode.PRODUCTS_VIEW))],
    db: Session = Depends(get_db_session),
) -> dict:
    images = ProductImageRepository(db).list_for_product(product_id)
    return success_response([ProductImageRead.model_validate(i).model_dump() for i in images])


@router.post(
    "/{product_id}/images",
    response_model=dict,
    status_code=status.HTTP_201_CREATED,
)
def add_product_image(
    product_id: int,
    payload: ProductImageCreate,
    user: Annotated[User, Depends(require_permission(PermissionCode.PRODUCTS_UPDATE))],
    db: Session = Depends(get_db_session),
) -> dict:
    from app.models.catalog import ProductImage

    ProductService(db).get(product_id)
    image = ProductImage(product_id=product_id, **payload.model_dump())
    repo = ProductImageRepository(db)
    repo.add(image)
    db.commit()
    return success_response(ProductImageRead.model_validate(db.get(ProductImage, image.image_id)).model_dump())
