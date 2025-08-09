# CLAUDE.md - 한국어 형태소 분석 프로젝트 설정

## 프로젝트 개요

한국어 형태소 분석기를 활용한 텍스트 분석 프로젝트

## 환경 설정

- **OS**: Windows
- **IDE**: VS Code
- **언어**: R
- **R 버전**: 4.5.1
- **공유 폴더**: SynologyDrive (여러 PC에서 동기화)
- **작업 방식**: 다중 사용자/PC 환경 지원

## 다중 PC 환경 설정

### 환경별 경로 차이 해결

여러 PC에서 공유 폴더를 사용할 때 각 PC마다 다른 경로 구조를 가질 수 있습니다:
- PC1: `C:/Users/user1/SynologyDrive/lecture/mopheme_test`
- PC2: `D:/SynologyDrive/lecture/mopheme_test`
- PC3: `C:/Users/rubat/SynologyDrive/lecture/mopheme_test`

### 동적 경로 설정 방법

#### 1. 현재 디렉토리 기반 실행 (가장 범용적)
```bash
# 프로젝트 폴더로 이동 후 실행
cd [프로젝트 폴더 경로]
"C:/Program Files/R/R-4.5.1/bin/Rscript.exe" [스크립트파일명].R
```

#### 2. 환경 변수 활용
```bash
# Windows 환경 변수 설정 (각 PC에서 한 번만 설정)
# 시스템 속성 > 고급 > 환경 변수에서 설정
# PROJECT_PATH = C:/Users/[사용자명]/SynologyDrive/lecture/mopheme_test
# R_PATH = C:/Program Files/R/R-4.5.1/bin

# 실행 명령
cd "$PROJECT_PATH" && "$R_PATH/Rscript.exe" [스크립트파일명].R
```

#### 3. 상대 경로 활용 (프로젝트 내부에서)
```bash
# 현재 위치에서 실행
"C:/Program Files/R/R-4.5.1/bin/Rscript.exe" ./[스크립트파일명].R
```

### 실행 예시 (PC별 차이 극복)

```bash
# 방법 1: 현재 디렉토리에서 실행 (모든 PC 공통)
pwd  # 현재 위치 확인
"C:/Program Files/R/R-4.5.1/bin/Rscript.exe" 01_data_loading_and_analysis.R

# 방법 2: 프로젝트 폴더 찾아서 이동
find /c/Users -name "mopheme_test" -type d 2>/dev/null | head -1 | xargs -I {} cd {}
"C:/Program Files/R/R-4.5.1/bin/Rscript.exe" 01_data_loading_and_analysis.R

# 방법 3: R 스크립트 내에서 작업 디렉토리 설정
"C:/Program Files/R/R-4.5.1/bin/Rscript.exe" -e "setwd(getwd()); source('01_data_loading_and_analysis.R')"
```

### R 스크립트 내 경로 설정 (권장)

R 스크립트 시작 부분에 다음 코드 추가:

```r
# 작업 디렉토리 자동 설정
if (!endsWith(getwd(), "mopheme_test")) {
  # 스크립트 파일 위치 기준으로 작업 디렉토리 설정
  script_path <- commandArgs(trailingOnly = FALSE)
  script_dir <- dirname(sub("--file=", "", script_path[grep("--file", script_path)]))
  if (length(script_dir) > 0 && script_dir != "") {
    setwd(script_dir)
  }
}

# 작업 디렉토리 확인
cat("작업 디렉토리:", getwd(), "\n")
```

## Windows 파일 관리 명령어

### ✅ 파일 삭제 방법 (작동 확인됨)
```bash
# 방법 1: 기본 rm 명령어 (권장)
rm "[파일경로]"

# 방법 2: 안전한 삭제 (파일 존재 여부 확인)
[ -f "[파일경로]" ] && rm "[파일경로]" && echo "파일 삭제 완료" || echo "파일이 존재하지 않습니다"

# 방법 3: unlink 명령어
unlink "[파일경로]"
```

