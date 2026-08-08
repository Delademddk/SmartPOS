"""Generic repository base providing common persistence operations.

Repositories only perform data access - no business rules live here.
"""

from __future__ import annotations

from typing import Any, Generic, TypeVar

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.database.base import Base

ModelT = TypeVar("ModelT", bound=Base)


class BaseRepository(Generic[ModelT]):
    model: type[ModelT]

    def __init__(self, session: Session) -> None:
        self.session = session

    def get(self, pk: int) -> ModelT | None:
        return self.session.get(self.model, pk)

    def get_or_404(self, pk: int) -> ModelT:
        from app.exceptions import NotFoundError

        obj = self.get(pk)
        if obj is None:
            raise NotFoundError(
                f"{self.model.__name__} with id {pk} was not found.",
                resource_type=self.model.__name__,
                resource_id=pk,
            )
        return obj

    def list_all(self) -> list[ModelT]:
        stmt = select(self.model).order_by(self.model.__table__.primary_key.columns[0])
        return list(self.session.scalars(stmt).all())

    def add(self, obj: ModelT) -> ModelT:
        self.session.add(obj)
        return obj

    def delete(self, obj: ModelT) -> None:
        self.session.delete(obj)

    def flush(self) -> None:
        self.session.flush()

    def commit(self) -> None:
        self.session.commit()

    def count(self, *filters: Any) -> int:
        stmt = select(func.count()).select_from(self.model)
        if filters:
            stmt = stmt.where(*filters)
        return int(self.session.scalar(stmt) or 0)
