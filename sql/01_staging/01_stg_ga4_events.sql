-- =============================================================================
-- 01_stg_ga4_events.sql
-- Camada: Staging
-- Destino: ga4-attribution-project-511113.ga4_attribution.stg_ga4_events
-- Estratégia: materialização particionada e clusterizada para reduzir releituras
-- do dataset bruto e padronizar a extração de parâmetros aninhados.
-- =============================================================================

CREATE OR REPLACE TABLE
  `ga4-attribution-project-511113.ga4_attribution.stg_ga4_events`
PARTITION BY event_date
CLUSTER BY event_name, user_pseudo_id
OPTIONS (
  description = 'Eventos GA4 tipados e achatados a partir da amostra pública; camada staging do pipeline de atribuição.'
)
AS

SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  TIMESTAMP_MICROS(event_timestamp) AS event_timestamp,
  event_name,
  user_pseudo_id,

  (
    SELECT ep.value.int_value
    FROM UNNEST(event_params) AS ep
    WHERE ep.key = 'ga_session_id'
    LIMIT 1
  ) AS session_id,

  (
    SELECT ep.value.int_value
    FROM UNNEST(event_params) AS ep
    WHERE ep.key = 'ga_session_number'
    LIMIT 1
  ) AS session_number,

  (
    SELECT ep.value.string_value
    FROM UNNEST(event_params) AS ep
    WHERE ep.key = 'source'
    LIMIT 1
  ) AS source,

  (
    SELECT ep.value.string_value
    FROM UNNEST(event_params) AS ep
    WHERE ep.key = 'medium'
    LIMIT 1
  ) AS medium,

  (
    SELECT ep.value.string_value
    FROM UNNEST(event_params) AS ep
    WHERE ep.key = 'campaign'
    LIMIT 1
  ) AS campaign,

  (
    SELECT ep.value.string_value
    FROM UNNEST(event_params) AS ep
    WHERE ep.key = 'page_location'
    LIMIT 1
  ) AS page_location,

  (
    SELECT ep.value.string_value
    FROM UNNEST(event_params) AS ep
    WHERE ep.key = 'page_referrer'
    LIMIT 1
  ) AS page_referrer,

  traffic_source.source AS first_user_source,
  traffic_source.medium AS first_user_medium,
  traffic_source.name AS first_user_campaign,

  device.category AS device_category,
  device.operating_system AS operating_system,
  device.web_info.browser AS browser,

  geo.country AS country,
  geo.region AS region,
  geo.city AS city,

  ecommerce.transaction_id AS transaction_id,
  ecommerce.purchase_revenue AS purchase_revenue,
  ecommerce.total_item_quantity AS total_item_quantity,

  CURRENT_TIMESTAMP() AS processed_at

FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

WHERE
  _TABLE_SUFFIX BETWEEN '20201101' AND '20210131';
