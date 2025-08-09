# 02-3_full_enhanced_kiwipiepy_analysis.R
# 개선된 XSN 처리로 전체 데이터 형태소 분석 
# 기능: XSN 명사파생접미사 처리 강화로 고품질 형태소 분석
# 작성일: 2025-08-08

# ========== 패키지 설치 및 로드 ==========
cat("========== 개선된 XSN 처리 - 전체 데이터 분석 시작 ==========\n")

library(reticulate)
library(dplyr)
library(tidyr)
library(stringr)
library(parallel)

# 설정 및 유틸리티 함수 로드 (00_ 접두사로 보호됨)
if (file.exists("00_config.R")) {
  source("00_config.R")
  initialize_config()
}

if (file.exists("00_utils.R")) {
  source("00_utils.R")
}

if (file.exists("00_interactive_utils.R")) {
  source("00_interactive_utils.R")
}

# ========== 환경 설정 ==========
if (!endsWith(getwd(), "mopheme_test")) {
  script_path <- commandArgs(trailingOnly = FALSE)
  script_dir <- dirname(sub("--file=", "", script_path[grep("--file", script_path)]))
  if (length(script_dir) > 0 && script_dir != "") {
    setwd(script_dir)
  }
}
cat("작업 디렉토리:", getwd(), "\n")

# ========== Python 환경 및 Kiwipiepy 설정 ==========
cat("\n========== Python 환경 설정 ==========\n")

python_available <- FALSE
tryCatch({
  py_info <- py_config()
  python_available <- TRUE
  cat("✅ Python 확인됨\n")
  
  version_str <- tryCatch({
    if (is.list(py_info$version)) {
      paste(py_info$version, collapse=".")
    } else {
      as.character(py_info$version)
    }
  }, error = function(e) {
    "버전 정보 없음"
  })
  
  cat("Python 버전:", version_str, "\n")
}, error = function(e) {
  cat("❌ Python 환경 문제:", e$message, "\n")
  stop("Python 설치가 필요합니다.")
})

# kiwipiepy 패키지 확인 및 설치
kiwi <- NULL
tryCatch({
  kiwi <<- import("kiwipiepy")
  cat("✅ Kiwipiepy 모듈 로드 성공\n")
}, error = function(e) {
  cat("❌ Kiwipiepy 로드 실패:", e$message, "\n")
  cat("Kiwipiepy 자동 설치 시도 중...\n")
  
  tryCatch({
    # 가상환경에서는 py_require 사용
    py_require("kiwipiepy")
    cat("✅ Kiwipiepy 요구사항 확인 완료\n")
    kiwi <<- import("kiwipiepy")
    cat("✅ Kiwipiepy 로드 성공\n")
  }, error = function(e2) {
    # py_require 실패 시 py_install 시도
    cat("py_require 실패, py_install 시도 중...\n")
    tryCatch({
      py_install("kiwipiepy", pip = TRUE)
      cat("✅ Kiwipiepy 설치 완료\n")
      kiwi <<- import("kiwipiepy")
      cat("✅ Kiwipiepy 로드 성공\n")
    }, error = function(e3) {
      cat("❌ 자동 설치 실패:", e3$message, "\n")
      stop("Kiwipiepy 설치에 실패했습니다. 수동으로 설치해주세요.")
    })
  })
})

# kiwi 객체 확인
if (is.null(kiwi)) {
  stop("Kiwipiepy 로드에 실패했습니다.")
}

# ========== 모델 선택 및 분석기 초기화 ==========
cat("\n========== 모델 선택 ==========\n")

# CoNg 모델 사용 가능 여부 확인
cong_model_dir <- "cong-base"
cong_available <- dir.exists(cong_model_dir)

if (cong_available) {
  cat("✅ CoNg 모델 발견:", cong_model_dir, "\n")
  
  # 스마트 입력 사용
  if (exists("smart_input")) {
    use_cong <- smart_input(
      "CoNg 모델을 사용하시겠습니까?",
      type = "select",
      options = c("예 - CoNg 모델 사용 (향상된 성능)", "아니오 - 기본 모델 사용"),
      default = 1
    )
    USE_CONG_MODEL <- (use_cong == 1)
  } else {
    # 기존 방식 (fallback)
    cat("CoNg 모델을 사용하시겠습니까?\n")
    cat("1. 예 - CoNg 모델 사용 (향상된 성능)\n") 
    cat("2. 아니오 - 기본 모델 사용\n")
    model_choice <- readline(prompt = "선택하세요 (1 또는 2): ")
    USE_CONG_MODEL <- (model_choice == "1")
  }
  
  if (USE_CONG_MODEL) {
    cat("CoNg 모델을 사용합니다.\n")
  } else {
    cat("기본 모델을 사용합니다.\n")
  }
} else {
  cat("⚠️ CoNg 모델을 찾을 수 없습니다.\n")
  cat("CoNg 모델을 다운로드하시겠습니까?\n")
  cat("1. 예 - CoNg 모델 다운로드 및 사용 (58.7MB, 향상된 성능)\n")
  cat("2. 아니오 - 기본 모델 사용\n")
  
  cat("❌ CoNg 모델 자동 다운로드는 지원하지 않습니다. 기본 모델 사용\n")
  
  if (FALSE) {  # 자동 다운로드 비활성화
    cat("\n========== CoNg 모델 자동 설치 ==========\n")
    
    model_file <- "kiwi_model_v0.21.0_cong_base.tgz"
    model_url <- "https://github.com/bab2min/Kiwi/releases/download/v0.21.0/kiwi_model_v0.21.0_cong_base.tgz"
    
    cat("CoNg 모델을 다운로드합니다...\n")
    cat("URL:", model_url, "\n")
    cat("크기: 약 58.7MB\n\n")
    
    # 다운로드 시도
    tryCatch({
      download.file(model_url, destfile = model_file, mode = "wb")
      cat("✅ 다운로드 완료\n")
      
      # 압축 해제
      cat("압축 해제 중...\n")
      system2("tar", args = c("-zxvf", model_file))
      
      # 압축 파일 삭제
      file.remove(model_file)
      cat("✅ CoNg 모델 설치 완료\n")
      
      # 모델 파일 확인
      if (dir.exists(cong_model_dir)) {
        cat("모델 디렉토리 내용:\n")
        model_files <- list.files(cong_model_dir)
        for (f in model_files) {
          cat("  -", f, "\n")
        }
        USE_CONG_MODEL <- TRUE
        cong_available <- TRUE
      } else {
        cat("❌ 모델 설치 확인 실패\n")
        USE_CONG_MODEL <- FALSE
      }
      
    }, error = function(e) {
      cat("❌ 다운로드 실패:", e$message, "\n")
      cat("\n수동 설치 방법:\n")
      cat("1. 브라우저에서 다음 URL 접속:\n")
      cat("   ", model_url, "\n")
      cat("2. 다운로드한 파일을 현재 디렉토리에 복사\n")
      cat("3. 압축 해제: tar -zxvf", model_file, "\n")
      cat("기본 모델을 사용합니다.\n")
      USE_CONG_MODEL <- FALSE
    })
  } else {
    cat("기본 모델을 사용합니다.\n")
    USE_CONG_MODEL <- FALSE
  }
}

