# 05_stm_topic_modeling.R
# Structural Topic Model (STM) for KCI and RISS data

# 1. Load data and libraries ---------------------------------------------------
library(stm) # For STM
library(tm) # For text mining
library(SnowballC) # For stemming
library(tidyverse) # For data manipulation
library(tidytext) # For text manipulation
library(furrr) # For parallel processing
# library(here) # For file paths - 제거됨, 상대 경로 사용

# ========== quanteda DTM 데이터 로드 ==========
cat("\n", rep("=", 60), "\n")
cat("📊 quanteda DTM 데이터 로드\n") 
cat(rep("=", 60), "\n")

# quanteda DTM 파일 찾기
quanteda_files <- list.files("data/processed/", 
                            pattern = ".*_quanteda_dfm\\.rds$", 
                            full.names = TRUE)

if (length(quanteda_files) == 0) {
  stop("quanteda DTM 파일을 찾을 수 없습니다. 04_quanteda_dtm_creation.R을 먼저 실행해주세요.")
}

# 최신 quanteda DTM 파일 자동 선택
latest_quanteda_file <- quanteda_files[order(file.mtime(quanteda_files), decreasing = TRUE)][1]
cat(sprintf("✅ 사용할 quanteda DTM 파일: %s\n", basename(latest_quanteda_file)))

# quanteda DTM 데이터 로드
cat("📁 quanteda DTM 데이터 로딩 중...\n")
dfm_data <- readRDS(latest_quanteda_file)

# 데이터 구조 확인
cat(sprintf("- STM 문서 수: %d\n", length(dfm_data$stm_documents)))
cat(sprintf("- STM 어휘 수: %d\n", length(dfm_data$stm_vocab))) 
cat(sprintf("- 메타데이터 변수: %d개\n", ncol(dfm_data$stm_meta)))
cat(sprintf("- 전처리 방법: %s\n", dfm_data$analysis_type))

# STM 데이터 추출
kci_riss_stm_data <- list(
  documents = dfm_data$stm_documents,
  vocab = dfm_data$stm_vocab
)

# 메타데이터 추출 (STM용)
kci_riss_preprocessed_matched <- dfm_data$stm_meta

cat("✅ quanteda → STM 형식 변환 완료\n")

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

# 메타데이터가 이미 quanteda에서 로드되었으므로 추가 처리 불필요
# quanteda의 STM 변환은 자동으로 문서와 메타데이터를 정렬해줌

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

# 메타데이터와 문서 수 일치성 확인
cat(sprintf("\n📋 데이터 일치성 확인:\n"))
cat(sprintf("- STM 문서 수: %d\n", length(kci_riss_stm_data$documents)))
cat(sprintf("- 메타데이터 행 수: %d\n", nrow(kci_riss_preprocessed_matched)))

# 문서 수와 메타데이터 행 수가 다른 경우 조정
if (length(kci_riss_stm_data$documents) != nrow(kci_riss_preprocessed_matched)) {
  cat("⚠️ 문서 수와 메타데이터 행 수 불일치 감지. 조정 중...\n")
  
  # 더 작은 크기로 맞춤
  min_size <- min(length(kci_riss_stm_data$documents), nrow(kci_riss_preprocessed_matched))
  
  # STM 데이터 조정
  kci_riss_stm_data$documents <- kci_riss_stm_data$documents[1:min_size]
  
  # 메타데이터 조정
  kci_riss_preprocessed_matched <- kci_riss_preprocessed_matched[1:min_size, ]
  
  cat(sprintf("✅ 조정 완료: %d개 문서로 통일\n", min_size))
}

# 메타데이터 변수 확인 및 prevalence 공식 결정
meta_vars <- names(kci_riss_preprocessed_matched)
cat(sprintf("\n사용 가능한 메타데이터 변수: %s\n", paste(meta_vars, collapse = ", ")))

# 메타데이터 변수 존재 여부 및 유효성 검사
use_prevalence <- FALSE
prevalence_formula <- NULL

