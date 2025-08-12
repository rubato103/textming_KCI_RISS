# utils.R
# 데이터 처리를 위한 유틸리티 함수들
# 작성일: 2025-01-09

# ========== 데이터 표준화 함수 ==========

# 해시 기반 doc_id 생성 함수 (숫자 ID 생성)
generate_hash_id <- function(data) {
  # 식별용 컬럼명 패턴들 (우선순위 순)
  title_patterns <- c("제목", "논문제목", "제목명", "title", "Title")
  author_patterns <- c("저자", "저자명", "author", "Author", "작성자")
  institution_patterns <- c("발행기관", "소속기관", "기관명", "institution", "Institution", "발행처")
  
  current_cols <- names(data)
  
  # 각 패턴에 해당하는 컬럼 찾기
  title_col <- NULL
  author_col <- NULL
  institution_col <- NULL
  
  for (pattern in title_patterns) {
    if (pattern %in% current_cols) {
      title_col <- pattern
      break
    }
  }
  
  for (pattern in author_patterns) {
    if (pattern %in% current_cols) {
      author_col <- pattern
      break
    }
  }
  
  for (pattern in institution_patterns) {
    if (pattern %in% current_cols) {
      institution_col <- pattern
      break
    }
  }
  
  # 해시 생성을 위한 문자열 조합
  hash_strings <- character(nrow(data))
  
  for (i in 1:nrow(data)) {
    components <- c()
    
    # 제목 추가
    if (!is.null(title_col) && !is.na(data[[title_col]][i])) {
      components <- c(components, as.character(data[[title_col]][i]))
    }
    
    # 저자 추가
    if (!is.null(author_col) && !is.na(data[[author_col]][i])) {
      components <- c(components, as.character(data[[author_col]][i]))
    }
    
    # 발행기관 추가
    if (!is.null(institution_col) && !is.na(data[[institution_col]][i])) {
      components <- c(components, as.character(data[[institution_col]][i]))
    }
    
    # 만약 모든 컬럼이 없다면 행 번호 사용
    if (length(components) == 0) {
      components <- c(paste0("row_", i))
    }
    
    # 문자열 조합 및 정규화
    combined_string <- paste(components, collapse = "|")
    # 공백 제거 및 소문자 변환
    normalized_string <- gsub("\\s+", "", tolower(combined_string))
    
    hash_strings[i] <- normalized_string
  }
  
  # MD5 해시 생성 후 숫자로 변환
  if (!require("digest", quietly = TRUE)) {
    install.packages("digest", repos = "https://cran.seoul.go.kr/")
    library(digest)
  }
  
  # 해시 생성 후 16진수를 10진수로 변환하여 숫자 ID 생성
  numeric_ids <- sapply(hash_strings, function(x) {
    # MD5 해시의 앞 8자리를 16진수로 가져옴
    hex_part <- substr(digest(x, algo = "md5"), 1, 8)
    # 16진수를 10진수로 변환
    as.numeric(paste0("0x", hex_part))
  })
  
  # doc숫자 형식으로 변환 (8자리 숫자)
  doc_ids <- sprintf("doc%08d", numeric_ids %% 100000000)  # doc + 8자리 숫자
  
  # 중복 확인 및 처리
  if (any(duplicated(doc_ids))) {
    duplicated_indices <- which(duplicated(doc_ids))
    for (idx in duplicated_indices) {
      # 중복된 경우 행 번호를 뒤에 붙임
      doc_ids[idx] <- paste0(doc_ids[idx], "_", sprintf("%03d", idx))
    }
  }
  
  cat(sprintf("✅ 숫자 기반 doc_id 생성 완료: %d개\n", length(doc_ids)))
  cat(sprintf("   - 제목 컬럼: %s\n", ifelse(is.null(title_col), "없음", title_col)))
  cat(sprintf("   - 저자 컬럼: %s\n", ifelse(is.null(author_col), "없음", author_col)))
  cat(sprintf("   - 기관 컬럼: %s\n", ifelse(is.null(institution_col), "없음", institution_col)))
  
  return(doc_ids)
}

