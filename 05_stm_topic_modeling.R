1# 05_stm_topic_modeling.R
# quanteda에서 STM으로 직접 변환하는 간소화된 STM 분석
# 작성일: 2025-08-06
# 특징: 복잡한 메타데이터 매칭 없이 quanteda convert() 사용

cat("=== quanteda 기반 STM 토픽모델링 ===\n")
cat("메타데이터 자동 매칭, 문서 순서 보장\n\n")

# ========== 환경 설정 ==========
if (!endsWith(getwd(), "mopheme_test")) {
  script_path <- commandArgs(trailingOnly = FALSE)
  script_dir <- dirname(sub("--file=", "", script_path[grep("--file", script_path)]))
  if (length(script_dir) > 0 && script_dir != "") {
    setwd(script_dir)
  }
}
cat("작업 디렉토리:", getwd(), "\n")

# 1. 필요한 패키지 로드
required_packages <- c("quanteda", "stm", "dplyr", "ggplot2")
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
  stop("필요한 패키지를 먼저 설치해주세요.")
}

# 2. DTM 파일 선택
dtm_files <- list.files("data/processed/", pattern = "^dtm_results_.*[.]rds$", full.names = TRUE)

if (length(dtm_files) == 0) {
  stop("DTM 결과 파일이 없습니다. 먼저 04_dtm_creation_interactive.R을 실행해주세요.")
}

cat("사용 가능한 DTM 파일:\n")
for (i in seq_along(dtm_files)) {
  cat(sprintf("%d. %s\n", i, basename(dtm_files[i])))
}

# 파일 선택 (비대화형 모드 대응)
if (interactive()) {
  file_choice <- as.integer(readline("DTM 파일 번호 선택: "))
} else {
  file_choice <- length(dtm_files)  # 최신 파일 자동 선택
  cat(sprintf("자동 선택: %d번 (%s)\n", file_choice, basename(dtm_files[file_choice])))
}

selected_file <- dtm_files[file_choice]
cat(sprintf("선택된 파일: %s\n", basename(selected_file)))

# 3. DTM 데이터 로드
cat("\n📂 DTM 데이터 로드 중...\n")
dtm_data <- readRDS(selected_file)
noun_dfm <- dtm_data$dfm
noun_corpus <- dtm_data$corpus

cat(sprintf("✅ DTM 로드 완료: %d개 문서, %d개 용어\n", ndoc(noun_dfm), nfeat(noun_dfm)))

# 4. 메타데이터 확인
docvars_df <- docvars(noun_corpus)
# 메타데이터 목록은 STM 변환 후 카테고리별로 표시됩니다

# 문서 ID 확인
if ("document_id" %in% names(docvars_df)) {
  cat(sprintf("✅ 문서 ID: document_id (샘플: %s)\n", 
              paste(head(docvars_df$document_id, 3), collapse = ", ")))
} else if ("doc_id" %in% names(docvars_df)) {
  cat(sprintf("✅ 문서 ID: doc_id (샘플: %s)\n", 
              paste(head(docvars_df$doc_id, 3), collapse = ", ")))
}

# 5. 연도 컬럼 확인 및 전처리
year_column <- NULL
if ("발행연도" %in% names(docvars_df)) {
  year_column <- "발행연도"
} else {
  year_candidates <- names(docvars_df)[grepl("발행연도|연도|년|year", names(docvars_df), ignore.case = TRUE)]
  if (length(year_candidates) > 0) {
    cat("\n발견된 연도 컬럼:\n")
    for (i in seq_along(year_candidates)) {
      cat(sprintf("  %d. %s\n", i, year_candidates[i]))
    }
    
    if (interactive()) {
      year_choice <- as.integer(readline("연도 컬럼 번호 선택: "))
    } else {
      year_choice <- 1  # 첫 번째 후보 자동 선택
      cat(sprintf("자동 선택: 1번 (%s)\n", year_candidates[1]))
    }
    
    year_column <- year_candidates[year_choice]
  }
}

if (is.null(year_column)) {
  stop("연도 컬럼을 찾을 수 없습니다.")
}

cat(sprintf("사용할 연도 컬럼: %s\n", year_column))

# 연도 데이터 전처리
years_raw <- docvars_df[[year_column]]
cat(sprintf("원본 연도 데이터 타입: %s\n", class(years_raw)[1]))
cat(sprintf("샘플: %s\n", paste(head(years_raw, 5), collapse = ", ")))

