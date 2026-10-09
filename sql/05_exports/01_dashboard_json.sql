-- =============================================================================
-- 01_dashboard_json.sql
-- Exporta todos os dados agregados necessários ao dashboard HTML.
-- O resultado contém uma única célula JSON, sem dados pessoais ou credenciais.
-- =============================================================================

SELECT
  TO_JSON_STRING(
    STRUCT(
      CURRENT_TIMESTAMP() AS generated_at,
      '2020-11-01' AS source_start_date,
      '2021-01-31' AS source_end_date,
      30 AS attribution_window_days,
      7 AS time_decay_half_life_days,

      (
        SELECT AS STRUCT
          COUNT(*) AS total_journeys,
          COUNTIF(is_multi_touch) AS multi_touch_journeys,
          ROUND(
            100 * SAFE_DIVIDE(COUNTIF(is_multi_touch), COUNT(*)),
            2
          ) AS multi_touch_pct,
          COUNTIF(is_multi_channel) AS multi_channel_journeys,
          ROUND(
            100 * SAFE_DIVIDE(COUNTIF(is_multi_channel), COUNT(*)),
            2
          ) AS multi_channel_pct,
          COUNTIF(has_unattributed_touchpoint)
            AS journeys_with_unattributed,
          COUNTIF(had_self_referral_removed)
            AS journeys_with_self_referral_removed,
          ROUND(AVG(total_touchpoints), 2) AS avg_touchpoints,
          ROUND(AVG(journey_duration_days), 2)
            AS avg_journey_duration_days,
          ROUND(
            APPROX_QUANTILES(
              journey_duration_days,
              100
            )[OFFSET(50)],
            2
          ) AS median_journey_duration_days,
          ROUND(
            APPROX_QUANTILES(
              journey_duration_days,
              100
            )[OFFSET(90)],
            2
          ) AS p90_journey_duration_days,
          ROUND(MAX(journey_duration_days), 2)
            AS max_journey_duration_days,
          ROUND(
            SUM(IF(is_revenue_eligible, purchase_revenue, 0)),
            2
          ) AS canonical_revenue
        FROM
          `ga4-attribution-project-511113.ga4_attribution.mart_journey_analysis`
      ) AS kpis,

      ARRAY(
        SELECT AS STRUCT
          channel,
          source,
          medium,
          channel_quality_status,
          ROUND(first_click_conversions, 4)
            AS first_click_conversions,
          ROUND(last_click_conversions, 4)
            AS last_click_conversions,
          ROUND(linear_conversions, 4)
            AS linear_conversions,
          ROUND(time_decay_conversions, 4)
            AS time_decay_conversions,
          ROUND(position_based_conversions, 4)
            AS position_based_conversions,
          ROUND(first_click_revenue, 2)
            AS first_click_revenue,
          ROUND(last_click_revenue, 2)
            AS last_click_revenue,
          ROUND(linear_revenue, 2)
            AS linear_revenue,
          ROUND(time_decay_revenue, 2)
            AS time_decay_revenue,
          ROUND(position_based_revenue, 2)
            AS position_based_revenue,
          ROUND(100 * first_click_vs_last_click_pct, 2)
            AS first_click_vs_last_click_pct,
          ROUND(100 * linear_vs_last_click_pct, 2)
            AS linear_vs_last_click_pct,
          ROUND(100 * time_decay_vs_last_click_pct, 2)
            AS time_decay_vs_last_click_pct,
          ROUND(100 * position_based_vs_last_click_pct, 2)
            AS position_based_vs_last_click_pct
        FROM
          `ga4-attribution-project-511113.ga4_attribution.mart_model_comparison`
        ORDER BY last_click_conversions DESC
      ) AS channels,

      ARRAY(
        SELECT AS STRUCT
          total_touchpoints,
          COUNT(*) AS journeys,
          ROUND(
            100 * SAFE_DIVIDE(
              COUNT(*),
              SUM(COUNT(*)) OVER ()
            ),
            2
          ) AS journey_share_pct,
          ROUND(
            SUM(IF(is_revenue_eligible, purchase_revenue, 0)),
            2
          ) AS revenue
        FROM
          `ga4-attribution-project-511113.ga4_attribution.mart_journey_analysis`
        GROUP BY total_touchpoints
        ORDER BY total_touchpoints
      ) AS touchpoint_distribution,

      ARRAY(
        SELECT AS STRUCT
          COALESCE(
            conversion_device_category,
            '(unknown)'
          ) AS device_category,
          COUNT(*) AS journeys,
          ROUND(
            100 * SAFE_DIVIDE(
              COUNT(*),
              SUM(COUNT(*)) OVER ()
            ),
            2
          ) AS journey_share_pct,
          ROUND(
            SUM(IF(is_revenue_eligible, purchase_revenue, 0)),
            2
          ) AS revenue
        FROM
          `ga4-attribution-project-511113.ga4_attribution.mart_journey_analysis`
        GROUP BY device_category
        ORDER BY journeys DESC
      ) AS devices,

      ARRAY(
        SELECT AS STRUCT
          FORMAT_DATE('%Y-%m', purchase_date) AS month,
          COUNT(*) AS journeys,
          ROUND(
            SUM(IF(is_revenue_eligible, purchase_revenue, 0)),
            2
          ) AS revenue,
          ROUND(AVG(total_touchpoints), 2)
            AS avg_touchpoints,
          ROUND(AVG(journey_duration_days), 2)
            AS avg_journey_duration_days
        FROM
          `ga4-attribution-project-511113.ga4_attribution.mart_journey_analysis`
        GROUP BY month
        ORDER BY month
      ) AS monthly_trend
    ),
    TRUE
  ) AS dashboard_json;
