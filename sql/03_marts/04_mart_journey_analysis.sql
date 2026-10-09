-- =============================================================================
-- 04_mart_journey_analysis.sql
-- Camada Gold: uma linha por jornada/compra.
-- Usado para EDA, métricas de comportamento e dashboard.
-- =============================================================================

DECLARE existing_object_type STRING DEFAULT (
  SELECT table_type
  FROM
    `ga4-attribution-project-511113.ga4_attribution.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'mart_journey_analysis'
  LIMIT 1
);

IF existing_object_type = 'BASE TABLE' THEN
  EXECUTE IMMEDIATE '''
    DROP TABLE
      `ga4-attribution-project-511113.ga4_attribution.mart_journey_analysis`
  ''';
ELSEIF existing_object_type = 'VIEW' THEN
  EXECUTE IMMEDIATE '''
    DROP VIEW
      `ga4-attribution-project-511113.ga4_attribution.mart_journey_analysis`
  ''';
END IF;

CREATE VIEW
  `ga4-attribution-project-511113.ga4_attribution.mart_journey_analysis`
AS

SELECT
  purchase_key,
  ANY_VALUE(transaction_id) AS transaction_id,
  ANY_VALUE(purchase_date) AS purchase_date,
  ANY_VALUE(purchase_ts) AS purchase_ts,
  ANY_VALUE(purchase_revenue) AS purchase_revenue,
  LOGICAL_OR(is_revenue_eligible) AS is_revenue_eligible,

  MAX(total_touchpoints) AS total_touchpoints,
  COUNT(DISTINCT channel) AS distinct_channels,

  MAX(days_before_purchase) AS journey_duration_days,

  ARRAY_AGG(
    channel
    ORDER BY touchpoint_position
    LIMIT 1
  )[OFFSET(0)] AS first_channel,

  ARRAY_AGG(
    channel
    ORDER BY reverse_touchpoint_position
    LIMIT 1
  )[OFFSET(0)] AS last_channel,

  ARRAY_AGG(
    device_category
    IGNORE NULLS
    ORDER BY IF(is_conversion_session, 0, 1), touchpoint_position
    LIMIT 1
  )[SAFE_OFFSET(0)] AS conversion_device_category,

  ARRAY_AGG(
    country
    IGNORE NULLS
    ORDER BY IF(is_conversion_session, 0, 1), touchpoint_position
    LIMIT 1
  )[SAFE_OFFSET(0)] AS conversion_country,

  MAX(total_touchpoints) > 1 AS is_multi_touch,
  COUNT(DISTINCT channel) > 1 AS is_multi_channel,

  COUNTIF(
    channel_quality_status = 'unattributed'
  ) > 0 AS has_unattributed_touchpoint,

  LOGICAL_OR(had_self_referral_removed)
    AS had_self_referral_removed

FROM
  `ga4-attribution-project-511113.ga4_attribution.int_touchpoints`

GROUP BY purchase_key;