# 숫자형 변환
if (is.character(years_raw) || is.factor(years_raw)) {
  cat("📝 문자형 데이터를 숫자형으로 변환 중...\n")
  year_pattern <- "\\b(19|20)\\d{2}\\b"
  extracted_years <- regmatches(as.character(years_raw), regexpr(year_pattern, as.character(years_raw)))
  years <- suppressWarnings(as.numeric(extracted_years))
} else {
  years <- as.numeric(years_raw)
}

# 유효하지 않은 연도 제거
valid_years <- !is.na(years) & years >= 1900 & years <= 2030
invalid_count <- sum(!valid_years)

if (invalid_count > 0) {
  cat(sprintf("⚠️ 유효하지 않은 연도 %d개 발견, 해당 문서 제외\n", invalid_count))
  noun_dfm <- noun_dfm[valid_years, ]
  docvars_df <- docvars_df[valid_years, ]
  years <- years[valid_years]
}

cat(sprintf("✅ 최종 분석 대상: %d개 문서\n", ndoc(noun_dfm)))
cat(sprintf("연도 범위: %d - %d\n", min(years), max(years)))

# 6. quanteda → STM 변환
cat("\n🔄 quanteda → STM 변환 중...\n")

# docvars에 정제된 연도 추가
docvars_df$year_processed <- years

tryCatch({
  stm_data <- convert(noun_dfm, to = "stm", docvars = docvars_df)
  
  cat("✅ quanteda → STM 변환 성공!\n")
  cat(sprintf("📊 문서 수: %d개\n", length(stm_data$documents)))
  cat(sprintf("📝 어휘 수: %d개\n", length(stm_data$vocab)))
  cat(sprintf("📋 메타데이터: %d행 %d열\n", nrow(stm_data$meta), ncol(stm_data$meta)))
  
  # 메타데이터 필드 카테고리별 표시
  meta_columns <- names(stm_data$meta)
  
  # 메타데이터를 카테고리별로 분류하여 표시 (중복 제거됨)
  basic_info <- c("유형", "논문명", "논문외국어명", "논문영어명", "언어", "발행연도", "발행일")
  author_info <- c("저자명", "주저자 소속기관", "주저자 ORCID")
  journal_info <- c("학술지 ID", "학술지명", "학술지약어명", "학술지외국어명", "발행기관 ID", "발행기관명", "발행기관영어명", "ISSN", "eISSN")
  content_info <- c("저자키워드", "외국어키워드", "영어키워드", "초록", "외국어초록", "영어초록", "주제분야")
  publication_info <- c("권", "호", "특별호", "시작 페이지", "끝 페이지", "DOI", "URL", "KCI 등재 구분")
  citation_info <- c("참고문헌 수", "인용된 총 횟수", "참고문헌 목록")
  technical_info <- c("source_file", "document_id", "반출일", "year_processed")
  
  # 모든 정의된 필드들을 하나의 벡터로 합치기
  all_defined_fields <- c(basic_info, author_info, journal_info, content_info, 
                          publication_info, citation_info, technical_info)
  
  # 중복 체크 및 제거
  if(any(duplicated(all_defined_fields))) {
    duplicates <- all_defined_fields[duplicated(all_defined_fields)]
    cat("⚠️ 중복 필드 발견 및 제거됨:", paste(unique(duplicates), collapse = ", "), "\n")
    
    # 각 카테고리에서 중복 제거
    basic_info <- unique(basic_info)
    author_info <- unique(author_info)
    journal_info <- unique(journal_info)
    content_info <- unique(content_info)
    publication_info <- unique(publication_info)
    citation_info <- unique(citation_info)
    technical_info <- unique(technical_info)
  }

  cat("\n📋 사용 가능한 메타데이터 (카테고리별):\n")
  cat(rep("─", 60), "\n")

  categories <- list(
    "📄 기본 정보" = basic_info,
    "👤 저자 정보" = author_info,
    "📖 학술지 정보" = journal_info,
    "📝 내용 정보" = content_info,
    "📊 출간 정보" = publication_info,
    "📚 인용 정보" = citation_info,
    "🔧 기술 정보" = technical_info
  )

  for(category in names(categories)) {
    fields <- categories[[category]]
    available_fields <- fields[fields %in% meta_columns]
    
    if(length(available_fields) > 0) {
      cat(sprintf("\n%s:\n", category))
      # 3열로 정렬하되 충분한 폭 확보
      for(i in seq_along(available_fields)) {
        cat(sprintf("  %-25s", available_fields[i]))
        if(i %% 3 == 0) cat("\n")
      }
      # 마지막 줄이 3의 배수가 아닌 경우 줄바꿈 추가
      if(length(available_fields) %% 3 != 0) cat("\n")
    }
  }

  # 정의된 필드와 실제 필드 비교
  all_defined_unique <- unique(all_defined_fields)
  missing_from_data <- setdiff(all_defined_unique, meta_columns)
  extra_in_data <- setdiff(meta_columns, all_defined_unique)
  
  # 실제 표시된 필드 개수 계산
  total_displayed_fields <- sum(sapply(categories, function(fields) {
    length(fields[fields %in% meta_columns])
  }))
  
  cat(sprintf("\n💡 총 %d개 메타데이터 필드 사용 가능 (분류된 필드: %d개)\n", 
              length(meta_columns), total_displayed_fields))
  
  if(length(missing_from_data) > 0) {
    cat("ℹ️ 정의되었지만 데이터에 없는 필드:", paste(missing_from_data, collapse = ", "), "\n")
  }
  if(length(extra_in_data) > 0) {
    cat("ℹ️ 데이터에는 있지만 분류되지 않은 필드:", paste(extra_in_data, collapse = ", "), "\n")
  }
  
  # 분류 완전성 확인
  if(total_displayed_fields == length(meta_columns) && length(extra_in_data) == 0) {
    cat("✅ 모든 메타데이터 필드가 적절히 분류되었습니다.\n")
  } else if(length(extra_in_data) > 0) {
    cat("⚠️ 일부 필드가 분류되지 않았습니다. 카테고리 정의를 확인하세요.\n")
  }
  
  # 중요 필드 확인
  if ("document_id" %in% meta_columns) {
    cat("✅ document_id 보존됨\n")
  }
  if ("year_processed" %in% meta_columns) {
    cat("✅ year_processed 생성됨\n")
  }
  if ("연도" %in% meta_columns) {
    cat("✅ 연도 필드 확인됨\n")
  }
  
}, error = function(e) {
  stop(sprintf("quanteda → STM 변환 실패: %s", e$message))
})

