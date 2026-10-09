-- =============================================================================
-- 02c_purchase_key_strategy.sql
-- Objetivo: validar uma chave canônica de compra resistente a IDs ausentes,
-- placeholders e colisões causadas pela ofuscação da amostra pública.
-- =============================================================================

WITH purchases AS (
  SELECT
    event_timestamp,
    user_pseudo_id,
    (
      SELECT ep.value.int_value
      FROM UNNEST(event_params) AS ep
      WHERE ep.key = 'ga_session_id'
      LIMIT 1
    ) AS session_id,
    NULLIF(TRIM(ecommerce.transaction_id), '') AS raw_transaction_id,
    ecommerce.purchase_revenue AS purchase_revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),

classified AS (
  SELECT
    *,
    CASE
      WHEN raw_transaction_id IS NULL THEN 'missing'
      WHEN LOWER(raw_transaction_id) IN ('(not set)', 'not set', '(data deleted)')
        THEN 'placeholder'
      ELSE 'valid'
    END AS transaction_id_status,
    CASE
      WHEN raw_transaction_id IS NOT NULL
        AND LOWER(raw_transaction_id)
          NOT IN ('(not set)', 'not set', '(data deleted)')
      THEN CONCAT(
        'txn|',
        COALESCE(user_pseudo_id, 'unknown'),
        '|',
        raw_transaction_id
      )
      ELSE CONCAT(
        'evt|',
        COALESCE(user_pseudo_id, 'unknown'),
        '|',
        CAST(event_timestamp AS STRING)
      )
    END AS canonical_purchase_key
  FROM purchases
),

key_quality AS (
  SELECT
    canonical_purchase_key,
    COUNT(*) AS event_rows,
    COUNT(DISTINCT user_pseudo_id) AS distinct_users,
    COUNT(DISTINCT session_id) AS distinct_sessions,
    COUNT(DISTINCT purchase_revenue) AS distinct_non_null_revenues
  FROM classified
  GROUP BY canonical_purchase_key
)

SELECT
  (SELECT COUNT(*) FROM classified) AS purchase_event_rows,
  (SELECT COUNTIF(transaction_id_status = 'valid') FROM classified)
    AS rows_with_valid_transaction_id,
  (SELECT COUNTIF(transaction_id_status = 'placeholder') FROM classified)
    AS rows_with_placeholder_transaction_id,
  (SELECT COUNTIF(transaction_id_status = 'missing') FROM classified)
    AS rows_with_missing_transaction_id,
  COUNT(*) AS distinct_canonical_purchase_keys,
  COUNTIF(event_rows > 1) AS duplicated_canonical_keys,
  SUM(IF(event_rows > 1, event_rows - 1, 0)) AS excess_event_rows,
  COUNTIF(distinct_users > 1) AS keys_with_multiple_users,
  COUNTIF(distinct_sessions > 1) AS keys_with_multiple_sessions,
  COUNTIF(distinct_non_null_revenues > 1) AS keys_with_revenue_conflict
FROM key_quality;
