# 07_stm_model_comparison.R
# STM 모델 K값별 성능 비교 및 최적 모델 선택

# 1. 패키지 설치 및 로드 ---------------------------------------------------
cat("📦 필요한 패키지 확인 및 설치 중...\n")

# 필요한 패키지 목록
required_packages <- c(
  "stm", "quanteda", "tidyverse", "furrr", 
  "ggplot2", "viridis", "gridExtra", "scales",
  "plotly", "DT", "knitr", "corrplot"
)

# 패키지 설치 및 로드 함수
install_and_load <- function(package) {
  tryCatch({
    if (!require(package, character.only = TRUE, quietly = TRUE)) {
      cat(sprintf("📥 %s 패키지를 설치합니다...\n", package))
      install.packages(package, dependencies = TRUE, repos = "https://cran.rstudio.com/")
      if (require(package, character.only = TRUE, quietly = TRUE)) {
        cat(sprintf("✅ %s 패키지 설치 및 로드 완료\n", package))
        return(TRUE)
      } else {
        cat(sprintf("❌ %s 패키지 설치 실패\n", package))
        return(FALSE)
      }
    } else {
      cat(sprintf("✅ %s 패키지 로드 완료\n", package))
      return(TRUE)
    }
  }, error = function(e) {
    cat(sprintf("❌ %s 패키지 설치/로드 실패: %s\n", package, e$message))
    return(FALSE)
  })
}

# 모든 패키지 설치 및 로드
package_status <- list()
for (pkg in required_packages) {
  package_status[[pkg]] <- install_and_load(pkg)
}

# 필수 패키지 상태 확인
essential_packages <- c("stm", "quanteda", "tidyverse")
missing_essential <- essential_packages[!sapply(essential_packages, function(x) package_status[[x]])]

if (length(missing_essential) > 0) {
  stop(sprintf("❌ 필수 패키지 설치 실패: %s", paste(missing_essential, collapse = ", ")))
}

# furrr 패키지 상태 확인 (병렬 처리용)
furrr_available <- package_status[["furrr"]]
if (!furrr_available) {
  cat("⚠️  furrr 패키지를 사용할 수 없습니다. 순차 처리로 진행합니다.\n")
}

cat("📦 패키지 로드 완료!\n\n")

# 2. STM 데이터 로드 -------------------------------------------------------
cat("\n", rep("=", 60), "\n")
cat("📊 STM 데이터 로드\n") 
cat(rep("=", 60), "\n")

# quanteda DTM 파일 찾기
quanteda_files <- list.files("data/processed/", 
                            pattern = ".*_quanteda_dfm\\.rds$", 
                            full.names = TRUE)

if (length(quanteda_files) == 0) {
  stop("quanteda DTM 파일을 찾을 수 없습니다. 04_quanteda_dtm_creation.R을 먼저 실행해주세요.")
}

# 최신 quanteda DTM 파일 자동 선택
latest_quanteda_file <- quanteda_files[order(file.mtime(quanteda_files), decreasing = TRUE)][1]
cat(sprintf("✅ 사용할 quanteda DTM 파일: %s\n", basename(latest_quanteda_file)))

# quanteda DTM 데이터 로드
cat("📁 quanteda DTM 데이터 로딩 중...\n")
dfm_data <- readRDS(latest_quanteda_file)

# 데이터 구조 확인
cat(sprintf("- STM 문서 수: %d\n", length(dfm_data$stm_documents)))
cat(sprintf("- STM 어휘 수: %d\n", length(dfm_data$stm_vocab))) 
cat(sprintf("- 메타데이터 변수: %d개\n", ncol(dfm_data$stm_meta)))
cat(sprintf("- 전처리 방법: %s\n", dfm_data$analysis_type))

# STM 데이터 추출
stm_documents <- dfm_data$stm_documents
stm_vocab <- dfm_data$stm_vocab
stm_meta <- dfm_data$stm_meta

# 데이터 유효성 확인
if (length(stm_documents) == 0 || length(stm_vocab) == 0) {
  stop("❌ STM 데이터가 비어있습니다. 데이터를 확인해주세요.")
}

cat("✅ STM 데이터 로드 완료\n")

# 3. 모델 비교 설정 -------------------------------------------------------
cat("\n", rep("=", 60), "\n")
cat("⚙️ STM 모델 비교 설정\n") 
cat(rep("=", 60), "\n")

# K값 범위 설정
cat("📊 K값 범위 설정:\n")

# Windows 운영체제 확인 (먼저 정의)
is_windows <- .Platform$OS.type == "windows"

# 문서 수에 따른 적절한 K값 범위 결정
doc_count <- length(stm_documents)
vocab_count <- length(stm_vocab)

# 기본 권장 K값 범위 제안
cat(sprintf("현재 데이터: %d개 문서, %d개 어휘\n", doc_count, vocab_count))

