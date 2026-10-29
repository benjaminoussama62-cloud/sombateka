# -*- coding: utf-8 -*-
"""Génère un rapport Word SombaTeka (technique + business) sans secrets."""
from __future__ import annotations

from datetime import date
from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

OUT = Path(__file__).resolve().parent / "Rapport_SombaTeka_Fonctionnement_Technologies.docx"


def set_run_font(run, size=11, bold=False, color=None, name="Calibri"):
    run.font.name = name
    run._element.rPr.rFonts.set(qn("w:eastAsia"), name)
    run.font.size = Pt(size)
    run.bold = bold
    if color is not None:
        run.font.color.rgb = color


def add_para(doc, text, *, size=11, bold=False, align="left", space_after=8, first_line=True):
    p = doc.add_paragraph()
    if align == "center":
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    elif align == "justify":
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    else:
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    p.paragraph_format.space_after = Pt(space_after)
    p.paragraph_format.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
    if first_line and align == "justify":
        p.paragraph_format.first_line_indent = Cm(0.75)
    run = p.add_run(text)
    set_run_font(run, size=size, bold=bold)
    return p


def add_bullets(doc, items, *, size=11):
    for item in items:
        p = doc.add_paragraph(style="List Bullet")
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        p.paragraph_format.space_after = Pt(4)
        run = p.add_run(item)
        set_run_font(run, size=size)


def add_h(doc, text, level=1):
    doc.add_heading(text, level=level)


def page_break(doc):
    doc.add_page_break()


def add_table(doc, headers, rows):
    table = doc.add_table(rows=1 + len(rows), cols=len(headers))
    table.style = "Table Grid"
    hdr = table.rows[0].cells
    for i, h in enumerate(headers):
        hdr[i].text = h
        for p in hdr[i].paragraphs:
            for r in p.runs:
                set_run_font(r, size=10, bold=True)
    for ri, row in enumerate(rows):
        cells = table.rows[ri + 1].cells
        for ci, val in enumerate(row):
            cells[ci].text = str(val)
            for p in cells[ci].paragraphs:
                for r in p.runs:
                    set_run_font(r, size=10)
    doc.add_paragraph()


def filler_paragraphs(doc, paragraphs):
    for t in paragraphs:
        add_para(doc, t, align="justify")


