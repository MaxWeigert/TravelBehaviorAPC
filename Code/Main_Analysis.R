### This is the main code file containing the analyses done for the
### publication "Disentangling Temporal Changes in Travel Behavior: An Age,
### Period, and Cohort Analysis".

# Loading of necessary packages and sourcing of self-defined functions:
library(APCtools)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggpubr)
library(mgcv)
library(pROC)
library(gratia)
source("Code/Functions.R")
theme_set(theme_minimal())


################################################################################

# Description of response variables:

# define age and period groups for the density matrices
age_groups    <- list(c(70,79),c(60,69),c(50,59),c(40,49),c(30,39),c(20,29),c(14,19))
period_groups <- list(c(1970,1979),c(1980,1989),c(1990,1999),c(2000,2009),c(2010,2018))

# participation plot
dat_P <- read_and_prepare_data(model = "participation")

# create the participation variable
dat_P <- dat_P %>% 
  mutate(participation = case_when(JS_Anzahl_URs == 0 ~ "0 trips",
                                   TRUE               ~ ">= 1 trips")) %>% 
  mutate(participation = factor(participation, levels = c("0 trips",">= 1 trips")))

# marginal distribution
gg1 <- plot_variable(dat_P, "participation", legend_title = "Participation") +
    scale_fill_manual("Participation  ", values = c("lightblue","dodgerblue3")) +
  scale_x_discrete(breaks = 1983:2018,
                   labels = c(1983, rep("", 6), 1990, rep("", 4),
                              1995, rep("", 4), 2000, rep("", 4), 2005,
                              rep("", 4), 2010, rep("", 7), 2018)) +
  scale_y_continuous("Rel. frequency", labels = scales::percent) +
  theme_minimal(base_size = 16) +
  theme(legend.position = "bottom")

# travel frequency plot
dat_F <- read_and_prepare_data(model = "frequency")

dat_F <- dat_F %>% 
  filter(JS_Anzahl_URs > 0) %>% 
  mutate(JS_Anzahl_URs_cat = case_when(JS_Anzahl_URs < 5 ~ as.character(JS_Anzahl_URs),
                                       TRUE              ~ "5+ trips")) %>% 
  mutate(JS_Anzahl_URs_cat = factor(JS_Anzahl_URs_cat, levels = c("5+ trips","4","3","2","1")))

# marginal distribution
green_colors <- RColorBrewer::brewer.pal(6, "Greens")[6:2]
gg2 <- dat_F %>% 
  mutate(JS_Anzahl_URs_cat = factor(JS_Anzahl_URs_cat,
                                    levels = c("5+ trips", "4", "3", "2", "1"),
                                    labels = 5:1)) %>% 
  plot_variable("JS_Anzahl_URs_cat") +
  scale_fill_manual("No. of trips  ", values = green_colors) +
  scale_x_discrete(breaks = 1983:2018,
                   labels = c(1983, rep("", 6), 1990, rep("", 4),
                              1995, rep("", 4), 2000, rep("", 4), 2005,
                              rep("", 4), 2010, rep("", 7), 2018)) +
  scale_y_continuous("Rel. frequency", labels = scales::percent) +
  theme_minimal(base_size = 16) +
  theme(legend.position = "bottom")

# relative travel expenses plot 
dat_E <- read_and_prepare_data(model = "expenses")

# plot the household income
dat_plotIncome <- dat_E %>% 
  group_by(period) %>% 
  summarize(q10    = quantile(S_Einkommen_HH_equi, probs = 0.1),
            median = median(S_Einkommen_HH_equi),
            q90    = quantile(S_Einkommen_HH_equi, probs = 0.9)) %>% 
  pivot_longer(-period) %>% 
  mutate(name = factor(name, levels = c("q10", "median", "q90"),
                       labels = c("10% quantile  ", "median  ", "90% quantile  ")))
gg3 <- ggplot(dat_plotIncome, aes(x = period, y = value, group = name, color = name)) +
  geom_line(aes(linetype = name)) +
  geom_point() +
  ylim(c(0, NA)) +
  scale_color_manual(values = c("gray80", "black", "gray80")) +
  scale_linetype_manual(values = c(2, 1, 2)) +
  xlab("Period") +
  ylab("Median of household income [€]") +
  theme_minimal(base_size = 16) +
  theme(legend.position = "bottom",
        legend.title    = element_blank())
