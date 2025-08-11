# 03-2_create_user_dict.R
# 사용자 검토 완료된 후보 단어를 바탕으로 Kiwipiepy 사용자 사전을 생성합니다.
# 기능: 복합명사, 고유명사 후보 CSV를 통합하여 최종 사전 파일(.txt) 생성
# 개선: 대화형 사전 이름 설정 기능 추가, 인코딩 문제 해결
# 작성일: 2025-08-09

# ========== 패키지 로드 ==========
library(dplyr)
library(stringr)

cat("========== Kiwipiepy 사용자 사전 생성 (대화형) ==========\n")

# ========== 환경 설정 ==========
if (!endsWith(getwd(), "mopheme_test")) {
  script_path <- commandArgs(trailingOnly = FALSE)
  script_dir <- dirname(sub("--file=", "", script_path[grep("--file", script_path)]))
  if (length(script_dir) > 0 && script_dir != "") {
    setwd(script_dir)
  }
}
cat("작업 디렉토리:", getwd(), "\n")

# 입출력 경로 설정
candidates_path <- "data/dictionaries/dict_candidates/"
output_path <- "data/dictionaries/"

# 결과 저장 폴더 생성
if (!dir.exists(output_path)) dir.create(output_path, recursive = TRUE)

# ========== 후보 파일 검색 ==========
cat("\n========== 1단계: 사전 후보 파일 검색 ==========\n")

# 사용 가능한 후보 파일 찾기
compound_files <- list.files(candidates_path, pattern = "ng_compound_nouns_candidates_.*\\.csv$", full.names = TRUE)
proper_files <- list.files(candidates_path, pattern = "ng_proper_nouns_candidates_.*\\.csv$", full.names = TRUE)

if (length(compound_files) == 0 && length(proper_files) == 0) {
  stop("사전 후보 파일을 찾을 수 없습니다. 03_ngram_analysis.R를 먼저 실행하세요.")
}

# 사용 가능한 파일 표시
cat("\n사용 가능한 후보 파일:\n")
all_files <- c(compound_files, proper_files)
for (i in seq_along(all_files)) {
  file_info <- file.info(all_files[i])
  file_type <- ifelse(grepl("compound", all_files[i]), "[복합명사]", "[고유명사]")
  cat(sprintf("%s %s (%.1f KB, %s)\n", 
              file_type, basename(all_files[i]), 
              file_info$size/1024,
              format(file_info$mtime, "%Y-%m-%d %H:%M")))
}

# 파일 선택 방식
cat("\n파일 선택 방식:\n")
cat("1. 최신 파일 자동 선택 (추천)\n")
cat("2. 수동으로 파일 선택\n")

file_choice <- readline(prompt = "선택 (1 또는 2): ")

if (file_choice == "2") {
  # 수동 선택 모드
  cat("\n복합명사 파일 선택:\n")
  if (length(compound_files) > 0) {
    for (i in seq_along(compound_files)) {
      cat(sprintf("%d. %s\n", i, basename(compound_files[i])))
    }
    cat(sprintf("%d. 사용 안함\n", length(compound_files) + 1))
    
    compound_choice <- readline(prompt = sprintf("선택 (1-%d): ", length(compound_files) + 1))
    if (compound_choice %in% as.character(1:length(compound_files))) {
      selected_compound_files <- c(compound_files[as.numeric(compound_choice)])
    } else {
      selected_compound_files <- c()
    }
  }
  
  cat("\n고유명사 파일 선택:\n")
  if (length(proper_files) > 0) {
    for (i in seq_along(proper_files)) {
      cat(sprintf("%d. %s\n", i, basename(proper_files[i])))
    }
    cat(sprintf("%d. 사용 안함\n", length(proper_files) + 1))
    
    proper_choice <- readline(prompt = sprintf("선택 (1-%d): ", length(proper_files) + 1))
    if (proper_choice %in% as.character(1:length(proper_files))) {
      selected_proper_files <- c(proper_files[as.numeric(proper_choice)])
    } else {
      selected_proper_files <- c()
    }
  }
} else {
  # 자동 선택 (최신 파일)
  selected_compound_files <- if(length(compound_files) > 0) c(compound_files[which.max(file.mtime(compound_files))]) else c()
  selected_proper_files <- if(length(proper_files) > 0) c(proper_files[which.max(file.mtime(proper_files))]) else c()
  cat("-> 최신 파일들을 자동 선택했습니다.\n")
}

