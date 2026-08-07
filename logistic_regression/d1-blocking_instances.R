#install.packages("margins", repos = "https://cloud.r-project.org/")
#install.packages("mfx", repos = "https://cloud.r-project.org/")
library('arrow')
library('tidyverse')
library(margins)
library(MASS)
library(mfx)
library(car)
library(sjPlot)
library(pscl)

data <- read_parquet('regression_data.parquet')
output_dir <- "./results/blocking_instances_results_without_blocked_by_mastodon/"
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
    across(c(user_count, status_count,active_users), ~ replace_na(as.numeric(.), 0)),
    across(c(user_count, status_count,active_users), ~ log1p(pmax(as.numeric(.), 0)))
  )

# data <- data %>%
#   mutate(
#     across(c(user_count), as.numeric)
#   ) %>%
#   mutate(
#     across(c(user_count), log1p)
#   )
  # mutate(
  #   lean1 = rescale(lean1, to = c(0, 1))  # Normalize political_leaning
  # )

######################## OLS Regression for plotting purposes only
model <- lm(
  blocks ~ user_count + status_count #+ lang_de + lang_fr + lang_ja  + lang_other 
  + software_pleroma + software_gotosocial + software_akkoma + software_pixelfed + software_other 
  #+ topic_software_programming + topic_misc + topic_science_research + topic_news_politics + topic_humor_memes_play + topic_sports + topic_countries_local_contexts + topic_religion + topic_games_gaming + topic_identity_discrimination_subculture + topic_travel_mobility_transport + topic_cloud_networks_security_privacy + topic_arts_crafts_design + topic_hardware_devices_infrastructure + topic_animals_nature + topic_adult_content + topic_life_relationship + topic_books_movies_fandom + topic_economy_finance + topic_environment_climate_weather + topic_music + topic_health_mental_health_body + topic_current_political_events + topic_food_drinks + topic_ai_silicon_valley
  #+ is_blocked_by_mastodon_social 
  #+  lean1 + low_info_02_count + hs_count,  
  , data=data
)
# Print the summary of the regression model
summary(model)
# Plot the regression coefficients, keeping only the significant ones
plot <- plot_model(model,  value.style = "signif", sort.est = TRUE, vline.color = "red") + theme(axis.text.y = element_text(size = 12))
# Save the plot to a specified path
plot_path <- file.path(output_dir, "blocks.png")
ggsave(plot_path, plot = plot, width = 10, height = 8, create.dir = TRUE)
########################



############## binomial regression
model_logit <- glm(
  blocks ~ user_count + status_count #+ lang_de + lang_fr + lang_ja + lang_other 
  + software_pleroma + software_gotosocial + software_akkoma + software_pixelfed + software_other
  #+ topic_software_programming + topic_misc + topic_science_research + topic_news_politics + topic_humor_memes_play + topic_sports + topic_countries_local_contexts + topic_religion + topic_games_gaming + topic_identity_discrimination_subculture + topic_travel_mobility_transport + topic_cloud_networks_security_privacy + topic_arts_crafts_design + topic_hardware_devices_infrastructure + topic_animals_nature + topic_adult_content + topic_life_relationship + topic_books_movies_fandom + topic_economy_finance + topic_environment_climate_weather + topic_music + topic_health_mental_health_body + topic_current_political_events + topic_food_drinks + topic_ai_silicon_valley
  #+ is_blocked_by_mastodon_social 
  #+ lean1 + low_info_02_count + hs_count,
  , data = data,
  family = binomial
)

s <- summary(model_logit)

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
write.csv(result_robust, file = file.path(output_dir, "results_is_blocking_logit.csv"), row.names = FALSE)


######################## OLS Regression for plotting purposes only
model <- lm(
  block_count ~ user_count + status_count #+ lang_de + lang_fr + lang_ja + lang_other #+ lang_zh
  + software_pleroma + software_gotosocial + software_akkoma + software_pixelfed + software_other 
  #+ topic_software_programming + topic_misc + topic_science_research + topic_news_politics + topic_humor_memes_play + topic_sports + topic_countries_local_contexts + topic_religion + topic_games_gaming + topic_identity_discrimination_subculture + topic_travel_mobility_transport + topic_cloud_networks_security_privacy + topic_arts_crafts_design + topic_hardware_devices_infrastructure + topic_animals_nature + topic_adult_content + topic_life_relationship + topic_books_movies_fandom + topic_economy_finance + topic_environment_climate_weather + topic_music + topic_health_mental_health_body + topic_current_political_events + topic_food_drinks + topic_ai_silicon_valley
  #+ is_blocked_by_mastodon_social 
  #+ lean1 + low_info_02_count + hs_count,
  , data=data
)

# Print the summary of the regression model
summary(model)
# Plot the regression coefficients, keeping only the significant ones
plot <- plot_model(model,  value.style = "signif", sort.est = TRUE, vline.color = "red") + theme(axis.text.y = element_text(size = 12))

# Save the plot to a specified path
plot_path <- file.path(output_dir, "blocks_count.png")
ggsave(plot_path, plot = plot, width = 10, height = 8, create.dir = TRUE)
#################



################# Negative Binomial Regression für count
nb_model <- glm.nb(
  block_count ~ user_count + status_count #+ lang_de + lang_fr + lang_ja + lang_other
  + software_pleroma + software_gotosocial + software_akkoma + software_pixelfed + software_other 
  #+ topic_software_programming + topic_misc + topic_science_research + topic_news_politics + topic_humor_memes_play + topic_sports + topic_countries_local_contexts + topic_religion + topic_games_gaming + topic_identity_discrimination_subculture + topic_travel_mobility_transport + topic_cloud_networks_security_privacy + topic_arts_crafts_design + topic_hardware_devices_infrastructure + topic_animals_nature + topic_adult_content + topic_life_relationship + topic_books_movies_fandom + topic_economy_finance + topic_environment_climate_weather + topic_music + topic_health_mental_health_body + topic_current_political_events + topic_food_drinks + topic_ai_silicon_valley
 #+ is_blocked_by_mastodon_social  
  #+ lean1 + low_info_02_count + hs_count,
  , data = data,
)

# Print the summary of the Negative Binomial regression model
s <- summary(nb_model)

result_nb <- data.frame(
  variable  = rownames(s$coefficients),
  estimate  = s$coefficients[, "Estimate"],
  std_error = s$coefficients[, "Std. Error"],
  p_value   = s$coefficients[, "Pr(>|z|)"]
)
result_nb$McFadden_R2 <- as.numeric(pR2(nb_model)["McFadden"])

result_nb$significance <- cut(
  result_nb$p_value,
  breaks = c(-Inf, 0.001, 0.01, 0.05, Inf),
  labels = c("***", "**", "*", "")
)

write.csv(result_nb, file = file.path(output_dir, "results_is_blocking_count_nb.csv"), row.names = FALSE)


# Exponentiate the coefficients
exp_coef <- exp(coef(nb_model))
print(exp_coef)
