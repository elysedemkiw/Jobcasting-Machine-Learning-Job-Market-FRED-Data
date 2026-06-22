#install.packages(c("rlang", "devtools", "readr", "pracma", "rpart", "rpart.plot"))
devtools::install_github("cykbennie/fbi")

install.packages("rlang")
library(fbi); library(rpart); library(rpart.plot)

raw <- fredmd("/Users/elyse/Desktop/jobcasting/current.csv", transform = TRUE)
clean <- rm_outliers.fredmd(raw)

lagk <- function(x, k) c(rep(NA, k), head(x, length(x) - k))

# component employment series + which sector each belongs to
industries <- c(mining = "CES1021000001", construction = "USCONS",
                durable_mfg = "DMANEMP", nondurable_mfg = "NDMANEMP",
                financial = "USFIRE")
sector <- c(mining = "goods", construction = "goods", durable_mfg = "goods",
            nondurable_mfg = "goods", financial = "white")

# economy-wide predictors (identical across industries at each date)
predictors <- c(claims = "CLAIMSx", indpro = "INDPRO", hours = "AWHMAN",
                permits = "PERMIT", unrate = "UNRATE", spread = "T10YFFM")

build_one <- function(ind) {
  d <- data.frame(date = clean$date, industry = ind, sector = sector[[ind]])
  d$target <- clean[[ industries[[ind]] ]]
  for (nm in names(predictors)) d[[nm]] <- clean[[ predictors[[nm]] ]]
  d$target_lag1 <- lagk(d$target, 1)
  d
}

# 1-3: stack all industries into one long panel
panel <- do.call(rbind, lapply(names(industries), build_one))
panel <- panel[complete.cases(panel), ]
panel$industry <- factor(panel$industry)
panel$sector   <- factor(panel$sector)

# 4: one time split for the whole stack
split_date <- as.Date("2015-01-01")
train <- panel[panel$date <  split_date, ]
test  <- panel[panel$date >= split_date, ]

# 5: one tree across all industries
fit <- rpart(target ~ industry + sector + claims + indpro + hours +
               permits + unrate + spread + target_lag1,
             data = train, method = "anova",
             control = rpart.control(maxdepth = 5, cp = 0.005, minbucket = 30))

rpart.plot(fit, type = 2, extra = 101, box.palette = "RdYlGn",
           main = "Panel tree: monthly job creation across industries")

          png("/Users/elyse/Desktop/jobcasting/panel_tree.png", width = 1200, height = 800, res = 130)
rpart.plot(fit, type = 2, extra = 101, box.palette = "RdYlGn",
           main = "Panel tree: monthly job creation across industries")
dev.off()

# 6: evaluate overall, then per industry
test$pred <- predict(fit, test)
rmse <- function(a, b) sqrt(mean((a - b)^2))
cat(sprintf("Overall RMSE: %.5f\n", rmse(test$target, test$pred)))
for (ind in levels(test$industry)) {
  s <- test[test$industry == ind, ]
  cat(sprintf("  %-15s RMSE %.5f\n", ind, rmse(s$target, s$pred)))
}

# ===== Boosted model + evaluation =====
# install.packages("xgboost")   # run ONCE in the console, then leave commented
library(xgboost)

rmse <- function(a, b) sqrt(mean((a - b)^2))

# one-hot encode industry + the indicators (sector dropped; it's implied by industry)
X <- model.matrix(~ industry + claims + indpro + hours + permits +
                    unrate + spread + target_lag1 - 1, data = panel)
y <- panel$target

idx_full <- panel$date <  split_date   # train: everything pre-2015
idx_test <- panel$date >= split_date   # test:  2015 onward

dfull <- xgb.DMatrix(X[idx_full, ], label = y[idx_full])
dtest <- xgb.DMatrix(X[idx_test, ], label = y[idx_test])

params <- list(objective = "reg:squarederror",
               eta = 0.05, max_depth = 4,
               subsample = 0.8, colsample_bytree = 0.8)

best_n <- 250
set.seed(1)
bst <- xgb.train(params, dfull, nrounds = best_n, verbose = 0)

print(head(xgb.importance(model = bst), 10))   # which features drive it

# ---- fair tree-vs-boosting: both trained on the same pre-2015 data ----
pred_xgb  <- predict(bst, dtest)
pred_tree <- predict(fit, test)
ytest     <- y[idx_test]
base_full <- tapply(y[idx_full], panel$industry[idx_full], mean)

report <- function(pred, label) {
  ind <- panel$industry[idx_test]
  cat(sprintf("\n== %s ==\n", label))
  for (i in levels(ind)) {
    s <- ind == i; b <- rep(base_full[i], sum(s))
    cat(sprintf("  %-15s rmse %.5f  skill %+.1f%%\n", i,
                rmse(ytest[s], pred[s]),
                100 * (1 - rmse(ytest[s], pred[s]) / rmse(ytest[s], b))))
  }
  cat(sprintf("  OVERALL          rmse %.5f  skill %+.1f%%\n",
              rmse(ytest, pred),
              100 * (1 - rmse(ytest, pred) / rmse(ytest, base_full[as.character(ind)]))))
}
report(pred_tree, "Single tree (rpart)")
report(pred_xgb,  "Boosted (XGBoost)")

# ---- expanding-window evaluation: refit each test month on all prior data ----
test_months <- sort(unique(panel$date[idx_test]))
ew <- data.frame()
set.seed(1)
for (k in seq_along(test_months)) {
  t  <- test_months[k]
  tr <- panel$date <  t
  te <- panel$date == t
  m  <- xgb.train(params, xgb.DMatrix(X[tr, ], label = y[tr]),
                  nrounds = best_n, verbose = 0)
  ew <- rbind(ew, data.frame(industry = panel$industry[te],
                             actual   = y[te],
                             pred     = predict(m, xgb.DMatrix(X[te, ]))))
}

cat("\n== Expanding window (refit every month) ==\n")
for (i in levels(ew$industry)) {
  s <- ew$industry == i; b <- rep(base_full[i], sum(s))
  cat(sprintf("  %-15s rmse %.5f  skill %+.1f%%\n", i,
              rmse(ew$actual[s], ew$pred[s]),
              100 * (1 - rmse(ew$actual[s], ew$pred[s]) / rmse(ew$actual[s], b))))
}
cat(sprintf("  OVERALL          rmse %.5f  skill %+.1f%%\n",
            rmse(ew$actual, ew$pred),
            100 * (1 - rmse(ew$actual, ew$pred) / rmse(ew$actual, base_full[as.character(ew$industry)]))))