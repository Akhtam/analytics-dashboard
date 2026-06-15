# Call Analytics Dashboard

## Summary

A real-time inbound-call analytics dashboard built as a **Rails 8 + Hotwire monolith** (server-rendered, no separate frontend app). It gives a marketing manager **call volume over time** (last 7 days / 24 hours, daily & hourly), **conversion rate by campaign**, and a **live feed** of recent calls — all filterable by date range, campaign, and outcome, with the feed updating in real time via Turbo Streams.

**Stack:** Ruby 4.0.5 · Rails 8 · PostgreSQL · Hotwire (Turbo Frames + Turbo Streams + Stimulus) · Propshaft · importmap · RSpec/FactoryBot. Charts are server-rendered HTML/CSS (no charting library).

---

## Architecture

```
                       ┌─────────────────────────────────────────────┐
                       │                 Browser                      │
                       │  Hotwire (Turbo + Stimulus)                  │
                       │   • Filters → auto-submit (Stimulus)         │
                       │   • "Go live" → live-feed controller         │
                       └─────────────────────────────────────────────┘
                          │  ▲ Turbo Frame             ▲ Turbo Stream
            HTTP GET/POST │  │ (partial re-render)     │ (WebSocket /cable)
                          ▼  │                         │
                       ┌─────────────────────────────────────────────┐
                       │            Rails app (backend)               │
                       │  CallsController#index                       │
                       │    └ CallsFilter → CallStats (volume,        │
                       │        conversion) → CallsHelper → views     │
                       │  CallsController#simulate → Call.simulate!   │
                       │  Call#after_create_commit ── broadcast ──────┼─► back to Browser
                       └─────────────────────────────────────────────┘    via ActionCable
                          │
                          ▼
                       ┌─────────────────────────────────────────────┐
                       │          PostgreSQL (data layer)             │
                       │   campaigns, calls  (index on started_at)    │
                       └─────────────────────────────────────────────┘

External system (simulated): the in-app live-feed simulator stands in for a
telephony provider. In production, a provider webhook would POST call events →
Call.create → the same after_create_commit broadcast → live feed.
```

### Database schema

```
Campaign 1 ───< * Call

┌──── campaigns ─────┐        ┌──── calls ───────┐
│ id                 │        │ id               │
│ name               │ 1    * │ campaign_id      │
│ source             │───────<│ status           │
│ tracking_number    │        │ started_at       │
│ created_at         │        │ ended_at         │
│ updated_at         │        │ duration_seconds │
└────────────────────┘        │ call_number      │
                              │ created_at       │
                              │ updated_at       │
                              └──────────────────┘
```



---

## Option 1 — Run with Docker (recommended)

**Requirements**
- Docker with Compose v2 (`docker compose`, included in Docker Desktop)

**Run**
```bash
docker compose up
```
Builds the app image, starts PostgreSQL, creates/migrates the database, loads demo seed data, and starts the server. Open **http://localhost:3000**.

**Stop**
```bash
docker compose down       # stop (Postgres data kept in a volume)
docker compose down -v    # also wipe the database volume
```

**Tests**
```bash
docker compose exec web bundle exec rspec
```

Notes: runs in `development` so the (development-only) seed data loads; the live feed works in-process (no Redis); seed regenerates fresh data on each `up`.

---

## Option 2 — Run without Docker (local)

**Requirements**
- **Ruby 4.0.5** (see `.ruby-version`)
- **PostgreSQL** running locally (v9.3+; tested on 18)
- `libpq` + a C toolchain for the `pg` gem (macOS: `brew install postgresql`; Debian/Ubuntu: `apt-get install libpq-dev`)
- Bundler (`gem install bundler`)

**Setup**
```bash
bundle install
bin/rails db:prepare   # create + migrate development & test databases
bin/rails db:seed      # load demo data (development only)
```

**Database connection.** By default the app connects to Postgres on `localhost` as your OS user (works with a standard local/Homebrew Postgres). Override with env vars if needed:
```bash
export DATABASE_HOST=localhost
export DATABASE_USERNAME=postgres
export DATABASE_PASSWORD=secret
```

**Run**
```bash
bin/rails server   # http://localhost:3000
```

**Tests**
```bash
bundle exec rspec
```

---


## Data model

- **Campaign** — `name`, `source`, `tracking_number`
- **Call** — `campaign`, `status` (enum: `missed` / `connected` / `converted`), `started_at`, `ended_at`, `duration_seconds`, `call_number`

Demo data (`db/seeds.rb`, `MockDataGenerator`): ~7 days of calls across several campaigns with realistic per-source conversion rates and business-hour weighting.

---

## Decisions & trade-offs

### What I built
A single Rails app (server-rendered + Hotwire) backed by PostgreSQL, with query objects for the aggregations and Turbo Streams for the real-time feed.

### Key trade-offs
- **Single full-stack app instead of an API-only backend + separate frontend.** Faster to build and cohesive for a demo; less suited to multiple client types.
- **Read-time aggregation** (compute volume/conversion on every request) rather than precomputed rollups. Fine at demo scale with the `started_at` index; doesn't scale to millions of calls.
- **Filters via Turbo Frame (server round-trip)** instead of client-side recompute — single source of truth in Ruby, at the cost of a (cheap, indexed) query per change.
- **Live feed via an in-process simulator + ActionCable `async`** (no Redis). Works in one process, but broadcasts are unfiltered and the feed isn't trimmed server-side.
- **Simplified data layer** — `status` is an integer enum on `Call` rather than a separate status/outcome model.

### What I'd do differently with more time
- **Precomputed rollups** (hourly per-campaign/status counters or a materialized view, incremented on call creation) so reads are O(buckets) — the main scalability fix — plus a `(campaign_id, started_at)` composite index and time-partitioning at large volume.
- **Real ingestion**: a telephony webhook/API (idempotent) replacing the simulator.
- **Per-filter live updates** (scoped streams), server-side feed trimming, and pagination.
- **Data-integrity safeguards**: `dependent:`/FK `on_delete` for campaign→calls, and `Call` validations + DB CHECK constraints (`ended_at >= started_at`, non-negative duration).
- **AuthN/AuthZ + multi-tenancy**, configurable per-user timezone, observability, and system/integration tests for the JS flows.

### Intentionally left out
Authentication/users/multi-tenancy · real telephony integration (simulator instead) · charting library / pixel-perfect UI · caching/rollups · some data-integrity constraints (FK cascade, timing validations) · Capybara system specs · production secrets/Kamal deploy beyond the generated defaults.
