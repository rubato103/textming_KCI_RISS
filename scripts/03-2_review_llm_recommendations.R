# 03-2_review_llm_recommendations.R
# LLM 추천 복합명사를 CSV로 변환하여 사용자 검토용 파일 생성
# 기능: JSON 파일을 파싱하여 CSV로 저장, 사용자가 Excel에서 편집 후 03-3에서 사용
# 작성일: 2025-08-12

# ========== 패키지 로드 ==========
cat("\n", rep("=", 60), "\n")
cat("📋 LLM 추천 복합명사 검토용 CSV 생성\n")
cat(rep("=", 60), "\n")

library(jsonlite)
library(dplyr)
library(stringr)

# ========== 환경 설정 ==========
# 프로젝트 루트 디렉토리로 이동
if (basename(getwd()) == "scripts") {
  setwd("..")
}
cat("\n작업 디렉토리:", getwd(), "\n")

# 경로 설정
input_path <- "data/dictionaries/dict_candidates/"
output_path <- "data/dictionaries/dict_candidates"

# ========== JSON 파일 로드 ==========
cat("\n1️⃣ LLM 추천 JSON 파일 검색 중...\n")

# JSON 파일 검색
json_files <- list.files(input_path, 
                         pattern = "LLM_recommended_compound_noun.*\\.json$", 
                         full.names = TRUE)

if (length(json_files) == 0) {
  cat("❌ LLM 추천 복합명사 JSON 파일을 찾을 수 없습니다.\n")
  cat("LLM 분석 결과 JSON 파일을 먼저 data/dictionaries/dict_candidates/ 폴더에 넣어주세요.\n")
  stop("JSON 파일이 없습니다.")
}

# 파일을 수정일자 내림차순으로 정렬
json_files <- json_files[order(file.mtime(json_files), decreasing = TRUE)]

# 파일 목록 표시
cat("\n발견된 JSON 파일:\n")
for (i in seq_along(json_files)) {
  file_info <- file.info(json_files[i])
  cat(sprintf("%2d: %s (수정일: %s, 크기: %.1f KB)\n", 
              i, basename(json_files[i]), 
              format(file_info$mtime, "%Y-%m-%d %H:%M"),
              file_info$size/1024))
}

# 파일 선택 또는 병합
if (length(json_files) > 1) {
  cat("\n파일 처리 방식을 선택하세요:\n")
  cat("1. 단일 파일 선택\n")
  cat("2. 여러 파일 병합\n")
  cat("3. 모든 파일 병합\n")
  
  process_choice <- readline(prompt = "선택 (1-3, 기본값: 1): ")
  if (process_choice == "") process_choice <- "1"
  
  if (process_choice == "1") {
    # 단일 파일 선택
    cat("\n사용할 파일을 선택하세요:\n")
    for (i in seq_along(json_files)) {
      cat(sprintf("%2d: %s\n", i, basename(json_files[i])))
    }
    file_choice <- readline(prompt = sprintf("파일 번호 (1-%d, 기본값: 1): ", length(json_files)))
    if (file_choice == "") file_choice <- "1"
    selected_files <- json_files[as.numeric(file_choice)]
    
  } else if (process_choice == "2") {
    # 여러 파일 선택
    cat("\n병합할 파일들을 선택하세요 (콤마로 구분, 예: 1,2,3):\n")
    for (i in seq_along(json_files)) {
      cat(sprintf("%2d: %s\n", i, basename(json_files[i])))
    }
    file_choices <- readline(prompt = "파일 번호들: ")
    
    # 선택된 번호 파싱
    selected_indices <- as.numeric(unlist(strsplit(file_choices, ",")))
    selected_indices <- selected_indices[!is.na(selected_indices)]
    selected_indices <- selected_indices[selected_indices >= 1 & selected_indices <= length(json_files)]
    
    if (length(selected_indices) == 0) {
      cat("⚠️ 유효한 선택이 없어 첫 번째 파일을 사용합니다.\n")
      selected_files <- json_files[1]
    } else {
      selected_files <- json_files[selected_indices]
    }
    
  } else {
    # 모든 파일 병합
    selected_files <- json_files
  }
  
} else {
  selected_files <- json_files[1]
}

