-- =============================================================================
-- 02_mart_channel_performance.sql
-- Camada Gold: desempenho agregado por modelo e canal.
-- Formato longo, apropriado para análise, gráficos e exportação.
-- =============================================================================

DECLARE existing_object_type STRING DEFAULT (
  SELECT table_type
  FROM
    `ga4-attribution-project-511113.ga4_attribution.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'mart_channel_performance'
  LIMIT 1
);

IF existing_object_type = 'BASE TABLE' THEN
  EXECUTE IMMEDIATE '''
    DROP TABLE
      `ga4-attribution-project-511113.ga4_attribution.mart_channel_performance`
  ''';
ELSEIF existing_object_type = 'VIEW' THEN
  EXECUTE IMMEDIATE '''
    DROP VIEW
      `ga4-attribution-project-511113.ga4_attribution.mart_channel_performance`
  ''';
END IF;

CREATE VIEW
  `ga4-attribution-project-511113.ga4_attribution.mart_channel_performance`
AS

WITH channel_metrics AS (
  SELECT
    attribution_model,
    source,
    medium,
    channel,
    channel_quality_status,

    COUNT(DISTINCT purchase_key) AS touched_purchases,
    COUNT(DISTINCT session_key) AS contributing_sessions,

    SUM(conversion_credit) AS attributed_conversions,
    SUM(revenue_credit) AS attributed_revenue,

    SAFE_DIVIDE(
      SUM(days_before_purchase * conversion_credit),
      SUM(conversion_credit)
    ) AS weighted_avg_days_before_purchase

  FROM
    `ga4-attribution-project-511113.ga4_attribution.fct_attribution`

  GROUP BY
    attribution_model,
    source,
    medium,
    channel,
    channel_quality_status
)

SELECT
  *,

  SAFE_DIVIDE(
    attributed_conversions,
    SUM(attributed_conversions) OVER (
      PARTITION BY attribution_model
    )
  ) AS conversion_share,

  SAFE_DIVIDE(
    attributed_revenue,
    SUM(attributed_revenue) OVER (
      PARTITION BY attribution_model
    )
  ) AS revenue_share,

  DENSE_RANK() OVER (
    PARTITION BY attribution_model
    ORDER BY attributed_conversions DESC
  ) AS conversion_rank,

  DENSE_RANK() OVER (
    PARTITION BY attribution_model
    ORDER BY attributed_revenue DESC
  ) AS revenue_rank

FROM channel_metrics;
