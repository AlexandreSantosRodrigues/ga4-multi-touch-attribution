-- =============================================================================
-- 02_int_purchases.sql
-- Camada Intermediate: uma linha por compra canônica.
-- Chave:
--   ID válido -> user_pseudo_id + transaction_id
--   ID ausente/placeholder -> user_pseudo_id + event_timestamp
-- Duplicatas técnicas mantêm o primeiro evento observado.
-- =============================================================================

CREATE OR REPLACE VIEW
  `ga4-attribution-project-511113.ga4_attribution.int_purchases`
AS

WITH purchase_events AS (
  SELECT
    event_date AS purchase_date,
    event_timestamp AS purchase_ts,
    user_pseudo_id,
    session_id,
    NULLIF(TRIM(transaction_id), '') AS raw_transaction_id,
    purchase_revenue,
    total_item_quantity
  FROM `ga4-attribution-project-511113.ga4_attribution.stg_ga4_events`
  WHERE event_name = 'purchase'
),

classified AS (
  SELECT
    *,
    CASE
      WHEN raw_transaction_id IS NULL THEN 'missing'
      WHEN LOWER(raw_transaction_id) IN (
        '(not set)',
        'not set',
        '(data deleted)'
      ) THEN 'placeholder'
      ELSE 'valid'
    END AS transaction_id_status,

    CASE
      WHEN raw_transaction_id IS NOT NULL
        AND LOWER(raw_transaction_id) NOT IN (
          '(not set)',
          'not set',
          '(data deleted)'
        )
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
        CAST(UNIX_MICROS(purchase_ts) AS STRING)
      )
    END AS purchase_key
  FROM purchase_events
),

ranked AS (
  SELECT
    *,
    COUNT(*) OVER (
      PARTITION BY purchase_key
    ) AS source_event_count,

    ROW_NUMBER() OVER (
      PARTITION BY purchase_key
      ORDER BY
        purchase_ts,
        purchase_revenue DESC,
        total_item_quantity DESC
    ) AS purchase_row_number
  FROM classified
)

SELECT
  purchase_key,
  CONCAT(
    user_pseudo_id,
    '|',
    CAST(session_id AS STRING)
  ) AS session_key,
  user_pseudo_id,
  session_id,
  purchase_date,
  purchase_ts,
  raw_transaction_id AS transaction_id,
  transaction_id_status,
  purchase_revenue,
  total_item_quantity,

  purchase_revenue IS NOT NULL
    AND purchase_revenue >= 0 AS is_revenue_eligible,

  source_event_count,
  source_event_count - 1 AS duplicate_event_rows_removed,
  source_event_count > 1 AS was_deduplicated

FROM ranked
WHERE purchase_row_number = 1;
