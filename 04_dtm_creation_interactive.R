# 04_dtm_creation_interactive.R
# DTM(Document-Term Matrix) 생성을 위한 대화형 스크립트
# 작성일: 2025-08-06
# 기능: 형태소 분석 결과로부터 DTM을 생성하고 메타데이터와 결합

# 1. 필요한 패키지 로드 및 확인
cat("=== DTM 생성 및 분석 보고서 프로그램 시작 ===\n")
cat("필요한 패키지를 확인하고 로드합니다...\n\n")

# 00_utils.R 로드 (00_ 접두사로 보호됨)
if (file.exists("00_utils.R")) {
  source("00_utils.R")
}

required_packages <- c("readr", "quanteda", "dplyr", "ggplot2")
missing_packages <- c()

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    missing_packages <- c(missing_packages, pkg)
  }
}

if (length(missing_packages) > 0) {
  cat("❌ 다음 패키지가 설치되지 않았습니다:\n")
  for (pkg in missing_packages) {
    cat(sprintf("   - %s\n", pkg))
  }
  cat("\n설치 명령어:\n")
  cat(sprintf("install.packages(c(%s))\n", 
              paste(sprintf('"%s"', missing_packages), collapse = ", ")))
  stop("필요한 패키지를 먼저 설치해주세요.")
}

cat("✅ 모든 필요한 패키지가 로드되었습니다.\n\n")

# ========== 환경 설정 ==========
if (!endsWith(getwd(), "mopheme_test")) {
  script_path <- commandArgs(trailingOnly = FALSE)
  script_dir <- dirname(sub("--file=", "", script_path[grep("--file", script_path)]))
  if (length(script_dir) > 0 && script_dir != "") {
    setwd(script_dir)
  }
}
cat("작업 디렉토리:", getwd(), "\n")

# 2. 원본 메타데이터 로드 (combined_data.rds)
# 최신 dl_combined_data 파일 자동 검색
processed_dir <- "data/processed/"
combined_data_files <- list.files(processed_dir, pattern = "^dl_combined_data_.*\\.rds$", full.names = TRUE)
if (length(combined_data_files) == 0) {
  stop("dl_combined_data_*.rds 파일을 찾을 수 없습니다. 01_data_loading_and_analysis.R을 먼저 실행해주세요.")
}
latest_combined_data_file <- combined_data_files[order(file.mtime(combined_data_files), decreasing = TRUE)][1]
original_metadata_df <- readRDS(latest_combined_data_file)
cat(sprintf("✅ 최신 데이터 파일 로드: %s\n", basename(latest_combined_data_file)))

# 데이터 표준화 (utils.R 함수 사용)
if (exists("standardize_data")) {
  original_metadata_df <- standardize_data(original_metadata_df)
} else {
  # utils.R이 없는 경우 기존 방식 사용
  if ("논문 ID" %in% names(original_metadata_df)) {
    original_metadata_df <- original_metadata_df %>% rename(doc_id = `논문 ID`)
  }
}

# 3. 형태소 분석 결과 파일 목록 찾기
# 최신 mp_morpheme_results 파일 자동 검색
morpheme_files <- list.files(processed_dir, pattern = "^mp_morpheme_results_.*\\.rds$", full.names = TRUE)
if (length(morpheme_files) == 0) {
  stop("mp_morpheme_results_*.rds 파일을 찾을 수 없습니다. 02_kiwipiepy_morpheme_analysis.R을 먼저 실행해주세요.")
}
selected_file_path <- morpheme_files[order(file.mtime(morpheme_files), decreasing = TRUE)][1]

# 5. 선택된 형태소 분석 결과 데이터 로드
morpheme_results_list <- readRDS(selected_file_path)
# 리스트에서 noun_extraction 데이터프레임 추출
morpheme_results_df <- morpheme_results_list$noun_extraction

# 6. 메타데이터와 형태소 분석 결과 조인
# 'doc_id'를 기준으로 두 데이터프레임을 조인합니다.
# left_join을 사용하여 형태소 분석 결과에 메타데이터를 추가합니다.

# 조인 전 상태 확인
cat("📋 조인 전 데이터 확인:\n")
cat(sprintf("  형태소 분석 결과: %d행, %d열\n", nrow(morpheme_results_df), ncol(morpheme_results_df)))
cat(sprintf("  원본 메타데이터: %d행, %d열\n", nrow(original_metadata_df), ncol(original_metadata_df)))

# doc_id 컬럼 존재 확인
if ("doc_id" %in% names(morpheme_results_df)) {
  cat("✅ 형태소 분석 결과에 doc_id 존재\n")
} else {
  cat("⚠️ 형태소 분석 결과에 doc_id 없음 - 첫 번째 컬럼을 doc_id로 가정\n")
  names(morpheme_results_df)[1] <- "doc_id"
}

if ("doc_id" %in% names(original_metadata_df)) {
  cat("✅ 원본 메타데이터에 doc_id 존재\n")
} else {
  cat("❌ 원본 메타데이터에 doc_id 없음\n")
}

combined_df <- left_join(morpheme_results_df, original_metadata_df, by = "doc_id")

# 조인 후 상태 확인
cat(sprintf("📋 조인 후 결합 데이터: %d행, %d열\n", nrow(combined_df), ncol(combined_df)))
if ("doc_id" %in% names(combined_df)) {
  cat(sprintf("✅ doc_id 보존 확인: %s\n", paste(head(combined_df$doc_id, 3), collapse = ", ")))
} else {
  cat("❌ doc_id가 조인 과정에서 손실됨\n")
}

# 7. noun_extraction 열 전처리 (쉼표를 공백으로 대체)
# 이렇게 하면 quanteda의 tokens() 함수가 각 명사를 올바르게 개별 토큰으로 인식하고, 쉼표는 제거됩니다.
combined_df$noun_extraction <- gsub(", ", " ", combined_df$noun_extraction) # 쉼표와 공백을 공백으로 대체
combined_df$noun_extraction <- gsub(",", " ", combined_df$noun_extraction)  # 혹시 남아있을 수 있는 쉼표를 공백으로 대체 (안전 장치)

# 8. 한자어 자동 제거 처리
cat("\n🔤 한자어 자동 제거 단계\n")
cat(rep("-", 40), "\n")

