# Phase 1: Containerization

**Goal:** package the app so it runs the same way on my laptop, in CI, and on AWS,
with one image that gets configured per environment at runtime.

**Pull request:** [#1](https://github.com/keshawndev/code-fast-saas/pull/1)

## Results

| | Before | After |
|---|---|---|
| Runtime files | 439 MB (`node_modules`) | 66 MB (Next.js standalone output) |
| Docker image | 1.06 GB (build stage) | 336 MB (final image) |
| Rebuild after a code change | ~85s (reinstalling dependencies) | ~1s for the dependency layer (cached) |

## What I Built

| File | Purpose |
|---|---|
| [`Dockerfile`](../Dockerfile) | Three-stage build: `deps` → `builder` → `runner` |
| [`.dockerignore`](../.dockerignore) | Keeps `node_modules`, `.next`, `.git`, and `.env*` out of the build context |
| [`docker-compose.yml`](../docker-compose.yml) | App + local MongoDB with a persistent volume and health-based startup |
| [`app/api/health/route.js`](../app/api/health/route.js) | Liveness endpoint for Docker and load balancer health checks |
| [`.env.example`](../.env.example) | Documents every required environment variable, with no values |
| [`.gitattributes`](../.gitattributes) | Enforces LF line endings so Windows edits don't break Linux containers |

## Design Decisions

- **Multi-stage build:** separate stages install dependencies, build the
  app, and run it. Only the final stage ships, so build tools never reach
  production.
- **Standalone output:** `output: "standalone"` in `next.config.mjs` makes
  `next build` trace which files the app actually uses at runtime, and copy
  only those.
- **Layer caching:** `package.json` and `package-lock.json` are copied before
  the source code, so `npm ci` only reruns when dependencies change.
- **Non-root user:** the container runs as a limited `nextjs` user. If the
  app were compromised, the attacker would not have root inside the
  container.
- **Liveness, not readiness:** `/api/health` deliberately doesn't check
  MongoDB. A brief database hiccup shouldn't cause healthy containers to be
  killed and restarted.
- **Build once, configure at runtime:** secrets are passed in when the
  container starts, never baked into the image. The same image can run in
  dev, staging, and prod with different configuration.
- **Database not exposed:** in Compose, MongoDB has no published port. Only
  the app can reach it, over the private Compose network.

## Problems I Solved

### 1. The build failed without database credentials
- **Problem:** `next build` crashed inside Docker with `Missing environment variable: "MONGO_URI"`.
- **Cause:** `libs/mongo.js` connected to MongoDB as soon as it was imported, and Next.js imports route files during the build ("Collecting page data").
- **Fix:** made the connection lazy. `getMongoClient()` connects on first use and is passed to `MongoDBAdapter` as a function, so the database is only needed at runtime.

### 2. The container reported "unhealthy" even though the app worked
- **Problem:** the site loaded in a browser, but `docker ps` showed `(unhealthy)`.
- **Cause:** I found it with `docker inspect --format '{{json .State.Health}}'` and by running `wget` from inside the container. On Alpine, `localhost` resolved to IPv6 (`::1`), but the server only listened on IPv4 (`HOSTNAME=0.0.0.0`).
- **Fix:** pointed the health check at `127.0.0.1`.

### 3. Google sign-in failed inside the container
- **Problem:** OAuth login was rejected, and no user was ever written to the database.
- **Cause:** `curl /api/auth/providers` showed Auth.js building callback URLs with `0.0.0.0` (the server's listen address) instead of `localhost`, so they didn't match the redirect URIs registered with Google.
- **Fix:** set `AUTH_URL` to tell Auth.js its public address. Each environment gets its own value.

### 4. Subscriptions didn't activate
- **Problem:** checkout succeeded, but the user never got access.
- **Cause:** Stripe confirms payments by calling the app's webhook, and Stripe's servers can't reach `localhost`. The user's `hasAccess` field was never set.
- **Fix:** used `stripe listen --forward-to localhost:3000/api/webhook` to forward events to the local container, with the CLI's signing secret in `.env.local`.

## Follow-up Fixes

Bugs that containerization exposed, each fixed in its own PR:

- [ ] Board share link is hardcoded to a single domain. It needs to come from per-environment configuration.
- [ ] `/dashboard` can throw on a null session in one case.

## What I Learned

- `localhost` inside a container means *that container*. Services reach each
  other by name (`mongo:27017`), and the outside world reaches the app
  through published ports.
- Anything needed at build time can end up in the image, so configuration
  and secrets belong at runtime.
- The app needs to know its own public URL, and that URL is different in
  every environment.