# 7. STM 모델 훈련 (K=8, 스플라인 공변량)
cat("\n🧠 STM 모델 훈련 중 (K=8, 스플라인 공변량)...\n")
cat("이 작업은 몇 분이 소요될 수 있습니다...\n")

start_time <- Sys.time()

stm_model <- stm(documents = stm_data$documents,
                vocab = stm_data$vocab,
                K = 8,
                prevalence = ~ s(year_processed),  # 스플라인 함수 적용
                data = stm_data$meta,
                verbose = TRUE,
                seed = 12345)

end_time <- Sys.time()
training_time <- round(difftime(end_time, start_time, units = "mins"), 2)

cat(sprintf("✅ STM 모델 훈련 완료! (소요 시간: %s분)\n", training_time))

# 8. 결과 저장
output_file <- sprintf("data/processed/stm_topic_model_%s.rds", format(Sys.time(), "%Y%m%d_%H%M%S"))

stm_results <- list(
  model = stm_model,
  stm_data = stm_data,
  metadata = list(
    K = 8,
    prevalence_formula = "~ s(year_processed)",
    year_column = year_column,
    doc_count = ndoc(noun_dfm),
    vocab_count = length(stm_data$vocab),
    training_time = training_time,
    creation_time = Sys.time()
  )
)

saveRDS(stm_results, output_file)
cat(sprintf("✅ 결과 저장 완료: %s\n", basename(output_file)))

# 9. 간단한 결과 요약
cat("\n📊 STM 분석 결과 요약\n")
cat(rep("=", 50), "\n")
cat(sprintf("토픽 수: %d\n", stm_model$settings$dim$K))
cat(sprintf("문서 수: %d\n", stm_model$settings$dim$N))
cat(sprintf("어휘 수: %d\n", stm_model$settings$dim$V))
cat(sprintf("공변량: 발행연도 스플라인\n"))
cat(sprintf("메타데이터 매칭: 자동 (quanteda 보장)\n"))

cat("\n💡 다음 단계:\n")
cat("- 토픽별 주요 단어 확인: labelTopics(stm_model)\n") 
cat("- 토픽 간 상관관계: topicCorr(stm_model)\n")
cat("- 연도별 토픽 변화: estimateEffect(..., stm_model)\n")
cat("- 토픽 시각화: plot(stm_model)\n")

