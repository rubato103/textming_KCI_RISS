#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
01_data_loading_and_analysis.py
데이터 불러오기, 병합 및 구조 분석 통합 스크립트
작성일: 2025-01-08
Python 변환: 2025-01-18
"""

import os
import sys
import glob
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

# ========== 패키지 임포트 ==========
import pandas as pd
import numpy as np

# 프로젝트 루트 경로 설정
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.append(str(PROJECT_ROOT))

# ========== 환경 설정 ==========
class Config:
    """프로젝트 설정 관리 클래스"""
    
    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.raw_data_path = self.project_root / "data" / "raw_data"
        self.processed_data_path = self.project_root / "data" / "processed"
        self.reports_path = self.project_root / "reports"
        
        # 필요한 디렉토리 생성
        self._create_directories()
    
    def _create_directories(self):
        """필요한 디렉토리 생성"""
        for path in [self.processed_data_path, self.reports_path]:
            path.mkdir(parents=True, exist_ok=True)
            print(f"폴더 확인/생성: {path}")
    
    def generate_filename(self, prefix: str, name: str, extension: str) -> str:
        """타임스탬프가 포함된 파일명 생성"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"{timestamp}_{name}.{extension}"


# ========== 데이터 로딩 함수 ==========
class DataLoader:
    """Excel 데이터 로딩 및 병합 클래스"""
    
    def __init__(self, config: Config):
        self.config = config
        
    def find_excel_files(self) -> List[Path]:
        """raw_data 폴더의 모든 Excel 파일 찾기"""
        pattern1 = str(self.config.raw_data_path / "*.xls")
        pattern2 = str(self.config.raw_data_path / "*.xlsx")
        
        files = glob.glob(pattern1) + glob.glob(pattern2)
        file_paths = [Path(f) for f in files]
        
        print(f"발견된 파일 개수: {len(file_paths)}")
        print("파일 목록:")
        for f in file_paths:
            print(f" - {f.name}")
        
        return file_paths
    
    def load_excel_file(self, file_path: Path) -> pd.DataFrame:
        """Excel 파일 읽기"""
        print(f"\n파일 읽기: {file_path.name}")
        
        # Excel 파일의 모든 시트 이름 가져오기
        excel_file = pd.ExcelFile(file_path)
        sheet_names = excel_file.sheet_names
        print(f"시트 개수: {len(sheet_names)}")
        print(f"시트 이름: {', '.join(sheet_names)}")
        
        # 첫 번째 시트 읽기
        df = pd.read_excel(file_path, sheet_name=0)
        
        # 파일명을 데이터에 추가 (출처 추적용)
        df['source_file'] = file_path.name
        
        return df
    
    def load_and_combine(self) -> Optional[pd.DataFrame]:
        """모든 Excel 파일 로드 및 병합"""
        print("========== 데이터 불러오기 시작 ==========")
        
        file_list = self.find_excel_files()
        
        if not file_list:
            print("raw_data 폴더에 Excel 파일이 없습니다.")
            return None
        
        if len(file_list) == 1:
            # 단일 파일
            combined_data = self.load_excel_file(file_list[0])
        else:
            # 여러 파일 병합
            print("\n여러 파일 병합 중...")
            data_frames = [self.load_excel_file(f) for f in file_list]
            combined_data = pd.concat(data_frames, ignore_index=True)
        
        # 🐛 디버그 포인트: 데이터 로드 완료 후 확인
        print(f"DEBUG: 데이터 shape = {combined_data.shape}")  # 브레이크포인트 추천
        
        return combined_data


