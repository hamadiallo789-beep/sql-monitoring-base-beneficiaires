-- =============================================================================
-- Schema de la base de suivi des beneficiaires d'un programme humanitaire
-- Compatible SQLite (adaptable PostgreSQL/MySQL : voir README)
-- =============================================================================

CREATE TABLE zones (
    id_zone INTEGER PRIMARY KEY,
    nom_zone TEXT NOT NULL,
    region TEXT NOT NULL,
    province TEXT NOT NULL,
    milieu TEXT NOT NULL CHECK (milieu IN ('Rural','Urbain')),
    population_estimee INTEGER
);

CREATE TABLE agents_terrain (
    id_agent INTEGER PRIMARY KEY,
    nom_agent TEXT NOT NULL,
    fonction TEXT NOT NULL,
    id_zone_affectation INTEGER,
    FOREIGN KEY (id_zone_affectation) REFERENCES zones(id_zone)
);

CREATE TABLE menages (
    id_menage INTEGER PRIMARY KEY,
    id_zone INTEGER NOT NULL,
    date_enregistrement TEXT NOT NULL,
    taille_menage INTEGER NOT NULL CHECK (taille_menage > 0),
    sexe_cdm TEXT NOT NULL CHECK (sexe_cdm IN ('Homme','Femme')),
    statut_vulnerabilite TEXT NOT NULL CHECK (statut_vulnerabilite IN ('Faible','Modere','Severe')),
    programme_cible TEXT NOT NULL CHECK (programme_cible IN ('Securite alimentaire','Cash transfert','WASH','Multisectoriel')),
    numero_telephone TEXT,
    FOREIGN KEY (id_zone) REFERENCES zones(id_zone)
);

CREATE TABLE beneficiaires (
    id_beneficiaire INTEGER PRIMARY KEY,
    id_menage INTEGER NOT NULL,
    sexe TEXT NOT NULL CHECK (sexe IN ('Masculin','Feminin')),
    date_naissance TEXT NOT NULL,
    categorie_specifique TEXT NOT NULL CHECK (categorie_specifique IN
        ('Enfant moins de 5 ans','Enfant 5-17 ans','Femme enceinte ou allaitante','Adulte','Personne agee','Personne en situation de handicap')),
    FOREIGN KEY (id_menage) REFERENCES menages(id_menage)
);

CREATE TABLE distributions (
    id_distribution INTEGER PRIMARY KEY,
    id_menage INTEGER NOT NULL,
    id_zone INTEGER NOT NULL,
    id_agent INTEGER NOT NULL,
    type_assistance TEXT NOT NULL CHECK (type_assistance IN
        ('Vivres','Cash','Kit WASH','Kit hygiene','Intrants agricoles')),
    date_distribution TEXT NOT NULL,
    quantite REAL NOT NULL CHECK (quantite >= 0),
    unite TEXT NOT NULL,
    FOREIGN KEY (id_menage) REFERENCES menages(id_menage),
    FOREIGN KEY (id_zone) REFERENCES zones(id_zone),
    FOREIGN KEY (id_agent) REFERENCES agents_terrain(id_agent)
);

CREATE TABLE suivi_indicateurs (
    id_suivi INTEGER PRIMARY KEY,
    id_menage INTEGER NOT NULL,
    id_agent INTEGER NOT NULL,
    date_collecte TEXT NOT NULL,
    score_consommation_alimentaire INTEGER CHECK (score_consommation_alimentaire BETWEEN 0 AND 112),
    acces_eau_potable TEXT NOT NULL CHECK (acces_eau_potable IN ('Oui','Non')),
    distance_eau_min INTEGER,
    enfants_scolarises_pct REAL CHECK (enfants_scolarises_pct BETWEEN 0 AND 100),
    plainte_enregistree TEXT NOT NULL DEFAULT 'Non' CHECK (plainte_enregistree IN ('Oui','Non')),
    FOREIGN KEY (id_menage) REFERENCES menages(id_menage),
    FOREIGN KEY (id_agent) REFERENCES agents_terrain(id_agent)
);

CREATE INDEX idx_menages_zone ON menages(id_zone);

CREATE INDEX idx_beneficiaires_menage ON beneficiaires(id_menage);

CREATE INDEX idx_distributions_menage ON distributions(id_menage);

CREATE INDEX idx_suivi_menage ON suivi_indicateurs(id_menage);