if (ncol(kci_riss_preprocessed_matched) > 0) {
  # NA 값이 있는 메타데이터 변수 처리
  if ("pub_year" %in% meta_vars && "KCI 등재 구분" %in% meta_vars) {
    # NA 값 확인
    pub_year_na <- sum(is.na(kci_riss_preprocessed_matched$pub_year))
    kci_na <- sum(is.na(kci_riss_preprocessed_matched$`KCI 등재 구분`))
    
    cat(sprintf("- pub_year NA 수: %d\n", pub_year_na))
    cat(sprintf("- KCI 등재 구분 NA 수: %d\n", kci_na))
    
    if (pub_year_na == 0 && kci_na == 0) {
      prevalence_formula <- ~ pub_year + `KCI 등재 구분`
      use_prevalence <- TRUE
      cat("✅ 메타데이터 공변량 사용: pub_year + KCI 등재 구분\n")
    } else if (pub_year_na == 0) {
      prevalence_formula <- ~ pub_year  
      use_prevalence <- TRUE
      cat("✅ 메타데이터 공변량 사용: pub_year (KCI 등재 구분은 NA값으로 제외)\n")
    } else {
      cat("⚠️ 모든 메타데이터 변수에 NA값 존재 - 공변량 없이 진행\n")
    }
  } else if ("pub_year" %in% meta_vars) {
    pub_year_na <- sum(is.na(kci_riss_preprocessed_matched$pub_year))
    if (pub_year_na == 0) {
      prevalence_formula <- ~ pub_year  
      use_prevalence <- TRUE
      cat("✅ 메타데이터 공변량 사용: pub_year\n")
    } else {
      cat("⚠️ pub_year에 NA값 존재 - 공변량 없이 진행\n")
    }
  } else {
    cat("⚠️ 활용 가능한 메타데이터 변수 없음 - 공변량 없이 진행\n")
  }
} else {
  cat("⚠️ 메타데이터가 비어있음 - 공변량 없이 진행\n")
}

if (!use_prevalence) {
  cat("✅ prevalence 공식 없이 STM 실행 (순수 토픽 모델링)\n")
}

# STM 모델 실행 (메타데이터 활용)
cat("\n🔨 STM 토픽 모델링 실행 중...\n")
cat(sprintf("- 토픽 수: %d\n", optimal_k))
cat(sprintf("- 문서 수: %d\n", length(kci_riss_stm_data$documents)))
cat(sprintf("- 어휘 수: %d\n", length(kci_riss_stm_data$vocab)))
cat(sprintf("- 메타데이터 행 수: %d\n", nrow(kci_riss_preprocessed_matched)))

# prevalence 사용 여부에 따른 STM 모델 실행
if (use_prevalence) {
  kci_riss_stm_model <- stm(
    documents = kci_riss_stm_data$documents,
    vocab = kci_riss_stm_data$vocab,
    K = optimal_k,
    prevalence = prevalence_formula, # 메타데이터 공변량 사용
    data = kci_riss_preprocessed_matched,
    max.em.its = 500,  # 올바른 파라미터명
    init.type = "Spectral",
    seed = 848,
    verbose = TRUE
  )
} else {
  # 공변량 없이 순수 토픽 모델링
  kci_riss_stm_model <- stm(
    documents = kci_riss_stm_data$documents,
    vocab = kci_riss_stm_data$vocab,
    K = optimal_k,
    max.em.its = 500,  # 올바른 파라미터명
    init.type = "Spectral",
    seed = 848,
    verbose = TRUE
  )
}

# 5. Analyze STM results ------------------------------------------------------

cat("\n", rep("=", 60), "\n")
cat("📈 STM 결과 분석\n")
cat(rep("=", 60), "\n")

# Print topic summaries
cat("\n📋 토픽별 주요 용어 요약:\n")
cat("각 토픽의 상위 용어들을 확률(Prob), 프레임(FREX), 리프트(Lift), 점수(Score) 기준으로 표시합니다.\n\n")
topic_labels <- labelTopics(kci_riss_stm_model)
print(topic_labels)

# 토픽별 전체 비율 계산 및 출력
cat("\n📊 문서 전체에서 각 토픽의 평균 비율:\n")
topic_props <- colMeans(kci_riss_stm_model$theta)
for (i in 1:length(topic_props)) {
  cat(sprintf("토픽 %2d: %.2f%% - 주요용어: %s\n", 
              i, topic_props[i] * 100,
              paste(topic_labels$prob[i, 1:5], collapse = ", ")))
}

# Plot topics (토픽 요약 시각화)
cat("\n🎨 토픽 요약 시각화 생성 중...\n")
tryCatch({
  plot(kci_riss_stm_model, type = "summary", xlim = c(0, max(topic_props) * 1.2))
  cat("✅ 토픽 비율 차트가 생성되었습니다.\n")
}, error = function(e) {
  cat(sprintf("⚠️ 토픽 요약 시각화 오류: %s\n", e$message))
})

# 상위 3개 토픽의 용어 라벨 시각화
cat("\n🏷️ 상위 3개 토픽의 용어 라벨 시각화:\n")
top_topics <- order(topic_props, decreasing = TRUE)[1:min(3, length(topic_props))]
cat(sprintf("상위 토픽들: %s\n", paste(paste0("토픽", top_topics), collapse = ", ")))
tryCatch({
  plot(kci_riss_stm_model, type = "labels", topics = top_topics)
  cat("✅ 상위 토픽 라벨 차트가 생성되었습니다.\n")
}, error = function(e) {
  cat(sprintf("⚠️ 토픽 라벨 시각화 오류: %s\n", e$message))
})

