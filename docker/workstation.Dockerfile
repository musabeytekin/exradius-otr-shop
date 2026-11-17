# workstations.development in exradius.yaml, selected by the development environment:
# what an engineer on the project has installed. The source environment does not use it.
# Node 24 LTS (README; engines >=22.23.4) with the exact npm of packageManager (npm@11.17.0),
# the Postgres client (setup reads the seeded publishable key; agents inspect the database),
# and Chromium's system libraries for the playwright connection (the browser itself is
# installed by a setup command into the home).
FROM node:24-bookworm

RUN npm install -g npm@11.17.0 && npm --version \
 && rm -rf /root/.npm

RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-client \
 && npx -y -p @playwright/mcp@0.0.83 playwright install-deps chromium \
 && rm -rf /root/.npm /var/lib/apt/lists/*
