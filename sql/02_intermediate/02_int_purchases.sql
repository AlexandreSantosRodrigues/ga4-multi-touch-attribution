-- =============================================================================
-- 02_int_purchases.sql
-- Camada Intermediate: uma linha por compra canônica.
--
-- Evidências usadas:
--   - 5.692 eventos purchase na fonte;
--   - 883 transaction_id = '(not set)';
--   - 23 transaction_id nulos;
--   - IDs podem colidir entre usuários por causa da ofuscação;
--   - user_pseudo_id + transaction_id elimina conflitos;
--   - 320 eventos técnicos excedentes devem ser removidos;
--   - resultado esperado: 5.372 compras canônicas.
--
-- O bloco inicial torna o script idempotente: funciona se o objeto ainda não
-- existir, se for uma TABLE ou se for uma VIEW.
-- =============================================================================

DECLARE existing_object_type STRING DEFAULT (
  SELECT table_type
  FROM
    `ga4-attribution-project-511113.ga4_attribution.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'int_purchases'
  LIMIT 1
);

IF existing_object_type = 'BASE TABLE' THEN
  EXECUTE IMMEDIATE '''
    DROP TABLE
      `ga4-attribution-project-511113.ga4_attribution.int_purchases`
  ''';
ELSEIF existing_object_type = 'VIEW' THEN
  EXECUTE IMMEDIATE '''
    DROP VIEW
      `ga4-attribution-project-511113.ga4_attribution.int_purchases`
  ''';
END IF;

CREATE VIEW
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
  FROM
    `ga4-attribution-project-511113.ga4_attribution.stg_ga4_events`
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
        user_pseudo_id,
        '|',
        raw_transaction_id
      )
      ELSE CONCAT(
        'evt|',
        user_pseudo_id,
        '|',
        CAST(UNIX_MICROS(purchase_ts) AS STRING)
      )
    END AS purchase_key

  FROM purchase_events
  WHERE user_pseudo_id IS NOT NULL
    AND session_id IS NOT NULL
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
