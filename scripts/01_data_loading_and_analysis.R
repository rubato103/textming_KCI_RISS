# 01_data_loading_and_analysis.R
# 데이터 불러오기, 병합 및 구조 분석 통합 스크립트
# 작성일: 2025-01-08

# ========== 패키지 설치 및 로드 ==========
packages <- c("readxl", "dplyr", "tidyr", "stringr")
for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, repos = "https://cran.seoul.go.kr/")
    library(pkg, character.only = TRUE)
  }
}

# 00_utils.R 로드 (존재하는 경우)
if (file.exists("00_utils.R")) {
  source("00_utils.R")
}

# ========== 환경 설정 ==========
# 작업 디렉토리 설정
setwd(".")

# 데이터 디렉토리 경로
raw_data_path <- "data/raw_data"
processed_data_path <- "data/processed"

# 필요한 디렉토리 생성
if (!dir.exists(processed_data_path)) {
  dir.create(processed_data_path, recursive = TRUE)
  cat("폴더 생성:", processed_data_path, "\n")
}

# reports 폴더도 생성
if (!dir.exists("reports")) {
  dir.create("reports")
  cat("폴더 생성: reports\n")
}

# ========== 데이터 불러오기 ==========
cat("========== 데이터 불러오기 시작 ==========\n")

# raw_data 폴더의 모든 Excel 파일 목록 가져오기
file_list <- list.files(raw_data_path, pattern = "\\.xls$|\\.xlsx$", full.names = TRUE)

cat("발견된 파일 개수:", length(file_list), "\n")
cat("파일 목록:\n")
for (f in file_list) {
  cat(" -", basename(f), "\n")
}

# 데이터 불러오기 함수
load_excel_data <- function(file_path) {
  cat("\n파일 읽기:", basename(file_path), "\n")
  
  # Excel 파일의 모든 시트 이름 가져오기
  sheet_names <- excel_sheets(file_path)
  cat("시트 개수:", length(sheet_names), "\n")
  cat("시트 이름:", paste(sheet_names, collapse = ", "), "\n")
  
  # 첫 번째 시트 읽기 (필요시 모든 시트 읽기로 변경 가능)
  data <- read_excel(file_path, sheet = 1)
  
  # 파일명을 데이터에 추가 (출처 추적용)
  data$source_file <- basename(file_path)
  
  return(data)
}

