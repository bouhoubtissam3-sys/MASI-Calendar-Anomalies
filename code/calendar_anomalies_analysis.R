# =========================================================
# Calendar Anomalies in the Moroccan Stock Market
# =========================================================

# 1. Packages
library(readxl)
library(dplyr)
library(lubridate)
library(lmtest)
library(sandwich)
library(ggplot2)

# 2. Import data
file_path <- "data/Finance comportementale.xlsx"

returns <- read_excel(
  file_path,
  sheet = "Rendements et Calculs"
)

# 3. Construct market return
stock_columns <- c(
  "AWB", "BCP", "BOA", "CIH", "MNG",
  "RDS", "ADI", "ADH", "ATL", "WAA",
  "TQM", "CMA", "LHM", "CSR", "IAM"
)

returns <- returns %>%
  mutate(
    Rm = rowMeans(
      across(all_of(stock_columns)),
      na.rm = TRUE
    )
  )

returns$Rm[is.nan(returns$Rm)] <- NA

# 4. Create calendar variables
returns <- returns %>%
  mutate(
    weekday = wday(Date, label = TRUE, abbr = FALSE),
    month = month(Date, label = TRUE, abbr = FALSE)
  )

# =========================================================
# 5. Day-of-the-Week Analysis
# =========================================================

returns <- returns %>%
  mutate(
    Monday    = if_else(weekday == "Monday", 1, 0),
    Tuesday   = if_else(weekday == "Tuesday", 1, 0),
    Wednesday = if_else(weekday == "Wednesday", 1, 0),
    Thursday  = if_else(weekday == "Thursday", 1, 0),
    Friday    = if_else(weekday == "Friday", 1, 0)
  )

dow_model <- lm(
  Rm ~ Monday + Tuesday + Wednesday + Thursday + Friday - 1,
  data = returns
)

# Main inference: HC1 robust standard errors
dow_hc1 <- coeftest(
  dow_model,
  vcov = vcovHC(dow_model, type = "HC1")
)

# Robustness check: Newey-West HAC standard errors
dow_nw <- coeftest(
  dow_model,
  vcov = NeweyWest(dow_model, prewhite = FALSE)
)

# =========================================================
# 6. Month-of-the-Year Analysis
# =========================================================

returns <- returns %>%
  mutate(
    January   = if_else(month == "January", 1, 0),
    February  = if_else(month == "February", 1, 0),
    March     = if_else(month == "March", 1, 0),
    April     = if_else(month == "April", 1, 0),
    May       = if_else(month == "May", 1, 0),
    June      = if_else(month == "June", 1, 0),
    July      = if_else(month == "July", 1, 0),
    August    = if_else(month == "August", 1, 0),
    September = if_else(month == "September", 1, 0),
    October   = if_else(month == "October", 1, 0),
    November  = if_else(month == "November", 1, 0),
    December  = if_else(month == "December", 1, 0)
  )

moy_model <- lm(
  Rm ~ January + February + March + April +
    May + June + July + August + September +
    October + November + December - 1,
  data = returns
)

# Main inference: HC1 robust standard errors
moy_hc1 <- coeftest(
  moy_model,
  vcov = vcovHC(moy_model, type = "HC1")
)

# Robustness check: Newey-West HAC standard errors
moy_nw <- coeftest(
  moy_model,
  vcov = NeweyWest(moy_model, prewhite = FALSE)
)

# =========================================================
# 7. Display Results
# =========================================================

dow_hc1
dow_nw
moy_hc1
moy_nw

# =========================================================
# 8. Export Results
# =========================================================

clean_results <- function(model_results) {
  data.frame(
    Variable = rownames(model_results),
    Estimate = model_results[, 1],
    Std_Error = model_results[, 2],
    t_value = model_results[, 3],
    p_value = model_results[, 4],
    row.names = NULL
  )
}

dow_hc1_table <- clean_results(dow_hc1)
dow_nw_table  <- clean_results(dow_nw)

moy_hc1_table <- clean_results(moy_hc1)
moy_nw_table  <- clean_results(moy_nw)

write.csv(
  dow_hc1_table,
  "results/DOW_HC1_results.csv",
  row.names = FALSE
)

write.csv(
  dow_nw_table,
  "results/DOW_NeweyWest_results.csv",
  row.names = FALSE
)

write.csv(
  moy_hc1_table,
  "results/MOY_HC1_results.csv",
  row.names = FALSE
)

write.csv(
  moy_nw_table,
  "results/MOY_NeweyWest_results.csv",
  row.names = FALSE
)

# =========================================================
# 9. Visualizations
# =========================================================

# ---------- Day-of-the-Week Figure ----------

dow_hc1_table$Variable <- factor(
  dow_hc1_table$Variable,
  levels = c(
    "Monday", "Tuesday", "Wednesday",
    "Thursday", "Friday"
  )
)

dow_hc1_table <- dow_hc1_table %>%
  mutate(
    Lower = Estimate - 1.96 * Std_Error,
    Upper = Estimate + 1.96 * Std_Error
  )

dow_plot <- ggplot(
  dow_hc1_table,
  aes(x = Variable, y = Estimate)
) +
  geom_col(width = 0.65) +
  geom_errorbar(
    aes(ymin = Lower, ymax = Upper),
    width = 0.15
  ) +
  geom_hline(
    yintercept = 0,
    linetype = "dashed"
  ) +
  labs(
    title = "Average Returns by Day of the Week",
    subtitle = "Moroccan Stock Market (2020–2025)",
    x = NULL,
    y = "Average Daily Return"
  ) +
  theme_minimal(base_size = 12)

ggsave(
  "figures/day_of_week_returns.png",
  plot = dow_plot,
  width = 8,
  height = 5,
  dpi = 300
)

# ---------- Month-of-the-Year Figure ----------

moy_hc1_table$Variable <- factor(
  moy_hc1_table$Variable,
  levels = month.name
)

moy_hc1_table <- moy_hc1_table %>%
  mutate(
    Lower = Estimate - 1.96 * Std_Error,
    Upper = Estimate + 1.96 * Std_Error
  )

moy_plot <- ggplot(
  moy_hc1_table,
  aes(x = Variable, y = Estimate)
) +
  geom_col(width = 0.65) +
  geom_errorbar(
    aes(ymin = Lower, ymax = Upper),
    width = 0.15
  ) +
  geom_hline(
    yintercept = 0,
    linetype = "dashed"
  ) +
  labs(
    title = "Average Returns by Month of the Year",
    subtitle = "Moroccan Stock Market (2020–2025)",
    x = NULL,
    y = "Average Daily Return"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    )
  )

ggsave(
  "figures/month_of_year_returns.png",
  plot = moy_plot,
  width = 9,
  height = 5,
  dpi = 300
)