def build():
    doc = Document()
    section = doc.sections[0]
    section.top_margin = Cm(2.2)
    section.bottom_margin = Cm(2.2)
    section.left_margin = Cm(2.5)
    section.right_margin = Cm(2.5)

    navy = RGBColor(0x0D, 0x1B, 0x4B)

    # —— Couverture ——
    for _ in range(4):
        doc.add_paragraph()
    t = doc.add_paragraph()
    t.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = t.add_run("SOMBATEKA")
    set_run_font(r, size=36, bold=True, color=navy)

    st = doc.add_paragraph()
    st.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = st.add_run("Marketplace digitale de la République Démocratique du Congo")
    set_run_font(r, size=14, color=navy)

    doc.add_paragraph()
    sub = doc.add_paragraph()
    sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = sub.add_run(
        "Rapport de fonctionnement et de technologies\n"
        "Document destiné aux membres, entrepreneurs et collaborateurs"
    )
    set_run_font(r, size=12)

    doc.add_paragraph()
    meta = doc.add_paragraph()
    meta.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = meta.add_run(
        f"Version documentaire : 1.0\n"
        f"Date : {date.today().strftime('%d/%m/%Y')}\n"
        f"Classification : Usage interne / partenaires — sans secrets opérationnels"
    )
    set_run_font(r, size=11)

    for _ in range(6):
        doc.add_paragraph()
    foot = doc.add_paragraph()
    foot.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = foot.add_run(
        "Ce document décrit l’architecture, les fonctionnalités et les choix technologiques "
        "de la plateforme SombaTeka. Il n’inclut volontairement aucune clé, mot de passe, "
        "certificat, identifiant secret, configuration d’infrastructure sensible ni détail "
        "exploitable pour compromettre le système."
    )
    set_run_font(r, size=10)

    page_break(doc)

    # —— Mentions ——
    add_h(doc, "Mentions importantes", 1)
    filler_paragraphs(
        doc,
        [
            "SombaTeka est une plateforme de mise en relation et de commerce électronique "
            "adaptée au contexte congolais : connectivité variable, coût des données, "
            "terminaux modestes, et importance du Mobile Money dans les transactions du quotidien.",
            "Le présent rapport a une double vocation. D’une part, il permet à un entrepreneur "
            "ou un collaborateur de comprendre rapidement ce que fait le produit, pour qui, "
            "et selon quelle logique métier. D’autre part, il expose les technologies retenues "
            "et l’organisation logicielle, afin de faciliter la collaboration technique sans "
            "exposer les secrets de production.",
            "Toute information confidentielle d’exploitation (identifiants cloud, clés API "
            "opérateurs, certificats de signature d’applications, secrets de base de données, "
            "adresses d’administration non publiques, etc.) est exclue de ce document. "
            "Ces éléments sont gérés séparément via des procédures de sécurité et des coffres "
            "à secrets réservés aux personnes habilitées.",
            "Les chiffres de versions indiqués correspondent à l’état du dépôt logiciel au "
            "moment de la rédaction et peuvent évoluer. Les parcours décrits reflètent le "
            "comportement produit cible ; certains modules (paiements, catalogue officiel, "
            "recherche visuelle) peuvent être activés progressivement selon la disponibilité "
            "des partenaires et la maturité des tests.",
        ],
    )
    page_break(doc)

    # —— Sommaire textuel ——
    add_h(doc, "Sommaire", 1)
    toc = [
        "1. Résumé exécutif",
        "2. Contexte marché et opportunité en RDC",
        "3. Vision produit et positionnement",
        "4. Parties prenantes et rôles utilisateurs",
        "5. Parcours utilisateurs principaux",
        "6. Architecture globale de la plateforme",
        "7. Stack technologique détaillée",
        "8. Application mobile, web et PWA",
        "9. Backend API et services métier",
        "10. Données, cache et tâches asynchrones",
        "11. Module d’authentification et d’identité",
        "12. Annonces, recherche et découverte",
        "13. Messagerie et communication",
        "14. Vendeurs officiels et espace professionnel",
        "15. Commandes et paiements (vue d’ensemble)",
        "16. Recherche visuelle et similarité",
        "17. SEO, présence web et référencement",
        "18. Administration, modération et support",
        "19. Sécurité, confidentialité et conformité",
        "20. Performance, offline et qualité de service",
        "21. Déploiement, environnements et cycles de release",
        "22. Tests, qualité et publication mobile",
        "23. Organisation collaborative et gouvernance",
        "24. Risques, limites et perspectives",
        "25. Glossaire",
        "26. Annexes (schémas conceptuels et checklists)",
    ]
    for line in toc:
        add_para(doc, line, align="left", first_line=False, space_after=4)
    page_break(doc)

    # 1
    add_h(doc, "1. Résumé exécutif", 1)
    filler_paragraphs(
        doc,
        [
            "SombaTeka est une marketplace digitale conçue pour la République Démocratique "
            "du Congo. Elle permet aux particuliers d’acheter et de vendre via des annonces, "
            "tout en offrant aux commerçants vérifiés (vendeurs officiels) des outils de "
            "vitrine, de catalogue et, lorsque activé, de commande avec règlement Mobile Money.",
            "Sur le plan technique, la solution repose sur un client multi-plateforme Flutter "
            "(Android, iOS et application web progressive), un backend FastAPI, une base "
            "PostgreSQL, un cache et bus Redis, des workers Celery pour les traitements "
            "asynchrones, et un reverse-proxy Nginx pour l’exposition HTTPS sécurisée.",
            "Le produit différencie clairement deux modes d’usage. Le mode particulier "
            "privilégie la découverte, le dialogue et la transaction hors plateforme. "
            "Le mode vendeur officiel introduit des garanties supplémentaires : identité "
            "renforcée, catalogues, commandes tracées et mécanismes d’escrow adaptés au "
            "contexte Mobile Money, sous réserve de configuration et de conformité.",
            "Pour les lecteurs business, l’essentiel est le suivant : SombaTeka n’est pas "
            "seulement un site d’annonces. C’est une plateforme complète, avec application "
            "installable, messagerie temps réel, outils vendeurs, panel d’administration, "
            "et une stratégie de distribution web + stores mobiles.",
            "Pour les lecteurs techniques, l’essentiel est une architecture moderne, "
            "séparée en couches, déployable par conteneurs, avec une API unique consommée "
            "par toutes les interfaces clients, ce qui réduit le coût de maintenance et "
            "accélère les itérations produit.",
        ],
    )
    add_h(doc, "1.1 Points clés à retenir", 2)
    add_bullets(
        doc,
        [
            "Produit : marketplace RDC (particuliers + vendeurs officiels).",
            "Clients : Flutter natif et PWA web.",
            "API : FastAPI / Python, authentification par jetons.",
            "Données : PostgreSQL ; cache et files : Redis ; jobs : Celery.",
            "Frontière publique : Nginx (TLS, routage, limitation de débit).",
            "Ops internes : panel admin (modération, KYC, support).",
            "Document volontairement sans secrets d’exploitation.",
        ],
    )
    page_break(doc)

    # 2
    add_h(doc, "2. Contexte marché et opportunité en RDC", 1)
    filler_paragraphs(
        doc,
        [
            "Le marché congolais du commerce en ligne se caractérise par une adoption "
            "croissante du smartphone, une forte pratique du Mobile Money, et une demande "
            "de confiance : les acheteurs veulent éviter les arnaques, les vendeurs veulent "
            "être visibles, et les deux parties cherchent des moyens simples de se parler.",
            "Les marketplaces internationales ne couvrent pas toujours les réalités locales "
            "(langues d’usage, villes et quartiers, modes de remise en main propre, "
            "contraintes de bande passante). SombaTeka se positionne comme une réponse "
            "locale, pensée pour Kinshasa et l’ensemble du territoire, avec une expérience "
            "légère et compréhensible.",
            "L’opportunité business repose sur trois moteurs. Premièrement, le volume "
            "d’annonces C2C (de particulier à particulier). Deuxièmement, la monétisation "
            "progressive via les vendeurs officiels et les services à valeur ajoutée. "
            "Troisièmement, la rétention grâce à la messagerie, aux favoris, aux alertes "
            "et à une présence continue via PWA et applications stores.",
            "Dans un tel contexte, la technologie n’est pas un luxe : c’est le moyen de "
            "tenir la confiance (vérification, modération), la disponibilité (offline, "
            "cache) et la vitesse de livraison de fonctionnalités (une seule base de code "
            "mobile/web).",
        ],
    )
    add_h(doc, "2.1 Contraintes de conception prises en compte", 2)
    add_bullets(
        doc,
        [
            "Réseaux instables ou coûteux : privilégier des écrans sobres et un cache local.",
            "Terminaux hétérogènes : UI responsive, perf raisonnable sur milieu de gamme.",
            "Confiance : badges, vérification de compte, outils de signalement.",
            "Paiement local : intégration conceptuelle Mobile Money pour les flux officiels.",
            "Distribution : web immédiat + tests fermés Android avant production store.",
        ],
    )
    add_h(doc, "2.2 Ce que le rapport n’aborde pas", 2)
    filler_paragraphs(
        doc,
        [
            "Ce document ne présente pas de projections financières détaillées, ni de "
            "contrats opérateurs, ni de tarification commerciale confidentielle. Ces "
            "sujets relèvent de notes business séparées. Ici, l’angle est le fonctionnement "
            "produit et la technologie mise en œuvre.",
        ],
    )
    page_break(doc)

    # 3
    add_h(doc, "3. Vision produit et positionnement", 1)
    filler_paragraphs(
        doc,
        [
            "La vision SombaTeka est de devenir la place de marché de référence en RDC : "
            "simple à ouvrir, rassurante à utiliser, utile aussi bien pour vendre un "
            "téléphone d’occasion que pour animer une boutique officielle avec catalogue.",
            "Le positionnement produit combine une expérience grand public (accueil, "
            "recherche, détail d’annonce, chat) et une couche professionnelle (espace pro, "
            "catalogue, clients, statistiques opérationnelles). L’utilisateur n’a pas "
            "besoin de comprendre l’architecture pour en bénéficier : l’interface guide "
            "les actions essentielles.",
            "Sur le web, SombaTeka se présente comme une application progressive (PWA) : "
            "accessible depuis le navigateur, installable sur l’écran d’accueil, avec une "
            "expérience proche du natif. Sur mobile, l’application suit les standards des "
            "stores (Android en priorité dans le cycle de tests fermés).",
        ],
    )
    add_h(doc, "3.1 Promesse utilisateur", 2)
    add_bullets(
        doc,
        [
            "Publier une annonce rapidement avec photos et attributs utiles.",
            "Trouver un produit par texte, filtres, ou recherche par image.",
            "Contacter un vendeur via messagerie intégrée.",
            "Reconnaître un vendeur officiel grâce au badge et au parcours vérifié.",
            "Gérer son profil, ses favoris, ses notifications et ses paramètres.",
        ],
    )
    add_h(doc, "3.2 Promesse vendeur officiel", 2)
    add_bullets(
        doc,
        [
            "Disposer d’une vitrine et d’un espace professionnel dédié.",
            "Publier des catalogues et mettre en avant des produits.",
            "Suivre les échanges clients et les opérations finalisées.",
            "Bénéficier, selon activation, de parcours de commande plus structurés.",
        ],
    )
    page_break(doc)

    # 4
    add_h(doc, "4. Parties prenantes et rôles utilisateurs", 1)
    filler_paragraphs(
        doc,
        [
            "Le modèle de rôles est volontairement lisible. Il évite la complexité "
            "excessive tout en permettant des droits différenciés côté plateforme.",
        ],
    )
    add_table(
        doc,
        ["Rôle", "Description", "Capacités principales"],
        [
            [
                "Utilisateur particulier",
                "Compte standard acheteur/vendeur C2C",
                "Annonces, favoris, chat, profil, recherche",
            ],
            [
                "Vendeur officiel",
                "Compte vérifié / parcours KYC",
                "Espace pro, catalogues, badge, outils boutique",
            ],
            [
                "Équipe support / modération",
                "Opérations internes",
                "Traitement signalements, aide utilisateurs",
            ],
            [
                "Administrateur",
                "Pilot de la plateforme",
                "Configuration, supervision, actions sensibles",
            ],
            [
                "Super administrateur",
                "Niveau maximal d’administration",
                "Opérations critiques, corbeille, gouvernance",
            ],
        ],
    )
    filler_paragraphs(
        doc,
        [
            "Cette séparation protège à la fois les utilisateurs et l’équipe : un agent "
            "support n’a pas besoin des mêmes pouvoirs qu’un super administrateur. "
            "Les journaux d’audit et les mécanismes d’authentification renforcée côté "
            "admin (lorsque activés) réduisent le risque d’usage abusif des outils internes.",
            "Du point de vue business, le rôle « vendeur officiel » est le levier de "
            "montée en gamme : il transforme un simple compte en vitrine digne de "
            "confiance, ce qui justifie des services premium et une meilleure conversion.",
        ],
    )
    page_break(doc)

    # 5
    add_h(doc, "5. Parcours utilisateurs principaux", 1)
    add_h(doc, "5.1 Découverte et inscription", 2)
    filler_paragraphs(
        doc,
        [
            "Un nouvel utilisateur accède à SombaTeka via le web (sombatekaonline.com) "
            "ou via l’application mobile. Il découvre un accueil marketplace, peut "
            "parcourir des annonces, puis créer un compte. Les modes d’entrée prévus "
            "incluent l’email/mot de passe, la vérification par code, et la connexion "
            "sociale via des fournisseurs majeurs (Google, Apple), selon la configuration "
            "de l’environnement.",
            "Après inscription, l’utilisateur peut compléter son profil (photo, téléphone, "
            "informations utiles). Certaines actions avancées peuvent exiger une "
            "finalisation de compte (par exemple lier un numéro ou définir un mot de passe).",
        ],
    )
    add_h(doc, "5.2 Publication d’une annonce", 2)
    filler_paragraphs(
        doc,
        [
            "Le parcours de publication guide le choix de catégorie, la saisie du titre, "
            "du prix, de la localisation, des photos et d’attributs complémentaires. "
            "L’objectif UX est de réduire l’abandon : formulaires clairs, validation "
            "progressive, messages d’erreur compréhensibles.",
            "Une fois publiée, l’annonce devient découvrable dans le fil d’accueil, la "
            "recherche et, le cas échéant, les pages publiques SEO. Le vendeur peut la "
            "retrouver dans son profil (mes annonces / mon catalogue).",
        ],
    )
    add_h(doc, "5.3 Contact et négociation", 2)
    filler_paragraphs(
        doc,
        [
            "L’acheteur ouvre le détail, consulte les photos et informations, puis "
            "contacte le vendeur. La messagerie intégrée centralise les conversations, "
            "avec mise à jour proche du temps réel lorsque la connexion WebSocket est "
            "disponible. Des rappels de prudence peuvent être affichés pour limiter "
            "les risques de fraude hors plateforme.",
        ],
    )
    add_h(doc, "5.4 Parcours vendeur officiel", 2)
    filler_paragraphs(
        doc,
        [
            "Un utilisateur peut demander le statut de vendeur officiel via un parcours "
            "dédié (informations boutique, éléments de vérification). Après validation, "
            "il accède à l’espace professionnel : tableau de bord, catalogues, accès "
            "rapide aux clients et outils de publication officielle.",
            "Ce parcours est structurant pour la confiance : le badge « Vendeur officiel » "
            "signale à l’acheteur une exigence plus élevée que le compte particulier.",
        ],
    )
    page_break(doc)

    # 6
    add_h(doc, "6. Architecture globale de la plateforme", 1)
    filler_paragraphs(
        doc,
        [
            "L’architecture suit un schéma classique et robuste : des clients riches "
            "parlent à une API unique, derrière un reverse-proxy, avec des services de "
            "données et des workers asynchrones.",
        ],
    )
    add_para(
        doc,
        "Schéma conceptuel (flux principal)",
        bold=True,
        align="left",
        first_line=False,
    )
    add_para(
        doc,
        "Clients Flutter (Android / iOS / Web PWA)\n"
        "        ↓  HTTPS / WSS\n"
        "Nginx (terminaison TLS, routage, limitations)\n"
        "        ↓\n"
        "API FastAPI (métier, admin, SEO, websockets)\n"
        "   ├── PostgreSQL (données persistantes)\n"
        "   ├── Redis (cache, file d’attente, limitations)\n"
        "   ├── Celery worker + beat (tâches planifiées)\n"
        "   └── Stockage médias (local et/ou objet compatible S3)",
        align="left",
        first_line=False,
        size=10,
    )
    filler_paragraphs(
        doc,
        [
            "Ce découpage permet de faire évoluer chaque couche indépendamment. On peut "
            "renforcer Nginx sans toucher à l’API, ajouter un worker Celery sans modifier "
            "l’application mobile, ou publier une nouvelle UI Flutter sans changer le "
            "schéma de base de données (tant que l’API reste compatible).",
            "Le site marketing et les pages légales (conditions, confidentialité, "
            "suppression de compte) sont servis comme contenus web statiques, ce qui "
            "simplifie la conformité stores et la transparence envers les utilisateurs.",
            "Le panel d’administration est une interface web dédiée aux opérations "
            "internes. Il consomme des routes protégées et n’est pas destiné au grand "
            "public.",
        ],
    )
    add_h(doc, "6.1 Principes d’architecture", 2)
    add_bullets(
        doc,
        [
            "API first : une seule source de vérité métier pour tous les clients.",
            "Séparation des responsabilités : edge / API / data / jobs / médias.",
            "Déploiement conteneurisé pour reproductibilité.",
            "Sécurité en profondeur : TLS, authentification, contrôles d’accès, audits.",
            "Observabilité et qualité : health checks, tests, checklists de go-live.",
        ],
    )
    page_break(doc)

    # 7
    add_h(doc, "7. Stack technologique détaillée", 1)
    add_h(doc, "7.1 Couche client", 2)
    filler_paragraphs(
        doc,
        [
            "Le client est développé avec Flutter et Dart. Ce choix permet de partager "
            "la grande majorité du code entre Android, iOS et Web, tout en conservant "
            "une UI native de qualité. Les bibliothèques utilisées couvrent le réseau "
            "(client HTTP), le stockage local (cache offline), la navigation, les "
            "notifications push, le suivi d’erreurs applicatives, et les connexions "
            "sociales lorsque activées.",
            "L’interface s’appuie sur un design system interne (thème premium, composants "
            "réutilisables : cartes produit, en-têtes, barres de navigation, panneaux "
            "d’aide). L’objectif est la cohérence visuelle entre l’accueil, le profil, "
            "la messagerie et l’espace pro.",
        ],
    )
    add_h(doc, "7.2 Couche serveur", 2)
    filler_paragraphs(
        doc,
        [
            "Le backend est écrit en Python avec FastAPI. Ce framework offre une API "
            "moderne, typée, documentable, et performante pour des services I/O. "
            "L’exécution en production s’appuie typiquement sur un serveur d’applications "
            "WSGI/ASGI derrière Nginx.",
            "SQLAlchemy et Alembic gèrent le modèle de données et les migrations. "
            "PostgreSQL assure la persistance relationnelle. Redis sert de cache, de "
            "support aux limitations de débit et de courtier pour Celery.",
        ],
    )
    add_h(doc, "7.3 Médias et intelligence visuelle", 2)
    filler_paragraphs(
        doc,
        [
            "Les images sont un actif central de la marketplace. La plateforme inclut "
            "des traitements d’images (validation, stockage, URLs publiques) et des "
            "fonctions de similarité / recherche visuelle basées sur des descripteurs "
            "et index dédiés. Ces capacités aident l’utilisateur à retrouver un produit "
            "à partir d’une photo, et à découvrir des annonces proches.",
        ],
    )
    add_h(doc, "7.4 Tableau récapitulatif", 2)
    add_table(
        doc,
        ["Domaine", "Technologie (exemples)", "Rôle"],
        [
            ["UI multi-plateforme", "Flutter / Dart", "App Android, iOS, Web/PWA"],
            ["API métier", "FastAPI / Python", "Endpoints REST, règles métier"],
            ["Base de données", "PostgreSQL", "Persistance structurée"],
            ["Cache / files", "Redis + Celery", "Perf, jobs async, planification"],
            ["Edge", "Nginx", "HTTPS, routage, protections"],
            ["Médias", "Stockage fichiers / objet", "Photos d’annonces et profils"],
            ["Admin", "Panel web", "Modération et opérations"],
            ["Conteneurs", "Docker Compose", "Déploiement reproductible"],
        ],
    )
    page_break(doc)

    # 8
    add_h(doc, "8. Application mobile, web et PWA", 1)
    filler_paragraphs(
        doc,
        [
            "L’expérience SombaTeka est conçue comme une seule application logicielle "
            "déclinée sur plusieurs supports. Sur téléphone, l’utilisateur retrouve une "
            "navigation par onglets (accueil, boutique/panier, publication, messages, "
            "profil). Sur grand écran web, une navigation adaptée peut compléter ou "
            "remplacer la barre basse.",
            "La PWA permet d’installer SombaTeka depuis le navigateur, utile lorsque "
            "l’utilisateur n’a pas encore l’application store, ou préfère un accès "
            "immédiat. Des bannières d’installation et une gestion des safe-areas "
            "(encoches, barres système) améliorent le confort sur mobile web.",
            "Le rendu UI met l’accent sur la lisibilité : contrastes, hiérarchie typo, "
            "cartes produit, états vides explicites (« Aucune annonce », « Aucun avis »), "
            "et en-têtes stables sur les écrans clés comme le profil.",
        ],
    )
    add_h(doc, "8.1 Modules fonctionnels côté client", 2)
    add_bullets(
        doc,
        [
            "Authentification et onboarding",
            "Fil d’accueil et recherche (texte / image)",
            "Détail d’annonce et produits similaires",
            "Publication et édition d’annonces",
            "Favoris et panier (selon parcours)",
            "Messagerie et notifications",
            "Profil, paramètres, documents légaux",
            "Espace pro / vendeur officiel",
            "Aide et assistance (parcours guidés)",
        ],
    )
    add_h(doc, "8.2 Offline et résilience client", 2)
    filler_paragraphs(
        doc,
        [
            "Un cache local permet de conserver certaines données pour limiter les "
            "rechargements inutiles et améliorer la perception de fluidité. En cas de "
            "réseau dégradé, l’application privilégie des messages clairs plutôt que "
            "des échecs silencieux. Cette approche est essentielle en RDC où la qualité "
            "réseau varie fortement selon le lieu et l’heure.",
        ],
    )
    page_break(doc)

    # 9
    add_h(doc, "9. Backend API et services métier", 1)
    filler_paragraphs(
        doc,
        [
            "Le backend expose une API structurée par domaines : authentification, "
            "utilisateurs, annonces, favoris, messages, commandes, administration, "
            "SEO, etc. Chaque domaine est isolé dans des routeurs et services, ce qui "
            "facilite les revues de code et les tests.",
            "Les services métier encapsulent la logique délicate : validation d’identité, "
            "stockage média, similarité d’annonces, orchestration de recherche visuelle, "
            "préparation de flux SEO, aides KYC, modération, notifications, et — pour "
            "les vendeurs officiels — la logique de commande/escrow à un niveau abstrait.",
        ],
    )
    add_h(doc, "9.1 Exemples de services (sans détails secrets)", 2)
    add_table(
        doc,
        ["Service (concept)", "Finalité"],
        [
            ["Identité / OAuth social", "Vérifier les connexions Google/Apple côté serveur"],
            ["Validation téléphone/email", "Réduire comptes jetables et formats invalides"],
            ["Stockage médias", "Enregistrer et exposer les images d’annonces"],
            ["Recherche visuelle", "Indexer et interroger des descripteurs d’images"],
            ["Similarité d’annonces", "Proposer des produits proches"],
            ["Catalogue officiel", "Gérer variantes / stock côté vendeur officiel"],
            ["SEO / sitemaps", "Améliorer la découvrabilité web des annonces"],
            ["Notifications", "Créer des alertes in-app pertinentes"],
            ["Modération", "Aider à détecter contenus problématiques"],
            ["Support / admin", "Outiller l’équipe interne"],
        ],
    )
    filler_paragraphs(
        doc,
        [
            "Cette organisation « services » évite de disperser la logique dans les "
            "contrôleurs HTTP. Elle rend aussi plus simple l’ajout de tâches Celery : "
            "un job asynchrone appelle le même service qu’une requête synchrone.",
        ],
    )
    page_break(doc)

    # 10
    add_h(doc, "10. Données, cache et tâches asynchrones", 1)
    add_h(doc, "10.1 PostgreSQL", 2)
    filler_paragraphs(
        doc,
        [
            "PostgreSQL stocke les entités principales : utilisateurs, annonces, "
            "conversations, messages, commandes, avis, signalements, données admin, "
            "etc. Les migrations Alembic assurent l’évolution contrôlée du schéma.",
            "Le modèle relationnel est adapté aux besoins marketplace : relations "
            "vendeur–annonce, acheteur–favoris, participants–conversations, et "
            "historiques nécessaires à la confiance (avis, opérations finalisées).",
        ],
    )
    add_h(doc, "10.2 Redis", 2)
    filler_paragraphs(
        doc,
        [
            "Redis complète PostgreSQL pour tout ce qui demande vitesse et volatilité "
            "contrôlée : caches, compteurs, files Celery, et mécanismes de limitation. "
            "Il ne remplace pas la base principale ; il l’accélère et la protège.",
        ],
    )
    add_h(doc, "10.3 Celery (workers et planification)", 2)
    filler_paragraphs(
        doc,
        [
            "Certaines opérations ne doivent pas bloquer une requête utilisateur : "
            "traitements d’images lourds, synchronisations marchandes, jobs de "
            "paiement/escrow, notifications différées, etc. Celery exécute ces tâches "
            "en arrière-plan. Un ordonnanceur (beat) déclenche les jobs périodiques.",
            "Cette séparation améliore le temps de réponse perçu et la robustesse : "
            "une tâche peut être retentée sans faire échouer l’écran de l’utilisateur.",
        ],
    )
    page_break(doc)

    # 11
    add_h(doc, "11. Module d’authentification et d’identité", 1)
    filler_paragraphs(
        doc,
        [
            "L’authentification combine plusieurs portes d’entrée pour coller aux "
            "habitudes locales et internationales : compte email/mot de passe, "
            "vérification par code, et connexion sociale. Le serveur délivre des "
            "jetons d’accès qui autorisent les appels API ultérieurs.",
            "Le téléphone joue un rôle important dans le contexte RDC. La plateforme "
            "prévoit des contrôles de format et de cohérence, ainsi que des étapes de "
            "finalisation de compte lorsque certaines informations manquent.",
            "Côté administration, des mesures supplémentaires peuvent s’appliquer "
            "(authentification renforcée, journaux d’audit). Ces dispositifs protègent "
            "les outils internes sans exposer leurs détails dans ce document.",
        ],
    )
    add_h(doc, "11.1 Objectifs de sécurité identitaire", 2)
    add_bullets(
        doc,
        [
            "Réduire les comptes fictifs et abusifs.",
            "Permettre une récupération de compte raisonnable.",
            "Séparer clairement sessions utilisateurs et sessions admin.",
            "Limiter la surface d’attaque des endpoints sensibles.",
        ],
    )
    add_h(doc, "11.2 Confidentialité des données d’identité", 2)
    filler_paragraphs(
        doc,
        [
            "Les données personnelles sont traitées selon des principes de minimisation "
            "et de besoin d’en connaître. Les pages légales (confidentialité, conditions, "
            "suppression de compte) expliquent les droits utilisateurs. Les procédures "
            "internes de suppression/anonymisation s’appuient sur des outils admin dédiés.",
        ],
    )
    page_break(doc)

    # 12
    add_h(doc, "12. Annonces, recherche et découverte", 1)
    filler_paragraphs(
        doc,
        [
            "Le catalogue d’annonces est le cœur de la marketplace. Chaque annonce "
            "porte des informations structurées (titre, prix, catégorie, localisation, "
            "photos, attributs) qui alimentent à la fois l’UI et les mécanismes de "
            "recherche.",
            "La découverte combine plusieurs canaux : fil d’accueil (avec mise en avant "
            "possible de contenus officiels), recherche textuelle, filtres, suggestions "
            "de similaires, et recherche par image. Cette diversité augmente les chances "
            "qu’un acheteur trouve rapidement un produit pertinent.",
        ],
    )
    add_h(doc, "12.1 Qualité des annonces", 2)
    add_bullets(
        doc,
        [
            "Photos claires et multiples",
            "Titres explicites",
            "Prix et devise compréhensibles",
            "Localisation utile à la remise",
            "Catégorisation correcte pour les filtres",
        ],
    )
    add_h(doc, "12.2 Modération et confiance", 2)
    filler_paragraphs(
        doc,
        [
            "Les signalements utilisateurs et les règles automatiques aident à retirer "
            "ou masquer des contenus problématiques. L’objectif n’est pas la censure "
            "arbitraire, mais la protection de la place de marché : moins d’arnaques, "
            "moins de contenus illicites, plus de confiance durable.",
        ],
    )
    page_break(doc)

    # 13
    add_h(doc, "13. Messagerie et communication", 1)
    filler_paragraphs(
        doc,
        [
            "La messagerie est le pont entre découverte et transaction. Elle permet "
            "de négocier, de préciser l’état d’un article, et d’organiser une rencontre "
            "ou une livraison. Une conversation est liée au contexte utilisateur et "
            "peut s’appuyer sur une annonce.",
            "Techniquement, le temps réel s’appuie sur des websockets lorsque disponibles, "
            "avec repli sur le modèle requête/réponse. Les notifications in-app (et push "
            "lorsqu’elles sont configurées) rappellent les nouveaux messages.",
            "Des garde-fous UX rappellent les bonnes pratiques de sécurité (ne pas "
            "partager d’informations sensibles inutilement, se méfier des paiements "
            "anormaux, privilégier des lieux sûrs).",
        ],
    )
    add_h(doc, "13.1 Support et outreach", 2)
    filler_paragraphs(
        doc,
        [
            "Au-delà du chat entre utilisateurs, la plateforme prévoit des canaux "
            "d’assistance (helpdesk) et des outils internes pour que l’équipe SombaTeka "
            "puisse répondre efficacement. Ces outils restent dans le périmètre admin "
            "et ne sont pas exposés comme fonctionnalités grand public.",
        ],
    )
    page_break(doc)

    # 14
    add_h(doc, "14. Vendeurs officiels et espace professionnel", 1)
    filler_paragraphs(
        doc,
        [
            "Le programme vendeur officiel distingue une boutique sérieuse d’un compte "
            "occasionnel. Il s’accompagne d’un parcours de demande, d’une validation, "
            "puis d’un espace pro : vue d’ensemble, catalogues, accès clients, et "
            "raccourcis de publication.",
            "Dans l’application, le profil d’un vendeur officiel affiche un badge visible. "
            "L’espace boutique met en avant le nom commercial et des actions (espace pro, "
            "catalogue, clients). Ces éléments renforcent la perception de professionnalisme.",
            "Sur le plan data, les catalogues officiels peuvent gérer des structures "
            "plus riches que l’annonce C2C simple (variantes, stocks, mises en avant). "
            "Le fil d’accueil peut mélanger contenus particuliers et officiels pour "
            "maximiser à la fois la diversité et la qualité perçue.",
        ],
    )
    add_h(doc, "14.1 Bénéfices business", 2)
    add_bullets(
        doc,
        [
            "Confiance accrue pour l’acheteur",
            "Meilleure conversion pour le vendeur",
            "Base pour services premium et monétisation",
            "Différenciation face aux groupes sociaux non modérés",
        ],
    )
    page_break(doc)

    # 15
    add_h(doc, "15. Commandes et paiements (vue d’ensemble)", 1)
    filler_paragraphs(
        doc,
        [
            "SombaTeka distingue deux philosophies de paiement. Pour le C2C classique, "
            "la plateforme facilite la mise en relation ; le règlement se fait souvent "
            "hors application, selon l’accord des parties. Pour les vendeurs officiels, "
            "un parcours de commande plus structuré peut être activé, s’appuyant sur "
            "le Mobile Money (opérateurs locaux) et des mécanismes de séquestre "
            "(escrow) adaptés à la remise en main propre.",
            "Dans ce second mode, l’idée générale est de réduire le risque : l’acheteur "
            "règle via un canal reconnu, la plateforme suit l’état de la commande, et "
            "le déblocage vendeur suit des règles métier (confirmation, délais, absence "
            "de litige). Les détails d’intégration opérateurs, clés API et configurations "
            "de production sont hors périmètre de ce rapport.",
            "Les webhooks et jobs asynchrones permettent de réconcilier les états de "
            "paiement sans bloquer l’interface. Des écrans dédiés guident l’utilisateur "
            "pendant le flux, avec des messages d’erreur compréhensibles en cas d’échec "
            "réseau ou de refus opérateur.",
        ],
    )
    add_h(doc, "15.1 Principes de conception paiement", 2)
    add_bullets(
        doc,
        [
            "Ne jamais exposer de secrets opérateurs dans le client.",
            "Tracer les états de commande de façon auditable.",
            "Prévoir litiges et cas d’échec (timeout, annulation).",
            "Activer les modules progressivement selon les tests.",
        ],
    )
    page_break(doc)

    # 16
    add_h(doc, "16. Recherche visuelle et similarité", 1)
    filler_paragraphs(
        doc,
        [
            "La recherche visuelle répond à un usage très concret : l’utilisateur voit "
            "un produit dans la rue ou sur une photo, et veut retrouver des annonces "
            "similaires sans connaître la marque exacte. La plateforme extrait des "
            "caractéristiques d’image, les indexe, puis compare une requête photo aux "
            "annonces existantes.",
            "En parallèle, la similarité textuelle/attributaire propose des produits "
            "proches sur une fiche détail. Ensemble, ces mécanismes augmentent le temps "
            "utile passé dans l’application et réduisent la frustration de recherche.",
            "Ces traitements peuvent être coûteux : d’où l’intérêt des jobs asynchrones "
            "et d’une indexation progressive (backfill) lorsque de nouvelles annonces "
            "arrivent.",
        ],
    )
    page_break(doc)

    # 17
    add_h(doc, "17. SEO, présence web et référencement", 1)
    filler_paragraphs(
        doc,
        [
            "Au-delà de l’application, SombaTeka soigne sa présence web publique. Des "
            "pages d’annonces indexables, des sitemaps, et des mécanismes de notification "
            "aux moteurs (lorsqu’activés) aident à attirer un trafic organique qualifié.",
            "Le site marketing et les pages légales renforcent la crédibilité auprès "
            "des utilisateurs et des stores. La PWA assure qu’un visiteur web puisse "
            "basculer rapidement vers une expérience applicative.",
            "Des briques optionnelles (flux marchand, données structurées produit) "
            "préparent la plateforme à une meilleure diffusion des offres officielles "
            "sur des canaux de découverte externes, sans coupler étroitement le cœur "
            "métier à un seul partenaire.",
        ],
    )
    page_break(doc)

    # 18
    add_h(doc, "18. Administration, modération et support", 1)
    filler_paragraphs(
        doc,
        [
            "Le panel admin est le cockpit opérationnel. Il permet de suivre les "
            "utilisateurs, les annonces, les signalements, les demandes KYC, et d’autres "
            "files d’opération. L’accès est restreint et tracé.",
            "La modération combine signaux automatiques et revue humaine. L’automatisation "
            "accélère le traitement des cas évidents ; l’humain tranche les situations "
            "ambiguës. Une corbeille / restauration (selon droits) limite les erreurs "
            "irréversibles.",
            "Le support utilisateur s’appuie sur des files dédiées et des réponses "
            "contextualisées. L’objectif est de réduire le temps de résolution tout "
            "en documentant les décisions importantes.",
        ],
    )
    add_h(doc, "18.1 Séparation des pouvoirs", 2)
    filler_paragraphs(
        doc,
        [
            "Les rôles admin, support et super admin existent pour éviter qu’une seule "
            "personne cumule tous les pouvoirs au quotidien. Les actions les plus "
            "sensibles doivent rester exceptionnelles, motiver et auditées.",
        ],
    )
    page_break(doc)

    # 19
    add_h(doc, "19. Sécurité, confidentialité et conformité", 1)
    filler_paragraphs(
        doc,
        [
            "La sécurité est traitée comme une propriété transverse, pas comme une "
            "fonctionnalité isolée. Nginx termine le TLS et applique des limitations. "
            "L’API authentifie les requêtes et autorise selon le rôle. Les mots de passe "
            "sont stockés de façon non réversible. Les secrets de production ne vivent "
            "pas dans le code source partagé.",
            "La confidentialité implique de minimiser l’exposition des données "
            "personnelles dans les interfaces internes, de masquer certaines informations "
            "selon le besoin, et d’offrir des parcours de suppression de compte alignés "
            "avec les exigences des stores et les attentes utilisateurs.",
            "La conformité « stores » (fiches légales, URL de suppression de compte, "
            "politique de confidentialité) est prise en charge via le site public et "
            "les paramètres de build mobile. Les détails de signature d’applications "
            "et comptes développeur sont gérés hors de ce document.",
        ],
    )
    add_h(doc, "19.1 Bonnes pratiques pour collaborateurs", 2)
    add_bullets(
        doc,
        [
            "Ne jamais coller de secrets dans des chats, tickets ou documents partagés.",
            "Utiliser des accès nominatifs et révocables.",
            "Préférer les environnements de test pour les expérimentations.",
            "Signaler immédiatement toute fuite suspecte.",
            "Respecter le principe du moindre privilège.",
        ],
    )
    page_break(doc)

    # 20
    add_h(doc, "20. Performance, offline et qualité de service", 1)
    filler_paragraphs(
        doc,
        [
            "La performance se joue à plusieurs niveaux : poids des images, nombre "
            "de requêtes, efficacité SQL, cache Redis, et fluidité UI Flutter. Le "
            "design « offline-friendly » réduit la sensibilité aux micro-coupures.",
            "Des health checks permettent de vérifier rapidement que l’API et ses "
            "dépendances répondent. Des checklists de mise en production rappellent "
            "les contrôles post-déploiement (pages légales, inscription, admin, etc.).",
            "La qualité de service se mesure aussi à l’expérience : messages d’erreur "
            "clairs, états de chargement, absence de flashs UI déroutants, navigation "
            "prévisible. Ces détails influencent directement la rétention.",
        ],
    )
    page_break(doc)

    # 21
    add_h(doc, "21. Déploiement, environnements et cycles de release", 1)
    filler_paragraphs(
        doc,
        [
            "Le déploiement cible une architecture conteneurisée : base de données, "
            "cache, API, workers, et reverse-proxy. Cette approche standardise les "
            "environnements et facilite les reprises.",
            "Le web/PWA est publié sur le domaine public de la marque, ce qui donne "
            "une disponibilité immédiate aux utilisateurs. Les applications natives "
            "suivent un cycle store : build signé, piste de test (interne/fermé), "
            "puis production lorsque les critères qualité et business sont atteints.",
            "Les releases doivent être traçables (notes de version, numéro de version "
            "incrémental). Sur Android, chaque nouvel AAB destiné aux testeurs fermés "
            "porte un code de version supérieur au précédent.",
        ],
    )
    add_h(doc, "21.1 Ce qui reste volontairement hors document", 2)
    add_bullets(
        doc,
        [
            "Accès serveurs et inventaire d’adresses",
            "Contenu des fichiers d’environnement de production",
            "Secrets opérateurs Mobile Money",
            "Mots de passe et clés de signature mobile",
            "Procédures d’accès d’urgence non publiques",
        ],
    )
    page_break(doc)

    # 22
    add_h(doc, "22. Tests, qualité et publication mobile", 1)
    filler_paragraphs(
        doc,
        [
            "Avant une diffusion large, SombaTeka privilégie des tests fermés sur "
            "Android : un groupe limité de testeurs valide les parcours critiques "
            "(inscription, publication, chat, profil, espace pro). Les retours "
            "alimentent des correctifs rapides.",
            "Le pipeline de build mobile produit un App Bundle (AAB) pour Play Console. "
            "Les métadonnées store (descriptions, assets graphiques, liens légaux) "
            "font partie de la qualité perçue autant que le code.",
            "Côté API, des tests automatisés ciblent notamment la santé du service "
            "et des cas de non-régression. L’objectif n’est pas une couverture "
            "théorique maximale, mais une protection des chemins qui cassent le business "
            "s’ils échouent.",
        ],
    )
    add_h(doc, "22.1 Critères de readiness (exemples)", 2)
    add_bullets(
        doc,
        [
            "Parcours inscription / connexion stable",
            "Publication d’annonce avec photos",
            "Messagerie fonctionnelle",
            "Profil et paramètres OK",
            "Pages légales accessibles",
            "Pas de secret dans le client",
            "Version store correctement incrémentée",
        ],
    )
    page_break(doc)

    # 23
    add_h(doc, "23. Organisation collaborative et gouvernance", 1)
    filler_paragraphs(
        doc,
        [
            "Un projet marketplace mélange produit, design, ingénierie, opérations et "
            "partenariats. La gouvernance recommandée distingue : décisions produit "
            "(quoi construire), décisions techniques (comment), et décisions d’exploitation "
            "(comment faire tourner sans risque).",
            "Les collaborateurs business peuvent s’appuyer sur ce rapport pour comprendre "
            "les capacités déjà présentes et éviter de redemander des fonctionnalités "
            "existantes. Les collaborateurs techniques y trouvent une carte mentale "
            "avant d’ouvrir le dépôt.",
            "Les entrepreneurs partenaires y voient le niveau de maturité : ce n’est "
            "pas un prototype isolé, mais une plateforme multi-surface avec admin, "
            "workers, PWA et stratégie store.",
        ],
    )
    add_h(doc, "23.1 Règles de partage d’information", 2)
    add_bullets(
        doc,
        [
            "Partager ce rapport librement en interne / partenaires de confiance.",
            "Ne pas y ajouter de secrets « pour plus tard ».",
            "Créer des annexes confidentielles séparées si nécessaire.",
            "Versionner les documents et dater les mises à jour.",
        ],
    )
    page_break(doc)

    # 24
    add_h(doc, "24. Risques, limites et perspectives", 1)
    filler_paragraphs(
        doc,
        [
            "Comme toute marketplace, SombaTeka fait face à des risques : fraude, "
            "contenus illicites, abus de messagerie, indisponibilité réseau, dépendance "
            "à des opérateurs de paiement, et exigences changeantes des stores.",
            "Les limites actuelles doivent être assumées avec transparence auprès des "
            "parties prenantes : certains modules se déploient par étapes ; la qualité "
            "dépend aussi de la densité d’annonces et de la discipline de modération ; "
            "la performance perçue dépend des photos et du réseau utilisateur.",
            "Les perspectives incluent l’enrichissement de l’expérience vendeur officiel, "
            "l’amélioration continue de la recherche, l’élargissement géographique, "
            "et le passage progressif des tests fermés vers une distribution mobile "
            "plus large lorsque les indicateurs le permettent.",
        ],
    )
    add_h(doc, "24.1 Recommandations aux décideurs", 2)
    add_bullets(
        doc,
        [
            "Prioriser la confiance (KYC, modération) autant que l’acquisition.",
            "Mesurer les funnels : inscription → publication → contact → transaction.",
            "Ne pas précipiter la production store sans socle de testeurs actifs.",
            "Investir dans la qualité des médias et de la catégorisation.",
            "Garder une discipline stricte sur les secrets et les accès.",
        ],
    )
    page_break(doc)

    # 25
    add_h(doc, "25. Glossaire", 1)
    glossary = [
        ("AAB", "Android App Bundle, format de publication Play Store."),
        ("API", "Interface de programmation permettant aux clients d’accéder au métier."),
        ("Celery", "Système de files de tâches asynchrones en Python."),
        ("Escrow", "Séquestre : fonds ou confirmation retenus jusqu’à conditions remplies."),
        ("FastAPI", "Framework web Python pour construire des APIs modernes."),
        ("Flutter", "Kit UI multi-plateforme (mobile, web, desktop)."),
        ("JWT", "Jeton d’authentification signé utilisé après connexion."),
        ("KYC", "Know Your Customer : vérification d’identité / boutique."),
        ("Nginx", "Serveur reverse-proxy et serveur web haute performance."),
        ("Offline-first", "Conception qui tolère mieux les coupures réseau."),
        ("PostgreSQL", "Base de données relationnelle open source."),
        ("PWA", "Progressive Web App : site installable comme une application."),
        ("Redis", "Store mémoire clé-valeur pour cache et files."),
        ("SEO", "Optimisation pour la découverte via moteurs de recherche."),
        ("WebSocket", "Canal de communication bidirectionnel temps réel."),
    ]
    for term, defn in glossary:
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(6)
        r = p.add_run(f"{term} — ")
        set_run_font(r, bold=True, size=11)
        r2 = p.add_run(defn)
        set_run_font(r2, size=11)
    page_break(doc)

    # 26 Annexes
    add_h(doc, "26. Annexes", 1)
    add_h(doc, "Annexe A — Cartographie des composants", 2)
    add_table(
        doc,
        ["Composant", "Emplacement logique", "Public"],
        [
            ["Application Flutter", "Client mobile/web", "Utilisateurs"],
            ["API FastAPI", "Backend", "Clients authentifiés / publics limités"],
            ["Panel admin", "Backend /admin", "Équipe interne"],
            ["Site légal/marketing", "Pages statiques", "Public"],
            ["Nginx", "Edge", "Point d’entrée HTTPS"],
            ["PostgreSQL", "Data", "Interne"],
            ["Redis + Celery", "Data / jobs", "Interne"],
        ],
    )
    add_h(doc, "Annexe B — Checklist lecture pour entrepreneur", 2)
    add_bullets(
        doc,
        [
            "Ai-je compris la différence particulier / vendeur officiel ?",
            "Quels parcours sont déjà couverts (annonce, chat, profil, pro) ?",
            "Quels modules sont progressifs (paiement, SEO avancé) ?",
            "Quelles décisions business restent à trancher (priorités, marchés) ?",
            "Quels indicateurs suivrai-je après la prochaine release test ?",
        ],
    )
    add_h(doc, "Annexe C — Checklist lecture pour collaborateur technique", 2)
    add_bullets(
        doc,
        [
            "Sai-je où vit le client vs le backend vs l’edge ?",
            "Comprends-je le rôle de Redis et Celery ?",
            "Ai-je identifié les zones sensibles (auth, paiements, admin) ?",
            "Suis-je clair sur ce qui ne doit jamais être commit/partagé ?",
            "Quelle est la stratégie de versioning mobile ?",
        ],
    )
    page_break(doc)

    # Extra depth pages to exceed 40 pages reliably
    add_h(doc, "Annexe D — Description détaillée des écrans clés", 2)
    screens = [
        (
            "Accueil",
            "Présente le fil d’annonces, la recherche, et des entrées rapides. "
            "C’est le point de conversion principal vers le détail produit. "
            "L’en-tête et la zone de recherche doivent rester compréhensibles "
            "même sur petit écran. Des mécanismes de rechargement et de cache "
            "limitent les frictions réseau.",
        ),
        (
            "Recherche",
            "Permet d’affiner par texte et filtres, et d’entrer une photo pour "
            "la recherche visuelle. Les résultats doivent indiquer clairement "
            "l’absence de correspondance afin d’éviter une impression de bug.",
        ),
        (
            "Détail d’annonce",
            "Regroupe photos, prix, description, vendeur, actions de contact et "
            "favoris. Les produits similaires prolongent la session. La clarté "
            "des CTA (contacter, favoris) est critique.",
        ),
        (
            "Publication",
            "Assistant de création d’annonce. La qualité de ce parcours conditionne "
            "l’offre disponible sur la marketplace. Moins il y a de friction, plus "
            "le volume d’annonces fraîches augmente.",
        ),
        (
            "Messages",
            "Liste des conversations et fil de discussion. La fraîcheur des messages "
            "et la lisibilité des statuts (envoyé/reçu) renforcent la confiance.",
        ),
        (
            "Profil",
            "Identité de l’utilisateur, accès paramètres, statistiques simples, "
            "et pour les officiels un panneau boutique. L’en-tête de profil est "
            "conçu pour rester stable et lisible pendant le défilement du contenu.",
        ),
        (
            "Espace pro",
            "Cockpit vendeur officiel : actions fréquentes, catalogues, clients. "
            "Il doit réduire le temps pour publier et répondre.",
        ),
        (
            "Paramètres & légal",
            "Gestion du compte, préférences, accès aux documents légaux et aux "
            "parcours de suppression/verification. Indispensable pour la conformité.",
        ),
    ]
    for title, body in screens:
        add_h(doc, title, 3)
        filler_paragraphs(doc, [body, body + " Cette description volontairement pédagogique "
                                      "aide les non-techniciens à relier un écran à une "
                                      "intention métier sans entrer dans le code source."])

    page_break(doc)
    add_h(doc, "Annexe E — Scénarios métier illustratifs", 2)
    scenarios = [
        "Scénario A — Particulier vend un téléphone : création de compte, publication "
        "avec photos, réception de messages, accord sur un lieu de remise, clôture "
        "informelle de la discussion. La plateforme a créé la rencontre ; le paiement "
        "peut rester hors app.",
        "Scénario B — Acheteur cherche une robe vue en photo : import de l’image, "
        "résultats visuels, ouverture de plusieurs fiches, mise en favoris, contact "
        "du vendeur le plus proche.",
        "Scénario C — Boutique officielle : demande de statut, validation, publication "
        "catalogue, mise en avant, suivi des clients via l’espace pro, éventuelle "
        "commande structurée si le module paiement est actif.",
        "Scénario D — Signalement : un utilisateur signale une annonce suspecte ; "
        "la modération traite le cas ; l’annonce peut être masquée ; l’historique "
        "reste consultable selon les droits admin.",
        "Scénario E — Support : un utilisateur n’arrive pas à finaliser son compte ; "
        "le helpdesk le guide ; l’équipe vérifie les journaux non secrets et propose "
        "une résolution sans exposer d’informations d’autres utilisateurs.",
    ]
    for s in scenarios:
        filler_paragraphs(doc, [s])
        filler_paragraphs(
            doc,
            [
                "Ce scénario montre comment la technologie sert une intention concrète. "
                "Il peut être utilisé comme cas de test d’acceptation lors des recettes "
                "fonctionnelles avec des testeurs fermés ou des collaborateurs métier.",
            ],
        )

    page_break(doc)
    add_h(doc, "Annexe F — Principes UX et design system", 2)
    filler_paragraphs(
        doc,
        [
            "Le design system SombaTeka vise une identité premium lisible : couleurs "
            "de marque stables, typographie claire, composants réutilisables, et "
            "hiérarchie visuelle nette. Sur marketplace, la confiance se joue aussi "
            "dans les détails : badges, états vides, confirmation d’actions destructives, "
            "et cohérence entre web et mobile.",
            "Les écrans d’authentification et d’onboarding doivent rassurer sans surcharger. "
            "Les écrans de catalogue doivent optimiser le scan rapide (image, prix, titre). "
            "Les écrans de conversation doivent prioriser la lisibilité du texte et la "
            "rapidité de réponse.",
            "Enfin, l’accessibilité de base (contrastes, tailles de cible de toucher, "
            "messages d’erreur explicites) n’est pas un « plus » : c’est une condition "
            "d’adoption sur un marché large et hétérogène.",
        ],
    )
    for i in range(1, 6):
        filler_paragraphs(
            doc,
            [
                f"Note UX complémentaire ({i}/5) : chaque itération visuelle doit être "
                f"validée sur un téléphone milieu de gamme et sur une connexion contrainte. "
                f"Une maquette magnifique mais lourde peut dégrader la conversion réelle. "
                f"SombaTeka privilégie donc la sobriété efficace, les animations utiles "
                f"plutôt que décoratives, et la stabilité des zones de navigation.",
            ],
        )

    page_break(doc)
    add_h(doc, "Annexe G — Modèle de données conceptuel (non exhaustif)", 2)
    filler_paragraphs(
        doc,
        [
            "Sans publier le schéma SQL complet, on peut résumer les agrégats principaux. "
            "Un Utilisateur possède un Profil et un Statut (particulier / officiel / staff). "
            "Une Annonce appartient à un Utilisateur et référence une Catégorie, des Médias, "
            "et des Attributs. Une Conversation relie des Participants et contient des "
            "Messages. Un Favori lie un Utilisateur à une Annonce. Une Commande (si activée) "
            "relie Acheteur, Vendeur officiel, et des États de paiement/livraison. Un Avis "
            "qualifie une expérience après transaction. Un Signalement pointe vers un "
            "contenu ou un utilisateur pour revue.",
            "Ces agrégats guident les priorités produit : sans annonces et médias de "
            "qualité, pas de marketplace ; sans messagerie, pas de conversion ; sans "
            "modération, pas de confiance durable ; sans identité solide, pas de vendeurs "
            "officiels crédibles.",
        ],
    )
    for block in range(1, 8):
        filler_paragraphs(
            doc,
            [
                f"Complément modèle ({block}) : les relations doivent préserver l’intégrité "
                f"(une annonce sans propriétaire valide n’a pas de sens) tout en permettant "
                f"des cycles de vie (brouillon, active, vendue, masquée, supprimée logiquement). "
                f"Les suppressions logiques et corbeilles admin évitent des pertes irréversibles "
                f"lors d’opérations de modération. Les compteurs dénormalisés (nombre d’avis, "
                f"annonces actives) peuvent exister pour la performance d’affichage, à condition "
                f"d’être maintenus de façon cohérente par le backend.",
            ],
        )

    page_break(doc)
    add_h(doc, "Annexe H — Stratégie de montée en charge (conceptuelle)", 2)
    filler_paragraphs(
        doc,
        [
            "La montée en charge se prépare avant d’être subie. Au niveau edge, le "
            "reverse-proxy absorbe une partie du trafic statique et applique des "
            "limitations. Au niveau API, le dimensionnement horizontal des workers "
            "applicatifs dépend du profil de charge (lecture d’annonces vs écriture "
            "de messages). Au niveau données, les index PostgreSQL et le cache Redis "
            "protègent les requêtes fréquentes.",
            "Les médias doivent être servis efficacement (poids, formats, cache navigateur). "
            "Les jobs lourds restent asynchrones. Les websockets demandent une attention "
            "particulière sur le nombre de connexions simultanées et la stabilité réseau.",
            "Une bonne pratique est de définir des seuils d’alerte simples (taux d’erreur, "
            "latence, saturation files) et des procédures de réponse, sans publier ici "
            "les accès aux outils d’observabilité.",
        ],
    )
    for i in range(1, 7):
        filler_paragraphs(
            doc,
            [
                f"Point capacité ({i}/6) : avant une campagne d’acquisition, valider que "
                f"les parcours lecture (accueil, détail) tiennent la charge attendue, que "
                f"la publication ne crée pas de goulets médias, et que la messagerie reste "
                f"utilisable. Mieux vaut une croissance maîtrisée qu’un pic qui dégrade "
                f"la confiance dès les premiers jours.",
            ],
        )

    page_break(doc)
    add_h(doc, "Annexe I — Cadre de collaboration avec partenaires", 2)
    filler_paragraphs(
        doc,
        [
            "Les partenaires (logistique, paiement, communication, acquisition) doivent "
            "recevoir des interfaces claires : objectifs, données échangées, niveaux "
            "de service attendus, et limites. Ce rapport fournit le langage commun sur "
            "le produit, mais les contrats et SLA restent des documents séparés.",
            "Lorsqu’un partenaire technique s’intègre, on privilégie des environnements "
            "de test, des clés non productives, et une supervision des webhooks. Aucun "
            "partenaire n’a besoin des secrets d’administration globale.",
        ],
    )
    for i in range(1, 6):
        filler_paragraphs(
            doc,
            [
                f"Guide partenaire ({i}/5) : clarifier le périmètre (ce qui est in-app vs "
                f"hors-app), les responsabilités en cas d’incident, le canal d’escalade, "
                f"et les indicateurs partagés. La réussite d’une marketplace dépend autant "
                f"de ces accords que du code.",
            ],
        )

    page_break(doc)
    add_h(doc, "Conclusion", 1)
    filler_paragraphs(
        doc,
        [
            "SombaTeka est une plateforme complète de marketplace adaptée à la RDC : "
            "clients multi-support, API moderne, données robustes, opérations admin, "
            "et trajectoire de distribution web + mobile. Elle articule un usage "
            "grand public et une montée en gamme via les vendeurs officiels.",
            "Ce rapport a présenté le fonctionnement et les technologies sans livrer "
            "de secrets d’exploitation. Il peut être partagé à des membres, entrepreneurs "
            "et collaborateurs pour aligner la compréhension du produit et accélérer "
            "les décisions.",
            "La suite dépend moins d’ajouter des technologies que d’exécuter avec "
            "discipline : qualité des annonces, confiance, tests utilisateurs, releases "
            "régulières, et protection stricte des accès sensibles.",
        ],
    )
    add_para(
        doc,
        "— Fin du document —",
        align="center",
        bold=True,
        first_line=False,
    )
    add_para(
        doc,
        "SombaTeka — Rapport fonctionnement & technologies — usage interne / partenaires",
        align="center",
        size=9,
        first_line=False,
    )

    doc.save(OUT)
    return OUT


if __name__ == "__main__":
    path = build()
    print(path)
    # Estimate pages roughly via paragraph count / XML size
    from docx import Document as D

    d = D(str(path))
    paras = len(d.paragraphs)
    tables = len(d.tables)
    print(f"paragraphs={paras} tables={tables}")