# ========== 데이터 로드 및 통합 ==========
cat("\n========== 2단계: 데이터 로드 및 통합 ==========\n")
all_words <- data.frame()

# 1. 복합명사 처리
if (length(selected_compound_files) > 0) {
  cat(sprintf("복합명사 파일 로드: %d개 파일\n", length(selected_compound_files)))
  
  total_compound_words <- 0
  for (comp_file in selected_compound_files) {
    cat(sprintf("   처리 중: %s\n", basename(comp_file)))
    
    tryCatch({
      compound_df <- read.csv(comp_file, fileEncoding = "UTF-8", stringsAsFactors = FALSE)
      
      if (nrow(compound_df) > 0 && "ngram" %in% names(compound_df)) {
        # pos_tag가 없으면 기본값 설정
        if (!"pos_tag" %in% names(compound_df)) {
          compound_df$pos_tag <- "NNG"
        }
        
        # 데이터 정리 및 변환
        compound_words <- compound_df[!is.na(compound_df$ngram) & compound_df$ngram != "", ]
        if (nrow(compound_words) > 0) {
          compound_words <- data.frame(
            word = gsub("\\s+", "", compound_words$ngram), # 공백 제거
            tag = ifelse(is.na(compound_words$pos_tag) | compound_words$pos_tag == "", "NNG", compound_words$pos_tag),
            score = 0.0,
            stringsAsFactors = FALSE
          )
        } else {
          compound_words <- data.frame(word = character(0), tag = character(0), score = numeric(0))
        }
        
        all_words <- rbind(all_words, compound_words)
        total_compound_words <- total_compound_words + nrow(compound_words)
        cat(sprintf("     -> %d개 단어 추가\n", nrow(compound_words)))
      } else {
        cat(sprintf("     -> 빈 파일이거나 형식 오류\n"))
      }
    }, error = function(e) {
      cat(sprintf("     -> 오류: %s\n", e$message))
    })
  }
  
  cat(sprintf("   총 복합명사 %d개 추가 (%d개 파일에서)\n", total_compound_words, length(selected_compound_files)))
} else {
  cat("복합명사 파일 없음 (건너뜀)\n")
}

# 2. 고유명사 처리
if (length(selected_proper_files) > 0) {
  cat(sprintf("고유명사 파일 로드: %d개 파일\n", length(selected_proper_files)))
  
  total_proper_words <- 0
  for (prop_file in selected_proper_files) {
    cat(sprintf("   처리 중: %s\n", basename(prop_file)))
    
    tryCatch({
      proper_df <- read.csv(prop_file, fileEncoding = "UTF-8", stringsAsFactors = FALSE)
      
      if (nrow(proper_df) > 0 && "noun" %in% names(proper_df)) {
        # pos_tag가 없으면 기본값 설정
        if (!"pos_tag" %in% names(proper_df)) {
          proper_df$pos_tag <- "NNP"
        }
        
        # 데이터 정리 및 변환
        proper_words <- proper_df[!is.na(proper_df$noun) & proper_df$noun != "", ]
        if (nrow(proper_words) > 0) {
          proper_words <- data.frame(
            word = gsub("\\s+", "", proper_words$noun), # 공백 제거
            tag = ifelse(is.na(proper_words$pos_tag) | proper_words$pos_tag == "", "NNP", proper_words$pos_tag),
            score = 0.0,
            stringsAsFactors = FALSE
          )
        } else {
          proper_words <- data.frame(word = character(0), tag = character(0), score = numeric(0))
        }
        
        all_words <- rbind(all_words, proper_words)
        total_proper_words <- total_proper_words + nrow(proper_words)
        cat(sprintf("     -> %d개 단어 추가\n", nrow(proper_words)))
      } else {
        cat(sprintf("     -> 빈 파일이거나 형식 오류\n"))
      }
    }, error = function(e) {
      cat(sprintf("     -> 오류: %s\n", e$message))
    })
  }
  
  cat(sprintf("   총 고유명사 %d개 추가 (%d개 파일에서)\n", total_proper_words, length(selected_proper_files)))
} else {
  cat("고유명사 파일 없음 (건너뜀)\n")
}

