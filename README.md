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
3. Open the project's Verify tab: it runs by itself, checks each environment in turn
   (`development`, `source`, `review`, `triage`), and every step should pass. After a change to this
   repository reaches `main`, press Reread and then Verify. The local check passed on
   2026-11-17 for `linux/arm64`, one environment at a time:
   - `development`, with these commands run as the agent would: `npm run lint`
     (backend), `npx eslint src/modules/products` (storefront),
     `npm run test:unit -- --passWithNoTests`, `npm run build` (backend),
     `npm view @medusajs/medusa version`, and the application started with
     `check/start-app.sh` (backend, admin login, storefront, a Chromium screenshot).
   - `source`: the clone on the default image, read with `git log` and `grep`; no Node
     on the PATH and no host reached.
   - `review`: the clone on the default image, read with `git`; the `github` connection
     needs nothing in the image.
   - `triage`: the default image with an empty project directory.

   Not proven locally: the storefront's full lint (it fails on `main` with 10 errors in
   the code), the integration test suites (there are no tests yet), and what no local
   check covers (the agent and its model, pushes, the connections' tool lists).

## Ask the admin

- The cluster's CPU architecture: the images were checked for `linux/arm64`. If the
  cluster is `amd64`, tell the developers before the first Verify (nothing in the
  Dockerfile is architecture-specific, but it has not been built for `amd64`).
- The Exradius install must read config version 2 (agent environments). An older
  install refuses this file.
- The GitHub issues bridge: `bridges/github.yaml` claims the repository
  `musabeytekin/otr-shop`.

## Secret store `otr-shop`

| Key | Format | Where to get it | Used for |
|---|---|---|---|
| `GITHUB_TOKEN` | GitHub fine-grained personal access token, `github_pat_...` | github.com, Settings, Developer settings, Fine-grained tokens: resource owner `musabeytekin`, repository `otr-shop` only, permissions Contents: read and write, Pull requests: read and write, Issues: read and write (for the `triager` agent; without it that agent can read issues only), Metadata: read | pushing to `otr-shop` (the repository is public; cloning needs no token); the `github` connection (opening pull requests, reviewing them, and, once the token has Issues: read and write, commenting on and labelling issues) |

The panel accepts a pasted `.env` block:

```
GITHUB_TOKEN=
```

The database password, `JWT_SECRET` and `COOKIE_SECRET` are throwaway development values
in `exradius.yaml`: the database exists only inside a run.

## What a run gets

`exradius.yaml` is config version 2. The repository, the workstation, the service and
the connections are defined once at the root; each environment selects from them and
owns its setup, caches, variables, memory and network; each agent names one
environment, and a run gets only what that environment selects.

### Environment `development`

- Used by: `developer` (code changes; pushes a branch and opens a pull request against
  `main`; screenshots of visible changes) and `qa` (tries behaviour in the running
  store, reproduces bugs and reports with screenshots; never changes code).
- Workstation: `development`, built from `docker/workstation.Dockerfile`: Node 24
  (Debian bookworm), npm 11.17.0, the Postgres client, Chromium's system libraries.
- Repositories: `otr-shop` (`main`, push allowed).
- Services: `postgres` (`postgres:17`), the application's own database, reached by the
  application through `DATABASE_URL`. It is not an MCP connection.
- Connections: `github` (opening pull requests), `playwright` (a headless Chromium to
  look at pages and take screenshots).
- Setup: `npm ci`; `medusa db:migrate` (migrations and the demo seed: region, store,
  publishable API key, four products); an admin user for the dashboard; the storefront's
  `.env.local` with the seeded publishable key; Chromium for the browser tool.
- Network: besides its model, the repository and its connections, the agent reaches
  `registry.npmjs.org` (adding or updating npm dependencies) and
  `medusa-public-images.s3.eu-west-1.amazonaws.com` (the demo products' images, so pages
  and screenshots show them). Setup reaches any public host. A refused host shows on the
  task page's Network tab.
- Resources: `environments.development.resources.memory` is `7g`: each run needs a
  cluster node with that much memory free (it waits as "waiting for cluster capacity"
  until one has), and the workstation is killed if it goes over it (measured: `npm ci`
  2.5 GiB, the backend build 2.4 GiB, backend and storefront dev servers with Chromium
  3.3 GiB; the agent may run the application while it builds). Disk: about 1.8 GB per
  run. Setup took about 55 seconds with npm's cache filled and Chromium still to
  download, about 35 seconds with both caches filled; a fully cold setup was not timed
  in this check (the earlier one measured about 1.5 minutes).
- Caches: npm's download store (`~/.npm`) and Playwright's browsers
  (`~/.cache/ms-playwright`) are kept between runs on the project's volume in the cluster
  (the PersistentVolumeClaim `exradius-project-otr-shop` in the runs' namespace, about
  1.2 GB after the first run), kept apart per environment, shared by the runs of this
  environment and never cleaned by Exradius. Deleting the project deletes them; nothing
  else is lost when they are gone, the next run downloads again. Caches filled under the
  version 1 config are not reused: the first run after the migration downloads again.

### Environment `source`

- Used by: `scout` (answers questions by reading the code and its git history; never
  changes code, never starts the application or a database).
- Workstation: Exradius's default image (no Node).
- Repositories: `otr-shop` (`main`). The repository definition is shared, so the
  credential and `push: true` are the same as in `development`; the scout's role, not
  the environment, keeps it from pushing.
- Services: none. Connections: none. Setup: none. Caches: none.
- Network: nothing besides its model and the repository.
- Resources: no `resources.memory`, so the install's default request and no limit
  (measured: 7 MiB for the commands, 9 MB of disk; the agent's own memory is not
  measured locally).

### Environment `review`

- Used by: `reviewer` (reads a pull request's diff in the clone and leaves one comment
  review on it; never changes code, approves or merges).
- Workstation: Exradius's default image.
- Repositories: `otr-shop` (`main`), the shared definition as in `source`.
- Connections: `github` (reading the pull request and posting the review). It is the
  same connection and token the developer uses, so reviews appear under the same GitHub
  account as the pull requests, which is why they are comment reviews: GitHub refuses
  an approval of one's own pull request.
- Services, setup, caches: none. Network: besides its model, the repository and the
  connection, nothing. Resources: the install's default.

### Environment `triage`

- Used by: `triager` (reads GitHub issues of `musabeytekin/otr-shop`, asks for missing
  information, links duplicates, applies existing labels; never closes or assigns).
- Workstation: Exradius's default image.
- Repositories: none. Services, setup, caches: none.
- Connections: `github` (issues).
- Network: besides its model and the connection, nothing. Resources: the install's
  default.

A task that names no agent is given to one of the five by Exradius's agent routing,
which reads each agent's name, role and tools; routing must be set up in the install.

## Maintaining it

Edit `exradius.yaml` or the Dockerfile and push to `main`. Before pushing, the developers
check it locally with the `exradius-project` Claude Code skill, whose `check.sh` runs the
same steps as Verify with Docker: `check.sh --validate` for the whole file, then
`check.sh --environment <name>` for `development`, `source`, `review` and `triage`, one at a time.
`check/start-app.sh` is the script that proved the application starts in `development`;
`check/reviewed.json` records the code commit the config was checked against. After the
push, press Reread and then Verify on the project in Exradius.
