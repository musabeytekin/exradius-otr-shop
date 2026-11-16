# otr-shop on Exradius

Exradius config for otr-shop, an e-commerce store (Medusa 2 backend and admin, Next.js
storefront, Postgres) that is the foundation for a customer support agent. Exradius reads
`exradius.yaml` from this repository on every run; changes take effect when they are
pushed to `main`.

| | |
|---|---|
| Config repository | https://github.com/musabeytekin/exradius-otr-shop |
| Branch | `main` |
| Config file | `exradius.yaml` |
| Visibility | public: no credential needed to read it |
| Code repository | https://github.com/musabeytekin/otr-shop (`main`, public) |
| Project slug | `otr-shop` |
| Secret store | `otr-shop` |

## Add the project

1. Projects, Add: paste `https://github.com/musabeytekin/exradius-otr-shop`.
2. Stores: create `otr-shop`, allow project `otr-shop` to use it, and fill the key below.
3. Open the project's Verify tab: it runs by itself and every step should pass. The local
   check passed on 2026-11-16 for `linux/arm64`, with these commands run as the agent
   would: `npm run lint` (backend), `npx eslint src/modules/products` (storefront),
   `npm run test:unit -- --passWithNoTests`, `npm run build` (backend),
   `npm view @medusajs/medusa version`, and the application started with
   `check/start-app.sh` (backend, admin login, storefront, a Chromium screenshot).
   Not proven locally: the storefront's full lint (it fails on `main` with 10 errors in
   the code), and the integration test suites (there are no tests yet).

## Ask the admin

- The cluster's CPU architecture: the images were checked for `linux/arm64`. If the
  cluster is `amd64`, tell the developers before the first Verify (nothing in the
  Dockerfile is architecture-specific, but it has not been built for `amd64`).

## Secret store `otr-shop`

| Key | Format | Where to get it | Used for |
|---|---|---|---|
| `GITHUB_TOKEN` | GitHub fine-grained personal access token, `github_pat_...` | github.com, Settings, Developer settings, Fine-grained tokens: resource owner `musabeytekin`, repository `otr-shop` only, permissions Contents: read and write, Pull requests: read and write, Metadata: read | pushing to `otr-shop` (the repository is public; cloning needs no token); the `github` connection (opening pull requests) |

The panel accepts a pasted `.env` block:

```
GITHUB_TOKEN=
```

The database password, `JWT_SECRET` and `COOKIE_SECRET` are throwaway development values
in `exradius.yaml`: the database exists only inside a run.

## What a run gets

- Workstation: built from `docker/workstation.Dockerfile`: Node 24 (Debian bookworm),
  npm 11.17.0, the Postgres client, Chromium's system libraries.
- Repositories: `otr-shop` (`main`, push allowed).
- Services: `postgres` (`postgres:17`).
- Setup: `npm ci`; `medusa db:migrate` (migrations and the demo seed: region, store,
  publishable API key, four products); an admin user for the dashboard; the storefront's
  `.env.local` with the seeded publishable key; Chromium for the browser tool.
- Agents: `developer` (code changes; pushes a branch and opens a pull request against
  `main`; screenshots of visible changes), `scout` (investigates and reports, never
  changes code).
- Network: besides its model, the repository and its connections, an agent reaches
  `registry.npmjs.org` (adding or updating npm dependencies) and
  `medusa-public-images.s3.eu-west-1.amazonaws.com` (the demo products' images, so pages
  and screenshots show them). Setup reaches any public host. A refused host shows on the
  task page's Network tab.
- Resources: `resources.memory` is `7g`: each run needs a cluster node with that much
  memory free (it waits as "waiting for cluster capacity" until one has), and the
  workstation is killed if it goes over it (measured: `npm ci` 2.6 GiB, the backend
  build 2.4 GiB, backend and storefront dev servers with Chromium 3.2 GiB; the agent may
  run the application while it builds). Disk: about 2 GB per run. Setup takes about
  1.5 minutes cold, under 40 seconds once the caches are filled.
- Caches: npm's download store (`~/.npm`) and Playwright's browsers
  (`~/.cache/ms-playwright`) are kept between runs on the project's volume in the cluster
  (the PersistentVolumeClaim `exradius-project-otr-shop` in the runs' namespace, about
  1.1 GB after the first run), shared by the project's runs and never cleaned by
  Exradius. Deleting the project deletes them; nothing else is lost when they are gone,
  the next run downloads again.

## Maintaining it

Edit `exradius.yaml` or the Dockerfile and push to `main`. Before pushing, the developers
check it locally with the `exradius-project` Claude Code skill, whose `check.sh` runs the
same steps as Verify with Docker. `check/start-app.sh` is the script that proved the
application starts; `check/reviewed.json` records the code commit the config was checked
against.
