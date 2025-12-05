#!/bin/bash
###############################################################################
# Docker 이미지 빌드 및 Tar 파일로 내보내기
# 웹 인터페이스에서 "Tar" 방식으로 업로드할 수 있도록 이미지를 tar 파일로 저장
###############################################################################

set -e

# 색상 설정
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 설정
IMAGE_NAME="gpu-llm-server"
IMAGE_TAG="latest"
OUTPUT_FILE="gpu-llm-server.tar"
COMPRESSED_FILE="${OUTPUT_FILE}.gz"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GPU LLM Server - Docker 이미지 빌드 및 내보내기${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. Docker 이미지 빌드
echo -e "${YELLOW}[1/3] Docker 이미지 빌드 중...${NC}"
docker build -f Dockerfile.all-in-one -t ${IMAGE_NAME}:${IMAGE_TAG} .

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 이미지 빌드 실패${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 이미지 빌드 완료${NC}"
echo ""

# 2. 이미지 정보 확인
echo -e "${YELLOW}[2/3] 이미지 정보 확인${NC}"
docker images ${IMAGE_NAME}:${IMAGE_TAG}
echo ""

# 3. Tar 파일로 저장
echo -e "${YELLOW}[3/3] Tar 파일로 저장 중...${NC}"
echo "이 작업은 시간이 걸릴 수 있습니다..."

# 압축 없이 저장 (웹 인터페이스에서 자동 압축 해제 가능)
docker save ${IMAGE_NAME}:${IMAGE_TAG} -o ${OUTPUT_FILE}

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Tar 파일 저장 실패${NC}"
    exit 1
fi

# 파일 크기 확인
FILE_SIZE=$(du -h ${OUTPUT_FILE} | cut -f1)
echo -e "${GREEN}✓ Tar 파일 저장 완료${NC}"
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
echo "  3. 'Docker Image Created Type'에서 'Tar' 선택"
echo "  4. 생성된 ${OUTPUT_FILE} 파일 업로드"
echo ""
echo "선택사항: 압축 파일로 저장하려면 다음 명령어 실행:"
echo "  gzip ${OUTPUT_FILE}"
echo "  (압축 후: ${COMPRESSED_FILE})"
echo ""

