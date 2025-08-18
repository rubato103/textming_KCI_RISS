#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
02_morpheme_analysis.py
KiwiPiePy 한국어 형태소 분석 스크립트 (R 스크립트 완전 복제)
Python 변환: 2025-01-18

R 스크립트 02_kiwipiepy_mopheme_analysis.R의 모든 디테일 기능 구현
- CoNg 모델 자동 다운로드 및 설치
- 사용자 사전 관리
- XPN+NNG/NNP+XSN 3-way 형태소 패턴 처리
- 동적 배치 크기 계산 및 병렬 처리
- Combined_data 파일 선택 기능

사용법:
1. 대화형 모드 (기본): 각 단계에서 사용자가 선택
   python/src/02_morpheme_analysis.py
   
2. 자동 모드: 최적 설정으로 무인 실행 (배치 작업용)
   파일 하단의 main(interactive=True)를 main(interactive=False)로 변경

특징:
- 여러 combined_data 파일이 있으면 선택 가능
- CoNg 모델이 없으면 자동 다운로드 시도
- 시스템 리소스에 따른 최적 병렬 처리
- 상세한 XPN/XSN 패턴 분석 보고서 생성
"""

import os
import sys
import json
import requests
import tarfile
import shutil
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
import time

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

# ========== 고급 설정 클래스 ==========
class EnhancedMorphemeConfig:
    """향상된 형태소 분석 설정 관리 (R 스크립트 완전 복제)"""
    
    def __init__(self):
        self.project_root = PROJECT_ROOT
        self.processed_data_path = self.project_root / "data" / "processed"
        self.reports_path = self.project_root / "reports"
        self.cong_model_dir = self.project_root / "cong-base"
        self.dictionaries_path = self.project_root / "data" / "dictionaries"
        
        # CoNg 모델 다운로드 정보
        self.cong_model_url = "https://github.com/bab2min/Kiwi/releases/download/v0.21.0/kiwi_model_v0.21.0_cong_base.tgz"
        self.cong_model_file = "kiwi_model_v0.21.0_cong_base.tgz"
        self.cong_model_size = "58.7MB"
        
        # 설정값들
        self.use_cong_model = False
        self.use_user_dict = False
        self.selected_dict = None
        self.dict_tag = "default"
        
        # 시스템 리소스 감지
        self._detect_system_resources()
        self._detect_cong_model()
        self._detect_user_dictionaries()
    
    def _detect_system_resources(self):
        """시스템 리소스 자동 감지 (R 스크립트와 동일한 로직)"""
        self.cpu_cores = mp.cpu_count()
        print(f"[INFO] 감지된 CPU 코어 수: {self.cpu_cores}개")
        
        # CPU 코어 수만으로 시스템 사양 판단 (R 스크립트와 동일)
        if self.cpu_cores >= 12:
            self.available_memory_gb = 32  # 고사양 시스템
            self.system_tier = "고사양"
        elif self.cpu_cores >= 8:
            self.available_memory_gb = 16  # 중사양 시스템
            self.system_tier = "중사양"
        else:
            self.available_memory_gb = 8   # 저사양 시스템
            self.system_tier = "저사양"
        
        print(f"[INFO] 시스템 등급: {self.system_tier} ({self.cpu_cores} 코어 → {self.available_memory_gb} GB 추정)")
        
        # 최적 코어 수 계산 (R 스크립트와 동일한 로직)
        if self.system_tier == "고사양":
            self.use_cores = max(1, self.cpu_cores - 1)  # 1개만 시스템용으로 예약
        elif self.system_tier == "중사양":
            self.use_cores = min(8, max(1, self.cpu_cores - 1))  # 최대 8코어 제한
        else:
            self.use_cores = min(6, max(1, round(self.cpu_cores * 0.75)))  # 최대 6코어 제한
        
        # 안전 범위로 제한
        self.use_cores = max(1, min(self.use_cores, self.cpu_cores - 1))
        
        print(f"[INFO] 사용 코어: {self.use_cores}개 (전체 {self.cpu_cores}개 중)")
    
    def _calculate_optimal_batch_size(self, total_docs: int) -> int:
        """동적 배치 크기 계산 (R 스크립트와 동일한 로직)"""
        # 목표: 코어 수와 배치 수를 정확히 일치시켜 모든 코어 활용
        target_batches = self.use_cores
        
        # 이상적인 배치 크기: 문서 수를 코어 수로 나눈 값
        ideal_batch_size = max(1, total_docs // target_batches)
        
        # 최소 배치 크기를 매우 낮게 설정해서 코어 수 일치를 우선시
        min_batch_size = max(1, total_docs // (self.use_cores * 2))  # 코어당 최소 0.5개 문서
        
        # 최대 배치 크기는 전체 문서의 50%로 제한
        max_batch_size = max(ideal_batch_size, total_docs // 2)
        
        # 코어 수 일치를 위해 이상적인 배치 크기를 우선 적용
        optimal_batch_size = max(min_batch_size, min(ideal_batch_size, max_batch_size))
        
        return optimal_batch_size
    
    def _detect_cong_model(self):
        """CoNg 모델 감지"""
        self.cong_available = self.cong_model_dir.exists()
        if self.cong_available:
            print(f"[OK] CoNg 모델 발견: {self.cong_model_dir}")
            # 모델 파일들 확인
            model_files = list(self.cong_model_dir.glob("*"))
            if model_files:
                print("모델 디렉토리 내용:")
                for f in model_files[:5]:  # 처음 5개만 표시
                    print(f"  - {f.name}")
        else:
            print("[INFO] CoNg 모델을 찾을 수 없습니다.")
    
    def _detect_user_dictionaries(self):
        """사용자 사전 파일 감지"""
        self.dict_files = []
        if self.dictionaries_path.exists():
            self.dict_files = list(self.dictionaries_path.glob("user_dict_*.txt"))
            if self.dict_files:
                # 수정 시간 기준 정렬 (최신 순)
                self.dict_files.sort(key=lambda f: f.stat().st_mtime, reverse=True)
                print(f"[INFO] 사용 가능한 사전 파일: {len(self.dict_files)}개")
                for i, dict_file in enumerate(self.dict_files[:3], 1):  # 최신 3개만 표시
                    file_info = dict_file.stat()
                    size_kb = file_info.st_size / 1024
                    mtime = datetime.fromtimestamp(file_info.st_mtime)
                    print(f"  {i}. {dict_file.name} ({size_kb:.1f} KB, {mtime.strftime('%Y-%m-%d %H:%M')})")
            else:
                print("[INFO] 사용자 사전 파일이 없습니다.")
        else:
            print("[INFO] 사전 디렉토리가 없습니다.")
    
    def download_cong_model(self) -> bool:
        """CoNg 모델 자동 다운로드 및 설치 (R 스크립트와 동일)"""
        print(f"\n========== CoNg 모델 자동 설치 ==========")
        print(f"CoNg 모델을 다운로드합니다...")
        print(f"URL: {self.cong_model_url}")
        print(f"크기: 약 {self.cong_model_size}")
        print()
        
        try:
            # 다운로드
            print("다운로드 중...")
            response = requests.get(self.cong_model_url, stream=True)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0))
            with open(self.cong_model_file, 'wb') as f, tqdm(
                desc="Downloading",
                total=total_size,
                unit='B',
                unit_scale=True,
                unit_divisor=1024,
            ) as pbar:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        pbar.update(len(chunk))
            
            print("[OK] 다운로드 완료")
            
            # 압축 해제
            print("압축 해제 중...")
            with tarfile.open(self.cong_model_file, 'r:gz') as tar:
                tar.extractall('.')
            
            # 압축 파일 삭제
            os.remove(self.cong_model_file)
            print("[OK] CoNg 모델 설치 완료")
            
            # 모델 파일 확인
            if self.cong_model_dir.exists():
                print("모델 디렉토리 내용:")
                model_files = list(self.cong_model_dir.glob("*"))
                for f in model_files:
                    print(f"  - {f.name}")
                self.cong_available = True
                return True
            else:
                print("[ERROR] 모델 설치 확인 실패")
                return False
                
        except Exception as e:
            print(f"[ERROR] 다운로드 실패: {e}")
            print("\n수동 설치 방법:")
            print("1. 브라우저에서 다음 URL 접속:")
            print(f"   {self.cong_model_url}")
            print("2. 다운로드한 파일을 현재 디렉토리에 복사")
            print(f"3. 압축 해제: tar -zxvf {self.cong_model_file}")
            return False
    
    def setup_analyzer(self) -> Kiwi:
        """Kiwi 분석기 설정 (R 스크립트와 동일한 로직)"""
        try:
            if self.use_cong_model and self.cong_available:
                print("[INFO] CoNg 모델로 분석기 초기화 중...")
                analyzer = Kiwi(model_path=str(self.cong_model_dir), model_type='cong')
                print("[OK] CoNg 모델 분석기 초기화 성공")
            else:
                print("[INFO] 기본 모델로 분석기 초기화 중...")
                analyzer = Kiwi()
                print("[OK] 기본 모델 분석기 초기화 성공")
            
            # 복합명사 인식을 위한 공백 허용 설정
            analyzer.space_tolerance = 2
            print("[INFO] space_tolerance=2 설정 완료")
            
            # 사용자 사전 로드
            if self.use_user_dict and self.selected_dict:
                try:
                    added_count = analyzer.load_user_dictionary(str(self.selected_dict))
                    print(f"[OK] 사용자 사전 파일 로드 완료: {added_count}개 형태소 추가")
                    return analyzer
                except Exception as e:
                    print(f"[ERROR] 사용자 사전 로드 실패: {e}")
                    print("[INFO] 기본 분석기로 계속 진행")
            
            return analyzer
            
        except Exception as e:
            print(f"[ERROR] 분석기 초기화 실패: {e}")
            print("[INFO] 기본 모델로 fallback")
            analyzer = Kiwi()
            analyzer.space_tolerance = 2
            self.use_cong_model = False
            return analyzer
    
    def interactive_setup(self):
        """대화형 설정 (R 스크립트와 동일한 UI)"""
        print("\n========== 모델 선택 ==========")
        
        # CoNg 모델 설정
        if self.cong_available:
            print(f"[OK] CoNg 모델 발견: {self.cong_model_dir}")
            choice = input("CoNg 모델을 사용하시겠습니까?\n1. 예 - CoNg 모델 사용 (향상된 성능)\n2. 아니오 - 기본 모델 사용\n선택하세요 (1 또는 2): ")
            self.use_cong_model = (choice == "1")
        else:
            print("[INFO] CoNg 모델을 찾을 수 없습니다.")
            choice = input(f"CoNg 모델을 다운로드하시겠습니까?\n1. 예 - CoNg 모델 다운로드 및 사용 ({self.cong_model_size}, 향상된 성능)\n2. 아니오 - 기본 모델 사용\n선택하세요 (1 또는 2): ")
            
            if choice == "1":
                if self.download_cong_model():
                    self.use_cong_model = True
                else:
                    print("[INFO] 기본 모델을 사용합니다.")
                    self.use_cong_model = False
            else:
                print("[INFO] 기본 모델을 사용합니다.")
                self.use_cong_model = False
        
        # 사용자 사전 설정
        print("\n========== 사용자 사전 설정 ==========")
        
        if self.dict_files:
            choice = input("사용자 사전을 적용하시겠습니까?\n1. 예 - 사용자 사전 적용\n2. 아니오 - 기본 분석기 사용\n선택하세요 (1 또는 2): ")
            
            if choice == "1":
                self.use_user_dict = True
                
                if len(self.dict_files) == 1:
                    # 사전 파일이 하나만 있으면 자동 선택
                    self.selected_dict = self.dict_files[0]
                    print(f"[OK] 자동 선택된 사전 파일: {self.selected_dict.name}")
                else:
                    # 여러 개가 있으면 사용자가 선택
                    print("\n사용 가능한 사용자 사전 파일:")
                    for i, dict_file in enumerate(self.dict_files, 1):
                        file_info = dict_file.stat()
                        size_kb = file_info.st_size / 1024
                        mtime = datetime.fromtimestamp(file_info.st_mtime)
                        print(f"{i}. {dict_file.name} ({size_kb:.1f} KB, {mtime.strftime('%Y-%m-%d %H:%M')})")
                    
                    try:
                        dict_selection = int(input(f"사전을 선택하세요 (1-{len(self.dict_files)}): "))
                        if 1 <= dict_selection <= len(self.dict_files):
                            self.selected_dict = self.dict_files[dict_selection - 1]
                            print(f"[OK] 선택된 사전 파일: {self.selected_dict.name}")
                        else:
                            print("[WARNING] 잘못된 선택입니다. 최신 사전을 자동 선택합니다.")
                            self.selected_dict = self.dict_files[0]
                            print(f"[OK] 자동 선택된 사전 파일: {self.selected_dict.name}")
                    except ValueError:
                        print("[WARNING] 잘못된 입력입니다. 최신 사전을 자동 선택합니다.")
                        self.selected_dict = self.dict_files[0]
                        print(f"[OK] 자동 선택된 사전 파일: {self.selected_dict.name}")
                
                # 사전 파일명에서 태그 추출
                dict_filename = self.selected_dict.name
                # 예: 20250811_175903_user_dict_test1.txt → test1
                if "_user_dict_" in dict_filename:
                    self.dict_tag = dict_filename.split("_user_dict_")[1].replace(".txt", "")
                else:
                    self.dict_tag = "userdict"
            else:
                self.use_user_dict = False
                print("[INFO] 기본 분석기를 사용합니다.")
        else:
            print("[INFO] 사용 가능한 사전 파일이 없습니다. 기본 분석기를 사용합니다.")
            self.use_user_dict = False
        
        # 최종 설정 확인
        print(f"\n========== 분석 설정 확인 ==========")
        print(f"모델: {'CoNg 모델 (향상된 정확도/속도)' if self.use_cong_model else '기본 모델'}")
        if self.use_user_dict and self.selected_dict:
            print(f"사용자 사전 적용: {self.selected_dict.name}")
            dict_info = self.selected_dict.stat()
            print(f"   사전 크기: {dict_info.st_size/1024:.1f} KB")
            mtime = datetime.fromtimestamp(dict_info.st_mtime)
            print(f"   생성일시: {mtime.strftime('%Y-%m-%d %H:%M')}")
        else:
            print("분석기 설정: 기본 분석기 (사전 미적용)")
        
        # 결과 파일 접미사 생성
        model_suffix = "cong" if self.use_cong_model else "default"
        if self.use_user_dict:
            self.optional_tag = f"kiwipiepy_{model_suffix}_{self.dict_tag}"
        else:
            self.optional_tag = f"kiwipiepy_{model_suffix}_default"
        
        print(f"결과 파일 접미사: {self.optional_tag}")
        
        # 분석 시작 확인
        choice = input("\n분석을 시작하시겠습니까?\n1. 예 - 분석 시작\n2. 아니오 - 종료\n선택하세요 (1 또는 2): ")
        if choice == "2":
            print("[INFO] 사용자가 분석을 중단했습니다.")
            sys.exit(0)
        
        print("\n[OK] 분석을 시작합니다.")
        
        # 배치 크기 계산을 위해 임시로 데이터 크기 추정
        self.batch_size = 50  # 기본값
    
    def find_latest_data(self, interactive: bool = False) -> Optional[Path]:
        """combined_data 파일 찾기 및 선택 (중복 제거)"""
        patterns = ["*combined_data*.rds", "*combined_data*.parquet", "*combined_data*.csv"]
        
        all_files = []
        for pattern in patterns:
            files = list(self.processed_data_path.glob(pattern))
            all_files.extend(files)
        
        if not all_files:
            print("[ERROR] combined_data 파일을 찾을 수 없습니다. 01_data_loading_and_analysis.py를 먼저 실행해주세요.")
            return None
        
        # 타임스탬프별로 그룹화하여 중복 제거 (같은 데이터의 다른 형식 제거)
        file_groups = {}
        for file_path in all_files:
            # 파일명에서 타임스탬프 추출 (예: 20250818_145520)
            name_parts = file_path.name.split('_')
            if len(name_parts) >= 2:
                timestamp = f"{name_parts[0]}_{name_parts[1]}"
            else:
                timestamp = file_path.stem
            
            if timestamp not in file_groups:
                file_groups[timestamp] = []
            file_groups[timestamp].append(file_path)
        
        # 각 그룹에서 최적 파일 선택 (우선순위: parquet > csv > rds)
        unique_files = []
        for timestamp, files in file_groups.items():
            # 형식별 우선순위로 정렬
            def format_priority(file_path):
                if file_path.suffix == '.parquet':
                    return 1  # 최우선 (압축률 좋음, 빠름)
                elif file_path.suffix == '.csv':
                    return 2  # 2순위 (호환성 좋음)
                elif file_path.suffix == '.rds':
                    return 3  # 3순위 (R 전용)
                else:
                    return 4
            
            best_file = min(files, key=format_priority)
            unique_files.append(best_file)
        
        # 수정 시간 기준 정렬 (최신 순)
        unique_files.sort(key=lambda f: f.stat().st_mtime, reverse=True)
        
        if len(unique_files) == 1:
            # 파일이 하나만 있으면 자동 선택
            selected_file = unique_files[0]
            print(f"[OK] 데이터 파일 로드: {selected_file.name}")
            return selected_file
        
        # 여러 파일이 있으면 선택 옵션 제공
        if interactive:
            print(f"\n[INFO] {len(unique_files)}개의 고유한 combined_data 파일을 발견했습니다:")
            print("(동일 데이터의 중복 형식은 자동 제거됨)")
            for i, file_path in enumerate(unique_files, 1):
                file_info = file_path.stat()
                size_mb = file_info.st_size / (1024 * 1024)
                mtime = datetime.fromtimestamp(file_info.st_mtime)
                
                # 형식 설명 추가
                format_desc = ""
                if file_path.suffix == '.parquet':
                    format_desc = " [권장: 압축률 우수]"
                elif file_path.suffix == '.csv':
                    format_desc = " [호환성 우수]"
                elif file_path.suffix == '.rds':
                    format_desc = " [R 전용]"
                
                print(f"{i}. {file_path.name} ({size_mb:.1f} MB, {mtime.strftime('%Y-%m-%d %H:%M')}){format_desc}")
            
            try:
                choice = int(input(f"\n파일을 선택하세요 (1-{len(unique_files)}, 0=최신파일 자동선택): "))
                if choice == 0 or choice < 1 or choice > len(unique_files):
                    selected_file = unique_files[0]  # 최신 파일
                    print(f"[AUTO] 최신 파일 선택: {selected_file.name}")
                else:
                    selected_file = unique_files[choice - 1]
                    print(f"[OK] 선택된 파일: {selected_file.name}")
            except (ValueError, KeyboardInterrupt):
                selected_file = unique_files[0]  # 최신 파일
                print(f"[AUTO] 최신 파일 자동 선택: {selected_file.name}")
        else:
            # 비대화형 모드: 최신 파일 자동 선택하되 정보 표시
            selected_file = unique_files[0]
            if len(all_files) > len(unique_files):
                removed_count = len(all_files) - len(unique_files)
                print(f"[INFO] {removed_count}개 중복 형식 파일 자동 제거됨")
            print(f"[AUTO] {len(unique_files)}개 고유 파일 중 최신 파일 선택: {selected_file.name}")
            if len(unique_files) > 1:
                print("다른 파일을 사용하려면 interactive=True로 실행하세요.")
        
        return selected_file
    
    def generate_filename(self, prefix: str, name: str, extension: str) -> str:
        """타임스탬프가 포함된 파일명 생성 (R 스크립트와 동일)"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"{timestamp}_{name}_{self.optional_tag}.{extension}"


