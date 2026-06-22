### Results 

## Single tree (rpart) 

| Sector | RMSE | Skill |
|---|---|---|---|
  construction  |   0.00352  | -0.1%
  durable_mfg    |  0.00284  |  -14.3%
  financial     |   0.00165 |  -12.2%
  mining         |  0.00885 |  +16.0%
  nondurable_mfg  | 0.00232 |  -3.0%
  OVERALL          | 0.00462 | skill | +11.6%
## Boosted (XGBoost)
  construction    rmse 0.00362  skill -3.1%
  durable_mfg     rmse 0.00250  skill -0.4%
  financial       rmse 0.00139  skill +5.1%
  mining          rmse 0.01137  skill -8.0%
  nondurable_mfg  rmse 0.00169  skill +24.9%
  OVERALL          rmse 0.00554  skill -5.9%

## Expanding window (refit every month) 
  construction    rmse 0.00332  skill +5.5%
  durable_mfg     rmse 0.00264  skill -6.4%
  financial       rmse 0.00134  skill +8.8%
  mining          rmse 0.00866  skill +17.8%
  nondurable_mfg  rmse 0.00177  skill +21.3%
  OVERALL          rmse 0.00443  skill +15.3%


## Nowcast for April 2026 (monthly job growth rate):

       industry nowcast_growth actual_growth direction
         mining       2.38e-04      0.004410      gain
   construction       2.51e-03      0.001082      gain
    durable_mfg       1.75e-03      0.000256      gain
 nondurable_mfg       1.23e-03     -0.000838      gain
      financial      -9.62e-05     -0.001206      loss
