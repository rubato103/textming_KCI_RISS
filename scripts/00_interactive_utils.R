# interactive_utils.R
# 대화형/비대화형 모드 지원을 위한 유틸리티 함수
# 작성일: 2025-01-09

# ========== 모드 감지 ==========

# 실행 모드 감지 함수
detect_execution_mode <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  
  # 명령줄 인자가 있거나 비대화형 세션이면 자동 모드
  if (length(args) > 0 || !interactive()) {
    return("auto")
  } else {
    return("interactive")
  }
}

# 글로벌 실행 모드 설정
EXECUTION_MODE <- detect_execution_mode()

# ========== 명령줄 인자 파싱 ==========

# 명령줄 인자 파싱 함수
parse_arguments <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  parsed_args <- list()
  
  if (length(args) == 0) {
    return(parsed_args)
  }
  
  for (arg in args) {
    if (grepl("^--", arg)) {
      # --key=value 형태
      if (grepl("=", arg)) {
        parts <- strsplit(arg, "=", fixed = TRUE)[[1]]
        key <- gsub("^--", "", parts[1])
        value <- parts[2]
        
        # 값 타입 변환 시도
        if (value == "TRUE" || value == "true") {
          value <- TRUE
        } else if (value == "FALSE" || value == "false") {
          value <- FALSE
        } else if (!is.na(suppressWarnings(as.numeric(value)))) {
          value <- as.numeric(value)
        }
        
        parsed_args[[key]] <- value
      } else {
        # --flag 형태 (TRUE로 설정)
        key <- gsub("^--", "", arg)
        parsed_args[[key]] <- TRUE
      }
    }
  }
  
  return(parsed_args)
}

# ========== 자동 선택 함수 ==========

# 파일 자동 선택 (최신 파일 우선)
auto_select_file <- function(file_list, criteria = "latest") {
  if (length(file_list) == 0) {
    return(NULL)
  }
  
  if (criteria == "latest") {
    # 가장 최근에 수정된 파일 선택
    return(file_list[order(file.mtime(file_list), decreasing = TRUE)][1])
  } else if (criteria == "largest") {
    # 가장 큰 파일 선택
    return(file_list[order(file.size(file_list), decreasing = TRUE)][1])
  } else {
    # 첫 번째 파일 선택
    return(file_list[1])
  }
}

# 옵션 자동 선택
auto_select_option <- function(options, default_option = 1) {
  # default_option을 숫자로 변환
  if (is.character(default_option)) {
    default_option <- suppressWarnings(as.integer(default_option))
  }
  
  if (is.numeric(default_option) && !is.na(default_option)) {
    if (default_option >= 1 && default_option <= length(options)) {
      return(default_option)
    }
  }
  
  return(1)  # 기본값: 첫 번째 옵션
}

# ========== 스마트 입력 함수 ==========

# 스마트 사용자 입력 (자동/대화형 모드 지원)
smart_input <- function(prompt, 
                       type = "text", 
                       default = NULL, 
                       options = NULL,
                       validation_fn = NULL) {
  
  # 비대화형 모드에서는 기본값 또는 자동 선택 사용
  if (EXECUTION_MODE == "auto") {
    if (type == "select" && !is.null(options)) {
      selected <- auto_select_option(options, default)
      cat(sprintf("%s: 자동 선택 (%d) %s\n", prompt, selected, 
                  if(selected <= length(options)) options[selected] else ""))
      return(selected)
    } else if (!is.null(default)) {
      cat(sprintf("%s: 기본값 사용 (%s)\n", prompt, default))
      return(default)
    } else {
      # 타입별 기본값 제공
      default_value <- switch(type,
        "numeric" = 1,
        "logical" = TRUE,
        "text" = "",
        "select" = 1
      )
      cat(sprintf("%s: 자동값 사용 (%s)\n", prompt, default_value))
      return(default_value)
    }
  }
  
  # 대화형 모드에서는 사용자 입력 받기
  if (type == "select") {
    return(get_selection_input(prompt, options, default))
  } else if (type == "numeric") {
    return(get_numeric_input(prompt, default, validation_fn))
  } else if (type == "logical") {
    return(get_yes_no_input(prompt, default))
  } else {
    return(get_text_input(prompt, default, validation_fn))
  }
}

# ========== 개별 입력 함수 ==========

# 텍스트 입력
get_text_input <- function(prompt, default = NULL, validation_fn = NULL) {
  while (TRUE) {
    if (!is.null(default)) {
      full_prompt <- sprintf("%s (기본값: %s): ", prompt, default) 
    } else {
      full_prompt <- sprintf("%s: ", prompt)
    }
    
    input <- readline(full_prompt)
    
    if (input == "" && !is.null(default)) {
      input <- default
    }
    
    # 검증 함수가 있으면 실행
    if (!is.null(validation_fn)) {
      validation_result <- validation_fn(input)
      if (validation_result$valid) {
        return(validation_result$value)
      } else {
        cat(sprintf("❌ %s\n", validation_result$message))
        next
      }
    }
    
    return(input)
  }
}

