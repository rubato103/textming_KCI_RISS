# 한국어 형태소 분석 프로젝트 - 데이터 입출력 체계성 분석 보고서

## 📊 데이터 흐름 분석

### 1. 전체 워크플로우
```
원본 데이터(Excel) 
    ↓ [01_data_loading_and_analysis.R]
병합 데이터(dl_combined_data_*.rds/csv)
    ↓ [02_kiwipiepy_morpheme_analysis.R]
형태소 분석 결과(mp_morpheme_results_*.rds, mp_noun_extraction_*.csv)
    ↓ [03-1_ngram_analysis.R]
N그램 분석 + 사전 후보(ng_compound_nouns_candidates_*.csv, ng_proper_nouns_candidates_*.csv)
    ↓ [03-3_create_user_dict.R]
사용자 사전(user_dict_*.txt)
    ↓ [04_dtm_creation_interactive.R]
DTM 결과(dtm_results_*.rds)
    ↓ [05_stm_topic_modeling.R]
토픽 모델링 결과(stm_results_*.rds)
```

### 2. 스크립트별 입출력 상세

#### 01_data_loading_and_analysis.R
- **입력**: `data/raw_data/*.xls, *.xlsx`
- **출력**: 
  - `data/processed/dl_combined_data_[timestamp].rds`
  - `data/processed/dl_combined_data_[timestamp].csv`
  - `data/processed/dl_data_structure_info_[timestamp].rds`
  - `reports/dl_data_structure_summary_[timestamp].md`
- **주요 데이터**: combined_data (원본 메타데이터 + source_file 컬럼 추가)

#### 02_kiwipiepy_morpheme_analysis.R
- **입력**: `data/processed/dl_combined_data_*.rds` (최신 파일 자동 선택)
- **선택적 입력**: `data/dictionaries/user_dict_*.txt` (사용자 사전)
- **출력**:
  - `data/processed/mp_morpheme_results_[timestamp]_[tag].rds` (구조화된 결과)
  - `data/processed/mp_morpheme_results_enhanced_xsn_[timestamp]_[tag].rds` (상세 결과)
  - `data/processed/mp_morpheme_analysis_[timestamp]_[tag].csv`
  - `data/processed/mp_noun_extraction_[timestamp]_[tag].csv`
  - `reports/mp_analysis_report_[timestamp]_[tag].md`
- **주요 데이터**: 
  - morpheme_analysis (doc_id, morpheme_analysis)
  - noun_extraction (doc_id, noun_extraction)

#### 03-1_ngram_analysis.R
- **입력**: `data/processed/mp_noun_extraction_*.csv` (대화형 선택)
- **출력**:
  - `data/dictionaries/dict_candidates/ng_compound_nouns_candidates_[timestamp].csv`
  - `data/dictionaries/dict_candidates/ng_proper_nouns_candidates_[timestamp].csv`
  - `plots/ng_*.png` (시각화)
  - `reports/ng_ngram_analysis_report_[timestamp].md`
- **주요 데이터**: N그램 빈도 분석 결과, 사전 후보 단어

#### 03-3_create_user_dict.R
- **입력**: 
  - `data/dictionaries/dict_candidates/ng_compound_nouns_candidates_*.csv`
  - `data/dictionaries/dict_candidates/ng_proper_nouns_candidates_*.csv`
- **출력**: `data/dictionaries/user_dict_[name]_[timestamp].txt`
- **주요 데이터**: Kiwipiepy 형식 사용자 사전 (단어\t품사\t점수)

#### 04_dtm_creation_interactive.R
- **입력**:
  - `data/processed/dl_combined_data_*.rds` (메타데이터)
  - `data/processed/mp_morpheme_results_*.rds` (형태소 분석 결과)
- **출력**:
  - `data/processed/dtm_results_[timestamp]_[filtering].rds`
  - `reports/dtm_analysis_report_[timestamp]_[filtering].md`
