export interface DashboardSummary {
  dau: number;
  wau: number;
  mau: number;
  newInstallsToday: number;
  generations: {
    total: number;
    success: number;
    failed: number;
    safetyRejected: number;
    byCategory: Record<string, number>;
    byTone: Record<string, number>;
    byLanguage: Record<string, number>;
    avgLatencyMs: number;
    p95LatencyMs: number;
  };
  quotas: {
    quotaExceededCount: number;
  };
  ads: {
    rewardedGranted: number;
    estimatedAdRevenueInr: number;
  };
  subscriptions: {
    active: number;
    expired: number;
    canceled: number;
    estimatedSubscriptionRevenueInr: number;
  };
  totalEstimatedRevenueInr: number;
  streaks: {
    range0_2: number;
    range3_6: number;
    range7_13: number;
    range14_29: number;
    range30Plus: number;
  };
  referrals: {
    totalCount: number;
    rewardedCount: number;
  };
  dailyHistory: Array<{
    stat_date: string;
    dau: number;
    generations: number;
    failed: number;
    revenue_inr: number;
  }>;
}

export class StatsRepository {
  constructor(private db: D1Database) {}

  public async getDashboardSummary(): Promise<DashboardSummary> {
    const today = new Date().toISOString().substring(0, 10);
    const now = new Date();

    const sevenDaysAgo = new Date(now.getTime() - 7 * 86400000).toISOString().substring(0, 10);
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 86400000).toISOString().substring(0, 10);

    // 1. Activity / Active users (DAU, WAU, MAU)
    const [dauRow, wauRow, mauRow, newInstallsRow] = await Promise.all([
      this.db
        .prepare('SELECT COUNT(DISTINCT installation_id) as count FROM daily_usage WHERE usage_date = ?')
        .bind(today)
        .first<{ count: number }>(),
      this.db
        .prepare('SELECT COUNT(DISTINCT installation_id) as count FROM daily_usage WHERE usage_date >= ?')
        .bind(sevenDaysAgo)
        .first<{ count: number }>(),
      this.db
        .prepare('SELECT COUNT(DISTINCT installation_id) as count FROM daily_usage WHERE usage_date >= ?')
        .bind(thirtyDaysAgo)
        .first<{ count: number }>(),
      this.db
        .prepare('SELECT COUNT(*) as count FROM installations WHERE created_at >= ?')
        .bind(`${today}T00:00:00.000Z`)
        .first<{ count: number }>(),
    ]);

    // 2. Generations breakdown (Today)
    const genRows = await this.db
      .prepare(
        `SELECT category, tone, language, status, latency_ms
         FROM generation_metadata
         WHERE created_at >= ?`
      )
      .bind(`${today}T00:00:00.000Z`)
      .all<{
        category: string;
        tone: string | null;
        language: string | null;
        status: string;
        latency_ms: number | null;
      }>();

    const genList = genRows.results ?? [];
    let success = 0;
    let failed = 0;
    let safetyRejected = 0;
    const byCategory: Record<string, number> = {};
    const byTone: Record<string, number> = {};
    const byLanguage: Record<string, number> = {};
    const latencies: number[] = [];

    for (const g of genList) {
      if (g.status === 'success') success++;
      else if (g.status === 'safety_rejected') safetyRejected++;
      else failed++;

      if (g.category) byCategory[g.category] = (byCategory[g.category] ?? 0) + 1;
      if (g.tone) byTone[g.tone] = (byTone[g.tone] ?? 0) + 1;
      if (g.language) byLanguage[g.language] = (byLanguage[g.language] ?? 0) + 1;
      if (g.latency_ms && g.latency_ms > 0) latencies.push(g.latency_ms);
    }

    latencies.sort((a, b) => a - b);
    const avgLatencyMs = latencies.length > 0 ? Math.round(latencies.reduce((a, b) => a + b, 0) / latencies.length) : 0;
    const p95Idx = Math.floor(latencies.length * 0.95);
    const p95LatencyMs = latencies.length > 0 ? latencies[p95Idx] ?? avgLatencyMs : 0;

    // 3. Quota Exceeded Signals
    const quotaRow = await this.db
      .prepare(
        `SELECT COUNT(*) as count FROM daily_usage
         WHERE usage_date = ? AND free_credits_used >= 3`
      )
      .bind(today)
      .first<{ count: number }>();

    // 4. Rewarded ads watched
    const adRow = await this.db
      .prepare(
        `SELECT SUM(rewarded_ads_watched) as total_ads
         FROM daily_usage
         WHERE usage_date = ?`
      )
      .bind(today)
      .first<{ total_ads: number | null }>();

    const rewardedGranted = adRow?.total_ads ?? 0;
    // Estimated Ad Revenue: Approx ₹1.50 per rewarded impression (~$0.018 eCPM proxy)
    const estimatedAdRevenueInr = Math.round(rewardedGranted * 1.5);

    // 5. Subscription Entitlements
    const subRows = await this.db
      .prepare(
        `SELECT status, product_id, COUNT(*) as count
         FROM subscription_entitlements
         GROUP BY status, product_id`
      )
      .all<{ status: string; product_id: string; count: number }>();

    let activeSubs = 0;
    let expiredSubs = 0;
    let canceledSubs = 0;
    let estimatedSubscriptionRevenueInr = 0;

    for (const s of subRows.results ?? []) {
      if (s.status === 'ACTIVE') {
        activeSubs += s.count;
        // Estimated subscription value (avg ₹99 monthly equivalent)
        const price = s.product_id.includes('yearly') ? 699 : s.product_id.includes('weekly') ? 49 : 99;
        estimatedSubscriptionRevenueInr += s.count * price;
      } else if (s.status === 'EXPIRED') {
        expiredSubs += s.count;
      } else if (s.status === 'CANCELED') {
        canceledSubs += s.count;
      }
    }

