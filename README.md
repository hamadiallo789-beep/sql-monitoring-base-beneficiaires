# Base de données de suivi des bénéficiaires — Programme humanitaire multi-sectoriel (Burkina Faso)

Conception et exploitation en **SQL** d'une base relationnelle de suivi des bénéficiaires d'un programme humanitaire (sécurité alimentaire, transferts monétaires, WASH). Ce dépôt sert de démonstration de compétences en modélisation de bases de données et en requêtage SQL appliqué au suivi-évaluation (MEAL) : couverture, ciblage, qualité des données et alertes.

## Contexte du programme

Une organisation met en œuvre un programme multi-sectoriel (sécurité alimentaire, transferts monétaires, WASH) auprès de **180 ménages** (1 262 bénéficiaires individuels) répartis sur **9 zones d'intervention** dans les régions Est, Nord et Sahel du Burkina Faso. La base modélise l'ensemble du cycle de suivi : enregistrement des ménages et de leurs membres, distributions d'assistance, et collectes de suivi post-distribution (PDM) réalisées par 12 agents de terrain.

> Base de données **synthétique**, construite pour reproduire fidèlement la structure et les problématiques réelles d'une base de suivi terrain (y compris des anomalies volontairement introduites pour démontrer les requêtes de contrôle qualité).

## Objectifs

1. Concevoir un schéma relationnel normalisé, fidèle aux besoins réels d'un système de suivi de bénéficiaires.
2. Écrire des requêtes SQL répondant aux besoins opérationnels d'un chargé de suivi-évaluation : couverture, ciblage, agrégations multi-tables.
3. Détecter des problèmes de qualité de données (doublons, gaps de couverture, anomalies de saisie) — une compétence clé en assurance qualité des données MEAL.
4. Démontrer l'usage de vues, sous-requêtes, fonctions fenêtrées (`ROW_NUMBER`) et jointures multiples.

## Schéma de la base

6 tables : `zones`, `agents_terrain`, `menages`, `beneficiaires`, `distributions`, `suivi_indicateurs`. Diagramme entité-relation complet (Mermaid) dans [`docs/dictionnaire_donnees.md`](docs/dictionnaire_donnees.md).

```
zones (1) ───< menages (1) ───< beneficiaires
  │                │
  │                ├───< distributions >─── agents_terrain
  │                └───< suivi_indicateurs >─── agents_terrain
  └───< agents_terrain (affectation)
```

## Structure du dépôt

```
├── data/
│   └── suivi_beneficiaires.db          # Base SQLite prête à l'emploi (6 tables, ~2100 lignes)
├── scripts/
│   ├── 01_schema.sql                    # Création du schéma (tables, clés, contraintes, index)
│   ├── 02_insertion_donnees.sql         # Insertion des données synthétiques
│   └── 03_requetes_analytiques.sql      # 10 requêtes commentées : couverture, ciblage, qualité, vues
└── docs/
    └── dictionnaire_donnees.md          # Dictionnaire des tables + diagramme entité-relation
```

## Comment exécuter

**Option 1 — base SQLite déjà prête (recommandé) :**
```bash
sqlite3 data/suivi_beneficiaires.db < scripts/03_requetes_analytiques.sql
```

**Option 2 — reconstruire la base depuis zéro :**
```bash
sqlite3 nouvelle_base.db < scripts/01_schema.sql
sqlite3 nouvelle_base.db < scripts/02_insertion_donnees.sql
sqlite3 nouvelle_base.db < scripts/03_requetes_analytiques.sql
```

Compatible également avec [DB Browser for SQLite](https://sqlitebrowser.org/) (interface graphique) pour explorer les tables sans ligne de commande. Le SQL utilisé est standard et facilement portable vers PostgreSQL/MySQL (voir notes dans `docs/dictionnaire_donnees.md`).

## Exemples de requêtes et résultats

**1. Taux de couverture par zone** (population bénéficiaire / population estimée) :

| Zone | Région | Ménages | Population couverte | Taux de couverture |
|---|---|---|---|---|
| Thiou | Nord | 21 | 171 | 2,31 % |
| Diapangou | Est | 17 | 111 | 1,82 % |
| Gorom-Gorom | Sahel | 24 | 167 | 1,07 % |

**2. Alerte qualité — doublons de numéro de téléphone** : 4 numéros de téléphone partagés par deux ménages différents détectés (ex. ménages n°50 et 97), à vérifier sur le terrain.

**3. Alerte qualité — ménages sans aucune distribution** : 5 ménages enregistrés depuis plus d'un an n'ont reçu aucune assistance (gap de couverture à corriger en priorité).

**4. Ciblage à corriger** : plusieurs ménages en insécurité alimentaire sévère (score SCA < 28) n'ont reçu aucune distribution de vivres — liste priorisée générée automatiquement par la requête 5.

**5. Accès à l'eau potable par région** (dernier relevé de suivi par ménage) : Sahel 59,2 %, Est 51,3 %, Nord 43,4 % — met en évidence un besoin WASH plus marqué en zone Nord.

**6. Alerte qualité — anomalie de montant cash** : une distribution cash de 368 000 FCFA détectée, très supérieure à la moyenne du programme (~40 600 FCFA) — à vérifier (erreur de saisie ou fraude potentielle).

Le détail des 10 requêtes (couverture, ciblage, doublons, gaps, vue consolidée `v_profil_menage`, agrégations par catégorie de bénéficiaires, accès à l'eau, performance des agents, anomalies de montants) est disponible et commenté dans [`scripts/03_requetes_analytiques.sql`](scripts/03_requetes_analytiques.sql).

## Compétences démontrées

- Modélisation d'un schéma relationnel normalisé (clés primaires/étrangères, contraintes `CHECK`, index)
- Écriture de SQL structuré et commenté : jointures multiples, sous-requêtes, CTE (`WITH`), fonctions fenêtrées (`ROW_NUMBER`), vues
- Traduction de besoins opérationnels de suivi-évaluation (couverture, ciblage, qualité des données) en requêtes SQL exploitables
- Détection d'anomalies et de problèmes de qualité de données — compétence essentielle en assurance qualité MEAL
- Capacité à documenter une base de données pour un public non technique (dictionnaire, diagramme entité-relation)

## À propos

**Hama DIALLO (Sékou)** — Data Analyst / Chargé MEAL, spécialisé en suivi-évaluation de projets de développement et statistiques appliquées au Sahel.
Contact : hamadiallo789@gmail.com · Portfolio : [hamadiallo789-beep.github.io/portfolio](https://hamadiallo789-beep.github.io/portfolio)
