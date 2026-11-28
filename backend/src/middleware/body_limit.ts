import { MiddlewareHandler } from 'hono';
import { AppHonoEnv } from '../types';
import { ValidationError } from '../errors/app_error';

/**
 * Enforces strict request body size limit by validating Content-Length strictly
 * AND counting actual streamed bytes on cloned request bodies without buffering unbounded OOM payloads.
 */
export const bodyLimitMiddleware = (maxBytes: number = 16384): MiddlewareHandler<AppHonoEnv> => {
  return async (c, next) => {
    const rawHeader = c.req.header('content-length');
    if (rawHeader !== undefined) {
      const trimmed = rawHeader.trim();
      if (!/^\d+$/.test(trimmed)) {
        throw new ValidationError('Invalid Content-Length header.');
      }
      const parsedLength = Number.parseInt(trimmed, 10);
      if (!Number.isSafeInteger(parsedLength) || parsedLength < 0) {
        throw new ValidationError('Invalid Content-Length header.');
      }
      if (parsedLength > maxBytes) {
        throw new ValidationError(`Request payload exceeds maximum allowed size of ${maxBytes} bytes.`, {
          maxBytes,
          receivedBytes: parsedLength,
        });
      }
    }

    if (c.req.method === 'POST' || c.req.method === 'PUT' || c.req.method === 'PATCH') {
      const cloned = c.req.raw.clone();
      if (cloned.body) {
        const reader = cloned.body.getReader();
        let totalBytes = 0;
        let exceeded = false;
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            if (value) {
              totalBytes += value.byteLength;
              if (totalBytes > maxBytes) {
                exceeded = true;
                break;
              }
            }
          }
        } finally {
          reader.releaseLock();
          if (exceeded) {
            void cloned.body.cancel().catch(() => {});
          }
        }
        if (exceeded) {
          throw new ValidationError(`Request payload exceeds maximum allowed size of ${maxBytes} bytes.`, {
            maxBytes,
            receivedBytes: totalBytes,
          });
        }
      } else {
        const raw = await cloned.arrayBuffer().catch(() => null);
        if (raw && raw.byteLength > maxBytes) {
          throw new ValidationError(`Request payload exceeds maximum allowed size of ${maxBytes} bytes.`, {
            maxBytes,
            receivedBytes: raw.byteLength,
          });
        }
      }
    }

    await next();
  };
};
