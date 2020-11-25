CREATE OR REPLACE MODEL `bqml.rpm_bqml_model`
OPTIONS(MODEL_TYPE = 'logistic_reg',
        labels = [ 'will_buy_on_return_visit' ]
        )
AS
SELECT * EXCEPT (fullVisitorId)
FROM `bqml.propensity_data`;