# ========== 데이터 분석 함수 ==========
class DataAnalyzer:
    """데이터 구조 분석 클래스"""
    
    def __init__(self, config: Config):
        self.config = config
    
    def standardize_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """데이터 표준화 (컬럼명 정리 등)"""
        # 컬럼명 정리: 공백 제거, 소문자 변환 등
        df.columns = df.columns.str.strip()
        return df
    
    def analyze_structure(self, df: pd.DataFrame) -> Dict[str, Any]:
        """데이터 구조 분석"""
        print("\n========== 데이터 구조 분석 ==========")
        
        # 기본 정보
        total_rows = len(df)
        total_cols = len(df.columns)
        column_names = df.columns.tolist()
        column_types = df.dtypes.to_dict()
        
        print(f"전체 행 수: {total_rows:,}")
        print(f"전체 열 수: {total_cols}")
        
        # 열 정보 상세 분석
        print("\n========== 열 정보 상세 ==========")
        
        column_info = pd.DataFrame({
            '번호': range(1, len(column_names) + 1),
            '열이름': column_names,
            '데이터타입': [str(dtype) for dtype in df.dtypes],
            '결측치수': df.isna().sum().values,
            '결측치비율': [f"{(cnt/total_rows*100):.2f}%" for cnt in df.isna().sum()],
            '고유값수': [df[col].nunique() for col in column_names]
        })
        
        print(column_info.to_string(index=False))
        
        # 텍스트 열 식별 (형태소 분석 대상)
        text_columns = [col for col in column_names 
                       if df[col].dtype == 'object' and col != 'source_file']
        
        print("\n텍스트 열 (형태소 분석 가능):")
        for col in text_columns:
            non_na_values = df[col].dropna()
            if len(non_na_values) > 0:
                sample_text = str(non_na_values.iloc[0])
                if len(sample_text) > 20:
                    sample_text = sample_text[:20] + "..."
                print(f" - {col}: '{sample_text}'")
        
        # 데이터 샘플
        print("\n========== 데이터 샘플 (처음 5행) ==========")
        print(df.iloc[:5, :min(5, len(df.columns))])
        
        # 분석 결과 반환
        return {
            'total_rows': total_rows,
            'total_cols': total_cols,
            'column_info': column_info,
            'text_columns': text_columns,
            'sample_data': df.head(10),
            'analysis_date': datetime.now().strftime("%Y-%m-%d")
        }
    
    def save_results(self, df: pd.DataFrame, analysis: Dict[str, Any]):
        """분석 결과 저장"""
        print("\n========== 데이터 저장 ==========")
        
        # 파일명 생성
        rds_filename = self.config.generate_filename("", "combined_data", "parquet")
        csv_filename = self.config.generate_filename("", "combined_data", "csv")
        info_filename = self.config.generate_filename("", "data_structure_info", "json")
        
        # 데이터 저장
        df.to_parquet(self.config.processed_data_path / rds_filename)
        df.to_csv(self.config.processed_data_path / csv_filename, 
                 index=False, encoding='utf-8-sig')
        
        # 분석 정보 저장 (JSON으로)
        import json
        
        # DataFrame을 JSON 직렬화 가능한 형태로 변환
        analysis_json = analysis.copy()
        analysis_json['column_info'] = analysis['column_info'].to_dict('records')
        analysis_json['sample_data'] = analysis['sample_data'].to_dict('records')
        
        with open(self.config.processed_data_path / info_filename, 'w', encoding='utf-8') as f:
            json.dump(analysis_json, f, ensure_ascii=False, indent=2)
        
        # Markdown 보고서 생성
        report_filename = self.config.generate_filename("", "data_structure_summary", "md")
        self._create_markdown_report(analysis, report_filename)
        
        print(f"\n완료! 다음 파일이 생성되었습니다:")
        print(f"- 데이터: {self.config.processed_data_path / rds_filename}")
        print(f"- CSV: {self.config.processed_data_path / csv_filename}")
        print(f"- 분석 정보: {self.config.processed_data_path / info_filename}")
        print(f"- 보고서: {self.config.reports_path / report_filename}")
        
        return {
            'data_file': str(self.config.processed_data_path / rds_filename),
            'csv_file': str(self.config.processed_data_path / csv_filename),
            'info_file': str(self.config.processed_data_path / info_filename),
            'report_file': str(self.config.reports_path / report_filename)
        }
    
    def _create_markdown_report(self, analysis: Dict[str, Any], filename: str):
        """Markdown 보고서 생성"""
        report_lines = [
            "# 데이터 구조 분석 보고서 (자동 생성)\n",
            f"**분석일**: {analysis['analysis_date']}",
            "**분석 스크립트**: 01_data_loading_and_analysis.py\n",
            "## 데이터 요약",
            f"- 전체 행 수: {analysis['total_rows']:,}",
            f"- 전체 열 수: {analysis['total_cols']}\n",
            "## 형태소 분석 가능 텍스트 열"
        ]
        
        for col in analysis['text_columns']:
            report_lines.append(f"- {col}")
        
        report_lines.extend([
            "\n## 열 정보 요약",
            "| 열 이름 | 데이터 타입 | 결측치 비율 | 고유값 수 |",
            "|---------|------------|------------|----------|"
        ])
        
        for _, row in analysis['column_info'].iterrows():
            if row['열이름'] != 'source_file':
                report_lines.append(
                    f"| {row['열이름']} | {row['데이터타입']} | "
                    f"{row['결측치비율']} | {row['고유값수']:,} |"
                )
        
        with open(self.config.reports_path / filename, 'w', encoding='utf-8') as f:
            f.write('\n'.join(report_lines))


# ========== 메인 실행 함수 ==========
def main():
    """메인 실행 함수"""
    # 설정 초기화
    config = Config()
    
    # 데이터 로더 초기화
    loader = DataLoader(config)
    
    # 데이터 로드 및 병합
    combined_data = loader.load_and_combine()
    
    if combined_data is None:
        return
    
    # 데이터 분석기 초기화
    analyzer = DataAnalyzer(config)
    
    # 데이터 표준화
    combined_data = analyzer.standardize_data(combined_data)
    
    # 데이터 구조 분석
    analysis_result = analyzer.analyze_structure(combined_data)
    
    # 결과 저장
    saved_files = analyzer.save_results(combined_data, analysis_result)
    
    return combined_data, analysis_result, saved_files


if __name__ == "__main__":
    # 스크립트 직접 실행 시
    combined_data, analysis_result, saved_files = main()