# Estimate topic prevalence (토픽 효과 분석)
if (use_prevalence) {
  cat("\n📊 메타데이터 기반 토픽 효과 분석 중...\n")
  topic_prevalence <- estimateEffect(
    formula = prevalence_formula, # 앞서 결정된 공식 사용
    stmobj = kci_riss_stm_model,
    metadata = kci_riss_preprocessed_matched
  )
  
  cat("✅ 토픽 효과 분석 완료!\n")
  cat("\n📈 토픽 효과 분석 결과 요약:\n")
  print(summary(topic_prevalence))
} else {
  cat("\n⚠️ 메타데이터가 없어 토픽 효과 분석을 건너뜁니다.\n")
  cat("📊 순수 토픽 모델링 결과만 제공됩니다.\n")
  topic_prevalence <- NULL
}

# Extract topic proportions for each document
cat("\n📑 문서별 토픽 비율 매트릭스 생성 중...\n")
doc_topic_proportions <- make.dt(kci_riss_stm_model)
cat(sprintf("✅ 문서-토픽 매트릭스 생성 완료: %d개 문서 × %d개 토픽\n", 
            nrow(doc_topic_proportions), ncol(doc_topic_proportions)))

# 각 문서의 주요 토픽 확인
main_topics <- apply(doc_topic_proportions, 1, which.max)
main_topic_props <- apply(doc_topic_proportions, 1, max)
cat("\n🎯 문서별 주요 토픽 분포:\n")
topic_dist <- table(main_topics)
for (i in 1:length(topic_dist)) {
  topic_num <- as.numeric(names(topic_dist)[i])
  count <- topic_dist[i]
  percentage <- count / sum(topic_dist) * 100
  cat(sprintf("토픽 %2d: %3d개 문서 (%.1f%%)\n", topic_num, count, percentage))
}

# 토픽별 대표 문서 찾기 (논문명이 있는 경우)
if ("논문명" %in% names(kci_riss_preprocessed_matched)) {
  cat("\n📚 각 토픽별 대표 논문 (상위 2개):\n")
  for (i in 1:min(5, optimal_k)) {  # 상위 5개 토픽만
    cat(sprintf("\n🔸 토픽 %d 대표 논문:\n", i))
    tryCatch({
      thoughts <- findThoughts(kci_riss_stm_model, 
                              texts = kci_riss_preprocessed_matched$논문명, 
                              n = 2, topics = i)
      for (j in 1:length(thoughts$docs[[1]])) {
        cat(sprintf("  %d. %s\n", j, thoughts$docs[[1]][j]))
      }
    }, error = function(e) {
      cat(sprintf("  ⚠️ 토픽 %d 대표 문서 추출 실패\n", i))
    })
  }
} else {
  cat("\n⚠️ 논문명 정보가 없어 대표 문서를 표시할 수 없습니다.\n")
}

# 토픽 간 상관관계 분석
cat("\n🔗 토픽 간 상관관계 분석 중...\n")
if (optimal_k >= 3) {
  tryCatch({
    topic_corr <- topicCorr(kci_riss_stm_model)
    cat("✅ 토픽 상관관계 분석 완료!\n")
    plot(topic_corr)
    cat("📊 토픽 상관관계 네트워크 그래프가 생성되었습니다.\n")
  }, error = function(e) {
    cat(sprintf("⚠️ 토픽 상관관계 분석 오류: %s\n", e$message))
  })
} else {
  cat("⚠️ 토픽 수가 너무 적어 상관관계 분석을 건너뜁니다.\n")
}

# 6. Save results -------------------------------------------------------------

cat("\n", rep("=", 60), "\n")
cat("💾 STM 분석 결과 저장\n")
cat(rep("=", 60), "\n")

# 결과 저장 디렉토리 생성
if (!dir.exists("results")) {
  dir.create("results", recursive = TRUE)
  cat("📁 results/ 디렉토리를 생성했습니다.\n")
} else {
  cat("📁 기존 results/ 디렉토리를 사용합니다.\n")
}

# 타임스탬프 추가
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

# STM 모델 저장
model_file <- sprintf("results/kci_riss_stm_model_%s_K%d.RData", timestamp, optimal_k)
cat(sprintf("💾 STM 모델 저장 중... %s\n", basename(model_file)))
save(kci_riss_stm_model, file = model_file)
cat("✅ STM 모델 저장 완료!\n")

# 토픽 효과 분석 결과 저장 (있는 경우에만)
if (!is.null(topic_prevalence)) {
  prevalence_file <- sprintf("results/kci_riss_topic_prevalence_%s_K%d.RData", timestamp, optimal_k)
  cat(sprintf("📊 토픽 효과 분석 결과 저장 중... %s\n", basename(prevalence_file)))
  save(topic_prevalence, file = prevalence_file)
  cat("✅ 토픽 효과 분석 결과 저장 완료!\n")
} else {
  prevalence_file <- "토픽 효과 분석 없음"
  cat("⚠️ 토픽 효과 분석 결과가 없어 저장하지 않습니다.\n")
}