# ========== 데이터 병합 ==========
if (length(file_list) > 0) {
  # 단일 파일인 경우
  if (length(file_list) == 1) {
    combined_data <- load_excel_data(file_list[1])
  } else {
    # 여러 파일인 경우 병합
    cat("\n여러 파일 병합 중...\n")
    data_list <- lapply(file_list, load_excel_data)
    combined_data <- bind_rows(data_list)
  }
  
  # ========== 데이터 표준화 ==========
  # utils.R이 로드된 경우 데이터 표준화 적용
  if (exists("standardize_data")) {
    combined_data <- standardize_data(combined_data)
  }
  
  # ========== 데이터 구조 분석 ==========
  cat("\n========== 데이터 구조 분석 ==========\n")
  
  # 기본 정보
  total_rows <- nrow(combined_data)
  total_cols <- ncol(combined_data)
  column_names <- colnames(combined_data)
  column_types <- sapply(combined_data, class)
  
  cat("전체 행 수:", total_rows, "\n")
  cat("전체 열 수:", total_cols, "\n")
  
  # 열 정보 상세 분석
  cat("\n========== 열 정보 상세 ==========\n")
  column_info <- data.frame(
    번호 = 1:length(column_names),
    열이름 = column_names,
    데이터타입 = as.character(column_types),
    결측치수 = colSums(is.na(combined_data)),
    결측치비율 = paste0(round(colSums(is.na(combined_data)) / total_rows * 100, 2), "%"),
    고유값수 = sapply(combined_data, function(x) length(unique(x))),
    stringsAsFactors = FALSE
  )
  print(column_info)
  
  # 텍스트 열 식별 (형태소 분석 대상)
  text_columns <- column_names[column_types == "character"]
  cat("\n텍스트 열 (형태소 분석 가능):\n")
  for (col in text_columns) {
    if (col != "source_file") {
      sample_text <- combined_data[[col]][!is.na(combined_data[[col]])][1]
      if (length(sample_text) > 0) {
        # 텍스트가 20자보다 길면 잘라서 표시
        if (nchar(sample_text) > 20) {
          sample_text <- paste0(substr(sample_text, 1, 20), "...")
        }
        cat(sprintf(" - %s: '%s'\n", col, sample_text))
      }
    }
  }
  
  # 데이터 샘플
  cat("\n========== 데이터 샘플 (처음 5행) ==========\n")
  print(head(combined_data[, 1:min(5, ncol(combined_data))], 5))
  
  # ========== 분석 보고서 생성 ==========
  cat("\n========== 분석 보고서 생성 ==========\n")
  
  # 보고서용 데이터 구조화
  report_data <- list(
    file_info = list(
      file_count = length(file_list),
      file_names = basename(file_list),
      total_rows = total_rows,
      total_cols = total_cols
    ),
    column_info = column_info,
    text_columns = text_columns[text_columns != "source_file"],
    sample_data = head(combined_data, 10),
    analysis_date = Sys.Date()
  )
  
  # ========== 데이터 검증 ==========
  if (exists("validate_data")) {
    validate_data(combined_data, "metadata")
  }
  
  # ========== 데이터 저장 ==========
  cat("\n========== 데이터 저장 ==========\n")
  
  # 처리된 데이터 저장 (통일된 파일명 사용)
  if (exists("generate_filename")) {
    # config.R의 함수 사용
    combined_data_rds_filename <- generate_filename(get_config("prefixes", "data_loading"), "combined_data", "rds")
    combined_data_csv_filename <- generate_filename(get_config("prefixes", "data_loading"), "combined_data", "csv")
    data_structure_info_filename <- generate_filename(get_config("prefixes", "data_loading"), "data_structure_info", "rds")
  } else {
    # 기존 방식 (fallback)
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    combined_data_rds_filename <- sprintf("dl_combined_data_%s.rds", timestamp)
    combined_data_csv_filename <- sprintf("dl_combined_data_%s.csv", timestamp)
    data_structure_info_filename <- sprintf("dl_data_structure_info_%s.rds", timestamp)
  }
  
  saveRDS(combined_data, file = file.path(processed_data_path, combined_data_rds_filename))
  write.csv(combined_data, file = file.path(processed_data_path, combined_data_csv_filename), 
            row.names = FALSE, fileEncoding = "UTF-8")
  
  # 분석 보고서 데이터 저장
  saveRDS(report_data, file = file.path(processed_data_path, data_structure_info_filename))
  
  # Markdown 보고서 생성 (통일된 파일명 사용)
  if (exists("generate_filename")) {
    report_filename <- generate_filename(get_config("prefixes", "data_loading"), "data_structure_summary", "md")
  } else {
    report_filename <- sprintf("dl_data_structure_summary_%s.md", get_timestamp())
  }
  report_text <- paste0(
    "# 데이터 구조 분석 보고서 (자동 생성)\n\n",
    "**분석일**: ", Sys.Date(), "\n",
    "**분석 스크립트**: 01_data_loading_and_analysis.R\n\n",
    "## 데이터 요약\n",
    "- 파일 수: ", length(file_list), "\n",
    "- 전체 행 수: ", format(total_rows, big.mark = ","), "\n",
    "- 전체 열 수: ", total_cols, "\n\n",
    "## 형태소 분석 가능 텍스트 열\n"
  )
  
  for (col in text_columns[text_columns != "source_file"]) {
    report_text <- paste0(report_text, "- ", col, "\n")
  }
  
  report_text <- paste0(report_text, "\n## 열 정보 요약\n",
                       "| 열 이름 | 데이터 타입 | 결측치 비율 | 고유값 수 |\n",
                       "|---------|------------|------------|----------|\n")
  
  for (i in 1:nrow(column_info)) {
    if (column_info$열이름[i] != "source_file") {
      report_text <- paste0(report_text, 
                           "| ", column_info$열이름[i], 
                           " | ", column_info$데이터타입[i],
                           " | ", column_info$결측치비율[i],
                           " | ", format(column_info$고유값수[i], big.mark = ","),
                           " |\n")
                           
    }
  }
  
  writeLines(report_text, file.path("reports", report_filename))
  
  cat(sprintf("\n완료! 다음 파일이 생성되었습니다:\n"))
  cat(sprintf("- 데이터: %s\n", file.path(processed_data_path, combined_data_rds_filename)))
  cat(sprintf("- CSV: %s\n", file.path(processed_data_path, combined_data_csv_filename)))
  cat(sprintf("- 분석 정보: %s\n", file.path(processed_data_path, data_structure_info_filename)))
  cat(sprintf("- 보고서: %s\n", file.path("reports", report_filename)))
  
} else {
  cat("raw_data 폴더에 Excel 파일이 없습니다.\n")
}
