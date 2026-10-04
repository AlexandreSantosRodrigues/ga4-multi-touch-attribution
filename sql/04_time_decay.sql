-- ============================================================
-- 04_time_decay.sql
-- Modelo: Time-Decay Attribution
-- Sessões mais próximas da compra recebem mais crédito
-- Meia-vida: 7 dias (padrão Google Analytics)
-- Problema: desvaloriza canais de descoberta (topo de funil)
-- que iniciaram a jornada dias antes da compra
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
    s.session_ts,
    -- Peso exponencial com meia-vida de 7 dias
    POW(0.5, (p.purchase_ts - s.session_ts) / 86400000000.0 / 7.0) AS decay_weight
  FROM purchases p
  JOIN sessions s
    ON p.user_pseudo_id = s.user_pseudo_id
    AND s.session_ts <= p.purchase_ts
),
normalized AS (
  SELECT
    *,
    decay_weight / SUM(decay_weight) OVER (
      PARTITION BY user_pseudo_id, purchase_ts
    ) AS normalized_weight
  FROM touchpoints
)
SELECT
  source,
  medium,
  ROUND(SUM(normalized_weight), 2) AS conversions_attributed
FROM normalized
GROUP BY source, medium
ORDER BY conversions_attributed DESC;
