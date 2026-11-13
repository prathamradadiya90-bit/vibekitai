import { Hono } from 'hono';
import { Env } from '../types';
import { FeedbackSchema } from '../schemas/validation';
import { FeedbackRepository } from '../db/feedback.repo';

export const feedbackRoute = new Hono<{ Bindings: Env }>();

feedbackRoute.post('/feedback', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const bodyResult = FeedbackSchema.safeParse(await c.req.json());

  if (!bodyResult.success) {
    return c.json(
      {
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid feedback message.',
          details: bodyResult.error.format(),
        },
      },
      400
    );
  }

  if (c.env.DB) {
    const feedbackRepo = new FeedbackRepository(c.env.DB);
    await feedbackRepo.create(installationId, bodyResult.data.message);
  }

  return c.json({
    success: true,
    message: 'Feedback received. Thank you for helping us improve VibeKit AI!',
  });
});