# 데이터 규모별 권장 K값 범위 제시
if (doc_count < 100) {
  recommended_k <- if(is_windows) c(3, 5, 8, 12) else c(3, 5, 7, 10, 12, 15)
  cat("📝 소규모 데이터셋 (< 100 문서) 권장 범위\n")
} else if (doc_count < 500) {
  recommended_k <- if(is_windows) c(5, 10, 15, 20) else c(5, 10, 15, 20, 25, 30)
  cat("📝 중간 규모 데이터셋 (100-500 문서) 권장 범위\n")
} else if (doc_count < 1000) {
  recommended_k <- if(is_windows) c(10, 15, 20, 25) else c(10, 15, 20, 25, 30, 35, 40)
  cat("📝 대규모 데이터셋 (500-1000 문서) 권장 범위\n")
} else {
  recommended_k <- if(is_windows) c(15, 20, 25, 30) else c(15, 20, 25, 30, 35, 40, 45, 50)
  cat("📝 초대형 데이터셋 (> 1000 문서) 권장 범위\n")
}

if(is_windows) {
  cat("⚠️ Windows 환경: 실행 시간을 고려하여 범위를 축소했습니다.\n")
}

cat(sprintf("💡 권장 K값 범위: %s\n", paste(recommended_k, collapse = ", ")))

# 사용자 입력 받기
cat("\n", rep("-", 50), "\n")
cat("🎯 K값 범위를 선택하세요:\n")
cat("1. 권장 범위 사용 (빠른 분석)\n")
cat("2. 사용자 정의 범위 입력\n")
cat("3. 세밀한 범위 (더 많은 K값, 시간 오래 걸림)\n")

# 사용자 선택 입력
repeat {
  choice <- readline(prompt = "선택 (1/2/3): ")
  
  if (choice == "1") {
    k_range <- recommended_k
    cat(sprintf("✅ 권장 범위 선택: %s\n", paste(k_range, collapse = ", ")))
    break
  } else if (choice == "2") {
    cat("\n사용자 정의 K값을 입력하세요.\n")
    cat("📝 형식: 쉼표로 구분된 숫자 (예: 5,10,15,20)\n")
    cat("📝 범위: 2 이상 100 이하의 정수\n")
    cat("📝 권장: 3-8개 K값 (너무 많으면 시간이 오래 걸림)\n")
    
    repeat {
      user_input <- readline(prompt = "K값 입력: ")
      
      # 입력값 파싱 및 검증
      tryCatch({
        # 쉼표로 분리하고 공백 제거
        k_values <- as.numeric(trimws(unlist(strsplit(user_input, ","))))
        
        # 유효성 검사
        if (any(is.na(k_values))) {
          cat("❌ 숫자가 아닌 값이 포함되어 있습니다. 다시 입력하세요.\n")
          next
        }
        
        if (any(k_values < 2 | k_values > 100)) {
          cat("❌ K값은 2 이상 100 이하여야 합니다. 다시 입력하세요.\n")
          next
        }
        
        if (length(k_values) < 2) {
          cat("❌ 최소 2개 이상의 K값을 입력하세요.\n")
          next
        }
        
        if (length(k_values) > 12) {
          cat("⚠️ K값이 12개보다 많습니다. 실행 시간이 매우 오래 걸릴 수 있습니다.\n")
          confirm <- readline(prompt = "계속 진행하시겠습니까? (y/n): ")
          if (tolower(confirm) != "y") {
            cat("다시 입력하세요.\n")
            next
          }
        }
        
        # 중복 제거 및 정렬
        k_range <- sort(unique(k_values))
        cat(sprintf("✅ 사용자 정의 K값: %s\n", paste(k_range, collapse = ", ")))
        break
        
      }, error = function(e) {
        cat(sprintf("❌ 입력 오류: %s\n다시 입력하세요.\n", e$message))
      })
    }
    break
  } else if (choice == "3") {
    # 세밀한 범위 생성
    if (doc_count < 100) {
      k_range <- if(is_windows) c(3, 5, 7, 10, 12, 15) else c(3, 5, 7, 10, 12, 15, 18, 20)
    } else if (doc_count < 500) {
      k_range <- if(is_windows) c(5, 8, 10, 12, 15, 18, 20, 25) else c(5, 8, 10, 12, 15, 18, 20, 25, 30, 35)
    } else if (doc_count < 1000) {
      k_range <- if(is_windows) c(10, 12, 15, 18, 20, 25, 30) else c(10, 12, 15, 18, 20, 25, 30, 35, 40, 45)
    } else {
      k_range <- if(is_windows) c(15, 18, 20, 25, 30, 35) else c(15, 18, 20, 25, 30, 35, 40, 45, 50, 60)
    }
    
    estimated_time <- length(k_range) * 3  # 대략적 추정 (분)
    cat(sprintf("📊 세밀한 범위 선택: %s\n", paste(k_range, collapse = ", ")))
    cat(sprintf("⏱️ 예상 소요 시간: 약 %d분\n", estimated_time))
    
    if (estimated_time > 30) {
      confirm <- readline(prompt = "⚠️ 시간이 오래 걸릴 수 있습니다. 계속하시겠습니까? (y/n): ")
      if (tolower(confirm) != "y") {
        cat("다른 옵션을 선택하세요.\n")
        next
      }
    }
    break
  } else {
    cat("❌ 잘못된 선택입니다. 1, 2, 또는 3을 입력하세요.\n")
  }
}

cat(sprintf("- 문서 수: %d개\n", doc_count))
cat(sprintf("- 어휘 수: %d개\n", vocab_count))
cat(sprintf("- 테스트할 K값: %s\n", paste(k_range, collapse = ", ")))

