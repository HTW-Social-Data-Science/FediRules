library('arrow')
library('tidyverse')
library('sjPlot')
library('ggplot2')
library('dsl')
library(pscl)
library(car)
library(glmnet)
library(philentropy)

data <- read_parquet('regression_data.parquet')

impute_median <- function(x) {
  ifelse(is.na(x), median(x, na.rm = TRUE), x)
}

# Convert selected variables to numeric and apply log transformation
data <- data %>%
  mutate(
    across(c(user_count, status_count), ~ replace_na(as.numeric(.), 0)),
    across(c(user_count, status_count), ~ log1p(pmax(as.numeric(.), 0)))
  )

# Initialize lists to store results and p-values
results_list <- list()
p_values <- c()

# Function to collect coefficients and p-values for Holm-Bonferroni correction
collect_coefficients <- function(model, outcome_name) {
  summary_model <- summary(model)
  coefficients <- summary_model$coefficients
  if (is.null(coefficients) || nrow(coefficients) == 0) return(NULL)
  
  coeffs_df <- as.data.frame(coefficients)
  coeffs_df$variable <- rownames(coefficients)
  coeffs_df$regression <- outcome_name
  results_list[[length(results_list) + 1]] <<- coeffs_df
  p_col <- intersect(c("Pr(>|t|)", "Pr(>|z|)"), colnames(coeffs_df))
  p_values <<- c(p_values, coeffs_df[[p_col[1]]])
}

# initialize DSL results list
dsl_results_list <<- list()

# function to extract DSL table (without correction - applied later globally)
extract_dsl_table <- function(model, outcome_name) {
  if (is.null(model$coefficients)) return(NULL)

  df <- data.frame(
    variable = names(model$coefficients),
    estimate = as.numeric(model$coefficients),
    std_error = sqrt(diag(model$vcov))
  )

  df$statistic <- df$estimate / df$std_error
  df$p_value <- 2 * pnorm(abs(df$statistic), lower.tail = FALSE)
  df$outcome <- outcome_name
  df
}

# Define predictors and main regression
predictors <- c(
  "user_count", "status_count", #"is_blocked_by_mastodon_social",
  #paste0("lang_", c("de", "fr", "ja", "other")), #reference: en
  paste0("software_", c("pleroma", "gotosocial", "akkoma", "pixelfed", "other")) #reference: mastodon
  #paste0("topic_", c("software_programming", "science_research", "misc", "news_politics", "humor_memes_play", "sports", "countries_local_contexts", "religion", "games_gaming", "identity_discrimination_subculture", "travel_mobility_transport", "cloud_networks_security_privacy", "arts_crafts_design", "hardware_devices_infrastructure", "animals_nature", "adult_content", "life_relationship", "books_movies_fandom", "economy_finance", "environment_climate_weather", "music", "health_mental_health_body", "current_political_events", "food_drinks", "ai_silicon_valley")), #"social_media_plaforms_communities",
  #"lean1", "low_info_02_count", "hs_count"
)

# Main regression model
predictor_formula <- as.formula(paste("has_rules ~", paste(predictors, collapse = " + ")))
model1 <- glm(predictor_formula, data = data, family = binomial(link = "logit"))
summary(model1)
pR2(model1)["McFadden"]

# Check for multicollinearity using VIF
alias(model1)
vif_values <- vif(model1)
print(vif_values)

# Collect coefficients for the main regression
collect_coefficients(model1, "has_rules")

# Regressions on individual rules
outcome_variables <- c("advertising", "ai_generated", "animal_cruelty", "automated_tools_bots", "be_nice", "block_report_mute", "codes_conduct", "consequences_moderation", "copyright_piracy_credit", "crypto", "CSAM", "cw_general", "dont_be_dick", "harassment", "hate_speech", "illegal", "incitement_violence", "language_specific", "misinfo", "nazis", "nsfw", "nsfw_cw", "politics", "politics_cw", "adult_content", "adult_content_cw", "privacy", "private_no_reg", "registration_requirements", "religion", "scrape_model_training", "sensitive_cw", "spam", "spoilers", "spoilers_cw", "violence", "violence_cw", "impersonation", "copyright")

