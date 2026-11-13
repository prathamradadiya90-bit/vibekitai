export type ErrorCode =
  | 'VALIDATION_ERROR'
  | 'QUOTA_EXCEEDED'
  | 'AI_PROVIDER_ERROR'
  | 'GENERATION_FAILED'
  | 'UNAUTHORIZED'
  | 'FORBIDDEN'
  | 'ACCOUNT_BANNED'
  | 'NOT_FOUND'
  | 'RATE_LIMIT_EXCEEDED'
  | 'MALFORMED_JSON'
  | 'INTERNAL_SERVER_ERROR';

export class AppError extends Error {
  public readonly code: ErrorCode;
  public readonly statusCode: number;
  public readonly details?: unknown;

  constructor(message: string, code: ErrorCode, statusCode: number = 400, details?: unknown) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export class ValidationError extends AppError {
  constructor(message: string = 'Invalid request payload.', details?: unknown) {
    super(message, 'VALIDATION_ERROR', 400, details);
  }
}

export class QuotaExceededError extends AppError {
  constructor(message: string = 'You have reached your daily credit limit. Please watch an ad or upgrade to Pro.') {
    super(message, 'QUOTA_EXCEEDED', 429);
  }
}

export class ProviderError extends AppError {
  constructor(message: string = 'AI generation failed. Please try again.') {
    super(message, 'AI_PROVIDER_ERROR', 502);
  }
}

export class RateLimitError extends AppError {
  constructor(message: string = 'Rate limit exceeded. Please slow down.') {
    super(message, 'RATE_LIMIT_EXCEEDED', 429);
  }
}

export class AuthError extends AppError {
  constructor(message: string = 'Unauthorized request.') {
    super(message, 'UNAUTHORIZED', 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message: string = 'Access denied.') {
    super(message, 'FORBIDDEN', 403);
  }
}

export class AccountBannedError extends AppError {
  constructor(message: string = 'This installation has been suspended for policy violations.') {
    super(message, 'ACCOUNT_BANNED', 403);
  }
}

export class NotFoundError extends AppError {
  constructor(message: string = 'Resource not found.') {
    super(message, 'NOT_FOUND', 404);
  }
}