# ========== 기존 사전 병합 확인 ==========
if (nrow(all_words) == 0) {
  stop("사전에 추가할 단어가 없습니다. 작업을 종료합니다.")
}

# 기존 사전 파일 확인
existing_dict_files <- list.files(output_path, pattern = "^kiwi_user_dict_.*\.txt$", full.names = TRUE)

MERGE_MODE <- FALSE
if (length(existing_dict_files) > 0) {
  cat("\n========== 기존 사전 병합 옵션 ==========\n")
  cat(sprintf("새로 추가할 단어: %d개\n", nrow(all_words)))
  cat(sprintf("기존 사전 파일: %d개 발견\n", length(existing_dict_files)))
  
  cat("\n기존 사전 파일 목록:\n")
  for (i in seq_along(existing_dict_files)) {
    file_info <- file.info(existing_dict_files[i])
    cat(sprintf("%d. %s (%.1f KB, %s)\n", 
                i, basename(existing_dict_files[i]), 
                file_info$size/1024,
                format(file_info$mtime, "%Y-%m-%d %H:%M")))
  }
  
  cat("\n기존 사전과 병합하시겠습니까?\n")
  cat("1. 예 - 기존 사전과 병합 (추가 단어만 병합)\n")
  cat("2. 아니오 - 새 사전 파일 생성\n")
  
  merge_choice <- readline(prompt = "선택 (1 또는 2): ")
  
  if (merge_choice == "1") {
    # 병합할 기존 사전 선택
    if (length(existing_dict_files) == 1) {
      base_dict_file <- existing_dict_files[1]
      cat(sprintf("-> 기존 사전 선택됨: %s\n", basename(base_dict_file)))
    } else {
      cat("\n병합할 기존 사전을 선택하세요:\n")
      for (i in seq_along(existing_dict_files)) {
        cat(sprintf("%d. %s\n", i, basename(existing_dict_files[i])))
      }
      cat(sprintf("%d. 최신 사전 자동 선택\n", length(existing_dict_files) + 1))
      
      base_dict_choice <- readline(prompt = sprintf("선택 (1-%d): ", length(existing_dict_files) + 1))
      
      if (base_dict_choice == as.character(length(existing_dict_files) + 1)) {
        base_dict_file <- existing_dict_files[which.max(file.mtime(existing_dict_files))]
        cat("-> 최신 사전 선택됨\n")
      } else if (base_dict_choice %in% as.character(1:length(existing_dict_files))) {
        base_dict_file <- existing_dict_files[as.numeric(base_dict_choice)]
      } else {
        base_dict_file <- existing_dict_files[which.max(file.mtime(existing_dict_files))]
        cat("-> 잘못된 선택, 최신 사전을 사용합니다\n")
      }
    }
    
    # 기존 사전 내용 로드
    cat(sprintf("\n기존 사전 로드: %s\n", basename(base_dict_file)))
    existing_dict_content <- read.table(base_dict_file, sep = "\t", header = FALSE, 
                                       fileEncoding = "UTF-8", stringsAsFactors = FALSE)
    
    # 컬럼명 통일
    if (ncol(existing_dict_content) >= 3) {
      names(existing_dict_content) <- c("word", "tag", "score")
    } else if (ncol(existing_dict_content) >= 2) {
      names(existing_dict_content) <- c("word", "tag")
      existing_dict_content$score <- 0.0
    } else {
      stop("기존 사전 파일 형식이 올바르지 않습니다.")
    }
    
    cat(sprintf("   기존 단어 수: %d개\n", nrow(existing_dict_content)))
    
    # 신규 단어와 병합 (중복 제거)
    combined_words <- rbind(existing_dict_content, all_words)
    # 중복 제거 (단어 기준)
    all_words <- combined_words[!duplicated(combined_words$word), ]
    # 정렬
    all_words <- all_words[order(all_words$word), ]
    
    cat(sprintf("   병합 후 총 단어 수: %d개\n", nrow(all_words)))
    cat(sprintf("   실제 추가된 단어: %d개\n", nrow(all_words) - nrow(existing_dict_content)))
    
    # 병합된 사전의 새 이름 생성
    base_name <- gsub("kiwi_user_dict_|\.txt$", "", basename(base_dict_file))
    date_suffix <- format(Sys.Date(), "%Y%m%d")
    default_name <- sprintf("kiwi_user_dict_%s_merged_%s", base_name, date_suffix)
    
    MERGE_MODE <- TRUE
  } else {
    cat("-> 새 사전 파일을 생성합니다.\n")
  }
} else {
  cat("\n기존 사전 파일이 없습니다. 새 사전을 생성합니다.\n")
}

