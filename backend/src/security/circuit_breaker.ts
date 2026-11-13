import { AppError } from '../errors/app_error';

export interface BudgetStatus {
  date: string;
  totalSpendUsd: number;
  maxBudgetUsd: number;
  isTripped: boolean;
}

export class AICircuitBreaker {
  constructor(private db?: D1Database, private defaultMaxBudgetUsd: number = 25.0) {}

  public async checkBudgetGuard(estimatedCostUsd: number = 0.001): Promise<void> {
    if (!this.db) return;

    const today = new Date().toISOString().substring(0, 10);
    const row = await this.db
      .prepare('SELECT total_spend_usd, max_budget_usd, is_tripped FROM ai_daily_budget WHERE stat_date = ?')
      .bind(today)
      .first<{ total_spend_usd: number; max_budget_usd: number; is_tripped: number }>();

    if (row) {
      if (row.is_tripped === 1 || row.total_spend_usd + estimatedCostUsd > row.max_budget_usd) {
        throw new AppError(
          'Service temporarily in protective maintenance. Daily AI generation budget limit reached.',
          'RATE_LIMIT_EXCEEDED',
          503,
          { date: today, budgetUsd: row.max_budget_usd }
        );
      }
    }
  }

  public async recordSpend(actualCostUsd: number): Promise<void> {
    if (!this.db || actualCostUsd <= 0) return;

    const today = new Date().toISOString().substring(0, 10);
    const now = new Date().toISOString();

    await this.db
      .prepare(
        `INSERT INTO ai_daily_budget (stat_date, total_spend_usd, max_budget_usd, is_tripped, updated_at)
         VALUES (?, ?, ?, 0, ?)
         ON CONFLICT(stat_date) DO UPDATE SET
           total_spend_usd = total_spend_usd + excluded.total_spend_usd,
           is_tripped = CASE WHEN (total_spend_usd + excluded.total_spend_usd) >= max_budget_usd THEN 1 ELSE 0 END,
           updated_at = excluded.updated_at`
      )
      .bind(today, actualCostUsd, this.defaultMaxBudgetUsd, now)
      .run();
  }

  public async getBudgetStatus(): Promise<BudgetStatus> {
    const today = new Date().toISOString().substring(0, 10);
    if (!this.db) {
      return { date: today, totalSpendUsd: 0, maxBudgetUsd: this.defaultMaxBudgetUsd, isTripped: false };
    }

    const row = await this.db
      .prepare('SELECT total_spend_usd, max_budget_usd, is_tripped FROM ai_daily_budget WHERE stat_date = ?')
      .bind(today)
      .first<{ total_spend_usd: number; max_budget_usd: number; is_tripped: number }>();

    return {
      date: today,
      totalSpendUsd: row?.total_spend_usd ?? 0,
      maxBudgetUsd: row?.max_budget_usd ?? this.defaultMaxBudgetUsd,
      isTripped: Boolean(row?.is_tripped),
    };
  }
}
