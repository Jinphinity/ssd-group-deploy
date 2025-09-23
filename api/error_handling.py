"""
Comprehensive Error Handling and Structured Logging for Dizzy's Disease API
Academic Compliance - §14 Error Handling & Logging
"""

import json
import time
import uuid
import logging
from datetime import datetime
from typing import Dict, Any, Optional
from fastapi import Request, Response, HTTPException
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
import asyncpg


class StructuredLogger:
    """Structured JSON logger with correlation ID support"""

    def __init__(self, component: str = "API"):
        self.component = component
        self.logger = logging.getLogger(component)

    def log_event(self, event_type: str, data: Dict[str, Any],
                 level: str = "INFO", correlation_id: str = None) -> None:
        """Log structured event with correlation ID and timestamp"""

        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "unix_time": time.time(),
            "level": level,
            "event_type": event_type,
            "component": self.component,
            "correlation_id": correlation_id or str(uuid.uuid4()),
            "data": data
        }

        # Log to structured format
        log_message = json.dumps(log_entry)

        if level == "ERROR":
            self.logger.error(log_message)
        elif level == "WARNING":
            self.logger.warning(log_message)
        elif level == "INFO":
            self.logger.info(log_message)
        else:
            self.logger.debug(log_message)


class ErrorHandlingMiddleware(BaseHTTPMiddleware):
    """Comprehensive error handling middleware with structured logging"""

    def __init__(self, app, logger: StructuredLogger):
        super().__init__(app)
        self.logger = logger

    async def dispatch(self, request: Request, call_next):
        # Generate correlation ID for request tracking
        correlation_id = str(uuid.uuid4())
        request.state.correlation_id = correlation_id

        # Log request start
        start_time = time.time()
        self.logger.log_event("request_started", {
            "method": request.method,
            "url": str(request.url),
            "client_ip": request.client.host if request.client else "unknown",
            "user_agent": request.headers.get("user-agent", "unknown")
        }, correlation_id=correlation_id)

        try:
            response = await call_next(request)

            # Log successful request
            duration = time.time() - start_time
            self.logger.log_event("request_completed", {
                "status_code": response.status_code,
                "duration_ms": round(duration * 1000, 2),
                "method": request.method,
                "url": str(request.url)
            }, correlation_id=correlation_id)

            # Add correlation ID to response headers
            response.headers["X-Correlation-ID"] = correlation_id
            return response

        except HTTPException as e:
            # Log HTTP exceptions
            duration = time.time() - start_time
            self.logger.log_event("request_http_error", {
                "status_code": e.status_code,
                "detail": e.detail,
                "duration_ms": round(duration * 1000, 2),
                "method": request.method,
                "url": str(request.url)
            }, level="WARNING", correlation_id=correlation_id)

            return create_error_response(
                status_code=e.status_code,
                error_code=f"HTTP_{e.status_code}",
                message=e.detail,
                correlation_id=correlation_id
            )

        except Exception as e:
            # Log unexpected errors
            duration = time.time() - start_time
            self.logger.log_event("request_internal_error", {
                "error_type": type(e).__name__,
                "error_message": str(e),
                "duration_ms": round(duration * 1000, 2),
                "method": request.method,
                "url": str(request.url)
            }, level="ERROR", correlation_id=correlation_id)

            return create_error_response(
                status_code=500,
                error_code="INTERNAL_SERVER_ERROR",
                message="An unexpected error occurred",
                correlation_id=correlation_id,
                details={"error_type": type(e).__name__}
            )