# ID 컬럼명을 doc_id로 통일하는 함수
standardize_id_column <- function(data) {
  # 가능한 ID 컬럼명 패턴들
  id_patterns <- c("논문 ID", "논문ID", "Article ID", "article_id", 
                   "ID", "id", "일련번호", "번호", "doc_id")
  
  # 현재 데이터의 컬럼명 확인
  current_cols <- names(data)
  
  # ID 컬럼 찾기
  id_col_found <- FALSE
  for (pattern in id_patterns) {
    if (pattern %in% current_cols && pattern != "doc_id") {
      # doc_id로 이름 변경
      names(data)[names(data) == pattern] <- "doc_id"
      cat(sprintf("✅ ID 컬럼 표준화: '%s' → 'doc_id'\n", pattern))
      id_col_found <- TRUE
      break
    } else if ("doc_id" %in% current_cols) {
      cat("✅ doc_id 컬럼이 이미 존재합니다.\n")
      id_col_found <- TRUE
      break
    }
  }
  
  if (!id_col_found) {
    cat("⚠️ ID 컬럼을 찾을 수 없습니다. 해시 기반 doc_id를 생성합니다.\n")
    data$doc_id <- generate_hash_id(data)
  } else {
    # doc_id를 문자형으로 변환
    data$doc_id <- as.character(data$doc_id)
    
    # 중복 확인 및 처리
    if (any(duplicated(data$doc_id))) {
      cat("⚠️ 기존 doc_id에 중복이 발견되었습니다. 해시 기반 doc_id로 재생성합니다.\n")
      data$doc_id <- generate_hash_id(data)
    }
  }
  
  return(data)
}

