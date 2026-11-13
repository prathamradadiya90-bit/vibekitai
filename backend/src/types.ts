export interface Env {
  DB: D1Database;
  ENVIRONMENT: string;
  GEMINI_API_KEY?: string;
  GEMINI_MODEL?: string;
  // Multi-Provider AI Support (Groq, OpenRouter, OpenAI, Together, DeepSeek, Mistral)
  AI_PROVIDER?: string; // 'gemini' | 'groq' | 'openrouter' | 'openai' | 'together' | 'custom'
  AI_API_KEY?: string;
  AI_BASE_URL?: string;
  AI_MODEL?: string;
  FALLBACK_AI_PROVIDER?: string;
  FALLBACK_AI_API_KEY?: string;
  FALLBACK_AI_BASE_URL?: string;
  FALLBACK_AI_MODEL?: string;
  GROQ_API_KEY?: string;
  OPENROUTER_API_KEY?: string;
  OPENAI_API_KEY?: string;
  MAX_DAILY_FREE_CREDITS?: string;
  REWARD_CREDITS_PER_AD?: string;
  MAX_DAILY_REWARDS?: string;
  MONTHLY_PRO_CREDITS?: string;
  GOOGLE_PLAY_PACKAGE_NAME?: string;
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON?: string;
  PLAY_INTEGRITY_DECRYPTION_KEY?: string;
  ADMOB_SSV_KEY_URL?: string;
  SKIP_SSV_VERIFY_FOR_DEV?: string;
  ENABLE_CREDIT_PACKS?: string;
  // Local dev only: accept purchases without Google Play verification when no service account is set
  ALLOW_UNVERIFIED_PURCHASES?: string;
  // Admin & Security Bindings
  CF_ACCESS_AUD?: string;
  CF_ACCESS_TEAM_NAME?: string;
  ADMIN_SECRET?: string;
  ADMIN_USERS_JSON?: string;
  ADMIN_ALLOWED_EMAILS?: string;
}

export type AdminRole = 'admin' | 'viewer';

export interface AdminUser {
  email: string;
  role: AdminRole;
  source: 'cf_access' | 'session_token';
}

export interface InstallationRecord {
  id: string;
  created_at: string;
  last_active_at: string;
  is_pro: number;
  pro_expires_at: string | null;
}

export interface AppVariables {
  installation: InstallationRecord;
  requestId: string;
  adminUser?: AdminUser;
}

export type AppHonoEnv = {
  Bindings: Env;
  Variables: AppVariables;
};