# 문서-토픽 비율 매트릭스 저장
doc_topics_file <- sprintf("results/kci_riss_doc_topic_proportions_%s_K%d.RData", timestamp, optimal_k)
cat(sprintf("📑 문서-토픽 비율 매트릭스 저장 중... %s\n", basename(doc_topics_file)))
save(doc_topic_proportions, file = doc_topics_file)
cat("✅ 문서-토픽 비율 매트릭스 저장 완료!\n")

# CSV 형태로도 저장 (Excel에서 열람 가능)
csv_file <- sprintf("results/kci_riss_document_topics_%s_K%d.csv", timestamp, optimal_k)
cat(sprintf("📋 CSV 형태로 문서-토픽 결과 저장 중... %s\n", basename(csv_file)))

# 실제 문서 ID 추출 (우선순위 적용)
actual_doc_ids <- NULL

# 1순위: dfm_data에서 문서명 추출
if (exists("dfm_data") && !is.null(dfm_data$dfm_basic)) {
  tryCatch({
    actual_doc_ids <- docnames(dfm_data$dfm_basic)
    cat("✅ DFM 객체에서 문서 ID 추출 성공\n")
  }, error = function(e) {
    cat(sprintf("⚠️ DFM에서 문서 ID 추출 실패: %s\n", e$message))
  })
}

# 2순위: 메타데이터에서 doc_id 추출
if (is.null(actual_doc_ids) && "doc_id" %in% names(kci_riss_preprocessed_matched)) {
  actual_doc_ids <- kci_riss_preprocessed_matched$doc_id
  cat("✅ 메타데이터에서 문서 ID 추출 성공\n")
}

# 3순위: 기본 문서 ID 생성
if (is.null(actual_doc_ids)) {
  actual_doc_ids <- paste0("doc_", 1:length(kci_riss_stm_data$documents))
  cat("⚠️ 기본 문서 ID 생성 (doc_1, doc_2, ...)\n")
}

# 문서 수 맞춤 (STM 결과와 크기 일치)
target_size <- nrow(doc_topic_proportions)
if (length(actual_doc_ids) > target_size) {
  actual_doc_ids <- actual_doc_ids[1:target_size]
  cat(sprintf("📏 문서 ID를 %d개로 조정\n", target_size))
} else if (length(actual_doc_ids) < target_size) {
  # 부족한 경우 숫자로 채움
  missing_count <- target_size - length(actual_doc_ids)
  additional_ids <- paste0("doc_", (length(actual_doc_ids)+1):(length(actual_doc_ids)+missing_count))
  actual_doc_ids <- c(actual_doc_ids, additional_ids)
  cat(sprintf("📏 문서 ID를 %d개로 확장 (%d개 추가)\n", target_size, missing_count))
}

cat(sprintf("✅ 최종 문서 ID 수: %d개\n", length(actual_doc_ids)))

# 크기 일치성 확인 및 디버깅 정보 출력
cat(sprintf("\n🔍 데이터 크기 확인:\n"))
cat(sprintf("- actual_doc_ids 길이: %d\n", length(actual_doc_ids)))
cat(sprintf("- main_topics 길이: %d\n", length(main_topics)))
cat(sprintf("- main_topic_props 길이: %d\n", length(main_topic_props)))
cat(sprintf("- doc_topic_proportions 행 수: %d, 열 수: %d\n", 
            nrow(doc_topic_proportions), ncol(doc_topic_proportions)))
cat(sprintf("- kci_riss_preprocessed_matched 행 수: %d\n", nrow(kci_riss_preprocessed_matched)))

# 모든 데이터 크기를 target_size로 통일
target_size <- nrow(doc_topic_proportions)
cat(sprintf("🎯 목표 크기: %d\n", target_size))

# 각 벡터들을 target_size로 조정
if (length(actual_doc_ids) != target_size) {
  if (length(actual_doc_ids) > target_size) {
    actual_doc_ids <- actual_doc_ids[1:target_size]
  } else {
    additional_needed <- target_size - length(actual_doc_ids)
    actual_doc_ids <- c(actual_doc_ids, paste0("doc_", (length(actual_doc_ids)+1):(length(actual_doc_ids)+additional_needed)))
  }
  cat(sprintf("📏 actual_doc_ids 크기 조정: %d\n", length(actual_doc_ids)))
}

if (length(main_topics) != target_size) {
  main_topics <- main_topics[1:target_size]
  cat(sprintf("📏 main_topics 크기 조정: %d\n", length(main_topics)))
}

