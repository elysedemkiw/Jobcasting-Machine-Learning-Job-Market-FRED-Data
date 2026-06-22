# Jobcasting-Machine-Learning-Job-Market-FRED-Data


Jobcasting nowcasts monthly US job creation by industry using machine learning on FRED-MD macroeconomic data. Nowcasting means predicting a number before its official release by reading timelier indicators like jobless claims, industrial production, and housing permits.

The project uses a panel setup. Every industry and month is stacked into one table with one row per industry per month, so a single model learns across all industries at once while telling them apart through an industry label. The industries are mining, construction, durable manufacturing, nondurable manufacturing (the goods producing group), and financial activities (a white collar proxy).

## Data

Data comes from FRED-MD, the monthly macro database from the Federal Reserve Bank of St. Louis (McCracken and Ng, 2016). Loading, transforming, and cleaning use the fbi R package by Yankang (Bennie) Chen, Serena Ng, and Jushan Bai: https://github.com/cykbennie/fbi. It reads the FRED-MD file, turns each employment series into a monthly growth rate, and removes outliers.

Download current.csv into the project folder from https://www.stlouisfed.org/research/economists/mccracken/fred-databases

### Targets (industry employment growth)

| FRED code | Description | Industry label | Group |
|---|---|---|---|
| CES1021000001 | Mining and logging employment | mining | goods |
| USCONS | Construction employment | construction | goods |
| DMANEMP | Durable goods manufacturing employment | durable_mfg | goods |
| NDMANEMP | Nondurable goods manufacturing employment | nondurable_mfg | goods |
| USFIRE | Financial activities employment | financial | white collar |

### Predictors

| FRED code | Description | Why it is included |
|---|---|---|
| CLAIMSx | Initial jobless claims | Weekly and timely, rises before layoffs show up in payrolls |
| INDPRO | Industrial production index | Output of factories, mines, and utilities, rising output leads hiring |
| AWHMAN | Average weekly hours, manufacturing | Employers cut hours before workers, so it leads job losses |
| PERMIT | New housing permits | Leading signal for construction jobs |
| UNRATE | Unemployment rate | Broad labor market slack |
| T10YFFM | 10 year Treasury yield minus the fed funds rate | The yield curve, a recession and financial conditions gauge |

### Engineered features

| Feature | Description |
|---|---|
| target_lag1 | The same industry's job growth in the previous month, capturing momentum |
| industry | The industry label, one hot encoded so one model can separate industries |


## Methodology

The model is gradient boosting (XGBoost), a sequence of small trees where each one corrects the errors of the ones before it. It was chosen after starting with a single decision tree, which was readable but too unstable

Models are scored out of sample and split strictly by time. Accuracy is reported as skill, the model error divided by a naive baseline that predicts each industry's average. The evaluation uses an expanding window, where the model refits every month on all data up to that point. This mirrors real time use and gives the trustworthy result. A single fixed split was misleading, suggesting negative skill, because it froze the model for over a decade

Expanding window skill is +15.3 percent overall, positive in four of five industries:


nondurable manufacturing: +21.3 percent
mining: +17.8 percent
financial activities: +8.8 percent
construction: +5.5 percent
durable manufacturing: -6.4 percent


The largest driver is last month's own job growth, followed by industrial production and housing permits

## How to run


Install packages: install.packages("xgboost") and devtools::install_github("cykbennie/fbi").
Download current.csv into the project folder.
Run the script. Each month, download a fresh current.csv and rerun.


## References

McCracken, M. W., and Ng, S. (2016). FRED-MD: A Monthly Database for Macroeconomic Research. Federal Reserve Bank of St. Louis.

Chen, Y., Ng, S., and Bai, J. fbi: Factor-Based Imputation and FRED-MD/QD Data Set. https://github.com/cykbennie/fbi

