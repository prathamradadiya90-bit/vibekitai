import { MiddlewareHandler } from 'hono';
import { AppHonoEnv } from '../types';
import { ValidationError } from '../errors/app_error';

/**
 * Enforces strict request body size limit to protect against OOM and Zod CVE GHSA-mrhx-c7xc-m3w5
 */
export const bodyLimitMiddleware = (maxBytes: number = 16384): MiddlewareHandler<AppHonoEnv> => {
  return async (c, next) => {
    const contentLength = c.req.header('content-length');
    if (contentLength && parseInt(contentLength, 10) > maxBytes) {
      throw new ValidationError(`Request payload exceeds maximum allowed size of ${maxBytes} bytes.`, {
        maxBytes,
        receivedBytes: parseInt(contentLength, 10),
      });
    }

    if (!contentLength && (c.req.method === 'POST' || c.req.method === 'PUT' || c.req.method === 'PATCH')) {
      // Chunked or streaming request without Content-Length header: verify buffer size
      const raw = await c.req.raw.clone().arrayBuffer().catch(() => null);
      if (raw && raw.byteLength > maxBytes) {
        throw new ValidationError(`Request payload exceeds maximum allowed size of ${maxBytes} bytes.`, {
          maxBytes,
          receivedBytes: raw.byteLength,
        });
      }
    }

    await next();
  };
};