# ========== 사용자 사전 설정 ==========
cat("\n========== 사용자 사전 설정 ==========\n")

# Kiwi 분석기 초기화 (모델에 따라)
if (USE_CONG_MODEL) {
  cat("CoNg 모델로 분석기 초기화 중...\n")
  tryCatch({
    cong_model_path <- normalizePath(cong_model_dir, winslash = "/")
    kiwi_analyzer <- kiwi$Kiwi(model_path = cong_model_path, model_type = "cong")
    cat("✅ CoNg 모델 분석기 초기화 성공\n")
  }, error = function(e) {
    cat("❌ CoNg 모델 초기화 실패:", e$message, "\n")
    cat("기본 모델로 fallback합니다.\n")
    kiwi_analyzer <- kiwi$Kiwi()
    USE_CONG_MODEL <<- FALSE
  })
} else {
  cat("기본 모델로 분석기 초기화 중...\n")
  kiwi_analyzer <- kiwi$Kiwi()
  cat("✅ 기본 모델 분석기 초기화 성공\n")
}

# 대화형 사전 선택
cat("\n사용자 사전을 적용하시겠습니까?\n")
cat("1. 예 - 사용자 사전 적용\n")
cat("2. 아니오 - 기본 분석기 사용\n")

# 사용자 입력 받기
dict_choice <- readline(prompt = "선택하세요 (1 또는 2): ")

if (dict_choice == "1") {
  USE_USER_DICT <- TRUE
  cat("사용자 사전을 적용합니다.\n")
  
  # 사용 가능한 사전 파일 찾기
  dict_path <- "data/dictionaries/"
  dict_files <- list.files(dict_path, pattern = "user_dict_.*\\.txt$", full.names = TRUE)
  
  if (length(dict_files) > 0) {
    if (length(dict_files) == 1) {
      # 사전 파일이 하나만 있으면 자동 선택
      selected_dict <- dict_files[1]
      cat("✅ 자동 선택된 사전 파일:", basename(selected_dict), "\n")
    } else {
      # 여러 개가 있으면 사용자가 선택
      cat("\n사용 가능한 사용자 사전 파일:\n")
      dict_files <- dict_files[order(file.info(dict_files)$mtime, decreasing = TRUE)]
      
      for (i in seq_along(dict_files)) {
        file_info <- file.info(dict_files[i])
        cat(sprintf("%d. %s (%.1f KB, %s)\n", 
                    i, basename(dict_files[i]), 
                    file_info$size/1024,
                    format(file_info$mtime, "%Y-%m-%d %H:%M")))
      }
      
      dict_selection <- readline(prompt = sprintf("사전을 선택하세요 (1-%d): ", length(dict_files)))
      dict_idx <- as.numeric(dict_selection)
      
      if (!is.na(dict_idx) && dict_idx >= 1 && dict_idx <= length(dict_files)) {
        selected_dict <- dict_files[dict_idx]
        cat("✅ 선택된 사전 파일:", basename(selected_dict), "\n")
      } else {
        cat("⚠️ 잘못된 선택입니다. 최신 사전을 자동 선택합니다.\n")
        selected_dict <- dict_files[1]
        cat("✅ 자동 선택된 사전 파일:", basename(selected_dict), "\n")
      }
    }
  } else {
    cat("⚠️ 사용자 사전 파일을 찾을 수 없습니다. 기본 분석기를 사용합니다.\n")
    USE_USER_DICT <- FALSE
    selected_dict <- NULL
  }
} else {
  USE_USER_DICT <- FALSE
  selected_dict <- NULL
  cat("기본 분석기를 사용합니다.\n")
}

if (FALSE) {  # 사용자 사전 로직 비활성화
  USE_USER_DICT <- TRUE
  
  # 사용 가능한 사전 파일 찾기
  dict_path <- "data/dictionaries/"
  dict_files <- list.files(dict_path, pattern = "user_dict_.*\\.txt$", full.names = TRUE)
  
  if (length(dict_files) > 0) {
    cat("\n========== 사용 가능한 사전 파일 ==========\n")
    for (i in seq_along(dict_files)) {
      file_info <- file.info(dict_files[i])
      cat(sprintf("%d. %s (%.1f KB, %s)\n", 
                  i, basename(dict_files[i]), 
                  file_info$size/1024,
                  format(file_info$mtime, "%Y-%m-%d %H:%M")))
    }
    cat(sprintf("%d. 최신 파일 자동 선택 (추천)\n", length(dict_files) + 1))
    
    # 사전 선택
    dict_choice <- readline(prompt = sprintf("선택 (1-%d): ", length(dict_files) + 1))
    
    if (dict_choice == as.character(length(dict_files) + 1)) {
      selected_dict <- dict_files[which.max(file.mtime(dict_files))]
      cat("→ 최신 파일 선택됨\n")
    } else if (dict_choice %in% as.character(1:length(dict_files))) {
      selected_dict <- dict_files[as.numeric(dict_choice)]
    } else {
      cat("잘못된 선택입니다. 최신 파일을 사용합니다.\n")
      selected_dict <- dict_files[which.max(file.mtime(dict_files))]
    }
    
    if (!is.null(selected_dict)) {
      cat("\n선택된 사전:", basename(selected_dict), "\n")
      
      # 사전 내용 읽기 및 적용
      dict_content <- readLines(selected_dict, encoding = "UTF-8")
      dict_words <- strsplit(dict_content, "\t")
      
      added_count <- 0
      for (word_info in dict_words) {
        if (length(word_info) >= 1) {
          word <- word_info[1]
          tag <- if(length(word_info) >= 2) word_info[2] else "NNG"
          score <- if(length(word_info) >= 3) as.numeric(word_info[3]) else 0.0
          
          tryCatch({
            kiwi_analyzer$add_user_word(word, tag, score)
            added_count <- added_count + 1
          }, error = function(e) {
            # 오류 무시 (중복 단어 등)
          })
        }
      }
      
      cat(sprintf("✅ 사용자 사전 적용 완료: %d개 단어 추가\n", added_count))
      model_suffix <- if(USE_CONG_MODEL) "cong" else "default"
      dict_type_suffix <- paste0("kiwipiepy_", model_suffix, "_userdict_", 
                                  gsub("kiwi_user_dict_|\\.txt", "", basename(selected_dict)))
    } else {
      cat("❌ 사전 선택 안됨\n")
      model_suffix <- if(USE_CONG_MODEL) "cong" else "default"
      dict_type_suffix <- paste0("kiwipiepy_", model_suffix, "_no_dict")
    }
  } else {
    cat("❌ 사용 가능한 사전 파일이 없습니다.\n")
    USE_USER_DICT <- FALSE
    model_suffix <- if(USE_CONG_MODEL) "cong" else "default"
    dict_type_suffix <- paste0("kiwipiepy_", model_suffix, "_no_dict")
  }
} else {
  cat("→ 기본 분석기를 사용합니다.\n")
  model_suffix <- if(USE_CONG_MODEL) "cong" else "default"
  dict_type_suffix <- paste0("kiwipiepy_", model_suffix, "_default")
}

