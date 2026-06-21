#!/usr/bin/env python3
"""Corrige l'enum PostgreSQL userrole (ajoute super_admin)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.schema_patches import ensure_userrole_super_admin
from app.settings import settings


def main() -> None:
    print(f"Base : {settings.database_url}")
    ensure_userrole_super_admin()
    print("Done. Restart the backend and retry /admin/login.")


if __name__ == "__main__":
    main()