cat(sprintf("\n✅ 선택된 파일 수: %d개\n", length(selected_files)))
for (file in selected_files) {
  cat(sprintf("   - %s\n", basename(file)))
}

# ========== JSON 파싱 ==========
cat("\n2️⃣ JSON 데이터 파싱 중...\n")

# 여러 JSON 파일 읽기 및 병합
llm_data_list <- list()

for (i in seq_along(selected_files)) {
  file <- selected_files[i]
  cat(sprintf("  파일 %d/%d 읽는 중: %s\n", i, length(selected_files), basename(file)))
  
  tryCatch({
    json_content <- fromJSON(file, simplifyDataFrame = TRUE)
    llm_data_list[[i]] <- json_content
    cat(sprintf("    → %d개 항목 로드\n", nrow(json_content)))
  }, error = function(e) {
    cat(sprintf("    ❌ 파싱 오류: %s\n", e$message))
  })
}

# 데이터 병합
if (length(llm_data_list) == 0) {
  stop("JSON 파일을 읽을 수 없습니다.")
} else if (length(llm_data_list) == 1) {
  llm_data <- llm_data_list[[1]]
  cat(sprintf("\n✅ 총 %d개의 복합명사 후보를 로드했습니다.\n", nrow(llm_data)))
} else {
  # 여러 파일 병합 (dplyr 사용으로 row.names 문제 회피)
  llm_data <- bind_rows(llm_data_list)
  cat(sprintf("\n✅ %d개 파일에서 총 %d개의 복합명사 후보를 병합했습니다.\n", 
              length(llm_data_list), nrow(llm_data)))
  
  # 병합 후 중복 처리 (같은 추천명사가 여러 파일에 있을 경우)
  before_dedup <- nrow(llm_data)
  
  # 중복된 항목들의 빈도수를 합산하는 옵션
  cat("\n중복 항목 처리 방식을 선택하세요:\n")
  cat("1. 빈도수 합산 (추천)\n")
  cat("2. 최대 빈도수만 유지\n")
  cat("3. 평균 빈도수 사용\n")
  
  merge_choice <- readline(prompt = "선택 (1-3, 기본값: 1): ")
  if (merge_choice == "") merge_choice <- "1"
  
  if (merge_choice == "1") {
    # 빈도수 합산
    llm_data <- llm_data %>%
      group_by(추천명사) %>%
      summarise(
        빈도수 = sum(빈도수, na.rm = TRUE),
        추천근거 = list(first(추천근거)),  # list()로 래핑하여 구조 보존
        .groups = 'drop'
      ) %>%
      # 추천근거를 다시 단일 항목으로 변환
      mutate(추천근거 = lapply(추천근거, function(x) x[[1]]))
  } else if (merge_choice == "2") {
    # 최대 빈도수만 유지 (구조 손실 없음)
    llm_data <- llm_data %>%
      group_by(추천명사) %>%
      slice_max(빈도수, n = 1, with_ties = FALSE) %>%
      ungroup()
  } else {
    # 평균 빈도수
    llm_data <- llm_data %>%
      group_by(추천명사) %>%
      summarise(
        빈도수 = round(mean(빈도수, na.rm = TRUE)),
        추천근거 = list(first(추천근거)),  # list()로 래핑하여 구조 보존
        .groups = 'drop'
      ) %>%
      # 추천근거를 다시 단일 항목으로 변환
      mutate(추천근거 = lapply(추천근거, function(x) x[[1]]))
  }
  
  after_dedup <- nrow(llm_data)
  if (before_dedup > after_dedup) {
    cat(sprintf("  → 중복 제거: %d개 → %d개\n", before_dedup, after_dedup))
  }
}

# ========== 데이터 정리 및 변환 ==========
cat("\n3️⃣ 검토용 CSV 형식으로 변환 중...\n")

