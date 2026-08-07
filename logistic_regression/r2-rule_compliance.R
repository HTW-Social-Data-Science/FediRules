# This script contains regressions for §R2
library('arrow')
library('tidyverse')
library('sjPlot')
library('ggplot2')
library(car)

data <- read_parquet('regression_data.parquet')

impute_median <- function(x) {
  ifelse(is.na(x), median(x, na.rm = TRUE), x)
}

data <- data |> 
  mutate(
    active_users = impute_median(active_users),
    lean1 = impute_median(lean1),
    share_low_info_quality_02 = impute_median(share_low_info_quality_02),
    share_low_info_quality_03 = impute_median(share_low_info_quality_03),
    share_low_info_quality_04 = impute_median(share_low_info_quality_04),
    share_low_info_quality_05 = impute_median(share_low_info_quality_05),
    hs_percent = impute_median(hs_percent)
  )

data <- data |>
  mutate(
    across(
      c(user_count, status_count, active_users),
      ~ log1p(pmax(as.numeric(.), 0))
    )
  )


models <- list(
  share_low_info_quality_02 = glm(share_low_info_quality_02 ~ user_count + status_count + 
                                   lang_de + lang_fr + lang_ja + lang_other + software_pleroma + 
                                   software_gotosocial + software_akkoma + software_pixelfed + software_other + 
                                 topic_software_programming + topic_misc + topic_science_research + topic_news_politics + topic_humor_memes_play + topic_sports + topic_countries_local_contexts + topic_religion + topic_games_gaming + topic_identity_discrimination_subculture + topic_travel_mobility_transport + topic_cloud_networks_security_privacy + topic_arts_crafts_design + topic_hardware_devices_infrastructure + topic_animals_nature + topic_adult_content + topic_life_relationship + topic_books_movies_fandom + topic_economy_finance + topic_environment_climate_weather + topic_music + topic_health_mental_health_body + topic_current_political_events + topic_food_drinks + topic_ai_silicon_valley + 
                                   lean1 + misinfo, data = data),
                                   #reference: topic_social_media_plaforms_communities
  share_low_info_quality_03 = glm(share_low_info_quality_03 ~ user_count + status_count + 
                                   lang_de + lang_fr + lang_ja + lang_other + software_pleroma + 
                                   software_gotosocial + software_akkoma + software_pixelfed + software_other +  
                                 topic_software_programming + topic_misc + topic_science_research + topic_news_politics + topic_humor_memes_play + topic_sports + topic_countries_local_contexts + topic_religion + topic_games_gaming + topic_identity_discrimination_subculture + topic_travel_mobility_transport + topic_cloud_networks_security_privacy + topic_arts_crafts_design + topic_hardware_devices_infrastructure + topic_animals_nature + topic_adult_content + topic_life_relationship + topic_books_movies_fandom + topic_economy_finance + topic_environment_climate_weather + topic_music + topic_health_mental_health_body + topic_current_political_events + topic_food_drinks + topic_ai_silicon_valley + 
                                   lean1 + misinfo, data = data),
                                   #reference: topic_social_media_plaforms_communities
  share_low_info_quality_04 = glm(share_low_info_quality_04 ~ user_count + status_count + 
                                   lang_de + lang_fr + lang_ja + lang_other + software_pleroma + 
                                   software_gotosocial + software_akkoma + software_pixelfed + software_other + 
                                 topic_software_programming + topic_misc + topic_science_research + topic_news_politics + topic_humor_memes_play + topic_sports + topic_countries_local_contexts + topic_religion + topic_games_gaming + topic_identity_discrimination_subculture + topic_travel_mobility_transport + topic_cloud_networks_security_privacy + topic_arts_crafts_design + topic_hardware_devices_infrastructure + topic_animals_nature + topic_adult_content + topic_life_relationship + topic_books_movies_fandom + topic_economy_finance + topic_environment_climate_weather + topic_music + topic_health_mental_health_body + topic_current_political_events + topic_food_drinks + topic_ai_silicon_valley + 
                                   + lean1 + misinfo, data = data),
                                  #reference: topic_social_media_plaforms_communities
  share_low_info_quality_05 = glm(share_low_info_quality_05 ~ user_count + status_count + 
                                   lang_de + lang_fr + lang_ja + lang_other + software_pleroma + 
                                   software_gotosocial + software_akkoma + software_pixelfed + software_other +  
                                 topic_software_programming + topic_misc + topic_science_research + topic_news_politics + topic_humor_memes_play + topic_sports + topic_countries_local_contexts + topic_religion + topic_games_gaming + topic_identity_discrimination_subculture + topic_travel_mobility_transport + topic_cloud_networks_security_privacy + topic_arts_crafts_design + topic_hardware_devices_infrastructure + topic_animals_nature + topic_adult_content + topic_life_relationship + topic_books_movies_fandom + topic_economy_finance + topic_environment_climate_weather + topic_music + topic_health_mental_health_body + topic_current_political_events + topic_food_drinks + topic_ai_silicon_valley + 
                                   + lean1 + misinfo, data = data),
                                  #reference: topic_social_media_plaforms_communities
  hs_percent = glm(hs_percent ~ user_count + status_count + 
                    lang_de + lang_fr + lang_ja + lang_other + software_pleroma + 
                    software_gotosocial + software_akkoma + software_pixelfed + software_other + 
                  topic_software_programming 
                  + topic_misc + topic_science_research + topic_news_politics + topic_humor_memes_play + topic_sports + topic_countries_local_contexts + topic_religion + topic_games_gaming + topic_identity_discrimination_subculture + topic_travel_mobility_transport + topic_cloud_networks_security_privacy + topic_arts_crafts_design + topic_hardware_devices_infrastructure + topic_animals_nature + topic_adult_content + topic_life_relationship + topic_books_movies_fandom + topic_economy_finance + topic_environment_climate_weather + topic_music + topic_health_mental_health_body + topic_current_political_events + topic_food_drinks + topic_ai_silicon_valley + 
                    + lean1 + hate_speech, data = data)
                    #reference: topic_social_media_plaforms_communities
)


pseudo_r2 <- sapply(models, function(m) {
  as.numeric(pscl::pR2(m)["McFadden"])
})

pseudo_r2_df <- data.frame(
  regression = names(pseudo_r2),
  McFadden_R2 = pseudo_r2
)


results_list <- lapply(names(models), function(n) {
  m <- models[[n]]
  df <- as.data.frame(summary(m)$coefficients)
  df$variable <- rownames(df)
  df$regression <- n
  df
})

all_results <- bind_rows(results_list)

all_results <- all_results %>%
  mutate(formatted = sprintf("%.3f (%.3f)", Estimate, `Pr(>|t|)`))
all_results <- all_results %>%
  mutate(
    sig = case_when(
      `Pr(>|t|)` < 0.001 ~ "***",
      `Pr(>|t|)` < 0.01  ~ "**",
      `Pr(>|t|)` < 0.05  ~ "*",
      `Pr(>|t|)` < 0.1   ~ ".",
      TRUE               ~ ""
    ),
    formatted = sprintf("%.3f%s (%.3f)", Estimate, sig, `Pr(>|t|)`)
  )


all_results <- all_results %>%
  left_join(pseudo_r2_df, by = "regression")

write.csv(all_results, "./results/r2/rule_compliance.csv", row.names = FALSE)