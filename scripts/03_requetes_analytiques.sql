-- =============================================================================
-- PROJET  : Base de suivi des beneficiaires d'un programme humanitaire
-- FICHIER : 03_requetes_analytiques.sql
-- OBJET   : Requetes qu'un charge de suivi-evaluation utilise en pratique
--           (couverture, ciblage, qualite des donnees, vues, agregations)
-- AUTEUR  : Hama DIALLO (Sekou)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. COUVERTURE : nombre de menages assistes et population beneficiaire par zone
-- -----------------------------------------------------------------------------
SELECT
    z.nom_zone,
    z.region,
    z.milieu,
    z.population_estimee,
    COUNT(DISTINCT m.id_menage)                       AS nb_menages_enregistres,
    SUM(m.taille_menage)                               AS population_beneficiaire,
    ROUND(100.0 * SUM(m.taille_menage) / z.population_estimee, 2) AS taux_couverture_pct
FROM zones z
LEFT JOIN menages m ON m.id_zone = z.id_zone
GROUP BY z.id_zone
ORDER BY taux_couverture_pct DESC;

-- -----------------------------------------------------------------------------
-- 2. CIBLAGE : repartition des menages par statut de vulnerabilite et programme
-- -----------------------------------------------------------------------------
SELECT
    programme_cible,
    statut_vulnerabilite,
    COUNT(*) AS nb_menages,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM menages), 1) AS pct_du_total
FROM menages
GROUP BY programme_cible, statut_vulnerabilite
ORDER BY programme_cible,
    CASE statut_vulnerabilite WHEN 'Severe' THEN 1 WHEN 'Modere' THEN 2 ELSE 3 END;

-- Verification du ciblage : la vulnerabilite severe doit etre surrepresentee
-- parmi les menages assistes en securite alimentaire (a l'oeil, comparer aux
-- proportions globales de l'echantillon).

-- -----------------------------------------------------------------------------
-- 3. ALERTE QUALITE : doublons potentiels de numero de telephone
--    (un meme numero rattache a plusieurs menages = risque de doublon
--     d'enregistrement ou d'usurpation, a verifier sur le terrain)
-- -----------------------------------------------------------------------------
SELECT
    numero_telephone,
    COUNT(*) AS nb_menages_associes,
    GROUP_CONCAT(id_menage) AS ids_menages_concernes
FROM menages
WHERE numero_telephone IS NOT NULL
GROUP BY numero_telephone
HAVING COUNT(*) > 1;

-- -----------------------------------------------------------------------------
-- 4. ALERTE QUALITE / SUIVI : menages enregistres depuis plus de 60 jours et
--    n'ayant recu AUCUNE distribution (gap potentiel dans l'assistance)
-- -----------------------------------------------------------------------------
SELECT
    m.id_menage,
    z.nom_zone,
    m.programme_cible,
    m.statut_vulnerabilite,
    m.date_enregistrement,
    CAST(julianday('now') - julianday(m.date_enregistrement) AS INTEGER) AS jours_depuis_enregistrement
FROM menages m
JOIN zones z ON z.id_zone = m.id_zone
WHERE m.id_menage NOT IN (SELECT DISTINCT id_menage FROM distributions)
ORDER BY jours_depuis_enregistrement DESC;

-- -----------------------------------------------------------------------------
-- 5. SOUS-REQUETE : menages en insecurite alimentaire severe (SCA < 28) qui
--    n'ont pourtant reçu AUCUNE distribution de type "Vivres"
--    (ciblage a corriger en priorite)
-- -----------------------------------------------------------------------------
SELECT
    m.id_menage,
    z.nom_zone,
    m.statut_vulnerabilite,
    si.score_consommation_alimentaire,
    si.date_collecte
FROM menages m
JOIN zones z ON z.id_zone = m.id_zone
JOIN suivi_indicateurs si ON si.id_menage = m.id_menage
WHERE si.score_consommation_alimentaire < 28
  AND m.id_menage NOT IN (
        SELECT id_menage FROM distributions WHERE type_assistance = 'Vivres'
  )
ORDER BY si.score_consommation_alimentaire ASC;