# 안전한 데이터 추출 함수
extract_safely <- function(row_data, field_name, max_length = NULL) {
  tryCatch({
    # 추천근거가 리스트인지 확인
    근거 <- row_data$추천근거
    
    # 다양한 데이터 구조에 대응
    value <- ""
    if (is.list(근거)) {
      if (!is.null(근거[[field_name]])) {
        value <- 근거[[field_name]]
      } else if (length(근거) > 0 && is.list(근거[[1]]) && !is.null(근거[[1]][[field_name]])) {
        value <- 근거[[1]][[field_name]]
      }
    }
    
    # 문자열이 아닌 경우 변환
    if (!is.character(value)) {
      value <- as.character(value)
    }
    
    # 길이 제한 적용
    if (!is.null(max_length) && nchar(value) > max_length) {
      value <- substr(value, 1, max_length)
    }
    
    return(value)
  }, error = function(e) {
    return("")  # 오류 시 빈 문자열 반환
  })
}

# 데이터프레임 변환 (robust 방식)
review_df <- data.frame(
  word = llm_data$추천명사,
  freq = llm_data$빈도수,
  context = sapply(1:nrow(llm_data), function(i) {
    context_raw <- extract_safely(llm_data[i, ], "맥락적_용례")
    
    # c() 구조나 배열이 텍스트로 들어온 경우 정리
    if (grepl("^c\\(", context_raw)) {
      # c("문장1", "문장2") 형태에서 첫 번째 문장만 추출
      clean_text <- gsub('^c\\("', '', context_raw)
      clean_text <- gsub('".*$', '', clean_text)
      context_raw <- clean_text
    }
    
    # 모든 맥락 데이터를 수록 (길이 제한 없음)
    return(context_raw)
  }),
  pos = "NNP",  # 기본값: 고유명사
  type = sapply(1:nrow(llm_data), function(i) {
    extract_safely(llm_data[i, ], "주제_영역")
  }),
  concept = sapply(1:nrow(llm_data), function(i) {
    extract_safely(llm_data[i, ], "개념적_핵심성", 100)
  }),
  trend = sapply(1:nrow(llm_data), function(i) {
    trend_text <- extract_safely(llm_data[i, ], "시계열적_동향")
    if (trend_text != "") {
      years <- str_extract_all(trend_text, "\\d{4}")[[1]]
      if (length(years) >= 2) {
        return(paste0(min(years), "-", max(years)))
      }
    }
    return("")
  }),
  stringsAsFactors = FALSE
)

# ========== 데이터 품질 검사 ==========
cat("\n4️⃣ 데이터 품질 검사 중...\n")

# 1. 형태소 분석 오류 확인 (단일 음절로 끝나는 경우)
truncated_words <- review_df %>%
  filter(str_detect(word, "\\s[가-힣]$"))

if (nrow(truncated_words) > 0) {
  cat(sprintf("⚠️  형태소 경계 오류 의심: %d개\n", nrow(truncated_words)))
  cat("   예시:", paste(head(truncated_words$word, 3), collapse = ", "), "\n")
  
  # (reviewed 열이 제거되어 이 부분도 제거)
}

# 2. 일반적 용어 확인
general_terms <- c("연구 결과", "연구 방법", "분석 결과", "통계 분석", 
                   "데이터 분석", "결론 및", "서론 및", "연구 목적",
                   "연구 대상", "연구 내용", "분석 방법")

general_found <- review_df %>%
  filter(word %in% general_terms)

if (nrow(general_found) > 0) {
  cat(sprintf("⚠️  일반적 용어 발견: %d개\n", nrow(general_found)))
  cat("   예시:", paste(head(general_found$word, 3), collapse = ", "), "\n")
  
  # (reviewed 열이 제거되어 이 부분도 제거)
}

# 3. 중복 제거
duplicates <- review_df %>%
  group_by(word) %>%
  filter(n() > 1) %>%
  ungroup()

if (nrow(duplicates) > 0) {
  cat(sprintf("⚠️  중복 항목 발견: %d개 → 제거 중...\n", nrow(duplicates)/2))
  
  # 빈도수가 높은 것만 유지
  review_df <- review_df %>%
    group_by(word) %>%
    slice_max(freq, n = 1, with_ties = FALSE) %>%
    ungroup()
}