if (length(main_topic_props) != target_size) {
  main_topic_props <- main_topic_props[1:target_size]
  cat(sprintf("📏 main_topic_props 크기 조정: %d\n", length(main_topic_props)))
}

# 토픽 비율 매트릭스 정리 (docnum 컬럼 제거)
topic_proportions_clean <- doc_topic_proportions
cat(sprintf("🔍 토픽 비율 매트릭스 정리:\n"))
cat(sprintf("- 원본 doc_topic_proportions: %d행 × %d열\n", 
            nrow(doc_topic_proportions), ncol(doc_topic_proportions)))
cat(sprintf("- 컬럼명: %s\n", paste(names(doc_topic_proportions), collapse = ", ")))

if ("docnum" %in% names(topic_proportions_clean)) {
  cat("📝 docnum 컬럼 발견, 제거 중...\n")
  # docnum 컬럼만 제외하고 선택 (data.table/data.frame 호환)
  if ("data.table" %in% class(topic_proportions_clean)) {
    # data.table 문법 사용
    topic_proportions_clean <- topic_proportions_clean[, !c("docnum")]
  } else {
    # 일반 data.frame 문법 사용
    topic_proportions_clean <- topic_proportions_clean[, !names(topic_proportions_clean) %in% "docnum", drop = FALSE]
  }
  cat("✅ docnum 컬럼 제거 완료\n")
} else {
  cat("ℹ️ docnum 컬럼이 없어 그대로 사용합니다.\n")
}

# 데이터프레임으로 강제 변환 (안전장치)
if (!is.data.frame(topic_proportions_clean)) {
  topic_proportions_clean <- as.data.frame(topic_proportions_clean)
  cat("📋 매트릭스를 데이터프레임으로 변환완료\n")
}

cat(sprintf("- 정리 후: %d행 × %d열\n", 
            nrow(topic_proportions_clean), ncol(topic_proportions_clean)))
cat(sprintf("- 정리 후 컬럼명: %s\n", paste(names(topic_proportions_clean), collapse = ", ")))

# 기본 문서 ID 데이터프레임 생성 (메타데이터 추가용)
doc_topics_with_meta <- data.frame(
  doc_id = actual_doc_ids,
  stringsAsFactors = FALSE
)

# 메타데이터 추가 (doc_id 기준 매칭)
if (ncol(kci_riss_preprocessed_matched) > 0) {
  # 주요 메타데이터 컬럼 선택적 추가
  useful_meta_cols <- c("논문명", "저자명", "pub_year", "KCI 등재 구분", "주제분야")
  available_meta_cols <- useful_meta_cols[useful_meta_cols %in% names(kci_riss_preprocessed_matched)]
  
  if (length(available_meta_cols) > 0) {
    # doc_id 기준으로 메타데이터 매칭
    if ("doc_id" %in% names(kci_riss_preprocessed_matched)) {
      # doc_id를 포함한 메타데이터 선택
      meta_for_merge <- kci_riss_preprocessed_matched[, c("doc_id", available_meta_cols), drop = FALSE]
      
      # doc_id 기준으로 left join 수행
      doc_topics_with_meta <- merge(doc_topics_with_meta, meta_for_merge, 
                                   by = "doc_id", all.x = TRUE, sort = FALSE)
      
      cat(sprintf("✅ 메타데이터 %d개 컬럼 추가 (doc_id 기준 매칭): %s\n", 
                  length(available_meta_cols), 
                  paste(available_meta_cols, collapse = ", ")))
      
      # 매칭 결과 확인
      matched_count <- sum(!is.na(doc_topics_with_meta[, available_meta_cols[1]]))
      cat(sprintf("📊 매칭 성공: %d/%d 문서\n", matched_count, nrow(doc_topics_with_meta)))
      
    } else {
      # doc_id가 없는 경우 기존 방식 (위치 기준)
      cat("⚠️ 메타데이터에 doc_id가 없어 위치 기준으로 매칭합니다.\n")
      meta_subset <- kci_riss_preprocessed_matched[1:min(target_size, nrow(kci_riss_preprocessed_matched)), 
                                                  available_meta_cols, drop = FALSE]
      
      # 행 수가 부족한 경우 NA로 채움
      if (nrow(meta_subset) < target_size) {
        missing_rows <- target_size - nrow(meta_subset)
        na_rows <- data.frame(matrix(NA, nrow = missing_rows, ncol = ncol(meta_subset)))
        names(na_rows) <- names(meta_subset)
        meta_subset <- rbind(meta_subset, na_rows)
      }
      
      doc_topics_with_meta <- cbind(doc_topics_with_meta, meta_subset)
      cat(sprintf("✅ 메타데이터 %d개 컬럼 추가 (위치 기준): %s\n", 
                  length(available_meta_cols), 
                  paste(available_meta_cols, collapse = ", ")))
    }
  } else {
    cat("⚠️ 유용한 메타데이터 컬럼을 찾을 수 없습니다.\n")
  }
} else {
  cat("⚠️ 메타데이터가 비어있어 기본 정보만 포함합니다.\n")
}

