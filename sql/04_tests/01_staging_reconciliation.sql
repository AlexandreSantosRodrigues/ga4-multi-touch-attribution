-- =============================================================================
-- 01_staging_reconciliation.sql
-- Teste: reconciliação da camada Staging com a fonte pública.
-- Resultado esperado: todos os status = PASS.
-- =============================================================================

WITH staging AS (
  SELECT
    COUNT(*) AS total_rows,
    MIN(event_date) AS min_event_date,
    MAX(event_date) AS max_event_date,
    COUNTIF(event_name = 'purchase') AS purchase_rows,
    COUNTIF(event_name = 'session_start') AS session_start_rows,
    COUNT(DISTINCT user_pseudo_id) AS distinct_users
  FROM
    `ga4-attribution-project-511113.ga4_attribution.stg_ga4_events`
),

expected AS (
  SELECT
    4295584 AS total_rows,
    DATE '2020-11-01' AS min_event_date,
    DATE '2021-01-31' AS max_event_date,
    5692 AS purchase_rows,
    354970 AS session_start_rows
)

SELECT
  s.total_rows,
  IF(s.total_rows = e.total_rows, 'PASS', 'FAIL') AS total_rows_test,

  s.min_event_date,
  IF(s.min_event_date = e.min_event_date, 'PASS', 'FAIL')
    AS min_date_test,

  s.max_event_date,
  IF(s.max_event_date = e.max_event_date, 'PASS', 'FAIL')
    AS max_date_test,

  s.purchase_rows,
  IF(s.purchase_rows = e.purchase_rows, 'PASS', 'FAIL')
    AS purchase_rows_test,

  s.session_start_rows,
  IF(s.session_start_rows = e.session_start_rows, 'PASS', 'FAIL')
    AS session_start_rows_test,

  s.distinct_users,
  IF(s.distinct_users > 0, 'PASS', 'FAIL') AS users_test

FROM staging AS s
CROSS JOIN expected AS e;