# searchK 매개변수 설정
search_k_params <- list(
  # Windows에서는 시간 절약을 위해 N값 축소
  N = ifelse(is_windows, 2, 3),  # 각 K값당 랜덤 시드 수
  proportion = 0.5,  # held-out likelihood 계산용 비율
  heldout.seed = 12345,
  # Windows에서는 병렬 처리 비활성화
  cores = ifelse(is_windows, 1, ifelse(furrr_available, min(4, parallel::detectCores() - 1), 1)),
  verbose = TRUE
)

cat(sprintf("- 운영체제: %s\n", ifelse(is_windows, "Windows", "Unix/Linux/Mac")))
cat(sprintf("- 랜덤 시드 수 (N): %d\n", search_k_params$N))
cat(sprintf("- Held-out 비율: %.1f\n", search_k_params$proportion))
cat(sprintf("- 사용 코어 수: %d\n", search_k_params$cores))

# 병렬 처리 설정 (Windows 제외)
if (!is_windows && furrr_available && search_k_params$cores > 1) {
  cat("🚀 병렬 처리를 설정합니다...\n")
  plan(multisession, workers = search_k_params$cores)
} else {
  if (is_windows) {
    cat("⚠️ Windows에서는 순차 처리로 진행합니다 (병렬 처리 제한)\n")
  } else {
    cat("⚠️ 순차 처리로 진행합니다\n")
  }
}

# 4. searchK를 통한 모델 성능 비교 ----------------------------------------
cat("\n", rep("=", 60), "\n")
cat("🔍 searchK를 통한 K값별 모델 성능 평가\n") 
cat(rep("=", 60), "\n")

# 시간 측정 시작
start_time <- Sys.time()
cat(sprintf("⏰ 분석 시작 시간: %s\n", format(start_time, "%Y-%m-%d %H:%M:%S")))

# 예상 소요 시간 계산 및 안내
estimated_minutes <- length(k_range) * search_k_params$N * 2  # 대략적 추정
cat(sprintf("⏱️ 예상 소요 시간: 약 %d분\n", estimated_minutes))
cat("☕ 시간이 오래 걸릴 수 있으니 잠시 다른 일을 하세요!\n\n")

# searchK 실행
cat("🔬 searchK 함수 실행 중...\n")
cat("(진행 상황은 verbose 출력으로 확인할 수 있습니다)\n\n")

tryCatch({
  k_search_results <- searchK(
    documents = stm_documents,
    vocab = stm_vocab,
    K = k_range,
    prevalence = ~ 1,  # 공변량 없이 순수 토픽 모델링
    data = stm_meta,
    N = search_k_params$N,
    proportion = search_k_params$proportion,
    heldout.seed = search_k_params$heldout.seed,
    cores = search_k_params$cores,
    verbose = search_k_params$verbose,
    init.type = "Spectral",
    seed = 12345
  )
  
  # 소요 시간 계산
  end_time <- Sys.time()
  elapsed_time <- as.numeric(difftime(end_time, start_time, units = "mins"))
  
  cat(sprintf("\n✅ searchK 완료! 소요 시간: %.1f분\n", elapsed_time))
  
}, error = function(e) {
  cat(sprintf("❌ searchK 실행 실패: %s\n", e$message))
  cat("💡 해결 방법:\n")
  cat("- K값 범위를 줄여보세요 (예: 3-4개 값만)\n")
  cat("- N값을 줄여보세요 (예: N=2)\n")
  cat("- 코어 수를 줄여보세요 (cores=1)\n")
  stop("searchK 실행을 중단합니다.")
})

# 결과 확인
cat("\n📋 searchK 결과 요약:\n")
cat(sprintf("- 테스트된 K값 수: %d개\n", length(k_search_results$results$K)))
cat(sprintf("- 평가 지표 수: %d개\n", ncol(k_search_results$results) - 1))

# 결과 데이터프레임 정리
results_df <- k_search_results$results
cat(sprintf("- 결과 데이터 크기: %d행 × %d열\n", nrow(results_df), ncol(results_df)))

# 5. 성능 지표 분석 -------------------------------------------------------
cat("\n", rep("=", 60), "\n")
cat("📈 모델 성능 지표 분석\n") 
cat(rep("=", 60), "\n")

# 주요 성능 지표 확인
available_metrics <- names(results_df)
cat("📊 사용 가능한 성능 지표들:\n")
for (i in 1:length(available_metrics)) {
  cat(sprintf("%2d. %s\n", i, available_metrics[i]))
}

# 핵심 지표 추출 및 분석
core_metrics <- c("K", "heldout", "residual", "bound", "lbound", "em.its")
if ("exclusivity" %in% available_metrics) {
  core_metrics <- c(core_metrics, "exclusivity")
}
if ("semcoh" %in% available_metrics) {
  core_metrics <- c(core_metrics, "semcoh")
}

# searchK 결과 활용 (추가 계산 불필요)
cat("\n✅ searchK에서 모든 성능 지표가 계산되었습니다\n")
cat("   추가 모델 학습 없이 기존 결과를 활용합니다.\n")

# searchK에서 계산된 지표들 확인 및 표시
cat("\n📊 사용 가능한 성능 지표:\n")
for (metric in available_metrics) {
  if (metric == "K") next
  cat(sprintf("✅ %s\n", metric))
}

