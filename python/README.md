# Python 변환 프로젝트

R 코드를 Python으로 변환하는 작업을 위한 디렉토리입니다.

## 디렉토리 구조

```
python/
├── src/             # 소스 코드
├── notebooks/       # Jupyter 노트북
├── tests/          # 테스트 코드
└── utils/          # 유틸리티 함수
```

## 파일 매핑

| R Script | Python Module | 상태 |
|----------|--------------|------|
| 01_data_loading_and_analysis.R | src/01_data_loading_and_analysis.py | 🔄 진행중 |
| 02_kiwipiepy_mopheme_analysis.R | src/02_morpheme_analysis.py | ⏳ 대기 |
| 03-1_ngram_analysis.R | src/03_ngram_analysis.py | ⏳ 대기 |
| 04_quanteda_dtm_creation.R | src/04_dtm_creation.py | ⏳ 대기 |
| 05_stm_topic_modeling.R | src/05_topic_modeling.py | ⏳ 대기 |

## 설치

```bash
pip install -r requirements.txt
```

## 사용법

```python
from src import data_loading
# 사용 예제
```