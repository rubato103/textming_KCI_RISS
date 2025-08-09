# 🚀 데모 가이드

한국어 형태소 분석 프로젝트를 빠르게 체험해보세요.

## 📋 사전 준비사항

### 1. R 환경 설정
```r
# 필수 패키지 설치
install.packages(c("readxl", "dplyr", "tidyr", "stringr", "parallel", 
                   "stm", "ggplot2", "wordcloud", "reticulate"))
```

### 2. Python 환경 설정
```bash
pip install kiwipiepy
```

### 3. 샘플 데이터 준비
- `data/raw_data/` 폴더에 KCI 또는 RISS Excel 파일 복사
- 파일이 없는 경우 샘플 데이터로 테스트 가능

## 🎯 데모 시나리오

### 시나리오 1: 전체 파이프라인 (권장)
```r
# 모든 단계를 자동으로 실행
source("00_run_pipeline.R")
```

**예상 소요시간**: 5-10분  
**결과**: 토픽 모델링까지 완료된 전체 분석 결과

### 시나리오 2: 단계별 실행
```r
# 1단계: 데이터 로딩
source("01_data_loading_and_analysis.R")

# 2단계: 형태소 분석
source("02_kiwipiepy_mopheme_analysis.R")

# 3단계: N그램 분석
source("03-1_ngram_analysis.R")
```

## 📊 기대 결과

### 데이터 로딩 결과
```
✅ Excel 파일 자동 감지 및 병합
✅ 데이터 표준화 (doc_id, abstract, pub_year)
✅ 메타데이터 보존 (시간, 카테고리 변수)
```

### 형태소 분석 결과
```
✅ 고성능 병렬 처리 (15개 코어)
✅ 명사 추출 완료 (XSN 처리 포함)
✅ 100% 성공률 달성
```

### N그램 분석 결과
```
✅ 2그램: "학습 부진", "연구 목적" 등
✅ 3그램: "학습 부진 학생" 등
✅ 복합명사 후보 CSV 생성
```

## 🔍 결과 확인 방법

### 생성된 파일들
```
data/processed/
├── dl_combined_data_*.rds        # 통합 데이터
├── mp_noun_extraction_*.csv      # 명사 추출 결과
└── ng_compound_nouns_*.csv       # 복합명사 후보

reports/
├── *_analysis_report_*.md        # 각 단계별 분석 보고서
└── ng_ngram_results_*.png        # N그램 시각화
```

### 주요 지표 확인
```r
# 최신 결과 파일 로드
data <- readRDS("data/processed/dl_combined_data_hash_id_최신날짜.rds")
cat("전체 문서 수:", nrow(data))

# 형태소 분석 결과 확인  
nouns <- read.csv("data/processed/mp_noun_extraction_최신날짜.csv")
cat("분석 완료 문서:", nrow(nouns))
```

## ⚠️ 문제 해결

### 1. "파일을 찾을 수 없습니다"
```bash
# 현재 디렉토리 확인
getwd()
# 작업 디렉토리 설정
setwd("프로젝트_폴더_경로")
```

### 2. Python 환경 오류
```r
library(reticulate)
py_config()  # Python 환경 확인
```

### 3. 메모리 부족
```r
# config.R에서 코어 수 조정
set_config("morpheme_analysis", "parallel_cores", 4)
```

## 🎉 성공 확인

다음 메시지들이 출력되면 성공입니다:

```
✅ 데이터 로딩 완료!
✅ 형태소 분석 완료! (100% 성공률)
✅ N그램 분석 완료!
🎉 전체 파이프라인 완료!
```

## 📞 도움말

- **GitHub Issues**: 기술적 문제 보고
- **CLAUDE.md**: 상세 설정 가이드
- **README.md**: 전체 프로젝트 개요