# 한글 초록 선별 및 텍스트 컬럼 표준화 함수
standardize_text_column <- function(data) {
  # 초록 관련 컬럼들을 모두 찾아서 한글 초록만 선별
  abstract_patterns <- c("국문 초록 (Abstract)", "국문초록", "국문 초록", "초록", 
                        "영문초록", "영문 초록", "Abstract", "abstract",
                        "다국어초록", "다국어 초록", "요약", "Summary")
  
  # 현재 데이터의 컬럼명 확인
  current_cols <- names(data)
  
  # 초록 관련 컬럼들을 모두 수집
  abstract_cols <- c()
  for (pattern in abstract_patterns) {
    if (pattern %in% current_cols && is.character(data[[pattern]])) {
      abstract_cols <- c(abstract_cols, pattern)
    }
  }
  
  cat(sprintf("🔍 초록 관련 컬럼 발견: %d개\n", length(abstract_cols)))
  for (col in abstract_cols) {
    cat(sprintf("   - %s\n", col))
  }
  
  # 한글 초록 선별 함수
  is_korean_text <- function(text_vector) {
    if (length(text_vector) == 0) return(FALSE)
    
    # NA가 아닌 텍스트들만 검사
    valid_texts <- text_vector[!is.na(text_vector) & nchar(text_vector) > 10]
    if (length(valid_texts) == 0) return(FALSE)
    
    # 샘플 텍스트들의 한글 비율 검사
    sample_size <- min(10, length(valid_texts))
    sample_texts <- sample(valid_texts, sample_size)
    
    korean_ratios <- sapply(sample_texts, function(text) {
      # 한글 문자 개수 / 전체 문자 개수
      korean_chars <- nchar(gsub("[^가-힣]", "", text))
      total_chars <- nchar(gsub("\\s", "", text))  # 공백 제외
      if (total_chars == 0) return(0)
      return(korean_chars / total_chars)
    })
    
    # 평균 한글 비율이 30% 이상이면 한글 텍스트로 판단
    avg_korean_ratio <- mean(korean_ratios, na.rm = TRUE)
    return(avg_korean_ratio >= 0.3)
  }
  
  # 각 초록 컬럼의 한글 비율 검사
  korean_abstract_col <- NULL
  best_score <- 0
  
  if (length(abstract_cols) > 0) {
    cat("\n🔍 한글 초록 검사 결과:\n")
    
    # 컬럼명 우선순위 설정 (한글 초록 관련 컬럼명에 보너스)
    get_priority_score <- function(col_name) {
      if (grepl("국문.*초록|국문초록", col_name)) return(3)
      if (grepl("^초록$", col_name)) return(2)
      if (grepl("요약", col_name)) return(1)
      return(0)  # 영문초록, Abstract 등은 보너스 없음
    }
    
    for (col in abstract_cols) {
      # 샘플 텍스트로 한글 비율 계산
      valid_texts <- data[[col]][!is.na(data[[col]]) & nchar(data[[col]]) > 10]
      
      if (length(valid_texts) > 0) {
        sample_size <- min(5, length(valid_texts))
        sample_texts <- sample(valid_texts, sample_size)
        
        korean_ratios <- sapply(sample_texts, function(text) {
          korean_chars <- nchar(gsub("[^가-힣]", "", text))
          total_chars <- nchar(gsub("\\s", "", text))
          if (total_chars == 0) return(0)
          return(korean_chars / total_chars)
        })
        
        avg_ratio <- mean(korean_ratios, na.rm = TRUE)
        avg_length <- mean(nchar(valid_texts), na.rm = TRUE)
        priority_bonus <- get_priority_score(col)
        
        # 종합 점수 계산: 한글비율(0.7) + 우선순위(0.2) + 길이점수(0.1)
        length_score <- min(avg_length / 200, 1)  # 200자 기준으로 정규화
        total_score <- avg_ratio * 0.7 + priority_bonus * 0.2 + length_score * 0.1
        
        status_text <- ""
        if (priority_bonus > 0) {
          status_text <- sprintf(" [우선순위: +%.1f]", priority_bonus)
        }
        if (avg_ratio >= 0.3 && avg_length >= 50) {
          status_text <- sprintf("%s ✓", status_text)
        }
        
        cat(sprintf("   - %s: 한글비율 %.1f%%, 평균길이 %.0f자, 점수 %.2f%s\n", 
                   col, avg_ratio * 100, avg_length, total_score, status_text))
        
        # 한글 비율이 30% 이상이고 적절한 길이인 경우만 후보로 고려
        if (avg_ratio >= 0.3 && avg_length >= 50 && total_score > best_score) {
          korean_abstract_col <- col
          best_score <- total_score
        }
      } else {
        cat(sprintf("   - %s: 유효한 텍스트 없음\n", col))
      }
    }
  }
  
  # 한글 초록 컬럼을 abstract로 설정
  if (!is.null(korean_abstract_col)) {
    if (korean_abstract_col != "abstract") {
      names(data)[names(data) == korean_abstract_col] <- "abstract"
    }
    cat(sprintf("✅ 한글 초록 선택: '%s' → 'abstract' (종합점수: %.2f)\n", 
               korean_abstract_col, best_score))
    
    # 다른 초록 컬럼들은 백업용으로 유지 (필요시 제거 가능)
    other_abstract_cols <- setdiff(abstract_cols, korean_abstract_col)
    if (length(other_abstract_cols) > 0) {
      cat(sprintf("ℹ️ 기타 초록 컬럼들은 유지됨: %s\n", paste(other_abstract_cols, collapse = ", ")))
    }
    
    return(data)
  }
  
  # 한글 초록을 찾지 못한 경우, 기존 로직으로 폴백
  cat("⚠️ 한글 초록을 찾을 수 없음. 일반 텍스트 컬럼 검색 중...\n")
  
  # 문자형 컬럼 중 가장 긴 텍스트를 가진 컬럼을 abstract로 가정
  # 단, doc_id는 제외
  char_cols <- names(data)[sapply(data, is.character)]
  char_cols <- char_cols[char_cols != "doc_id"]  # doc_id 제외
  
  if (length(char_cols) > 0) {
    max_length_col <- char_cols[1]
    max_length <- 0
    
    for (col in char_cols) {
      avg_length <- mean(nchar(data[[col]][!is.na(data[[col]])]), na.rm = TRUE)
      # 한글 비율도 고려
      if (is_korean_text(data[[col]]) && avg_length > max_length) {
        max_length_col <- col
        max_length <- avg_length
      }
    }
    
    if (max_length > 50) {  # 최소 50자 이상인 경우만
      if (max_length_col != "abstract") {
        names(data)[names(data) == max_length_col] <- "abstract"
      }
      cat(sprintf("✅ 텍스트 컬럼 추정: '%s' → 'abstract' (평균 길이: %.0f자)\n", 
                 max_length_col, max_length))
    } else {
      cat("⚠️ 적절한 한글 텍스트 컬럼을 찾을 수 없습니다.\n")
    }
  }
  
  return(data)
}