# 10. 분석 보고서 생성 및 저장 (Markdown 형식)
report_content <- c(
  "# STM 토픽모델링 분석 보고서",
  "",
  sprintf("**생성일시**: %s  ", Sys.time()),
  "**분석 방법**: quanteda → STM 직접 변환  ",
  "",
  "## 📊 분석 설정",
  "",
  sprintf("- 토픽 수: %d  ", stm_model$settings$dim$K),
  sprintf("- 문서 수: %d  ", stm_model$settings$dim$N),
  sprintf("- 어휘 수: %d  ", stm_model$settings$dim$V),
  "- 공변량: 발행연도 스플라인 함수 (~s(year))  ",
  sprintf("- 연도 범위: %d - %d  ", min(years), max(years)),
  sprintf("- 훈련 시간: %.2f분  ", training_time),
  "",
  "## ✅ 메타데이터 매칭",
  "",
  "- 매칭 방식: quanteda convert() 자동 매칭  ",
  sprintf("- 메타데이터: %d행 %d열  ", nrow(stm_data$meta), ncol(stm_data$meta)),
  sprintf("- 문서 ID: %s  ", ifelse("document_id" %in% names(stm_data$meta), "보존됨", "미확인")),
  "",
  "## 📁 결과 파일",
  "",
  sprintf("- STM 모델: %s  ", basename(output_file)),
  sprintf("- 원본 DTM: %s  ", basename(selected_file)),
  "",
  "## 💡 다음 분석 단계",
  "",
  "1. `labelTopics(stm_model)` - 토픽별 주요 단어 확인  ",
  "2. `topicCorr(stm_model)` - 토픽 간 상관관계 분석  ", 
  "3. `estimateEffect(..., stm_model)` - 연도별 토픽 변화  ",
  "4. `plot(stm_model)` - 토픽 시각화  "
)

# reports 폴더가 없으면 생성
if (!dir.exists("reports")) {
  dir.create("reports", recursive = TRUE)
}

report_filename <- sprintf("reports/stm_analysis_report_%s.md", format(Sys.time(), "%Y%m%d_%H%M%S"))
writeLines(report_content, report_filename)
cat(sprintf("✅ 분석 보고서 저장: %s\n", basename(report_filename)))

cat("\n✅ quanteda 기반 STM 분석 완료!\n")

# ========== 추가 분석 예시 안내 ==========
cat("\n📊 추가 분석 예시\n")
cat(rep("=", 60), "\n")
cat("\n💡 주요 분석 명령어:\n")

cat("🔍 기본 분석:\n")
cat("  labelTopics(stm_model)                    # 토픽별 주요 단어\n")
cat("  findThoughts(stm_model, n=3, topics=1)   # 토픽 대표 문서\n")
cat("  topics(stm_model)                        # 문서별 주요 토픽\n\n")

cat("📊 품질 평가:\n") 
cat("  topicQuality(stm_model, documents)       # 토픽 품질 점수\n")
cat("  topicCorr(stm_model)                     # 토픽 간 상관관계\n\n")

cat("📈 시간 분석:\n")
cat("  prep <- estimateEffect(1:8 ~ s(연도), stm_model, meta=stm_data$meta)\n")
cat("  plot(prep, topics=1, method='continuous') # 연도별 토픽 변화\n\n")

cat("🎨 시각화:\n")
cat("  plot(stm_model)                          # 기본 토픽 플롯\n")
cat("  cloud(stm_model, topic=1)                # 워드클라우드\n\n")

cat("💡 권장 순서: labelTopics → findThoughts → topicQuality → 시각화\n")

# ========== labelTopics 기반 STM 분석 보고서 생성 ==========
cat("\n📝 STM 분석 보고서 생성 중...\n")

