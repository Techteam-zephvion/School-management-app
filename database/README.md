# Database

The Drizzle schema lives in `services/api/src/db/schema.ts` so application code and migrations share one typed source of truth.

Generate migrations from the API workspace:

```bash
pnpm db:generate
```

Apply migrations to a Neon branch using Drizzle Kit with `DATABASE_URL` set in the environment.