# ========== 고급 형태소 분석 클래스 ==========
class AdvancedMorphemeAnalyzer:
    """고급 접두사/접미사 처리 형태소 분석기 (R 스크립트 완전 복제)"""
    
    def __init__(self, config: EnhancedMorphemeConfig):
        self.config = config
        self.analyzer = config.setup_analyzer()
    
    def extract_nouns_enhanced_xpn_xsn(self, text: str) -> List[str]:
        """
        개선된 XPN+XSN 명사 추출 (R 스크립트와 100% 동일한 로직)
        
        처리 순서:
        1. XPN + NNG/NNP + XSN (3-way 결합)
        2. XPN + NNG/NNP (2-way 결합)  
        3. NNG/NNP + XSN (2-way 결합)
        4. 단독 처리: NNG, NNP, XPN, XSN
        """
        if not text or pd.isna(text) or len(text.strip()) < 10:
            return []
        
        clean_text = text.strip()
        if len(clean_text) < 10:
            return []
        
        try:
            result = self.analyzer.tokenize(clean_text)
            all_nouns = []
            i = 0
            
            while i < len(result):
                token = result[i]
                
                # ========== 복합 패턴 처리: XPN + NNG/NNP + XSN ==========
                if (i <= len(result) - 3 and 
                    token.tag == "XPN" and 
                    result[i+1].tag in ["NNG", "NNP"] and 
                    result[i+2].tag == "XSN"):
                    
                    # 3-way 결합: 접두사 + 명사 + 접미사 (예: 비/XPN + 정상/NNG + 적/XSN = 비정상적)
                    triple_combined = token.form + result[i+1].form + result[i+2].form
                    all_nouns.append(triple_combined)
                    i += 3  # 3칸 이동
                    continue
                
                # ========== XPN + NNG/NNP 패턴 처리 ==========
                if (i <= len(result) - 2 and 
                    token.tag == "XPN" and 
                    result[i+1].tag in ["NNG", "NNP"]):
                    
                    # 접두사 + 명사 결합 (예: 비/XPN + 정상/NNG = 비정상)
                    prefix_combined = token.form + result[i+1].form
                    all_nouns.append(prefix_combined)
                    i += 2  # 2칸 이동
                    continue
                
                # ========== NNG/NNP + XSN 패턴 처리 (기존 로직) ==========
                if (i <= len(result) - 2 and 
                    token.tag in ["NNG", "NNP"] and 
                    result[i+1].tag == "XSN"):
                    
                    # 명사 + 접미사 결합 (예: 정상/NNG + 적/XSN = 정상적)
                    suffix_combined = token.form + result[i+1].form
                    all_nouns.append(suffix_combined)
                    i += 2  # 2칸 이동
                    continue
                
                # ========== 단독 처리: 일반 명사, 접두사, 접미사 ==========
                if token.tag in ["NNG", "NNP"]:
                    all_nouns.append(token.form)
                elif token.tag == "XPN":
                    all_nouns.append(token.form)
                elif token.tag == "XSN":
                    all_nouns.append(token.form)
                
                i += 1
            
            if all_nouns:
                final_nouns = list(set([noun for noun in all_nouns if len(noun) >= 1]))
                return final_nouns
            else:
                return []
                
        except Exception as e:
            print(f"[WARNING] 개선된 XPN+XSN 형태소 분석 오류: {e}")
            return []
    
    def analyze_morphemes_enhanced(self, text: str) -> str:
        """형태소 분석 수행 (R 스크립트와 동일)"""
        if not text or pd.isna(text) or len(text.strip()) < 10:
            return ""
        
        clean_text = text.strip()
        if len(clean_text) < 10:
            return ""
        
        try:
            result = self.analyzer.tokenize(clean_text)
            morpheme_tags = []
            
            for token in result:
                # 형태소/품사태그 형식으로 저장
                morpheme_tags.append(f"{token.form}/{token.tag}")
            
            return " ".join(morpheme_tags)
            
        except Exception as e:
            print(f"[WARNING] 개선된 형태소 분석 오류: {e}")
            return ""
    
    def process_single_document(self, doc_data: Tuple[str, str]) -> Dict[str, Any]:
        """단일 문서 처리"""
        doc_id, abstract = doc_data
        
        # 명사 추출
        nouns = self.extract_nouns_enhanced_xpn_xsn(abstract)
        noun_text = ", ".join(nouns) if nouns else ""
        
        # 형태소 분석
        morphemes = self.analyze_morphemes_enhanced(abstract)
        
        return {
            'doc_id': doc_id,
            'nouns': noun_text,
            'morphemes': morphemes,
            'has_result': bool(noun_text or morphemes)
        }