- **주요 데이터**: quanteda DFM 객체 + 코퍼스 (메타데이터 포함)

#### 05_stm_topic_modeling.R
- **입력**: `data/processed/dtm_results_*.rds`
- **출력**:
  - `data/processed/stm_results_[timestamp]_k[토픽수].rds`
  - `plots/stm_*.png`
  - `reports/stm_topic_report_[timestamp]_k[토픽수].md`
- **주요 데이터**: STM 모델 객체 + 토픽 분석 결과

## 🚨 데이터 체계성 문제점

### 1. 파일명 규칙 불일치
- **문제**: 각 스크립트마다 다른 접두사 사용 (dl_, mp_, ng_, dtm_, stm_)
- **영향**: 파일 검색 및 관리 복잡도 증가
- **예시**: 
  - 01번: `dl_combined_data_*`
  - 02번: `mp_morpheme_results_*`

### 2. 하드코딩된 파일 경로
- **문제**: 일부 스크립트에 절대 경로가 하드코딩됨
- **위치**:
  - 03-3_create_user_dict.R (34-35행): 특정 경로 하드코딩
  - 04_dtm_creation_interactive.R (43행, 52행): 특정 파일 하드코딩
- **영향**: 다른 환경에서 실행 불가능

### 3. 데이터 구조 불일치
- **문제**: doc_id 컬럼명이 스크립트마다 다름
- **예시**:
  - 원본 데이터: `논문 ID`
  - 형태소 분석: `doc_id`
  - DTM 생성 시 rename 필요 (47행)
- **영향**: 데이터 조인 시 오류 가능성

### 4. 타임스탬프 형식 불일치
- **문제**: 모든 스크립트가 동일한 형식 사용하나 정렬 시 혼란
- **형식**: `%Y%m%d_%H%M%S`
- **영향**: 파일 버전 관리의 일관성은 유지되나 가독성 부족

### 5. 메타데이터 손실 위험
- **문제**: 파이프라인 진행 시 메타데이터가 점진적으로 손실
- **예시**: 
  - 02번 스크립트: noun_extraction만 저장, 메타데이터 미포함
  - 04번에서 다시 조인 필요
- **영향**: 중간 단계에서 메타데이터 활용 불가

### 6. 대화형 입력 의존성
- **문제**: 모든 스크립트가 대화형 입력 요구
- **영향**: 자동화 및 배치 처리 불가능
- **위치**: 02, 03-1, 03-3, 04, 05 스크립트 모두

## ✅ 개선 방안

### 1. 통합 설정 파일 도입
```r
# config.R
PROJECT_CONFIG <- list(
  data_path = "data/processed",
  raw_path = "data/raw_data",
  dict_path = "data/dictionaries",
  report_path = "reports",
  plot_path = "plots",
  
  # 파일명 패턴
  patterns = list(
    combined_data = "combined_data_*.rds",
    morpheme_results = "morpheme_results_*.rds",
    noun_extraction = "noun_extraction_*.csv",
    dtm_results = "dtm_results_*.rds",
    stm_results = "stm_results_*.rds"
  ),
  
  # 기본 설정
  defaults = list(
    use_latest = TRUE,
    interactive = FALSE,
    encoding = "UTF-8"
  )
)
```

### 2. 표준화된 데이터 구조
```r
# 모든 스크립트에서 사용할 표준 구조
STANDARD_COLUMNS <- list(
  id = "doc_id",  # 통일된 ID 컬럼명
  text = "abstract",
  year = "pub_year",
  metadata_prefix = "meta_"
)

# 데이터 표준화 함수
standardize_data <- function(data) {
  # ID 컬럼 통일
  id_patterns <- c("논문 ID", "ID", "id", "doc_id")
  for (pattern in id_patterns) {
    if (pattern %in% names(data)) {
      names(data)[names(data) == pattern] <- STANDARD_COLUMNS$id
      break
    }
  }
  return(data)
}
```

