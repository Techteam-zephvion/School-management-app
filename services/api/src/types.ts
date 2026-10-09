export type Env = {
  APP_ENV: string;
  CORS_ORIGIN: string;
  DATABASE_URL: string;
  NEON_AUTH_URL: string;
  NEON_AUTH_AUDIENCE?: string;
  BOOTSTRAP_TOKEN?: string;
};

export type Role = 'admin' | 'teacher';

export type AuthUser = {
  neonUserId: string;
  email: string;
  roles: Role[];
  schoolId: string;
  staffId?: string | null;
};

export type AppBindings = {
  Bindings: Env;
  Variables: {
    authUser: AuthUser;
  };
};