def create_error_response(status_code: int, error_code: str, message: str,
                         correlation_id: str, details: Dict[str, Any] = None) -> JSONResponse:
    """Create standardized error response with proper structure"""

    error_payload = {
        "error": {
            "code": error_code,
            "message": message,
            "correlation_id": correlation_id,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
    }

    if details:
        error_payload["error"]["details"] = details

    return JSONResponse(
        status_code=status_code,
        content=error_payload,
        headers={"X-Correlation-ID": correlation_id}
    )


class DatabaseErrorHandler:
    """Handle database-specific errors with proper categorization"""

    def __init__(self, logger: StructuredLogger):
        self.logger = logger

    def handle_database_error(self, error: Exception, correlation_id: str,
                            operation: str) -> HTTPException:
        """Convert database errors to appropriate HTTP exceptions"""

        if isinstance(error, asyncpg.UniqueViolationError):
            self.logger.log_event("database_constraint_violation", {
                "constraint_type": "unique",
                "operation": operation,
                "error_message": str(error)
            }, level="WARNING", correlation_id=correlation_id)

            return HTTPException(
                status_code=409,
                detail="Resource already exists"
            )

        elif isinstance(error, asyncpg.ForeignKeyViolationError):
            self.logger.log_event("database_constraint_violation", {
                "constraint_type": "foreign_key",
                "operation": operation,
                "error_message": str(error)
            }, level="WARNING", correlation_id=correlation_id)

            return HTTPException(
                status_code=400,
                detail="Invalid reference to related resource"
            )

        elif isinstance(error, asyncpg.CheckViolationError):
            self.logger.log_event("database_constraint_violation", {
                "constraint_type": "check",
                "operation": operation,
                "error_message": str(error)
            }, level="WARNING", correlation_id=correlation_id)

            return HTTPException(
                status_code=400,
                detail="Data violates business rules"
            )

        elif isinstance(error, asyncpg.ConnectionDoesNotExistError):
            self.logger.log_event("database_connection_error", {
                "error_type": "connection_lost",
                "operation": operation,
                "error_message": str(error)
            }, level="ERROR", correlation_id=correlation_id)

            return HTTPException(
                status_code=503,
                detail="Database temporarily unavailable"
            )

        else:
            self.logger.log_event("database_unexpected_error", {
                "error_type": type(error).__name__,
                "operation": operation,
                "error_message": str(error)
            }, level="ERROR", correlation_id=correlation_id)

            return HTTPException(
                status_code=500,
                detail="Database operation failed"
            )


class SecurityLogger:
    """Security-specific event logging"""

    def __init__(self, logger: StructuredLogger):
        self.logger = logger

    def log_authentication_event(self, event_type: str, user_id: Optional[int],
                                email: str, success: bool, correlation_id: str,
                                client_ip: str = "unknown", details: Dict[str, Any] = None):
        """Log authentication events for security monitoring"""

        event_data = {
            "user_id": user_id,
            "email": email,
            "success": success,
            "client_ip": client_ip
        }

        if details:
            event_data.update(details)

        level = "INFO" if success else "WARNING"
        self.logger.log_event(f"auth_{event_type}", event_data,
                            level=level, correlation_id=correlation_id)

    def log_authorization_event(self, resource: str, action: str, user_id: int,
                              allowed: bool, correlation_id: str, details: Dict[str, Any] = None):
        """Log authorization decisions for audit trail"""

        event_data = {
            "resource": resource,
            "action": action,
            "user_id": user_id,
            "allowed": allowed
        }

        if details:
            event_data.update(details)

        level = "INFO" if allowed else "WARNING"
        self.logger.log_event("authorization_check", event_data,
                            level=level, correlation_id=correlation_id)

    def log_security_violation(self, violation_type: str, user_id: Optional[int],
                             correlation_id: str, details: Dict[str, Any]):
        """Log security violations for investigation"""

        event_data = {
            "violation_type": violation_type,
            "user_id": user_id
        }
        event_data.update(details)

        self.logger.log_event("security_violation", event_data,
                            level="ERROR", correlation_id=correlation_id)


class InputValidator:
    """Comprehensive input validation with business rules"""

    def __init__(self, logger: StructuredLogger):
        self.logger = logger

    def validate_registration_data(self, data: Dict[str, Any], correlation_id: str) -> Dict[str, str]:
        """Validate user registration data with business rules"""
        errors = {}

        # Email validation
        email = data.get("email", "").strip().lower()
        if not email:
            errors["email"] = "Email is required"
        elif "@" not in email or "." not in email.split("@")[-1]:
            errors["email"] = "Invalid email format"
        elif len(email) > 254:
            errors["email"] = "Email too long"

        # Password validation
        password = data.get("password", "")
        if not password:
            errors["password"] = "Password is required"
        elif len(password) < 8:
            errors["password"] = "Password must be at least 8 characters"
        elif len(password) > 128:
            errors["password"] = "Password too long"
        elif not any(c.isupper() for c in password):
            errors["password"] = "Password must contain uppercase letter"
        elif not any(c.islower() for c in password):
            errors["password"] = "Password must contain lowercase letter"
        elif not any(c.isdigit() for c in password):
            errors["password"] = "Password must contain number"

        # Display name validation
        display_name = data.get("display_name", "").strip()
        if not display_name:
            errors["display_name"] = "Display name is required"
        elif len(display_name) > 50:
            errors["display_name"] = "Display name too long"
        elif any(c in display_name for c in "<>\"'&"):
            errors["display_name"] = "Display name contains invalid characters"

        if errors:
            self.logger.log_event("validation_failed", {
                "validation_type": "registration",
                "errors": list(errors.keys()),
                "error_count": len(errors)
            }, level="WARNING", correlation_id=correlation_id)

        return errors

    def validate_market_transaction(self, data: Dict[str, Any], correlation_id: str) -> Dict[str, str]:
        """Validate market transaction data"""
        errors = {}

        # Quantity validation
        quantity = data.get("quantity")
        if quantity is None:
            errors["quantity"] = "Quantity is required"
        elif not isinstance(quantity, int):
            errors["quantity"] = "Quantity must be an integer"
        elif quantity <= 0:
            errors["quantity"] = "Quantity must be positive"
        elif quantity > 10000:
            errors["quantity"] = "Quantity too large"

        # Item ID validation
        item_id = data.get("item_id")
        if item_id is None:
            errors["item_id"] = "Item ID is required"
        elif not isinstance(item_id, int):
            errors["item_id"] = "Item ID must be an integer"
        elif item_id <= 0:
            errors["item_id"] = "Item ID must be positive"

        # Settlement ID validation
        settlement_id = data.get("settlement_id")
        if settlement_id is None:
            errors["settlement_id"] = "Settlement ID is required"
        elif not isinstance(settlement_id, int):
            errors["settlement_id"] = "Settlement ID must be an integer"
        elif settlement_id <= 0:
            errors["settlement_id"] = "Settlement ID must be positive"

        if errors:
            self.logger.log_event("validation_failed", {
                "validation_type": "market_transaction",
                "errors": list(errors.keys()),
                "error_count": len(errors)
            }, level="WARNING", correlation_id=correlation_id)

        return errors

    def validate_performance_report(self, data: Dict[str, Any], correlation_id: str) -> Dict[str, str]:
        """Validate performance report data"""
        errors = {}

        # Timestamp validation
        timestamp = data.get("timestamp")
        if timestamp is None:
            errors["timestamp"] = "Timestamp is required"
        elif not isinstance(timestamp, (int, float)):
            errors["timestamp"] = "Timestamp must be a number"
        elif timestamp <= 0:
            errors["timestamp"] = "Timestamp must be positive"

        # Duration validation
        duration = data.get("duration_seconds")
        if duration is None:
            errors["duration_seconds"] = "Duration is required"
        elif not isinstance(duration, (int, float)):
            errors["duration_seconds"] = "Duration must be a number"
        elif duration <= 0 or duration > 86400:  # Max 24 hours
            errors["duration_seconds"] = "Duration must be between 0 and 86400 seconds"

        # FPS validation
        fps = data.get("fps", {})
        if not isinstance(fps, dict):
            errors["fps"] = "FPS data must be an object"
        else:
            avg_fps = fps.get("average", 0)
            if not isinstance(avg_fps, (int, float)) or avg_fps < 0 or avg_fps > 1000:
                errors["fps.average"] = "Average FPS must be between 0 and 1000"

        # Memory validation
        memory = data.get("memory", {})
        if not isinstance(memory, dict):
            errors["memory"] = "Memory data must be an object"
        else:
            avg_memory = memory.get("average_mb", 0)
            if not isinstance(avg_memory, (int, float)) or avg_memory < 0 or avg_memory > 32768:  # Max 32GB
                errors["memory.average_mb"] = "Average memory must be between 0 and 32768 MB"

        # Platform validation
        platform = data.get("platform", "")
        if not platform or not isinstance(platform, str):
            errors["platform"] = "Platform is required and must be a string"
        elif len(platform) > 50:
            errors["platform"] = "Platform name too long"

        # Renderer validation
        renderer = data.get("renderer", "")
        if not renderer or not isinstance(renderer, str):
            errors["renderer"] = "Renderer is required and must be a string"
        elif len(renderer) > 100:
            errors["renderer"] = "Renderer name too long"

        if errors:
            self.logger.log_event("validation_failed", {
                "validation_type": "performance_report",
                "errors": list(errors.keys()),
                "error_count": len(errors)
            }, level="WARNING", correlation_id=correlation_id)

        return errors

    def validate_market_event(self, data: Dict[str, Any], correlation_id: str) -> Dict[str, str]:
        """Validate market event data"""
        errors = {}

        # Event type validation
        event_type = data.get("event_type", "")
        if not event_type:
            errors["event_type"] = "Event type is required"
        elif not isinstance(event_type, str):
            errors["event_type"] = "Event type must be a string"
        elif len(event_type) > 50:
            errors["event_type"] = "Event type too long"
        elif event_type not in ["price_update", "supply_change", "demand_shift", "market_crash", "boom"]:
            errors["event_type"] = "Invalid event type"

        # Settlement ID validation
        settlement_id = data.get("settlement_id")
        if settlement_id is None:
            errors["settlement_id"] = "Settlement ID is required"
        elif not isinstance(settlement_id, int):
            errors["settlement_id"] = "Settlement ID must be an integer"
        elif settlement_id <= 0:
            errors["settlement_id"] = "Settlement ID must be positive"

        # Price changes validation
        price_changes = data.get("price_changes", {})
        if not isinstance(price_changes, dict):
            errors["price_changes"] = "Price changes must be an object"
        elif len(price_changes) == 0:
            errors["price_changes"] = "Price changes cannot be empty"
        else:
            for item_name, price_data in price_changes.items():
                if not isinstance(item_name, str) or len(item_name) == 0:
                    errors[f"price_changes.{item_name}"] = "Item name must be a non-empty string"
                elif len(item_name) > 100:
                    errors[f"price_changes.{item_name}"] = "Item name too long"

                if not isinstance(price_data, dict):
                    errors[f"price_changes.{item_name}"] = "Price data must be an object"
                else:
                    new_price = price_data.get("new")
                    if new_price is None:
                        errors[f"price_changes.{item_name}.new"] = "New price is required"
                    elif not isinstance(new_price, (int, float)):
                        errors[f"price_changes.{item_name}.new"] = "New price must be a number"
                    elif new_price <= 0 or new_price > 1000000:
                        errors[f"price_changes.{item_name}.new"] = "New price must be between 0 and 1,000,000"

        # Timestamp validation
        timestamp = data.get("timestamp")
        if timestamp is None:
            errors["timestamp"] = "Timestamp is required"
        elif not isinstance(timestamp, (int, float)):
            errors["timestamp"] = "Timestamp must be a number"
        elif timestamp <= 0:
            errors["timestamp"] = "Timestamp must be positive"

        if errors:
            self.logger.log_event("validation_failed", {
                "validation_type": "market_event",
                "errors": list(errors.keys()),
                "error_count": len(errors),
                "event_type": event_type
            }, level="WARNING", correlation_id=correlation_id)

        return errors


# Global instances for use across the application
structured_logger = StructuredLogger("API")
db_error_handler = DatabaseErrorHandler(structured_logger)
security_logger = SecurityLogger(structured_logger)
input_validator = InputValidator(structured_logger)


def get_correlation_id(request: Request) -> str:
    """Get correlation ID from request state"""
    return getattr(request.state, "correlation_id", str(uuid.uuid4()))


# Custom exception handlers
async def validation_exception_handler(request: Request, exc: ValueError):
    """Handle validation errors with proper structure"""
    correlation_id = get_correlation_id(request)

    structured_logger.log_event("validation_error", {
        "error_message": str(exc),
        "url": str(request.url),
        "method": request.method
    }, level="WARNING", correlation_id=correlation_id)

    return create_error_response(
        status_code=422,
        error_code="VALIDATION_ERROR",
        message=str(exc),
        correlation_id=correlation_id
    )


async def database_exception_handler(request: Request, exc: asyncpg.PostgresError):
    """Handle database errors with proper categorization"""
    correlation_id = get_correlation_id(request)

    http_exception = db_error_handler.handle_database_error(
        exc, correlation_id, f"{request.method} {request.url.path}"
    )

    return create_error_response(
        status_code=http_exception.status_code,
        error_code=f"DATABASE_ERROR",
        message=http_exception.detail,
        correlation_id=correlation_id
    )