"""Constantes métier partagées."""

# Compte démo interne — jamais affiché dans le catalogue public.
DEMO_SELLER_PHONE = "+243000000000"

# Compte administrateur par défaut (dev) — panneau /admin
DEV_ADMIN_PHONE = "+243900000001"

# Centre d'aide — messages & notifications utilisateurs
TEAM_SOMBA_TEKA_PHONE = "+243900000099"
TEAM_DISPLAY_NAME = "Centre d'aide SombaTeka"
TEAM_DISPLAY_NAME_SHORT = "Équipe SombaTeka"

# Mots interdits (modération auto — particuliers & officiels)
BANNED_WORDS: tuple[str, ...] = (
    "arme",
    "armes",
    "kalachnikov",
    "ak47",
    "pistolet",
    "fusil",
    "munition",
    "explosif",
    "drogue",
    "cocaïne",
    "cocaine",
    "héroïne",
    "heroine",
    "cannabis",
    "weed",
    "faux billet",
    "fausse monnaie",
    "contrefaçon",
    "contrefacon",
    "bitcoin scam",
    "arnaque",
    "escroc",
    "piratage",
    "hack",
    "organes",
    "enfant",
    "mineur",
)

DELIVERY_METHOD_LABELS: dict[str, str] = {
    "own_courier": "Livraison par mon livreur",
    "pickup_store": "Récupération en boutique / sur place",
}

ESCROW_SYSTEM_MESSAGE = (
    "Bonjour ! Le paiement a été sécurisé par SombaTeka. L'argent est bloqué jusqu'à validation "
    "de l'essayage ou du rendez-vous. Discutez ici des détails (lieu, horaire, livraison). "
    "Code de remise : {handover_code}"
)

ESCROW_CHAT_LOCKED_MESSAGE = (
    "Cette commande est terminée. Le chat est en lecture seule. Contactez le centre d'aide "
    "SombaTeka pour toute réclamation."
)