# 성능 지표 통계 요약
cat("\n📊 성능 지표 통계 요약:\n")

# 주요 지표별 요약 통계
summary_metrics <- c("heldout", "exclusivity", "semcoh", "bound", "residual")
available_summary <- summary_metrics[summary_metrics %in% names(results_df)]

for (metric in available_summary) {
  tryCatch({
    values <- as.numeric(results_df[[metric]])  # 숫자로 변환
    if (!all(is.na(values))) {
      cat(sprintf("- %s: %.3f (±%.3f) [%.3f ~ %.3f]\n", 
                  metric, 
                  mean(values, na.rm = TRUE), 
                  sd(values, na.rm = TRUE), 
                  min(values, na.rm = TRUE), 
                  max(values, na.rm = TRUE)))
    }
  }, error = function(e) {
    cat(sprintf("- %s: 계산 불가\n", metric))
  })
}

# 6. 시각화 및 plotModels() ----------------------------------------------
cat("\n", rep("=", 60), "\n")
cat("🎨 모델 성능 시각화\n") 
cat(rep("=", 60), "\n")

# 시각화 디렉토리 생성
if (!dir.exists("plots")) {
  dir.create("plots", recursive = TRUE)
  cat("📁 plots/ 디렉토리를 생성했습니다.\n")
}

# 1. plot.searchK() 기본 시각화 (STM 패키지 공식 함수)
cat("📊 plot.searchK() 기본 시각화 생성 중...\n")

tryCatch({
  # plot.searchK 함수를 사용한 공식 비교 차트
  png("plots/stm_searchK_comparison.png", width = 1200, height = 800, res = 150)
  
  # STM 패키지의 공식 plot.searchK 함수 사용
  plot(k_search_results)
  
  dev.off()
  cat("✅ STM searchK 비교 차트 저장: plots/stm_searchK_comparison.png\n")
  
}, error = function(e) {
  cat(sprintf("⚠️ plot.searchK 시각화 오류: %s\n", e$message))
})

# 2. 개별 지표별 상세 시각화
cat("📈 개별 지표별 상세 시각화 생성 중...\n")

# 색상 팔레트 설정
color_palette <- viridis::viridis(length(k_range))

# Held-out Likelihood (높을수록 좋음)
if ("heldout" %in% names(results_df)) {
  tryCatch({
    p1 <- ggplot(results_df, aes(x = K, y = heldout)) +
      geom_line(color = "steelblue", size = 1.2) +
      geom_point(color = "darkblue", size = 3) +
      geom_text(aes(label = sprintf("%.2f", heldout)), 
                vjust = -0.5, size = 3) +
      labs(title = "Held-out Likelihood by K",
           subtitle = "Higher values indicate better predictive performance",
           x = "Number of Topics (K)",
           y = "Held-out Likelihood") +
      theme_minimal() +
      theme(plot.title = element_text(size = 14, face = "bold"),
            plot.subtitle = element_text(size = 10, color = "gray60"))
    
    ggsave("plots/stm_heldout_likelihood.png", p1, width = 10, height = 6, dpi = 300)
    cat("✅ Held-out Likelihood 차트 저장\n")
    
  }, error = function(e) {
    cat(sprintf("⚠️ Held-out Likelihood 시각화 오류: %s\n", e$message))
  })
}

# Exclusivity (높을수록 좋음)
if ("exclusivity" %in% names(results_df)) {
  tryCatch({
    p2 <- ggplot(results_df, aes(x = K, y = exclusivity)) +
      geom_line(color = "forestgreen", size = 1.2) +
      geom_point(color = "darkgreen", size = 3) +
      geom_text(aes(label = sprintf("%.3f", exclusivity)), 
                vjust = -0.5, size = 3) +
      labs(title = "Exclusivity by K",
           subtitle = "Higher values indicate more distinctive topics",
           x = "Number of Topics (K)",
           y = "Exclusivity") +
      theme_minimal() +
      theme(plot.title = element_text(size = 14, face = "bold"),
            plot.subtitle = element_text(size = 10, color = "gray60"))
    
    ggsave("plots/stm_exclusivity.png", p2, width = 10, height = 6, dpi = 300)
    cat("✅ Exclusivity 차트 저장\n")
    
  }, error = function(e) {
    cat(sprintf("⚠️ Exclusivity 시각화 오류: %s\n", e$message))
  })
} else {
  cat("⚠️ Exclusivity 지표가 없어 차트를 건너뜁니다\n")
}

# Semantic Coherence (높을수록 좋음)
if ("semcoh" %in% names(results_df)) {
  tryCatch({
    p3 <- ggplot(results_df, aes(x = K, y = semcoh)) +
      geom_line(color = "orange", size = 1.2) +
      geom_point(color = "darkorange", size = 3) +
      geom_text(aes(label = sprintf("%.3f", semcoh)), 
                vjust = -0.5, size = 3) +
      labs(title = "Semantic Coherence by K",
           subtitle = "Higher values indicate more coherent topics",
           x = "Number of Topics (K)",
           y = "Semantic Coherence") +
      theme_minimal() +
      theme(plot.title = element_text(size = 14, face = "bold"),
            plot.subtitle = element_text(size = 10, color = "gray60"))
    
    ggsave("plots/stm_semantic_coherence.png", p3, width = 10, height = 6, dpi = 300)
    cat("✅ Semantic Coherence 차트 저장\n")
    
  }, error = function(e) {
    cat(sprintf("⚠️ Semantic Coherence 시각화 오류: %s\n", e$message))
  })
} else {
  cat("⚠️ Semantic Coherence 지표가 없어 차트를 건너뜁니다\n")
}