# 한자어 패턴 확인
chinese_pattern <- "[\u4e00-\u9fff]+"
all_terms <- unlist(strsplit(combined_df$noun_extraction, "\\s+"))
chinese_terms <- grep(chinese_pattern, all_terms, value = TRUE)
original_term_count <- length(all_terms)

# 한자어 자동 제거 적용
chinese_filtering_applied <- FALSE
filtering_type <- "없음"

if (length(chinese_terms) > 0) {
  unique_chinese <- unique(chinese_terms)
  chinese_ratio <- length(chinese_terms) / length(all_terms) * 100
  
  cat(sprintf("📊 한자어 포함 용어 발견: %d개 (전체의 %.1f%%)\n", 
              length(unique_chinese), chinese_ratio))
  cat("📋 한자어 샘플:", paste(head(unique_chinese, 10), collapse = ", "), "\n")
  
  cat("\n🔄 한자어 포함 용어를 자동으로 제거하고 있습니다...\n")
  
  # 각 문서별로 한자어 포함 용어 제거
  combined_df$noun_extraction <- sapply(combined_df$noun_extraction, function(text) {
    terms <- unlist(strsplit(text, "\\s+"))
    korean_terms <- grep(chinese_pattern, terms, value = TRUE, invert = TRUE)
    paste(korean_terms, collapse = " ")
  })
  
  chinese_filtering_applied <- TRUE
  filtering_type <- "한자어_자동제거"
  
  # 필터링 결과 확인
  remaining_terms <- unlist(strsplit(combined_df$noun_extraction, "\\s+"))
  remaining_chinese <- grep(chinese_pattern, remaining_terms, value = TRUE)
  removed_terms <- original_term_count - length(remaining_terms)
  removal_ratio <- removed_terms / original_term_count * 100
  
  cat(sprintf("✅ 한자어 자동 제거 완료\n"))
  cat(sprintf("   제거된 용어: %d개 (%.1f%%)\n", removed_terms, removal_ratio))
  cat(sprintf("   남은 용어: %d개\n", length(remaining_terms)))
  cat(sprintf("   남은 한자어: %d개\n", length(remaining_chinese)))
  
} else {
  cat("✅ 한자어가 발견되지 않았습니다. 추가 처리가 필요하지 않습니다.\n")
  filtering_type <- "없음"
}

# 9. 영문과 숫자 자동 제거 처리
cat("\n🔤 영문과 숫자 자동 제거 단계\n")
cat(rep("-", 40), "\n")

# 영문과 숫자 패턴 확인
english_pattern <- "[a-zA-Z]+"
number_pattern <- "[0-9]+"
mixed_pattern <- "[a-zA-Z0-9]+"

current_terms <- unlist(strsplit(combined_df$noun_extraction, "\\s+"))
english_terms <- grep(english_pattern, current_terms, value = TRUE)
number_terms <- grep(number_pattern, current_terms, value = TRUE)
mixed_terms <- grep(mixed_pattern, current_terms, value = TRUE)

# 영문/숫자 자동 제거 적용
english_filtering_applied <- FALSE
number_filtering_applied <- FALSE
english_filtering_type <- "없음"

if (length(mixed_terms) > 0) {
  unique_mixed <- unique(mixed_terms)
  mixed_ratio <- length(mixed_terms) / length(current_terms) * 100
  
  cat(sprintf("📊 영문/숫자 포함 용어 발견: %d개 (전체의 %.1f%%)\n", 
              length(unique_mixed), mixed_ratio))
  cat("📋 영문/숫자 샘플:", paste(head(unique_mixed, 10), collapse = ", "), "\n")
  
  cat("\n🔄 영문/숫자 포함 용어를 자동으로 제거하고 있습니다...\n")
  
  # 각 문서별로 영문/숫자 포함 용어 제거
  combined_df$noun_extraction <- sapply(combined_df$noun_extraction, function(text) {
    terms <- unlist(strsplit(text, "\\s+"))
    # 순수 한글만 남기기 (한글 자음, 모음, 완성형 문자)
    korean_only_terms <- grep("^[ㄱ-ㅎㅏ-ㅣ가-힣]+$", terms, value = TRUE)
    paste(korean_only_terms, collapse = " ")
  })
  
  english_filtering_applied <- TRUE
  english_filtering_type <- "영문숫자_자동제거"
  
  # 필터링 결과 확인
  remaining_terms_after_english <- unlist(strsplit(combined_df$noun_extraction, "\\s+"))
  removed_english_terms <- length(current_terms) - length(remaining_terms_after_english)
  english_removal_ratio <- removed_english_terms / length(current_terms) * 100
  
  cat(sprintf("✅ 영문/숫자 자동 제거 완료\n"))
  cat(sprintf("   제거된 용어: %d개 (%.1f%%)\n", removed_english_terms, english_removal_ratio))
  cat(sprintf("   남은 용어: %d개\n", length(remaining_terms_after_english)))
  
} else {
  cat("✅ 영문/숫자 포함 용어가 발견되지 않았습니다.\n")
  english_filtering_type <- "없음"
}

# 빈 문서 확인 (필터링으로 인해 내용이 사라진 문서)
empty_docs <- which(trimws(combined_df$noun_extraction) == "")
if (length(empty_docs) > 0) {
  cat(sprintf("\n⚠️  필터링으로 인해 내용이 사라진 문서: %d개\n", length(empty_docs)))
  cat("   해당 문서들을 분석에서 제외합니다.\n")
  
  # 빈 문서 제거
  combined_df <- combined_df[-empty_docs, ]
  cat(sprintf("✅ 최종 분석 대상 문서: %d개\n", nrow(combined_df)))
}

# 9. quanteda 코퍼스 생성
# quanteda의 docid_field는 지정한 컬럼을 문서 식별자로 사용 후 docvars에서 제거합니다.
# 따라서 doc_id를 보존하기 위해 document_id로 복사한 후 corpus를 생성합니다.
combined_df$document_id <- combined_df$doc_id  # doc_id 보존용 복사본 생성

noun_corpus <- corpus(combined_df,
                      docid_field = "doc_id",
                      text_field = "noun_extraction")

# 10. DFM (Document-Feature Matrix) 생성
cat("\n🔨 DTM(Document-Term Matrix) 생성 중...\n")
noun_dfm <- dfm(tokens(noun_corpus))

cat("✅ DTM 생성 완료!\n")
cat(sprintf("📊 기본 정보: %d개 문서, %d개 고유 용어\n", ndoc(noun_dfm), nfeat(noun_dfm)))

