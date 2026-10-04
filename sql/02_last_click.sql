-- ============================================================
-- 02_last_click.sql
-- Modelo: Last-Click Attribution
-- 100% do crédito para o canal da última sessão antes da compra
-- Problema: ignora touchpoints iniciais e intermediários
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
    traffic_source.medium AS medium,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'session_start'
),
last_click AS (
  SELECT
    p.user_pseudo_id,
    p.purchase_ts,
    s.source,
    s.medium,
    ROW_NUMBER() OVER (
      PARTITION BY p.user_pseudo_id, p.purchase_ts
      ORDER BY s.session_ts DESC
    ) AS rn
  FROM purchases p
  JOIN sessions s
    ON p.user_pseudo_id = s.user_pseudo_id
    AND s.session_ts <= p.purchase_ts
)
SELECT
  source,
  medium,
  COUNT(*) AS conversions_attributed
FROM last_click
WHERE rn = 1
GROUP BY source, medium
ORDER BY conversions_attributed DESC;
