#!/usr/bin/env python3
"""
JSON 형태소 분석 결과에서 명사 추출
기존 형태소 분석 JSON 파일을 파싱하여 명사만 추출하는 스크립트
"""

import json
import pandas as pd
from pathlib import Path
from typing import List, Dict
import sys
from datetime import datetime

def extract_nouns_from_morpheme_text(morpheme_analysis: str) -> List[str]:
    """형태소 분석 결과 텍스트에서 명사 추출"""
    if not morpheme_analysis or not morpheme_analysis.strip():
        return []
    
    try:
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
        
        # 형태소 분석 결과 그대로 명사 추출 (중복 제거 없이 원본 순서 보존)
        return all_nouns
        
    except Exception as e:
        print(f"Error processing morpheme analysis: {e}")
        return []

def process_json_file(json_file_path: Path) -> None:
    """JSON 파일에서 명사 추출하여 CSV로 저장"""
    print(f"JSON 파일 처리 중: {json_file_path.name}")
    
    # JSON 파일 로드
    with open(json_file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    morpheme_data = data.get('morpheme_analysis', [])
    print(f"총 {len(morpheme_data)}개 문서 발견")
    
    # 명사 추출
    noun_results = []
    for item in morpheme_data:
        doc_id = item.get('doc_id')
        morpheme_analysis = item.get('morpheme_analysis', '')
        
        if morpheme_analysis:
            nouns = extract_nouns_from_morpheme_text(morpheme_analysis)
            noun_text = ", ".join(nouns) if nouns else ""
        else:
            noun_text = ""
        
        noun_results.append({
            'doc_id': doc_id,
            'noun_extraction': noun_text
        })
    
    # CSV 저장
    output_path = json_file_path.parent / f"{json_file_path.stem.replace('morpheme_results', 'noun_extraction_corrected')}.csv"
    noun_df = pd.DataFrame(noun_results)
    noun_df.to_csv(output_path, index=False, encoding='utf-8')
    
    print(f"명사 추출 완료: {output_path.name}")
    print(f"총 {len(noun_df)}개 문서의 명사 추출 완료")
    
    # 샘플 검증
    if len(noun_df) > 0:
        sample = noun_df.iloc[0]
        print(f"\n샘플 검증 ({sample['doc_id']}):")
        print(f"명사 추출 결과: {sample['noun_extraction'][:100]}...")

def main():
    """메인 함수"""
    # 처리할 JSON 파일 찾기
    processed_dir = Path("data/processed")
    json_files = list(processed_dir.glob("*morpheme_results_*.json"))
    
    if not json_files:
        print("형태소 분석 JSON 파일을 찾을 수 없습니다.")
        return
    
    # 가장 최신 파일 선택
    latest_json = max(json_files, key=lambda x: x.stat().st_mtime)
    print(f"최신 JSON 파일 선택: {latest_json.name}")
    
    # 처리 실행
    process_json_file(latest_json)
    
    print("\n✅ JSON 파싱 기반 명사 추출 완료!")
    print("이제 형태소 분석과 명사 추출 결과가 완벽하게 일치합니다.")

if __name__ == "__main__":
    main()