# plot the relative expenses
dat_plotExpenses <- dat_E %>% 
  group_by(period) %>% 
  summarize(q10    = quantile(rel_expenses, probs = 0.1),
            median = median(rel_expenses),
            q90    = quantile(rel_expenses, probs = 0.9)) %>% 
  pivot_longer(-period) %>% 
  mutate(name = factor(name, levels = c("q10", "median", "q90"),
                       labels = c("10% quantile  ", "median  ", "90% quantile  ")))
gg4 <- ggplot(dat_plotExpenses, aes(x = period, y = value, group = name, color = name)) +
  geom_line(aes(linetype = name)) +
  geom_point() +
  scale_color_manual(values = c("gray80", "black", "gray80")) +
  scale_linetype_manual(values = c(2, 1, 2)) +
  xlab("Period") +
  scale_y_continuous("Median or rel. expenses", labels = scales::percent,
                     limits = c(0, NA)) +
  theme_minimal(base_size = 16) +
  theme(legend.position = "bottom",
        legend.title    = element_blank())

# joint plot
ggpubr::ggarrange(gg1, gg2, gg3, gg4, ncol = 2, nrow = 2)
# ggsave("Graphics/Figure2.jpeg", width = 11, height = 8, dpi = 300, bg = "white")


################################################################################

# Description of covariates:

# data prep
dat <- read_and_prepare_data(model = "participation")

dat <- dat %>% 
  dplyr::rename(Gender                 = S_Geschlecht,
                Household_net_income   = S_Einkommen_HH,
                Education_level        = S_Bildung,
                Household_size         = S_Haushaltsgroesse,
                Children_under_5_years = S_Kinder_0_bis_5_binaer,
                Size_of_residence      = S_Wohnortgroesse,
                Duration_of_main_trip  = JS_HUR_Reisedauer)

# categorize the household net income
dat <- dat %>% 
  mutate(Household_net_income_cat = case_when(Household_net_income < 1000 ~ "[0,1000)",
                                              Household_net_income < 2000 ~ "[1000,2000)",
                                              Household_net_income < 3000 ~ "[2000,3000)",
                                              Household_net_income < 4000 ~ "[3000,4000)",
                                              Household_net_income < 5000 ~ "[4000,5000)",
                                              Household_net_income < 6000 ~ "[5000,6000)",
                                              TRUE                        ~ ">= 6000"))

# descriptions ------------------------------------------------------------
vars <- c("Gender","Household_net_income_cat","Education_level","Household_size",
          "Children_under_5_years","Size_of_residence","Duration_of_main_trip")

# Note: Among the above variables only the trip duration has some NA values,
#       and these are only in the data for non-travelers.´
#       Accordingly, we don't have to bother with NA values in the following
#       table.

# create the frequency table with separate information for all travelers
freq_dat_list <- lapply(vars, function(var) {
  
  x_all       <- dat[[var]]
  x_travelers <- dat[[var]][dat$y_atLeastOneUR == 1]
  
  tab_abs_all       <- table(x_all)
  tab_abs_travelers <- table(x_travelers)
  tab_rel_all       <- prop.table(tab_abs_all)
  tab_rel_travelers <- prop.table(tab_abs_travelers)
  
  freq_dat <- data.frame(Variable       = var,
                         Value          = names(tab_abs_all),
                         n_overall      = as.vector(tab_abs_all),
                         n_travelers    = as.vector(tab_abs_travelers),
                         freq_overall   = paste0(round(100 * as.vector(tab_rel_all),       1), "%"),
                         freq_travelers = paste0(round(100 * as.vector(tab_rel_travelers), 1), "%"))
  
  # only keep the information on the trip duration for travelers
  if (var == "Duration_of_main_trip") {
    freq_dat$n_overall <- freq_dat$freq_overall <- NA
  }
  
  return(freq_dat)
})

freq_dat <- dplyr::bind_rows(freq_dat_list)
#write.csv2(freq_dat, file = "Graphics/Table2.csv", row.names = FALSE)


################################################################################

# Model effects:

# model estimation participation
dat_P <- read_and_prepare_data(model = "participation")