# 최종 선택 확인
cat("\n========== 분석 설정 확인 ==========\n")
cat("🤖 사용 모델:", if(USE_CONG_MODEL) "CoNg 모델 (향상된 정확도/속도)" else "기본 모델", "\n")
if (USE_USER_DICT && !is.null(selected_dict)) {
  cat("✅ 사용자 사전 적용:", basename(selected_dict), "\n")
  dict_info <- file.info(selected_dict)
  cat(sprintf("   📊 사전 크기: %.1f KB\n", dict_info$size/1024))
  cat(sprintf("   📅 생성일시: %s\n", format(dict_info$mtime, "%Y-%m-%d %H:%M")))
} else {
  cat("✅ 분석기 설정: 사전 미적용\n")
}
cat("📁 결과 파일 접미사:", dict_type_suffix, "\n")

# 새로운 파일명 체계 적용을 위한 타임스탬프 및 태그 설정
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
optional_tag <- dict_type_suffix # 기존 dict_type_suffix를 optional_tag로 사용

# 최종 확인

cat("\n분석을 시작하시겠습니까?\n")
cat("1. 예 - 분석 시작\n")
cat("2. 아니오 - 종료\n")

# 사용자 입력 받기
start_choice <- readline(prompt = "선택하세요 (1 또는 2): ")

if (start_choice == "2") {
  cat("분석을 취소합니다.\n")
  quit(save = "no", status = 0)
}

cat("\n✅ 분석을 시작합니다.\n")
cat("예상 분석 시간: 약 0.3분 (최적화됨)\n")

# ========== 데이터 불러오기 ==========
cat("\n========== 데이터 불러오기 ==========\n")

# 최신 combined_data.rds 파일 찾기
processed_data_path <- "data/processed"
combined_data_files <- list.files(
  processed_data_path,
  pattern = "^dl_combined_data_.*\\.rds$",
  full.names = TRUE
)

if (length(combined_data_files) == 0) {
  stop("dl_combined_data_*.rds 파일을 찾을 수 없습니다. 01_data_loading_and_analysis.R을 먼저 실행해주세요.")
}

# 가장 최신 파일 선택
latest_combined_data_file <- combined_data_files[order(file.mtime(combined_data_files), decreasing = TRUE)][1]

combined_data <- readRDS(latest_combined_data_file)
cat(sprintf("✅ 최신 데이터 파일 로드: %s\n", basename(latest_combined_data_file)))
cat("전체 데이터 행 수:", nrow(combined_data), "\n")

# 컬럼 식별
id_patterns <- c("ID", "id", "논문 ID", "일련", "번호", "article", "Article")
id_column <- NULL
for (pattern in id_patterns) {
  matching_cols <- grep(pattern, names(combined_data), ignore.case = TRUE, value = TRUE)
  if (length(matching_cols) > 0) {
    id_column <- matching_cols[1]
    break
  }
}

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

if (is.null(id_column)) id_column <- names(combined_data)[1]
if (is.null(abstract_column)) {
  text_cols <- names(combined_data)[sapply(combined_data, is.character)]
  abstract_column <- text_cols[text_cols != "source_file"][1]
}

# ========== 태그 기반 명사 추출 함수 ==========
extract_nouns_enhanced_xsn <- function(text) {
  if (is.na(text) || is.null(text) || !is.character(text) || nchar(trimws(text)) == 0) {
    return(character(0))
  }
  
  clean_text <- trimws(as.character(text))
  if (nchar(clean_text) < 10) {
    return(character(0))
  }
  
  tryCatch({
    result <- kiwi_analyzer$tokenize(clean_text)
    all_nouns <- c()
    i <- 1
    
    while (i <= length(result)) {
      token <- result[[i]]
      
      # Noun + XSN 결합을 위한 Look-ahead
      if (i < length(result) && token$tag %in% c("NNG", "NNP")) {
        next_token <- result[[i + 1]]
        if (next_token$tag == "XSN") {
          # 결합 성공: 결합된 명사를 추가하고 인덱스를 2칸 이동
          combined_noun <- paste0(token$form, next_token$form)
          all_nouns <- c(all_nouns, combined_noun)
          i <- i + 2
          next
        }
      }
      
      # 일반 명사(NNG, NNP) 처리
      if (token$tag %in% c("NNG", "NNP")) {
        all_nouns <- c(all_nouns, token$form)
      }
      
      i <- i + 1
    }
    
    if (length(all_nouns) > 0) {
      final_nouns <- unique(all_nouns[nchar(all_nouns) >= 1])
      return(final_nouns)
    } else {
      return(character(0))
    }
    
  }, error = function(e) {
    warning(paste("개선된 XSN 형태소 분석 오류:", e$message))
    return(character(0))
  })
}