# ========== 배치 처리 함수 (R 스크립트 복제) ==========
def process_batch_safe(batch_data: List[Tuple[str, str]], config_dict: Dict) -> Dict[str, Any]:
    """
    워커 프로세스에서 배치 처리 (R 스크립트의 process_batch_safe 함수와 동일)
    """
    worker_start_time = time.time()
    
    try:
        # 각 워커에서 독립적인 kiwipiepy 초기화 (최소한)
        from kiwipiepy import Kiwi
        
        # 모델 초기화 (간단한 불린 값만 사용)
        cong_available = config_dict.get('cong_available', False)
        use_cong_model = config_dict.get('use_cong_model', False)
        
        if use_cong_model and cong_available:
            # CoNg 모델 경로는 상대 경로로 고정
            cong_model_path = "cong-base"
            if Path(cong_model_path).exists():
                kiwi_analyzer = Kiwi(model_path=cong_model_path, model_type='cong')
            else:
                kiwi_analyzer = Kiwi()
        else:
            kiwi_analyzer = Kiwi()
        
        kiwi_analyzer.space_tolerance = 2
        
        # 사용자 사전 로드 (파일 경로만 전달)
        dict_loaded = False
        dict_file_path = config_dict.get('selected_dict')
        if dict_file_path and Path(dict_file_path).exists():
            try:
                added_words = kiwi_analyzer.load_user_dictionary(dict_file_path)
                dict_loaded = True
            except Exception:
                dict_loaded = False
        
        # 1단계: 형태소 분석 수행 및 저장
        morpheme_data = []  # (doc_id, morpheme_analysis) 튜플 저장
        
        for doc_id, abstract in batch_data:
            try:
                morpheme_analysis = analyze_morphemes_enhanced_worker(abstract, kiwi_analyzer)
                if morpheme_analysis and len(morpheme_analysis.strip()) > 0:
                    morpheme_data.append((str(doc_id), morpheme_analysis))
            except Exception:
                continue  # 실패한 경우 건너뛰기
        
        # 2단계: 형태소 분석 결과를 태그 기반으로 파싱하여 명사 추출
        def parse_morpheme_to_nouns(morpheme_text: str) -> str:
            """형태소 분석 결과를 파싱하여 명사만 추출"""
            if not morpheme_text or not morpheme_text.strip():
                return ""
            
            try:
                tokens = morpheme_text.split()
                parsed_tokens = []
                
                for token in tokens:
                    if '/' in token:
                        form, tag = token.rsplit('/', 1)
                        parsed_tokens.append({'form': form, 'tag': tag})
                
                extracted_nouns = []
                i = 0
                
                while i < len(parsed_tokens):
                    token = parsed_tokens[i]
                    
                    # 3-way: XPN + NNG/NNP + XSN
                    if (i <= len(parsed_tokens) - 3 and 
                        token['tag'] == "XPN" and 
                        parsed_tokens[i+1]['tag'] in ["NNG", "NNP"] and 
                        parsed_tokens[i+2]['tag'] == "XSN"):
                        triple_combined = token['form'] + parsed_tokens[i+1]['form'] + parsed_tokens[i+2]['form']
                        extracted_nouns.append(triple_combined)
                        i += 3
                        continue
                    
                    # 2-way: XPN + NNG/NNP
                    if (i <= len(parsed_tokens) - 2 and 
                        token['tag'] == "XPN" and 
                        parsed_tokens[i+1]['tag'] in ["NNG", "NNP"]):
                        prefix_combined = token['form'] + parsed_tokens[i+1]['form']
                        extracted_nouns.append(prefix_combined)
                        i += 2
                        continue
                    
                    # 2-way: NNG/NNP + XSN
                    if (i <= len(parsed_tokens) - 2 and 
                        token['tag'] in ["NNG", "NNP"] and 
                        parsed_tokens[i+1]['tag'] == "XSN"):
                        suffix_combined = token['form'] + parsed_tokens[i+1]['form']
                        extracted_nouns.append(suffix_combined)
                        i += 2
                        continue
                    
                    # 단독 처리
                    if token['tag'] in ["NNG", "NNP", "XPN", "XSN"] and len(token['form']) >= 1:
                        extracted_nouns.append(token['form'])
                    
                    i += 1
                
                # 형태소 분석 결과 그대로 명사 추출 (중복 제거 없이 원본 순서 보존)
                return ", ".join(extracted_nouns) if extracted_nouns else ""
                
            except Exception:
                return ""
        
        # 3단계: 명사 추출 결과 생성 (형태소 분석 결과와 동일한 doc_id 순서)
        noun_data = []  # (doc_id, noun_extraction) 튜플 저장
        
        for doc_id, morpheme_analysis in morpheme_data:
            noun_extraction = parse_morpheme_to_nouns(morpheme_analysis)
            if noun_extraction:  # 명사가 추출된 경우만 저장
                noun_data.append((doc_id, noun_extraction))
        
        # 결과 정리 (형태소 분석과 명사 추출이 동일한 데이터 소스 기반으로 일치 보장)
        morpheme_doc_ids = [item[0] for item in morpheme_data]
        morpheme_results_filtered = [item[1] for item in morpheme_data]
        noun_doc_ids = [item[0] for item in noun_data]
        noun_results_filtered = [item[1] for item in noun_data]
        
        result = {
            'morpheme_doc_ids': morpheme_doc_ids,
            'morphemes': morpheme_results_filtered,
            'noun_doc_ids': noun_doc_ids,
            'nouns': noun_results_filtered,
            'batch_start': 1,
            'batch_end': len(batch_data),
            'processing_time': time.time() - worker_start_time,
            'dict_loaded': dict_loaded
        }
        
        return result
        
    except Exception as e:
        # 오류 발생 시 빈 결과 반환
        return {
            'morpheme_doc_ids': [],
            'morphemes': [],
            'noun_doc_ids': [],
            'nouns': [],
            'batch_start': 1,
            'batch_end': len(batch_data),
            'processing_time': time.time() - worker_start_time,
            'dict_loaded': False,
            'error': str(e)
        }