model_P <- bam(formula = y_atLeastOneUR ~ te(period, age, k = c(10, 10), bs = "ps") +
                 S_Geschlecht + S_Kinder_0_bis_5_binaer + S_Wohnortgroesse +
                 S_Bildung + s(S_Einkommen_HH_equi, bs = "ps", k =10) +
                 S_Haushaltsgroesse,
               family = binomial(link = "logit"), data = dat_P)
#saveRDS(object = model_P, file = "Models/Main_Analysis/Model_participation.rds")

# model estimation frequency
dat_F <- read_and_prepare_data(model = "frequency")

model_F <- bam(y_atLeastTwoURs ~ te(period, age, k = c(10, 10), bs = "ps") +
                 S_Geschlecht + S_Kinder_0_bis_5_binaer + S_Wohnortgroesse + S_Bildung +
                 s(S_Einkommen_HH_equi, bs = "ps", k = 10) + S_Haushaltsgroesse,
               family = binomial(link = "logit"), data = dat_F)
#saveRDS(object = model_F, file = "Models/Main_Analysis/Model_frequency.rds")

# model estimation expenses 
dat_E <- read_and_prepare_data(model = "expenses")

model_E <- bam(formula = rel_expenses ~ te(period, age, bs = "ps", k = c(10, 10)) +
                 S_Geschlecht + S_Kinder_0_bis_5_binaer + S_Wohnortgroesse +
                 S_Bildung + S_Haushaltsgroesse + JS_HUR_Reisedauer +
                 s(S_Einkommen_HH_equi, bs = "ps", k = 10),
               family = Gamma(link = "log"),
               data = dat_E)
#saveRDS(object = model_E, file = "Models/Main_Analysis/Model_expenses.rds")

# general preparations for all following plots 
model_suffices <- c("P","F","E")
model_labels   <- c("Participation","Frequency","Expenses")

# create an effect heatmap (including confidence intervals) for every model
options(digits = 2)
APCtools::plot_APCheatmap(dat          = dat_P,
                          model        = model_P,
                          bin_heatmap  = FALSE,
                          legend_title = "Odds Ratio    ")
# ggsave("Graphics/FigureB5_participation.jpeg", width = 12, height = 5)
APCtools::plot_APCheatmap(dat          = dat_F,
                          model        = model_F,
                          bin_heatmap  = FALSE,
                          legend_title = "Odds Ratio    ")
# ggsave("Graphics/FigureB6_frequency.jpeg", width = 12, height = 5)
APCtools::plot_APCheatmap(dat          = dat_E,
                          model        = model_E,
                          bin_heatmap  = FALSE,
                          legend_title = "exponentiated effect       ")
# ggsave("Graphics/FigureB7_expenses.jpeg", width = 12, height = 5)


# data prep for the marginal effect plots 
plot_dat_list <- lapply(model_suffices, function(suffix) {
  
  # return a list for all age, period and cohort
  model_dat_list <- plot_marginalAPCeffects(model           = get(paste0("model_",suffix)),
                                            dat             = get(paste0("dat_",suffix)),
                                            variable        = "age",
                                            return_plotData = TRUE)
  
  model_dat <- model_dat_list[2:4] %>% dplyr::bind_rows() %>% 
    mutate(model = suffix)
  
  return(model_dat)
})

plot_dat <- plot_dat_list %>% dplyr::bind_rows() %>% 
  mutate(model    = factor(model,    levels = model_suffices, labels = model_labels),
         variable = factor(variable,
                           levels = c("age","period","cohort"),
                           labels = c("Age","Period","Cohort"))) %>%
  filter(variable != "Cohort" | value >= 1939)

# marginal effect plots 
vlines_cohort <- list("cohort" = c(1946.5,1966.5,1982.5,1994.5))
cols          <- rev(scales::hue_pal()(3))

# vertical lines, only to be drawn for the cohort plots
vline_dat <- data.frame(variable = factor("Cohort", levels = c("Age","Period","Cohort")),
                        x        = c(1946.5,1966.5,1982.5,1994.5))

