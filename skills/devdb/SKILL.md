---
name: devdb
description: Do queries on local database
---

# Dev Database PG Skill

Answer queries about db data by asking questions

## How to use

### Main Database (Prisma)
1. Connect to local database with `psql` on `postgres://postgres:postgres@localhost:5432/alliance-network` (container `alliance_postgres_local`)
2. If you are not able to connect to it, check if the container is stopped (`docker ps`). If it is missing, see "Local DB Setup" below
3. Check scripts folder for similar queries
4. If it's not clear how to answer by looking at data, try to find in the code how data is used
5. Look at @packages/database/prisma/schema/schema.prisma to understand schema
6. After query is run, ask user if they wanna save it, then save query with script on skill scripts folder

> If `psql` is not on `PATH`, use the libpq build at `/opt/homebrew/opt/libpq/bin/psql`.

### Two databases: Docker vs Prisma dev daemon

There are **two separate local Postgres instances**:

| | Docker DB | Prisma dev daemon |
|---|---|---|
| URL | `postgres://postgres:postgres@localhost:5432/alliance-network` | `prisma+postgres://...` (worktree-specific, see `output/dev/runtime.env`) |
| Lifetime | Persistent across reboots | In-memory; lives as long as the daemon process runs |
| Used by | Ad-hoc scripts, `fnox.local.toml` overrides, this skill | `bun run dev up <app>` managed processes |
| Schema setup | Manual: `DATABASE_URL=<docker-url> bun run db:setup` | Auto: run by apps with a `setupCommand` on daemon start |

**This skill queries the Docker DB.** Apps started via `bun run dev up` use the Prisma dev daemon URL.

### Which apps set up the schema?

All apps run `db:setup` (`prisma db push && prisma db seed`) against the Prisma dev daemon on startup:

- `webapp` ✅
- `admin` ✅
- `bullqueue` ✅
- `website` ✅

The setup commands are deduplicated by label, so if you start multiple apps at once, `db:setup` only runs once.

### Local DB Setup

This is the persistent docker-backed local database that this skill queries and that apps read from when `fnox.local.toml` points `DATABASE_URL` at it. Use it for a fresh worktree, or to recover a missing/empty container. All commands run from the repo root.

1. **Create and start the docker container** (defined in `services/postgres/docker-compose.yml`: container `alliance_postgres_local`, user/password `postgres`/`postgres`, db `alliance-network`, port `5432`):

   ```bash
   docker compose -f services/postgres/docker-compose.yml up -d
   ```

   `services/postgres/init.sql` installs the required extensions (`vector`, `pg_visibility`, `pageinspect`) on first boot.

2. **Apply the schema and seed data** against the docker DB. `prisma` reads `DATABASE_URL`, so point it at the container, then run push + seed:

   ```bash
   cd packages/database
   DATABASE_URL=postgres://postgres:postgres@localhost:5432/alliance-network bun run db:setup
   ```

   `db:setup` runs `prisma db push` (creates/syncs tables) then `prisma db seed` (~12 companies, members, demo days, perks, etc.). Re-running is safe.

3. **Set up `fnox.local.toml`** so local apps and ad-hoc scripts read this docker DB instead of the Prisma dev daemon. Create a gitignored `fnox.local.toml` at the repo root (next to `fnox.toml`):

   ```toml
   [profiles.development.providers.plain]
   type = "plain"

   [profiles.development.secrets]
   DATABASE_URL = { provider = "plain", value = "postgres://postgres:postgres@localhost:5432/alliance-network" }
   ```

   `fnox` loads this override automatically (hierarchical config) and it is gitignored, so it stays machine-local. Note: managed `bun run dev up <app>` processes still receive a control-plane-generated `DATABASE_URL` (a `prisma+postgres://` Prisma-dev URL) that overrides this; the `fnox.local.toml` value applies to raw app runs, scripts, and `fnox`/`mise exec` invocations.

### IMDB Database (Investment Manager)
1. Connect with `psql` on `postgresql://retool:retool@localhost:5433/retool`
2. Data lives in the `im` schema — use `SET search_path TO im;` or prefix tables with `im.`
3. Look at @packages/database-imdb/src/schema.sql to understand the schema
4. Key tables: `im.event` (source of truth), `im.project`, `im.investment_entity`, `im.custody`, `im.paperwork`
5. Key views: `im.v_project_current`, `im.v_investments`, `im.v_realizations`, `im.v_payments`
6. Key tables for normalized records: `im.round`, `im.custody`, `im.paperwork`, `im.investment_entity`

### Local Redis
1. Connect with `redis-cli -u redis://localhost:6379`
2. Used by BullMQ for job queues — inspect queues with `KEYS bull:*`

## Example usage

"find out how many founders have posted investor reviews"

"rank top ten users that created the most shoutouts"