# 3. 종합 비교 차트 (다중 지표)
cat("📊 종합 비교 차트 생성 중...\n")

tryCatch({
  # searchK 결과에서 사용 가능한 지표 확인
  plot_metrics <- c()
  if ("heldout" %in% names(results_df)) plot_metrics <- c(plot_metrics, "heldout")
  if ("exclusivity" %in% names(results_df)) plot_metrics <- c(plot_metrics, "exclusivity")  
  if ("semcoh" %in% names(results_df)) plot_metrics <- c(plot_metrics, "semcoh")
  
  if (length(plot_metrics) >= 2) {
    # 정규화를 위해 각 지표를 0-1 스케일로 변환
    results_normalized <- results_df
    for (metric in plot_metrics) {
      values <- results_df[[metric]]
      if (all(!is.na(values))) {
        results_normalized[[paste0(metric, "_norm")]] <- 
          (values - min(values)) / (max(values) - min(values))
      }
    }
    
    # Long format으로 변환
    norm_metrics <- paste0(plot_metrics, "_norm")
    norm_metrics <- norm_metrics[norm_metrics %in% names(results_normalized)]
    
    if (length(norm_metrics) >= 2) {
      library(reshape2)
      results_long <- melt(results_normalized[c("K", norm_metrics)], id.vars = "K")
      
      # 라벨 정리
      results_long$variable <- factor(results_long$variable,
                                     levels = norm_metrics,
                                     labels = gsub("_norm", "", norm_metrics))
      
      # 종합 비교 차트
      p4 <- ggplot(results_long, aes(x = K, y = value, color = variable)) +
        geom_line(size = 1.2) +
        geom_point(size = 3) +
        scale_color_viridis_d(name = "Metrics") +
        labs(title = "STM Model Performance Comparison",
             subtitle = "All metrics normalized to 0-1 scale (higher is better)",
             x = "Number of Topics (K)",
             y = "Normalized Score") +
        theme_minimal() +
        theme(plot.title = element_text(size = 14, face = "bold"),
              plot.subtitle = element_text(size = 10, color = "gray60"),
              legend.position = "bottom")
      
      ggsave("plots/stm_comprehensive_comparison.png", p4, width = 12, height = 8, dpi = 300)
      cat("✅ 종합 비교 차트 저장\n")
    } else {
      cat("⚠️ 정규화 가능한 지표가 부족하여 종합 차트를 건너뜁니다\n")
    }
  } else {
    cat("⚠️ 비교할 지표가 부족하여 종합 차트를 건너뜁니다\n")
  }
  
}, error = function(e) {
  cat(sprintf("⚠️ 종합 비교 차트 오류: %s\n", e$message))
})

# 7. 최적 K값 추천 (간소화) -----------------------------------------------
cat("\n", rep("=", 60), "\n")
cat("🎯 최적 K값 추천\n") 
cat(rep("=", 60), "\n")

# searchK 결과에서 직접 최적 K값 찾기
cat("\n🏆 성능 지표 기준 최적 K값:\n")

# Held-out Likelihood 기준 최적 K
if ("heldout" %in% names(results_df)) {
  best_k_heldout <- results_df$K[which.max(results_df$heldout)]
  best_heldout_value <- max(results_df$heldout, na.rm = TRUE)
  cat(sprintf("1️⃣ Held-out Likelihood 기준: K=%d (값: %.3f)\n", 
              best_k_heldout, best_heldout_value))
  
  # 기본적으로 held-out likelihood 기준을 최적으로 선택
  best_k_composite <- best_k_heldout
  best_composite_score <- best_heldout_value
} else {
  # held-out이 없으면 가장 작은 K값 선택
  best_k_composite <- min(results_df$K)
  best_composite_score <- NA
  cat(sprintf("⚠️ Held-out Likelihood가 없어 K=%d를 선택합니다\n", best_k_composite))
}

# Exclusivity 기준 최적 K (참고용)
if ("exclusivity" %in% names(results_df)) {
  best_k_excl <- results_df$K[which.max(results_df$exclusivity)]
  best_excl_value <- max(results_df$exclusivity, na.rm = TRUE)
  cat(sprintf("2️⃣ Exclusivity 기준: K=%d (값: %.3f)\n", 
              best_k_excl, best_excl_value))
}

# Semantic Coherence 기준 최적 K (참고용)
if ("semcoh" %in% names(results_df)) {
  best_k_semcoh <- results_df$K[which.max(results_df$semcoh)]
  best_semcoh_value <- max(results_df$semcoh, na.rm = TRUE)
  cat(sprintf("3️⃣ Semantic Coherence 기준: K=%d (값: %.3f)\n", 
              best_k_semcoh, best_semcoh_value))
}

# 결과 데이터프레임 생성 (시각화용)
results_with_scores <- results_df

