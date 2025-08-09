# config.R
# 한국어 형태소 분석 프로젝트 통합 설정 파일
# 작성일: 2025-01-09

# ========== 프로젝트 설정 ==========
PROJECT_CONFIG <- list(
  # 기본 정보
  project_name = "Korean Morpheme Analysis",
  version = "1.1.0",
  encoding = "UTF-8",
  
  # 경로 설정
  paths = list(
    raw_data = "data/raw_data",
    processed_data = "data/processed", 
    dictionaries = "data/dictionaries",
    dict_candidates = "data/dictionaries/dict_candidates",
    reports = "reports",
    plots = "plots"
  ),
  
  # 파일 패턴 설정
  file_patterns = list(
    # 입력 파일 패턴
    excel_files = "\\.(xls|xlsx)$",
    combined_data = "^dl_combined_data_.*\\.rds$",
    morpheme_results = "^mp_morpheme_results_.*\\.rds$", 
    noun_extraction = "^mp_noun_extraction_.*\\.csv$",
    dtm_results = "^dtm_results_.*\\.rds$",
    stm_results = "^stm_results_.*\\.rds$",
    
    # 사전 관련 패턴
    compound_candidates = "^ng_compound_nouns_candidates_.*\\.csv$",
    proper_candidates = "^ng_proper_nouns_candidates_.*\\.csv$", 
    user_dict = "^user_dict_.*\\.txt$"
  ),
  
  # 파일명 접두사 (통일된 명명 규칙)
  prefixes = list(
    data_loading = "dl",      # 01_data_loading_and_analysis.R
    morpheme = "mp",          # 02_kiwipiepy_morpheme_analysis.R
    ngram = "ng",             # 03-1_ngram_analysis.R
    dict = "dict",            # 03-3_create_user_dict.R
    dtm = "dtm",              # 04_dtm_creation_interactive.R
    stm = "stm"               # 05_stm_topic_modeling.R
  ),
  
  # 기본 설정
  defaults = list(
    use_latest_file = TRUE,
    interactive_mode = TRUE,
    backup_files = TRUE,
    validate_data = TRUE,
    create_reports = TRUE,
    
    # 타임스탬프 형식
    timestamp_format = "%Y%m%d_%H%M%S",
    date_format = "%Y-%m-%d"
  ),
  
  # 형태소 분석 설정
  morpheme_analysis = list(
    default_model = "kiwipiepy",
    use_cong_model = FALSE,
    use_user_dict = FALSE,
    parallel_cores = "auto",  # "auto", 숫자, 또는 NULL
    batch_size = "auto"       # "auto" 또는 숫자
  ),
  
  # N그램 분석 설정
  ngram_analysis = list(
    default_n_values = c(2, 3),
    min_frequency = 3,
    max_candidates = 1000,
    filter_korean_only = TRUE,
    remove_single_char = TRUE
  ),
  
  # DTM 생성 설정
  dtm_creation = list(
    min_term_freq = 2,
    max_term_freq = 0.95,
    remove_punctuation = TRUE,
    remove_numbers = FALSE,
    to_lower = FALSE,
    
    # 필터링 옵션
    auto_remove_chinese = TRUE,
    auto_remove_english = TRUE,
    auto_remove_numbers = TRUE
  ),
  
  # STM 토픽 모델링 설정
  stm_modeling = list(
    default_k = 10,           # 기본 토픽 수
    k_range = c(5, 20),       # 토픽 수 범위
    max_iterations = 100,
    seed = 12345,
    
    # 메타데이터 설정
    prevalence_vars = c("pub_year"),
    content_vars = NULL
  )
)

# ========== 환경 변수 설정 ==========
# 환경 변수로 설정 재정의 가능
override_from_env <- function() {
  # 병렬 처리 코어 수
  if (Sys.getenv("MORPHEME_CORES") != "") {
    PROJECT_CONFIG$morpheme_analysis$parallel_cores <<- as.numeric(Sys.getenv("MORPHEME_CORES"))
  }
  
  # 대화형 모드
  if (Sys.getenv("INTERACTIVE_MODE") != "") {
    PROJECT_CONFIG$defaults$interactive_mode <<- as.logical(Sys.getenv("INTERACTIVE_MODE"))
  }
  
  # 사용자 사전 사용
  if (Sys.getenv("USE_USER_DICT") != "") {
    PROJECT_CONFIG$morpheme_analysis$use_user_dict <<- as.logical(Sys.getenv("USE_USER_DICT"))
  }
}

# ========== 설정 유틸리티 함수 ==========

# 경로 생성 함수
ensure_directories <- function() {
  paths_to_create <- unlist(PROJECT_CONFIG$paths)
  
  for (path in paths_to_create) {
    if (!dir.exists(path)) {
      dir.create(path, recursive = TRUE)
      cat(sprintf("✅ 디렉토리 생성: %s\n", path))
    }
  }
}

# 설정값 가져오기 함수
get_config <- function(category, item = NULL) {
  if (is.null(item)) {
    return(PROJECT_CONFIG[[category]])
  } else {
    return(PROJECT_CONFIG[[category]][[item]])
  }
}