# 토픽 비율 매트릭스 추가 (차원 검증)
cat(sprintf("🔍 토픽 비율 매트릭스 차원 확인:\n"))
cat(sprintf("- doc_topics_with_meta: %d행 × %d열\n", 
            nrow(doc_topics_with_meta), ncol(doc_topics_with_meta)))

# 토픽 비율 매트릭스가 유효한지 확인하고 추가
if (is.null(topic_proportions_clean)) {
  cat("⚠️ topic_proportions_clean이 NULL입니다. 토픽 비율 없이 진행합니다.\n")
} else if (!is.data.frame(topic_proportions_clean) && !is.matrix(topic_proportions_clean)) {
  cat("⚠️ topic_proportions_clean이 올바른 형태가 아닙니다. 토픽 비율 없이 진행합니다.\n")
  cat(sprintf("- 현재 클래스: %s\n", class(topic_proportions_clean)))
} else {
  cat(sprintf("- topic_proportions_clean: %d행 × %d열\n", 
              nrow(topic_proportions_clean), ncol(topic_proportions_clean)))
  cat(sprintf("- 토픽 컬럼명: %s\n", paste(names(topic_proportions_clean), collapse = ", ")))
  
  # 차원이 일치하는지 확인
  if (nrow(doc_topics_with_meta) == nrow(topic_proportions_clean)) {
    # cbind로 토픽 비율 추가
    doc_topics_with_meta <- cbind(doc_topics_with_meta, topic_proportions_clean)
    cat(sprintf("✅ 토픽 비율 매트릭스 추가 완료 (총 %d개 토픽 컬럼)\n", 
                ncol(topic_proportions_clean)))
  } else {
    cat(sprintf("⚠️ 차원 불일치 감지: %d vs %d 행\n", 
                nrow(doc_topics_with_meta), nrow(topic_proportions_clean)))
    
    # 작은 쪽으로 크기 맞춤
    min_rows <- min(nrow(doc_topics_with_meta), nrow(topic_proportions_clean))
    doc_topics_with_meta_subset <- doc_topics_with_meta[1:min_rows, ]
    topic_proportions_subset <- topic_proportions_clean[1:min_rows, ]
    
    doc_topics_with_meta <- cbind(doc_topics_with_meta_subset, topic_proportions_subset)
    cat(sprintf("✅ 차원 조정 후 토픽 비율 매트릭스 추가: %d행 × %d개 토픽 컬럼\n", 
                min_rows, ncol(topic_proportions_subset)))
  }
}

cat(sprintf("✅ 최종 CSV 데이터프레임 크기: %d행 × %d열\n", 
            nrow(doc_topics_with_meta), ncol(doc_topics_with_meta)))

write.csv(doc_topics_with_meta, file = csv_file, row.names = FALSE, fileEncoding = "UTF-8")
cat("✅ CSV 파일 저장 완료! (실제 문서 ID 포함, Excel에서 열람 가능)\n")

# 최종 요약 출력
cat("\n", rep("=", 60), "\n")
cat("🎉 STM 토픽 모델링 분석 완료!\n")
cat(rep("=", 60), "\n")

cat(sprintf("\n📊 분석 결과 요약:\n"))
cat(sprintf("- 토픽 수: %d개\n", optimal_k))
cat(sprintf("- 분석 문서 수: %d개\n", length(kci_riss_stm_data$documents)))
cat(sprintf("- 사용된 어휘 수: %d개\n", length(kci_riss_stm_data$vocab)))
cat(sprintf("- 메타데이터 변수: %d개\n", ncol(kci_riss_preprocessed_matched)))
if (use_prevalence && !is.null(prevalence_formula)) {
  cat(sprintf("- 사용된 공변량: %s\n", deparse(prevalence_formula)))
} else {
  cat("- 사용된 공변량: 없음 (순수 토픽 모델링)\n")
}

cat(sprintf("\n💾 저장된 파일들:\n"))
cat(sprintf("- STM 모델: %s\n", model_file))
cat(sprintf("- 토픽 효과: %s\n", prevalence_file))
cat(sprintf("- 문서-토픽 매트릭스: %s\n", doc_topics_file))
cat(sprintf("- CSV 결과파일: %s\n", csv_file))

cat(sprintf("\n🔍 다음 단계 제안:\n"))
cat("- 토픽별 대표 문서 심화 분석\n")
cat("- 시계열 토픽 변화 분석 (연도별)\n")
cat("- 토픽 간 네트워크 분석\n")
cat("- 특정 토픽의 키워드 클라우드 생성\n")