tryCatch({
  # labelTopics 실행
  topic_labels <- labelTopics(stm_model, n = 15)
  
  # 토픽 비중 계산 (theta 값 이용)
  doc_topics <- stm_model$theta
  avg_topic_prop <- colMeans(doc_topics)
  topic_ranking <- order(avg_topic_prop, decreasing = TRUE)
  
  # 보고서 내용 생성 (Markdown 형식)
  report_content <- c(
    "# STM 토픽모델링 분석 보고서",
    "",
    sprintf("**생성일시**: %s  ", Sys.time()),
    sprintf("**분석 모델**: STM (K=%d)  ", stm_model$settings$dim$K),
    sprintf("**문서 수**: %d개  ", stm_model$settings$dim$N),
    sprintf("**어휘 수**: %d개  ", stm_model$settings$dim$V),
    "",
    "## 📊 토픽별 상세 분석 (평균 비중 순)",
    ""
  )
  
  # 각 토픽별 상세 정보 (Markdown 형식)
  for(rank in 1:stm_model$settings$dim$K) {
    topic_idx <- topic_ranking[rank]
    proportion <- round(avg_topic_prop[topic_idx] * 100, 1)
    
    report_content <- c(report_content,
      sprintf("### 🏷️ 토픽 %d (평균 비중: %.1f%%, 순위: %d위)", topic_idx, proportion, rank),
      "",
      "**📈 확률 기반 주요 단어 (상위 10개):**  ",
      sprintf("%s  ", paste(topic_labels$prob[topic_idx, 1:10], collapse = " | ")),
      "",
      "**🎯 FREX 기반 특징 단어 (상위 10개):**  ",
      sprintf("%s  ", paste(topic_labels$frex[topic_idx, 1:10], collapse = " | ")),
      "",
      "**⚡ Lift 기반 차별 단어 (상위 8개):**  ",
      sprintf("%s  ", paste(topic_labels$lift[topic_idx, 1:8], collapse = " | ")),
      "",
      "**🔍 Score 기반 균형 단어 (상위 8개):**  ",
      sprintf("%s  ", paste(topic_labels$score[topic_idx, 1:8], collapse = " | ")),
      ""
    )
  }
  
  # 토픽 해석 가이드 추가 (Markdown 형식)
  report_content <- c(report_content,
    "## 📋 토픽 해석 가이드",
    "",
    "- **확률 기반**: 해당 토픽에서 가장 자주 나타나는 단어들  ",
    "- **FREX 기반**: 다른 토픽과 구별되는 특징적인 단어들 (권장)  ",
    "- **Lift 기반**: 해당 토픽에서만 특별히 많이 나타나는 단어들  ",
    "- **Score 기반**: 빈도와 배타성을 균형 있게 고려한 단어들  ",
    "",
    "## 💡 토픽 명명 권장사항",
    "",
    "1. FREX 단어를 우선적으로 고려하여 토픽의 주제를 파악  ",
    "2. 확률 기반 단어로 토픽의 전반적인 내용 확인  ", 
    "3. Lift 단어로 토픽의 독특한 특성 파악  ",
    "4. 여러 지표를 종합하여 의미있는 토픽 이름 부여  ",
    "",
    "## 📈 토픽 비중 요약",
    ""
  )
  
  # 상위 토픽 요약 (Markdown 형식)
  top5_topics <- topic_ranking[1:min(5, length(topic_ranking))]
  for(i in 1:length(top5_topics)) {
    topic_idx <- top5_topics[i]
    proportion <- round(avg_topic_prop[topic_idx] * 100, 1)
    main_words <- paste(topic_labels$frex[topic_idx, 1:5], collapse = ", ")
    report_content <- c(report_content,
      sprintf("%d. **토픽 %d**: %.1f%% - %s  ", i, topic_idx, proportion, main_words)
    )
  }
  
  report_content <- c(report_content,
    "",
    "---",
    "",
    "**보고서 생성 완료** | 다음 단계: `findThoughts()`로 대표 문서 확인  "
  )
  
  # 보고서 저장
  report_filename <- sprintf("reports/stm_labelTopics_report_%s.md", 
                             format(Sys.time(), "%Y%m%d_%H%M%S"))
  writeLines(report_content, report_filename, useBytes = TRUE)
  
  cat(sprintf("✅ STM 분석 보고서 생성 완료: %s\n", basename(report_filename)))
  
  # 간단한 콘솔 요약 출력
  cat("\n📊 토픽 요약 (상위 5개):\n")
  for(i in 1:min(5, length(top5_topics))) {
    topic_idx <- top5_topics[i]
    proportion <- round(avg_topic_prop[topic_idx] * 100, 1)
    main_words <- paste(topic_labels$frex[topic_idx, 1:4], collapse = ", ")
    cat(sprintf("  %d위. 토픽 %d (%.1f%%): %s\n", i, topic_idx, proportion, main_words))
  }
  
}, error = function(e) {
  cat(sprintf("❌ 보고서 생성 실패: %s\n", e$message))
  cat("수동으로 labelTopics(stm_model)를 실행하여 결과를 확인하세요.\n")
})

cat("\n🎉 STM 분석 완료!\n")
cat("📁 분석 결과와 상세 보고서가 저장되었습니다.\n")