#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
02_morpheme_analysis.py
KiwiPiePy를 사용한 한국어 형태소 분석 스크립트
Python 변환: 2025-01-18

R 스크립트 02_kiwipiepy_mopheme_analysis.R의 Python 버전
"""

import os
import sys
import json
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple
import warnings
warnings.filterwarnings('ignore')

# 패키지 임포트
import pandas as pd
import numpy as np
from tqdm import tqdm
import multiprocessing as mp
from concurrent.futures import ProcessPoolExecutor, as_completed

# 프로젝트 루트 경로 설정
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.append(str(PROJECT_ROOT))

# KiwiPiePy 임포트
try:
    from kiwipiepy import Kiwi
    print("[OK] KiwiPiePy imported successfully")
except ImportError as e:
    print(f"[ERROR] KiwiPiePy import failed: {e}")
    print("Please install: uv add kiwipiepy")
    sys.exit(1)

# ========== 설정 클래스 ==========
class MorphemeConfig:
    """형태소 분석 설정 관리"""
    
    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.processed_data_path = self.project_root / "data" / "processed"
        self.reports_path = self.project_root / "reports"
        self.cong_model_dir = self.project_root / "cong-base"
        
        # 설정값들
        self.use_cong_model = False
        self.use_user_dict = False
        self.selected_dict = None
        
        # 성능 설정
        self.cpu_cores = mp.cpu_count()
        self.use_cores = min(max(1, self.cpu_cores - 1), 8)  # 최대 8코어
        self.batch_size = 50
        
        self._detect_cong_model()
    
    def _detect_cong_model(self):
        """CoNg 모델 감지"""
        self.cong_available = self.cong_model_dir.exists()
        if self.cong_available:
            print(f"[INFO] CoNg model found: {self.cong_model_dir}")
        
    def setup_analyzer(self) -> Kiwi:
        """Kiwi 분석기 설정"""
        try:
            if self.use_cong_model and self.cong_available:
                print("[INFO] Initializing with CoNg model...")
                analyzer = Kiwi(model_path=str(self.cong_model_dir), model_type='cong')
            else:
                print("[INFO] Initializing with default model...")
                analyzer = Kiwi()
            
            # 공백 허용 설정 (복합명사 인식용)
            analyzer.space_tolerance = 2
            
            # 사용자 사전 로드
            if self.use_user_dict and self.selected_dict:
                try:
                    added_count = analyzer.load_user_dictionary(str(self.selected_dict))
                    print(f"[OK] User dictionary loaded: {added_count} words added")
                except Exception as e:
                    print(f"[ERROR] Failed to load user dictionary: {e}")
            
            return analyzer
            
        except Exception as e:
            print(f"[ERROR] Failed to initialize Kiwi: {e}")
            # Fallback to basic model
            return Kiwi()
    
    def find_latest_data(self) -> Optional[Path]:
        """최신 combined_data 파일 찾기"""
        patterns = ["*combined_data*.parquet", "*combined_data*.csv"]
        
        for pattern in patterns:
            files = list(self.processed_data_path.glob(pattern))
            if files:
                # 수정 시간 기준 최신 파일
                latest_file = max(files, key=lambda f: f.stat().st_mtime)
                print(f"[OK] Latest data file: {latest_file.name}")
                return latest_file
        
        print("[ERROR] No combined_data file found")
        return None
    
    def generate_filename(self, prefix: str, name: str, extension: str) -> str:
        """타임스탬프가 포함된 파일명 생성"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 모델/사전 정보 태그 생성
        model_tag = "cong" if self.use_cong_model else "default"
        dict_tag = "userdict" if self.use_user_dict else "basic"
        
        return f"{timestamp}_{name}_kiwipiepy_{model_tag}_{dict_tag}.{extension}"


