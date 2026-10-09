-- =============================================================================
-- 01c_session_channel_transitions.sql
-- Objetivo: investigar sessões com mais de um canal completo e identificar as
-- principais transições entre o primeiro e o último canal observado.
-- =============================================================================

WITH events AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'ga_session_id'
      LIMIT 1
    ) AS session_id,
    (
      SELECT ep.value.string_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'source'
      LIMIT 1
    ) AS source,
    (
      SELECT ep.value.string_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'medium'
      LIMIT 1
    ) AS medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

complete_channel_events AS (
  SELECT
    user_pseudo_id,
    session_id,
    event_timestamp,
    CONCAT(source, ' / ', medium) AS channel
  FROM events
  WHERE user_pseudo_id IS NOT NULL
    AND session_id IS NOT NULL
    AND source IS NOT NULL
    AND medium IS NOT NULL
),

session_transitions AS (
  SELECT
    user_pseudo_id,
    session_id,
    COUNT(DISTINCT channel) AS distinct_channels,
    ARRAY_AGG(
      channel
      ORDER BY event_timestamp ASC
      LIMIT 1
    )[OFFSET(0)] AS first_channel,
    ARRAY_AGG(
      channel
      ORDER BY event_timestamp DESC
      LIMIT 1
    )[OFFSET(0)] AS last_channel
  FROM complete_channel_events
  GROUP BY user_pseudo_id, session_id
)

SELECT
  first_channel,
  last_channel,
  COUNT(*) AS sessions,
  ROUND(
    100 * SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()),
    2
  ) AS share_of_changed_sessions_pct
FROM session_transitions
WHERE distinct_channels > 1
GROUP BY first_channel, last_channel
ORDER BY sessions DESC
LIMIT 30;