# 연도 컬럼명을 pub_year로 통일하는 함수
standardize_year_column <- function(data) {
  # 가능한 연도 컬럼명 패턴들
  year_patterns <- c("발행연도", "발행년도", "연도", "년도", "Year", "year", 
                   "출판연도", "출판년도", "Publication Year", "pub_year")
  
  # 현재 데이터의 컬럼명 확인
  current_cols <- names(data)
  
  # 연도 컬럼 찾기
  year_col_found <- FALSE
  for (pattern in year_patterns) {
    if (pattern %in% current_cols && pattern != "pub_year") {
      names(data)[names(data) == pattern] <- "pub_year"
      cat(sprintf("✅ 연도 컬럼 표준화: '%s' → 'pub_year'\n", pattern))
      year_col_found <- TRUE
      break
    } else if ("pub_year" %in% current_cols) {
      cat("✅ pub_year 컬럼이 이미 존재합니다.\n")
      year_col_found <- TRUE
      break
    }
  }
  
  # 연도 데이터 정제
  if (year_col_found && "pub_year" %in% names(data)) {
    if (is.character(data$pub_year) || is.factor(data$pub_year)) {
      # 4자리 연도 추출
      year_pattern <- "\\b(19|20)\\d{2}\\b"
      extracted_years <- regmatches(as.character(data$pub_year), 
                                   regexpr(year_pattern, as.character(data$pub_year)))
      data$pub_year <- as.numeric(extracted_years)
    } else {
      data$pub_year <- as.numeric(data$pub_year)
    }
  }
  
  return(data)
}

# 전체 데이터 표준화 함수
standardize_data <- function(data, verbose = TRUE) {
  if (verbose) {
    cat("\n========== 데이터 표준화 시작 ==========\n")
  }
  
  # ID 컬럼 표준화
  data <- standardize_id_column(data)
  
  # 텍스트 컬럼 표준화 (필요한 경우)
  if (any(grepl("초록|abstract|요약|본문", names(data), ignore.case = TRUE))) {
    data <- standardize_text_column(data)
  }
  
  # 연도 컬럼 표준화 (필요한 경우)
  if (any(grepl("연도|년도|year", names(data), ignore.case = TRUE))) {
    data <- standardize_year_column(data)
  }
  
  # doc_id를 첫 번째 컬럼으로 이동
  if ("doc_id" %in% names(data)) {
    other_cols <- setdiff(names(data), "doc_id")
    data <- data[, c("doc_id", other_cols)]
    cat("✅ doc_id를 첫 번째 컬럼으로 정렬\n")
  }
  
  if (verbose) {
    cat("========== 데이터 표준화 완료 ==========\n\n")
  }
  
  return(data)
}

# ========== 파일 관리 함수 ==========

# 최신 파일 찾기 함수
get_latest_file <- function(pattern, path = "data/processed", full.names = TRUE) {
  files <- list.files(path, pattern = pattern, full.names = full.names)
  
  if (length(files) == 0) {
    return(NULL)
  }
  
  # 수정 시간 기준 정렬
  files <- files[order(file.mtime(files), decreasing = TRUE)]
  
  return(files[1])
}

# 타임스탬프 생성 함수
get_timestamp <- function(format = "%Y%m%d_%H%M%S") {
  format(Sys.time(), format)
}