# 4. 저빈도 항목 표시
low_freq <- sum(review_df$freq <= 2)
if (low_freq > 0) {
  cat(sprintf("⚠️  저빈도 항목 (≤2회): %d개\n", low_freq))
}

# ========== CSV 저장 ==========
cat("\n5️⃣ 검토용 CSV 파일 저장 중...\n")

# 타임스탬프 생성 (연월일_시간 형태)
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

# 파일명 생성
output_file <- file.path(output_path, sprintf("%s_llm_compound_nouns_candidates.csv", timestamp))

# 빈도수 내림차순 정렬
review_df <- review_df %>%
  arrange(desc(freq))

# CSV 저장
write.csv(review_df, output_file, row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("✅ CSV 파일 저장 완료: %s\n", basename(output_file)))

# ========== 결과 요약 ==========
cat("\n", rep("=", 60), "\n")
cat("📊 변환 결과 요약\n")
cat(rep("=", 60), "\n")

if (length(selected_files) > 1) {
  cat(sprintf("\n병합된 파일 수: %d개\n", length(selected_files)))
}
cat(sprintf("총 항목 수: %d개\n", nrow(review_df)))
cat(sprintf("평균 빈도수: %.1f\n", mean(review_df$freq)))
cat(sprintf("빈도수 범위: %d ~ %d\n", min(review_df$freq), max(review_df$freq)))

# 빈도 구간별 분포
freq_dist <- review_df %>%
  mutate(freq_range = case_when(
    freq >= 100 ~ "100회 이상",
    freq >= 50 ~ "50-99회",
    freq >= 20 ~ "20-49회",
    freq >= 10 ~ "10-19회",
    freq >= 5 ~ "5-9회",
    freq >= 3 ~ "3-4회",
    TRUE ~ "1-2회"
  )) %>%
  count(freq_range) %>%
  mutate(freq_range = factor(freq_range, 
                             levels = c("100회 이상", "50-99회", "20-49회", 
                                       "10-19회", "5-9회", "3-4회", "1-2회")))

cat("\n빈도수 분포:\n")
for (i in 1:nrow(freq_dist)) {
  cat(sprintf("  %s: %d개\n", freq_dist$freq_range[i], freq_dist$n[i]))
}

# 상위 10개 복합명사 표시
cat("\n상위 10개 복합명사:\n")
top_10 <- head(review_df, 10)
for (i in 1:nrow(top_10)) {
  cat(sprintf("  %2d. %s (빈도: %d)\n", i, top_10$word[i], top_10$freq[i]))
}

# ========== 사용 안내 ==========
cat("\n", rep("=", 60), "\n")
cat("💡 다음 단계 안내\n")
cat(rep("=", 60), "\n")

cat("\n1. 생성된 CSV 파일을 Excel에서 열어 검토하세요:\n")
cat(sprintf("   📁 %s\n", output_file))

cat("\n2. Excel에서 편집 방법:\n")
cat("   - 유지할 항목: 그대로 두기\n")
cat("   - 삭제할 항목: 행 전체를 삭제\n")
cat("   - pos 수정: NNP(고유명사), NNG(일반명사) 중 선택\n")
cat("   - word 수정: 복합명사 형태 수정 가능\n")
cat("   - context 확인: 맥락적 용례를 통해 의미 검토\n")

cat("\n3. 편집 완료 후:\n")
cat("   - 같은 파일명으로 저장 (UTF-8 인코딩 유지)\n")
cat("   - 03-3_create_user_dict.R 실행하여 사용자 사전 생성\n")

cat("\n4. 권장 검토 기준:\n")
cat("   - 빈도수 3회 이상\n")
cat("   - 도메인 특화 용어 우선\n")
cat("   - 형태소 경계 오류 수정\n")
cat("   - 일반적 용어 제외\n")

cat("\n✅ CSV 파일 생성이 완료되었습니다.\n")
cat("Excel에서 편집 후 03-3_create_user_dict.R을 실행하세요.\n\n")