def extract_nouns_from_morpheme_analysis(morpheme_analysis: str) -> List[str]:
    """형태소 분석 결과에서 명사 추출 (동일한 데이터 소스 보장)"""
    if not morpheme_analysis or not morpheme_analysis.strip():
        return []
    
    try:
        # 형태소 분석 결과 파싱
        tokens = morpheme_analysis.split()
        parsed_tokens = []
        
        for token in tokens:
            if '/' in token:
                form, tag = token.rsplit('/', 1)
                parsed_tokens.append({'form': form, 'tag': tag})
        
        all_nouns = []
        i = 0
        
        while i < len(parsed_tokens):
            token = parsed_tokens[i]
            
            # 3-way: XPN + NNG/NNP + XSN
            if (i <= len(parsed_tokens) - 3 and 
                token['tag'] == "XPN" and 
                parsed_tokens[i+1]['tag'] in ["NNG", "NNP"] and 
                parsed_tokens[i+2]['tag'] == "XSN"):
                triple_combined = token['form'] + parsed_tokens[i+1]['form'] + parsed_tokens[i+2]['form']
                all_nouns.append(triple_combined)
                i += 3
                continue
            
            # 2-way: XPN + NNG/NNP
            if (i <= len(parsed_tokens) - 2 and 
                token['tag'] == "XPN" and 
                parsed_tokens[i+1]['tag'] in ["NNG", "NNP"]):
                prefix_combined = token['form'] + parsed_tokens[i+1]['form']
                all_nouns.append(prefix_combined)
                i += 2
                continue
            
            # 2-way: NNG/NNP + XSN
            if (i <= len(parsed_tokens) - 2 and 
                token['tag'] in ["NNG", "NNP"] and 
                parsed_tokens[i+1]['tag'] == "XSN"):
                suffix_combined = token['form'] + parsed_tokens[i+1]['form']
                all_nouns.append(suffix_combined)
                i += 2
                continue
            
            # 단독 처리
            if token['tag'] in ["NNG", "NNP", "XPN", "XSN"] and len(token['form']) >= 1:
                all_nouns.append(token['form'])
            
            i += 1
        
        return list(set(all_nouns))
        
    except Exception:
        return []


