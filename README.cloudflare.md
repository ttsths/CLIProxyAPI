# CLIProxyAPI on Cloudflare Containers

This repository can be deployed to Cloudflare **without rewriting the Go server**. The new Cloudflare entrypoint is a thin Worker that forwards HTTP and WebSocket traffic to a Cloudflare Container built from `Dockerfile.cloudflare`.

If you only want Cloudflare as a public edge in front of a server you host elsewhere, keep using the existing `docker-compose.yml` + `cloudflared` tunnel flow. This document is for running CLIProxyAPI **inside Cloudflare Containers**.

## Important persistence note

CLIProxyAPI is file-backed by default (`config.yaml`, auth files under `auth-dir`). Cloudflare Containers do **not** provide durable local disk.

That means:

| Use case | Recommended setup |
| --- | --- |
| OAuth logins, rotating auth files, management edits you want to keep | Use `PGSTORE_*`, `OBJECTSTORE_*`, or `GITSTORE_*` |
| API-key-only proxy with mostly static config | Use `CLI_PROXY_CONFIG_B64` |
| Existing VM / NAS / Docker host | Use the existing Cloudflare Tunnel setup instead of Containers |

For durable Cloudflare deployments, prefer one of the remote stores already supported by this repo:

- `PGSTORE_DSN`, `PGSTORE_SCHEMA`, `PGSTORE_LOCAL_PATH`
- `OBJECTSTORE_ENDPOINT`, `OBJECTSTORE_BUCKET`, `OBJECTSTORE_ACCESS_KEY`, `OBJECTSTORE_SECRET_KEY`, `OBJECTSTORE_LOCAL_PATH`
- `GITSTORE_GIT_URL`, `GITSTORE_GIT_USERNAME`, `GITSTORE_GIT_TOKEN`, `GITSTORE_GIT_BRANCH`, `GITSTORE_LOCAL_PATH`

## Files added for Cloudflare

- `wrangler.toml` - Worker + Container configuration
- `cloudflare/index.ts` - Worker entrypoint
- `Dockerfile.cloudflare` - container image used by Wrangler
- `scripts/deploy-cloudflare.sh`
- `scripts/deploy-cloudflare.ps1`
- `.github/workflows/cloudflare-containers.yml`

## 1. Install tooling

```bash
npm install
npx wrangler login
```

Docker must be running locally before `wrangler deploy`.

## 2. Configure runtime secrets

At minimum, choose one of these approaches:

### Option A: inline static config

Encode your `config.yaml` as base64 and upload it as a Worker secret:

```bash
base64 < config.yaml | tr -d '\n' | npx wrangler secret put CLI_PROXY_CONFIG_B64
```

This is the easiest path when you only need API keys and do not expect Cloudflare Container restarts to preserve locally generated auth files.

### Option B: durable remote store

Upload the remote store credentials as Worker secrets:

```bash
npx wrangler secret put PGSTORE_DSN
npx wrangler secret put PGSTORE_SCHEMA
npx wrangler secret put PGSTORE_LOCAL_PATH
```

or:

```bash
npx wrangler secret put OBJECTSTORE_ENDPOINT
npx wrangler secret put OBJECTSTORE_BUCKET
npx wrangler secret put OBJECTSTORE_ACCESS_KEY
npx wrangler secret put OBJECTSTORE_SECRET_KEY
npx wrangler secret put OBJECTSTORE_LOCAL_PATH
```

or:

```bash
npx wrangler secret put GITSTORE_GIT_URL
npx wrangler secret put GITSTORE_GIT_USERNAME
npx wrangler secret put GITSTORE_GIT_TOKEN
npx wrangler secret put GITSTORE_GIT_BRANCH
npx wrangler secret put GITSTORE_LOCAL_PATH
```

You can mix these with `CLI_PROXY_CONFIG_B64` if you want to seed the first Postgres/object-store/git-backed config from your existing `config.yaml`.

## 3. Deploy

Use the same flow as the sibling project, but without D1/KV bootstrap:

```bash
bash ./scripts/deploy-cloudflare.sh
```

Windows PowerShell:

```powershell
pwsh ./scripts/deploy-cloudflare.ps1
```

Or deploy directly:

```bash
npx wrangler deploy
```

## 4. Verify

After deploy:

- `GET https://<your-worker>.workers.dev/healthz`
- open your Worker URL in the browser
- if you enabled remote management, verify your management route and secret work as expected

## 5. GitHub Actions deployment

This repository now includes `.github/workflows/cloudflare-containers.yml`.

Required repository secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

Optional repository secrets for runtime configuration:

- `CLI_PROXY_CONFIG_B64`
- any of the `PGSTORE_*`, `OBJECTSTORE_*`, or `GITSTORE_*` variables listed above

The workflow will:

1. build-check the Go server
2. run `npm ci`
3. run `npm run typecheck`
4. sync any configured runtime secrets to the Worker
5. run `wrangler deploy`

## 6. Notes

- The Worker uses a single named container instance (`primary`) so the Go server behaves like one long-lived service behind Cloudflare.
- WebSocket traffic is proxied through the Worker entrypoint as well.
- `DEPLOY=cloud` is set in `wrangler.toml`, matching the existing cloud deploy branch in `cmd/server/main.go`.
