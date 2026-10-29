#!/bin/sh
set -e
if [ -n "$RUN_MIGRATIONS" ] && [ "$RUN_MIGRATIONS" = "true" ]; then
  if [ "$ENVIRONMENT" = "production" ]; then
    alembic upgrade head
  else
    alembic upgrade head || true
  fi
fi
exec "$@"
