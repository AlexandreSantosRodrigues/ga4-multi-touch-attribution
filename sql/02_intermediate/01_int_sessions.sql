-- =============================================================================
-- 01_int_sessions.sql
-- Camada Intermediate: uma linha por sessão.
-- Regra de canal: primeiro canal completo externo observado na sessão.
-- Autorreferências internas conhecidas são excluídas da seleção.
-- =============================================================================

DROP TABLE IF EXISTS
  `ga4-attribution-project-511113.ga4_attribution.int_sessions`;

CREATE OR REPLACE VIEW
  `ga4-attribution-project-511113.ga4_attribution.int_sessions`
AS

WITH valid_events AS (
  SELECT *
  FROM `ga4-attribution-project-511113.ga4_attribution.stg_ga4_events`
  WHERE user_pseudo_id IS NOT NULL
    AND session_id IS NOT NULL
),

session_rollup AS (
  SELECT
    CONCAT(user_pseudo_id, '|', CAST(session_id AS STRING)) AS session_key,
    user_pseudo_id,
    session_id,
    MIN(event_date) AS session_date,
    MIN(event_timestamp) AS session_start_ts,
    MAX(event_timestamp) AS session_end_ts,
    TIMESTAMP_DIFF(
      MAX(event_timestamp),
      MIN(event_timestamp),
      SECOND
    ) AS session_duration_seconds,
    COUNT(*) AS event_count,
    COUNTIF(event_name = 'session_start') AS session_start_event_count,
    COUNTIF(event_name = 'purchase') AS purchase_event_count,

    ARRAY_AGG(session_number IGNORE NULLS
      ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS session_number,

    ARRAY_AGG(device_category IGNORE NULLS
      ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS device_category,

    ARRAY_AGG(operating_system IGNORE NULLS
      ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS operating_system,

    ARRAY_AGG(browser IGNORE NULLS
      ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS browser,

    ARRAY_AGG(country IGNORE NULLS
      ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS country,

    ARRAY_AGG(region IGNORE NULLS
      ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS region,

    ARRAY_AGG(city IGNORE NULLS
      ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS city,

    ARRAY_AGG(first_user_source IGNORE NULLS
      ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS first_user_source,

    ARRAY_AGG(first_user_medium IGNORE NULLS
      ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS first_user_medium,

    COUNTIF(
      LOWER(source) IN (
        'shop.googlemerchandisestore.com',
        'googlemerchandisestore.com'
      )
      AND LOWER(medium) = 'referral'
    ) AS self_referral_event_count

  FROM valid_events
  GROUP BY user_pseudo_id, session_id
),

external_channel_candidates AS (
  SELECT
    CONCAT(user_pseudo_id, '|', CAST(session_id AS STRING)) AS session_key,
    source,
    medium,
    campaign,
    event_timestamp AS channel_observed_at
  FROM valid_events
  WHERE source IS NOT NULL
    AND medium IS NOT NULL
    AND NOT (
      LOWER(source) IN (
        'shop.googlemerchandisestore.com',
        'googlemerchandisestore.com'
      )
      AND LOWER(medium) = 'referral'
    )
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY user_pseudo_id, session_id
    ORDER BY event_timestamp
  ) = 1
)

SELECT
  s.session_key,
  s.user_pseudo_id,
  s.session_id,
  s.session_number,
  s.session_date,
  s.session_start_ts,
  s.session_end_ts,
  s.session_duration_seconds,
  s.event_count,
  s.session_start_event_count,
  s.purchase_event_count,

  COALESCE(c.source, '(unattributed)') AS source,
  COALESCE(c.medium, '(not available)') AS medium,
  c.campaign,
  c.channel_observed_at,

  CONCAT(
    COALESCE(c.source, '(unattributed)'),
    ' / ',
    COALESCE(c.medium, '(not available)')
  ) AS channel,

  CASE
    WHEN c.source IS NULL OR c.medium IS NULL THEN 'unattributed'
    WHEN LOWER(c.source) = '(direct)'
      AND LOWER(c.medium) = '(none)' THEN 'direct'
    WHEN LOWER(c.source) = '(data deleted)'
      OR LOWER(c.medium) = '(data deleted)' THEN 'data_deleted'
    WHEN LOWER(c.source) = '<other>'
      OR LOWER(c.medium) = '<other>' THEN 'obfuscated'
    ELSE 'identified'
  END AS channel_quality_status,

  s.first_user_source,
  s.first_user_medium,
  s.device_category,
  s.operating_system,
  s.browser,
  s.country,
  s.region,
  s.city,

  s.self_referral_event_count,
  s.self_referral_event_count > 0 AS had_self_referral_removed

FROM session_rollup AS s
LEFT JOIN external_channel_candidates AS c
  USING (session_key);