# 11. DTM 분석 보고서 생성
cat("\n📋 DTM 분석 보고서 생성 중...\n")
cat(rep("=", 60), "\n")
cat("                 DTM 분석 보고서                   \n")
cat(rep("=", 60), "\n")

# 10-1. 기본 통계
cat("\n📊 1. 기본 통계\n")
cat(rep("-", 40), "\n")
cat(sprintf("📄 총 문서 수: %s개\n", format(ndoc(noun_dfm), big.mark = ",")))
cat(sprintf("📝 총 고유 명사 수: %s개\n", format(nfeat(noun_dfm), big.mark = ",")))
cat(sprintf("🔢 총 토큰 수: %s개\n", format(sum(noun_dfm), big.mark = ",")))

# 문서별 토큰 수 통계
doc_tokens <- rowSums(noun_dfm)
cat(sprintf("📏 문서당 평균 토큰 수: %.1f개\n", mean(doc_tokens)))
cat(sprintf("📏 문서당 토큰 수 범위: %d~%d개\n", min(doc_tokens), max(doc_tokens)))

# 희소성(Sparsity) 계산
original_sparsity <- sparsity(noun_dfm)
cat(sprintf("🕳️  원본 희소성(Sparsity): %.2f%%\n", original_sparsity * 100))

# 11-1. 희소성 관리 옵션
cat("\n🔧 희소성 관리 설정\n")
cat(rep("-", 40), "\n")

if(original_sparsity > 0.95) {
  cat("⚠️  희소성이 95%를 초과하여 분석 품질에 영향을 줄 수 있습니다.\n")
  cat("   필터링을 통해 희소성을 낮추는 것을 권장합니다.\n\n")
  
  # 사용자 선택 
  filter_choice <- readline("희소성 관리 필터링을 적용하시겠습니까? (y/n, 기본값: y): ")
  
  # 기본값 처리: 빈 입력시 'y' 사용
  if (filter_choice == "" || is.na(filter_choice)) {
    filter_choice <- "y"
    cat("기본값 사용: y (필터링 적용)\n")
  }
  
  if(tolower(substr(filter_choice, 1, 1)) == "y") {
    cat("\n📋 필터링 매개변수 설정\n")
    
    # 기본값 제시
    cat("💡 권장 설정 (학술논문 기준):\n")
    cat("   - 최소 용어 빈도: 3회 이상\n")
    cat("   - 최소 문서 빈도: 2개 문서 이상\n\n")
    
    # 사용자 입력
    min_termfreq_str <- readline("최소 용어 빈도 (기본값 3): ")
    min_termfreq <- ifelse(min_termfreq_str == "", 3, as.integer(min_termfreq_str))
    
    min_docfreq_str <- readline("최소 문서 빈도 (기본값 2): ")
    min_docfreq <- ifelse(min_docfreq_str == "", 2, as.integer(min_docfreq_str))
    
    cat(sprintf("\n🔄 필터링 적용 중... (min_termfreq=%d, min_docfreq=%d)\n", 
                min_termfreq, min_docfreq))
    
    # 필터링 적용
    filtered_dfm <- dfm_trim(noun_dfm, 
                            min_termfreq = min_termfreq,
                            min_docfreq = min_docfreq)
    
    # 필터링 결과 확인
    filtered_sparsity <- sparsity(filtered_dfm)
    
    cat("\n📊 필터링 결과 비교:\n")
    cat(sprintf("   원본: %d개 문서, %d개 용어, 희소성 %.2f%%\n", 
                ndoc(noun_dfm), nfeat(noun_dfm), original_sparsity * 100))
    cat(sprintf("   필터링 후: %d개 문서, %d개 용어, 희소성 %.2f%%\n", 
                ndoc(filtered_dfm), nfeat(filtered_dfm), filtered_sparsity * 100))
    cat(sprintf("   제거된 용어: %d개 (%.1f%%)\n", 
                nfeat(noun_dfm) - nfeat(filtered_dfm),
                (nfeat(noun_dfm) - nfeat(filtered_dfm)) / nfeat(noun_dfm) * 100))
    
    # 필터링된 DTM을 메인 DTM으로 사용
    use_filtered <- readline("\n필터링된 DTM을 분석에 사용하시겠습니까? (y/n, 기본값: y): ")
    
    # 기본값 처리: 빈 입력시 'y' 사용
    if (use_filtered == "" || is.na(use_filtered)) {
      use_filtered <- "y"
      cat("기본값 사용: y (필터링된 DTM 사용)\n")
    }
    
    if(tolower(substr(use_filtered, 1, 1)) == "y") {
      noun_dfm <- filtered_dfm
      sparsity <- filtered_sparsity
      cat("✅ 필터링된 DTM으로 분석을 진행합니다.\n")
      
      # 필터링 정보 저장
      filtering_applied <- TRUE
      filtering_params <- list(
        min_termfreq = min_termfreq,
        min_docfreq = min_docfreq
      )
    } else {
      sparsity <- original_sparsity
      cat("📝 원본 DTM으로 분석을 진행합니다.\n")
      filtering_applied <- FALSE
      filtering_params <- NULL
    }
    
  } else {
    sparsity <- original_sparsity
    cat("📝 필터링 없이 원본 DTM으로 분석을 진행합니다.\n")
    filtering_applied <- FALSE
    filtering_params <- NULL
  }
} else {
  cat("✅ 희소성이 적절한 수준입니다. 추가 필터링이 필요하지 않습니다.\n")
  sparsity <- original_sparsity
  filtering_applied <- FALSE
  filtering_params <- NULL
}

# 10-1. 동의어 처리 옵션
cat("\n📚 동의어 처리\n")
cat(rep("=", 50), "\n")

