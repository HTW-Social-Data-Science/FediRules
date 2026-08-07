#################
library('arrow')
library('tidyverse')
library('sjPlot')
library('ggplot2')
library(car)
library(MASS)

# Read data
data <- read_parquet('regression_data_low_info.parquet')
#data <- read_parquet('regression_data.parquet')


# Impute missing values with the median
impute_median <- function(x) {
  ifelse(is.na(x), median(x, na.rm = TRUE), x)
}


data <- data |> 
  mutate(
    active_users = impute_median(active_users),
    lean1 = impute_median(lean1),
    low_info_02_count = replace_na(low_info_02_count, 0),
    hs_count = replace_na(hs_count, 0)
  )

# Convert selected variables to numeric and apply log transformation
data <- data |>
  mutate(
    across(
      c(user_count, status_count, active_users),
      ~ log1p(pmax(as.numeric(.), 0))
    )
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
    software_other_gotosocial = software_other + software_gotosocial
  )

data <- data %>%
  mutate(misinfo = replace_na(misinfo, 0))

data <- data %>%
  mutate(across(c(topic_tech, topic_culture, topic_politics_econ,
                  topic_society, topic_science, topic_other),
                ~ ifelse(is.na(.) | !is.finite(.), 0, .)))

# model_vars <- c("low_info_02_count", "user_count", "lang_de", "lang_fr", "lang_ja", "lang_other",
#                 "topic_tech", "topic_culture", "topic_politics_econ", "topic_society", 
#                 "topic_science", "topic_other", "lean1", "misinfo", "toots_per_server")

# sapply(data[, model_vars], function(x) sum(is.na(x) | is.infinite(x)))

model_nb <- glm.nb(
    low_info_02_count ~ user_count + #status_count +
      lang_de + lang_fr + lang_ja + lang_other +
      software_pleroma + software_akkoma + software_pixelfed + software_other_gotosocial + #software_other + #software_gotosocial      
      # topic_software_programming + topic_misc + topic_science_research + topic_news_politics +
      # topic_humor_memes_play + topic_sports + topic_countries_local_contexts + topic_religion +
      # topic_games_gaming + topic_identity_discrimination_subculture + topic_travel_mobility_transport +
      # topic_cloud_networks_security_privacy + topic_arts_crafts_design + topic_hardware_devices_infrastructure +
      # topic_animals_nature + topic_adult_content + topic_life_relationship + topic_books_movies_fandom +
      # topic_economy_finance + topic_environment_climate_weather + topic_music + topic_health_mental_health_body +
      # topic_current_political_events + topic_food_drinks + topic_ai_silicon_valley +
      topic_tech + topic_culture + topic_politics_econ + topic_society + topic_science + topic_other 
      + lean1 
      + misinfo 
      + offset(log1p(toots_per_server)),
    data = data
  )


adj_r2 <- sapply(list(model_nb), function(m) {
  as.numeric(pscl::pR2(m)["McFadden"])
})

adj_r2_df <- data.frame(
  regression = "low_info_02_count",
  McFadden_R2 = as.numeric(pscl::pR2(model_nb)["McFadden"])
)


#######
# print("Prüfen:")
# model_null <- glm(low_info_02_count ~ 1 + log1p(status_count), data = data, family = poisson)
# pscl::pR2(model_null)["McFadden"]

# alias(models_nb$low_info_02_count)
# coef(models_nb$low_info_02_count)
# vif(models_nb$low_info_02_count)


results_list <- lapply(list(low_info_02_count = model_nb), function(m) {
  df <- as.data.frame(summary(m)$coefficients)
  df$variable <- rownames(df)
  df
})

all_results <- bind_rows(results_list, .id = "regression")

all_results <- all_results %>%
  mutate(formatted = sprintf("%.3f (%.3f)", Estimate, `Pr(>|z|)`))
all_results <- all_results %>%
  mutate(
    sig = case_when(
      `Pr(>|z|)` < 0.001 ~ "***",
      `Pr(>|z|)` < 0.01  ~ "**",
      `Pr(>|z|)` < 0.05  ~ "*",
      `Pr(>|z|)` < 0.1   ~ ".",
      TRUE               ~ ""
    ),
    formatted = sprintf("%.3f%s (%.3f)", Estimate, sig, `Pr(>|z|)`)
  )

all_results <- all_results %>%
  left_join(adj_r2_df, by = "regression")

write.csv(all_results, "./results/rule_compliance_without/rule_compliance_NB_low_info.csv", row.names = FALSE)