def analyze_morphemes_enhanced_worker(text: str, kiwi_analyzer) -> str:
    """워커용 형태소 분석 함수"""
    if not text or pd.isna(text) or len(text.strip()) < 10:
        return ""
    
    clean_text = text.strip()
    if len(clean_text) < 10:
        return ""
    
    try:
        result = kiwi_analyzer.tokenize(clean_text)
        morpheme_tags = []
        
        for token in result:
            morpheme_tags.append(f"{token.form}/{token.tag}")
        
        return " ".join(morpheme_tags)
        
    except Exception:
        return ""


# ========== 고급 분석 관리자 ==========
class AdvancedMorphemeAnalysisManager:
    """고급 형태소 분석 관리자 (R 스크립트 완전 복제)"""
    
    def __init__(self, interactive: bool = True):
        self.config = EnhancedMorphemeConfig()
        self.interactive = interactive
        if interactive:
            self.config.interactive_setup()
        else:
            self._auto_setup()
    
    def _auto_setup(self):
        """자동 설정 (비대화형)"""
        print("\n========== 자동 설정 모드 ==========")
        
        # CoNg 모델 자동 선택 및 설치
        if self.config.cong_available:
            self.config.use_cong_model = True
            print("[AUTO] CoNg 모델 사용")
        else:
            print("[AUTO] CoNg 모델이 없어 자동 다운로드를 시도합니다...")
            if self.config.download_cong_model():
                self.config.use_cong_model = True
                print("[AUTO] CoNg 모델 다운로드 및 설치 완료")
            else:
                print("[AUTO] 기본 모델 사용")
        
        # 사용자 사전 자동 선택
        if self.config.dict_files:
            self.config.use_user_dict = True
            self.config.selected_dict = self.config.dict_files[0]  # 최신 파일
            # 태그 생성
            dict_filename = self.config.selected_dict.name
            if "_user_dict_" in dict_filename:
                self.config.dict_tag = dict_filename.split("_user_dict_")[1].replace(".txt", "")
            else:
                self.config.dict_tag = "userdict"
            print(f"[AUTO] 사전 선택: {self.config.selected_dict.name}")
        else:
            self.config.use_user_dict = False
            self.config.dict_tag = "default"
            print("[AUTO] 사전 없음")
        
        # 결과 파일 태그 생성
        model_suffix = "cong" if self.config.use_cong_model else "default"
        self.config.optional_tag = f"kiwipiepy_{model_suffix}_{self.config.dict_tag}"
        
        print(f"[AUTO] 설정 완료: {self.config.optional_tag}")
    
    def load_data(self) -> pd.DataFrame:
        """데이터 로드 (R 스크립트와 동일한 로직)"""
        print("\n========== 데이터 불러오기 ==========")
        
        data_file = self.config.find_latest_data(interactive=self.interactive)
        if not data_file:
            raise FileNotFoundError("combined_data 파일을 찾을 수 없습니다.")
        
        # 파일 형식에 따라 로드
        if data_file.suffix == '.parquet':
            combined_data = pd.read_parquet(data_file)
        elif data_file.suffix == '.csv':
            combined_data = pd.read_csv(data_file)
        else:
            raise ValueError(f"지원하지 않는 파일 형식: {data_file.suffix}")
        
        print(f"전체 데이터 행 수: {len(combined_data)}")
        
        # 컬럼 식별 (R 스크립트와 동일한 로직)
        id_patterns = ["ID", "id", "논문 ID", "일련", "번호", "article", "Article"]
        id_column = None
        for pattern in id_patterns:
            matching_cols = [col for col in combined_data.columns if pattern in col]
            if matching_cols:
                id_column = matching_cols[0]
                break
        
        # abstract 컬럼 우선 사용 (R 스크립트와 동일)
        abstract_column = None
        if "abstract" in combined_data.columns and combined_data["abstract"].dtype == 'object':
            abstract_column = "abstract"
            print("[OK] 표준화된 'abstract' 컬럼을 사용합니다.")
        else:
            # 대체 패턴으로 검색 (한글 우선)
            abstract_patterns = ["초록", "국문초록", "국문 초록", "요약", "summary"]
            for pattern in abstract_patterns:
                matching_cols = [col for col in combined_data.columns if pattern in col]
                # 영문 초록은 제외
                matching_cols = [col for col in matching_cols 
                               if not any(x in col.lower() for x in ["multilingual", "다국어", "영문", "english"])]
                
                if matching_cols:
                    for col in matching_cols:
                        if combined_data[col].dtype == 'object':
                            abstract_column = col
                            break
                    if abstract_column:
                        break
        
        if not id_column:
            id_column = combined_data.columns[0]
        if not abstract_column:
            text_cols = [col for col in combined_data.columns if combined_data[col].dtype == 'object']
            text_cols = [col for col in text_cols if col != "source_file"]
            abstract_column = text_cols[0] if text_cols else None
        
        if not abstract_column:
            raise ValueError("분석할 텍스트 컬럼을 찾을 수 없습니다.")
        
        print(f"ID 컬럼: {id_column}")
        print(f"초록 컬럼: {abstract_column}")
        
        # 분석 데이터 준비 (R 스크립트와 동일한 로직)
        analysis_data = combined_data[[id_column, abstract_column]].copy()
        analysis_data.columns = ['doc_id', 'abstract']
        
        # 데이터 정리
        analysis_data = analysis_data[
            analysis_data['abstract'].notna() & 
            (analysis_data['abstract'].astype(str).str.len() > 10)
        ].copy()
        
        analysis_data['doc_id'] = analysis_data['doc_id'].astype(str)
        analysis_data['abstract'] = analysis_data['abstract'].astype(str).str.strip()
        analysis_data = analysis_data[analysis_data['abstract'].str.len() > 10]
        
        print(f"분석 대상: {len(analysis_data)}개 문서")
        
        # 배치 크기 재계산
        self.config.batch_size = self.config._calculate_optimal_batch_size(len(analysis_data))
        total_batches = (len(analysis_data) + self.config.batch_size - 1) // self.config.batch_size
        
        print(f"배치 크기 최적화:")
        print(f"  총 문서: {len(analysis_data)}개")
        print(f"  사용 코어: {self.config.use_cores}개")
        print(f"  최적 배치 크기: {self.config.batch_size}개")
        print(f"  총 배치 수: {total_batches}개")
        print(f"  배치/코어 비율: {total_batches / self.config.use_cores:.1f}개")
        
        return analysis_data
    
    def process_parallel_enhanced(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.DataFrame, Dict]:
        """고급 병렬 처리 (R 스크립트와 동일한 로직)"""
        print(f"\n========== 개선된 접두사/접미사 처리 형태소 분석 실행 (안전한 병렬 처리) ==========")
        print(f"분석기 버전: 개선된 접두사/접미사 처리 v3.0 (병렬 최적화)")
        print(f"사용 코어: {self.config.use_cores}개 (전체 {self.config.cpu_cores}개 중)")
        
        # 배치 생성
        doc_data = list(zip(df['doc_id'], df['abstract']))
        batches = [doc_data[i:i + self.config.batch_size] 
                  for i in range(0, len(doc_data), self.config.batch_size)]
        
        print(f"총 배치 수: {len(batches)}")
        
        # 설정을 딕셔너리로 변환 (직렬화 가능)
        config_dict = {
            'cong_available': self.config.cong_available,
            'use_cong_model': self.config.use_cong_model,
            'selected_dict': str(self.config.selected_dict) if self.config.selected_dict else None,
        }
        
        # 병렬 처리 실행
        total_start_time = time.time()
        all_results = []
        
        if self.config.use_cores <= 2 or len(df) <= 50:
            print("[INFO] 소규모 데이터 또는 제한된 코어 - 직렬 처리 모드")
            # 직렬 처리
            for i, batch in enumerate(batches):
                print(f"처리 중: 배치 {i+1}/{len(batches)}")
                result = process_batch_safe(batch, config_dict)
                all_results.append(result)
        else:
            # 병렬 처리
            print(f"[INFO] 안전한 병렬 배치 처리 시작... ({self.config.use_cores} 워커 × {len(batches)} 배치)")
            
            with ProcessPoolExecutor(max_workers=self.config.use_cores) as executor:
                futures = {
                    executor.submit(process_batch_safe, batch, config_dict): i 
                    for i, batch in enumerate(batches)
                }
                
                with tqdm(total=len(batches), desc="Processing batches") as pbar:
                    for future in as_completed(futures):
                        try:
                            batch_result = future.result()
                            all_results.append(batch_result)
                        except Exception as e:
                            print(f"[ERROR] Batch processing error: {e}")
                            # 빈 결과 추가
                            all_results.append({
                                'doc_ids': [], 'morphemes': [], 'nouns': [],
                                'processing_time': 0, 'dict_loaded': False
                            })
                        pbar.update(1)
        
        total_end_time = time.time()
        total_processing_time = total_end_time - total_start_time
        
        print(f"\n========== 결과 통합 중 ==========")
        
        # 결과 통합 (형태소 분석과 명사 추출 분리)
        all_morpheme_doc_ids = []
        all_morphemes = []
        all_noun_doc_ids = []
        all_nouns = []
        worker_times = []
        dict_status = []
        
        for result in all_results:
            # 새로운 분리된 결과 처리
            if 'morpheme_doc_ids' in result and 'noun_doc_ids' in result:
                all_morpheme_doc_ids.extend(result.get('morpheme_doc_ids', []))
                all_morphemes.extend(result.get('morphemes', []))
                all_noun_doc_ids.extend(result.get('noun_doc_ids', []))
                all_nouns.extend(result.get('nouns', []))
            else:
                # 기존 형식 호환성 유지
                old_doc_ids = result.get('doc_ids', [])
                all_morpheme_doc_ids.extend(old_doc_ids)
                all_morphemes.extend(result.get('morphemes', []))
                all_noun_doc_ids.extend(old_doc_ids)
                all_nouns.extend(result.get('nouns', []))
            
            if 'processing_time' in result:
                worker_times.append(result['processing_time'])
            if 'dict_loaded' in result:
                dict_status.append(result['dict_loaded'])
        
        # 데이터프레임 생성 (각각 독립적으로)
        morpheme_df = pd.DataFrame({
            'doc_id': all_morpheme_doc_ids,
            'morpheme_analysis': all_morphemes
        }) if all_morpheme_doc_ids else pd.DataFrame(columns=['doc_id', 'morpheme_analysis'])
        
        noun_df = pd.DataFrame({
            'doc_id': all_noun_doc_ids,
            'noun_extraction': all_nouns
        }) if all_noun_doc_ids else pd.DataFrame(columns=['doc_id', 'noun_extraction'])
        
        # 성능 통계 (형태소 분석 기준)
        performance_stats = {
            'total_documents': len(df),
            'processed_documents': len(all_morpheme_doc_ids),
            'success_count': len(all_morpheme_doc_ids),
            'error_count': len(df) - len(all_morpheme_doc_ids),
            'success_rate': (len(all_morpheme_doc_ids) / len(df) * 100) if len(df) > 0 else 0,
            'total_processing_time': total_processing_time,
            'processing_speed': len(all_morpheme_doc_ids) / total_processing_time if total_processing_time > 0 else 0,
            'worker_times': worker_times,
            'dict_loaded_count': sum(dict_status) if dict_status else 0,
            'total_workers': len(dict_status) if dict_status else 0
        }
        
        # 결과 출력 (R 스크립트와 동일한 형식)
        print("\n========== 개선된 접두사/접미사 처리 분석 결과 (병렬 처리) ==========")
        print("분석기 버전: 개선된 접두사/접미사 처리 v3.0 (병렬 최적화)")
        print(f"사용 코어: {self.config.use_cores}개 (전체 {self.config.cpu_cores}개 중)")
        print(f"전체 문서 수: {performance_stats['total_documents']}")
        print(f"처리된 문서 수: {performance_stats['processed_documents']}")
        print(f"성공한 문서 수: {performance_stats['success_count']}")
        print(f"오류 발생 문서 수: {performance_stats['error_count']}")
        print(f"형태소 분석 결과 수: {len(morpheme_df)}")
        print(f"명사 추출 결과 수: {len(noun_df)}")
        print(f"성공률: {performance_stats['success_rate']:.1f}%")
        print(f"전체 처리 시간: {performance_stats['total_processing_time']/60:.2f}분")
        print(f"평균 처리 속도: {performance_stats['processing_speed']:.1f} 문서/초")
        print(f"리소스 활용 효율성: {self.config.use_cores}/{self.config.cpu_cores} 코어 ({(self.config.use_cores/self.config.cpu_cores)*100:.0f}%) 사용")
        
        return morpheme_df, noun_df, performance_stats
    
    def save_results_enhanced(self, morpheme_df: pd.DataFrame, noun_df: pd.DataFrame, 
                            performance_stats: Dict, total_docs: int):
        """향상된 결과 저장 (R 스크립트와 동일한 형식)"""
        print("\n========== 최종 결과 저장 ==========")
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 메타데이터 생성 (R 스크립트와 동일한 구조)
        metadata = {
            'analysis_date': datetime.now().date().isoformat(),
            'dict_type': self.config.optional_tag,
            'selected_dict': self.config.selected_dict.name if self.config.selected_dict else None,
            'total_documents': total_docs,
            'processed_documents': performance_stats['processed_documents'],
            'successful_documents': performance_stats['success_count'],
            'error_documents': performance_stats['error_count'],
            'success_rate': performance_stats['success_rate'],
            'use_custom_dict': self.config.use_user_dict,
            'api_used': False,
            'batch_size': self.config.batch_size,
            'total_batches': len(performance_stats.get('worker_times', [])),
            # Enhanced XPN+XSN Kiwipiepy + 병렬 처리 추가 필드
            'analyzer_type': "개선된 접두사/접미사 처리 (병렬 최적화)",
            'analyzer_version': "v3.1_python_parallel_userdict" if self.config.use_user_dict else "v3.0_python_parallel",
            'model_type': "CoNg" if self.config.use_cong_model else "기본",
            'model_path': str(self.config.cong_model_dir) if self.config.use_cong_model else None,
            'total_processing_time': performance_stats['total_processing_time'],
            'processing_speed': performance_stats['processing_speed'],
            # 병렬 처리 정보 추가
            'parallel_info': {
                'cores_used': self.config.use_cores,
                'total_cores': self.config.cpu_cores,
                'system_tier': self.config.system_tier,
                'available_memory_gb': self.config.available_memory_gb,
                'core_utilization_percent': round((self.config.use_cores/self.config.cpu_cores)*100, 1),
                'parallel_efficiency': round((min(performance_stats['worker_times']) / max(performance_stats['worker_times'])) * 100, 1) if performance_stats['worker_times'] else None,
                'batch_count': len(performance_stats.get('worker_times', [])),
                'avg_batch_completion': round(np.mean(performance_stats['worker_times']), 2) if performance_stats['worker_times'] else None
            },
            'enhancements': [
                "배치 레벨 병렬 처리 (최적화 1순위)",
                "리스트 수집 방식 메모리 최적화 (최적화 2순위)", 
                "파일 기반 진행률 모니터링 (최적화 3순위)",
                "XSN 명사파생접미사 태그 기반 추출",
                "XPN 명사파생접두사 태그 기반 추출",
                "선행명사와 XSN 접미사 결합",
                "XPN 접두사와 후행명사 결합",
                "XPN + NNG/NNP + XSN 3-way 복합 결합",
                "순수 품사 태그 기반 명사 추출",
                "형태소 품질 향상",
                "CoNg 모델 (향상된 정확도/속도)" if self.config.use_cong_model else None,
                "사용자 사전 적용" if self.config.use_user_dict else None
            ]
        }
        
        # 결과 구조화 (R 스크립트와 동일)
        final_results = {
            'morpheme_analysis': morpheme_df.to_dict('records'),
            'noun_extraction': noun_df.to_dict('records'),
            'metadata': metadata
        }
        
        # 파일 저장
        result_files = {}
        
        # 형태소 분석 결과 (JSON) - 통합된 버전
        morpheme_json = self.config.processed_data_path / f"{timestamp}_morpheme_results_{self.config.optional_tag}.json"
        with open(morpheme_json, 'w', encoding='utf-8') as f:
            json.dump(final_results, f, ensure_ascii=False, indent=2)
        result_files['morpheme_json'] = morpheme_json
        
        # CSV 저장
        if len(morpheme_df) > 0:
            morpheme_csv = self.config.processed_data_path / f"{timestamp}_morpheme_analysis_{self.config.optional_tag}.csv"
            morpheme_df.to_csv(morpheme_csv, index=False, encoding='utf-8-sig')
            result_files['morpheme_csv'] = morpheme_csv
        
        if len(noun_df) > 0:
            noun_csv = self.config.processed_data_path / f"{timestamp}_noun_extraction_{self.config.optional_tag}.csv"
            noun_df.to_csv(noun_csv, index=False, encoding='utf-8-sig')
            result_files['noun_csv'] = noun_csv
        
        # 상세 분석 보고서 생성 (R 스크립트와 동일)
        report_file = self._generate_detailed_report(morpheme_df, noun_df, metadata, timestamp)
        result_files['report'] = report_file
        
        print("생성된 파일:")
        for file_type, file_path in result_files.items():
            print(f"- {file_path.name}")
        
        return result_files
    
    def _generate_detailed_report(self, morpheme_df: pd.DataFrame, noun_df: pd.DataFrame, 
                                metadata: Dict, timestamp: str) -> Path:
        """상세 분석 보고서 생성 (R 스크립트와 동일한 형식)"""
        
        # 기본 정보
        model_info_text = ""
        if metadata['model_type'] == 'CoNg':
            model_info_text = "**사용 모델**: CoNg 모델 (Contextual N-gram, v0.21.0+)\n**모델 특징**: 향상된 정확도 및 처리 속도\n"
        else:
            model_info_text = "**사용 모델**: 기본 모델\n"
        
        dict_info_text = ""
        if metadata['use_custom_dict'] and metadata['selected_dict']:
            dict_info_text = f"**적용 사전**: {metadata['selected_dict']}\n"
            if self.config.selected_dict:
                dict_info = self.config.selected_dict.stat()
                dict_info_text += f"**사전 파일 크기**: {dict_info.st_size/1024:.1f} KB\n"
                mtime = datetime.fromtimestamp(dict_info.st_mtime)
                dict_info_text += f"**사전 생성일**: {mtime.strftime('%Y-%m-%d %H:%M')}\n"
        else:
            dict_info_text = "**적용 사전**: 없음\n"
        
        # 보고서 시작
        report_lines = [
            "# 개선된 접두사/접미사 처리 형태소 분석 결과",
            "",
            f"**분석일**: {metadata['analysis_date']}",
            f"**분석기**: {metadata['analyzer_type']}",
            model_info_text,
            dict_info_text,
            f"**전체 문서 수**: {metadata['total_documents']:,}",
            f"**처리된 문서 수**: {metadata['processed_documents']:,}",
            f"**성공한 문서 수**: {metadata['successful_documents']:,}",
            f"**오류 발생 문서 수**: {metadata['error_documents']:,}",
            f"**성공률**: {metadata['success_rate']:.1f}%",
            f"**형태소 분석 결과**: {len(morpheme_df):,}개",
            f"**명사 추출 결과**: {len(noun_df):,}개",
            f"**전체 처리 시간**: {metadata['total_processing_time']/60:.2f}분",
            f"**평균 처리 속도**: {metadata['processing_speed']:.1f} 문서/초",
            "",
            "## 태그 기반 명사 추출 특징",
            "- **XPN+XSN 태그 기반**: XPN 명사파생접두사와 XSN 명사파생접미사를 태그로 직접 추출",
            "- **복합 패턴 처리**: XPN + NNG/NNP + XSN 3-way 결합 자동 인식 및 처리",
            "- **접두사 결합**: XPN 접두사 + 명사(NNG/NNP) 자동 결합",
            "- **접미사 결합**: 명사(NNG/NNP) + XSN 접미사 자동 결합 (기존 기능 유지)",
            "- **순수 품사 추출**: NNG, NNP, XPN, XSN 태그만 사용한 정확한 추출",
            "- **워크플로우 호환**: 기존 분석 파이프라인과 완전 호환",
            ""
        ]
        
        # 명사 빈도 분석
        if len(noun_df) > 0:
            all_nouns = []
            for noun_text in noun_df['noun_extraction']:
                if pd.notna(noun_text) and noun_text:
                    all_nouns.extend(noun_text.split(', '))
            
            if all_nouns:
                noun_counts = pd.Series(all_nouns).value_counts()
                
                report_lines.extend([
                    "## 상위 20개 명사 (개선된 접두사/접미사 처리)",
                    ""
                ])
                
                for i, (noun, count) in enumerate(noun_counts.head(20).items(), 1):
                    report_lines.append(f"{i}. **{noun}** ({count:,}회)")
                
                # XSN 패턴 분석 (R 스크립트와 동일한 로직)
                report_lines.extend([
                    "",
                    "## XSN 명사파생접미사 패턴 분석 (태그 기반)",
                    ""
                ])
                
                # 형태소 분석 결과에서 XSN 태그 추출
                xsn_morphemes = []
                combined_nouns = []
                
                for _, row in morpheme_df.iterrows():
                    morpheme_text = row['morpheme_analysis']
                    if pd.notna(morpheme_text) and morpheme_text:
                        # 형태소/태그 쌍으로 분리
                        morphemes = morpheme_text.split()
                        
                        for i, morpheme in enumerate(morphemes):
                            if morpheme.endswith('/XSN'):
                                xsn_form = morpheme.replace('/XSN', '')
                                xsn_morphemes.append(xsn_form)
                                
                                # 선행 명사와 결합된 형태 찾기
                                if i > 0 and (morphemes[i-1].endswith('/NNG') or morphemes[i-1].endswith('/NNP')):
                                    noun_form = morphemes[i-1].split('/')[0]
                                    combined_form = noun_form + xsn_form
                                    combined_nouns.append(combined_form)
                
                # XSN 접미사 빈도 분석
                if xsn_morphemes:
                    xsn_counts = pd.Series(xsn_morphemes).value_counts()
                    
                    report_lines.extend([
                        "### 발견된 XSN 접미사 (태그 기반 추출)",
                        f"총 XSN 접미사 종류: {len(xsn_counts):,}개",
                        f"총 XSN 사용 빈도: {sum(xsn_counts):,}회",
                        ""
                    ])
                    
                    # 상위 XSN 접미사 보고
                    for i, (xsn, count) in enumerate(xsn_counts.head(15).items(), 1):
                        report_lines.append(f"{i}. **{xsn}** ({count:,}회)")
                else:
                    report_lines.append("XSN 태그가 발견되지 않았습니다.")
                
                # 결합 명사 분석
                if combined_nouns:
                    combined_counts = pd.Series(combined_nouns).value_counts()
                    
                    report_lines.extend([
                        "",
                        "### NNG/NNP + XSN 결합 명사 분석",
                        f"총 결합 명사 종류: {len(combined_counts):,}개",
                        f"총 결합 명사 빈도: {sum(combined_counts):,}회",
                        ""
                    ])
                    
                    # 상위 결합 명사
                    for i, (noun, count) in enumerate(combined_counts.head(20).items(), 1):
                        report_lines.append(f"{i}. **{noun}** ({count:,}회)")
                else:
                    report_lines.extend([
                        "",
                        "### NNG/NNP + XSN 결합 명사",
                        "결합 명사가 발견되지 않았습니다."
                    ])
                
                # XPN 패턴 분석 추가 (R 스크립트와 동일)
                report_lines.extend([
                    "",
                    "## XPN 명사파생접두사 패턴 분석 (태그 기반)",
                    ""
                ])
                
                # 형태소 분석 결과에서 XPN 태그 추출
                xpn_morphemes = []
                prefix_combined_nouns = []
                triple_combined_nouns = []
                
                for _, row in morpheme_df.iterrows():
                    morpheme_text = row['morpheme_analysis']
                    if pd.notna(morpheme_text) and morpheme_text:
                        morphemes = morpheme_text.split()
                        
                        for i, morpheme in enumerate(morphemes):
                            if morpheme.endswith('/XPN'):
                                xpn_form = morpheme.replace('/XPN', '')
                                xpn_morphemes.append(xpn_form)
                                
                                # XPN + NNG/NNP + XSN 3-way 결합 찾기
                                if (i < len(morphemes) - 2 and 
                                    (morphemes[i+1].endswith('/NNG') or morphemes[i+1].endswith('/NNP')) and
                                    morphemes[i+2].endswith('/XSN')):
                                    noun_form = morphemes[i+1].split('/')[0]
                                    xsn_form = morphemes[i+2].split('/')[0]
                                    triple_form = xpn_form + noun_form + xsn_form
                                    triple_combined_nouns.append(triple_form)
                                # XPN + NNG/NNP 2-way 결합 찾기
                                elif (i < len(morphemes) - 1 and 
                                      (morphemes[i+1].endswith('/NNG') or morphemes[i+1].endswith('/NNP'))):
                                    noun_form = morphemes[i+1].split('/')[0]
                                    prefix_form = xpn_form + noun_form
                                    prefix_combined_nouns.append(prefix_form)
                
                # XPN 접두사 빈도 분석
                if xpn_morphemes:
                    xpn_counts = pd.Series(xpn_morphemes).value_counts()
                    
                    report_lines.extend([
                        "### 발견된 XPN 접두사 (태그 기반 추출)",
                        f"총 XPN 접두사 종류: {len(xpn_counts):,}개",
                        f"총 XPN 사용 빈도: {sum(xpn_counts):,}회",
                        ""
                    ])
                    
                    # 상위 XPN 접두사 보고
                    for i, (xpn, count) in enumerate(xpn_counts.head(15).items(), 1):
                        report_lines.append(f"{i}. **{xpn}** ({count:,}회)")
                else:
                    report_lines.append("XPN 태그가 발견되지 않았습니다.")
                
                # XPN + NNG/NNP 결합 명사 분석
                if prefix_combined_nouns:
                    prefix_counts = pd.Series(prefix_combined_nouns).value_counts()
                    
                    report_lines.extend([
                        "",
                        "### XPN + NNG/NNP 결합 명사 분석",
                        f"총 접두사 결합 명사 종류: {len(prefix_counts):,}개",
                        f"총 접두사 결합 명사 빈도: {sum(prefix_counts):,}회",
                        ""
                    ])
                    
                    # 상위 접두사 결합 명사
                    for i, (noun, count) in enumerate(prefix_counts.head(15).items(), 1):
                        report_lines.append(f"{i}. **{noun}** ({count:,}회)")
                
                # XPN + NNG/NNP + XSN 3-way 결합 명사 분석
                if triple_combined_nouns:
                    triple_counts = pd.Series(triple_combined_nouns).value_counts()
                    
                    report_lines.extend([
                        "",
                        "### XPN + NNG/NNP + XSN 복합 결합 명사 분석",
                        f"총 복합 결합 명사 종류: {len(triple_counts):,}개",
                        f"총 복합 결합 명사 빈도: {sum(triple_counts):,}회",
                        ""
                    ])
                    
                    # 상위 복합 결합 명사
                    for i, (noun, count) in enumerate(triple_counts.head(10).items(), 1):
                        report_lines.append(f"{i}. **{noun}** ({count:,}회)")
                
                # 통계 정보
                report_lines.extend([
                    "",
                    "## 통계 정보",
                    f"총 고유 명사 수: {len(noun_counts):,}",
                    f"총 명사 빈도: {len(all_nouns):,}",
                    f"문서당 평균 명사 수: {len(all_nouns) / len(noun_df):.1f}" if len(noun_df) > 0 else "문서당 평균 명사 수: 0"
                ])
        
        # 보고서 파일 저장
        report_filename = f"{timestamp}_analysis_report_{self.config.optional_tag}.md"
        report_file = self.config.reports_path / report_filename
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(report_lines))
        
        return report_file


