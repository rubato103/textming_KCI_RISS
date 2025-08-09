# utils.R
# 데이터 처리를 위한 유틸리티 함수들
# 작성일: 2025-01-09

# ========== 데이터 표준화 함수 ==========

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
    warning("⚠️ ID 컬럼을 찾을 수 없습니다. 첫 번째 컬럼을 doc_id로 가정합니다.")
    names(data)[1] <- "doc_id"
  }
  
  # doc_id를 문자형으로 변환
  data$doc_id <- as.character(data$doc_id)
  
  return(data)
}

# 초록/텍스트 컬럼명을 abstract로 통일하는 함수
standardize_text_column <- function(data) {
  # 가능한 텍스트 컬럼명 패턴들
  text_patterns <- c("초록", "Abstract", "abstract", "요약", "Summary", 
                   "본문", "내용", "텍스트", "text")
  
  # 현재 데이터의 컬럼명 확인
  current_cols <- names(data)
  
  # 텍스트 컬럼 찾기
  text_col_found <- FALSE
  for (pattern in text_patterns) {
    if (pattern %in% current_cols && pattern != "abstract") {
      # 문자형 컬럼인지 확인
      if (is.character(data[[pattern]])) {
        names(data)[names(data) == pattern] <- "abstract"
        cat(sprintf("✅ 텍스트 컬럼 표준화: '%s' → 'abstract'\n", pattern))
        text_col_found <- TRUE
        break
      }
    } else if ("abstract" %in% current_cols) {
      cat("✅ abstract 컬럼이 이미 존재합니다.\n")
      text_col_found <- TRUE
      break
    }
  }
  
  if (!text_col_found) {
    # 문자형 컬럼 중 가장 긴 텍스트를 가진 컬럼을 abstract로 가정
    char_cols <- names(data)[sapply(data, is.character)]
    if (length(char_cols) > 0) {
      max_length_col <- char_cols[1]
      max_length <- 0
      for (col in char_cols) {
        avg_length <- mean(nchar(data[[col]][!is.na(data[[col]])]), na.rm = TRUE)
        if (avg_length > max_length) {
          max_length_col <- col
        }
      }
      if (max_length_col != "abstract") {
        names(data)[names(data) == max_length_col] <- "abstract"
        cat(sprintf("✅ 텍스트 컬럼 추정: '%s' → 'abstract'\n", max_length_col))
      }
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
      year_pattern <- "\b(19|20)\d{2}\b"
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
