"""Custom domain exceptions and the HTTP exception mapper.

Business rules raise domain exceptions (e.g. ``InsufficientStockError``);
a global handler translates them into the standard error envelope with the
correct HTTP status code.
"""

from __future__ import annotations

from typing import Any


class SmartPOSError(Exception):
    """Base class for all domain errors."""

    status_code = 400
    code = "ERROR"

    def __init__(
        self,
        message: str,
        details: list[dict[str, Any]] | None = None,
        *,
        resource_type: str | None = None,
        resource_id: int | str | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.details = details or []
        self.resource_type = resource_type
        self.resource_id = resource_id


class NotFoundError(SmartPOSError):
    status_code = 404
    code = "NOT_FOUND"


class ConflictError(SmartPOSError):
    status_code = 409
    code = "CONFLICT"


class UnauthorizedError(SmartPOSError):
    status_code = 401
    code = "UNAUTHORIZED"


class ForbiddenError(SmartPOSError):
    status_code = 403
    code = "FORBIDDEN"


class ValidationError_(SmartPOSError):
    status_code = 422
    code = "VALIDATION_ERROR"


class BadRequestError(SmartPOSError):
    status_code = 400
    code = "BAD_REQUEST"


# ---------------------------------------------------------------------------
# Domain-specific exceptions
# ---------------------------------------------------------------------------


class InvalidCredentialsError(UnauthorizedError):
    code = "INVALID_CREDENTIALS"


class AccountDisabledError(UnauthorizedError):
    code = "ACCOUNT_DISABLED"


class AccountLockedError(SmartPOSError):
    status_code = 423
    code = "ACCOUNT_LOCKED"


class TokenExpiredError(UnauthorizedError):
    code = "TOKEN_EXPIRED"


class TokenInvalidError(UnauthorizedError):
    code = "TOKEN_INVALID"


class PermissionDeniedError(ForbiddenError):
    code = "PERMISSION_DENIED"


class RoleRequiredError(ForbiddenError):
    code = "ROLE_REQUIRED"


class DuplicateResourceError(ConflictError):
    code = "DUPLICATE_RESOURCE"


class InsufficientStockError(ConflictError):
    code = "INSUFFICIENT_STOCK"


class ProductArchivedError(ConflictError):
    code = "PRODUCT_ARCHIVED"


class CannotDeleteInUseError(ConflictError):
    code = "RESOURCE_IN_USE"


class InvalidOperationError(BadRequestError):
    code = "INVALID_OPERATION"


class PasswordPolicyError(ValidationError_):
    code = "PASSWORD_POLICY"


class SessionRevokedError(UnauthorizedError):
    code = "SESSION_REVOKED"


class SaleAlreadySettledError(ConflictError):
    code = "SALE_ALREADY_SETTLED"


class ReturnLimitExceededError(ConflictError):
    code = "RETURN_LIMIT_EXCEEDED"


class ImageValidationError(BadRequestError):
    code = "INVALID_IMAGE"