### 3. 파일 관리 유틸리티
```r
# utils.R
get_latest_file <- function(pattern, path = "data/processed") {
  files <- list.files(path, pattern = pattern, full.names = TRUE)
  if (length(files) == 0) return(NULL)
  files[order(file.mtime(files), decreasing = TRUE)][1]
}

save_with_metadata <- function(data, prefix, metadata = NULL) {
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  result <- list(
    data = data,
    metadata = metadata,
    timestamp = timestamp,
    version = "1.0"
  )
  
  filename <- sprintf("%s/%s_%s.rds", 
                     PROJECT_CONFIG$data_path, prefix, timestamp)
  saveRDS(result, filename)
  return(filename)
}
```

### 4. 비대화형 모드 지원
```r
# 각 스크립트 시작 부분에 추가
args <- commandArgs(trailingOnly = TRUE)
INTERACTIVE_MODE <- interactive() && length(args) == 0

if (!INTERACTIVE_MODE) {
  # 명령줄 인자 또는 설정 파일에서 옵션 읽기
  options <- parse_args(args)
} else {
  # 기존 대화형 로직
  options <- get_user_input()
}
```

### 5. 데이터 파이프라인 래퍼
```r
# run_pipeline.R
run_pipeline <- function(config_file = "config.yaml") {
  config <- yaml::read_yaml(config_file)
  
  # 1단계: 데이터 로딩
  source("01_data_loading_and_analysis.R")
  
  # 2단계: 형태소 분석
  Sys.setenv(USE_USER_DICT = config$use_dict)
  source("02_kiwipiepy_morpheme_analysis.R")
  
  # 3단계: N그램 분석 (선택적)
  if (config$run_ngram) {
    source("03-1_ngram_analysis.R")
  }
  
  # 4단계: DTM 생성
  source("04_dtm_creation_interactive.R")
  
  # 5단계: 토픽 모델링
  source("05_stm_topic_modeling.R")
  
  cat("✅ 전체 파이프라인 실행 완료\n")
}
```

### 6. 데이터 검증 함수
```r
# validate.R
validate_data_flow <- function() {
  checks <- list()
  
  # 각 단계별 출력 파일 존재 확인
  checks$step1 <- length(list.files("data/processed", 
                                    pattern = "combined_data_*.rds")) > 0
  checks$step2 <- length(list.files("data/processed", 
                                    pattern = "morpheme_results_*.rds")) > 0
  checks$step3 <- length(list.files("data/processed", 
                                    pattern = "dtm_results_*.rds")) > 0
  
  # 데이터 무결성 확인
  if (all(unlist(checks))) {
    latest_combined <- readRDS(get_latest_file("combined_data_*.rds"))
    latest_morpheme <- readRDS(get_latest_file("morpheme_results_*.rds"))
    
    # doc_id 일치 확인
    checks$id_match <- all(latest_morpheme$data$doc_id %in% 
                           latest_combined$data$doc_id)
  }
  
  return(checks)
}
```

## 📋 우선순위 개선 작업

1. **긴급 (즉시 수정 필요)**
   - 하드코딩된 파일 경로 제거
   - doc_id 컬럼명 통일

2. **중요 (다음 버전에서 수정)**
   - 통합 설정 파일 도입
   - 비대화형 모드 지원 추가

3. **권장 (점진적 개선)**
   - 파일명 규칙 통일
   - 데이터 검증 함수 추가
   - 파이프라인 자동화 스크립트 작성

## 🎯 결론

현재 시스템은 기능적으로 작동하나, 데이터 체계성과 자동화 측면에서 개선이 필요합니다. 특히 하드코딩된 경로와 불일치하는 컬럼명은 즉시 수정이 필요하며, 장기적으로는 통합 설정 시스템과 파이프라인 자동화를 구현하여 사용성과 유지보수성을 향상시켜야 합니다.