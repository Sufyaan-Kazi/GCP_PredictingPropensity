SELECT
  roc_auc,
  # evaluating the auc value based on the scale at http://gim.unmc.edu/dxtests/roc3.htm
  CASE WHEN roc_auc >.9 THEN 'excellent' WHEN roc_auc >.8 THEN 'good'
  WHEN roc_auc >.7 THEN 'fair' WHEN roc_auc >.6 THEN 'poor' ELSE 'fail' END
  AS modelquality
FROM ML.EVALUATE(MODEL `bqml.rpm_bqml_model`);