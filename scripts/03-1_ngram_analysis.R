# 03-1_ngram_analysis.R
# N그램 분석 및 결과 파일 생성 (대화형)
# 기능: N그램 분석 결과를 사용자 검토용 CSV 파일로 저장
# 작성일: 2025-08-05

# ========== 패키지 설치 및 로드 ==========
required_packages <- c("dplyr", "tidyr", "stringr", "ggplot2", "wordcloud", "RColorBrewer")

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
# 프로젝트 루트 디렉토리로 이동 (scripts 폴더의 상위)
if (basename(getwd()) == "scripts") {
  setwd("..")
}
cat("작업 디렉토리:", getwd(), "\n")

# 그래프 한글 폰트 설정 (Windows)
if (Sys.info()["sysname"] == "Windows") {
  windowsFonts(malgun = windowsFont("맑은 고딕"))
  par(family = "malgun")
}

# 결과 저장 폴더 생성
if (!dir.exists("plots")) dir.create("plots", recursive = TRUE)
if (!dir.exists("reports")) dir.create("reports", recursive = TRUE)
if (!dir.exists("data/dictionaries/dict_candidates")) dir.create("data/dictionaries/dict_candidates", recursive = TRUE)

# ========== 사용자 입력 함수 ==========
get_numeric_input <- function(prompt, min_val = 1, max_val = Inf, default = NULL) {
  while (TRUE) {
    if (!is.null(default)) {
      full_prompt <- paste0(prompt, " (기본값: ", default, "): ")
    } else {
      full_prompt <- paste0(prompt, ": ")
    }
    
    input <- readline(full_prompt)
    
    if (input == "" && !is.null(default)) {
      return(default)
    }
    
    num <- suppressWarnings(as.numeric(input))
    
    if (is.na(num)) {
      cat("❌ 올바른 숫자를 입력해주세요.\n")
      next
    }
    
    if (num < min_val || num > max_val) {
      cat(sprintf("❌ %d와 %d 사이의 값을 입력해주세요.\n", min_val, max_val))
      next
    }
    
    return(as.integer(num))
  }
}

get_list_input <- function(prompt, min_val = 1, max_val = 10, default = NULL) {
  while (TRUE) {
    if (!is.null(default)) {
      default_str <- paste(default, collapse = ", ")
      full_prompt <- paste0(prompt, " (기본값: ", default_str, "): ")
    } else {
      full_prompt <- paste0(prompt, ": ")
    }
    
    input <- readline(full_prompt)
    
    if (input == "" && !is.null(default)) {
      return(default)
    }
    
    # 범위 입력 처리 (예: 2:5)
    if (grepl(":", input)) {
      range_parts <- unlist(strsplit(input, ":"))
      if (length(range_parts) == 2) {
        start_num <- suppressWarnings(as.numeric(trimws(range_parts[1])))
        end_num <- suppressWarnings(as.numeric(trimws(range_parts[2])))
        
        if (!is.na(start_num) && !is.na(end_num) && start_num <= end_num) {
          nums <- start_num:end_num
        } else {
          cat("❌ 범위 형식이 올바르지 않습니다. (예: 2:5)\n")
          next
        }
      }
    } else {
      # 기존 콤마 구분 처리
      items <- unlist(strsplit(input, "[,\\s]+"))
      items <- items[items != ""]
      
      if (length(items) == 0) {
        cat("❌ 최소 하나의 값을 입력해주세요.\n")
        next
      }
      
      nums <- suppressWarnings(as.numeric(items))
      
      if (any(is.na(nums))) {
        cat("❌ 모든 값이 올바른 숫자여야 합니다.\n")
        next
      }
    }
    
    if (any(nums < min_val) || any(nums > max_val)) {
      cat(sprintf("❌ 모든 값이 %d와 %d 사이여야 합니다.\n", min_val, max_val))
      next
    }
    
    return(sort(unique(as.integer(nums))))
  }
}

