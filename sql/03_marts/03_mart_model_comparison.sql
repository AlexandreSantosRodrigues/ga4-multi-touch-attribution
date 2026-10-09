-- =============================================================================
-- 03_mart_model_comparison.sql
-- Camada Gold: comparação ampla dos modelos por canal.
-- Inclui conversões, receita e variações em relação ao Last-Click.
-- =============================================================================

DECLARE existing_object_type STRING DEFAULT (
  SELECT table_type
  FROM
    `ga4-attribution-project-511113.ga4_attribution.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'mart_model_comparison'
  LIMIT 1
);

IF existing_object_type = 'BASE TABLE' THEN
  EXECUTE IMMEDIATE '''
    DROP TABLE
      `ga4-attribution-project-511113.ga4_attribution.mart_model_comparison`
  ''';
ELSEIF existing_object_type = 'VIEW' THEN
  EXECUTE IMMEDIATE '''
    DROP VIEW
      `ga4-attribution-project-511113.ga4_attribution.mart_model_comparison`
  ''';
END IF;

CREATE VIEW
  `ga4-attribution-project-511113.ga4_attribution.mart_model_comparison`
AS

WITH pivoted AS (
  SELECT
    source,
    medium,
    channel,
    channel_quality_status,

    SUM(IF(attribution_model = 'first_click',
      attributed_conversions, 0)) AS first_click_conversions,

    SUM(IF(attribution_model = 'last_click',
      attributed_conversions, 0)) AS last_click_conversions,

    SUM(IF(attribution_model = 'linear',
      attributed_conversions, 0)) AS linear_conversions,

    SUM(IF(attribution_model = 'time_decay',
      attributed_conversions, 0)) AS time_decay_conversions,

    SUM(IF(attribution_model = 'position_based',
      attributed_conversions, 0)) AS position_based_conversions,

    SUM(IF(attribution_model = 'first_click',
      attributed_revenue, 0)) AS first_click_revenue,

    SUM(IF(attribution_model = 'last_click',
      attributed_revenue, 0)) AS last_click_revenue,

    SUM(IF(attribution_model = 'linear',
      attributed_revenue, 0)) AS linear_revenue,

    SUM(IF(attribution_model = 'time_decay',
      attributed_revenue, 0)) AS time_decay_revenue,

    SUM(IF(attribution_model = 'position_based',
      attributed_revenue, 0)) AS position_based_revenue

  FROM
    `ga4-attribution-project-511113.ga4_attribution.mart_channel_performance`

  GROUP BY
    source,
    medium,
    channel,
    channel_quality_status
)

SELECT
  *,

  SAFE_DIVIDE(
    first_click_conversions - last_click_conversions,
    NULLIF(last_click_conversions, 0)
  ) AS first_click_vs_last_click_pct,

  SAFE_DIVIDE(
    linear_conversions - last_click_conversions,
    NULLIF(last_click_conversions, 0)
  ) AS linear_vs_last_click_pct,

  SAFE_DIVIDE(
    time_decay_conversions - last_click_conversions,
    NULLIF(last_click_conversions, 0)
  ) AS time_decay_vs_last_click_pct,

  SAFE_DIVIDE(
    position_based_conversions - last_click_conversions,
    NULLIF(last_click_conversions, 0)
  ) AS position_based_vs_last_click_pct,

  SAFE_DIVIDE(
    first_click_revenue - last_click_revenue,
    NULLIF(last_click_revenue, 0)
  ) AS first_click_revenue_vs_last_click_pct,

  SAFE_DIVIDE(
    linear_revenue - last_click_revenue,
    NULLIF(last_click_revenue, 0)
  ) AS linear_revenue_vs_last_click_pct,

  SAFE_DIVIDE(
    time_decay_revenue - last_click_revenue,
    NULLIF(last_click_revenue, 0)
  ) AS time_decay_revenue_vs_last_click_pct,

  SAFE_DIVIDE(
    position_based_revenue - last_click_revenue,
    NULLIF(last_click_revenue, 0)
  ) AS position_based_revenue_vs_last_click_pct

FROM pivoted;