# ========== 형태소 분석 함수 ==========
analyze_morphemes_enhanced <- function(text) {
  if (is.na(text) || is.null(text) || !is.character(text) || nchar(trimws(text)) == 0) {
    return("")
  }
  
  clean_text <- trimws(as.character(text))
  if (nchar(clean_text) < 10) {
    return("")
  }
  
  tryCatch({
    result <- kiwi_analyzer$tokenize(clean_text)
    
    morpheme_tags <- c()
    for (token in result) {
      kiwi_tag <- token$tag
      # 형태소/품사태그 형식으로 저장
      morpheme_tags <- c(morpheme_tags, paste0(token$form, "/", kiwi_tag))
    }
    
    return(paste(morpheme_tags, collapse = " "))
    
  }, error = function(e) {
    warning(paste("개선된 형태소 분석 오류:", e$message))
    return("")
  })
}

# ========== 전체 데이터 준비 ==========
cat("\n========== 전체 데이터 준비 ==========\n")

analysis_data <- combined_data %>%
  select(all_of(c(id_column, abstract_column))) %>%
  filter(!is.na(!!sym(abstract_column)) & 
         nchar(trimws(!!sym(abstract_column))) > 10) %>%
  rename(doc_id = !!sym(id_column), abstract = !!sym(abstract_column)) %>%
  mutate(doc_id = as.character(doc_id),
         abstract = trimws(as.character(abstract))) %>%
  filter(nchar(abstract) > 10)

cat("전체 분석 대상:", nrow(analysis_data), "개 문서\n")

if (nrow(analysis_data) == 0) {
  stop("분석할 데이터가 없습니다.")
}

# ========== 병렬 처리 설정 (리소스 최대 활용) ==========
cat("\n========== 병렬 처리 최적화 ==========\n")

# 시스템 리소스 자동 감지
n_cores <- detectCores()

# 메모리 기반 동적 코어 수 조정 (Windows 환경)
available_memory_gb <- tryCatch({
  # 방법 1: wmic 명령어로 사용 가능 메모리 확인
  mem_info <- system('wmic OS get FreePhysicalMemory /value', intern = TRUE)
  free_mem_line <- grep('FreePhysicalMemory=', mem_info, value = TRUE)
  if (length(free_mem_line) > 0) {
    free_mem_kb <- as.numeric(sub('FreePhysicalMemory=', '', free_mem_line))
    detected_memory <- round(free_mem_kb / (1024^2), 1)
    cat(sprintf("감지된 사용 가능 메모리: %.1f GB\n", detected_memory))
    return(detected_memory)
  }
  
  # 방법 2: 전체 메모리로 추정 (wmic 실패 시)
  total_info <- system('wmic computersystem get TotalPhysicalMemory /value', intern = TRUE)
  total_mem_line <- grep('TotalPhysicalMemory=', total_info, value = TRUE)
  if (length(total_mem_line) > 0) {
    total_mem_bytes <- as.numeric(sub('TotalPhysicalMemory=', '', total_mem_line))
    total_memory <- round(total_mem_bytes / (1024^3), 1)
    estimated_available <- total_memory * 0.7  # 전체의 70%를 사용 가능으로 추정
    cat(sprintf("전체 메모리 기반 추정: %.1f GB (전체 %.1f GB의 70%%)\n", 
                estimated_available, total_memory))
    return(estimated_available)
  }
  
  # 방법 3: CPU 코어 수로 추정 (모든 방법 실패 시)
  cores <- parallel::detectCores()
  if (cores >= 12) {
    estimated <- 32  # 12코어 이상 = 고사양 시스템 추정
    cat(sprintf("CPU 코어 수(%d) 기반 추정: %.1f GB\n", cores, estimated))
    return(estimated)
  } else if (cores >= 8) {
    estimated <- 16  # 8-11코어 = 중사양 시스템 추정
    cat(sprintf("CPU 코어 수(%d) 기반 추정: %.1f GB\n", cores, estimated))
    return(estimated)
  } else {
    estimated <- 8   # 8코어 미만 = 저사양 시스템 추정
    cat(sprintf("CPU 코어 수(%d) 기반 추정: %.1f GB\n", cores, estimated))
    return(estimated)
  }
}, error = function(e) {
  # 최종 기본값: CPU 코어 기반 추정
  cores <- parallel::detectCores()
  if (cores >= 12) {
    32  # 고사양 추정
  } else if (cores >= 8) {
    16  # 중사양 추정  
  } else {
    8   # 저사양 추정
  }
})

# 최적 코어 수 계산 (실제 성능 기반 조정)
if (available_memory_gb >= 32) {
  # 고사양: 32GB+ - 사용자 시스템 최적화 (원래 설정 복원)
  use_cores <- max(1, n_cores - 1)  # 거의 모든 코어 활용 (1개만 예약)
  memory_tier <- "고사양"
} else if (available_memory_gb >= 16) {
  # 중사양: 16GB+ - 메모리 제약 고려  
  optimal_cores <- min(8, round(n_cores * 0.75))  # 최대 8코어 또는 75% 활용
  use_cores <- max(1, optimal_cores)
  memory_tier <- "중사양"
} else if (available_memory_gb >= 8) {
  # 저사양: 8GB+ - 보수적 활용
  optimal_cores <- min(6, round(n_cores * 0.5))  # 최대 6코어, 50% 활용
  use_cores <- max(1, optimal_cores)
  memory_tier <- "저사양"
} else {
  # 최저사양: 8GB 미만 - 최소한만 활용
  use_cores <- max(1, min(4, n_cores - 2))  # 최대 4코어, 시스템 안정성 우선
  memory_tier <- "최저사양"
}

# 안전 범위로 제한
use_cores <- max(1, min(use_cores, n_cores - 1))

# 동적 배치 크기 계산 (CPU 코어 수 기반)
calculate_optimal_batch_size <- function(total_docs, num_cores) {
  # 실제 성능 기반 최적화: 배치 오버헤드 vs 병렬 효율성
  
  # 코어 수와 동일한 배치 수를 목표 (오버헤드 최소화)
  target_batches <- num_cores
  
  # 배치 크기 계산
  base_batch_size <- ceiling(total_docs / target_batches)
  
  # 성능 기반 제한
  min_batch_size <- 50   # Python 초기화 오버헤드 고려하여 증가
  max_batch_size <- 300  # 메모리 효율성 고려하여 증가
  
  optimal_batch_size <- max(min_batch_size, min(base_batch_size, max_batch_size))
  
  return(optimal_batch_size)
}