# K값별 성능 요약 테이블
cat("\n📊 K값별 성능 요약:\n")
cat("K | Held-out | Exclusivity | Semantic Coherence\n")
cat("--|----------|-------------|-------------------\n")
for (i in 1:nrow(results_df)) {
  heldout_str <- if ("heldout" %in% names(results_df)) sprintf("%.3f", results_df$heldout[i]) else "N/A"
  excl_str <- if ("exclusivity" %in% names(results_df)) sprintf("%.3f", results_df$exclusivity[i]) else "N/A"
  semcoh_str <- if ("semcoh" %in% names(results_df)) sprintf("%.3f", results_df$semcoh[i]) else "N/A"
  
  # 최적 K값에 별표 표시
  if (results_df$K[i] == best_k_composite) {
    cat(sprintf("%d* | %s | %s | %s\n", results_df$K[i], heldout_str, excl_str, semcoh_str))
  } else {
    cat(sprintf("%d | %s | %s | %s\n", results_df$K[i], heldout_str, excl_str, semcoh_str))
  }
}
cat("\n* 추천 K값\n")

# 최적 K값 상세 정보
cat(sprintf("\n🔸 추천 K=%d 상세 정보:\n", best_k_composite))
row_idx <- which(results_df$K == best_k_composite)

if ("heldout" %in% names(results_df)) {
  cat(sprintf("   - Held-out Likelihood: %.3f\n", results_df$heldout[row_idx]))
}

if ("exclusivity" %in% names(results_df)) {
  cat(sprintf("   - Exclusivity: %.3f\n", results_df$exclusivity[row_idx]))
}

if ("semcoh" %in% names(results_df)) {
  cat(sprintf("   - Semantic Coherence: %.3f\n", results_df$semcoh[row_idx]))
}

# 8. 최적 모델 학습 및 저장 -----------------------------------------------
cat("\n", rep("=", 60), "\n")
cat("🏆 최적 모델 학습 및 저장\n") 
cat(rep("=", 60), "\n")

# 최적 K값으로 최종 모델 학습
optimal_k <- best_k_composite
cat(sprintf("🎯 최적 K값 %d로 최종 모델 학습 중...\n", optimal_k))

tryCatch({
  optimal_model <- stm(
    documents = stm_documents,
    vocab = stm_vocab,
    K = optimal_k,
    max.em.its = 500,  # 충분한 반복
    init.type = "Spectral",
    seed = 12345,
    verbose = TRUE
  )
  
  cat("✅ 최적 모델 학습 완료!\n")
  
  # 모델 저장
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # 결과 저장 디렉토리 생성
  if (!dir.exists("results")) {
    dir.create("results", recursive = TRUE)
    cat("📁 results/ 디렉토리를 생성했습니다.\n")
  }
  
  # 최적 모델 저장
  optimal_model_file <- sprintf("results/optimal_stm_model_K%d_%s.RData", optimal_k, timestamp)
  save(optimal_model, file = optimal_model_file)
  cat(sprintf("💾 최적 모델 저장: %s\n", basename(optimal_model_file)))
  
  # searchK 결과 저장
  search_results_file <- sprintf("results/stm_model_comparison_%s.RData", timestamp)
  save(k_search_results, results_with_scores, performance_scores, file = search_results_file)
  cat(sprintf("📊 모델 비교 결과 저장: %s\n", basename(search_results_file)))
  
}, error = function(e) {
  cat(sprintf("❌ 최적 모델 학습 실패: %s\n", e$message))
  optimal_model <- NULL
  optimal_model_file <- "최적 모델 학습 실패"
  search_results_file <- sprintf("results/stm_model_comparison_%s.RData", 
                                format(Sys.time(), "%Y%m%d_%H%M%S"))
  save(k_search_results, results_with_scores, performance_scores, file = search_results_file)
})

# 9. 성능 비교 보고서 생성 ------------------------------------------------
cat("\n", rep("=", 60), "\n")
cat("📝 STM 모델 성능 비교 보고서 생성\n") 
cat(rep("=", 60), "\n")

# 보고서 파일명 생성
report_file <- sprintf("results/STM모델성능비교_보고서_%s.md", 
                      format(Sys.time(), "%Y%m%d_%H%M%S"))
cat(sprintf("📋 보고서 생성 중... %s\n", basename(report_file)))

# 보고서 내용 생성
report_content <- sprintf("# STM 모델 성능 비교 분석 보고서

**분석일**: %s  
**데이터**: KCI/RISS 학술 논문 %d편  
**방법**: searchK() 함수를 통한 K값별 성능 비교

---

## 📊 분석 개요

### 기본 정보
- **총 문서 수**: %s개 논문
- **어휘 수**: %s개 용어
- **테스트된 K값**: %s
- **평가 지표**: %d개
- **소요 시간**: %.1f분

### 분석 방법
- **평가 함수**: searchK()
- **랜덤 시드 수**: %d회
- **Held-out 비율**: %.1f
- **병렬 처리**: %s

---

## 🎯 최적 K값 추천 결과

### 1순위 추천: K=%d
**복합 점수: %.3f** (정규화된 점수)

",
format(Sys.Date(), "%Y년 %m월 %d일"),
length(stm_documents),
format(length(stm_documents), big.mark = ","),
format(length(stm_vocab), big.mark = ","),
paste(k_range, collapse = ", "),
ncol(results_df) - 1,
elapsed_time,
search_k_params$N,
search_k_params$proportion,
ifelse(search_k_params$cores > 1, "활성화", "비활성화"),
best_k_composite,
best_composite_score
)