-- -----------------------------------------------------------------------------
-- 6. VUE : profil consolide du menage (derniere collecte de suivi connue)
-- -----------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS v_profil_menage AS
SELECT
    m.id_menage,
    z.nom_zone,
    z.region,
    m.programme_cible,
    m.statut_vulnerabilite,
    m.taille_menage,
    (SELECT COUNT(*) FROM distributions d WHERE d.id_menage = m.id_menage) AS nb_distributions_recues,
    (SELECT MAX(date_collecte) FROM suivi_indicateurs si WHERE si.id_menage = m.id_menage) AS derniere_date_suivi,
    (SELECT score_consommation_alimentaire FROM suivi_indicateurs si
       WHERE si.id_menage = m.id_menage
       ORDER BY date_collecte DESC LIMIT 1) AS dernier_score_sca
FROM menages m
JOIN zones z ON z.id_zone = m.id_zone;

-- Exemple d'utilisation de la vue :
SELECT * FROM v_profil_menage ORDER BY dernier_score_sca ASC LIMIT 10;

-- -----------------------------------------------------------------------------
-- 7. AGREGATION MULTI-TABLES : effectifs de beneficiaires par categorie
--    specifique et par region (jointure beneficiaires -> menages -> zones)
-- -----------------------------------------------------------------------------
SELECT
    z.region,
    b.categorie_specifique,
    COUNT(*) AS nb_beneficiaires
FROM beneficiaires b
JOIN menages m ON m.id_menage = b.id_menage
JOIN zones z ON z.id_zone = m.id_zone
GROUP BY z.region, b.categorie_specifique
ORDER BY z.region, nb_beneficiaires DESC;

-- -----------------------------------------------------------------------------
-- 8. ACCES A L'EAU POTABLE : taux d'acces par region (dernier releve par menage)
-- -----------------------------------------------------------------------------
WITH dernier_suivi AS (
    SELECT si.*,
           ROW_NUMBER() OVER (PARTITION BY si.id_menage ORDER BY si.date_collecte DESC) AS rang
    FROM suivi_indicateurs si
)
SELECT
    z.region,
    COUNT(*) AS nb_menages_suivis,
    SUM(CASE WHEN ds.acces_eau_potable = 'Oui' THEN 1 ELSE 0 END) AS nb_avec_acces_eau,
    ROUND(100.0 * SUM(CASE WHEN ds.acces_eau_potable = 'Oui' THEN 1 ELSE 0 END) / COUNT(*), 1) AS taux_acces_eau_pct
FROM dernier_suivi ds
JOIN menages m ON m.id_menage = ds.id_menage
JOIN zones z ON z.id_zone = m.id_zone
WHERE ds.rang = 1
GROUP BY z.region
ORDER BY taux_acces_eau_pct ASC;

-- -----------------------------------------------------------------------------
-- 9. PERFORMANCE DES AGENTS : nombre de collectes de suivi realisees par agent
-- -----------------------------------------------------------------------------
SELECT
    a.nom_agent,
    a.fonction,
    z.nom_zone AS zone_affectation,
    COUNT(si.id_suivi) AS nb_collectes_realisees,
    SUM(CASE WHEN si.plainte_enregistree = 'Oui' THEN 1 ELSE 0 END) AS nb_plaintes_enregistrees
FROM agents_terrain a
LEFT JOIN zones z ON z.id_zone = a.id_zone_affectation
LEFT JOIN suivi_indicateurs si ON si.id_agent = a.id_agent
GROUP BY a.id_agent
ORDER BY nb_collectes_realisees DESC;

-- -----------------------------------------------------------------------------
-- 10. ALERTE QUALITE : distributions "Cash" avec montant hors plage attendue
--     (au-dela de 2 ecarts-types de la moyenne -> a verifier / potentielle
--      erreur de saisie ou fraude)
-- -----------------------------------------------------------------------------
WITH stats_cash AS (
    SELECT AVG(quantite) AS moyenne, AVG(quantite*quantite) - AVG(quantite)*AVG(quantite) AS variance
    FROM distributions WHERE type_assistance = 'Cash'
)
SELECT
    d.id_distribution,
    d.id_menage,
    d.date_distribution,
    d.quantite AS montant_fcfa,
    ROUND(s.moyenne, 0) AS moyenne_cash_programme
FROM distributions d, stats_cash s
WHERE d.type_assistance = 'Cash'
  AND ABS(d.quantite - s.moyenne) > 2 * SQRT(s.variance)
ORDER BY d.quantite DESC;

-- =============================================================================
-- Fin des requetes analytiques
-- =============================================================================
