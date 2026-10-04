-- ============================================================
-- 05_comparison.sql
-- Comparação lado a lado: Last-Click vs Linear vs Time-Decay
-- Fonte: bigquery-public-data.ga4_obfuscated_sample_ecommerce
-- ============================================================
WITH purchases AS (
  SELECT user_pseudo_id, event_timestamp AS purchase_ts
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
    s.session_ts,
    POW(0.5, (p.purchase_ts - s.session_ts) / 86400000000.0 / 7.0) AS decay_weight,
    ROW_NUMBER() OVER (
      PARTITION BY p.user_pseudo_id, p.purchase_ts
      ORDER BY s.session_ts DESC
    ) AS rn_last,
    COUNT(*) OVER (
      PARTITION BY p.user_pseudo_id, p.purchase_ts
    ) AS total_tp
  FROM purchases p
  JOIN sessions s
    ON p.user_pseudo_id = s.user_pseudo_id
    AND s.session_ts <= p.purchase_ts
),
with_decay AS (
  SELECT *,
    decay_weight / SUM(decay_weight) OVER (
      PARTITION BY user_pseudo_id, purchase_ts
    ) AS norm_decay
  FROM touchpoints
)
SELECT
  source,
  medium,
  ROUND(SUM(IF(rn_last = 1, 1, 0)), 0)  AS last_click,
  ROUND(SUM(1.0 / total_tp), 2)          AS linear,
  ROUND(SUM(norm_decay), 2)              AS time_decay,
  -- Delta: quanto o Linear difere do Last-Click (em %)
  ROUND(
    (SUM(1.0 / total_tp) - SUM(IF(rn_last = 1, 1, 0)))
    / NULLIF(SUM(IF(rn_last = 1, 1, 0)), 0) * 100
  , 1) AS linear_vs_lc_pct
FROM with_decay
GROUP BY source, medium
ORDER BY last_click DESC;
