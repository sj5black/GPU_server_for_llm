#!/bin/bash
###############################################################################
# Dockerfile Build 방식용 소스 패키지 준비
# 웹 인터페이스에서 "Dockerfile build" 방식으로 업로드할 수 있도록
# 필요한 파일들을 압축 파일로 만듭니다
# (로컬에 Docker가 필요 없습니다!)
###############################################################################

set -e

# 색상 설정
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 설정
PACKAGE_NAME="gpu-llm-server-source"
OUTPUT_FILE="${PACKAGE_NAME}.tar.gz"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GPU LLM Server - 소스 패키지 준비${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
echo -e "${YELLOW}[1/3] 임시 디렉토리 생성: ${TEMP_DIR}${NC}"

# 필요한 파일 복사
echo -e "${YELLOW}[2/3] 필요한 파일 복사 중...${NC}"

# 필수 파일들
cp Dockerfile.all-in-one "${TEMP_DIR}/Dockerfile"
cp main.py "${TEMP_DIR}/"
cp run.py "${TEMP_DIR}/"
cp requirements.txt "${TEMP_DIR}/"

# .dockerignore가 있으면 복사
if [ -f .dockerignore ]; then
    cp .dockerignore "${TEMP_DIR}/"
    echo "  ✓ .dockerignore 복사"
fi

# 파일 목록 출력
echo ""
echo "포함된 파일:"
ls -lh "${TEMP_DIR}/"
echo ""

# 압축 파일 생성
echo -e "${YELLOW}[3/3] 압축 파일 생성 중...${NC}"
cd "${TEMP_DIR}"
tar -czf "${OLDPWD}/${OUTPUT_FILE}" .

# 임시 디렉토리 정리
cd "${OLDPWD}"
rm -rf "${TEMP_DIR}"

# 파일 크기 확인
FILE_SIZE=$(du -h "${OUTPUT_FILE}" | cut -f1)

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}완료!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "파일 정보:"
echo "  - 파일명: ${OUTPUT_FILE}"
echo "  - 크기: ${FILE_SIZE}"
echo "  - 위치: $(pwd)/${OUTPUT_FILE}"
echo ""
echo "다음 단계:"
echo "  1. 웹 인터페이스에서 'Create Docker Image' 클릭"
echo "  2. 'Docker Image Name' 입력 (예: gpu-llm-server)"
echo "  3. 'Docker Image Created Type'에서 'Dockerfile build' 선택"
echo "  4. 생성된 ${OUTPUT_FILE} 파일 업로드"
echo "  5. Dockerfile 경로: 'Dockerfile' (또는 웹 인터페이스에서 자동 감지)"
echo ""
echo "참고: 이 방법은 로컬에 Docker가 필요 없습니다!"
echo "      서버 측에서 자동으로 빌드됩니다."
echo ""



