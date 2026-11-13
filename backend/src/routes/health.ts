import { Hono } from 'hono';
import { Env } from '../types';

export const healthRoute = new Hono<{ Bindings: Env }>();

healthRoute.get('/health', (c) => {
  return c.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});
