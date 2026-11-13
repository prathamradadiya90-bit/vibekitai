import { ErrorHandler } from 'hono';
import { AppHonoEnv } from '../types';
import { AppError } from '../errors/app_error';

export const globalErrorHandler: ErrorHandler<AppHonoEnv> = (err, c) => {
  const requestId = c.get('requestId') || 'unknown';

  if (err instanceof AppError) {
    const errorBody: { code: string; message: string; requestId: string; details?: unknown } = {
      code: err.code,
      message: err.message,
      requestId,
    };
    if (err.details !== undefined) {
      errorBody.details = err.details;
    }
    return c.json({ error: errorBody }, err.statusCode as any);
  }

  if (err instanceof SyntaxError || err.name === 'SyntaxError') {
    return c.json(
      {
        error: {
          code: 'MALFORMED_JSON',
          message: 'The request body must be a valid JSON object.',
          requestId,
        },
      },
      400
    );
  }

  console.error(
    JSON.stringify({
      level: 'error',
      timestamp: new Date().toISOString(),
      requestId,
      path: c.req.path,
      method: c.req.method,
      errorName: err.name,
      errorMessage: err.message,
    })
  );

  return c.json(
    {
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'An internal server error occurred. Please try again later.',
        requestId,
      },
    },
    500
  );
};