get_yes_no_input <- function(prompt, default = "y") {
  while (TRUE) {
    full_prompt <- paste0(prompt, " (y/n, 기본값: ", default, "): ")
    input <- tolower(trimws(readline(full_prompt)))
    
    if (input == "") {
      input <- default
    }
    
    if (input %in% c("y", "yes", "예", "네")) {
      return(TRUE)
    } else if (input %in% c("n", "no", "아니오", "아니요")) {
      return(FALSE)
    } else {
      cat("❌ 'y' 또는 'n'을 입력해주세요.\n")
    }
  }
}

# ========== 유틸리티 함수 ==========
is_korean <- function(text) {
  grepl("[가-힣ㄱ-ㅎㅏ-ㅣ]", text)
}

has_english <- function(text) {
  grepl("[a-zA-Z]", text)
}

has_numbers <- function(text) {
  grepl("[0-9]", text)
}

clean_text <- function(text) {
  text <- gsub("[^가-힣a-zA-Z0-9\\s]", "", text)
  text <- gsub("\\s+", " ", text)
  trimws(text)
}

# N그램 생성 함수
generate_ngrams <- function(word_list, n) {
  if (length(word_list) < n) {
    return(character(0))
  }
  
  ngrams <- c()
  for (i in 1:(length(word_list) - n + 1)) {
    ngram <- paste(word_list[i:(i + n - 1)], collapse = " ")
    ngrams <- c(ngrams, ngram)
  }
  
  return(ngrams)
}

# ========== 형태소 분석 결과 파일 선택 ==========
cat("\n", rep("=", 60), "\n")
cat("🔍 대화형 N그램 분석 - 사용자 사전 예비 자료 생성\n")
cat(rep("=", 60), "\n")

cat("\n1️⃣ 형태소 분석 결과 파일 검색 중...\n")

# 모든 명사 추출 결과 파일 검색
result_files <- list.files("data/processed/", pattern = "^mp_noun_extraction_.*\\.csv$", full.names = TRUE)

if (length(result_files) == 0) {
  cat("❌ 형태소 분석 결과 파일을 찾을 수 없습니다.\n")
  cat("먼저 02_kiwipiepy_morpheme_analysis.R 스크립트를 실행해주세요.\n")
  stop("형태소 분석 결과 파일이 없습니다.")
}

# 파일을 수정일자 내림차순으로 정렬
result_files <- result_files[order(file.mtime(result_files), decreasing = TRUE)]

# 사용자에게 파일 선택 요청
cat("분석할 데이터 파일을 선택해주세요:\n")
for (i in 1:length(result_files)) {
  file_info <- file.info(result_files[i])
  cat(sprintf("%2d: %s (수정일: %s, 크기: %.1f KB)\n", 
              i, basename(result_files[i]), 
              format(file_info$mtime, "%Y-%m-%d %H:%M"),
              file_info$size / 1024))
}

file_choice <- get_numeric_input(
  "분석할 파일 번호를 입력하세요",
  min_val = 1,
  max_val = length(result_files),
  default = 1
)

selected_file <- result_files[file_choice]
cat("선택된 파일:", basename(selected_file), "\n")


# ========== 원본 초록 데이터 불러오기 ==========
cat("\n2️⃣ 원본 초록 데이터 불러오기...\n")
combined_data_files <- list.files("data/processed/", pattern = "^dl_combined_data_.*\\.rds$", full.names = TRUE)

if (length(combined_data_files) == 0) {
  stop("dl_combined_data_*.rds 파일을 찾을 수 없습니다. 01_data_loading_and_analysis.R을 먼저 실행해주세요.")
}

# 가장 최신 파일 선택
latest_combined_data_file <- combined_data_files[order(file.mtime(combined_data_files), decreasing = TRUE)][1]
combined_data <- readRDS(latest_combined_data_file)
cat(sprintf("✅ 최신 데이터 파일 로드: %s\n", basename(latest_combined_data_file)))
cat(sprintf("전체 문서 수: %d\n", nrow(combined_data)))