# 1) plot grid for participation and frequency
gg1 <- plot_dat %>% 
  filter(model %in% c("Participation","Frequency")) %>% 
  ggplot(aes(x = value, y = effect, col = model)) +
  geom_hline(yintercept = 1, lty = 2, col = gray(0.3)) +
  geom_vline(data = vline_dat, aes(xintercept = x), lty = 2, col = gray(0.3)) +
  geom_line() +
  facet_grid(model ~ variable, scales = "free") +
  scale_y_continuous("OR", breaks = c(.5, .75, 1, 1.25, 1.5), trans = "log2",
                     limits = range(plot_dat$effect)) +
  scale_color_manual(values = cols[1:2]) +
  theme(axis.title.x     = element_blank(),
        axis.text.x      = element_blank(),
        strip.background = element_rect(fill = gray(0.8)),
        panel.grid.minor = element_blank(),
        legend.position  = "none")

# 2) plot grid for expenses
gg2 <- plot_dat %>% 
  filter(model == "Expenses") %>% 
  ggplot(aes(x = value, y = effect, col = model)) +
  geom_hline(yintercept = 1, lty = 2, col = gray(0.3)) +
  geom_vline(data = vline_dat, aes(xintercept = x), lty = 2, col = gray(0.3)) +
  geom_line() +
  facet_grid(model ~ variable, scales = "free") +
  scale_y_continuous("EE", breaks = c(.9,.95,1,1.05,1.1), trans = "log2", limits = c(0.9, 1.1)) +
  scale_color_manual(values = cols[3]) +
  theme(axis.title.x     = element_blank(),
        strip.text.x     = element_blank(),
        strip.background = element_rect(fill = gray(0.8)),
        panel.grid.minor = element_blank(),
        legend.position  = "none")

ggpubr::ggarrange(gg1, gg2, nrow = 2, heights = c(2/3,1/3))
# ggsave("Graphics/Figure3.jpeg", width = 6, height = 4, dpi = 300, bg = "white")

# Summary of effects:
summary_P <- create_APCsummary(list(model_P), dat = dat_P,
                               apc_range = list("cohort" = 1939:2018),
                               kable = FALSE) %>%
  mutate(model = "participation") %>%
  dplyr::select(model, effect, value_withMaxEffect, value_withMinEffect,
                max_effect, min_effect, ratio)
summary_F <- create_APCsummary(list(model_F), dat = dat_F,
                               apc_range = list("cohort" = 1939:2018),
                               kable = FALSE) %>%
  mutate(model = "frequency") %>%
  dplyr::select(model, effect, value_withMaxEffect, value_withMinEffect,
                max_effect, min_effect, ratio)
summary_E <- create_APCsummary(list(model_E), dat = dat_E,
                               apc_range = list("cohort" = 1939:2018),
                               kable = FALSE) %>%
  mutate(model = "expenses") %>%
  dplyr::select(model, effect, value_withMaxEffect, value_withMinEffect,
                max_effect, min_effect, ratio)
summary_dat <- dplyr::bind_rows(summary_P, summary_F, summary_E)
#write.csv2(summary_dat, file = "Graphics/Table3.csv", row.names = FALSE)

# linear covariate effects
plot_dat_list <- lapply(model_suffices, function(suffix) {
  
  m <- get(paste0("model_",suffix))
  plot_dat_m <- plot_linearEffects(m, return_plotData = TRUE, refCat = TRUE) %>% 
    mutate(model = model_labels[match(suffix, model_suffices)])
  
  return(plot_dat_m)
})

