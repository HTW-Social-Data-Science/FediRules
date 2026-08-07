library('arrow')
library('tidyverse')
library('scales')
library(margins)
library(MASS)
library(mfx)
library(car)
library(sjPlot)
library(pscl)
library(logistf)


data <- read_parquet('regression_data.parquet')
output_dir <- "./results/blocked_instances_results_without_blocked_by_mastodon"
dir.create(output_dir, showWarnings = FALSE)


# Impute missing values with the mean across the dataset for specific variables
impute_median <- function(x) {
  ifelse(is.na(x), median(x, na.rm = TRUE), x)
}

data <- data %>%
  mutate(
    active_users = impute_median(active_users),
    lean1 = impute_median(lean1),
    low_info_02_count = replace_na(low_info_02_count, 0),
    hs_count = replace_na(hs_count, 0)
  )

data <- data %>%
  mutate(
    topic_tech = 
      #topic_social_media_plaforms_communities +
      topic_cloud_networks_security_privacy +
      topic_hardware_devices_infrastructure +
      topic_software_programming,

    topic_culture = 
      topic_humor_memes_play +
      topic_arts_crafts_design +
      topic_music +
      topic_books_movies_fandom +
      topic_games_gaming +
      topic_animals_nature +
      topic_food_drinks +
      topic_sports,

    topic_politics_econ =
      topic_current_political_events +
      topic_countries_local_contexts +
      topic_ai_silicon_valley +
      topic_economy_finance +
      topic_news_politics,

    topic_society =
      topic_life_relationship +
      topic_adult_content +
      topic_identity_discrimination_subculture +
      topic_religion,

    topic_science =
      topic_environment_climate_weather +
      topic_health_mental_health_body +
      topic_science_research,

    topic_other =
      topic_misc +
      topic_travel_mobility_transport
  )


data <- data %>%
  mutate(
    across(c(user_count, status_count,active_users), ~ replace_na(as.numeric(.), 0)),
    across(c(user_count, status_count,active_users), ~ log1p(pmax(as.numeric(.), 0))),
    across(c(toots_per_server), ~ replace_na(as.numeric(.), 0))
  )

topic_vars <- c("topic_tech", "topic_culture", "topic_politics_econ",
                "topic_society", "topic_science", "topic_other")

model_vars <- c(
  "is_blocked_count", "user_count", "status_count", "active_users", "lean1",
  "low_info_02_count", "hs_count", "toots_per_server",
  #"is_blocked_by_mastodon_social",
  paste0("lang_", c("de","fr","ja","zh","other")),
  paste0("software_", c("pleroma","gotosocial","akkoma","pixelfed","other")),
  topic_vars
)

vars_to_scale <- c("user_count", "status_count", "lang_de", "lang_fr", "lang_ja", 
                   "lang_other", "software_pleroma", "software_gotosocial", 
                   "software_akkoma", "software_pixelfed", "software_other",
                   "topic_tech", "topic_culture", "topic_politics_econ",
                   "topic_society", "topic_science", "topic_other",
                   "lean1", "low_info_02_count", "hs_count")


# Alle NA/NaN/Inf filtern
data_clean <- data %>%
  mutate(across(all_of(model_vars), ~ ifelse(is.na(.) | !is.finite(.), 0, .)))


# Count the number of missing values for each variable
missing_counts <- sapply(data, function(x) sum(is.na(x)))

# Sort the counts in descending order
missing_counts <- sort(missing_counts, decreasing = TRUE)

# Print the variables with the most missing values
#print(missing_counts)

  # mutate(
  #   lean1 = rescale(lean1, to = c(0, 1))  # Normalize political_leaning
  # )

################ Model OLS for plotting (nicht sinnvoll bei binärer Variable, wird aber für den Plot benutzt)
model_ols <- lm(
    is_blocked ~ user_count + status_count #+ lang_de + lang_fr + lang_ja + lang_other 
    + software_pleroma + software_gotosocial + software_akkoma + software_pixelfed + software_other,
    #+ topic_tech + topic_culture + topic_politics_econ +
    #+ topic_society + topic_science + topic_other +
    #+  lean1 + low_info_02_count + hs_count,
    data=data
  )
  #reference: + topic_software_programming

# Print the summary of the regression model
# summary(model_ols)
# summary(model_ols)$adj.r.squared

# Check for multicollinearity using VIF
vif_values <- vif(model_ols)

# Print VIF values
# print(vif_values)