# 메타데이터와 함께 저장하는 함수
save_with_metadata <- function(data, prefix, path = "data/processed", 
                              metadata = NULL, format = "rds") {
  timestamp <- get_timestamp()
  
  # 저장할 객체 구성
  if (!is.null(metadata)) {
    save_object <- list(
      data = data,
      metadata = metadata,
      timestamp = timestamp,
      save_date = Sys.Date(),
      save_time = Sys.time()
    )
  } else {
    save_object <- data
  }
  
  # 파일명 생성
  filename <- file.path(path, sprintf("%s_%s.%s", prefix, timestamp, format))
  
  # 저장
  if (format == "rds") {
    saveRDS(save_object, filename)
  } else if (format == "csv") {
    write.csv(data, filename, row.names = FALSE, fileEncoding = "UTF-8")
  }
  
  cat(sprintf("✅ 파일 저장: %s\n", basename(filename)))
  
  return(filename)
}

# ========== 데이터 검증 함수 ==========

# doc_id 중복 확인
check_duplicate_ids <- function(data) {
  if (!"doc_id" %in% names(data)) {
    warning("doc_id 컬럼이 없습니다.")
    return(FALSE)
  }
  
  duplicated_ids <- data$doc_id[duplicated(data$doc_id)]
  
  if (length(duplicated_ids) > 0) {
    warning(sprintf("중복된 doc_id 발견: %d개", length(duplicated_ids)))
    return(FALSE)
  }
  
  return(TRUE)
}

# 필수 컬럼 확인
check_required_columns <- function(data, required_cols) {
  missing_cols <- setdiff(required_cols, names(data))
  
  if (length(missing_cols) > 0) {
    warning(sprintf("필수 컬럼 누락: %s", paste(missing_cols, collapse = ", ")))
    return(FALSE)
  }
  
  return(TRUE)
}

# 데이터 무결성 검증
validate_data <- function(data, check_type = "basic") {
  cat("\n========== 데이터 검증 ==========\n")
  
  validation_results <- list()
  
  # 기본 검증
  validation_results$has_rows <- nrow(data) > 0
  validation_results$has_columns <- ncol(data) > 0
  validation_results$has_doc_id <- "doc_id" %in% names(data)
  validation_results$no_duplicate_ids <- check_duplicate_ids(data)
  
  if (check_type == "morpheme") {
    # 형태소 분석 결과 검증
    required_cols <- c("doc_id", "noun_extraction")
    validation_results$has_required_cols <- check_required_columns(data, required_cols)
  } else if (check_type == "metadata") {
    # 메타데이터 검증
    required_cols <- c("doc_id")
    validation_results$has_required_cols <- check_required_columns(data, required_cols)
  }
  
  # 결과 출력
  all_valid <- all(unlist(validation_results))
  
  if (all_valid) {
    cat("✅ 모든 검증 통과\n")
  } else {
    cat("❌ 검증 실패 항목:\n")
    for (check in names(validation_results)) {
      if (!validation_results[[check]]) {
        cat(sprintf("  - %s\n", check))
      }
    }
  }
  
  cat("========== 검증 완료 ==========\n\n")
  
  return(all_valid)
}

# ========== 디버깅 도구 ==========

# 데이터 구조 요약
summarize_data_structure <- function(data) {
  cat("\n========== 데이터 구조 요약 ==========\n")
  cat(sprintf("행 수: %d\n", nrow(data)))
  cat(sprintf("열 수: %d\n", ncol(data)))
  cat("\n컬럼 정보:\n")
  
  for (i in 1:ncol(data)) {
    col_name <- names(data)[i]
    col_type <- class(data[[col_name]])[1]
    na_count <- sum(is.na(data[[col_name]]))
    na_percent <- round(na_count / nrow(data) * 100, 1)
    
    cat(sprintf("  %2d. %-30s [%s] - 결측: %d (%.1f%%)\n", 
                i, col_name, col_type, na_count, na_percent))
  }
  
  cat("========================================\n\n")
}

cat("✅ utils.R 로드 완료\n")
cat("사용 가능한 함수:\n")
cat("  - standardize_data(): 데이터 표준화\n")
cat("  - get_latest_file(): 최신 파일 찾기\n")
cat("  - save_with_metadata(): 메타데이터와 함께 저장\n")
cat("  - validate_data(): 데이터 검증\n")
cat("  - summarize_data_structure(): 데이터 구조 요약\n\n")
