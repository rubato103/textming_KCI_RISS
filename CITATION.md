# 인용 가이드 (Citation Guide)

## 중요 공지

본 코드를 활용할 경우 반드시 아래와 같이 인용 표기 바랍니다.

## 인용 형식

### 학술 논문에서 사용시
```
Korean Morpheme Analysis Pipeline for KCI/RISS Data. (2025). 
GitHub Repository. https://github.com/rubato103/textming_KCI_RISS
```

### APA 형식
```
Yang, Yeondong. (2025). Text Mining Korean Academic Data using R [Computer software]. 
GitHub. https://github.com/rubato103/textming_KCI_RISS
```

### BibTeX 형식
```bibtex
@software{korean_morpheme_2025,
  author = {Yang, Yeondong},
  title = {Korean Morpheme Analysis Pipeline for KCI/RISS Data},
  url = {https://github.com/rubato103/textming_KCI_RISS},
  version = {1.0.0},
  year = {2025}
}
```

### 한국어 논문에서 사용시
```
양연동. (2025). R을 이용한 한국어 학술데이터 텍스트마이닝. 
GitHub 저장소. https://github.com/rubato103/textming_KCI_RISS
```

## 인용 필수 상황

다음과 같은 경우 인용 표기가 필수적입니다:

### 인용 필수 사례
- **학술 연구**: 논문, 학회 발표, 학위 논문 등
- **교육 자료**: 강의, 교재, 워크샵 등  
- **상업적 활용**: 컨설팅, 분석 서비스 등
- **블로그/웹사이트**: 기술 블로그, 튜토리얼 등
- **소프트웨어 개발**: 다른 프로젝트에 코드 포함시

### 인용시 포함 요소
1. **저자**: 양연동 (Yang, Yeondong)
2. **제목**: R을 이용한 한국어 학술데이터 텍스트마이닝
3. **URL**: https://github.com/rubato103/textming_KCI_RISS
4. **연도**: 2025

## 라이선스 정보

- **라이선스**: Academic and Educational Use License
- **학술/교육 이용**: 허용 (인용 표기시)
- **상업적 이용**: 금지 (별도 라이선스 필요)
- **수정/배포**: 허용 (학술/교육 목적만)
- **보증**: 없음 (AS-IS 제공)

### 중요 안내
이 소프트웨어는 **학술 및 교육 목적으로만** 사용할 수 있습니다.

## 연락처

- 문의: rubato103@dodaseo.cc

## 의존성 라이브러리 인용

이 프로젝트는 다음 라이브러리들을 사용합니다. **해당 라이브러리들도 함께 인용해주세요.**

### Kiwi 형태소 분석기 (필수 인용)

**논문 인용 형식 (한국어)**:
```
이민철. (2024). Kiwi: 통계적 언어 모델과 Skip-Bigram을 이용한 한국어 형태소 분석기 구현. 
디지털인문학, 1(1), 109-136. https://doi.org/10.23287/KJDH.2024.1.1.6
```

**논문 인용 형식 (English)**:
```
Lee, M. (2024). Kiwi: Developing a Korean Morphological Analyzer Based on Statistical Language Models and Skip-Bigram. 
Korean Journal of Digital Humanities, 1(1), 109-136. https://doi.org/10.23287/KJDH.2024.1.1.6
```

### 기타 주요 라이브러리

- **STM**: Roberts, M. E., Stewart, B. M., & Tingley, D. (2019). stm: An R Package for Structural Topic Models. Journal of Statistical Software, 91(2), 1-40.
- **Kiwipiepy**: Python wrapper for Kiwi morphological analyzer

## 완전한 인용 예시

### 학술 논문에서 모든 도구를 인용하는 경우

**한국어 논문**:
```
본 연구의 텍스트 분석에는 양연동의 R을 이용한 한국어 학술데이터 텍스트마이닝 파이프라인
(https://github.com/rubato103/textming_KCI_RISS)을 활용하였으며, 
형태소 분석에는 Kiwi 분석기(이민철, 2024)를, 토픽 모델링에는 
STM 패키지(Roberts et al., 2019)를 사용하였다.
```

**English Paper**:
```
Text analysis was conducted using the Text Mining Korean Academic Data using R pipeline 
(https://github.com/rubato103/textming_KCI_RISS), with morphological analysis 
performed using the Kiwi analyzer (Lee, 2024) and topic modeling using 
the STM package (Roberts et al., 2019).
```

## 당부

본 코드가 연구 및 프로젝트에 기여하기를 바랍니다. 올바른 인용은 오픈소스 생태계 유지에 중요합니다. 특히 Kiwi 형태소 분석기 개발자의 학술적 기여를 인정하여 반드시 인용 바랍니다.
