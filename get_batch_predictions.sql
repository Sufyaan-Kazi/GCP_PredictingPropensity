# predict the inputs (rows) from the input table
SELECT
  fullVisitorId,
  predicted_will_buy_on_return_visit
FROM ML.PREDICT(MODEL bqml.rpm_bqml_model,
(
   SELECT
   fullVisitorId,
   bounces,
   time_on_site
   from bqml.propensity_data
))