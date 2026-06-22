
# Jobcasting: nowcasting US industry job creation

library(fbi)
library(xgboost)

# ---- 1. Load and clean FRED-MD ----
raw   <- fredmd("/Users/elyse/Desktop/jobcasting/current.csv", transform = TRUE)
clean <- rm_outliers.fredmd(raw)

# ---- 2. Build the panel: one row per industry per month ----
lagk <- function(x, k) c(rep(NA, k), head(x, length(x) - k))

industries <- c(mining = "CES1021000001", construction = "USCONS",
                durable_mfg = "DMANEMP", nondurable_mfg = "NDMANEMP",
                financial = "USFIRE")
predictors <- c(claims = "CLAIMSx", indpro = "INDPRO", hours = "AWHMAN",
                permits = "PERMIT", unrate = "UNRATE", spread = "T10YFFM")

build_one <- function(ind) {
  d <- data.frame(date = clean$date, industry = ind)
  d$target <- clean[[ industries[[ind]] ]]
  for (nm in names(predictors)) d[[nm]] <- clean[[ predictors[[nm]] ]]
  d$target_lag1 <- lagk(d$target, 1)
  d
}
panel <- do.call(rbind, lapply(names(industries), build_one))
panel <- panel[complete.cases(panel), ]
panel$industry <- factor(panel$industry)

# ---- 3. Train on all history except the latest month ----
X <- model.matrix(~ industry + claims + indpro + hours + permits +
                    unrate + spread + target_lag1 - 1, data = panel)
y <- panel$target

latest    <- max(panel$date)
idx_train <- panel$date <  latest
idx_now   <- panel$date == latest

params <- list(objective = "reg:squarederror", eta = 0.05, max_depth = 4,
               subsample = 0.8, colsample_bytree = 0.8)
set.seed(1)
model <- xgb.train(params, xgb.DMatrix(X[idx_train, ], label = y[idx_train]),
                   nrounds = 250, verbose = 0)

# ---- 4. Nowcast the latest month ----
nowcast <- data.frame(
  industry       = panel$industry[idx_now],
  nowcast_growth = predict(model, xgb.DMatrix(X[idx_now, ])),
  actual_growth  = y[idx_now]
)
nowcast$direction <- ifelse(nowcast$nowcast_growth >= 0, "gain", "loss")

cat(sprintf("\nNowcast for %s (monthly job growth rate):\n\n", format(latest, "%B %Y")))
print(nowcast, row.names = FALSE, digits = 3)