-- ============================================================
-- 03_linear.sql
-- Modelo: Linear Attribution
-- Crédito dividido igualmente entre todos os touchpoints
-- Problema: trata todos os canais como igualmente importantes,
-- ignorando posição e timing na jornada
-- ============================================================
WITH purchases AS (
  SELECT
    user_pseudo_id,
    event_timestamp AS purchase_ts
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'purchase'
),
sessions AS (
  SELECT
    user_pseudo_id,
    event_timestamp AS session_ts,
    traffic_source.source AS source,
    traffic_source.medium AS medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'session_start'
),
touchpoints AS (
  SELECT
    p.user_pseudo_id,
    p.purchase_ts,
    s.source,
    s.medium,
    COUNT(*) OVER (
      PARTITION BY p.user_pseudo_id, p.purchase_ts
    ) AS total_touchpoints
  FROM purchases p
  JOIN sessions s
    ON p.user_pseudo_id = s.user_pseudo_id
    AND s.session_ts <= p.purchase_ts
)
SELECT
  source,
  medium,
  ROUND(SUM(1.0 / total_touchpoints), 2) AS conversions_attributed
FROM touchpoints
GROUP BY source, medium
ORDER BY conversions_attributed DESC;