BATCH_SIZE <- calculate_optimal_batch_size(nrow(analysis_data), use_cores)
total_batches <- ceiling(nrow(analysis_data) / BATCH_SIZE)

cat(sprintf("🎯 성능 기반 배치 크기 최적화:\n"))
cat(sprintf("  └─ 총 문서: %d개\n", nrow(analysis_data)))
cat(sprintf("  └─ 사용 코어: %d개\n", use_cores))
cat(sprintf("  └─ 최적 배치 크기: %d개\n", BATCH_SIZE))
cat(sprintf("  └─ 총 배치 수: %d개\n", total_batches))
cat(sprintf("  └─ 배치/코어 비율: %.1f개 (이상적: 1.0)\n", total_batches / use_cores))

# 성능 예측 안내
if (total_batches / use_cores > 1.2) {
  cat("  ⚠️  배치 오버헤드 주의: 배치 수가 코어 수보다 많아 성능 저하 가능\n")
} else if (total_batches < use_cores) {
  cat("  ⚠️  코어 미활용: 일부 코어가 놀 수 있음\n")
} else {
  cat("  ✅ 최적 배치: 배치 수와 코어 수 균형 달성\n")
}


# ========== 배치 처리 함수 정의 ==========
process_batch_parallel <- function(batch_data, batch_num, USE_CONG_MODEL, USE_USER_DICT, selected_dict) {
  # CPU 집약적 작업 확인을 위한 타이밍
  worker_start_time <- Sys.time()
  cat(sprintf("[워커 %d] 시작 - PID: %d\n", batch_num, Sys.getpid()))
  
  # 각 워커에서 독립적인 kiwipiepy 초기화
  library(reticulate)
  kiwi <- import("kiwipiepy")
  
  init_time <- Sys.time()
  cat(sprintf("[워커 %d] Python 모듈 로드 완료: %.2f초\n", batch_num, 
              as.numeric(difftime(init_time, worker_start_time, units = "secs"))))
  
  # 모델 초기화
  if (USE_CONG_MODEL && dir.exists("cong-base")) {
    tryCatch({
      cong_model_path <- normalizePath("cong-base", winslash = "/")
      kiwi_analyzer <- kiwi$Kiwi(model_path = cong_model_path, model_type = "cong")
    }, error = function(e) {
      kiwi_analyzer <<- kiwi$Kiwi()
    })
  } else {
    kiwi_analyzer <- kiwi$Kiwi()
  }
  
  model_time <- Sys.time()
  cat(sprintf("[워커 %d] 모델 초기화 완료: %.2f초\n", batch_num,
              as.numeric(difftime(model_time, init_time, units = "secs"))))
  
  # 사용자 사전 적용 (필요시)
  if (USE_USER_DICT && !is.null(selected_dict) && file.exists(selected_dict)) {
    dict_content <- readLines(selected_dict, encoding = "UTF-8")
    dict_words <- strsplit(dict_content, "\t")
    
    for (word_info in dict_words) {
      if (length(word_info) >= 1) {
        word <- word_info[1]
        tag <- if(length(word_info) >= 2) word_info[2] else "NNG"
        score <- if(length(word_info) >= 3) as.numeric(word_info[3]) else 0.0
        
        tryCatch({
          kiwi_analyzer$add_user_word(word, tag, score)
        }, error = function(e) {
          # 오류 무시
        })
      }
    }
  }
  
  # 배치 내 문서 처리 (리스트 수집 방식 사용)
  morpheme_list <- list()
  noun_list <- list()
  success_count <- 0
  error_count <- 0
  
  for (i in 1:nrow(batch_data)) {
    doc_id <- batch_data$doc_id[i]
    abstract <- batch_data$abstract[i]
    
    tryCatch({
      # 개선된 XSN 처리 분석
      extracted_nouns <- extract_nouns_enhanced_xsn(abstract, kiwi_analyzer)
      morpheme_analysis <- analyze_morphemes_enhanced(abstract, kiwi_analyzer)
      
      if (length(extracted_nouns) > 0) {
        noun_extraction <- paste(extracted_nouns, collapse = ", ")
        noun_list[[length(noun_list) + 1]] <- data.frame(
          doc_id = as.character(doc_id),
          noun_extraction = noun_extraction,
          stringsAsFactors = FALSE
        )
      }
      
      if (nchar(morpheme_analysis) > 0) {
        morpheme_list[[length(morpheme_list) + 1]] <- data.frame(
          doc_id = as.character(doc_id),
          morpheme_analysis = morpheme_analysis,
          stringsAsFactors = FALSE
        )
      }
      
      success_count <- success_count + 1
      
    }, error = function(e) {
      error_count <- error_count + 1
    })
  }
  
  # 워커 완료 시간 기록
  worker_end_time <- Sys.time()
  total_worker_time <- as.numeric(difftime(worker_end_time, worker_start_time, units = "secs"))
  
  cat(sprintf("[워커 %d] 완료 - 총 시간: %.2f초, 문서 %d개 처리\n", 
              batch_num, total_worker_time, nrow(batch_data)))
  
  # 배치 결과 반환 (do.call(rbind) 방식)
  return(list(
    morpheme = if(length(morpheme_list) > 0) do.call(rbind, morpheme_list) else data.frame(),
    nouns = if(length(noun_list) > 0) do.call(rbind, noun_list) else data.frame(),
    batch_num = batch_num,
    processed_docs = nrow(batch_data),
    success_count = success_count,
    error_count = error_count,
    processing_time = Sys.time(),
    worker_total_time = total_worker_time
  ))
}

# 기존 함수를 병렬 처리용으로 수정 (kiwi_analyzer 파라미터 추가)
extract_nouns_enhanced_xsn <- function(text, kiwi_analyzer) {
  if (is.na(text) || is.null(text) || !is.character(text) || nchar(trimws(text)) == 0) {
    return(character(0))
  }
  
  clean_text <- trimws(as.character(text))
  if (nchar(clean_text) < 10) {
    return(character(0))
  }
  
  tryCatch({
    result <- kiwi_analyzer$tokenize(clean_text)
    all_nouns <- c()
    i <- 1
    
    while (i <= length(result)) {
      token <- result[[i]]
      
      # Noun + XSN 결합을 위한 Look-ahead
      if (i < length(result) && token$tag %in% c("NNG", "NNP")) {
        next_token <- result[[i + 1]]
        if (next_token$tag == "XSN") {
          combined_noun <- paste0(token$form, next_token$form)
          all_nouns <- c(all_nouns, combined_noun)
          i <- i + 2
          next
        }
      }
      
      # 일반 명사(NNG, NNP) 처리
      if (token$tag %in% c("NNG", "NNP")) {
        all_nouns <- c(all_nouns, token$form)
      }
      
      i <- i + 1
    }
    
    if (length(all_nouns) > 0) {
      final_nouns <- unique(all_nouns[nchar(all_nouns) >= 1])
      return(final_nouns)
    } else {
      return(character(0))
    }
    
  }, error = function(e) {
    return(character(0))
  })
}