# ========== 형태소 분석 클래스 ==========
class EnhancedMorphemeAnalyzer:
    """개선된 접두사/접미사 처리 형태소 분석기"""
    
    def __init__(self, config: MorphemeConfig):
        self.config = config
        self.analyzer = config.setup_analyzer()
    
    def extract_nouns_enhanced(self, text: str) -> List[str]:
        """
        개선된 명사 추출: XPN + NNG/NNP + XSN 패턴 처리
        """
        if not text or pd.isna(text) or len(text.strip()) < 10:
            return []
        
        try:
            tokens = self.analyzer.tokenize(text.strip())
            all_nouns = []
            i = 0
            
            while i < len(tokens):
                token = tokens[i]
                
                # XPN + NNG/NNP + XSN 3-way 결합
                if (i <= len(tokens) - 3 and 
                    token.tag == "XPN" and 
                    tokens[i+1].tag in ["NNG", "NNP"] and 
                    tokens[i+2].tag == "XSN"):
                    
                    triple_form = token.form + tokens[i+1].form + tokens[i+2].form
                    all_nouns.append(triple_form)
                    i += 3
                    continue
                
                # XPN + NNG/NNP 2-way 결합
                if (i <= len(tokens) - 2 and 
                    token.tag == "XPN" and 
                    tokens[i+1].tag in ["NNG", "NNP"]):
                    
                    prefix_form = token.form + tokens[i+1].form
                    all_nouns.append(prefix_form)
                    i += 2
                    continue
                
                # NNG/NNP + XSN 2-way 결합
                if (i <= len(tokens) - 2 and 
                    token.tag in ["NNG", "NNP"] and 
                    tokens[i+1].tag == "XSN"):
                    
                    suffix_form = token.form + tokens[i+1].form
                    all_nouns.append(suffix_form)
                    i += 2
                    continue
                
                # 단독 명사, 접두사, 접미사
                if token.tag in ["NNG", "NNP", "XPN", "XSN"] and len(token.form) >= 1:
                    all_nouns.append(token.form)
                
                i += 1
            
            return list(set(all_nouns))  # 중복 제거
            
        except Exception as e:
            print(f"[WARNING] Noun extraction error: {e}")
            return []
    
    def analyze_morphemes(self, text: str) -> str:
        """형태소 분석 수행"""
        if not text or pd.isna(text) or len(text.strip()) < 10:
            return ""
        
        try:
            tokens = self.analyzer.tokenize(text.strip())
            morpheme_tags = []
            
            for token in tokens:
                morpheme_tags.append(f"{token.form}/{token.tag}")
            
            return " ".join(morpheme_tags)
            
        except Exception as e:
            print(f"[WARNING] Morpheme analysis error: {e}")
            return ""
    
    def process_single_document(self, doc_data: Tuple[str, str]) -> Dict[str, Any]:
        """단일 문서 처리"""
        doc_id, abstract = doc_data
        
        # 명사 추출
        nouns = self.extract_nouns_enhanced(abstract)
        noun_text = ", ".join(nouns) if nouns else ""
        
        # 형태소 분석
        morphemes = self.analyze_morphemes(abstract)
        
        return {
            'doc_id': doc_id,
            'nouns': noun_text,
            'morphemes': morphemes,
            'has_result': bool(noun_text or morphemes)
        }


# ========== 배치 처리 함수 ==========
def process_batch_worker(batch_data: List[Tuple[str, str]], config_dict: Dict) -> List[Dict]:
    """워커 프로세스에서 배치 처리"""
    # 각 워커에서 새로운 분석기 초기화
    temp_config = MorphemeConfig()
    temp_config.__dict__.update(config_dict)
    
    analyzer = EnhancedMorphemeAnalyzer(temp_config)
    
    results = []
    for doc_data in batch_data:
        result = analyzer.process_single_document(doc_data)
        if result['has_result']:
            results.append(result)
    
    return results


