-- =============================================================================
-- 02_purchase_integrity.sql
-- Objetivo: verificar duplicidade, identificadores e receita antes da atribuição.
-- Regra: transaction_id será a chave preferencial da conversão quando disponível.
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

transaction_quality AS (
  SELECT
    transaction_id,
    COUNT(*) AS event_rows,
    COUNT(DISTINCT user_pseudo_id) AS distinct_users,
    COUNT(DISTINCT event_timestamp) AS distinct_timestamps,
    MIN(purchase_revenue) AS min_revenue,
    MAX(purchase_revenue) AS max_revenue
  FROM purchases
  WHERE transaction_id IS NOT NULL
  GROUP BY transaction_id
)

SELECT
  (SELECT COUNT(*) FROM purchases) AS purchase_event_rows,
  (SELECT COUNT(DISTINCT transaction_id) FROM purchases)
    AS distinct_transaction_ids,
  (SELECT COUNTIF(transaction_id IS NULL) FROM purchases)
    AS rows_without_transaction_id,
  (SELECT COUNTIF(session_id IS NULL) FROM purchases)
    AS rows_without_session_id,
  (SELECT COUNTIF(purchase_revenue IS NULL) FROM purchases)
    AS rows_without_revenue,
  (SELECT COUNTIF(purchase_revenue < 0) FROM purchases)
    AS rows_with_negative_revenue,
  (SELECT COUNTIF(total_item_quantity IS NULL) FROM purchases)
    AS rows_without_item_quantity,
  COUNTIF(event_rows > 1) AS duplicated_transaction_ids,
  COUNTIF(distinct_users > 1) AS transactions_linked_to_multiple_users,
  COUNTIF(min_revenue != max_revenue)
    AS duplicated_transactions_with_revenue_conflict,
  ROUND((SELECT SUM(COALESCE(purchase_revenue, 0)) FROM purchases), 2)
    AS raw_event_revenue,
  ROUND(SUM(max_revenue), 2) AS deduplicated_transaction_revenue
FROM transaction_quality;
