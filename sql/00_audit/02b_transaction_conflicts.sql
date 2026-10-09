-- =============================================================================
-- 02b_transaction_conflicts.sql
-- Objetivo: inspecionar transações duplicadas com conflito de usuário ou receita.
-- Não aplicar deduplicação definitiva antes de analisar este resultado.
-- =============================================================================

WITH purchases AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_timestamp,
    user_pseudo_id,
    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'ga_session_id'
      LIMIT 1
    ) AS session_id,
    ecommerce.transaction_id AS transaction_id,
    ecommerce.purchase_revenue AS purchase_revenue,
    ecommerce.total_item_quantity AS total_item_quantity
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),

conflicting_transactions AS (
  SELECT
    transaction_id,
    COUNT(*) AS event_rows,
    COUNT(DISTINCT user_pseudo_id) AS distinct_users,
    COUNT(DISTINCT session_id) AS distinct_sessions,
    COUNT(DISTINCT purchase_revenue) AS distinct_non_null_revenues,
    COUNTIF(purchase_revenue IS NULL) AS rows_without_revenue,
    MIN(purchase_revenue) AS min_revenue,
    MAX(purchase_revenue) AS max_revenue,
    MIN(event_date) AS first_event_date,
    MAX(event_date) AS last_event_date,
    TIMESTAMP_DIFF(
      TIMESTAMP_MICROS(MAX(event_timestamp)),
      TIMESTAMP_MICROS(MIN(event_timestamp)),
      MINUTE
    ) AS minutes_between_first_and_last
  FROM purchases
  WHERE transaction_id IS NOT NULL
  GROUP BY transaction_id
  HAVING COUNT(DISTINCT user_pseudo_id) > 1
      OR COUNT(DISTINCT purchase_revenue) > 1
)

SELECT
  transaction_id,
  event_rows,
  distinct_users,
  distinct_sessions,
  distinct_non_null_revenues,
  rows_without_revenue,
  min_revenue,
  max_revenue,
  ROUND(max_revenue - min_revenue, 2) AS revenue_difference,
  first_event_date,
  last_event_date,
  minutes_between_first_and_last
FROM conflicting_transactions
ORDER BY revenue_difference DESC, event_rows DESC, transaction_id;
