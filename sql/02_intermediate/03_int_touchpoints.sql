-- =============================================================================
-- 03_int_touchpoints.sql
-- Camada Intermediate: sessões elegíveis em cada jornada de conversão.
--
-- Regras:
--   - janela máxima de atribuição: 30 dias;
--   - sessões posteriores à compra são excluídas;
--   - após uma compra, inicia-se uma nova jornada;
--   - cada sessão possui o canal já limpo em int_sessions;
--   - sessões sem canal são preservadas como unattributed.
-- =============================================================================

DECLARE existing_object_type STRING DEFAULT (
  SELECT table_type
  FROM
    `ga4-attribution-project-511113.ga4_attribution.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'int_touchpoints'
  LIMIT 1
);

IF existing_object_type = 'BASE TABLE' THEN
  EXECUTE IMMEDIATE '''
    DROP TABLE
      `ga4-attribution-project-511113.ga4_attribution.int_touchpoints`
  ''';
ELSEIF existing_object_type = 'VIEW' THEN
  EXECUTE IMMEDIATE '''
    DROP VIEW
      `ga4-attribution-project-511113.ga4_attribution.int_touchpoints`
  ''';
END IF;

CREATE VIEW
  `ga4-attribution-project-511113.ga4_attribution.int_touchpoints`
AS

WITH ordered_purchases AS (
  SELECT
    p.*,

    LAG(purchase_ts) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY purchase_ts, purchase_key
    ) AS previous_purchase_ts

  FROM
    `ga4-attribution-project-511113.ga4_attribution.int_purchases` AS p
),

journey_boundaries AS (
  SELECT
    *,

    GREATEST(
      TIMESTAMP_SUB(purchase_ts, INTERVAL 30 DAY),
      COALESCE(
        previous_purchase_ts,
        TIMESTAMP '1900-01-01 00:00:00+00'
      )
    ) AS journey_start_ts

  FROM ordered_purchases
),

eligible_touchpoints AS (
  SELECT
    p.purchase_key,
    p.transaction_id,
    p.transaction_id_status,
    p.purchase_date,
    p.purchase_ts,
    p.purchase_revenue,
    p.is_revenue_eligible,
    p.previous_purchase_ts,
    p.journey_start_ts,

    s.session_key,
    s.session_date,
    s.session_start_ts,
    s.session_end_ts,
    s.source,
    s.medium,
    s.campaign,
    s.channel,
    s.channel_quality_status,
    s.device_category,
    s.country,
    s.had_self_referral_removed,

    TIMESTAMP_DIFF(
      p.purchase_ts,
      s.session_start_ts,
      SECOND
    ) / 86400.0 AS days_before_purchase,

    s.session_key = p.session_key AS is_conversion_session

  FROM journey_boundaries AS p
  INNER JOIN
    `ga4-attribution-project-511113.ga4_attribution.int_sessions` AS s
    ON p.user_pseudo_id = s.user_pseudo_id
   AND s.session_start_ts <= p.purchase_ts
   AND (
     s.session_start_ts > p.journey_start_ts
     OR s.session_key = p.session_key
   )
)

SELECT
  *,

  ROW_NUMBER() OVER (
    PARTITION BY purchase_key
    ORDER BY session_start_ts, session_key
  ) AS touchpoint_position,

  COUNT(*) OVER (
    PARTITION BY purchase_key
  ) AS total_touchpoints,

  ROW_NUMBER() OVER (
    PARTITION BY purchase_key
    ORDER BY session_start_ts DESC, session_key DESC
  ) AS reverse_touchpoint_position

FROM eligible_touchpoints;