analyze_morphemes_enhanced <- function(text, kiwi_analyzer) {
  if (is.na(text) || is.null(text) || !is.character(text) || nchar(trimws(text)) == 0) {
    return("")
  }
  
  clean_text <- trimws(as.character(text))
  if (nchar(clean_text) < 10) {
    return("")
  }
  
  tryCatch({
    result <- kiwi_analyzer$tokenize(clean_text)
    
    morpheme_tags <- c()
    for (token in result) {
      kiwi_tag <- token$tag
      # 형태소/품사태그 형식으로 저장
      morpheme_tags <- c(morpheme_tags, paste0(token$form, "/", kiwi_tag))
    }
    
    return(paste(morpheme_tags, collapse = " "))
    
  }, error = function(e) {
    return("")
  })
}

# ========== 형태소 분석 실행 ==========
cat("\n========== 개선된 XSN 처리 형태소 분석 실행 (병렬 처리) ==========\n")

total_start_time <- Sys.time()

# 데이터를 배치로 분할
batches <- split(analysis_data, ceiling(seq_len(nrow(analysis_data)) / BATCH_SIZE))

# ========== 병렬 처리 실행 ==========
cat(sprintf("🚀 병렬 클러스터 생성 중... (%d 워커)\n", use_cores))
cl <- makeCluster(use_cores, type = "PSOCK")  # Windows 최적화

# 클러스터 환경 최적화 설정
cat("⚙️  클러스터 환경 설정 중...\n")

# 각 워커에 필요한 패키지 로드 (병렬)
clusterEvalQ(cl, {
  library(reticulate)
  library(dplyr)
})

# 메모리 효율적인 함수 전송
cat("📦 함수 및 데이터 전송 중...\n")
clusterExport(cl, c("process_batch_parallel", "extract_nouns_enhanced_xsn", "analyze_morphemes_enhanced"))

# 클러스터 성능 최적화
clusterEvalQ(cl, {
  # R 메모리 관리 최적화
  options(warn = -1)  # 워커에서 경고 억제
  invisible(gc())     # 가비지 컬렉션
})

# 배치와 매개변수를 함께 전달
batch_with_params <- lapply(1:length(batches), function(i) {
  list(
    data = batches[[i]], 
    num = i,
    USE_CONG_MODEL = USE_CONG_MODEL,
    USE_USER_DICT = USE_USER_DICT,
    selected_dict = selected_dict
  )
})

cat(sprintf("🔥 병렬 배치 처리 시작... (%d 워커 × %d 배치)\n", use_cores, length(batches)))

batch_results <- parLapply(cl, batch_with_params, function(x) {
  result <- process_batch_parallel(x$data, x$num, x$USE_CONG_MODEL, x$USE_USER_DICT, x$selected_dict)
  return(result)
})

# 클러스터 정리 및 리소스 해제
cat("🧹 클러스터 정리 중...\n")
stopCluster(cl)
invisible(gc())  # 메모리 해제
cat("✅ 병렬 처리 완료! 리소스 최적화 성공\n")

# 워커별 성능 분석
worker_times <- sapply(batch_results, function(x) {
  if (!is.null(x$worker_total_time)) {
    return(x$worker_total_time)
  } else {
    return(NA)
  }
})

if (any(!is.na(worker_times))) {
  cat(sprintf("🔍 워커 성능 분석:\n"))
  cat(sprintf("  └─ 평균 워커 시간: %.2f초\n", mean(worker_times, na.rm = TRUE)))
  cat(sprintf("  └─ 최빠른 워커: %.2f초\n", min(worker_times, na.rm = TRUE)))
  cat(sprintf("  └─ 가장 느린 워커: %.2f초\n", max(worker_times, na.rm = TRUE)))
  
  # 병렬 효율성 계산
  if (max(worker_times, na.rm = TRUE) > 0) {
    parallel_efficiency <- min(worker_times, na.rm = TRUE) / max(worker_times, na.rm = TRUE) * 100
    cat(sprintf("  └─ 병렬 효율성: %.1f%% (100%% = 완벽한 로드 밸런싱)\n", parallel_efficiency))
    
    if (parallel_efficiency < 80) {
      cat("  ⚠️  낮은 병렬 효율성: 배치 크기 조정 또는 코어 수 감소 고려\n")
    }
  }
}

total_end_time <- Sys.time()
total_processing_time <- as.numeric(difftime(total_end_time, total_start_time, units = "secs"))

# ========== 병렬 처리 결과 통합 ==========
cat("\n========== 병렬 처리 결과 통합 중 ==========\n")

# 각 배치 결과에서 데이터프레임 추출 및 통합 (do.call(rbind) 방식)
morpheme_results <- do.call(rbind, lapply(batch_results, function(x) x$morpheme))
noun_results <- do.call(rbind, lapply(batch_results, function(x) x$nouns))

# 통계 계산
processed_count <- sum(sapply(batch_results, function(x) x$processed_docs))
success_count <- sum(sapply(batch_results, function(x) x$success_count))
error_count <- sum(sapply(batch_results, function(x) x$error_count))


# ========== 결과 통합 및 요약 ==========
cat("\n========== 개선된 XSN 처리 분석 결과 (병렬 처리) ==========\n")
cat("분석기 버전: Enhanced XSN Kiwipiepy v2.0 (병렬 최적화)\n")
cat(sprintf("사용 코어: %d개 (전체 %d개 중)\n", use_cores, n_cores))
cat("전체 문서 수:", nrow(analysis_data), "\n")
cat("처리된 문서 수:", processed_count, "\n")
cat("성공한 문서 수:", success_count, "\n")
cat("오류 발생 문서 수:", error_count, "\n")
cat("형태소 분석 결과 수:", nrow(morpheme_results), "\n")
cat("명사 추출 결과 수:", nrow(noun_results), "\n")
cat("성공률:", sprintf("%.1f%%", (success_count / processed_count) * 100), "\n")
cat("전체 처리 시간:", sprintf("%.2f분", total_processing_time / 60), "\n")
cat("평균 처리 속도:", sprintf("%.1f 문서/초", processed_count / total_processing_time), "\n")
cat(sprintf("리소스 활용 효율성: %d/%d 코어 (%.0f%%) 사용\n", 
            use_cores, n_cores, (use_cores/n_cores)*100))

