-- =============================================================================
-- 01_fct_attribution.sql
-- Camada Gold: créditos de conversão e receita por touchpoint e modelo.
--
-- Modelos:
--   first_click    -> 100% para o primeiro touchpoint;
--   last_click     -> 100% para o último touchpoint;
--   linear         -> crédito igual;
--   time_decay     -> meia-vida de 7 dias;
--   position_based -> 40% primeiro, 40% último, 20% intermediários.
-- =============================================================================

DECLARE existing_object_type STRING DEFAULT (
  SELECT table_type
  FROM
    `ga4-attribution-project-511113.ga4_attribution.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'fct_attribution'
  LIMIT 1
);

IF existing_object_type = 'BASE TABLE' THEN
  EXECUTE IMMEDIATE '''
    DROP TABLE
      `ga4-attribution-project-511113.ga4_attribution.fct_attribution`
  ''';
ELSEIF existing_object_type = 'VIEW' THEN
  EXECUTE IMMEDIATE '''
    DROP VIEW
      `ga4-attribution-project-511113.ga4_attribution.fct_attribution`
  ''';
END IF;

CREATE VIEW
  `ga4-attribution-project-511113.ga4_attribution.fct_attribution`
AS

WITH weighted_touchpoints AS (
  SELECT
    *,

    POW(
      0.5,
      days_before_purchase / 7.0
    ) AS raw_time_decay_weight

  FROM
    `ga4-attribution-project-511113.ga4_attribution.int_touchpoints`
),

model_credits AS (
  SELECT
    *,

    IF(touchpoint_position = 1, 1.0, 0.0)
      AS first_click_credit,

    IF(reverse_touchpoint_position = 1, 1.0, 0.0)
      AS last_click_credit,

    SAFE_DIVIDE(1.0, total_touchpoints)
      AS linear_credit,

    SAFE_DIVIDE(
      raw_time_decay_weight,
      SUM(raw_time_decay_weight) OVER (
        PARTITION BY purchase_key
      )
    ) AS time_decay_credit,

    CASE
      WHEN total_touchpoints = 1 THEN 1.0
      WHEN total_touchpoints = 2 THEN 0.5
      WHEN touchpoint_position = 1 THEN 0.4
      WHEN reverse_touchpoint_position = 1 THEN 0.4
      ELSE SAFE_DIVIDE(0.2, total_touchpoints - 2)
    END AS position_based_credit

  FROM weighted_touchpoints
),

long_format AS (
  SELECT *, 'first_click' AS attribution_model,
    first_click_credit AS conversion_credit
  FROM model_credits

  UNION ALL

  SELECT *, 'last_click' AS attribution_model,
    last_click_credit AS conversion_credit
  FROM model_credits

  UNION ALL

  SELECT *, 'linear' AS attribution_model,
    linear_credit AS conversion_credit
  FROM model_credits

  UNION ALL

  SELECT *, 'time_decay' AS attribution_model,
    time_decay_credit AS conversion_credit
  FROM model_credits

  UNION ALL

  SELECT *, 'position_based' AS attribution_model,
    position_based_credit AS conversion_credit
  FROM model_credits
)

SELECT
  attribution_model,
  purchase_key,
  transaction_id,
  purchase_date,
  purchase_ts,
  purchase_revenue,
  is_revenue_eligible,

  session_key,
  session_date,
  session_start_ts,
  source,
  medium,
  campaign,
  channel,
  channel_quality_status,
  device_category,
  country,

  touchpoint_position,
  reverse_touchpoint_position,
  total_touchpoints,
  days_before_purchase,
  is_conversion_session,

  conversion_credit,

  IF(
    is_revenue_eligible,
    purchase_revenue * conversion_credit,
    NULL
  ) AS revenue_credit

FROM long_format;