plot_dat <- dplyr::bind_rows(plot_dat_list) %>%
  mutate(model = factor(x = model,
                        levels = c("Participation", "Frequency",
                                   "Expenses"))) %>% 
  mutate(vargroup = as.character(vargroup)) %>% 
  mutate(vargroup = case_when(vargroup == "S_Geschlecht"            ~ "Gender",
                              vargroup == "S_Bildung"               ~ "Education",
                              vargroup == "S_Kinder_0_bis_5_binaer" ~ "Young children",
                              vargroup == "S_Haushaltsgroesse"      ~ "Household size",
                              vargroup == "JS_HUR_Reisedauer"       ~ "Trip length",
                              vargroup == "S_Wohnortgroesse"        ~ "City size",
                              TRUE ~ vargroup)) %>% 
  mutate(vargroup = factor(vargroup, levels = c("Gender","Education","Household size",
                                                "Young children","City size","Trip length"))) %>% 
  mutate(param = as.character(param)) %>% 
  mutate(param = case_when(param == "weiblich"                  ~ "female",
                           param == "maennlich"                 ~ "male",
                           grepl("Hauptschule", param)       ~ "junior high school",
                           grepl("Mittlere Reife", param)       ~ "secondary school",
                           grepl("Abitur",         param)       ~ "high school",
                           grepl("Universitaet",   param)       ~ "university or college",
                           param == "keine Kinder dieser Altersstufe" ~ "no",
                           param == "Kinder dieser Altersstufe" ~ "yes",
                           param == "5.3"                       ~ ">=5",
                           param == "bis 4.999"                 ~ "<5000",
                           param == "5.000 bis 49.999"          ~ "[5,000; 50,000)",
                           param == "50.000 bis 99.999"         ~ "[50,000; 100,000)",
                           param == "100.000 bis 499.999"       ~ "[100,000; 500,000)",
                           param == "500.000 und mehr"          ~ ">=500,000",
                           param == "bis 5 Tage"                ~ "5 days",
                           param == "6 bis 8 Tage"              ~ "6-8 days",
                           param == "9 bis 12 Tage"             ~ "9-12 days",
                           param == "13 bis 15 Tage"            ~ "13-15 days",
                           param == "16 bis 19 Tage"            ~ "16-19 days",
                           param == "20 bis 22 Tage"            ~ "20-22 days",
                           param == "23 bis 26 Tage"            ~ "23-26 days",
                           param == "27 bis 29 Tage"            ~ "27-29 days",
                           param == "30 Tage und mehr"          ~ ">=30 days",
                           TRUE ~ param)) %>% 
  mutate(param = factor(param, levels = c("male","female","junior high school",
                                          "secondary school","high school","university or college",
                                          "1","2","3","4",">=5","no","yes",
                                          "<5000","[5,000; 50,000)","[50,000; 100,000)",
                                          "[100,000; 500,000)",">=500,000",
                                          "5 days", "6-8 days","9-12 days","13-15 days",
                                          "16-19 days","20-22 days","23-26 days",
                                          "27-29 days",">=30 days")))

ggplot(plot_dat, mapping = aes(x = param, y = coef_exp)) +
  geom_hline(yintercept = 1, col = gray(0.3), lty = 2) +
  geom_point(mapping = aes(col = vargroup), size = 2.5) +
  geom_pointrange(mapping = aes(ymin = CI_lower_exp, ymax = CI_upper_exp, col = vargroup),
                  size = 1, fatten = 1) +
  geom_point(mapping = aes(col = vargroup), size = 1) +
  scale_y_continuous(trans = "log2", name = expression("OR" ~ " / EE")) +
  colorspace::scale_colour_discrete_qualitative(palette = "Dark 3") +
  facet_grid(model ~ vargroup, scales = "free_x", space = "free_x",
             labeller = labeller(vargroup = label_wrap_gen(width = 12))) +
  theme(legend.position = "none",
        axis.title.x    = element_blank(),
        axis.text.x     = element_text(angle = 45, hjust = 1),
        strip.background = element_rect(fill = gray(0.8)))
#ggsave("Graphics/FigureA1.jpeg", width = 9, height = 7, dpi = 300,
#       bg = "white")

# nonlinear income effects 
plot_dat_list <- lapply(model_suffices, function(suffix) {
  
  m <- get(paste0("model_",suffix))
  plot_dat_m <- plot_1Dsmooth(m, select = 2, return_plotData = TRUE) %>% 
    mutate(model = model_labels[match(suffix, model_suffices)])
  
  return(plot_dat_m)
})

plot_dat <- dplyr::bind_rows(plot_dat_list) %>%
  mutate(model = factor(x = model,
                        levels = c("Participation", "Frequency",
                                   "Expenses")))

ggplot() +
  geom_hline(yintercept = 1, lty = 2, col = gray(0.3)) +
  geom_ribbon(data = plot_dat, aes(x, ymin = CI_lower, ymax = CI_upper),
              fill = gray(0.75)) + 
  geom_line(data = plot_dat, aes(x, y, col = model)) +
  facet_grid(. ~ model) + scale_x_continuous(limits = c(0, 6000)) +
  scale_y_continuous(expression("OR" ~ " / EE"), trans = "log2", limits = c(0.25, 16),
                     breaks = 2^c(-2,-1,0,1, 2, 3, 4),
                     labels = c("0.25","0.5","1","2", "4", "8", "16")) +
  scale_color_manual(values = cols) +
  xlab("Household income [€]") +
  theme(strip.background = element_rect(fill = gray(0.8)),
        legend.position  = "none",
        panel.grid.minor = element_blank())
