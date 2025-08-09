```R
# 05_stm_topic_modeling.R
# Structural Topic Model (STM) for KCI and RISS data

# 1. Load data and libraries ---------------------------------------------------
library(stm) # For STM
library(tm) # For text mining
library(SnowballC) # For stemming
library(tidyverse) # For data manipulation
library(tidytext) # For text manipulation
library(furrr) # For parallel processing
library(here) # For file paths

# Load preprocessed data
load(here("data", "kci_riss_preprocessed.RData"))

# 2. Prepare data for STM -----------------------------------------------------
# Create a corpus from the preprocessed data
kci_riss_corpus <- VCorpus(VectorSource(kci_riss_preprocessed$text))

# Preprocessing steps for STM (similar to previous steps but within tm package)
# Convert to lowercase
kci_riss_corpus <- tm_map(kci_riss_corpus, content_transformer(tolower))
# Remove numbers
kci_riss_corpus <- tm_map(kci_riss_corpus, removeNumbers)
# Remove punctuation
kci_riss_corpus <- tm_map(kci_riss_corpus, removePunctuation)
# Remove stopwords (English and Korean custom stopwords)
# You might need to define custom Korean stopwords if not already done
# For simplicity, let's assume English stopwords for now or use a pre-defined list
kci_riss_corpus <- tm_map(kci_riss_corpus, removeWords, stopwords("english"))
# Remove custom stopwords (if any)
# kci_riss_corpus <- tm_map(kci_riss_corpus, removeWords, c("custom", "stopwords"))
# Stemming (English only)
kci_riss_corpus <- tm_map(kci_riss_corpus, stemDocument)
# Strip whitespace
kci_riss_corpus <- tm_map(kci_riss_corpus, stripWhitespace)

# Create a Document-Term Matrix (DTM)
kci_riss_dtm <- DocumentTermMatrix(kci_riss_corpus)

# Remove sparse terms (optional, but good for reducing matrix size)
# Adjust sparsity threshold as needed
kci_riss_dtm <- removeSparseTerms(kci_riss_dtm, 0.99) # Keep terms that appear in at least 1% of documents

# Convert DTM to a format suitable for STM
# The `stm` package requires a `dfm` object or a list from `readCorpus`
# We can convert the DTM to a list of documents and vocabulary
kci_riss_stm_data <- convert(kci_riss_dtm, to = "stm")

# 3. Estimate optimal number of topics (K) ------------------------------------
# This step can be computationally intensive.
# It's recommended to run this on a subset or with parallel processing.
# Using `furrr` for parallel processing
plan(multisession, workers = availableCores() - 1) # Use all but one core

# SearchK function to estimate optimal K
# This can take a very long time. For demonstration, let's use a smaller range.
# You might want to try a wider range like 5:50 in real analysis.
# The `data` argument should be the preprocessed data frame with metadata
# The `documents` and `vocab` come from `kci_riss_stm_data`
# The `prevalence` formula should include any metadata you want to use as covariates
# For now, let's use a simple formula without covariates for K estimation
# If you have metadata like 'year', 'journal', etc., you can include them:
# ~ s(year) + journal
# For this example, let's assume no specific metadata for K estimation
# If you have metadata, ensure it's aligned with the documents in kci_riss_stm_data$documents
# If not, you need to subset kci_riss_preprocessed to match the DTM rows.

# For now, let's create a dummy metadata if not directly available or matched
# This is a placeholder. In a real scenario, ensure metadata aligns with DTM rows.
if (!exists("kci_riss_preprocessed_matched")) {
  # Assuming kci_riss_preprocessed is already aligned with the DTM rows
  # If DTM removed sparse terms, kci_riss_preprocessed might need to be subsetted
  # to match the rows of kci_riss_stm_data$documents
  kci_riss_preprocessed_matched <- kci_riss_preprocessed[as.numeric(rownames(kci_riss_stm_data$documents)), ]
}

# Example of using metadata in SearchK (if available and matched)
# If you don't have metadata, use ~1
# If you have metadata, ensure it's a data frame with rows corresponding to documents
# For this example, let's assume we have 'year' and 'source' in kci_riss_preprocessed_matched
# If not, you can use ~1 or create dummy metadata for demonstration
# For now, let's use ~1 for simplicity in K estimation
# If you have actual metadata, replace ~1 with your formula, e.g., ~ s(year) + source
# Make sure the metadata dataframe is passed to the `data` argument.

# For demonstration, let's use a small range for K
# In a real analysis, you would use a wider range, e.g., K = c(5:50)
# And potentially run it for a longer time.
# This step is crucial for determining the number of topics.
# It evaluates different metrics like held-out likelihood, exclusivity, semantic coherence.
# The optimal K is often a trade-off between these metrics.

# To avoid long computation for demonstration, let's skip SearchK for now
# and directly choose a K for the next step.
# In a real project, you would run SearchK and analyze its output.
# k_search_results <- searchK(
#   documents = kci_riss_stm_data$documents,
#   vocab = kci_riss_stm_data$vocab,
#   data = kci_riss_preprocessed_matched, # Ensure this is aligned with documents
#   K = c(5, 10, 15, 20), # Example range, use wider range in real analysis
#   prevalence = ~1, # Or ~ s(year) + source if you have metadata
#   N = 10, # Number of random starts for each K, increase for more robust results
#   cores = availableCores() - 1,
#   verbose = TRUE
# )
#
# # Plotting SearchK results (after running SearchK)
# plot(k_search_results)
#
# # You would then analyze the plot and choose an optimal K.
# # For example, if K=10 looks good based on the metrics:
# optimal_k <- 10

# For this script, let's assume an optimal K is chosen, e.g., K=10
optimal_k <- 10

# 4. Run STM model ------------------------------------------------------------
# Now, run the STM model with the chosen optimal_k
# The `prevalence` formula allows you to include covariates that influence topic prevalence
# The `content` formula allows you to include covariates that influence word choice within topics
# For this example, let's use 'year' and 'source' (e.g., KCI/RISS) as prevalence covariates
# And no content covariates for simplicity.
# Ensure kci_riss_preprocessed_matched is correctly aligned with the documents.

# If you don't have 'year' or 'source' in your preprocessed data, use ~1 for prevalence.
# For demonstration, let's assume 'year' and 'source' are available and matched.
# If not, replace with ~1.
# kci_riss_stm_model <- stm(
#   documents = kci_riss_stm_data$documents,
#   vocab = kci_riss_stm_data$vocab,
#   K = optimal_k,
#   prevalence = ~ year + source, # Example with metadata
#   data = kci_riss_preprocessed_matched, # Ensure this is aligned
#   max.em.iter = 500, # Maximum EM iterations
#   init.type = "Spectral", # Initialization method
#   seed = 848 # For reproducibility
# )

# For simplicity and to ensure the script runs without specific metadata requirements,
# let's run a basic STM model without covariates for now.
# In a real analysis, you would use relevant metadata.
kci_riss_stm_model <- stm(
  documents = kci_riss_stm_data$documents,
  vocab = kci_riss_stm_data$vocab,
  K = optimal_k,
  prevalence = ~1, # No covariates for prevalence
  data = kci_riss_preprocessed_matched, # Still need to pass data for consistency
  max.em.iter = 500,
  init.type = "Spectral",
  seed = 848
)

# 5. Analyze STM results ------------------------------------------------------

# Print topic summaries
# This shows top words for each topic and their exclusivity/prevalence
labelTopics(kci_riss_stm_model)

# Plot topics (optional, requires more setup for meaningful visualization)
# plot(kci_riss_stm_model, type = "summary")
# plot(kci_riss_stm_model, type = "labels", topics = c(1, 2, 3)) # Example for specific topics

# Estimate topic prevalence (how much each topic contributes to each document)
topic_prevalence <- estimateEffect(
  formula = optimal_k ~ 1, # Or ~ year + source if used in prevalence
  stmobj = kci_riss_stm_model,
  metadata = kci_riss_preprocessed_matched # Ensure this is aligned
)

# Summarize topic prevalence (e.g., average prevalence across all documents)
summary(topic_prevalence)

# Extract topic proportions for each document
# This gives a matrix where rows are documents and columns are topics
# Values are the proportion of each topic in that document
doc_topic_proportions <- make.dt(kci_riss_stm_model)

# You can then merge this with your original data for further analysis
# For example, to see which topics are most prevalent in KCI vs RISS
# kci_riss_preprocessed_with_topics <- cbind(kci_riss_preprocessed_matched, doc_topic_proportions)

# Find most representative documents for each topic
# findThoughts(kci_riss_stm_model, texts = kci_riss_preprocessed_matched$text, n = 2, topics = 1)

# Plotting topic correlations (if you have many topics)
# topic_corr <- topicCorr(kci_riss_stm_model)
# plot(topic_corr)

# 6. Save results -------------------------------------------------------------
save(kci_riss_stm_model, file = here("results", "kci_riss_stm_model.RData"))
save(topic_prevalence, file = here("results", "kci_riss_topic_prevalence.RData"))
save(doc_topic_proportions, file = here("results", "kci_riss_doc_topic_proportions.RData"))

# End of script
```