############### MODEL Robust Standard Errors
model_logit <- glm(
  is_blocked ~ user_count + status_count #+ lang_de + lang_fr + lang_ja + lang_other +
  + software_pleroma + software_gotosocial + software_akkoma +
  software_pixelfed + software_other #+
  #topic_tech + topic_culture + topic_politics_econ +
  #topic_society + topic_science +
  #lean1 + low_info_02_count + hs_count,
  , data = data_clean, #data_scaled,
  family = binomial
)

print("Logistic Regression with Robust Standard Errors Summary:")
coeftest(model_logit, vcov = vcovHC(model_logit, type = "HC3"))

s <- summary(model_logit)
#pR2(model_logit)["McFadden"]

####### results without robust standard errors
# result_logit <- data.frame(
#   variable  = rownames(s$coefficients),
#   estimate  = s$coefficients[, "Estimate"],
#   std_error = s$coefficients[, "Std. Error"],
#   p_value   = s$coefficients[, "Pr(>|z|)"]
# )

# result_logit$McFadden_R2 <- as.numeric(pR2(model_logit)["McFadden"])

# result_logit$significance <- cut(
#   result_logit$p_value,
#   breaks = c(-Inf, 0.001, 0.01, 0.05, Inf),
#   labels = c("***", "**", "*", "")
# )

robust_test <- coeftest(model_logit, vcov = vcovHC(model_logit, type = "HC3"))
result_robust <- as.data.frame(robust_test[,])
colnames(result_robust) <- c("estimate", "std_error", "z_value", "p_value")
result_robust$variable <- rownames(robust_test)
result_robust$significance <- cut(
  result_robust$p_value,
  breaks = c(-Inf, 0.001, 0.01, 0.05, 0.1, Inf),
  labels = c("***", "**", "*", ".", "")
)
result_robust$McFadden_R2 <- as.numeric(pR2(model_logit)["McFadden"])

write.csv(result_robust, file = file.path(output_dir, "results_is_blocked_general_robust.csv"), row.names = FALSE)
############### ENDE MODEL Robust Standard Errors



# Plot the regression coefficients, keeping only the significant ones
plot <- plot_model(model_ols,  value.style = "signif", ci_method = "wald", sort.est = TRUE, vline.color = "red") + theme(axis.text.y = element_text(size = 12))

# Save the plot to a specified path
plot_path <- file.path(output_dir, "is_blocked.png")
ggsave(plot_path, plot = plot, width = 10, height = 8, create.dir = TRUE)


model_nb_blocked <- glm.nb(
  is_blocked_count ~ user_count + status_count + 
    #lang_de + lang_fr + lang_ja + lang_other +
    software_pleroma + software_gotosocial + software_akkoma + 
    software_pixelfed + software_other #+
    #topic_tech + topic_culture + topic_politics_econ +
    #topic_society + topic_science + topic_other +
    #lean1 + low_info_02_count + hs_count,
  , data = data_clean
)

print("Negative Binomial Regression Summary:")
summary(model_nb_blocked)

summary_nb <- summary(model_nb_blocked)
result_nb <- data.frame(
  variable  = rownames(summary_nb$coefficients),
  estimate  = summary_nb$coefficients[, "Estimate"],
  std_error = summary_nb$coefficients[, "Std. Error"],
  z_value   = summary_nb$coefficients[, "z value"],
  p_value   = summary_nb$coefficients[, "Pr(>|z|)"]
)

result_nb$significance <- cut(
  result_nb$p_value,
  breaks = c(-Inf, 0.001, 0.01, 0.05, 0.1, Inf),
  labels = c("***", "**", "*", ".", "")
)

result_nb$McFadden_R2 <- as.numeric(pR2(model_nb_blocked)["McFadden"])

write.csv(result_nb, file = file.path(output_dir, "results_is_blocked_count_nb.csv"), row.names = FALSE)

# Create a histogram of political_leaning
ggplot(data, aes(x = lean1)) +
  geom_histogram(binwidth = 0.05, fill = 'blue', color = 'black', alpha = 0.7) +
  labs(title = 'Histogram of Political Leaning', x = 'Political Leaning', y = 'Frequency') +
  theme_minimal()



# Plot the regression coefficients, keeping only the significant ones
plot <- plot_model(model_nb_blocked,  value.style = "signif", ci_method = "wald", sort.est = TRUE, vline.color = "red") + theme(axis.text.y = element_text(size = 12))

# Save the plot to a specified path
plot_path <- file.path(output_dir, "is_blocked_count.png")
ggsave(plot_path, plot = plot, width = 10, height = 8, create.dir = TRUE)

# Exponentiate the coefficients
# exp_coef <- exp(coef(nb_model))
# print(exp_coef)

# exp_coef <- exp(coef(logistf_model))
# print(exp_coef)