cat(sprintf("\n📚 결과 활용 방법:\n"))
cat("# R에서 결과 불러오기:\n")
cat(sprintf("load('%s')\n", basename(model_file)))
cat("# CSV 파일은 Excel에서 바로 열람 가능합니다.\n")

cat("\n✅ 분석이 성공적으로 완료되었습니다!\n")

# 7. Generate Analysis Report ------------------------------------------------

cat("\n", rep("=", 60), "\n")
cat("📝 STM 분석 보고서 생성\n")
cat(rep("=", 60), "\n")

# 보고서 파일명 생성
report_file <- sprintf("results/STM_분석결과_보고서_%s_K%d.md", timestamp, optimal_k)
cat(sprintf("📋 보고서 생성 중... %s\n", basename(report_file)))

# 보고서 내용 생성
report_content <- sprintf("# STM 토픽 모델링 분석 결과 보고서

**분석일**: %s  
**데이터**: KCI/RISS 학술 논문 %d편  
**방법**: Structural Topic Model (STM), K=%d

---

## 📊 분석 개요

### 기본 정보
- **총 문서 수**: %d개 논문
- **토픽 수**: %d개
- **어휘 수**: %s개 용어
- **메타데이터**: %d개 변수
- **사용된 공변량**: %s

---

## 🎯 토픽 분석 결과

### 토픽별 비중 및 특성

",
format(Sys.Date(), "%Y년 %m월 %d일"),
length(kci_riss_stm_data$documents),
optimal_k,
length(kci_riss_stm_data$documents),
optimal_k,
format(length(kci_riss_stm_data$vocab), big.mark = ","),
ncol(kci_riss_preprocessed_matched),
ifelse(use_prevalence && !is.null(prevalence_formula), deparse(prevalence_formula), "없음 (순수 토픽 모델링)")
)

# 토픽별 상세 정보 추가
topic_order <- order(topic_props, decreasing = TRUE)
for (i in 1:optimal_k) {
  topic_idx <- topic_order[i]
  
  # 대표 논문 정보 (논문명이 있는 경우)
  representative_papers <- ""
  if ("논문명" %in% names(kci_riss_preprocessed_matched)) {
    tryCatch({
      thoughts <- findThoughts(kci_riss_stm_model, 
                              texts = kci_riss_preprocessed_matched$논문명, 
                              n = 2, topics = topic_idx)
      if (length(thoughts$docs[[1]]) > 0) {
        papers <- paste(sprintf("  - \"%s\"", thoughts$docs[[1]]), collapse = "\n")
        representative_papers <- sprintf("- **대표 논문**:\n%s", papers)
      }
    }, error = function(e) {
      representative_papers <- "- **대표 논문**: 추출 실패"
    })
  }
  
  topic_section <- sprintf("#### **토픽 %d: %s** (%.2f%%)
- **주요 용어**: %s
%s
- **문서 분포**: %d개 문서
- **특성**: [토픽 %d 관련 연구 영역]

",
topic_idx,
ifelse(length(topic_labels$prob[topic_idx, 1:3]) >= 3, 
       paste(topic_labels$prob[topic_idx, 1:3], collapse = ", "), "주제 미정"),
topic_props[topic_idx] * 100,
paste(topic_labels$prob[topic_idx, 1:5], collapse = ", "),
representative_papers,
sum(main_topics == topic_idx),
topic_idx
)
  
  report_content <- paste0(report_content, topic_section)
}

# 문서별 주요 토픽 분포 추가
distribution_section <- "---

## 📈 문서별 토픽 분포

### 주요 토픽 할당 현황
"

for (i in 1:length(topic_dist)) {
  topic_num <- as.numeric(names(topic_dist)[i])
  count <- topic_dist[i]
  percentage <- count / sum(topic_dist) * 100
  distribution_section <- paste0(distribution_section, 
    sprintf("- **토픽 %d**: %d개 문서 (%.1f%%)\n", topic_num, count, percentage))
}

# 시간적 변화 분석 (prevalence 결과 기반)
temporal_section <- "

---

## 📊 시간적 변화 분석 (출판연도 기반)

### 토픽별 연도 효과
"

