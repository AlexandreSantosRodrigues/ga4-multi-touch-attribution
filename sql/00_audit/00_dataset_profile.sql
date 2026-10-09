-- =============================================================================
-- 00_dataset_profile.sql
-- Objetivo: estabelecer o contrato inicial de volume e completude do dataset.
-- Compatível com o esquema histórico do dataset público (2020–2021).
-- =============================================================================

WITH events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_name,
    user_pseudo_id,
    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'ga_session_id'
      LIMIT 1
    ) AS session_id,
    ecommerce.transaction_id AS transaction_id,
    ecommerce.purchase_revenue AS purchase_revenue,
    traffic_source.source AS first_user_source
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)

SELECT
  MIN(event_date) AS min_event_date,
  MAX(event_date) AS max_event_date,
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_pseudo_id) AS distinct_users,
  COUNT(DISTINCT IF(
    session_id IS NOT NULL,
    FORMAT('%s-%d', user_pseudo_id, session_id),
    NULL
  )) AS distinct_sessions,
  COUNTIF(event_name = 'session_start') AS session_start_events,
  COUNTIF(event_name = 'purchase') AS purchase_events,
  COUNT(DISTINCT IF(event_name = 'purchase', transaction_id, NULL))
    AS distinct_transactions,
  COUNTIF(event_name = 'purchase' AND transaction_id IS NULL)
    AS purchases_without_transaction_id,
  COUNTIF(event_name = 'purchase' AND purchase_revenue IS NULL)
    AS purchases_without_revenue,
  COUNTIF(user_pseudo_id IS NULL) AS events_without_user_id,
  COUNTIF(session_id IS NULL) AS events_without_session_id,
  COUNTIF(event_name = 'session_start' AND first_user_source IS NULL)
    AS session_starts_without_first_user_source,
  ROUND(SUM(IF(event_name = 'purchase', COALESCE(purchase_revenue, 0), 0)), 2)
    AS raw_purchase_revenue
FROM events;