#ggsave("Graphics/FigureA2.jpeg", width = 6, height = 2, dpi = 300,
#       bg = "white")


################################################################################

# Check the logistic regression models for overdispersion:

calc_dispersionParameter <- function(model) {
  
  # Extract Pearson residuals:
  residuals <- residuals(model, type = "pearson")
  
  # Calculate the overdispersion parameter:
  n <- length(model$y)            # number of observations
  p <- length(model$coefficients) # number of parameters estimated
  dispersion_param <- sum(residuals^2) / (n - p)
  
  return(dispersion_param)
}


calc_dispersionParameter(model_P)
calc_dispersionParameter(model_F)


################################################################################

# Further model evaluation:

# Participation:
set.seed(3456)
train_index <- sample(1:nrow(dat_P), 0.8 * nrow(dat_P))
dat_P_train <- dat_P[train_index, ]
dat_P_test <- dat_P[-train_index, ]
model_P_auc <- bam(formula = y_atLeastOneUR ~ te(period, age, k = c(10, 10), bs = "ps") +
                     S_Geschlecht + S_Kinder_0_bis_5_binaer + S_Wohnortgroesse +
                     S_Bildung + s(S_Einkommen_HH_equi, bs = "ps", k =10) +
                     S_Haushaltsgroesse,
                   family = binomial(link = "logit"), data = dat_P_train)
prediction <- predict(object = model_P_auc, newdata = dat_P_test)
roc(dat_P_test$y_atLeastOneUR, prediction)$auc

# Frequency:
set.seed(3456)
train_index <- sample(1:nrow(dat_F), 0.8 * nrow(dat_F))
dat_F_train <- dat_F[train_index, ]
dat_F_test <- dat_F[-train_index, ]
model_F_auc <- bam(formula = y_atLeastTwoURs ~ te(period, age, k = c(10, 10), bs = "ps") +
                     S_Geschlecht + S_Kinder_0_bis_5_binaer + S_Wohnortgroesse +
                     S_Bildung + s(S_Einkommen_HH_equi, bs = "ps", k =10) +
                     S_Haushaltsgroesse,
                   family = binomial(link = "logit"), data = dat_F_train)
prediction <- predict(object = model_F_auc, newdata = dat_F_test)
roc(dat_F_test$y_atLeastTwoURs, prediction)$auc

# Expenses:
set.seed(3456)
train_index <- sample(1:nrow(dat_E), 0.8 * nrow(dat_E))
dat_E_train <- dat_E[train_index, ]
dat_E_test <- dat_E[-train_index, ]
model_E_train <- bam(formula = rel_expenses ~ te(period, age, bs = "ps", k = c(10, 10)) +
                       S_Geschlecht + S_Kinder_0_bis_5_binaer + S_Wohnortgroesse +
                       S_Bildung + S_Haushaltsgroesse + JS_HUR_Reisedauer +
                       s(S_Einkommen_HH_equi, bs = "ps", k = 10),
                     family = Gamma(link = "log"),
                     data = dat_E_train)
prediction <- predict(object = model_E_train, newdata = dat_E_test, 
                      type = "response")
mean(abs(prediction - dat_E_test$rel_expenses), na.rm = TRUE)
median(abs(prediction - dat_E_test$rel_expenses) / dat_E_test$rel_expenses,
       na.rm = TRUE)

# QQ plot for the expenses model
qq_plot(model_E, method = "uniform") + ggtitle("") +
  theme(plot.subtitle = element_blank(),
        text = element_text(size = 16), axis.title = element_text(size = 18),
        axis.text = element_text(size = 14),
        legend.text = element_text(size = 16),
        legend.key.width = unit(2, "lines"),
        plot.title = element_text(hjust = 0.5, size = 18, face = "bold"),
        strip.text = element_text(size = 18, face = "bold"),
        strip.text.y = element_text(size = 16), legend.text.align = 0,
        strip.placement = "outside", strip.background = element_blank(),
        axis.title.y = element_text(margin = margin(0, 10, 0, 0)),
        axis.title.x = element_text(margin = margin(10, 0, 0, 0)))
#ggsave("Graphics/FigureA3.jpeg", width = 4, height = 4, dpi = 300,
#       bg = "white")


################################################################################