### ❌ 문제 있는 방법 (사용 금지)
```bash
# del 명령어는 bash에서 인식되지 않음
del "[파일경로]"

# cmd /c del 방법도 Windows에서 문제 발생
cmd /c "del \"[파일경로]\""
```

### 파일 관리 예시 (상대 경로 사용)
```bash
# 현재 프로젝트 폴더에서 파일 삭제
rm ./old_script.R

# 여러 파일 삭제
rm ./file1.R ./file2.R

# 패턴 매칭으로 삭제 (주의: 신중하게 사용)
rm ./temp_*.R

# 하위 폴더 파일 삭제
rm ./data/temp/*.csv
```

## 프로젝트 구조

```
mopheme_test/
├── data/
│   ├── raw_data/        # 원본 데이터
│   └── processed/       # 처리된 데이터
├── ref/                 # 참고 자료
├── slide/              # 프레젠테이션 자료
└── scripts/            # R 스크립트 (필요시 생성)
```

## 주요 작업

1. 한국어 텍스트 형태소 분석
2. 토픽 모델링
3. 텍스트 전처리 및 정제
4. 분석 결과 시각화

## R 패키지 설정

```r
# CRAN 미러 설정 (한국)
options(repos = "https://cran.seoul.go.kr/")

# 주요 패키지
# - KoNLP: 한국어 자연어 처리
# - tidyverse: 데이터 처리
# - tidytext: 텍스트 마이닝
# - topicmodels: 토픽 모델링
```

## 코딩 규칙

- 한글 주석 사용 권장
- UTF-8 인코딩 사용
- 변수명: snake_case 사용
- 함수명: 동사로 시작 (예: process_text, analyze_morpheme)

## 데이터 처리 원칙

- 원본 데이터는 raw_data에 보존
- 모든 처리 결과는 processed에 저장
- 중간 결과물도 저장하여 재현가능성 확보

## 주의사항

### 다중 PC 환경
- **경로 독립성**: 절대 경로 대신 상대 경로 사용 권장
- **사용자명 차이**: 각 PC의 사용자명이 다를 수 있음을 고려
- **드라이브 차이**: C:/, D:/ 등 드라이브 문자가 다를 수 있음
- **동기화 지연**: SynologyDrive 동기화 완료 후 작업 시작

### 일반 주의사항
- Windows 경로에서 백슬래시(\\) 사용 시 이스케이프 처리
- 한글 파일명 사용 가능하나 영문 권장
- R 세션 시작 시 작업 디렉토리 확인 필수

## 협업 가이드라인

### 파일 충돌 방지
1. **작업 시작 전**: 최신 파일 동기화 확인
2. **작업 중**: 같은 파일 동시 편집 피하기
3. **작업 완료 후**: 즉시 동기화하여 다른 사용자와 공유

### 데이터 파일 관리
- **원본 데이터**: `data/raw_data/`에만 저장 (수정 금지)
- **처리 데이터**: `data/processed/`에 사용자명 또는 날짜 포함
  - 예: `processed_data_user1_20250108.rds`
  - 예: `analysis_results_20250108.csv`

### 스크립트 명명 규칙
- 번호 접두사 사용: `01_`, `02_` 등 (실행 순서 명시)
- 기능 설명 포함: `01_data_loading.R`, `02_preprocessing.R`
- 테스트 스크립트: `test_` 접두사 사용

## 코드 관리 지침

### 코드 통합/분할 시 원칙
- **코드 통합**: 여러 스크립트를 하나로 합칠 때, 원본 파일들은 삭제
- **코드 분할**: 하나의 스크립트를 여러 개로 나눌 때, 원본 파일은 삭제
- **주요 변경**: 대규모 리팩토링 시 원본을 `archive/` 폴더에 날짜와 함께 보관
  - 예: `archive/01_data_loading_20250108.R`
- **버전 관리**: Git을 사용하는 경우 커밋 후 삭제, 사용하지 않는 경우 archive 폴더 활용
