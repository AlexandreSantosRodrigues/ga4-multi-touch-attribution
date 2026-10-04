SELECT
  event_name,
  COUNT(*) AS total_eventos
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY event_name
ORDER BY total_eventos DESC;