# 병렬 처리 효율성 분석
batch_times <- sapply(batch_results, function(x) {
  if (!is.null(x$processing_time)) {
    return(as.numeric(difftime(x$processing_time, total_start_time, units = "secs")))
  } else {
    return(NA)
  }
})
batch_times <- batch_times[!is.na(batch_times)]

if (length(batch_times) > 0) {
  cat("배치 완료 시간 분포:\n")
  cat(sprintf("  최초 배치 완료: %.1f초\n", min(batch_times)))
  cat(sprintf("  최종 배치 완료: %.1f초\n", max(batch_times)))
  cat(sprintf("  평균 배치 완료: %.1f초\n", mean(batch_times)))
}

# ========== 최종 결과 저장 ==========
cat("\n========== 최종 결과 저장 ==========\n")

# 02_morpheme_analysis.R과 동일한 구조로 변경
final_results <- list(
  morpheme_analysis = morpheme_results,
  noun_extraction = noun_results,
  metadata = list(
    analysis_date = Sys.Date(),
    dict_type = dict_type_suffix,
    selected_dict = if(USE_USER_DICT && exists("selected_dict")) basename(selected_dict) else NULL,
    total_documents = nrow(analysis_data),
    processed_documents = processed_count,
    successful_documents = success_count,
    error_documents = error_count,
    success_rate = (success_count / processed_count) * 100,
    use_custom_dict = USE_USER_DICT,
    api_used = FALSE,
    batch_size = BATCH_SIZE,
    total_batches = total_batches,
    # Enhanced XSN Kiwipiepy + 병렬 처리 추가 필드
    analyzer_type = "Enhanced XSN Kiwipiepy (병렬 최적화)",
    analyzer_version = if(USE_USER_DICT) "v3.1_parallel_userdict" else "v3.0_parallel", 
    model_type = if(USE_CONG_MODEL) "CoNg" else "기본",
    model_path = if(USE_CONG_MODEL) cong_model_dir else NULL,
    python_version = version_str,
    total_processing_time = total_processing_time,
    processing_speed = processed_count / total_processing_time,
    # 병렬 처리 정보 추가
    parallel_info = list(
      cores_used = use_cores,
      total_cores = n_cores,
      memory_tier = memory_tier,
      available_memory_gb = available_memory_gb,
      core_utilization_percent = round((use_cores/n_cores)*100, 1),
      parallel_efficiency = if(length(batch_times) > 0) round((min(batch_times) / max(batch_times)) * 100, 1) else NA,
      batch_count = length(batches),
      avg_batch_completion = if(length(batch_times) > 0) round(mean(batch_times), 2) else NA
    ),
    enhancements = list(
      "배치 레벨 병렬 처리 (최적화 1순위)",
      "리스트 수집 방식 메모리 최적화 (최적화 2순위)",
      "파일 기반 진행률 모니터링 (최적화 3순위)",
      "XSN 명사파생접미사 태그 기반 추출",
      "선행명사와 XSN 접미사 결합", 
      "순수 품사 태그 기반 명사 추출",
      "형태소 품질 향상",
      if(USE_CONG_MODEL) "CoNg 모델 (향상된 정확도/속도)" else NULL,
      if(USE_USER_DICT) "사용자 사전 적용" else NULL
    )
  )
)

# 결과 구조화
saveRDS(final_results, sprintf("data/processed/mp_morpheme_results_enhanced_xsn_%s_%s.rds", timestamp, optional_tag))

# CSV 형태로 저장
write.csv(morpheme_results, 
          sprintf("data/processed/mp_morpheme_analysis_%s_%s.csv", timestamp, optional_tag), 
          row.names = FALSE, fileEncoding = "UTF-8")

write.csv(noun_results, 
          sprintf("data/processed/mp_noun_extraction_%s_%s.csv", timestamp, optional_tag), 
          row.names = FALSE, fileEncoding = "UTF-8")

# 02_morpheme_analysis.R과 완전히 동일한 구조로 저장 (기본 파일명)
enhanced_results <- list(
  morpheme_analysis = morpheme_results,
  noun_extraction = noun_results,
  metadata = final_results$metadata
)

# 기존 워크플로우 호환을 위한 동일 구조로 저장 (dict_type 기준)
saveRDS(enhanced_results, sprintf("data/processed/mp_morpheme_results_%s_%s.rds", timestamp, optional_tag))

# 상세 분석 보고서
model_info_text <- if(USE_CONG_MODEL) {
  "**사용 모델**: CoNg 모델 (Contextual N-gram, v0.21.0+)\n**모델 특징**: 향상된 정확도 및 처리 속도\n"
} else {
  "**사용 모델**: 기본 모델\n"
}

dict_info_text <- if(USE_USER_DICT && !is.null(selected_dict)) {
  paste0("**적용 사전**: ", basename(selected_dict), "\n",
         "**사전 파일 크기**: ", sprintf("%.1f KB", file.info(selected_dict)$size/1024), "\n",
         "**사전 생성일**: ", format(file.info(selected_dict)$mtime, "%Y-%m-%d %H:%M"), "\n")
} else {
  "**적용 사전**: 없음\n"
}

report_text <- paste0(
  "# Enhanced XSN Kiwipiepy 형태소 분석 결과\n\n",
  "**분석일**: ", Sys.Date(), "\n",
  "**분석기**: Enhanced XSN Kiwipiepy v2.0\n",
  "**Python 버전**: ", version_str, "\n",
  model_info_text,
  dict_info_text,
  "**전체 문서 수**: ", nrow(analysis_data), "\n",
  "**처리된 문서 수**: ", processed_count, "\n",
  "**성공한 문서 수**: ", success_count, "\n",
  "**오류 발생 문서 수**: ", error_count, "\n",
  "**성공률**: ", sprintf("%.1f%%", (success_count / processed_count) * 100), "\n",
  "**형태소 분석 결과**: ", nrow(morpheme_results), "개\n",
  "**명사 추출 결과**: ", nrow(noun_results), "개\n",
  "**전체 처리 시간**: ", sprintf("%.2f분", total_processing_time / 60), "\n",
  "**평균 처리 속도**: ", sprintf("%.1f 문서/초", processed_count / total_processing_time), "\n\n",
  "## 태그 기반 명사 추출 특징\n",
  "- **XSN 태그 기반**: XSN 명사파생접미사를 태그로 직접 추출\n",
  "- **선행명사 결합**: 선행 명사(NNG/NNP) + XSN 접미사 자동 결합\n", 
  "- **순수 품사 추출**: NNG, NNP, XSN 태그만 사용한 정확한 추출\n",
  "- **워크플로우 호환**: 기존 분석 파이프라인과 완전 호환\n\n"
)

