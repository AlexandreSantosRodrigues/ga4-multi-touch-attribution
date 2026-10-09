-- =============================================================================
-- 01b_session_channel_coverage.sql
-- Objetivo: validar a reconstrução do canal a partir do primeiro evento da
-- sessão que contenha source/medium/campaign.
-- =============================================================================

WITH events AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    event_name,
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
    ) AS medium,
    (
      SELECT ep.value.string_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'campaign'
      LIMIT 1
    ) AS campaign
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),

session_profile AS (
  SELECT
    user_pseudo_id,
    session_id,
    COUNT(*) AS event_count,
    COUNTIF(event_name = 'session_start') AS session_start_count,
    COUNT(DISTINCT source) AS distinct_sources,
    COUNT(DISTINCT medium) AS distinct_mediums,
    ARRAY_AGG(
      source IGNORE NULLS
      ORDER BY event_timestamp
      LIMIT 1
    )[SAFE_OFFSET(0)] AS first_non_null_source,
    ARRAY_AGG(
      medium IGNORE NULLS
      ORDER BY event_timestamp
      LIMIT 1
    )[SAFE_OFFSET(0)] AS first_non_null_medium,
    ARRAY_AGG(
      campaign IGNORE NULLS
      ORDER BY event_timestamp
      LIMIT 1
    )[SAFE_OFFSET(0)] AS first_non_null_campaign
  FROM events
  WHERE user_pseudo_id IS NOT NULL
    AND session_id IS NOT NULL
  GROUP BY user_pseudo_id, session_id
)

SELECT
  COUNT(*) AS distinct_sessions,
  COUNTIF(session_start_count = 0) AS sessions_without_session_start,
  COUNTIF(session_start_count > 1) AS sessions_with_multiple_session_starts,
  COUNTIF(first_non_null_source IS NOT NULL) AS sessions_with_source,
  COUNTIF(first_non_null_medium IS NOT NULL) AS sessions_with_medium,
  COUNTIF(
    first_non_null_source IS NOT NULL
    AND first_non_null_medium IS NOT NULL
  ) AS sessions_with_complete_channel,
  COUNTIF(first_non_null_source IS NULL) AS sessions_without_source,
  COUNTIF(first_non_null_medium IS NULL) AS sessions_without_medium,
  COUNTIF(distinct_sources > 1) AS sessions_with_multiple_sources,
  COUNTIF(distinct_mediums > 1) AS sessions_with_multiple_mediums,
  ROUND(
    100 * SAFE_DIVIDE(
      COUNTIF(
        first_non_null_source IS NOT NULL
        AND first_non_null_medium IS NOT NULL
      ),
      COUNT(*)
    ),
    2
  ) AS complete_channel_coverage_pct
FROM session_profile;
