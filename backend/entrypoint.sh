#!/bin/sh
set -e
if [ -n "$RUN_MIGRATIONS" ] && [ "$RUN_MIGRATIONS" = "true" ]; then
  alembic upgrade head || true
fi
exec "$@"
