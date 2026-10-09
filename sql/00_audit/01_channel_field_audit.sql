-- =============================================================================
-- 01_channel_field_audit.sql
-- Objetivo: inventariar parâmetros de tráfego disponíveis no dataset histórico.
-- Motivo: collected_traffic_source não existe nesta amostra de 2020–2021.
-- O resultado definirá a regra possível de canal por sessão.
-- =============================================================================

WITH parameter_inventory AS (
  SELECT
    ep.key AS parameter_key,
    COUNT(*) AS occurrences,
    COUNTIF(event_name = 'session_start') AS occurrences_on_session_start,
    COUNTIF(event_name = 'page_view') AS occurrences_on_page_view,
    COUNTIF(event_name = 'purchase') AS occurrences_on_purchase,
    COUNTIF(ep.value.string_value IS NOT NULL) AS string_values,
    COUNTIF(ep.value.int_value IS NOT NULL) AS int_values
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
  UNNEST(event_params) AS ep
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND (
      REGEXP_CONTAINS(
        LOWER(ep.key),
        r'(source|medium|campaign|gclid|term|content|referrer)'
      )
      OR ep.key IN ('ga_session_id', 'ga_session_number')
    )
  GROUP BY ep.key
)

SELECT
  parameter_key,
  occurrences,
  occurrences_on_session_start,
  occurrences_on_page_view,
  occurrences_on_purchase,
  string_values,
  int_values
FROM parameter_inventory
ORDER BY occurrences DESC, parameter_key;
