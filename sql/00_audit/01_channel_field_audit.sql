-- =============================================================================
-- 01_channel_field_audit.sql
-- Objetivo: medir o risco de usar traffic_source como canal de cada sessão.
-- Nota: traffic_source representa aquisição inicial do usuário. A origem coletada
-- da sessão deve ser avaliada antes da construção das jornadas.
-- =============================================================================

WITH session_starts AS (
  SELECT
    user_pseudo_id,
    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'ga_session_id'
      LIMIT 1
    ) AS session_id,
    traffic_source.source AS first_user_source,
    traffic_source.medium AS first_user_medium,
    collected_traffic_source.manual_source AS collected_source,
    collected_traffic_source.manual_medium AS collected_medium,
    collected_traffic_source.gclid AS gclid
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'session_start'
),

classified AS (
  SELECT
    *,
    COALESCE(NULLIF(collected_source, ''), '(missing)') AS audited_source,
    CASE
      WHEN gclid IS NOT NULL THEN 'cpc'
      ELSE COALESCE(NULLIF(collected_medium, ''), '(missing)')
    END AS audited_medium,
    COALESCE(first_user_source, '(missing)')
      != COALESCE(collected_source, '(missing)')
      OR COALESCE(first_user_medium, '(missing)')
      != COALESCE(collected_medium, '(missing)')
      AS acquisition_differs_from_collected
  FROM session_starts
)

SELECT
  COUNT(*) AS session_start_rows,
  COUNT(DISTINCT FORMAT('%s-%d', user_pseudo_id, session_id))
    AS distinct_session_keys,
  COUNTIF(session_id IS NULL) AS rows_without_session_id,
  COUNTIF(collected_source IS NULL) AS rows_without_collected_source,
  COUNTIF(collected_medium IS NULL) AS rows_without_collected_medium,
  COUNTIF(gclid IS NOT NULL) AS rows_with_gclid,
  COUNTIF(acquisition_differs_from_collected)
    AS rows_where_acquisition_differs,
  ROUND(
    100 * SAFE_DIVIDE(
      COUNTIF(acquisition_differs_from_collected),
      COUNT(*)
    ),
    2
  ) AS acquisition_difference_pct,
  COUNT(DISTINCT CONCAT(audited_source, ' / ', audited_medium))
    AS distinct_collected_channel_pairs
FROM classified;
