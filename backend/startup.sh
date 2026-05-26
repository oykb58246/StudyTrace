#!/bin/sh
set -e

echo "==> Synchronizing Prisma schema..."
npx prisma db push --accept-data-loss

echo "==> Starting application..."
exec node dist/main
