# run_pipeline.R
# 한국어 형태소 분석 파이프라인 자동 실행 스크립트
# 작성일: 2025-01-09

# ========== 파이프라인 실행 함수 ==========
run_morpheme_analysis_pipeline <- function(
  steps = 1:5,  # 실행할 단계 (1:데이터로딩, 2:형태소분석, 3:N그램분석, 4:DTM생성, 5:토픽모델링)
  auto_mode = TRUE,  # 자동 모드 (비대화형)
  config_file = "config.R",
  use_user_dict = FALSE,
  skip_ngram = FALSE  # N그램 분석 건너뛰기
) {
  
  cat("========== 한국어 형태소 분석 파이프라인 시작 ==========\n")
  cat("실행 모드:", ifelse(auto_mode, "자동", "대화형"), "\n")
  cat("실행 단계:", paste(steps, collapse = ", "), "\n\n")
  
  # 환경 변수 설정 (비대화형 모드)
  if (auto_mode) {
    Sys.setenv(INTERACTIVE_MODE = "FALSE")
    Sys.setenv(USE_USER_DICT = as.character(use_user_dict))
  }
  
  pipeline_start_time <- Sys.time()
  results <- list()
  
  tryCatch({
    # 1단계: 데이터 로딩 및 분석
    if (1 %in% steps) {
      cat("========== 1단계: 데이터 로딩 및 분석 ==========\n")
      step1_start <- Sys.time()
      
      source("01_data_loading_and_analysis.R", local = TRUE)
      
      step1_end <- Sys.time()
      results$step1 <- list(
        status = "completed",
        duration = as.numeric(difftime(step1_end, step1_start, units = "mins"))
      )
      cat(sprintf("✅ 1단계 완료 (%.1f분 소요)\n\n", results$step1$duration))
    }
    
    # 2단계: 형태소 분석
    if (2 %in% steps) {
      cat("========== 2단계: 형태소 분석 ==========\n")
      step2_start <- Sys.time()
      
      # 02 스크립트를 비대화형 모드로 실행
      if (auto_mode) {
        # 자동 모드에서는 기본 설정 사용
        Sys.setenv(MORPHEME_MODEL = "default")
        Sys.setenv(MORPHEME_CORES = "auto")
      }
      
      source("02_kiwipiepy_mopheme_analysis.R", local = TRUE)
      
      step2_end <- Sys.time()
      results$step2 <- list(
        status = "completed",
        duration = as.numeric(difftime(step2_end, step2_start, units = "mins"))
      )
      cat(sprintf("✅ 2단계 완료 (%.1f분 소요)\n\n", results$step2$duration))
    }
    
    # 3단계: N그램 분석 (선택적)
    if (3 %in% steps && !skip_ngram) {
      cat("========== 3단계: N그램 분석 ==========\n")
      step3_start <- Sys.time()
      
      if (auto_mode) {
        # 자동 모드에서는 기본 N그램 설정 사용
        Sys.setenv(NGRAM_VALUES = "2,3")
        Sys.setenv(MIN_FREQUENCY = "3")
      }
      
      tryCatch({
        source("03-1_ngram_analysis.R", local = TRUE)
        step3_end <- Sys.time()
        results$step3 <- list(
          status = "completed", 
          duration = as.numeric(difftime(step3_end, step3_start, units = "mins"))
        )
        cat(sprintf("✅ 3단계 완료 (%.1f분 소요)\n\n", results$step3$duration))
      }, error = function(e) {
        cat("⚠️ 3단계 건너뜀:", e$message, "\n")
        results$step3 <<- list(status = "skipped", error = e$message)
      })
    } else if (3 %in% steps && skip_ngram) {
      cat("⚠️ 3단계 (N그램 분석) 건너뜀\n\n")
      results$step3 <- list(status = "skipped", reason = "user_request")
    }
    
    # 4단계: DTM 생성
    if (4 %in% steps) {
      cat("========== 4단계: DTM 생성 ==========\n")
      step4_start <- Sys.time()
      
      if (auto_mode) {
        # 자동 모드에서는 기본 DTM 설정 사용
        Sys.setenv(DTM_AUTO_FILTER = "TRUE")
        Sys.setenv(MIN_TERM_FREQ = "2")
      }
      
      source("04_dtm_creation_interactive.R", local = TRUE)
      
      step4_end <- Sys.time()
      results$step4 <- list(
        status = "completed",
        duration = as.numeric(difftime(step4_end, step4_start, units = "mins"))
      )
      cat(sprintf("✅ 4단계 완료 (%.1f분 소요)\n\n", results$step4$duration))
    }
    
    # 5단계: STM 토픽 모델링
    if (5 %in% steps) {
      cat("========== 5단계: STM 토픽 모델링 ==========\n")
      step5_start <- Sys.time()
      
      if (auto_mode) {
        # 자동 모드에서는 기본 토픽 수 사용
        Sys.setenv(STM_TOPICS = "10")
        Sys.setenv(STM_AUTO_SELECT = "TRUE")
      }
      
      source("05_stm_topic_modeling.R", local = TRUE)
      
      step5_end <- Sys.time()
      results$step5 <- list(
        status = "completed",
        duration = as.numeric(difftime(step5_end, step5_start, units = "mins"))
      )
      cat(sprintf("✅ 5단계 완료 (%.1f분 소요)\n\n", results$step5$duration))
    }
    
  }, error = function(e) {
    cat("❌ 파이프라인 실행 중 오류 발생:\n")
    cat("오류 메시지:", e$message, "\n")
    cat("파이프라인을 중단합니다.\n")
    return(list(status = "failed", error = e$message, results = results))
  })
  
  pipeline_end_time <- Sys.time()
  total_duration <- as.numeric(difftime(pipeline_end_time, pipeline_start_time, units = "mins"))
  
  # 결과 요약
  cat("========== 파이프라인 실행 완료 ==========\n")
  cat(sprintf("총 소요 시간: %.1f분\n", total_duration))
  cat("단계별 결과:\n")
  
  for (step_name in names(results)) {
    result <- results[[step_name]]
    if (result$status == "completed") {
      cat(sprintf("  %s: ✅ 완료 (%.1f분)\n", step_name, result$duration))
    } else if (result$status == "skipped") {
      reason <- if(!is.null(result$reason)) result$reason else "오류"
      cat(sprintf("  %s: ⚠️ 건너뜀 (%s)\n", step_name, reason))
    }
  }
  
  # 생성된 파일 요약
  cat("\n생성된 파일 확인:\n")
  check_pipeline_outputs()
  
  final_results <- list(
    status = "completed",
    total_duration = total_duration,
    steps = results,
    timestamp = Sys.time()
  )
  
  return(final_results)
}

