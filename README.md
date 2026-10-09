# Schoolic

Web-first school management MVP for a zero-cost pilot target.

## Stack

- Flutter web client in `apps/flutter_app`
- Cloudflare Worker API using Hono in `services/api`
- Neon PostgreSQL with Drizzle schema and migrations
- Neon Managed Auth integration through backend-validated sessions

## Local Setup

```bash
pnpm install
cd apps/flutter_app && flutter pub get
```

Copy `services/api/.env.example` to `services/api/.dev.vars` for local Worker development.

```bash
pnpm api:dev
pnpm api:test
pnpm flutter:test
```

The Flutter app can run with:

```bash
cd apps/flutter_app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8787
```

## Deployment Targets

- Flutter web: Cloudflare Pages, `school.zephvion.com`
- API Worker: `api-school.zephvion.com` when the Cloudflare zone is available, otherwise the generated `workers.dev` hostname

Secrets such as `DATABASE_URL`, `NEON_AUTH_URL`, and API keys must be stored in Cloudflare environment variables, not in Flutter source.