if (nrow(noun_results) > 0) {
  all_nouns <- unlist(strsplit(noun_results$noun_extraction, ", "))
  noun_freq <- table(all_nouns)
  top_nouns <- head(sort(noun_freq, decreasing = TRUE), 20)
  
  report_text <- paste0(report_text, "## 상위 20개 명사 (Enhanced XSN 처리)\n")
  for (i in 1:length(top_nouns)) {
    report_text <- paste0(report_text, i, ". ", names(top_nouns)[i], " (", top_nouns[i], "회)\n")
  }
  
  # XSN 패턴 분석 - 실제 태그 기반
  report_text <- paste0(report_text, "\n## XSN 명사파생접미사 패턴 분석 (태그 기반)\n")
  
  # 형태소 분석 결과에서 XSN 태그 추출
  xsn_morphemes <- c()
  combined_nouns <- c()
  
  for (i in 1:nrow(morpheme_results)) {
    morpheme_text <- morpheme_results$morpheme_analysis[i]
    if (!is.na(morpheme_text) && nchar(morpheme_text) > 0) {
      # 형태소/태그 쌍으로 분리
      morphemes <- unlist(strsplit(morpheme_text, "\\s+"))
      morphemes <- morphemes[nchar(morphemes) > 0]
      
      j <- 1
      while (j <= length(morphemes)) {
        if (grepl("/XSN$", morphemes[j])) {
          xsn_form <- gsub("/XSN$", "", morphemes[j])
          xsn_morphemes <- c(xsn_morphemes, xsn_form)
          
          # 선행 명사와 결합된 형태 찾기
          if (j > 1 && grepl("/(NNG|NNP)$", morphemes[j-1])) {
            noun_form <- gsub("/(NNG|NNP)$", "", morphemes[j-1])
            combined_form <- paste0(noun_form, xsn_form)
            combined_nouns <- c(combined_nouns, combined_form)
          }
        }
        j <- j + 1
      }
    }
  }
  
  # XSN 접미사 빈도 분석
  if (length(xsn_morphemes) > 0) {
    xsn_freq <- table(xsn_morphemes)
    xsn_freq <- sort(xsn_freq, decreasing = TRUE)
    
    report_text <- paste0(report_text, "### 발견된 XSN 접미사 (태그 기반 추출)\n")
    report_text <- paste0(report_text, sprintf("총 XSN 접미사 종류: %d개\n", length(xsn_freq)))
    report_text <- paste0(report_text, sprintf("총 XSN 사용 빈도: %d회\n\n", sum(xsn_freq)))
    
    # 상위 XSN 접미사 보고
    top_xsn <- head(xsn_freq, 15)
    for (i in 1:length(top_xsn)) {
      report_text <- paste0(report_text, sprintf("%d. **%s** (%d회)\n", 
                           i, names(top_xsn)[i], top_xsn[i]))
    }
  } else {
    report_text <- paste0(report_text, "XSN 태그가 발견되지 않았습니다.\n")
  }
  
  # 결합 명사 분석
  if (length(combined_nouns) > 0) {
    combined_freq <- table(combined_nouns)
    combined_freq <- sort(combined_freq, decreasing = TRUE)
    
    report_text <- paste0(report_text, "\n### NNG/NNP + XSN 결합 명사 분석\n")
    report_text <- paste0(report_text, sprintf("총 결합 명사 종류: %d개\n", length(combined_freq)))
    report_text <- paste0(report_text, sprintf("총 결합 명사 빈도: %d회\n\n", sum(combined_freq)))
    
    # 상위 결합 명사
    top_combined <- head(combined_freq, 20)
    for (i in 1:length(top_combined)) {
      report_text <- paste0(report_text, sprintf("%d. **%s** (%d회)\n", 
                           i, names(top_combined)[i], top_combined[i]))
    }
  } else {
    report_text <- paste0(report_text, "\n### NNG/NNP + XSN 결합 명사\n결합 명사가 발견되지 않았습니다.\n")
  }
  
  report_text <- paste0(report_text, "\n## 통계 정보\n")
  report_text <- paste0(report_text, "총 고유 명사 수: ", length(unique(all_nouns)), "\n")
  report_text <- paste0(report_text, "총 명사 빈도: ", length(all_nouns), "\n")
  report_text <- paste0(report_text, "문서당 평균 명사 수: ", sprintf("%.1f", length(all_nouns) / nrow(noun_results)), "\n")
}

# 보고서 파일명에 사전 정보 포함
report_filename <- sprintf("reports/mp_analysis_report_%s_%s.md", timestamp, optional_tag)
writeLines(report_text, report_filename)

# 임시 파일 정리
temp_files <- c("data/processed/temp_enhanced_xsn_results.rds")
for (temp_file in temp_files) {
  if (file.exists(temp_file)) {
    file.remove(temp_file)
    cat("임시 파일 정리:", basename(temp_file), "\n")
  }
}

cat("\n✅ Enhanced XSN Kiwipiepy 형태소 분석 완료!\n")
cat("생성된 파일:\n")
cat(sprintf("- data/processed/mp_morpheme_results_%s_%s.rds (구조화된 결과)\n", timestamp, optional_tag))
cat(sprintf("- data/processed/mp_morpheme_results_enhanced_xsn_%s_%s.rds (상세 결과)\n", timestamp, optional_tag))
cat(sprintf("- data/processed/mp_morpheme_analysis_%s_%s.csv (형태소 분석)\n", timestamp, optional_tag))
cat(sprintf("- data/processed/mp_noun_extraction_%s_%s.csv (명사 추출)\n", timestamp, optional_tag))
cat(sprintf("- %s (분석 보고서)\n", report_filename))