# ========== 사용자 사전 이름 설정 ==========
cat("\n========== 3단계: 사용자 사전 이름 설정 ==========\n")
if (MERGE_MODE) {
  cat(sprintf("병합 모드: 총 %d개 단어 (기존 + 신규)\n", nrow(all_words)))
} else {
  cat(sprintf("신규 생성: 총 %d개 단어\n", nrow(all_words)))
}
cat("생성할 사전의 이름을 설정하세요.\n")

# 기본 이름 제안 (병합 모드가 아닌 경우에만)
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

# 기본 이름 제안 (병합 모드가 아닌 경우에만)
if (!MERGE_MODE) {
  default_name_base <- "default"
} else {
  default_name_base <- sprintf("%s_merged", base_name)
}
default_name <- sprintf("ud_user_dict_%s_%s", default_name_base, timestamp)

cat(sprintf("\n1. 기본 이름 사용: %s (추천)\n", default_name))
cat("2. 사용자 정의 이름 입력\n")

name_choice <- readline(prompt = "선택 (1 또는 2): ")

if (name_choice == "2") {
  # 사용자 정의 이름
  cat("\n사용자 정의 이름을 입력하세요:\n")
  cat("규칙:\n")
  cat("   - 영문, 숫자, 언더스코어(_), 하이픈(-)만 사용\n")
  cat("   - 공백 없이 입력하세요\n")
  cat("   - 예: educational_terms, my_dict_v1, specialized_vocab\n")
  
  custom_name <- readline(prompt = "사전 이름: ")
  
  # 입력값 검증 및 정리
  if (nchar(str_trim(custom_name)) == 0) {
    cat("빈 이름입니다. 기본 이름을 사용합니다.\n")
    optional_tag <- default_name_base
  } else {
    # 특수문자 제거 및 정리
    cleaned_name <- str_replace_all(str_trim(custom_name), "[^a-zA-Z0-9_-]", "_")
    cleaned_name <- str_replace_all(cleaned_name, "_+$", "_") # 연속 언더스코어 제거
    cleaned_name <- str_replace_all(cleaned_name, "^[_]|[_]$", "") # 앞뒤 언더스코어 제거
    optional_tag <- cleaned_name
    cat(sprintf("-> 정리된 사전 태그: %s\n", optional_tag))
  }
  dict_name <- sprintf("ud_user_dict_%s_%s", optional_tag, timestamp)
} else {
  # 기본 이름
  optional_tag <- default_name_base
  dict_name <- default_name
  cat("-> 기본 이름을 사용합니다.\n")
}

# 최종 파일 경로
output_filename <- file.path(output_path, paste0(dict_name, ".txt"))


# 파일 중복 확인
if (file.exists(output_filename)) {
  cat(sprintf("\n경고: 동일한 이름의 파일이 이미 존재합니다: %s\n", basename(output_filename)))
  cat("1. 덮어쓰기\n")
  cat("2. 새 이름으로 저장 (자동으로 _v2, _v3 등 추가)\n")
  
  overwrite_choice <- readline(prompt = "선택 (1 또는 2): ")
  
  if (overwrite_choice != "1") {
    # 새 버전 이름 생성
    base_name <- gsub("\.txt$", "", output_filename)
    counter <- 2
    while (file.exists(sprintf("%s_v%d.txt", base_name, counter))) {
      counter <- counter + 1
    }
    output_filename <- sprintf("%s_v%d.txt", base_name, counter)
    cat(sprintf("-> 새 파일명: %s\n", basename(output_filename)))
  } else {
    cat("-> 기존 파일을 덮어씁니다.\n")
  }
}

