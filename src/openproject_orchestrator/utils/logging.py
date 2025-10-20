"""
Logging utilities for OpenProject Orchestrator

Provides centralized logging configuration and utilities for all modules.
Supports both file and console logging with different levels.
"""

import logging
import sys
from pathlib import Path
from typing import Optional
from datetime import datetime


class OrchestratorLogger:
    """
    Centralized logger for the orchestrator.

    Provides:
    - File logging to workspace/logs/
    - Console logging (optional, debug mode)
    - Configurable log levels
    - Log rotation support
    """

    _instance = None
    _initialized = False

    def __new__(cls):
        """Singleton pattern to ensure one logger instance."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        """Initialize the logger (only once)."""
        if not self._initialized:
            self.loggers = {}
            self._initialized = True

    def setup_logging(
        self,
        log_dir: Optional[Path] = None,
        console_level: str = "WARNING",
        file_level: str = "INFO",
        debug: bool = False,
    ):
        """
        Setup logging configuration.

        Args:
            log_dir: Directory for log files (default: ./workspace/logs)
            console_level: Log level for console output
            file_level: Log level for file output
            debug: Enable debug mode (sets console to DEBUG)
        """
        # Set log directory
        if log_dir is None:
            log_dir = Path("./workspace/logs")

        log_dir.mkdir(parents=True, exist_ok=True)

        # Create log file with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = log_dir / f"orchestrator_{timestamp}.log"

        # Determine console level
        if debug:
            console_level = "DEBUG"

        # Configure root logger
        root_logger = logging.getLogger("openproject_orchestrator")
        root_logger.setLevel(logging.DEBUG)  # Capture everything

        # Remove existing handlers
        root_logger.handlers.clear()

        # File handler
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(getattr(logging, file_level.upper()))
        file_formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        file_handler.setFormatter(file_formatter)
        root_logger.addHandler(file_handler)

        # Console handler (only if debug or explicitly requested)
        if debug or console_level != "CRITICAL":
            console_handler = logging.StreamHandler(sys.stderr)
            console_handler.setLevel(getattr(logging, console_level.upper()))
            console_formatter = logging.Formatter(
                "%(levelname)s - %(name)s - %(message)s"
            )
            console_handler.setFormatter(console_formatter)
            root_logger.addHandler(console_handler)

        root_logger.info(f"Logging initialized - File: {log_file}")
        root_logger.info(f"Console level: {console_level}, File level: {file_level}")

        self.log_file = log_file

    def get_logger(self, name: str) -> logging.Logger:
        """
        Get a logger for a specific module.

        Args:
            name: Logger name (typically __name__)

        Returns:
            Logger instance
        """
        if name not in self.loggers:
            # Create logger under openproject_orchestrator namespace
            logger_name = f"openproject_orchestrator.{name}"
            self.loggers[name] = logging.getLogger(logger_name)

        return self.loggers[name]

    def get_log_file(self) -> Optional[Path]:
        """Get the current log file path."""
        return getattr(self, "log_file", None)


# Global instance
_logger_instance = OrchestratorLogger()


def setup_logging(
    log_dir: Optional[Path] = None,
    console_level: str = "WARNING",
    file_level: str = "INFO",
    debug: bool = False,
):
    """
    Setup logging for the orchestrator.

    This should be called once at application startup.

    Args:
        log_dir: Directory for log files
        console_level: Log level for console output
        file_level: Log level for file output
        debug: Enable debug mode
    """
    _logger_instance.setup_logging(
        log_dir=log_dir, console_level=console_level, file_level=file_level, debug=debug
    )


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance.

    Args:
        name: Logger name (typically __name__)

    Returns:
        Logger instance
    """
    return _logger_instance.get_logger(name)


def get_log_file() -> Optional[Path]:
    """Get the current log file path."""
    return _logger_instance.get_log_file()
