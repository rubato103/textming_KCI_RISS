# 05_quanteda_dtm_creation.R
# quanteda를 사용한 메타데이터 보존 DTM 생성

# ========== 패키지 로드 ==========
required_packages <- c("quanteda", "dplyr", "readr", "ggplot2", "wordcloud", "wordcloud2", "RColorBrewer", "htmlwidgets")

cat("필요한 패키지 확인 중...\n")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    cat(paste("패키지", pkg, "설치 중...\n"))
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}
cat("✅ 모든 패키지 로드 완료\n")

# ========== 환경 설정 ==========
# 프로젝트 루트 디렉토리로 이동
if (basename(getwd()) == "scripts") {
  setwd("..")
}

# 사용자 입력 함수 로드
source("scripts/00_interactive_utils.R")

# 결과 저장 폴더 생성
if (!dir.exists("plots")) dir.create("plots", recursive = TRUE)

# ========== 데이터 로드 ==========
cat("\n", rep("=", 60), "\n")
cat("📊 quanteda DTM 생성 (메타데이터 보존)\n")
cat(rep("=", 60), "\n\n")

# 1. 명사 추출 결과 파일 선택
noun_extraction_files <- list.files("data/processed/", 
                                   pattern = "noun_extraction.*\\.csv$", 
                                   full.names = TRUE)

if (length(noun_extraction_files) == 0) {
  stop("noun_extraction 파일을 찾을 수 없습니다. 02_kiwipiepy_morpheme_analysis.R을 먼저 실행해주세요.")
}

cat("사용 가능한 명사 추출 파일:\n")
for (i in seq_along(noun_extraction_files)) {
  file_info <- file.info(noun_extraction_files[i])
  cat(sprintf("%d. %s (%.1f KB, %s)\n", 
              i, basename(noun_extraction_files[i]), 
              file_info$size/1024,
              format(file_info$mtime, "%Y-%m-%d %H:%M")))
}

file_choice <- get_numeric_input(
  sprintf("분석할 파일 번호를 입력하세요 (1-%d)", length(noun_extraction_files)),
  default = 1,
  validation_fn = function(x) {
    if (x >= 1 && x <= length(noun_extraction_files)) {
      list(valid = TRUE, value = x, message = "")
    } else {
      list(valid = FALSE, value = x, message = sprintf("1부터 %d까지의 숫자를 입력해주세요.", length(noun_extraction_files)))
    }
  }
)

selected_noun_file <- noun_extraction_files[file_choice]
cat("✅ 선택된 명사 추출 파일:", basename(selected_noun_file), "\n")

# 2. 원본 데이터 파일 찾기
combined_data_files <- list.files("data/processed/", 
                                 pattern = "combined_data.*\\.rds$", 
                                 full.names = TRUE)

if (length(combined_data_files) == 0) {
  stop("combined_data 파일을 찾을 수 없습니다. 01_data_loading_and_analysis.R을 먼저 실행해주세요.")
}

# 가장 최신 원본 데이터 파일 자동 선택
latest_combined_file <- combined_data_files[order(file.mtime(combined_data_files), decreasing = TRUE)][1]
cat("✅ 원본 메타데이터 파일:", basename(latest_combined_file), "\n\n")

# ========== 데이터 읽기 ==========
cat("📁 데이터 로딩 중...\n")

