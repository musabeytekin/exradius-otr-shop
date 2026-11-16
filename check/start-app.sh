#!/bin/bash
# What notes tell the agent, run once: start the backend and the storefront, prove they
# answer with seeded data, log in to the admin API, and take a screenshot with the browser
# the playwright connection uses.
set -u
cd /work/otr-shop

(cd apps/backend && npm run dev > /tmp/backend.log 2>&1 &)
for i in $(seq 1 120); do
  curl -fs -o /dev/null http://localhost:9000/health && break
  sleep 2
done

KEY=$(sed -n 's/^NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=//p' apps/storefront/.env.local)
echo "--- store API: products"
if ! curl -fsS -H "x-publishable-api-key: $KEY" "http://localhost:9000/store/products?limit=2&fields=title,handle" | head -c 300; then
  echo; echo "--- backend log"; tail -n 60 /tmp/backend.log; exit 1
fi
echo
echo "--- admin login"
TOKEN=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d '{"email":"admin@test.com","password":"supersecret"}' \
  http://localhost:9000/auth/user/emailpass | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
test -n "$TOKEN" || { echo "admin login failed"; tail -n 60 /tmp/backend.log; exit 1; }
curl -fsS -H "authorization: Bearer $TOKEN" "http://localhost:9000/admin/users/me?fields=email" | head -c 200; echo

(cd apps/storefront && npm run dev > /tmp/storefront.log 2>&1 &)
for i in $(seq 1 120); do
  curl -fs -o /dev/null http://localhost:8000/dk && break
  sleep 2
done
echo "--- storefront product page"
if ! curl -fsS http://localhost:8000/dk/products/sweatshirt -o /tmp/product.html; then
  echo "--- storefront log"; tail -n 60 /tmp/storefront.log; exit 1
fi
grep -o '<title>[^<]*</title>' /tmp/product.html
grep -q 'Medusa Sweatshirt' /tmp/product.html || { echo "product title missing"; exit 1; }

echo "--- screenshot"
npx -y -p @playwright/mcp@0.0.83 playwright screenshot --viewport-size=1280,800 --wait-for-timeout=3000 \
  http://localhost:8000/dk/store /work/store.png && test -s /work/store.png && ls -l /work/store.png

echo "--- stop"
pkill -f "medusa develop|cli.js start|next dev|next-server"
sleep 3
echo "left after pkill:"; ps -eo pid,args | grep -E "medusa|next" | grep -v grep | cut -c1-110
curl -fs -o /dev/null http://localhost:9000/health && { echo "backend still up"; exit 1; }
curl -fs -o /dev/null http://localhost:8000/dk && { echo "storefront still up"; exit 1; }
echo "both stopped"