# ========== 메인 분석 클래스 ==========
class MorphemeAnalysisManager:
    """형태소 분석 관리자"""
    
    def __init__(self):
        self.config = MorphemeConfig()
        self.setup_interactive_config()
    
    def setup_interactive_config(self):
        """자동 설정 (비대화형)"""
        print("\n========== 형태소 분석 설정 ==========")
        
        # CoNg 모델 자동 설정
        if self.config.cong_available:
            self.config.use_cong_model = True
            print("[AUTO] CoNg 모델 사용")
        else:
            print("[AUTO] 기본 모델 사용")
        
        # 사용자 사전 자동 설정
        dict_files = list(self.config.project_root.glob("data/dictionaries/user_dict_*.txt"))
        if dict_files:
            self.config.use_user_dict = True
            # 최신 사전 파일 자동 선택
            self.config.selected_dict = max(dict_files, key=lambda f: f.stat().st_mtime)
            print(f"[AUTO] Dictionary selected: {self.config.selected_dict.name}")
        else:
            print("[AUTO] No user dictionary found")
        
        # 설정 요약
        print(f"\n========== 설정 요약 ==========")
        print(f"시스템: {self.config.cpu_cores} CPU cores")
        print(f"사용 코어: {self.config.use_cores} cores")
        print(f"모델: {'CoNg' if self.config.use_cong_model else '기본'}")
        print(f"사용자 사전: {'적용' if self.config.use_user_dict else '미적용'}")
        print(f"배치 크기: {self.config.batch_size}")
        print("\n[AUTO] 분석을 시작합니다...")
    
    def load_data(self) -> pd.DataFrame:
        """데이터 로드"""
        print("\n========== 데이터 로드 ==========")
        
        data_file = self.config.find_latest_data()
        if not data_file:
            raise FileNotFoundError("No data file found. Run 01_data_loading_and_analysis.py first.")
        
        # 파일 형식에 따라 로드
        if data_file.suffix == '.parquet':
            df = pd.read_parquet(data_file)
        elif data_file.suffix == '.csv':
            df = pd.read_csv(data_file)
        else:
            raise ValueError(f"Unsupported file format: {data_file.suffix}")
        
        print(f"Total rows: {len(df)}")
        
        # 필요한 컬럼 확인 및 선택
        id_cols = [col for col in df.columns if 'id' in col.lower() or '논문' in col]
        abstract_cols = [col for col in df.columns if '초록' in col or 'abstract' in col.lower()]
        
        if not id_cols:
            id_col = df.columns[0]
        else:
            id_col = id_cols[0]
        
        if not abstract_cols:
            # 텍스트 컬럼 중 가장 긴 것 선택
            text_cols = df.select_dtypes(include=['object']).columns
            text_cols = [col for col in text_cols if col != 'source_file']
            if text_cols:
                abstract_col = text_cols[0]
            else:
                raise ValueError("No text column found for analysis")
        else:
            abstract_col = abstract_cols[0]
        
        print(f"ID column: {id_col}")
        print(f"Abstract column: {abstract_col}")
        
        # 데이터 정리
        analysis_df = df[[id_col, abstract_col]].copy()
        analysis_df.columns = ['doc_id', 'abstract']
        analysis_df['doc_id'] = analysis_df['doc_id'].astype(str)
        analysis_df = analysis_df.dropna(subset=['abstract'])
        analysis_df = analysis_df[analysis_df['abstract'].str.len() > 10]
        
        print(f"Analysis ready: {len(analysis_df)} documents")
        return analysis_df
    
    def process_parallel(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.DataFrame]:
        """병렬 처리로 형태소 분석 실행"""
        print(f"\n========== 병렬 형태소 분석 시작 ==========")
        print(f"Documents: {len(df)}")
        print(f"Cores: {self.config.use_cores}")
        print(f"Batch size: {self.config.batch_size}")
        
        # 배치 생성
        doc_data = list(zip(df['doc_id'], df['abstract']))
        batches = [doc_data[i:i + self.config.batch_size] 
                  for i in range(0, len(doc_data), self.config.batch_size)]
        
        print(f"Total batches: {len(batches)}")
        
        # 설정을 딕셔너리로 변환 (직렬화 가능)
        config_dict = {
            'use_cong_model': self.config.use_cong_model,
            'use_user_dict': self.config.use_user_dict,
            'selected_dict': str(self.config.selected_dict) if self.config.selected_dict else None,
            'cong_available': self.config.cong_available
        }
        
        # 병렬 처리 실행
        all_results = []
        start_time = datetime.now()
        
        with ProcessPoolExecutor(max_workers=self.config.use_cores) as executor:
            # 진행률 표시를 위한 future 추가
            futures = {
                executor.submit(process_batch_worker, batch, config_dict): i 
                for i, batch in enumerate(batches)
            }
            
            with tqdm(total=len(batches), desc="Processing batches") as pbar:
                for future in as_completed(futures):
                    try:
                        batch_results = future.result()
                        all_results.extend(batch_results)
                    except Exception as e:
                        print(f"Batch processing error: {e}")
                    pbar.update(1)
        
        end_time = datetime.now()
        processing_time = (end_time - start_time).total_seconds()
        
        print(f"\n========== 처리 완료 ==========")
        print(f"Total results: {len(all_results)}")
        print(f"Processing time: {processing_time:.2f} seconds")
        print(f"Speed: {len(all_results)/processing_time:.1f} docs/sec")
        
        # 결과 데이터프레임 생성
        if all_results:
            morpheme_df = pd.DataFrame([
                {'doc_id': r['doc_id'], 'morpheme_analysis': r['morphemes']}
                for r in all_results if r['morphemes']
            ])
            
            noun_df = pd.DataFrame([
                {'doc_id': r['doc_id'], 'noun_extraction': r['nouns']}
                for r in all_results if r['nouns']
            ])
        else:
            morpheme_df = pd.DataFrame(columns=['doc_id', 'morpheme_analysis'])
            noun_df = pd.DataFrame(columns=['doc_id', 'noun_extraction'])
        
        return morpheme_df, noun_df
    
    def save_results(self, morpheme_df: pd.DataFrame, noun_df: pd.DataFrame, 
                    processing_time: float, total_docs: int):
        """결과 저장"""
        print("\n========== 결과 저장 ==========")
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 메타데이터 생성
        metadata = {
            'analysis_date': datetime.now().strftime("%Y-%m-%d"),
            'analyzer_type': 'Enhanced XPN+XSN Processing',
            'analyzer_version': 'v3.0_python',
            'model_type': 'CoNg' if self.config.use_cong_model else 'Default',
            'use_user_dict': self.config.use_user_dict,
            'total_documents': total_docs,
            'processed_documents': len(morpheme_df),
            'processing_time_seconds': processing_time,
            'processing_speed': len(morpheme_df) / processing_time if processing_time > 0 else 0,
            'success_rate': (len(morpheme_df) / total_docs * 100) if total_docs > 0 else 0
        }
        
        # 통합 결과 구조
        final_results = {
            'morpheme_analysis': morpheme_df.to_dict('records'),
            'noun_extraction': noun_df.to_dict('records'),
            'metadata': metadata
        }
        
        # 파일명 생성
        model_tag = "cong" if self.config.use_cong_model else "default"
        dict_tag = "userdict" if self.config.use_user_dict else "basic"
        
        # 결과 저장
        result_files = {}
        
        # JSON 저장
        json_file = self.config.processed_data_path / f"{timestamp}_morpheme_results_kiwipiepy_{model_tag}_{dict_tag}.json"
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(final_results, f, ensure_ascii=False, indent=2)
        result_files['json'] = json_file
        
        # CSV 저장
        if len(morpheme_df) > 0:
            morpheme_csv = self.config.processed_data_path / f"{timestamp}_morpheme_analysis_kiwipiepy_{model_tag}_{dict_tag}.csv"
            morpheme_df.to_csv(morpheme_csv, index=False, encoding='utf-8-sig')
            result_files['morpheme_csv'] = morpheme_csv
        
        if len(noun_df) > 0:
            noun_csv = self.config.processed_data_path / f"{timestamp}_noun_extraction_kiwipiepy_{model_tag}_{dict_tag}.csv"
            noun_df.to_csv(noun_csv, index=False, encoding='utf-8-sig')
            result_files['noun_csv'] = noun_csv
        
        # 보고서 생성
        report_file = self._generate_report(morpheme_df, noun_df, metadata, timestamp, model_tag, dict_tag)
        result_files['report'] = report_file
        
        print("생성된 파일:")
        for file_type, file_path in result_files.items():
            print(f"  {file_type}: {file_path.name}")
        
        return result_files
    
    def _generate_report(self, morpheme_df: pd.DataFrame, noun_df: pd.DataFrame, 
                        metadata: Dict, timestamp: str, model_tag: str, dict_tag: str) -> Path:
        """분석 보고서 생성"""
        
        report_lines = [
            "# 형태소 분석 결과 보고서",
            "",
            f"**분석일**: {metadata['analysis_date']}",
            f"**분석기**: {metadata['analyzer_type']}",
            f"**모델**: {metadata['model_type']}",
            f"**사용자 사전**: {'적용' if metadata['use_user_dict'] else '미적용'}",
            "",
            "## 분석 결과 요약",
            f"- 전체 문서: {metadata['total_documents']:,}개",
            f"- 처리 성공: {metadata['processed_documents']:,}개",
            f"- 성공률: {metadata['success_rate']:.1f}%",
            f"- 처리 시간: {metadata['processing_time_seconds']:.2f}초",
            f"- 처리 속도: {metadata['processing_speed']:.1f} 문서/초",
            "",
            "## 추출된 명사 분석"
        ]
        
        # 명사 빈도 분석
        if len(noun_df) > 0:
            all_nouns = []
            for noun_text in noun_df['noun_extraction']:
                if pd.notna(noun_text):
                    all_nouns.extend(noun_text.split(', '))
            
            if all_nouns:
                noun_counts = pd.Series(all_nouns).value_counts()
                
                report_lines.extend([
                    f"- 총 고유 명사: {len(noun_counts):,}개",
                    f"- 총 명사 출현: {len(all_nouns):,}회",
                    "",
                    "### 상위 20개 명사",
                    ""
                ])
                
                for i, (noun, count) in enumerate(noun_counts.head(20).items(), 1):
                    report_lines.append(f"{i}. **{noun}** ({count:,}회)")
        
        # 보고서 파일 저장
        report_file = self.config.reports_path / f"{timestamp}_morpheme_analysis_report_kiwipiepy_{model_tag}_{dict_tag}.md"
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(report_lines))
        
        return report_file


# ========== 메인 실행 함수 ==========
def main():
    """메인 실행 함수"""
    print("========== KiwiPiePy 형태소 분석 시작 ==========")
    
    try:
        # 분석 관리자 초기화
        manager = MorphemeAnalysisManager()
        
        # 데이터 로드
        df = manager.load_data()
        
        # 형태소 분석 실행
        start_time = datetime.now()
        morpheme_df, noun_df = manager.process_parallel(df)
        end_time = datetime.now()
        
        processing_time = (end_time - start_time).total_seconds()
        
        # 결과 저장
        result_files = manager.save_results(morpheme_df, noun_df, processing_time, len(df))
        
        print(f"\n[SUCCESS] 형태소 분석 완료!")
        print(f"[RESULT] 처리 결과: {len(morpheme_df):,}개 문서")
        print(f"[TIME] 처리 시간: {processing_time:.2f}초")
        
    except Exception as e:
        print(f"[ERROR] 분석 실패: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()