# 초록 컬럼 찾기
abstract_patterns <- c("초록", "abstract", "요약", "summary", "Abstract")
abstract_column <- NULL
for (pattern in abstract_patterns) {
  matching_cols <- grep(pattern, names(combined_data), ignore.case = TRUE, value = TRUE)
  if (length(matching_cols) > 0) {
    for (col in matching_cols) {
      if (is.character(combined_data[[col]])) {
        abstract_column <- col
        break
      }
    }
    if (!is.null(abstract_column)) break
  }
}

# 명사 추출 결과 불러오기
noun_data <- read.csv(selected_file, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
cat("명사 추출 문서 수:", nrow(noun_data), "\n")

# 데이터 구조 확인
if (!"noun_extraction" %in% names(noun_data)) {
  cat("❌ 'noun_extraction' 컬럼을 찾을 수 없습니다.\n")
  stop("올바른 명사 추출 결과 파일이 필요합니다.")
}

# ========== 사용자 설정 입력 ==========
cat("\n", rep("=", 60), "\n")
cat("⚙️ 분석 설정\n")
cat(rep("=", 60), "\n")

# N그램 크기 설정
cat("\n🔢 N그램 크기 설정\n")
cat("분석하고 싶은 복합명사의 단어 수를 선택하세요.\n")
cat("예: 2 = 2단어 조합 (학습부진), 3 = 3단어 조합 (온라인교육플랫폼)\n")

NGRAM_SIZES <- get_list_input(
  "N그램 크기를 콤마로 구분하거나 범위로 입력하세요 (2-5)\n예: 2,3,4,5 또는 2:5",
  min_val = 2, 
  max_val = 5,
  default = c(2, 3)
)

cat("선택된 N그램 크기:", paste(NGRAM_SIZES, collapse = ", "), "\n")

# 최소 빈도 임계값 설정
cat("\n📊 빈도 임계값 설정\n")
MIN_FREQUENCY <- get_numeric_input(
  "결과 파일에 포함할 최소 출현 빈도 (1-10)",
  min_val = 1,
  max_val = 10,
  default = 1
)

cat("설정된 최소 빈도:", MIN_FREQUENCY, "회\n")

# 상위 결과 개수 설정
cat("\n🏆 결과 개수 설정\n")
MAX_RESULTS <- get_numeric_input(
  "각 N그램별 최대 결과 개수 (10-5000)",
  min_val = 10,
  max_val = 5000,
  default = 100
)

cat("설정된 최대 결과 개수:", MAX_RESULTS, "개\n")

# 시각화 옵션
cat("\n🎨 시각화 옵션\n")
GENERATE_PLOTS <- get_yes_no_input("빈도 그래프를 생성하시겠습니까?", "y")
GENERATE_WORDCLOUD <- get_yes_no_input("워드클라우드를 생성하시겠습니까?", "n")

# ========== 명사 데이터 전처리 ==========
cat("\n3️⃣ 명사 데이터 전처리 중...\n")

# 전체 명사를 하나의 벡터로 변환
all_nouns <- c()
doc_noun_lists <- list()

for (i in 1:nrow(noun_data)) {
  doc_id <- noun_data$doc_id[i]
  nouns <- unlist(strsplit(noun_data$noun_extraction[i], ", "))
  
  # 공백 제거 및 빈 문자열 제거
  nouns <- trimws(nouns)
  nouns <- nouns[nouns != "" & !is.na(nouns)]
  
  # 너무 짧은 명사 제거 (1글자)
  nouns <- nouns[nchar(nouns) > 1]
  
  all_nouns <- c(all_nouns, nouns)
  doc_noun_lists[[as.character(doc_id)]] <- nouns
}

cat("✅ 전처리 완료:\n")
cat("- 전체 명사 개수:", length(all_nouns), "\n")
cat("- 고유 명사 개수:", length(unique(all_nouns)), "\n")
cat("- 분석 문서 수:", length(doc_noun_lists), "\n")

# ========== N그램 분석 실행 ==========
cat("\n", rep("=", 60), "\n")
cat("🔬 N그램 분석 실행\n")
cat(rep("=", 60), "\n")

# 각 N그램 크기별로 분석
all_ngram_results <- list()

for (n in NGRAM_SIZES) {
  cat(sprintf("\n🔍 %d그램 분석 중...\n", n))
  
  # 전체 문서에서 N그램 생성
  all_ngrams <- c()
  
  for (doc_id in names(doc_noun_lists)) {
    doc_nouns <- doc_noun_lists[[doc_id]]
    doc_ngrams <- generate_ngrams(doc_nouns, n)
    all_ngrams <- c(all_ngrams, doc_ngrams)
  }
  
  if (length(all_ngrams) == 0) {
    cat(sprintf("⚠️ %d그램을 생성할 수 없습니다. (단어 수 부족)\n", n))
    next
  }
  
  # N그램 빈도 계산
  ngram_freq <- table(all_ngrams)
  ngram_freq_filtered <- ngram_freq[ngram_freq >= MIN_FREQUENCY]
  
  if (length(ngram_freq_filtered) == 0) {
    cat(sprintf("⚠️ 최소 빈도 %d 이상의 %d그램이 없습니다.\n", MIN_FREQUENCY, n))
    next
  }
  
  # 데이터프레임으로 변환
  ngram_df <- data.frame(
    ngram = names(ngram_freq_filtered),
    frequency = as.numeric(ngram_freq_filtered),
    ngram_size = n,
    pos_tag = "NNG",
    stringsAsFactors = FALSE
  )
  
  # 빈도순 정렬
  ngram_df <- ngram_df[order(-ngram_df$frequency), ]
  
  # 상위 결과만 유지
  if (nrow(ngram_df) > MAX_RESULTS) {
    ngram_df <- ngram_df[1:MAX_RESULTS, ]
  }
  
  cat(sprintf("✅ %d그램 분석 완료\n", n))
  cat(sprintf("- 전체 %d그램: %s개\n", n, format(length(all_ngrams), big.mark = ",")))
  cat(sprintf("- 고유 %d그램: %s개\n", n, format(length(ngram_freq), big.mark = ",")))
  cat(sprintf("- 빈도 %d+ %d그램: %s개\n", MIN_FREQUENCY, n, format(nrow(ngram_df), big.mark = ",")))
  
  # 상위 결과 미리보기
  preview_count <- min(10, nrow(ngram_df))
  top_results <- head(ngram_df, preview_count)
  cat("\n🏆 상위 ", preview_count, "개 ", n, "그램:\n", sep="")
  for (i in 1:nrow(top_results)) {
    cat(sprintf("%2d. %s (%s회)\n", i, top_results$ngram[i], 
                format(top_results$frequency[i], big.mark = ",")))
  }
  
  # 결과 저장
  all_ngram_results[[paste0(n, "gram")]] <- ngram_df
}

# ========== CSV 파일 생성 ==========
cat("\n", rep("=", 60), "\n")
cat("📝 N그램 결과 CSV 파일 생성\n")
cat(rep("=", 60), "\n")

date_suffix <- format(Sys.Date(), "%Y%m%d")
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

# 각 N그램별로 별도 파일 생성
for (n in NGRAM_SIZES) {
  ngram_key <- paste0(n, "gram")
  ngram_data <- all_ngram_results[[ngram_key]]
  
  if (!is.null(ngram_data) && is.data.frame(ngram_data) && nrow(ngram_data) > 0) {
    csv_file <- sprintf("data/dictionaries/dict_candidates/ng_%dgram_results_%s.csv", n, timestamp)
    write.csv(ngram_data, csv_file, row.names = FALSE, fileEncoding = "UTF-8")
    cat(sprintf("✅ %d그램 결과 파일: %s (%d개)\n", n, basename(csv_file), nrow(ngram_data)))
  } else {
    cat(sprintf("⚠️ %d그램 결과가 없어 파일을 생성하지 않습니다.\n", n))
  }
}

# 전체 결과 통합 파일 생성
all_combined <- data.frame(
  ngram = character(0),
  frequency = numeric(0),
  ngram_size = integer(0),
  pos_tag = character(0),
  stringsAsFactors = FALSE
)

for (ngram_data in all_ngram_results) {
  if (!is.null(ngram_data) && is.data.frame(ngram_data) && nrow(ngram_data) > 0) {
    all_combined <- rbind(all_combined, ngram_data)
  }
}

if (nrow(all_combined) > 0) {
  combined_csv_file <- sprintf("data/dictionaries/dict_candidates/ng_compound_nouns_candidates_%s.csv", timestamp)
  write.csv(all_combined, combined_csv_file, row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("✅ 복합명사 후보 파일: %s (%d개)\n", basename(combined_csv_file), nrow(all_combined)))
  
  # 검토용 파일 생성 (interactive_ngram_analysis.R 참조)
  cat("\n📋 복합명사 검토용 템플릿 생성 중...\n")
  
  # 복합명사 후보 필터링 조건
  MIN_DICT_NGRAM_SIZE <- 2      # 최소 2단어 이상
  MIN_DICT_FREQUENCY <- 1       # 최소 빈도 1로 낮춤
  MIN_WORD_LENGTH <- 1          # 각 단어는 1글자 이상
  MAX_TOTAL_LENGTH <- 20        # 전체 길이 20글자 이하
  
  cat("📊 필터링 조건:\n")
  cat(sprintf("- 최소 N그램 크기: %d단어 이상\n", MIN_DICT_NGRAM_SIZE))
  cat(sprintf("- 최소 빈도: %d회 이상\n", MIN_DICT_FREQUENCY))
  cat(sprintf("- 최소 단어 길이: %d글자 이상\n", MIN_WORD_LENGTH))
  cat(sprintf("- 최대 전체 길이: %d글자 이하\n", MAX_TOTAL_LENGTH))
  
  # 필터링 적용
  dict_candidates <- all_combined[
    all_combined$ngram_size >= MIN_DICT_NGRAM_SIZE &
    all_combined$frequency >= MIN_DICT_FREQUENCY &
    nchar(all_combined$ngram) <= MAX_TOTAL_LENGTH, ]
  
  # 각 단어 길이 검사
  word_length_check <- sapply(strsplit(dict_candidates$ngram, " "), function(words) {
    all(nchar(words) >= MIN_WORD_LENGTH)
  })
  dict_candidates <- dict_candidates[word_length_check, ]
  
  # 중복 제거 및 정렬
  dict_candidates <- dict_candidates[!duplicated(dict_candidates$ngram), ]
  dict_candidates <- dict_candidates[order(-dict_candidates$frequency, dict_candidates$ngram_size, dict_candidates$ngram), ]
  
  cat(sprintf("✅ 필터링 완료: %d개 → %d개 복합명사 후보\n", 
              nrow(all_combined), nrow(dict_candidates)))
  
  # 상위 10개 미리보기
  cat("\n📋 상위 10개 복합명사 후보 미리보기:\n")
  preview_dict <- head(dict_candidates, 10)
  for (i in 1:nrow(preview_dict)) {
    cat(sprintf("%2d. %s (%d회, %d단어)\n", 
                i, preview_dict$ngram[i], preview_dict$frequency[i], preview_dict$ngram_size[i]))
  }
}

# 빈 고유명사 템플릿 파일 생성
proper_template <- data.frame(
  noun = character(0),
  pos_tag = character(0),
  stringsAsFactors = FALSE
)

proper_csv_file <- sprintf("data/dictionaries/dict_candidates/ng_proper_nouns_candidates_%s.csv", timestamp)
write.csv(proper_template, proper_csv_file, row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("✅ 고유명사 후보 파일: %s (빈 템플릿)\n", basename(proper_csv_file)))

# ========== 시각화 생성 ==========
if (GENERATE_PLOTS && nrow(all_combined) > 0) {
  cat("\n📊 시각화 생성 중...\n")
  
  # 상위 20개 N그램 빈도 그래프
  plot_data <- head(all_combined, 20)
  
  p1 <- ggplot(plot_data, aes(x = reorder(ngram, frequency), y = frequency)) +
    geom_col(fill = "steelblue", alpha = 0.8) +
    coord_flip() +
    labs(
      title = "상위 20개 N그램 결과",
      subtitle = sprintf("최소 빈도: %d회 | N그램: %s", 
                        MIN_FREQUENCY, paste(NGRAM_SIZES, collapse = ", ")),
      x = "N그램",
      y = "빈도"
    ) +
    theme_minimal() +
    theme(
      text = element_text(family = "malgun", size = 12),
      plot.title = element_text(size = 14, face = "bold"),
      plot.subtitle = element_text(size = 11, color = "gray60")
    )
  
  ggsave(sprintf("reports/ng_ngram_results_%s.png", timestamp), p1, width = 12, height = 8, dpi = 300)
  cat("✅ N그램 결과 그래프 저장\n")
  
  # N그램 크기별 분포
  if (length(NGRAM_SIZES) > 1) {
    ngram_summary <- all_combined %>%
      group_by(ngram_size) %>%
      summarise(count = n(), .groups = "drop") %>%
      mutate(ngram_label = paste0(ngram_size, "그램"))
    
    p2 <- ggplot(ngram_summary, aes(x = reorder(ngram_label, ngram_size), y = count)) +
      geom_col(fill = "darkgreen", alpha = 0.8) +
      labs(
        title = "N그램 크기별 결과 개수",
        x = "N그램 크기",
        y = "개수"
      ) +
      theme_minimal() +
      theme(
        text = element_text(family = "malgun", size = 12),
        plot.title = element_text(size = 14, face = "bold")
      )
    
    ggsave(sprintf("reports/ng_ngram_size_distribution_%s.png", timestamp), p2, width = 8, height = 6, dpi = 300)
    cat("✅ N그램 크기별 분포 그래프 저장\n")
  }
}

# 워드클라우드 생성
if (GENERATE_WORDCLOUD && nrow(all_combined) > 0) {
  cat("\n☁️ 워드클라우드 생성 중...\n")
  
  png(sprintf("reports/ng_ngram_wordcloud_%s.png", timestamp), width = 800, height = 600)
  par(family = "malgun")
  
  tryCatch({
    wordcloud_data <- head(all_combined, 100)
    wordcloud(
      words = gsub(" ", "", wordcloud_data$ngram),
      freq = wordcloud_data$frequency,
      min.freq = MIN_FREQUENCY,
      max.words = 100,
      random.order = FALSE,
      rot.per = 0.35,
      colors = brewer.pal(8, "Dark2")
    )
    dev.off()
    cat("✅ 워드클라우드 저장\n")
  }, error = function(e) {
    dev.off()
    cat("⚠️ 워드클라우드 생성 실패:", e$message, "\n")
  })
}

# ========== 상세 보고서 생성 ==========
cat("\n📝 상세 보고서 생성 중...\n")

report_text <- paste0("# N그램 분석 결과 보고서\n\n",
  "**분석일**: ", Sys.Date(), "\n",
  "**분석 문서 수**: ", nrow(combined_data), "\n",
  "**형태소 분석 결과 파일**: ", basename(selected_file), "\n\n",
  
  "## 분석 설정\n",
  "- N그램 크기: ", paste(NGRAM_SIZES, collapse = ", "), "\n",
  "- 최소 빈도: ", MIN_FREQUENCY, "회\n",
  "- 최대 결과 수: ", MAX_RESULTS, "개\n\n",
  
  "## N그램 분석 결과\n\n"
)

# 각 N그램별 요약
for (n in NGRAM_SIZES) {
  ngram_data <- all_ngram_results[[paste0(n, "gram")]]
  report_text <- paste0(report_text, sprintf("### %d그램 결과\n", n))
  
  # ngram_data가 NULL이 아니고 데이터프레임인지 확인
  if (!is.null(ngram_data) && is.data.frame(ngram_data) && nrow(ngram_data) > 0) {
    report_text <- paste0(report_text, sprintf("- 총 개수: %d개\n", nrow(ngram_data)))
    
    top_10 <- head(ngram_data, 10)
    report_text <- paste0(report_text, "\n**상위 10개:**\n")
    for (i in 1:nrow(top_10)) {
      report_text <- paste0(report_text, 
                           sprintf("%d. %s (%d회)\n", 
                                  i, top_10$ngram[i], 
                                  top_10$frequency[i]))
    }
  } else {
    report_text <- paste0(report_text, "- 총 개수: 0개 (생성되지 않음)\n")
  }
  report_text <- paste0(report_text, "\n")
}

report_text <- paste0(report_text, "## 생성된 파일\n\n")
for (n in NGRAM_SIZES) {
  ngram_data <- all_ngram_results[[paste0(n, "gram")]]
  if (!is.null(ngram_data) && is.data.frame(ngram_data) && nrow(ngram_data) > 0) {
    report_text <- paste0(report_text, sprintf("- `ng_%dgram_results_%s.csv`: %d개\n", n, date_suffix, nrow(ngram_data)))
  }
}
if (nrow(all_combined) > 0) {
  report_text <- paste0(report_text, sprintf("- `ng_compound_nouns_candidates_%s.csv`: %d개 (복합명사 후보)\n", 
                                            date_suffix, nrow(all_combined)))
}
report_text <- paste0(report_text, sprintf("- `ng_proper_nouns_candidates_%s.csv`: 고유명사 후보 (빈 템플릿)\n", 
                                          date_suffix))

report_text <- paste0(report_text, "\n## 다음 단계\n\n")
report_text <- paste0(report_text, "1. Excel에서 생성된 CSV 파일을 열어 N그램 결과 검토\n")
report_text <- paste0(report_text, "2. 등록하지 않을 단어의 행을 삭제\n")
report_text <- paste0(report_text, "3. 고유명사 템플릿에 필요한 고유명사 직접 추가\n")
report_text <- paste0(report_text, "4. 03-1_register_user_dict_auto.R 실행하여 사전 등록\n")

# 보고서 저장
report_file <- sprintf("reports/ng_analysis_report_%s.md", timestamp)
writeLines(report_text, report_file)

# ========== 완료 메시지 ==========
cat("\n", rep("=", 60), "\n")
cat("🎉 N그램 분석 완료!\n")
cat(rep("=", 60), "\n")

cat("\n📁 생성된 파일:\n")

# 개별 N그램 파일
for (n in NGRAM_SIZES) {
  ngram_data <- all_ngram_results[[paste0(n, "gram")]]
  if (!is.null(ngram_data) && is.data.frame(ngram_data) && nrow(ngram_data) > 0) {
    cat(sprintf("- ng_%dgram_results_%s.csv (%d개)\n", n, timestamp, nrow(ngram_data)))
  }
}

# 통합 파일
if (nrow(all_combined) > 0) {
  cat(sprintf("- ng_compound_nouns_candidates_%s.csv (%d개 복합명사 후보)\n", timestamp, nrow(all_combined)))
}

# 고유명사 템플릿
cat(sprintf("- ng_proper_nouns_candidates_%s.csv (고유명사 후보 템플릿)\n", timestamp))

# 보고서
cat(sprintf("- %s\n", report_file))

if (GENERATE_PLOTS) {
  cat("\n📊 시각화 파일:\n")
  if (file.exists(sprintf("reports/ng_ngram_results_%s.png", timestamp)))
    cat(sprintf("- reports/ng_ngram_results_%s.png\n", timestamp))
  if (file.exists(sprintf("reports/ng_ngram_size_distribution_%s.png", timestamp)))
    cat(sprintf("- reports/ng_ngram_size_distribution_%s.png\n", timestamp))
}

if (GENERATE_WORDCLOUD && file.exists(sprintf("reports/ng_ngram_wordcloud_%s.png", timestamp))) {
  cat(sprintf("- reports/ng_ngram_wordcloud_%s.png\n", timestamp))
}

cat("\n🔄 다음 단계:\n")
cat("1. Excel에서 생성된 CSV 파일을 열어 N그램 결과 검토\n")
cat("2. 등록하지 않을 단어의 행을 삭제\n")
cat("3. 고유명사 템플릿에 필요한 고유명사 직접 추가\n")
cat("4. 03-1_register_user_dict_auto.R 실행하여 사전 등록\n")
cat("5. 등록된 사전으로 02_morpheme_analysis.R 다시 실행\n")

cat("\n✅ 대화형 N그램 분석이 완료되었습니다!\n")