# 설정값 설정하기 함수
set_config <- function(category, item, value) {
  PROJECT_CONFIG[[category]][[item]] <<- value
  cat(sprintf("✅ 설정 변경: %s.%s = %s\n", category, item, value))
}

# 파일 경로 생성 함수
get_file_path <- function(type, filename = NULL, create_dir = FALSE) {
  base_path <- switch(type,
    "raw_data" = PROJECT_CONFIG$paths$raw_data,
    "processed" = PROJECT_CONFIG$paths$processed_data,
    "dict" = PROJECT_CONFIG$paths$dictionaries,
    "dict_candidates" = PROJECT_CONFIG$paths$dict_candidates,
    "reports" = PROJECT_CONFIG$paths$reports,
    "plots" = PROJECT_CONFIG$paths$plots,
    "."  # 기본값: 현재 디렉토리
  )
  
  if (create_dir && !dir.exists(base_path)) {
    dir.create(base_path, recursive = TRUE)
  }
  
  if (is.null(filename)) {
    return(base_path)
  } else {
    return(file.path(base_path, filename))
  }
}

# 표준 파일명 생성 함수
generate_filename <- function(prefix, suffix = "", extension = "rds") {
  timestamp <- format(Sys.time(), PROJECT_CONFIG$defaults$timestamp_format)
  
  if (suffix != "") {
    filename <- sprintf("%s_%s_%s.%s", prefix, timestamp, suffix, extension)
  } else {
    filename <- sprintf("%s_%s.%s", prefix, timestamp, extension)
  }
  
  return(filename)
}

# 최신 파일 찾기 (설정 기반)
find_latest_file <- function(pattern_name, path_type = "processed") {
  pattern <- PROJECT_CONFIG$file_patterns[[pattern_name]]
  path <- PROJECT_CONFIG$paths[[paste0(path_type, "_data")]]
  
  if (path_type == "processed") {
    path <- PROJECT_CONFIG$paths$processed_data
  } else if (path_type == "dict_candidates") {
    path <- PROJECT_CONFIG$paths$dict_candidates
  }
  
  files <- list.files(path, pattern = pattern, full.names = TRUE)
  
  if (length(files) == 0) {
    return(NULL)
  }
  
  # 수정 시간 기준 정렬
  files <- files[order(file.mtime(files), decreasing = TRUE)]
  
  return(files[1])
}

# ========== 설정 검증 ==========
validate_config <- function() {
  cat("========== 설정 검증 ==========\n")
  
  validation_results <- list()
  
  # 필수 경로 존재 확인
  for (path_name in names(PROJECT_CONFIG$paths)) {
    path <- PROJECT_CONFIG$paths[[path_name]]
    validation_results[[paste0("path_", path_name)]] <- dir.exists(path) || path_name == "raw_data"
  }
  
  # 설정값 타입 확인
  validation_results$valid_cores <- is.numeric(PROJECT_CONFIG$morpheme_analysis$parallel_cores) || 
                                   PROJECT_CONFIG$morpheme_analysis$parallel_cores == "auto"
  
  validation_results$valid_timestamp <- !is.null(PROJECT_CONFIG$defaults$timestamp_format)
  
  # 결과 출력
  all_valid <- all(unlist(validation_results))
  
  if (all_valid) {
    cat("✅ 모든 설정 검증 통과\n")
  } else {
    cat("❌ 설정 검증 실패 항목:\n")
    for (check in names(validation_results)) {
      if (!validation_results[[check]]) {
        cat(sprintf("  - %s\n", check))
      }
    }
  }
  
  cat("===============================\n")
  
  return(all_valid)
}

# ========== 설정 초기화 ==========
initialize_config <- function() {
  cat("========== 프로젝트 설정 초기화 ==========\n")
  cat(sprintf("프로젝트: %s v%s\n", PROJECT_CONFIG$project_name, PROJECT_CONFIG$version))
  
  # 환경 변수에서 설정 재정의
  override_from_env()
  
  # 디렉토리 생성
  ensure_directories()
  
  # 설정 검증
  validate_config()
  
  cat("✅ 프로젝트 설정 초기화 완료\n")
  cat("=========================================\n\n")
}

# ========== 디버깅 함수 ==========
print_config <- function(category = NULL) {
  if (is.null(category)) {
    str(PROJECT_CONFIG)
  } else {
    str(PROJECT_CONFIG[[category]])
  }
}

# ========== 자동 초기화 ==========
# config.R이 source될 때 자동으로 초기화 수행
cat("✅ config.R 로드 완료\n")
cat("사용 가능한 함수:\n")
cat("  - initialize_config(): 프로젝트 설정 초기화\n") 
cat("  - get_config(category, item): 설정값 조회\n")
cat("  - set_config(category, item, value): 설정값 변경\n")
cat("  - get_file_path(type, filename): 파일 경로 생성\n")
cat("  - generate_filename(prefix, suffix): 표준 파일명 생성\n")
cat("  - find_latest_file(pattern_name): 최신 파일 찾기\n\n")