# ========== 파이프라인 출력 파일 확인 ==========
check_pipeline_outputs <- function() {
  # 각 단계별 예상 출력 파일 확인
  output_checks <- list(
    "1단계 (데이터로딩)" = list(
      pattern = "dl_combined_data_.*\\.rds",
      path = "data/processed"
    ),
    "2단계 (형태소분석)" = list(
      pattern = "mp_morpheme_results_.*\\.rds",
      path = "data/processed" 
    ),
    "3단계 (N그램분석)" = list(
      pattern = "ng_.*_candidates_.*\\.csv",
      path = "data/dictionaries/dict_candidates"
    ),
    "4단계 (DTM생성)" = list(
      pattern = "dtm_results_.*\\.rds",
      path = "data/processed"
    ),
    "5단계 (토픽모델링)" = list(
      pattern = "stm_results_.*\\.rds", 
      path = "data/processed"
    )
  )
  
  for (step_name in names(output_checks)) {
    check <- output_checks[[step_name]]
    if (dir.exists(check$path)) {
      files <- list.files(check$path, pattern = check$pattern)
      if (length(files) > 0) {
        latest_file <- files[order(file.mtime(file.path(check$path, files)), decreasing = TRUE)][1]
        cat(sprintf("  %s: ✅ %s\n", step_name, latest_file))
      } else {
        cat(sprintf("  %s: ❌ 파일 없음\n", step_name))
      }
    } else {
      cat(sprintf("  %s: ❌ 경로 없음\n", step_name))
    }
  }
}

# ========== 편의 함수들 ==========

# 전체 파이프라인 자동 실행
run_full_pipeline <- function(use_user_dict = FALSE) {
  return(run_morpheme_analysis_pipeline(
    steps = 1:5,
    auto_mode = TRUE,
    use_user_dict = use_user_dict
  ))
}

# N그램 제외 파이프라인 실행
run_pipeline_no_ngram <- function(use_user_dict = FALSE) {
  return(run_morpheme_analysis_pipeline(
    steps = c(1, 2, 4, 5),
    auto_mode = TRUE,
    use_user_dict = use_user_dict,
    skip_ngram = TRUE
  ))
}

# 형태소 분석까지만 실행
run_morpheme_only <- function() {
  return(run_morpheme_analysis_pipeline(
    steps = 1:2,
    auto_mode = TRUE
  ))
}

# 대화형 모드 실행
run_interactive_pipeline <- function(steps = 1:5) {
  return(run_morpheme_analysis_pipeline(
    steps = steps,
    auto_mode = FALSE
  ))
}

# ========== 사용법 출력 ==========
print_usage <- function() {
  cat("========== 파이프라인 실행 스크립트 사용법 ==========\n")
  cat("주요 함수:\n")
  cat("  - run_full_pipeline(): 전체 파이프라인 자동 실행\n")
  cat("  - run_pipeline_no_ngram(): N그램 분석 제외하고 실행\n")
  cat("  - run_morpheme_only(): 형태소 분석까지만 실행\n") 
  cat("  - run_interactive_pipeline(): 대화형 모드로 실행\n")
  cat("  - check_pipeline_outputs(): 생성된 파일 확인\n")
  cat("\n사용 예시:\n")
  cat("  source('run_pipeline.R')\n")
  cat("  result <- run_full_pipeline()  # 전체 자동 실행\n")
  cat("  result <- run_morpheme_only()  # 형태소 분석까지만\n")
  cat("=====================================================\n")
}

# 스크립트 로드 시 사용법 출력
cat("✅ run_pipeline.R 로드 완료\n\n")
print_usage()