# 동의어 사전 파일 검색
synonym_files <- list.files("data/dictionaries/", pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
# dict_candidates와 기타 사전 파일들도 포함
synonym_files <- c(synonym_files, list.files("data/dictionaries/dict_candidates/", pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE))

synonym_processed <- FALSE
synonym_processing_info <- list(applied = FALSE)

if (length(synonym_files) > 0) {
  cat(sprintf("발견된 동의어 사전 파일: %d개\n", length(synonym_files)))
  for (i in seq_along(synonym_files)) {
    cat(sprintf("  %d. %s\n", i, basename(synonym_files[i])))
  }
  
  use_synonym <- readline("\n동의어 처리를 적용하시겠습니까? (y/n, 기본값: n): ")
  
  # 기본값 처리: 빈 입력시 'n' 사용
  if (use_synonym == "" || is.na(use_synonym)) {
    use_synonym <- "n"
    cat("기본값 사용: n (동의어 처리 건너뜀)\n")
  }
  
  if (tolower(substr(use_synonym, 1, 1)) == "y") {
    cat("\n📂 동의어 처리 진행 중...\n")
    
    # 파일 선택
    if (length(synonym_files) > 1) {
      file_choice_str <- readline(sprintf("동의어 사전 파일 번호 선택 (기본값: 1): "))
      
      # 기본값 처리: 빈 입력시 첫 번째 파일 사용
      if (file_choice_str == "" || is.na(file_choice_str)) {
        file_choice <- 1
        cat(sprintf("기본값 사용: 1번 (%s)\n", basename(synonym_files[1])))
      } else {
        file_choice <- as.integer(file_choice_str)
        if (is.na(file_choice) || file_choice < 1 || file_choice > length(synonym_files)) {
          cat("⚠️ 잘못된 선택입니다. 첫 번째 파일을 사용합니다.\n")
          file_choice <- 1
        }
      }
    } else {
      file_choice <- 1
    }
    
    selected_synonym_file <- synonym_files[file_choice]
    cat(sprintf("선택된 동의어 사전: %s\n", basename(selected_synonym_file)))
    
    # 동의어 사전 로드 및 처리
    tryCatch({
      # CSV 파일 읽기 (헤더 있음)
      synonym_dict_raw <- read.csv(selected_synonym_file, 
                                   header = TRUE, 
                                   stringsAsFactors = FALSE,
                                   fileEncoding = "UTF-8",
                                   na.strings = c("", " ", "NA"))
      
      cat(sprintf("✅ 동의어 사전 로드 완료: %d행 %d열\n", nrow(synonym_dict_raw), ncol(synonym_dict_raw)))
      
      # 동의어 사전 전처리 (가변 길이 컬럼 지원)
      synonym_pairs <- list()
      valid_entries <- 0
      
      for (i in 1:nrow(synonym_dict_raw)) {
        # 모든 컬럼 데이터를 문자형으로 변환하여 처리
        row_data <- as.character(synonym_dict_raw[i, ])
        # NA, 공백, 빈 문자열 제거
        row_data <- row_data[!is.na(row_data) & row_data != "" & trimws(row_data) != ""]
        
        if (length(row_data) >= 2) {  # 최소 대표어와 동의어 1개
          main_word <- trimws(row_data[1])
          synonyms <- trimws(row_data[-1])  # 첫 번째 제외한 모든 컬럼
          # 중복 및 빈 값 제거
          synonyms <- synonyms[synonyms != "" & synonyms != main_word]
          
          if (length(synonyms) > 0) {
            for (synonym in synonyms) {
              synonym_pairs[[synonym]] <- main_word
            }
            valid_entries <- valid_entries + 1
            
            # 처리 과정 로그 (처음 5개만)
            if (valid_entries <= 5) {
              cat(sprintf("   %d. %s ← [%s]\n", valid_entries, main_word, 
                         paste(synonyms, collapse = ", ")))
            }
          }
        }
      }
      
      cat(sprintf("📊 유효한 동의어 규칙: %d개\n", valid_entries))
      cat(sprintf("📊 총 동의어 매핑: %d개\n", length(synonym_pairs)))
      
      # 동의어 처리 실행
      if (length(synonym_pairs) > 0) {
        # 현재 DTM의 feature 이름들
        original_features <- featnames(noun_dfm)
        
        # 동의어 매핑 적용
        matched_synonyms <- intersect(names(synonym_pairs), original_features)
        cat(sprintf("📊 DTM에서 발견된 동의어: %d개\n", length(matched_synonyms)))
        
        if (length(matched_synonyms) > 0) {
          cat("📋 처리될 동의어 샘플:\n")
          sample_matched <- head(matched_synonyms, 5)
          for (synonym in sample_matched) {
            cat(sprintf("   %s → %s\n", synonym, synonym_pairs[[synonym]]))
          }
          
          # 동의어 처리: dfm_group을 이용한 feature 통합
          # 1. feature 이름 매핑 벡터 생성
          feature_mapping <- original_features
          names(feature_mapping) <- original_features
          
          # 2. 동의어를 대표어로 매핑
          for (synonym in matched_synonyms) {
            main_word <- synonym_pairs[[synonym]]
            feature_mapping[synonym] <- main_word
          }
          
          # 3. 동의어 처리 전 희소성 계산
          pre_synonym_sparsity <- sparsity(noun_dfm)
          
          # 4. dfm에서 동일한 대표어를 가진 feature들을 합산
          colnames(noun_dfm) <- feature_mapping
          noun_dfm <- dfm_compress(noun_dfm, margin = "features")
          
          # 5. 동의어 처리 후 희소성 계산
          post_synonym_sparsity <- sparsity(noun_dfm)
          
          cat("✅ 동의어 처리 완료\n")
          cat(sprintf("   처리 전 용어 수: %d개\n", length(original_features)))
          cat(sprintf("   처리 후 용어 수: %d개\n", nfeat(noun_dfm)))
          cat(sprintf("   통합된 용어 수: %d개\n", length(original_features) - nfeat(noun_dfm)))
          cat(sprintf("   희소성 변화: %.2f%% → %.2f%% (%.2f%%p 개선)\n", 
                     pre_synonym_sparsity * 100, 
                     post_synonym_sparsity * 100,
                     (pre_synonym_sparsity - post_synonym_sparsity) * 100))
          
          # 희소성 개선 여부 평가
          if (pre_synonym_sparsity > post_synonym_sparsity) {
            cat("   📈 동의어 통합으로 희소성이 개선되었습니다!\n")
          } else if (pre_synonym_sparsity == post_synonym_sparsity) {
            cat("   📊 희소성 변화가 없습니다.\n")
          } else {
            cat("   📉 희소성이 약간 증가했습니다. (정상적인 경우)\n")
          }
          
          # 업데이트된 희소성을 전역 변수에 반영
          sparsity <- post_synonym_sparsity
          
          synonym_processed <- TRUE
          synonym_processing_info <- list(
            applied = TRUE,
            synonym_dict_file = basename(selected_synonym_file),
            original_features = length(original_features),
            processed_features = nfeat(noun_dfm),
            merged_count = length(original_features) - nfeat(noun_dfm),
            synonym_rules_applied = length(matched_synonyms),
            total_synonym_pairs = length(synonym_pairs),
            sparsity_change = list(
              pre_synonym = pre_synonym_sparsity,
              post_synonym = post_synonym_sparsity,
              improvement = pre_synonym_sparsity - post_synonym_sparsity,
              improvement_percent = (pre_synonym_sparsity - post_synonym_sparsity) * 100
            )
          )
          
        } else {
          cat("⚠️ DTM에서 매칭되는 동의어를 찾지 못했습니다.\n")
        }
      } else {
        cat("⚠️ 유효한 동의어 매핑이 없습니다.\n")
      }
      
    }, error = function(e) {
      cat(sprintf("❌ 동의어 처리 실패: %s\n", e$message))
      cat("📝 동의어 처리 없이 진행합니다.\n")
    })
  } else {
    cat("📝 동의어 처리를 건너뜁니다.\n")
  }
} else {
  cat("📝 동의어 사전 파일이 없습니다. 동의어 처리를 건너뜁니다.\n")
  cat("💡 동의어 사전을 사용하려면 data/dictionaries/ 폴더에 CSV 파일을 추가하세요.\n")
}

# 11-2. 빈도 분석
cat("\n📈 2. 빈도 분석 (상위 20개)\n")
cat(rep("-", 40), "\n")

# 상위 20개 빈번한 용어 (절대 빈도)
top_features <- topfeatures(noun_dfm, 20)
cat("🏆 절대 빈도 기준 상위 20개 용어:\n")
for(i in 1:length(top_features)) {
  cat(sprintf("  %2d. %-15s %s회\n", i, names(top_features)[i], 
              format(top_features[i], big.mark = ",")))
}

# 상대 빈도 분석 (문서당 평균 출현 빈도)
cat("\n📊 상대 빈도 기준 상위 20개 용어:\n")
relative_freq <- colSums(noun_dfm) / ndoc(noun_dfm)
top_relative <- sort(relative_freq, decreasing = TRUE)[1:20]
for(i in 1:length(top_relative)) {
  cat(sprintf("  %2d. %-15s %.2f회/문서\n", i, names(top_relative)[i], top_relative[i]))
}

# 11-3. TF-IDF 가중치 적용 옵션
cat("\n🔍 3. TF-IDF 가중치 적용\n")
cat(rep("-", 40), "\n")

cat("💡 TF-IDF는 문서별 용어의 중요도를 계산하는 방법입니다.\n")
cat("   - TF (Term Frequency): 문서 내 용어 빈도\n")
cat("   - IDF (Inverse Document Frequency): 전체 문서에서의 희귀성\n")
cat("   - 특정 문서에서만 중요한 용어들을 식별할 때 유용합니다.\n\n")

tfidf_choice <- readline("TF-IDF 가중치를 적용하시겠습니까? (y/n, 기본값: n): ")

# 기본값 처리: 빈 입력시 'n' 사용
if (tfidf_choice == "" || is.na(tfidf_choice)) {
  tfidf_choice <- "n"
  cat("기본값 사용: n (TF-IDF 적용 안함)\n")
}

if(tolower(substr(tfidf_choice, 1, 1)) == "y") {
  cat("\n🔄 TF-IDF 가중치 계산 중...\n")
  
  # TF-IDF 가중치 계산
  tfidf_dfm <- dfm_tfidf(noun_dfm)
  tfidf_applied <- TRUE
  
  cat("✅ TF-IDF 계산 완료!\n")
  cat(sprintf("📊 TF-IDF 적용 정보: %d개 문서, %d개 용어\n", ndoc(tfidf_dfm), nfeat(tfidf_dfm)))
  
  # 전체 문서에서 TF-IDF 평균 점수 계산
  tfidf_scores <- colSums(tfidf_dfm) / ndoc(tfidf_dfm)
  top_tfidf <- sort(tfidf_scores, decreasing = TRUE)[1:20]
  
  cat("\n🏆 TF-IDF 가중치 기준 상위 20개 용어:\n")
  for(i in 1:length(top_tfidf)) {
    cat(sprintf("  %2d. %-15s %.4f\n", i, names(top_tfidf)[i], top_tfidf[i]))
  }
  
  # TF-IDF 최대값을 가진 용어들 (문서별)
  cat("\n📊 각 문서에서 최고 TF-IDF 점수를 가진 용어 (상위 10개 문서):\n")
  max_tfidf_per_doc <- apply(tfidf_dfm, 1, function(x) {
    max_idx <- which.max(x)
    if(length(max_idx) > 0 && max(x) > 0) {
      return(list(term = colnames(tfidf_dfm)[max_idx], score = max(x)))
    }
    return(list(term = NA, score = 0))
  })
  
  # 상위 10개 문서의 대표 용어 표시
  doc_names <- rownames(tfidf_dfm)
  for(i in 1:min(10, length(max_tfidf_per_doc))) {
    if(!is.na(max_tfidf_per_doc[[i]]$term)) {
      cat(sprintf("  문서 %s: %s (%.4f)\n", 
                  substr(doc_names[i], 1, 10), 
                  max_tfidf_per_doc[[i]]$term, 
                  max_tfidf_per_doc[[i]]$score))
    }
  }
  
  # TF-IDF vs 빈도 비교 분석
  cat("\n📈 TF-IDF vs 빈도 기준 비교 (상위 10개):\n")
  freq_top10 <- names(top_features)[1:10]
  tfidf_top10 <- names(top_tfidf)[1:10]
  
  common_terms <- intersect(freq_top10, tfidf_top10)
  freq_only <- setdiff(freq_top10, tfidf_top10)
  tfidf_only <- setdiff(tfidf_top10, freq_top10)
  
  cat(sprintf("  📍 공통 중요 용어 (%d개): %s\n", length(common_terms), 
              paste(common_terms, collapse = ", ")))
  if(length(freq_only) > 0) {
    cat(sprintf("  📍 빈도만 높은 용어 (%d개): %s\n", length(freq_only), 
                paste(freq_only, collapse = ", ")))
  }
  if(length(tfidf_only) > 0) {
    cat(sprintf("  📍 TF-IDF만 높은 용어 (%d개): %s\n", length(tfidf_only), 
                paste(tfidf_only, collapse = ", ")))
  }
  
} else {
  cat("📝 TF-IDF를 적용하지 않고 원본 빈도로 분석을 진행합니다.\n")
  tfidf_applied <- FALSE
  tfidf_dfm <- NULL
  tfidf_scores <- NULL
  top_tfidf <- NULL
  max_tfidf_per_doc <- NULL
}

# 최종 DTM 구성 방식 선택
cat("\n🎯 DTM 구성 방식 선택\n")
cat(rep("-", 40), "\n")
cat("💡 DTM 구성을 위한 가중치 방식을 선택하세요:\n")
cat("   1. 빈도 기반 (Raw Frequency): 단어의 출현 횟수를 그대로 사용\n")
cat("   2. TF-IDF 가중치: 문서별 중요도를 반영한 가중치 사용\n\n")

if(tfidf_applied) {
  cat("📊 두 방식의 특징 비교:\n")
  cat("   - 빈도 기반: 전체적인 패턴 분석, 일반적인 주제 모델링에 적합\n")
  cat("   - TF-IDF: 문서별 특징 강조, 문서 분류/검색에 적합\n\n")
  
  dtm_choice <- readline("DTM 구성 방식 선택 (1: 빈도, 2: TF-IDF, 기본값: 1): ")
  
  # 기본값 처리: 빈 입력시 '1' 사용
  if (dtm_choice == "" || is.na(dtm_choice)) {
    dtm_choice <- "1"
    cat("기본값 사용: 1 (빈도 기반 DTM)\n")
  }
  
  if(dtm_choice == "2") {
    final_dfm <- tfidf_dfm
    dtm_type <- "TF-IDF"
    cat("✅ TF-IDF 가중치 기반 DTM을 사용합니다.\n")
  } else {
    final_dfm <- noun_dfm
    dtm_type <- "빈도"
    cat("✅ 빈도 기반 DTM을 사용합니다.\n")
  }
} else {
  final_dfm <- noun_dfm
  dtm_type <- "빈도"
  cat("📝 TF-IDF를 계산하지 않았으므로 빈도 기반 DTM을 사용합니다.\n")
}

cat(sprintf("🎯 최종 DTM 정보: %s 기반, %d개 문서, %d개 용어\n", 
            dtm_type, ndoc(final_dfm), nfeat(final_dfm)))

# 11-4. 문서 길이 분석
cat("\n📏 4. 문서 길이 분석\n")
cat(rep("-", 40), "\n")
doc_lengths <- rowSums(noun_dfm)
cat(sprintf("📊 평균 문서 길이: %.1f개 용어\n", mean(doc_lengths)))
cat(sprintf("📊 문서 길이 표준편차: %.1f\n", sd(doc_lengths)))
cat(sprintf("📊 최단 문서: %d개 용어\n", min(doc_lengths)))
cat(sprintf("📊 최장 문서: %d개 용어\n", max(doc_lengths)))

# 문서 길이 분포
length_quartiles <- quantile(doc_lengths)
cat("📊 문서 길이 분위수:\n")
for(i in 1:length(length_quartiles)) {
  cat(sprintf("  %s: %.0f개\n", names(length_quartiles)[i], length_quartiles[i]))
}

# 11-5. 용어 분포 분석
cat("\n📈 5. 용어 분포 분석\n")
cat(rep("-", 40), "\n")

# 전체 용어 빈도
term_frequencies <- colSums(noun_dfm)
cat(sprintf("📊 용어당 평균 출현 빈도: %.1f회\n", mean(term_frequencies)))
cat(sprintf("📊 용어 빈도 표준편차: %.1f\n", sd(term_frequencies)))

# 빈도별 용어 분포
freq_table <- table(term_frequencies)
cat("📊 빈도별 용어 분포 (상위 10개):\n")
top_freq <- head(sort(freq_table, decreasing = TRUE), 10)
for(i in 1:length(top_freq)) {
  freq <- names(top_freq)[i]
  count <- top_freq[i]
  cat(sprintf("  %s회 출현: %d개 용어\n", freq, count))
}

# 11-6. 메타데이터 분석 (연도별)
if("연도" %in% names(docvars(noun_corpus))) {
  cat("\n📅 6. 연도별 분석\n")
  cat(rep("-", 40), "\n")
  
  year_analysis <- docvars(noun_corpus) %>%
    group_by(연도) %>%
    summarise(
      문서수 = n(),
      평균토큰수 = round(mean(doc_lengths), 1),
      .groups = "drop"
    ) %>%
    arrange(연도)
  
  cat("📊 연도별 문서 분포:\n")
  for(i in 1:nrow(year_analysis)) {
    cat(sprintf("  %d년: %d편 (평균 %.1f개 용어)\n", 
                year_analysis$연도[i], 
                year_analysis$문서수[i],
                year_analysis$평균토큰수[i]))
  }
}

# 11-7. 보고서 요약
cat("\n📝 7. 분석 요약\n")
cat(rep("-", 40), "\n")


# 권장사항
cat("\n💡 분석 권장사항:\n")
if(sparsity > 0.99) {
  cat("  - 희소성이 매우 높습니다. 최소 빈도 필터링을 고려하세요.\n")
}
if(mean(doc_lengths) < 5) {
  cat("  - 문서 길이가 너무 짧습니다. 전처리 과정을 점검하세요.\n")
}
if(nfeat(noun_dfm) > 10000) {
  cat("  - 용어 수가 많습니다. TF-IDF나 차원 축소를 고려하세요.\n")
}

cat(rep("=", 60), "\n")

# 12. 결과 저장 옵션
cat("\n💾 8. 결과 저장\n")
cat(rep("-", 40), "\n")

# 타임스탬프 생성
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

# 저장할 파일명들
dfm_filename <- sprintf("data/processed/dtm_results_%s.rds", timestamp)
report_filename <- sprintf("reports/dtm_analysis_report_%s.md", timestamp)

# 사용자 확인
save_choice <- readline("분석 결과를 파일로 저장하시겠습니까? (y/n, 기본값: y): ")

# 기본값 처리: 빈 입력시 'y' 사용
if (save_choice == "" || is.na(save_choice)) {
  save_choice <- "y"
  cat("기본값 사용: y (결과 저장)\n")
}

if(tolower(substr(save_choice, 1, 1)) == "y") {
  cat("\n📁 결과 저장 중...\n")
  
  # DTM 객체 저장
  tryCatch({
    saveRDS(list(
      dfm = final_dfm,  # 사용자가 선택한 최종 DTM
      original_dfm = noun_dfm,  # 원본 빈도 기반 DTM
      tfidf_dfm = if(exists("tfidf_applied") && tfidf_applied) tfidf_dfm else NULL,
      dtm_type = dtm_type,  # 선택된 DTM 유형
      corpus = noun_corpus,
      analysis_results = list(
        top_features = top_features,
        top_relative = top_relative,
        top_tfidf = if(exists("tfidf_applied") && tfidf_applied) top_tfidf else NULL,
        doc_lengths = doc_lengths,
        term_frequencies = term_frequencies
      ),
      tfidf_info = if(exists("tfidf_applied")) {
        list(
          applied = tfidf_applied,
          scores = if(tfidf_applied) tfidf_scores else NULL
        )
      } else {
        list(applied = FALSE)
      },
      filtering_info = if(exists("filtering_applied") && filtering_applied) {
        list(
          applied = filtering_applied,
          params = filtering_params,
          original_sparsity = original_sparsity,
          filtered_sparsity = sparsity,
          original_features = nfeat(noun_dfm) + (nfeat(noun_dfm) - nfeat(filtered_dfm)),
          removed_features = ifelse(exists("filtered_dfm"), nfeat(noun_dfm) - nfeat(filtered_dfm), 0)
        )
      } else {
        list(applied = FALSE)
      },
      chinese_removal_info = if(exists("chinese_filtering_applied") && chinese_filtering_applied) {
        list(
          applied = chinese_filtering_applied,
          type = "자동제거",
          original_term_count = original_term_count,
          removed_terms = if(exists("removed_terms")) removed_terms else 0,
          removal_ratio = if(exists("removal_ratio")) removal_ratio else 0
        )
      } else {
        list(applied = FALSE, type = "없음")
      },
      english_removal_info = if(exists("english_filtering_applied") && english_filtering_applied) {
        list(
          applied = english_filtering_applied,
          type = english_filtering_type,
          removed_terms = if(exists("removed_english_terms")) removed_english_terms else 0,
          removal_ratio = if(exists("english_removal_ratio")) english_removal_ratio else 0
        )
      } else {
        list(applied = FALSE, type = english_filtering_type)
      },
      synonym_processing_info = synonym_processing_info,
      metadata = list(
        created = Sys.time(),
        source_file = basename(selected_file_path),
        n_docs = ndoc(noun_dfm),
        n_features = nfeat(noun_dfm),
        sparsity = sparsity,
        synonym_processed = synonym_processed
      )
    ), file = dfm_filename)
    
    cat(sprintf("✅ DTM 결과 저장 완료: %s\n", dfm_filename))
  }, error = function(e) {
    cat(sprintf("❌ DTM 저장 실패: %s\n", e$message))
  })
  
  # 보고서 저장 (Markdown 형식)
  tryCatch({
    # 보고서 내용을 Markdown으로 재생성
    report_content <- c(
      "# DTM 분석 보고서",
      "",
      sprintf("**생성일시**: %s  ", Sys.time()),
      sprintf("**원본 파일**: %s  ", basename(selected_file_path)),
      ""
    )
    
    # 한자어 자동 제거 정보 추가
    if(exists("chinese_filtering_applied") && chinese_filtering_applied) {
      report_content <- c(report_content,
        "## 🔤 한자어 자동 제거 정보",
        "",
        "✅ 한자어 자동 제거 적용됨  ",
        if(exists("removed_terms")) sprintf("- 제거된 용어: %d개 (%.1f%%)  ", removed_terms, removal_ratio) else "",
        if(exists("original_term_count")) sprintf("- 원본 용어 수: %d개  ", original_term_count) else "",
        ""
      )
    } else {
      report_content <- c(report_content,
        "## 🔤 한자어 자동 제거 정보",
        "",
        "📝 한자어가 발견되지 않았습니다  ",
        ""
      )
    }
    
    # 영문/숫자 자동 제거 정보 추가
    if(exists("english_filtering_applied") && english_filtering_applied) {
      report_content <- c(report_content,
        "## 🔤 영문/숫자 자동 제거 정보",
        "",
        sprintf("✅ 영문/숫자 자동 제거 적용됨 (%s)  ", english_filtering_type),
        if(exists("removed_english_terms")) sprintf("- 제거된 용어: %d개 (%.1f%%)  ", removed_english_terms, english_removal_ratio) else "",
        ""
      )
    } else {
      report_content <- c(report_content,
        "## 🔤 영문/숫자 자동 제거 정보",
        "",
        sprintf("📝 영문/숫자 제거 상태: %s  ", english_filtering_type),
        ""
      )
    }
    
    # 동의어 처리 정보 추가
    if(synonym_processed) {
      report_content <- c(report_content,
        "## 📚 동의어 처리 정보",
        "",
        "✅ 동의어 처리 적용됨  ",
        sprintf("- 사용된 사전: %s  ", synonym_processing_info$synonym_dict_file),
        sprintf("- 처리 전 용어 수: %d개  ", synonym_processing_info$original_features),
        sprintf("- 처리 후 용어 수: %d개  ", synonym_processing_info$processed_features),
        sprintf("- 통합된 용어 수: %d개  ", synonym_processing_info$merged_count),
        sprintf("- 적용된 동의어 규칙: %d개  ", synonym_processing_info$synonym_rules_applied),
        sprintf("- 전체 동의어 매핑: %d개  ", synonym_processing_info$total_synonym_pairs),
        sprintf("- 희소성 변화: %.2f%% → %.2f%% (%.2f%%p 개선)  ", 
                synonym_processing_info$sparsity_change$pre_synonym * 100,
                synonym_processing_info$sparsity_change$post_synonym * 100,
                synonym_processing_info$sparsity_change$improvement_percent),
        if(synonym_processing_info$sparsity_change$improvement > 0) "- 📈 희소성 개선 효과 확인  " else "- 📊 희소성 변화 미미  ",
        ""
      )
    } else {
      report_content <- c(report_content,
        "## 📚 동의어 처리 정보",
        "",
        "📝 동의어 처리가 적용되지 않았습니다  ",
        ""
      )
    }
    
    # 희소성 필터링 정보 추가
    if(exists("filtering_applied") && filtering_applied) {
      report_content <- c(report_content,
        "## 🔧 희소성 필터링 정보",
        "",
        "✅ 필터링 적용됨  ",
        sprintf("- 최소 용어 빈도: %d회  ", filtering_params$min_termfreq),
        sprintf("- 최소 문서 빈도: %d개  ", filtering_params$min_docfreq),
        sprintf("- 원본 희소성: %.2f%% → 필터링 후: %.2f%%  ", original_sparsity * 100, sparsity * 100),
        if(exists("filtered_dfm")) sprintf("- 제거된 용어: %d개  ", nfeat(noun_dfm) - nfeat(filtered_dfm)) else "",
        ""
      )
    } else {
      report_content <- c(report_content,
        "## 🔧 희소성 필터링 정보",
        "",
        "📝 필터링 적용 안됨 (원본 DTM 사용)  ",
        ""
      )
    }
    
    # TF-IDF 정보 추가
    if(exists("tfidf_applied") && tfidf_applied) {
      report_content <- c(report_content,
        "## 🔍 TF-IDF 가중치 정보",
        "",
        "✅ TF-IDF 가중치 적용됨  ",
        sprintf("- 적용 대상: %d개 문서, %d개 용어  ", ndoc(tfidf_dfm), nfeat(tfidf_dfm)),
        ""
      )
    } else {
      report_content <- c(report_content,
        "## 🔍 TF-IDF 가중치 정보",
        "",
        "📝 TF-IDF 적용 안됨 (원본 빈도 사용)  ",
        ""
      )
    }
    
    # 최종 DTM 구성 방식 정보 추가
    report_content <- c(report_content,
      "## 🎯 최종 DTM 구성 방식",
      "",
      sprintf("✅ 선택된 방식: %s 기반  ", dtm_type),
      sprintf("- 최종 DTM 정보: %d개 문서, %d개 용어  ", ndoc(final_dfm), nfeat(final_dfm)),
      if(dtm_type == "TF-IDF") "- TF-IDF 가중치로 문서별 특징이 강조됩니다  " else "- 원본 빈도로 전체적인 패턴이 보존됩니다  ",
      ""
    )
    
    report_content <- c(report_content,
      "## 📊 기본 통계",
      "",
      sprintf("- 총 문서 수: %s개  ", format(ndoc(noun_dfm), big.mark = ",")),
      sprintf("- 총 고유 명사 수: %s개  ", format(nfeat(noun_dfm), big.mark = ",")),
      sprintf("- 총 토큰 수: %s개  ", format(sum(noun_dfm), big.mark = ",")),
      sprintf("- 문서당 평균 토큰 수: %.1f개  ", mean(doc_tokens)),
      sprintf("- 문서당 토큰 수 범위: %d~%d개  ", min(doc_tokens), max(doc_tokens)),
      sprintf("- 최종 희소성(Sparsity): %.2f%%  ", sparsity * 100),
      "",
      "## 📈 빈도 분석 결과",
      "",
      "### 🏆 절대 빈도 기준 상위 20개 용어",
      ""
    )
    
    # 절대 빈도 상위 용어 추가
    for(i in 1:length(top_features)) {
      report_content <- c(report_content, 
        sprintf("%d. **%s**: %s회  ", i, names(top_features)[i], 
                format(top_features[i], big.mark = ",")))
    }
    
    # 상대 빈도 추가
    report_content <- c(report_content,
      "### 📊 상대 빈도 기준 상위 20개 용어",
      ""
    )
    for(i in 1:length(top_relative)) {
      report_content <- c(report_content, 
        sprintf("%d. **%s**: %.2f회/문서  ", i, names(top_relative)[i], top_relative[i]))
    }
    
    # TF-IDF 결과 추가 (적용된 경우에만)
    if(exists("tfidf_applied") && tfidf_applied && !is.null(top_tfidf)) {
      report_content <- c(report_content,
        "## 🔍 TF-IDF 분석 결과",
        "",
        "### 🏆 TF-IDF 가중치 기준 상위 20개 용어",
        ""
      )
      for(i in 1:length(top_tfidf)) {
        report_content <- c(report_content, 
          sprintf("%d. **%s**: %.4f  ", i, names(top_tfidf)[i], top_tfidf[i]))
      }
    } else {
      report_content <- c(report_content,
        "## 🔍 TF-IDF 분석 결과",
        "",
        "📝 TF-IDF 분석이 적용되지 않았습니다.  "
      )
    }
    
    report_content <- c(report_content,
      "## 📏 문서 길이 통계",
      "",
      sprintf("- 평균 문서 길이: %.1f개 용어  ", mean(doc_lengths)),
      sprintf("- 문서 길이 표준편차: %.1f  ", sd(doc_lengths)),
      sprintf("- 최단 문서: %d개 용어  ", min(doc_lengths)),
      sprintf("- 최장 문서: %d개 용어  ", max(doc_lengths)),
      ""
    )
    
    writeLines(report_content, report_filename)
    cat(sprintf("✅ 분석 보고서 저장 완료: %s\n", report_filename))
    
  }, error = function(e) {
    cat(sprintf("❌ 보고서 저장 실패: %s\n", e$message))
  })
  
} else {
  cat("📝 결과 저장을 건너뜁니다.\n")
}

cat("\n" , rep("=", 60), "\n")

message("\n✅ DTM 생성 및 분석 보고서가 완료되었습니다!")
message(sprintf("🎯 최종 DTM: %s 기반 (%d개 문서, %d개 용어)", dtm_type, ndoc(final_dfm), nfeat(final_dfm)))
message("📂 'final_dfm' 객체에 선택된 DTM이 저장되어 있습니다.")
message("📂 'noun_dfm' 객체에 원본 빈도 기반 DTM이 저장되어 있습니다.")
if(exists("tfidf_dfm") && !is.null(tfidf_dfm)) {
  message("📂 'tfidf_dfm' 객체에 TF-IDF 가중치 DTM이 저장되어 있습니다.")
}
message("📂 'noun_corpus' 객체에 메타데이터가 포함된 코퍼스가 저장되어 있습니다.")

if(tolower(substr(save_choice, 1, 1)) == "y") {
  message(sprintf("💾 결과 파일: %s", dfm_filename))
  message(sprintf("📋 보고서 파일: %s", report_filename))
}