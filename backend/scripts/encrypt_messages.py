"""Migration one-shot : chiffre les contenus de messages encore en clair.

Utilise du SQL brut (text()) pour contourner le TypeDecorator EncryptedText :
on lit/écrit la valeur RÉELLEMENT stockée, pas la version ORM.

Usage (dans le conteneur backend) :
    python -m scripts.encrypt_messages          # dry-run : compte seulement
    python -m scripts.encrypt_messages --apply  # applique le chiffrement
"""
import sys

from sqlalchemy import select, text

from app.db import SessionLocal
from app.models import AdminChatMessage, Message
from app.utils.message_crypto import encrypt_text, is_encrypted

TABLES = {Message: "messages", AdminChatMessage: "admin_chat_messages"}


def main() -> int:
    apply = "--apply" in sys.argv
    db = SessionLocal()
    try:
        total = updated = 0
        for model, table in TABLES.items():
            ids = db.scalars(select(model.id)).all()
            for row_id in ids:
                stored = db.execute(
                    text(f"SELECT content FROM {table} WHERE id = :i"), {"i": row_id}
                ).scalar()
                total += 1
                if is_encrypted(stored):
                    continue
                if apply:
                    db.execute(
                        text(f"UPDATE {table} SET content = :c WHERE id = :i"),
                        {"c": encrypt_text(stored), "i": row_id},
                    )
                updated += 1
        if apply:
            db.commit()
        print(f"{'APPLIQUE' if apply else 'DRY-RUN'} : {updated}/{total} contenus a chiffrer")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
