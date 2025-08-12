# 성능 최적화 스크립트
# 작성일: 2025-01-12

cat("========== R 성능 최적화 설정 ==========\n")

# 메모리 최적화
options(scipen = 999)  # 과학적 표기법 비활성화
options(max.print = 1000)  # 출력 제한
options(width = 120)  # 출력 너비 제한

# 타임아웃 설정 (1시간)
options(timeout = 3600)
cat("✅ 타임아웃을 1시간으로 설정\n")

# 메모리 정리
if (exists("gc")) {
  before_gc <- gc()
  cat("메모리 정리 전:\n")
  print(before_gc)
  
  # 강제 가비지 컬렉션
  for(i in 1:3) {
    gc(verbose = FALSE)
  }
  
  after_gc <- gc()
  cat("메모리 정리 후:\n")
  print(after_gc)
}

# 병렬 처리 최적화
cat("\n========== 병렬 처리 설정 확인 ==========\n")
available_cores <- parallel::detectCores()
recommended_cores <- max(1, available_cores - 1)  # 시스템 안정성을 위해 1개 코어 예약

cat(sprintf("전체 코어 수: %d개\n", available_cores))
cat(sprintf("권장 사용 코어: %d개\n", recommended_cores))

# 현재 실행 중인 프로세스 확인
if (.Platform$OS.type == "windows") {
  cat("\n현재 R 프로세스 메모리 사용량:\n")
  system("tasklist /FI \"IMAGENAME eq Rscript.exe\" /FO CSV", intern = FALSE)
}

cat("\n========== 최적화 권장사항 ==========\n")
cat("1. 데이터 크기 축소: 필요한 컬럼만 선택\n")
cat("2. 배치 처리: 전체 데이터를 작은 단위로 나누어 처리\n")
cat("3. 메모리 정리: 중간 결과물 즉시 삭제\n")
cat("4. 병렬 처리 제한: 과도한 병렬 처리 방지\n")

cat("\n========== 설정 완료 ==========\n")