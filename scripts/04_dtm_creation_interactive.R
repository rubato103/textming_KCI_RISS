# 04_dtm_creation_interactive.R

# Load necessary libraries
library(tm)
library(wordcloud)
library(RColorBrewer)
library(DT)
library(dplyr)

# Load the preprocessed data
# Assuming 'preprocessed_data.RData' contains a 'corpus' object
load("preprocessed_data.RData") 

# --- Create Document-Term Matrix (DTM) ---
# This process can be resource-intensive for large corpora.
# Consider sampling or more aggressive preprocessing if memory is an issue.

# Function to create DTM with options
create_dtm <- function(corpus, min_freq = 1, max_freq = Inf, sparsity = 0.999) {
  # Create DTM
  dtm <- DocumentTermMatrix(corpus, 
                            control = list(
                              wordLengths = c(min_freq, max_freq)
                            ))
  
  # Remove sparse terms (terms that appear in very few documents)
  # A higher sparsity value means more terms will be kept (less aggressive removal)
  dtm <- removeSparseTerms(dtm, sparsity)
  
  return(dtm)
}

# Initial DTM creation (can be adjusted interactively later)
dtM <- create_dtm(corpus)

# --- Explore DTM ---

# Get term frequencies
term_frequencies <- colSums(as.matrix(dtm))
term_frequencies <- sort(term_frequencies, decreasing = TRUE)

# Create a data frame for display
term_freq_df <- data.frame(
  Term = names(term_frequencies),
  Frequency = term_frequencies
)

# --- Interactive Visualization (using Shiny or similar for full interactivity) ---
# For a non-Shiny R script, we can simulate interactivity by allowing parameter changes
# and re-running sections.

# Word Cloud Generation
generate_wordcloud <- function(term_freq_df, max_words = 100, colors = brewer.pal(8, "Dark2")) {
  wordcloud(words = term_freq_df$Term, 
            freq = term_freq_df$Frequency, 
            min.freq = 1, 
            max.words = max_words,
            random.order = FALSE, 
            colors = colors)
}

# Display top N terms in a data table
display_top_terms <- function(term_freq_df, n = 20) {
  datatable(head(term_freq_df, n), 
            options = list(pageLength = 10, autoWidth = TRUE))
}

# --- Main interactive loop (conceptual for a script) ---
# In a real interactive application (e.g., Shiny), these would be reactive outputs.
# Here, you would manually change parameters and re-run the code.

# Example: Adjusting DTM parameters and re-generating visualizations
# You can uncomment and modify these lines to see the effect

# # 1. Re-create DTM with different parameters
# #    - min_freq: minimum word length
# #    - max_freq: maximum word length
# #    - sparsity: terms appearing in less than (1-sparsity)*100% of documents are removed
# dtm_adjusted <- create_dtm(corpus, min_freq = 3, max_freq = 15, sparsity = 0.99)
# term_frequencies_adjusted <- colSums(as.matrix(dtm_adjusted))
# term_frequencies_adjusted <- sort(term_frequencies_adjusted, decreasing = TRUE)
# term_freq_df_adjusted <- data.frame(
#   Term = names(term_frequencies_adjusted),
#   Frequency = term_frequencies_adjusted
# )
# 
# # 2. Generate word cloud with adjusted DTM and more words
# cat("\nGenerating Word Cloud with Adjusted DTM...\n")
# generate_wordcloud(term_freq_df_adjusted, max_words = 150)
# 
# # 3. Display top 30 terms from adjusted DTM
# cat("\nDisplaying Top 30 Terms from Adjusted DTM:\n")
# display_top_terms(term_freq_df_adjusted, n = 30)

# --- Further Analysis (Example: Finding associations) ---
# findAssocs(dtm, terms = "data", corlimit = 0.25) # Example: find terms associated with "data"

# Save DTM for further use
save(dtm, file = "dtm_output.RData")
cat("\nDTM saved to 'dtm_output.RData'\n")