# 숫자 입력
get_numeric_input <- function(prompt, default = NULL, validation_fn = NULL) {
  while (TRUE) {
    if (!is.null(default)) {
      full_prompt <- sprintf("%s (기본값: %s): ", prompt, default) 
    } else {
      full_prompt <- sprintf("%s: ", prompt)
    }
    
    input <- readline(full_prompt)
    
    if (input == "" && !is.null(default)) {
      return(default)
    }
    
    num_value <- suppressWarnings(as.numeric(input))
    
    if (is.na(num_value)) {
      cat("❌ 올바른 숫자를 입력해주세요.\n")
      next
    }
    
    # 검증 함수가 있으면 실행
    if (!is.null(validation_fn)) {
      validation_result <- validation_fn(num_value)
      if (validation_result$valid) {
        return(validation_result$value)
      } else {
        cat(sprintf("❌ %s\n", validation_result$message))
        next
      }
    }
    
    return(num_value)
  }
}

# Yes/No 입력
get_yes_no_input <- function(prompt, default = TRUE) {
  while (TRUE) {
    default_text <- if (default) "y" else "n"
    full_prompt <- sprintf("%s (y/n, 기본값: %s): ", prompt, default_text)
    
    input <- tolower(trimws(readline(full_prompt)))
    
    if (input == "") {
      return(default)
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

# 선택 입력 (목록에서 선택)
get_selection_input <- function(prompt, options, default = 1) {
  # default 값을 숫자로 변환하고 유효성 검사
  if (is.character(default)) {
    default <- suppressWarnings(as.integer(default))
  }
  if (is.na(default) || default < 1 || default > length(options)) {
    default <- 1
  }
  
  while (TRUE) {
    cat(sprintf("\n%s\n", prompt))
    for (i in seq_along(options)) {
      marker <- if (i == default) " (기본값)" else ""
      cat(sprintf("%d. %s%s\n", i, options[i], marker))
    }
    
    input <- readline(sprintf("선택하세요 (1-%d, 기본값: %d): ", length(options), default))
    
    if (input == "") {
      return(default)
    }
    
    selection <- suppressWarnings(as.integer(input))
    
    if (is.na(selection) || selection < 1 || selection > length(options)) {
      cat(sprintf("❌ 1부터 %d까지의 숫자를 입력해주세요.\n", length(options)))
      next
    }
    
    return(selection)
  }
}

# ========== 파일 선택 도우미 ==========

# 스마트 파일 선택
smart_file_selection <- function(files, 
                                description = "파일", 
                                auto_select = TRUE,
                                criteria = "latest") {
  
  if (length(files) == 0) {
    return(NULL)
  }
  
  if (length(files) == 1) {
    cat(sprintf("✅ %s 자동 선택: %s\n", description, basename(files[1])))
    return(files[1])
  }
  
  if (EXECUTION_MODE == "auto" && auto_select) {
    selected_file <- auto_select_file(files, criteria)
    cat(sprintf("✅ %s 자동 선택 (%s): %s\n", description, criteria, basename(selected_file)))
    return(selected_file)
  }
  
  # 대화형 모드에서는 사용자 선택
  cat(sprintf("\n사용 가능한 %s:\n", description))
  for (i in seq_along(files)) {
    file_info <- file.info(files[i])
    cat(sprintf("%d. %s (%.1f KB, %s)\n", 
                i, basename(files[i]), 
                file_info$size/1024,
                format(file_info$mtime, "%Y-%m-%d %H:%M")))
  }
  
  selection <- get_selection_input(
    sprintf("%s을 선택하세요", description),
    basename(files),
    1
  )
  
  return(files[selection])
}

# ========== 검증 함수들 ==========

# 범위 검증
validate_range <- function(min_val, max_val) {
  function(value) {
    if (value >= min_val && value <= max_val) {
      return(list(valid = TRUE, value = value))
    } else {
      return(list(
        valid = FALSE, 
        message = sprintf("%d와 %d 사이의 값을 입력해주세요", min_val, max_val)
      ))
    }
  }
}

# 파일 존재 검증
validate_file_exists <- function(value) {
  if (file.exists(value)) {
    return(list(valid = TRUE, value = value))
  } else {
    return(list(valid = FALSE, message = "파일이 존재하지 않습니다"))
  }
}

# ========== 설정 기반 입력 ==========

# config.R 설정을 고려한 스마트 입력
config_based_input <- function(config_path, prompt, default = NULL, type = "text") {
  # config에서 값을 먼저 찾기
  if (exists("PROJECT_CONFIG") && !is.null(config_path)) {
    config_parts <- strsplit(config_path, "\.")[[1]]
    
    config_value <- PROJECT_CONFIG
    for (part in config_parts) {
      if (part %in% names(config_value)) {
        config_value <- config_value[[part]]
      } else {
        config_value <- NULL
        break
      }
    }
    
    if (!is.null(config_value) && config_value != "auto") {
      if (EXECUTION_MODE == "auto") {
        cat(sprintf("%s: 설정값 사용 (%s)\n", prompt, config_value))
        return(config_value)
      } else {
        default <- config_value
      }
    }
  }
  
  return(smart_input(prompt, type, default))
}

# ========== 초기화 ==========
catalog("✅ interactive_utils.R 로드 완료\n")
catalog(sprintf("실행 모드: %s\n", EXECUTION_MODE))
catalog("사용 가능한 함수:\n")
catalog("  - smart_input(): 스마트 사용자 입력\n")
catalog("  - smart_file_selection(): 스마트 파일 선택\n")
catalog("  - config_based_input(): 설정 기반 입력\n")
catalog("  - auto_select_file(): 파일 자동 선택\n\n")