output_dir <- "./results/without_blocked_by_mastodon/dsl_community_discourse/"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

run_individual_rules <- TRUE

if (run_individual_rules) {
  for (outcome in outcome_variables) {
    
    true_var <- paste0(outcome, "_true")
    
    print(outcome)
    print(true_var)
    
    # Test auf genügend Variation im Outcome
    labeled_subset <- data %>% filter(labeled == 1)
    tab <- table(labeled_subset[[true_var]])
    print(tab)
    
    if (length(tab) < 2 || min(tab) < 10) {
      message("Skipping ", outcome, ": insufficient labeled variation")
      next
    }
    
    # Singuläre Spalten prüfen
    X <- model.matrix(as.formula(paste0(true_var, " ~ ", paste(predictors, collapse=" + "))),
                      data = labeled_subset)[, -1, drop=FALSE]
    rank_X <- qr(X)$rank
    if (rank_X < ncol(X)) {
      singular_cols <- colnames(X)[!colnames(X) %in% colnames(X[, qr(X)$pivot[1:rank_X]])]
      message("Singular columns in ", outcome, ": ", paste(singular_cols, collapse = ", "))
      predictors_clean <- setdiff(predictors, singular_cols)
    } else {
      predictors_clean <- predictors
    }
    
    # Regression in tryCatch
    tryCatch({
      formula_clean <- as.formula(paste0(true_var, " ~ ", paste(predictors_clean, collapse=" + ")))
      
      out_lm <- dsl(
        model = "logit",
        formula = formula_clean,
        predicted_var = true_var,
        prediction = outcome,
        data = data,
        labeled = "labeled"
      )
      
      # extract results
      result_df <- extract_dsl_table(out_lm, outcome)
      
      # add McFadden R2 BEFORE saving to list
      glm_model <- glm(formula_clean, data = labeled_subset, family = binomial(link="logit"))
      r2 <- tryCatch(as.numeric(pR2(glm_model)["McFadden"]), error = function(e) NA)
      result_df$R2 <- r2
      
      # save to list and write csv
      if (!is.null(result_df)) {
        current_list <- get("dsl_results_list", envir = .GlobalEnv)
        current_list[[length(current_list) + 1]] <- result_df
        assign("dsl_results_list", current_list, envir = .GlobalEnv)

        write.csv(
          result_df,
          file = file.path(output_dir, paste0("dsl_", outcome, ".csv")),
          row.names = FALSE
        )
      } 
    }, error = function(e) {
      message("Fehler bei Outcome ", outcome, ": ", e$message)
    })
  }
}
if (length(dsl_results_list) > 0) {
  all_dsl_results <- do.call(rbind, dsl_results_list)
  
  # holm-bonferroni auf alle DSL p-values gemeinsam anwenden
  all_dsl_results$corrected_p <- p.adjust(all_dsl_results$p_value, method = "holm")
  
  all_dsl_results$significance <- cut(
    all_dsl_results$corrected_p,
    breaks = c(-Inf, 0.001, 0.01, 0.05, 0.1, Inf),
    labels = c("***", "**", "*", ".", ""),
    right = FALSE
  )
  
  significant_dsl <- all_dsl_results[all_dsl_results$corrected_p < 0.05,
                                      c("variable", "estimate", "outcome")]
  
  wide_dsl <- pivot_wider(
    significant_dsl,
    names_from = outcome,
    values_from = estimate,
    values_fill = NA
  )
  
  write.csv(all_dsl_results, "./results/without_blocked_by_mastodon/dsl_all_corrected.csv", row.names = FALSE)
  write.csv(wide_dsl, "./results/without_blocked_by_mastodon/dsl_wide_corrected.csv", row.names = FALSE)
  
} else {
  message("dsl_results_list is empty - no DSL results to process")
}