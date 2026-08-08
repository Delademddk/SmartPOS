"""Structured logging setup using structlog.

Logs are emitted as JSON lines to both the console and a rotating file in the
configured log directory.
"""

from __future__ import annotations

import logging
import sys
from logging.handlers import TimedRotatingFileHandler
from pathlib import Path

import structlog

from app.core.config import get_settings

_RENDERER = structlog.processors.JSONRenderer()


def _configure_stdlib(level: int, log_file: Path) -> None:
    root = logging.getLogger()
    root.setLevel(level)

    formatter = logging.Formatter(
        "%(asctime)s %(levelname)s %(name)s %(message)s"
    )

    stream_handler = logging.StreamHandler(sys.stdout)
    stream_handler.setFormatter(formatter)
    root.addHandler(stream_handler)

    log_file.parent.mkdir(parents=True, exist_ok=True)
    file_handler = TimedRotatingFileHandler(
        log_file, when="midnight", backupCount=14, encoding="utf-8"
    )
    file_handler.setFormatter(formatter)
    root.addHandler(file_handler)


def setup_logging() -> structlog.stdlib.BoundLogger:
    """Configure structlog and stdlib logging, returning the root logger."""
    settings = get_settings()
    level = getattr(logging, settings.log_level.upper(), logging.INFO)
    log_file = Path(settings.log_dir) / "smartpos.log"
    _configure_stdlib(level, log_file)

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            _RENDERER,
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    return structlog.get_logger()


def get_logger(name: str = "smartpos") -> structlog.stdlib.BoundLogger:
    """Return a bound structlog logger for the given module name."""
    return structlog.get_logger(name)