    // 6. Streak Distribution
    const streakRows = await this.db
      .prepare('SELECT current_streak FROM streaks')
      .all<{ current_streak: number }>();

    const streaks = {
      range0_2: 0,
      range3_6: 0,
      range7_13: 0,
      range14_29: 0,
      range30Plus: 0,
    };

    for (const r of streakRows.results ?? []) {
      const s = r.current_streak;
      if (s < 3) streaks.range0_2++;
      else if (s < 7) streaks.range3_6++;
      else if (s < 14) streaks.range7_13++;
      else if (s < 30) streaks.range14_29++;
      else streaks.range30Plus++;
    }

    // 7. Referrals
    const referralRow = await this.db
      .prepare(
        `SELECT
           COUNT(*) as total,
           SUM(CASE WHEN status = 'REWARDED' THEN 1 ELSE 0 END) as rewarded
         FROM referrals`
      )
      .first<{ total: number; rewarded: number | null }>();

    // 8. Historical Daily Stats (From daily_stats table)
    const dailyHistoryRows = await this.db
      .prepare(
        `SELECT stat_date, dau, total_generations as generations, failed_generations as failed, estimated_revenue_inr as revenue_inr
         FROM daily_stats
         ORDER BY stat_date DESC
         LIMIT 14`
      )
      .all<{
        stat_date: string;
        dau: number;
        generations: number;
        failed: number;
        revenue_inr: number;
      }>();

    return {
      dau: dauRow?.count ?? 0,
      wau: wauRow?.count ?? 0,
      mau: mauRow?.count ?? 0,
      newInstallsToday: newInstallsRow?.count ?? 0,
      generations: {
        total: genList.length,
        success,
        failed,
        safetyRejected,
        byCategory,
        byTone,
        byLanguage,
        avgLatencyMs,
        p95LatencyMs,
      },
      quotas: {
        quotaExceededCount: quotaRow?.count ?? 0,
      },
      ads: {
        rewardedGranted,
        estimatedAdRevenueInr,
      },
      subscriptions: {
        active: activeSubs,
        expired: expiredSubs,
        canceled: canceledSubs,
        estimatedSubscriptionRevenueInr,
      },
      totalEstimatedRevenueInr: estimatedSubscriptionRevenueInr + estimatedAdRevenueInr,
      streaks,
      referrals: {
        totalCount: referralRow?.total ?? 0,
        rewardedCount: referralRow?.rewarded ?? 0,
      },
      dailyHistory: dailyHistoryRows.results ?? [],
    };
  }

  public async aggregateAndSaveDailyStats(dateStr: string): Promise<void> {
    const startOfDay = `${dateStr}T00:00:00.000Z`;
    const endOfDay = `${dateStr}T23:59:59.999Z`;

    const [dau, genStats, ads, subs] = await Promise.all([
      this.db
        .prepare('SELECT COUNT(DISTINCT installation_id) as c FROM daily_usage WHERE usage_date = ?')
        .bind(dateStr)
        .first<{ c: number }>(),
      this.db
        .prepare(
          `SELECT
             COUNT(*) as total,
             SUM(CASE WHEN status != 'success' THEN 1 ELSE 0 END) as failed,
             AVG(latency_ms) as avg_lat
           FROM generation_metadata
           WHERE created_at BETWEEN ? AND ?`
        )
        .bind(startOfDay, endOfDay)
        .first<{ total: number; failed: number; avg_lat: number | null }>(),
      this.db
        .prepare('SELECT SUM(rewarded_ads_watched) as total_ads FROM daily_usage WHERE usage_date = ?')
        .bind(dateStr)
        .first<{ total_ads: number | null }>(),
      this.db
        .prepare("SELECT COUNT(*) as c FROM subscription_entitlements WHERE status = 'ACTIVE'")
        .first<{ c: number }>(),
    ]);

    const installs = await this.db
      .prepare('SELECT COUNT(*) as c FROM installations WHERE created_at BETWEEN ? AND ?')
      .bind(startOfDay, endOfDay)
      .first<{ c: number }>();

    const totalGenerations = genStats?.total ?? 0;
    const failedGenerations = genStats?.failed ?? 0;
    const avgLatencyMs = Math.round(genStats?.avg_lat ?? 0);
    const rewardedAds = ads?.total_ads ?? 0;
    const proActive = subs?.c ?? 0;
    const revenueInr = Math.round(rewardedAds * 1.5 + proActive * 99);

    const now = new Date().toISOString();
    await this.db
      .prepare(
        `INSERT INTO daily_stats (
           stat_date, dau, wau, mau, new_installs, total_generations, failed_generations,
           avg_latency_ms, p95_latency_ms, rewarded_ads, pro_active_count, estimated_revenue_inr, computed_at
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(stat_date) DO UPDATE SET
           dau = excluded.dau,
           new_installs = excluded.new_installs,
           total_generations = excluded.total_generations,
           failed_generations = excluded.failed_generations,
           avg_latency_ms = excluded.avg_latency_ms,
           rewarded_ads = excluded.rewarded_ads,
           pro_active_count = excluded.pro_active_count,
           estimated_revenue_inr = excluded.estimated_revenue_inr,
           computed_at = excluded.computed_at`
      )
      .bind(
        dateStr,
        dau?.c ?? 0,
        dau?.c ?? 0, // daily wau approximation
        dau?.c ?? 0, // daily mau approximation
        installs?.c ?? 0,
        totalGenerations,
        failedGenerations,
        avgLatencyMs,
        Math.round(avgLatencyMs * 1.3),
        rewardedAds,
        proActive,
        revenueInr,
        now
      )
      .run();
  }
}