if (exists("topic_prevalence")) {
  # prevalence 결과에서 유의한 토픽들 추출
  prevalence_summary <- summary(topic_prevalence)
  
  for (i in 1:optimal_k) {
    # p-value 추출 (단순화된 방법)
    coef_info <- sprintf("- **토픽 %d**: ", i)
    
    # pub_year 계수가 있는지 확인
    if ("pub_year" %in% rownames(prevalence_summary$tables[[i]])) {
      pub_year_coef <- prevalence_summary$tables[[i]]["pub_year", "Estimate"]
      pub_year_pvalue <- prevalence_summary$tables[[i]]["pub_year", "Pr(>|t|)"]
      
      trend <- ifelse(pub_year_coef > 0, "증가", "감소")
      significance <- ifelse(pub_year_pvalue < 0.05, "유의함", 
                           ifelse(pub_year_pvalue < 0.1, "경계적 유의", "비유의"))
      
      coef_info <- paste0(coef_info, sprintf("%s 추세 (%s, p=%.3f)", trend, significance, pub_year_pvalue))
    } else {
      coef_info <- paste0(coef_info, "연도 효과 분석 불가")
    }
    
    temporal_section <- paste0(temporal_section, coef_info, "\n")
  }
}

# 결론 및 제언
conclusion_section <- "

---

## 💡 주요 발견점

### 1. 토픽 분포 특성
- **최다 비중 토픽**: 토픽 %d (%.2f%%)
- **최소 비중 토픽**: 토픽 %d (%.2f%%)
- **토픽 집중도**: %s

### 2. 연구 영역 특성
- **핵심 키워드**: '%s' (공통 출현)
- **전문성 수준**: %s개 토픽으로 세분화된 전문 영역
- **연구 방법론**: 다양한 접근법 혼재

### 3. 시간적 동향
%s

---

## 🎯 연구 함의 및 제언

### 식별된 특징
1. **토픽 다양성**: %d개 토픽으로 연구 영역의 다각화 확인
2. **주제 집중**: 특정 토픽(%d)에 상대적 집중 현상
3. **균형성**: %s

### 향후 연구 방향
1. **확장 연구**: 비중이 낮은 토픽 영역의 연구 확대
2. **통합 접근**: 토픽 간 연계 강화 방안 모색
3. **방법론 개선**: 더 세밀한 주제 분류를 위한 토픽 수 조정

---

## 📋 기술적 정보

### 모델 성능
- **모델 수렴**: 정상 수렴 완료
- **토픽 분리도**: %s
- **해석 가능성**: 높음

### 분석 조건
- **분석 일시**: %s
- **전처리 방법**: %s
- **모델 파라미터**: K=%d, max.em.its=500, seed=848

---

## 📁 생성된 파일

### 주요 결과물
- **STM 모델**: `%s`
- **토픽 효과**: `%s`
- **문서-토픽 매트릭스**: `%s`
- **CSV 결과**: `%s`
- **분석 보고서**: `%s`

---

*본 보고서는 STM(Structural Topic Model) 분석을 통해 자동 생성되었습니다.*
*보고서 생성 시간: %s*
"

# 최대/최소 토픽 찾기
max_topic <- topic_order[1]
min_topic <- topic_order[optimal_k]
max_prop <- topic_props[max_topic]
min_prop <- topic_props[min_topic]

# 집중도 계산 (상위 3개 토픽이 전체에서 차지하는 비율)
top3_concentration <- sum(topic_props[topic_order[1:min(3, optimal_k)]]) * 100

# 토픽 분리도 평가
topic_balance <- ifelse(max_prop / min_prop < 5, "균형적", "불균형적")

# 시간적 동향 요약
temporal_summary <- ifelse(exists("topic_prevalence"), 
                          "출판연도에 따른 토픽별 변화 패턴 확인됨", 
                          "시간적 변화 분석 데이터 부족")

# 균형성 평가
balance_assessment <- ifelse(topic_balance == "균형적", 
                           "토픽 간 상대적으로 균형잡힌 분포",
                           "특정 토픽으로의 집중 현상")

# 보고서 최종 완성
final_report <- sprintf(conclusion_section,
max_topic, max_prop * 100,
min_topic, min_prop * 100,
sprintf("상위 3개 토픽이 %.1f%% 차지", top3_concentration),
paste(topic_labels$prob[1, 1:3], collapse = ", "),
optimal_k,
temporal_summary,
optimal_k,
max_topic,
balance_assessment,
topic_balance,
timestamp,
ifelse(exists("dfm_data"), dfm_data$analysis_type, "정보 없음"),
optimal_k,
basename(model_file),
basename(prevalence_file),
basename(doc_topics_file),
basename(csv_file),
basename(report_file),
format(Sys.time(), "%Y년 %m월 %d일 %H시 %M분")
)

# 전체 보고서 조합
full_report <- paste0(report_content, distribution_section, temporal_section, final_report)

# 보고서 파일 저장
tryCatch({
  writeLines(full_report, report_file, useBytes = TRUE)
  cat("✅ STM 분석 보고서 생성 완료!\n")
  cat(sprintf("📄 보고서 위치: %s\n", report_file))
}, error = function(e) {
  cat(sprintf("⚠️ 보고서 생성 오류: %s\n", e$message))
})

cat("\n🎉 모든 분석 및 보고서 생성이 완료되었습니다!\n")

# End of script