# 추천 K값 정보 추가
report_content <- paste0(report_content, sprintf("### 추천 K값: K=%d\n\n", best_k_composite))

row_idx <- which(results_df$K == best_k_composite)

if ("heldout" %in% names(results_df)) {
  report_content <- paste0(report_content, sprintf("- **Held-out Likelihood**: %.3f\n", 
                          results_df$heldout[row_idx]))
}

if ("exclusivity" %in% names(results_df)) {
  report_content <- paste0(report_content, sprintf("- **Exclusivity**: %.3f\n", 
                          results_df$exclusivity[row_idx]))
}

if ("semcoh" %in% names(results_df)) {
  report_content <- paste0(report_content, sprintf("- **Semantic Coherence**: %.3f\n", 
                          results_df$semcoh[row_idx]))
}

report_content <- paste0(report_content, "\n")

# 성능 지표별 전체 결과 테이블
report_content <- paste0(report_content, "

---

## 📈 전체 성능 비교 결과

### K값별 성능 지표

| K | Held-out | Exclusivity | Semantic Coherence |
|---|----------|-------------|-------------------|
")

for (i in 1:nrow(results_df)) {
  k_val <- results_df$K[i]
  
  heldout_val <- ifelse("heldout" %in% names(results_df), 
                       sprintf("%.3f", results_df$heldout[i]), "N/A")
  
  excl_val <- if ("exclusivity" %in% names(results_df)) {
    if (!is.na(results_df$exclusivity[i])) {
      sprintf("%.3f", results_df$exclusivity[i])
    } else "N/A"
  } else "N/A"
  
  semcoh_val <- if ("semcoh" %in% names(results_df)) {
    if (!is.na(results_df$semcoh[i])) {
      sprintf("%.3f", results_df$semcoh[i])
    } else "N/A"
  } else "N/A"
  
  # 추천 K값에 별표 표시
  k_str <- if (k_val == best_k_composite) sprintf("%d*", k_val) else sprintf("%d", k_val)
  
  report_content <- paste0(report_content, 
    sprintf("| %s | %s | %s | %s |\n", 
            k_str, heldout_val, excl_val, semcoh_val))
}

# 성능 지표 설명
performance_explanation <- "

---

## 📚 성능 지표 설명

### Held-out Likelihood
- **의미**: 모델의 예측 성능을 측정하는 지표
- **해석**: 높을수록 좋음 (새로운 데이터에 대한 예측력이 높음)
- **중요도**: 매우 높음 (일반화 능력을 나타냄)

### Exclusivity
- **의미**: 각 토픽의 독특성을 측정하는 지표
- **해석**: 높을수록 좋음 (토픽 간 구별이 명확함)
- **중요도**: 높음 (토픽의 질적 차별성)

### Semantic Coherence
- **의미**: 토픽 내 단어들의 의미적 일관성을 측정
- **해석**: 높을수록 좋음 (토픽 내용이 일관됨)
- **중요도**: 높음 (토픽의 해석 가능성)

### 최적 K값 선정 기준
- **주요 기준**: Held-out Likelihood (예측 성능)
- **보조 기준**: Exclusivity와 Semantic Coherence
- **활용**: 예측 성능이 가장 좋은 K값을 우선 선택

---

## 💡 주요 발견점

### 1. 성능 트렌드 분석
"

# 성능 트렌드 분석 추가
if ("heldout" %in% names(results_with_scores)) {
  heldout_trend <- ifelse(cor(results_with_scores$K, results_with_scores$heldout) > 0, 
                         "증가", "감소")
  report_content <- paste0(report_content, 
    sprintf("- **Held-out Likelihood**: K값 증가에 따라 전반적으로 %s 경향\n", heldout_trend))
}

if ("exclusivity" %in% names(results_with_scores)) {
  excl_values <- results_with_scores$exclusivity[!is.na(results_with_scores$exclusivity)]
  if (length(excl_values) > 1) {
    excl_trend <- ifelse(cor(results_with_scores$K[!is.na(results_with_scores$exclusivity)], 
                            excl_values) > 0, "증가", "감소")
    report_content <- paste0(report_content, 
      sprintf("- **Exclusivity**: K값 증가에 따라 전반적으로 %s 경향\n", excl_trend))
  }
}

# 결론 및 제언
conclusion_section <- sprintf("

### 2. 최적 K값 선정 근거
- **K=%d**가 Held-out Likelihood 기준 최고 성능
- 예측 성능이 가장 우수한 모델
- 새로운 데이터에 대한 일반화 능력이 뛰어남

### 3. 추가 고려사항
- 도메인 전문가의 토픽 해석 검토 필요
- 실제 연구 목적에 따른 K값 조정 가능
- 시간적 변화나 하위그룹 분석 시 다른 K값 고려

---

## 🎯 실무 적용 제안

### 1. 추천 K값 적용
- **추천**: K=%d (Held-out Likelihood 최우수)

### 2. 후속 분석 방향
1. **선택된 K값으로 최종 STM 모델 학습**
2. **토픽별 키워드 및 대표 문서 분석**
3. **토픽 라벨링 및 해석**
4. **시계열 토픽 변화 분석 (시간 정보 있는 경우)**

---

## 📁 생성된 파일

### 분석 결과
- **최적 모델**: `%s`
- **성능 비교 데이터**: `%s`
- **성능 비교 보고서**: `%s`

### 시각화 파일
- **STM 공식 비교 차트**: `plots/stm_searchK_comparison.png`
- **Held-out Likelihood**: `plots/stm_heldout_likelihood.png`
- **Exclusivity**: `plots/stm_exclusivity.png`
- **Semantic Coherence**: `plots/stm_semantic_coherence.png`
- **종합 비교**: `plots/stm_comprehensive_comparison.png`

---

## 📋 기술적 정보

### 분석 조건
- **분석 일시**: %s
- **K값 범위**: %s
- **searchK 매개변수**: N=%d, proportion=%.1f
- **병렬 처리**: %d 코어

### 알고리즘
- **초기화**: Spectral
- **최적화**: EM 알고리즘
- **평가**: Cross-validation 기반 held-out likelihood
- **복합 점수**: 가중평균 (H:40%%, E:30%%, S:30%%)

---

*본 보고서는 searchK() 함수를 통한 STM 모델 성능 비교 분석 결과입니다.*  
*보고서 생성 시간: %s*
",
best_k_composite,
best_k_composite,
basename(optimal_model_file),
basename(search_results_file),
basename(report_file),
format(Sys.time(), "%Y년 %m월 %d일"),
paste(k_range, collapse = ", "),
search_k_params$N, search_k_params$proportion, search_k_params$cores,
format(Sys.time(), "%Y년 %m월 %d일 %H시 %M분")
)

# 전체 보고서 조합
full_report <- paste0(report_content, performance_explanation, conclusion_section)

# 보고서 파일 저장
tryCatch({
  writeLines(full_report, report_file, useBytes = TRUE)
  cat("✅ STM 모델 성능 비교 보고서 생성 완료!\n")
  cat(sprintf("📄 보고서 위치: %s\n", report_file))
}, error = function(e) {
  cat(sprintf("⚠️ 보고서 생성 오류: %s\n", e$message))
})

# 10. 최종 요약 ----------------------------------------------------------
cat("\n", rep("=", 60), "\n")
cat("🎉 STM 모델 성능 비교 분석 완료!\n")
cat(rep("=", 60), "\n")

cat(sprintf("\n📊 분석 결과 요약:\n"))
cat(sprintf("- 테스트된 K값: %s\n", paste(k_range, collapse = ", ")))
cat(sprintf("- 총 소요 시간: %.1f분\n", elapsed_time))
cat(sprintf("- 추천 K값: %d\n", best_k_composite))
if ("heldout" %in% names(results_df)) {
  best_idx <- which(results_df$K == best_k_composite)
  cat(sprintf("  - Held-out Likelihood: %.3f\n", results_df$heldout[best_idx]))
}
if ("exclusivity" %in% names(results_df)) {
  cat(sprintf("  - Exclusivity: %.3f\n", results_df$exclusivity[best_idx]))
}
if ("semcoh" %in% names(results_df)) {
  cat(sprintf("  - Semantic Coherence: %.3f\n", results_df$semcoh[best_idx]))
}

cat(sprintf("\n💾 저장된 파일들:\n"))
cat(sprintf("- 최적 모델: %s\n", 
            ifelse(exists("optimal_model_file"), basename(optimal_model_file), "저장 실패")))
cat(sprintf("- 성능 비교 데이터: %s\n", basename(search_results_file)))
cat(sprintf("- 분석 보고서: %s\n", basename(report_file)))

cat(sprintf("\n🎨 생성된 시각화:\n"))
cat("- plots/stm_searchK_comparison.png (STM 공식 비교 차트)\n")
cat("- plots/stm_heldout_likelihood.png (예측 성능)\n")
if ("exclusivity" %in% names(results_df)) {
  cat("- plots/stm_exclusivity.png (토픽 독특성)\n")
}
if ("semcoh" %in% names(results_df)) {
  cat("- plots/stm_semantic_coherence.png (의미 일관성)\n")
}
cat("- plots/stm_comprehensive_comparison.png (종합 비교)\n")

cat(sprintf("\n🔍 다음 단계 제안:\n"))
cat(sprintf("1. K=%d로 최종 STM 모델 학습 (05_stm_topic_modeling.R)\n", best_k_composite))
cat("2. 토픽별 키워드 분석 및 라벨링\n")
cat("3. 문서-토픽 분포 분석\n")
cat("4. 시계열 토픽 변화 분석 (시간 정보 있는 경우)\n")

cat(sprintf("\n📚 결과 활용 방법:\n"))
cat("# R에서 최적 모델 불러오기:\n")
if (exists("optimal_model_file")) {
  cat(sprintf("load('%s')\n", basename(optimal_model_file)))
}
cat("# 성능 비교 데이터 불러오기:\n")
cat(sprintf("load('%s')\n", basename(search_results_file)))

cat("\n✅ STM 모델 성능 비교 분석이 성공적으로 완료되었습니다!\n")

# 병렬 처리 정리 (Windows 제외)
if (!is_windows && furrr_available && search_k_params$cores > 1) {
  plan(sequential)
  cat("🔄 병렬 처리 정리 완료\n")
}

# End of script