# ========== 최종 사전 파일 생성 ==========
cat("\n========== 4단계: 최종 사전 파일 생성 ==========\n")

# 중복 제거 및 정렬
# 유효한 단어만 필터링
valid_rows <- !is.na(all_words$word) & all_words$word != ""
final_dict <- all_words[valid_rows, ]

# 중복 제거 (단어 기준)
if (nrow(final_dict) > 0) {
  final_dict <- final_dict[!duplicated(final_dict$word), ]
  # 정렬
  final_dict <- final_dict[order(final_dict$word), ]
} else {
  final_dict <- data.frame(word = character(0), tag = character(0), score = numeric(0))
}

cat(sprintf("최종 통계:\n"))
if (MERGE_MODE) {
  cat(sprintf("   - 병합 모드: 기존 사전과 신규 단어 병합\n"))
  if (exists("existing_dict_content")) {
    cat(sprintf("   - 기존 사전 단어: %d개\n", nrow(existing_dict_content)))
    new_words_count <- nrow(final_dict) - nrow(existing_dict_content)
    cat(sprintf("   - 신규 추가 단어: %d개\n", new_words_count))
  }
} else {
  cat(sprintf("   - 신규 생성 모드\n"))
  cat(sprintf("   - 중복 제거 전: %d개 단어\n", nrow(all_words)))
}
cat(sprintf("   - 최종 단어 수: %d개\n", nrow(final_dict)))
cat(sprintf("   - 최종 파일명: %s\n", basename(output_filename)))

# 사용자 최종 확인
cat("\n위 설정으로 사전 파일을 생성하시겠습니까?\n")
final_confirm <- readline(prompt = "계속하시겠습니까? (y/n): ")

if (tolower(final_confirm) != "y") {
  stop("사용자가 사전 생성을 취소했습니다.")
}

# Kiwi 형식에 맞게 저장 (탭으로 구분, 헤더 없음, 따옴표 없음)
write.table(
  final_dict,
  file = output_filename,
  sep = "\t",
  row.names = FALSE,
  col.names = FALSE,
  quote = FALSE,
  fileEncoding = "UTF-8"
)

# ========== 완료 및 결과 표시 ==========
if (MERGE_MODE) {
  cat("\n========== 사용자 사전 병합 완료! ==========\n")
  cat(sprintf("병합 결과:\n"))
  if (exists("existing_dict_content")) {
    cat(sprintf("   - 기존 사전: %d개 단어\n", nrow(existing_dict_content)))
    new_words_count <- nrow(final_dict) - nrow(existing_dict_content)
    cat(sprintf("   - 신규 추가: %d개 단어\n", new_words_count))
    cat(sprintf("   - 병합 후 총 단어: %d개\n", nrow(final_dict)))
  }
} else {
  cat("\n========== 사용자 사전 생성 완료! ==========\n")
}

cat("파일 정보:\n")
cat(sprintf("   - 파일 위치: %s\n", output_filename))
cat(sprintf("   - 파일 크기: %.1f KB\n", file.info(output_filename)$size/1024))
cat(sprintf("   - 총 등록 단어: %d개\n", nrow(final_dict)))

# 품사별 통계
tag_stats <- table(final_dict$tag)
cat(sprintf("   - 품사별 분포:\n"))
for (tag in names(tag_stats)) {
  cat(sprintf("     * %s: %d개\n", tag, tag_stats[tag]))
}

# 미리보기
cat("\n사전 내용 미리보기 (상위 10개):\n")
preview_dict <- final_dict[1:min(10, nrow(final_dict)), ]
print(preview_dict, row.names = FALSE)

if (nrow(final_dict) > 10) {
  cat(sprintf("   ... 외 %d개 더\n", nrow(final_dict) - 10))
}

cat("\n다음 단계:\n")
cat("   1. 02_kiwipiepy_morpheme_analysis.R 스크립트 실행\n")
cat("   2. 대화형 메뉴에서 '1. 예 - 사용자 사전 적용' 선택\n")
cat(sprintf("   3. 생성된 사전 '%s' 선택\n", basename(output_filename)))
cat("   4. 전체 데이터 형태소 분석 실행\n")

cat("\n사전 생성이 완료되었습니다!\n")
