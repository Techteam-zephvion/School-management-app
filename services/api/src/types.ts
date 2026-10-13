export type Env = {
  APP_ENV: string;
  CORS_ORIGIN: string;
  DATABASE_URL: string;
  NEON_AUTH_URL: string;
  NEON_AUTH_AUDIENCE?: string;
  BOOTSTRAP_TOKEN?: string;
  AI_FEATURES_ENABLED?: string;
  AI_PROVIDER?: string;
  AI_MODEL?: string;
  AI_BASE_URL?: string;
  AI_API_KEY?: string;
  AI_MAX_OUTPUT_TOKENS?: string;
  AI_TIMEOUT_MS?: string;
  AI_REQUESTS_PER_USER?: string;
  AI_REQUEST_WINDOW_MINUTES?: string;
};

export type Role = 'admin' | 'teacher' | 'student' | 'parent';

export type AuthUser = {
  appUserId: string;
  neonUserId: string;
  email: string;
  roles: Role[];
  schoolId: string;
  staffId?: string | null;
  displayName?: string | null;
};

export type AppBindings = {
  Bindings: Env;
  Variables: {
    authUser: AuthUser;
  };
};