# ========== 메인 실행 함수 ==========
def main(interactive: bool = False):
    """메인 실행 함수"""
    print("========== 개선된 접두사/접미사 처리 - 전체 데이터 분석 시작 ==========")
    
    try:
        # 분석 관리자 초기화
        manager = AdvancedMorphemeAnalysisManager(interactive=interactive)
        
        # 데이터 로드
        df = manager.load_data()
        
        print(f"\n[OK] 분석을 시작합니다.")
        print(f"예상 분석 시간: 약 {len(df) / 1000 * 0.3:.1f}분 (최적화됨)")
        
        # 고급 형태소 분석 실행
        morpheme_df, noun_df, performance_stats = manager.process_parallel_enhanced(df)
        
        # 결과 저장
        result_files = manager.save_results_enhanced(morpheme_df, noun_df, performance_stats, len(df))
        
        print(f"\n[SUCCESS] 개선된 접두사/접미사 처리 형태소 분석 완료!")
        print(f"[RESULT] 처리 결과: {len(morpheme_df):,}개 문서")
        print(f"[TIME] 처리 시간: {performance_stats['total_processing_time']/60:.2f}분")
        print(f"[SPEED] 처리 속도: {performance_stats['processing_speed']:.1f} 문서/초")
        
    except Exception as e:
        print(f"[ERROR] 분석 실패: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    # ========== 실행 모드 설정 ==========
    # interactive=True:  대화형 모드 (사용자 입력 필요)
    #   - CoNg 모델 다운로드 여부 선택
    #   - 사용자 사전 파일 선택
    #   - Combined_data 파일 선택 (여러 개 있을 때)
    #   - 각 단계에서 사용자 확인 및 선택
    #
    # interactive=False: 자동 모드 (무인 실행)
    #   - 가장 좋은 옵션으로 자동 설정
    #   - CoNg 모델이 있으면 자동 사용, 없으면 자동 다운로드 시도
    #   - 최신 사용자 사전 자동 선택
    #   - 최신 Combined_data 파일 자동 선택
    #   - 스크립트나 배치 작업에 적합
    
    main(interactive=False)  # 자동 모드로 실행 (JSON 통합 테스트)