# 명사 추출 결과 로드
noun_data <- read.csv(selected_noun_file, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
cat(sprintf("- 명사 추출 문서 수: %d\n", nrow(noun_data)))

# 원본 메타데이터 로드
original_data <- readRDS(latest_combined_file)
cat(sprintf("- 원본 데이터 문서 수: %d\n", nrow(original_data)))

# ========== 데이터 결합 및 검증 ==========
cat("\n🔗 데이터 결합 중...\n")

# 명사 추출 데이터에서 doc_id 열 확인
noun_id_cols <- names(noun_data)[grepl("id|ID", names(noun_data), ignore.case = TRUE)]
if (length(noun_id_cols) == 0) {
  stop("명사 추출 데이터에서 ID 컬럼을 찾을 수 없습니다.")
}

cat("명사 추출 데이터의 ID 컬럼:\n")
for (i in seq_along(noun_id_cols)) {
  sample_vals <- head(noun_data[[noun_id_cols[i]]], 3)
  cat(sprintf("%d. %s (예시: %s)\n", i, noun_id_cols[i], paste(sample_vals, collapse = ", ")))
}

noun_id_choice <- get_numeric_input(
  sprintf("명사 추출 데이터의 문서 ID 컬럼을 선택하세요 (1-%d)", length(noun_id_cols)),
  default = 1,
  validation_fn = function(x) {
    if (x >= 1 && x <= length(noun_id_cols)) {
      list(valid = TRUE, value = x, message = "")
    } else {
      list(valid = FALSE, value = x, message = sprintf("1부터 %d까지의 숫자를 입력해주세요.", length(noun_id_cols)))
    }
  }
)

selected_noun_id_col <- noun_id_cols[noun_id_choice]

# 원본 데이터에서 대응되는 ID 열 확인
original_id_cols <- names(original_data)[grepl("id|ID", names(original_data), ignore.case = TRUE)]
if (length(original_id_cols) == 0) {
  stop("원본 데이터에서 ID 컬럼을 찾을 수 없습니다.")
}

cat("\n원본 데이터의 ID 컬럼:\n")
for (i in seq_along(original_id_cols)) {
  sample_vals <- head(original_data[[original_id_cols[i]]], 3)
  cat(sprintf("%d. %s (예시: %s)\n", i, original_id_cols[i], paste(sample_vals, collapse = ", ")))
}

original_id_choice <- get_numeric_input(
  sprintf("원본 데이터의 문서 ID 컬럼을 선택하세요 (1-%d)", length(original_id_cols)),
  default = 1,
  validation_fn = function(x) {
    if (x >= 1 && x <= length(original_id_cols)) {
      list(valid = TRUE, value = x, message = "")
    } else {
      list(valid = FALSE, value = x, message = sprintf("1부터 %d까지의 숫자를 입력해주세요.", length(original_id_cols)))
    }
  }
)

selected_original_id_col <- original_id_cols[original_id_choice]

# 선택된 ID 컬럼으로 데이터 결합
cat(sprintf("\n✅ 결합 설정: %s (명사) ↔ %s (원본)\n", selected_noun_id_col, selected_original_id_col))

# 임시로 컬럼명을 통일하여 병합
noun_temp <- noun_data
original_temp <- original_data
names(noun_temp)[names(noun_temp) == selected_noun_id_col] <- "merge_id"
names(original_temp)[names(original_temp) == selected_original_id_col] <- "merge_id"

# 데이터 결합
combined_df <- merge(noun_temp, original_temp, by = "merge_id", all.x = TRUE, suffixes = c("", "_orig"))

# 병합 후 doc_id 컬럼 설정 (quanteda용)
combined_df$doc_id <- combined_df$merge_id
cat("✅ 데이터 결합 완료\n")

cat(sprintf("- 결합된 데이터 행 수: %d\n", nrow(combined_df)))
cat(sprintf("- 결합된 데이터 열 수: %d\n", ncol(combined_df)))

# NA 값 확인
missing_nouns <- sum(is.na(combined_df$noun_extraction))
if (missing_nouns > 0) {
  cat(sprintf("⚠️ 명사 추출 결과가 없는 문서: %d개\n", missing_nouns))
  combined_df <- combined_df[!is.na(combined_df$noun_extraction), ]
  cat(sprintf("✅ 유효한 문서 수: %d개\n", nrow(combined_df)))
}

# ========== 복합어 정규화 ==========
cat("\n🔧 복합어 정규화 적용 중...\n")

normalize_compounds <- function(text) {
  mappings <- list(
    "비자살적 자해" = "비자살적자해",
    "로지스틱 회귀" = "로지스틱회귀",
    "매개 효과" = "매개효과",
    "정서 조절" = "정서조절",
    "정신 건강" = "정신건강",
    "청소년 자해" = "청소년자해",
    "자해 행동" = "자해행동",
    "설문 조사" = "설문조사",
    "실태 조사" = "실태조사"
  )
  
  for (pattern in names(mappings)) {
    replacement <- mappings[[pattern]]
    text <- gsub(pattern, replacement, text, fixed = TRUE)
  }
  return(text)
}

combined_df$noun_extraction_normalized <- sapply(combined_df$noun_extraction, normalize_compounds)

# ========== quanteda Corpus 생성 ==========
cat("\n📚 quanteda Corpus 생성 중...\n")

# 메타데이터 컬럼 식별
text_col <- "noun_extraction_normalized"
id_col <- "doc_id"

# 텍스트 데이터와 메타데이터 분리
text_data <- combined_df[[text_col]]
meta_data <- combined_df[, !names(combined_df) %in% c(text_col, "noun_extraction")]

# quanteda corpus 생성 (메타데이터를 document variables로 추가)
corpus_obj <- corpus(text_data, 
                    docnames = combined_df[[id_col]])

# 메타데이터를 document variables로 추가
docvars(corpus_obj) <- meta_data

cat("✅ Corpus 생성 완료\n")
cat(sprintf("- 문서 수: %d\n", ndoc(corpus_obj)))
cat(sprintf("- 메타데이터 변수 수: %d\n", ncol(meta_data)))

# 메타데이터 변수 목록 표시
cat("\n📋 보존된 메타데이터 변수:\n")
meta_vars <- names(meta_data)
for (i in seq_along(meta_vars)) {
  # 각 변수의 샘플 값 표시 (최대 3개)
  sample_vals <- unique(meta_data[[meta_vars[i]]])[1:min(3, length(unique(meta_data[[meta_vars[i]]])))]
  sample_str <- paste(sample_vals, collapse = ", ")
  if (nchar(sample_str) > 50) {
    sample_str <- paste(substr(sample_str, 1, 47), "...")
  }
  cat(sprintf("  %2d. %-20s: %s\n", i, meta_vars[i], sample_str))
}

# ========== 토큰화 설정 ==========
cat("\n", rep("=", 60), "\n")
cat("⚙️ 토큰화 설정\n")
cat(rep("=", 60), "\n")

# 토큰화 방식 선택
cat("\n🔤 토큰화 방식:\n")
cat("1. 쉼표 분리 (기본) - 형태소 분석 결과를 쉼표로 분리\n")
cat("2. 공백 분리 - 공백으로 토큰화\n")

tokenize_method <- get_numeric_input(
  "토큰화 방식을 선택하세요 (1-2, 기본: 1)",
  default = 1,
  validation_fn = function(x) {
    if (x >= 1 && x <= 2) {
      list(valid = TRUE, value = x, message = "")
    } else {
      list(valid = FALSE, value = x, message = "1 또는 2를 입력해주세요.")
    }
  }
)

# 최소 토큰 길이
min_length <- get_numeric_input(
  "최소 토큰 길이 (1-5, 기본: 2)",
  default = 2,
  validation_fn = function(x) {
    if (x >= 1 && x <= 5) {
      list(valid = TRUE, value = x, message = "")
    } else {
      list(valid = FALSE, value = x, message = "1부터 5까지의 숫자를 입력해주세요.")
    }
  }
)

# ========== 토큰화 실행 ==========
cat(sprintf("\n🔨 토큰화 실행 중... (방식: %s, 최소 길이: %d)\n", 
            ifelse(tokenize_method == 1, "쉼표 분리", "공백 분리"), min_length))

if (tokenize_method == 1) {
  # 쉼표로 분리된 명사들을 직접 토큰화 (quanteda의 기본 분리 사용)
  tokens_obj <- tokens(corpus_obj, 
                      what = "word",  # 기본 토큰화
                      remove_punct = TRUE,  # 구두점 제거 (쉼표 포함)
                      remove_symbols = TRUE,
                      remove_numbers = FALSE) %>%
    tokens_select(min_nchar = min_length) %>%
    tokens_remove(c("", " "))  # 빈 토큰 제거
} else {
  # 일반적인 공백 토큰화
  tokens_obj <- tokens(corpus_obj, 
                      what = "word",
                      remove_punct = TRUE,
                      remove_symbols = TRUE,
                      remove_numbers = FALSE) %>%
    tokens_select(min_nchar = min_length)
}

cat("✅ 토큰화 완료\n")
cat(sprintf("- 평균 문서당 토큰 수: %.1f\n", mean(ntoken(tokens_obj))))

# ========== DFM 생성 및 희소성 관리 ==========
cat("\n", rep("=", 60), "\n")
cat("🎯 DFM (Document-Feature Matrix) 생성 및 희소성 관리\n")
cat(rep("=", 60), "\n")

# 1단계: 기본 DFM 생성 (필터링 없음)
cat("\n📊 1단계: 기본 DFM 생성 중...\n")
dfm_original <- dfm(tokens_obj)

cat("✅ 기본 DFM 생성 완료\n")
cat(sprintf("- 문서 수: %s\n", format(ndoc(dfm_original), big.mark = ",")))
cat(sprintf("- 피처(용어) 수: %s\n", format(nfeat(dfm_original), big.mark = ",")))
cat(sprintf("- 총 토큰 수: %s\n", format(sum(dfm_original), big.mark = ",")))
# quanteda의 sparsity() 함수 사용
original_sparsity <- sparsity(dfm_original) * 100
cat(sprintf("- 희소성: %.2f%%\n", original_sparsity))

# 2단계: 희소성 관리 설정
cat("\n", rep("=", 40), "\n")
cat("⚙️ 희소성 관리 설정\n")
cat(rep("=", 40), "\n")

cat("\n📋 희소성 관리 옵션:\n")
cat("- 최소 용어 빈도: 전체 코퍼스에서 용어가 나타나야 할 최소 횟수\n")
cat("- 최소 문서 빈도: 용어가 나타나야 할 최소 문서 수\n")

# 최소 용어 빈도 설정
min_termfreq <- get_numeric_input(
  sprintf("\n최소 용어 빈도 (1-%d, 기본: 2)", floor(sum(dfm_original)/1000)),
  default = 2,
  validation_fn = function(x) {
    if (x >= 1 && x <= floor(sum(dfm_original)/100)) {
      list(valid = TRUE, value = x, message = "")
    } else {
      list(valid = FALSE, value = x, message = sprintf("1부터 %d까지의 숫자를 입력해주세요.", floor(sum(dfm_original)/100)))
    }
  }
)

# 최소 문서 빈도 설정
min_docfreq <- get_numeric_input(
  sprintf("최소 문서 빈도 (1-%d, 기본: 1)", floor(nrow(combined_df)/10)),
  default = 1,
  validation_fn = function(x) {
    if (x >= 1 && x <= floor(nrow(combined_df)/2)) {
      list(valid = TRUE, value = x, message = "")
    } else {
      list(valid = FALSE, value = x, message = sprintf("1부터 %d까지의 숫자를 입력해주세요.", floor(nrow(combined_df)/2)))
    }
  }
)

# 최대 문서 빈도는 전체 문서 수로 설정 (제한 없음)
max_docfreq <- nrow(combined_df)

cat("\n✅ 희소성 관리 설정 완료:\n")
cat(sprintf("- 최소 용어 빈도: %d회\n", min_termfreq))
cat(sprintf("- 최소 문서 빈도: %d개 문서\n", min_docfreq))
cat("- 최대 문서 빈도: 제한 없음 (모든 용어 포함)\n")

# 3단계: DFM 필터링 적용
cat(sprintf("\n🔨 3단계: DFM 필터링 적용 중...\n"))
dfm_filtered <- dfm_trim(dfm_original,
                        min_termfreq = min_termfreq,
                        min_docfreq = min_docfreq, 
                        max_docfreq = max_docfreq,
                        termfreq_type = "count",
                        docfreq_type = "count")

# 4단계: 희소성 변화 분석
cat("\n", rep("=", 50), "\n")
cat("📈 희소성 변화 분석\n")
cat(rep("=", 50), "\n")

# 원본 DFM 통계
original_docs <- ndoc(dfm_original)
original_features <- nfeat(dfm_original)
original_nonzero <- sum(dfm_original > 0)  # 비영값 셀 수
original_total_cells <- original_docs * original_features
original_sparsity_calc <- 100 * (1 - original_nonzero / original_total_cells)

# 필터링된 DFM 통계
filtered_docs <- ndoc(dfm_filtered)
filtered_features <- nfeat(dfm_filtered)
filtered_nonzero <- sum(dfm_filtered > 0)  # 비영값 셀 수
filtered_total_cells <- filtered_docs * filtered_features
filtered_sparsity_calc <- 100 * (1 - filtered_nonzero / filtered_total_cells)

# 비교 결과 출력
cat("\n📊 DFM 비교 결과:\n")
cat(sprintf("%-25s %15s %15s %15s\n", "구분", "필터링 전", "필터링 후", "변화"))
cat(sprintf("%-25s %15s %15s %15s\n", paste(rep("-", 25), collapse=""), paste(rep("-", 15), collapse=""), paste(rep("-", 15), collapse=""), paste(rep("-", 15), collapse="")))
cat(sprintf("%-25s %15s %15s %15s\n", 
            "문서 수", 
            format(original_docs, big.mark = ","),
            format(filtered_docs, big.mark = ","),
            ifelse(original_docs == filtered_docs, "동일", sprintf("%+d", filtered_docs - original_docs))))

cat(sprintf("%-25s %15s %15s %15s\n", 
            "피처(용어) 수", 
            format(original_features, big.mark = ","),
            format(filtered_features, big.mark = ","),
            sprintf("%+d (%.1f%%)", filtered_features - original_features,
                   100 * (filtered_features - original_features) / original_features)))

cat(sprintf("%-25s %15s %15s %15s\n", 
            "비영값 셀 수", 
            format(original_nonzero, big.mark = ","),
            format(filtered_nonzero, big.mark = ","),
            sprintf("%+d (%.1f%%)", filtered_nonzero - original_nonzero,
                   100 * (filtered_nonzero - original_nonzero) / original_nonzero)))

cat(sprintf("%-25s %15s %15s %15s\n", 
            "총 셀 수", 
            format(original_total_cells, big.mark = ","),
            format(filtered_total_cells, big.mark = ","),
            sprintf("%+d (%.1f%%)", filtered_total_cells - original_total_cells,
                   100 * (filtered_total_cells - original_total_cells) / original_total_cells)))

cat(sprintf("%-25s %15.2f%% %14.2f%% %14.2f%%p\n", 
            "희소성", 
            original_sparsity_calc,
            filtered_sparsity_calc,
            filtered_sparsity_calc - original_sparsity_calc))

# 희소성 개선 효과 설명
sparsity_improvement <- original_sparsity_calc - filtered_sparsity_calc
if (sparsity_improvement > 0) {
  cat(sprintf("\n✅ 희소성 개선: %.2f%%p 감소 (더 조밀한 행렬)\n", sparsity_improvement))
} else if (sparsity_improvement < 0) {
  cat(sprintf("\n⚠️ 희소성 증가: %.2f%%p 증가 (더 희소한 행렬)\n", abs(sparsity_improvement)))
} else {
  cat("\n➡️ 희소성 변화 없음\n")
}

# 메모리 사용량 추정
original_memory_mb <- (original_nonzero * 8) / (1024 * 1024)  # 8바이트 per double
filtered_memory_mb <- (filtered_nonzero * 8) / (1024 * 1024)
memory_saved_mb <- original_memory_mb - filtered_memory_mb

cat(sprintf("\n💾 추정 메모리 사용량:\n"))
cat(sprintf("- 필터링 전: %.1f MB\n", original_memory_mb))
cat(sprintf("- 필터링 후: %.1f MB\n", filtered_memory_mb))
cat(sprintf("- 절약된 메모리: %.1f MB (%.1f%%)\n", 
            memory_saved_mb, 100 * memory_saved_mb / original_memory_mb))

# 최종 DFM 할당
dfm_obj <- dfm_filtered
cat(sprintf("\n✅ 최종 DFM 준비 완료 (피처 수: %s개)\n", format(nfeat(dfm_obj), big.mark = ",")))

# ========== TF-IDF 가중치 적용 여부 ==========
cat("\n", rep("=", 60), "\n")
cat("⚖️ TF-IDF 가중치 적용\n")
cat(rep("=", 60), "\n")

cat("\n📋 분석 옵션:\n")
cat("1. 기본 빈도 (Term Frequency): 단순 출현 빈도\n")
cat("2. TF-IDF 가중치: 문서별 중요도를 반영한 가중치\n")
cat("   - TF-IDF는 흔한 용어의 가중치를 낮추고 특정 문서에 집중된 용어의 가중치를 높임\n")

apply_tfidf <- get_yes_no_input("\nTF-IDF 가중치를 적용하시겠습니까?", FALSE)

if (apply_tfidf) {
  cat("\n🔨 TF-IDF 가중치 적용 중...\n")
  dfm_tfidf <- dfm_tfidf(dfm_obj)
  cat("✅ TF-IDF 가중치 적용 완료\n")
  
  # 분석용 DFM 설정
  analysis_dfm <- dfm_tfidf
  analysis_type <- "TF-IDF"
} else {
  cat("✅ 기본 빈도 분석을 사용합니다.\n")
  analysis_dfm <- dfm_obj
  analysis_type <- "기본 빈도"
}

# ========== DFM 분석 ==========
cat("\n", rep("=", 60), "\n")
cat(sprintf("📈 DFM 분석 (%s)\n", analysis_type))
cat(rep("=", 60), "\n")

# 상위 용어 표시 개수 설정
top_n <- get_numeric_input(
  "\n상위 몇 개 용어를 표시할까요? (10-100, 기본: 30)",
  default = 30,
  validation_fn = function(x) {
    if (x >= 10 && x <= 100) {
      list(valid = TRUE, value = x, message = "")
    } else {
      list(valid = FALSE, value = x, message = "10부터 100까지의 숫자를 입력해주세요.")
    }
  }
)

# ========== 1. 기본 빈도 분석 ==========
cat(sprintf("\n📊 1. 기본 빈도 분석 (상위 %d개):\n", top_n))
cat(rep("-", 60), "\n")

# 기본 용어 빈도 계산
term_freq_matrix <- colSums(dfm_obj)
term_freq <- data.frame(
  feature = names(term_freq_matrix),
  frequency = as.numeric(term_freq_matrix),
  docfreq = colSums(dfm_obj > 0),  # 문서 빈도
  stringsAsFactors = FALSE
)
term_freq <- term_freq[order(-term_freq$frequency), ]  # 빈도순 정렬
top_terms_freq <- head(term_freq, top_n)

for (i in 1:nrow(top_terms_freq)) {
  cat(sprintf("%3d. %-20s: %5s회 (문서 %d개)\n", 
              i, top_terms_freq$feature[i], 
              format(top_terms_freq$frequency[i], big.mark = ","),
              top_terms_freq$docfreq[i]))
}

# ========== 2. TF-IDF 분석 (항상 계산) ==========
cat(sprintf("\n📊 2. TF-IDF 가중치 분석 (상위 %d개):\n", top_n))
cat(rep("-", 60), "\n")

# TF-IDF 항상 계산 (사용자 선택과 무관)
dfm_tfidf_calc <- dfm_tfidf(dfm_obj)
tfidf_scores <- colSums(dfm_tfidf_calc)
tfidf_freq <- data.frame(
  feature = names(tfidf_scores),
  tfidf_score = as.numeric(tfidf_scores),
  frequency = as.numeric(term_freq_matrix[names(tfidf_scores)]),
  docfreq = colSums(dfm_obj[, names(tfidf_scores)] > 0),
  stringsAsFactors = FALSE
)
tfidf_freq <- tfidf_freq[order(-tfidf_freq$tfidf_score), ]  # TF-IDF 점수순 정렬
top_terms_tfidf <- head(tfidf_freq, top_n)

for (i in 1:nrow(top_terms_tfidf)) {
  cat(sprintf("%3d. %-20s: %6.3f (빈도 %s회, 문서 %d개)\n", 
              i, top_terms_tfidf$feature[i], 
              top_terms_tfidf$tfidf_score[i],
              format(top_terms_tfidf$frequency[i], big.mark = ","),
              top_terms_tfidf$docfreq[i]))
}

# 워드클라우드는 빈도와 TF-IDF 모두 생성하므로 viz_data 설정 제거

# ========== 메타데이터 기반 분석 건너뛰기 ==========
# 메타데이터 분석 섹션 제거

# ========== 시각화 ==========
cat("\n", rep("=", 60), "\n")
cat("🎨 시각화\n")
cat(rep("=", 60), "\n")

generate_viz <- get_yes_no_input("시각화를 생성하시겠습니까?", TRUE)

if (generate_viz) {
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # 워드클라우드 생성
  wordcloud_choice <- get_yes_no_input("워드클라우드를 생성하시겠습니까?", TRUE)
  
  if (wordcloud_choice) {
    max_words <- get_numeric_input(
      "워드클라우드 최대 단어 수 (50-300, 기본: 150)",
      default = 150,
      validation_fn = function(x) {
        if (x >= 50 && x <= min(300, nrow(term_freq))) {
          list(valid = TRUE, value = x, message = "")
        } else {
          list(valid = FALSE, value = x, message = sprintf("50부터 %d까지의 숫자를 입력해주세요.", min(300, nrow(term_freq))))
        }
      }
    )
    
    cat("\n☁️ 워드클라우드 생성 중...\n")
    
    # === 1. 기본 빈도 워드클라우드 (wordcloud2) ===
    freq_wordcloud_file <- file.path("plots", sprintf("%s_quanteda_frequency_wordcloud.html", timestamp))
    
    freq_top_words <- head(term_freq, max_words)
    freq_data <- data.frame(
      word = freq_top_words$feature,
      freq = freq_top_words$frequency,
      stringsAsFactors = FALSE
    )
    
    tryCatch({
      freq_wc <- wordcloud2(freq_data, 
                           size = 0.8, 
                           color = 'random-dark',
                           backgroundColor = "white",
                           fontFamily = "맑은 고딕",
                           rotateRatio = 0.3)
      
      saveWidget(freq_wc, freq_wordcloud_file, selfcontained = TRUE)
      cat(sprintf("✅ 기본 빈도 워드클라우드 저장: %s\n", freq_wordcloud_file))
    }, error = function(e) {
      cat(sprintf("⚠️ 기본 빈도 워드클라우드 생성 실패: %s\n", e$message))
    })
    
    # === 2. TF-IDF 워드클라우드 (wordcloud2) ===
    tfidf_wordcloud_file <- file.path("plots", sprintf("%s_quanteda_tfidf_wordcloud.html", timestamp))
    
    tfidf_top_words <- head(tfidf_freq, max_words)
    
    # TF-IDF 점수를 워드클라우드에 적합한 크기로 스케일링
    tfidf_values <- tfidf_top_words$tfidf_score
    # 최소값이 0 이하이면 양수로 변환
    if (min(tfidf_values) <= 0) {
      tfidf_values <- tfidf_values + abs(min(tfidf_values)) + 0.1
    }
    # 적절한 크기로 스케일링
    tfidf_values <- round(tfidf_values * 1000)
    
    tfidf_data <- data.frame(
      word = tfidf_top_words$feature,
      freq = tfidf_values,
      stringsAsFactors = FALSE
    )
    
    tryCatch({
      tfidf_wc <- wordcloud2(tfidf_data, 
                            size = 0.8, 
                            color = 'random-light',
                            backgroundColor = "black",
                            fontFamily = "맑은 고딕",
                            rotateRatio = 0.3)
      
      saveWidget(tfidf_wc, tfidf_wordcloud_file, selfcontained = TRUE)
      cat(sprintf("✅ TF-IDF 워드클라우드 저장: %s\n", tfidf_wordcloud_file))
    }, error = function(e) {
      cat(sprintf("⚠️ TF-IDF 워드클라우드 생성 실패: %s\n", e$message))
    })
    
    # === 3. 백업용 기본 워드클라우드 (PNG) ===
    backup_wordcloud_file <- file.path("plots", sprintf("%s_quanteda_backup_wordcloud.png", timestamp))
    
    tryCatch({
      png(filename = backup_wordcloud_file, width = 1200, height = 800, res = 100)
      set.seed(1234)
      
      wordcloud(words = freq_top_words$feature,
               freq = freq_top_words$frequency,
               min.freq = 1,
               random.order = FALSE,
               rot.per = 0.35,
               colors = brewer.pal(8, "Dark2"),
               scale = c(4, 0.5),
               family = "맑은 고딕")
      
      title(main = sprintf("상위 %d개 용어 (기본 빈도)", max_words), 
            cex.main = 1.5, font.main = 2)
      
      dev.off()
      cat(sprintf("✅ 백업용 PNG 워드클라우드 저장: %s\n", backup_wordcloud_file))
    }, error = function(e) {
      cat(sprintf("⚠️ 백업용 워드클라우드 생성 실패: %s\n", e$message))
    })
    
  }
}

# ========== 결과 저장 ==========
cat("\n", rep("=", 60), "\n")
cat("💾 결과 저장\n")
cat(rep("=", 60), "\n")

# 파일명 생성
dfm_filename <- sprintf("data/processed/%s_quanteda_dfm.rds", timestamp)
freq_filename <- sprintf("data/processed/%s_quanteda_frequencies.csv", timestamp)
meta_filename <- sprintf("data/processed/%s_quanteda_metadata.csv", timestamp)

# DFM 저장 (메타데이터 포함) - 기본 빈도, TF-IDF, STM 호환성 모두 저장
cat("\n🔄 STM 호환 형식 변환 중...\n")

# STM 호환 형식으로 변환
stm_conversion <- quanteda::convert(dfm_obj, to = "stm")

dfm_list <- list(
  dfm_basic = dfm_obj,
  dfm_tfidf = dfm_tfidf_calc,  # TF-IDF는 항상 저장
  analysis_type = analysis_type,
  tfidf_applied = apply_tfidf,  # 사용자 선택 기록
  
  # STM 직접 사용 가능한 데이터
  stm_documents = stm_conversion$documents,
  stm_vocab = stm_conversion$vocab,
  stm_meta = as.data.frame(docvars(dfm_obj)),  # STM이 요구하는 data.frame 형식
  
  # STM 연계를 위한 추가 정보
  preprocessing_params = list(
    min_termfreq = min_termfreq,
    min_docfreq = min_docfreq,
    max_docfreq = max_docfreq,
    tokenize_method = tokenize_method,
    min_token_length = min_length
  ),
  corpus_info = list(
    original_docs = ndoc(dfm_original),
    filtered_docs = ndoc(dfm_obj),
    original_features = nfeat(dfm_original),
    filtered_features = nfeat(dfm_obj),
    sparsity_original = sparsity(dfm_original),
    sparsity_filtered = sparsity(dfm_obj)
  ),
  timestamp = timestamp
)

cat(sprintf("- STM 문서 수: %d\n", length(stm_conversion$documents)))
cat(sprintf("- STM 어휘 수: %d\n", length(stm_conversion$vocab)))
cat(sprintf("- STM 메타데이터 변수: %d개\n", ncol(as.data.frame(docvars(dfm_obj)))))
saveRDS(dfm_list, file = dfm_filename)
cat(sprintf("✅ DFM 저장 (STM 호환): %s\n", dfm_filename))

# 용어 빈도 저장 (기본 빈도 + TF-IDF 항상 결합)
combined_freq <- merge(term_freq, tfidf_freq[, c("feature", "tfidf_score")], by = "feature", all.x = TRUE)
write.csv(combined_freq, file = freq_filename, row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("✅ 용어 빈도 저장 (기본빈도+TF-IDF): %s\n", freq_filename))

# 메타데이터 저장
meta_with_docnames <- cbind(docname = docnames(dfm_obj), meta_data)
write.csv(meta_with_docnames, file = meta_filename, row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("✅ 메타데이터 저장: %s\n", meta_filename))

# ========== 완료 및 요약 ==========
cat("\n", rep("=", 60), "\n")
cat("✅ quanteda DTM 생성 완료!\n")
cat(rep("=", 60), "\n")

cat("\n📋 최종 요약:\n")
cat(sprintf("- 분석 방법: %s\n", analysis_type))
cat(sprintf("- 분석 문서 수: %s\n", format(ndoc(dfm_obj), big.mark = ",")))
cat(sprintf("- 고유 피처 수: %s\n", format(nfeat(dfm_obj), big.mark = ",")))
cat(sprintf("- 총 토큰 수: %s\n", format(sum(term_freq$frequency), big.mark = ",")))
cat(sprintf("- 보존된 메타데이터 변수: %d개\n", ncol(meta_data)))
cat(sprintf("- 평균 문서당 토큰 수: %.1f\n", mean(rowSums(dfm_obj))))

cat(sprintf("- 가장 빈번한 용어 (빈도): %s (%s회)\n", 
            term_freq$feature[1], format(term_freq$frequency[1], big.mark = ",")))
cat(sprintf("- 가장 중요한 용어 (TF-IDF): %s (%.3f)\n", 
            tfidf_freq$feature[1], tfidf_freq$tfidf_score[1]))

# 메타데이터 활용 팁
if (ncol(meta_data) > 0) {
  cat("\n💡 메타데이터 활용 팁:\n")
  cat("- dfm_subset() 함수로 특정 조건의 문서만 필터링 가능\n")
  cat("- textstat_frequency() 함수로 그룹별 용어 빈도 분석 가능\n")
  cat("- textstat_keyness() 함수로 그룹 간 특징 용어 추출 가능\n")
}