# GPU LLM Server - Dockerfile
# Ollama와 FastAPI 서버를 함께 실행하는 컨테이너

FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

# 환경 변수 설정
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV OLLAMA_HOST=0.0.0.0:11434

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 패키지 설치
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3.11 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Ollama 설치
RUN curl -fsSL https://ollama.com/install.sh | sh

# Python 의존성 설치
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# 애플리케이션 코드 복사
COPY main.py .
COPY run.py .

# Ollama 모델 저장 디렉토리 생성
RUN mkdir -p /root/.ollama

# 포트 노출
EXPOSE 8001 11434

# 시작 스크립트 생성
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Ollama 백그라운드 실행\n\
ollama serve &\n\
OLLAMA_PID=$!\n\
\n\
# Ollama가 시작될 때까지 대기\n\
echo "Ollama 시작 대기 중..."\n\
for i in {1..30}; do\n\
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then\n\
        echo "Ollama가 시작되었습니다"\n\
        break\n\
    fi\n\
    sleep 1\n\
done\n\
\n\
# 모델이 없으면 다운로드\n\
if ! ollama list | grep -q "${OLLAMA_MODEL:-exaone3.5:latest}"; then\n\
    echo "모델 다운로드 중: ${OLLAMA_MODEL:-exaone3.5:latest}"\n\
    ollama pull ${OLLAMA_MODEL:-exaone3.5:latest}\n\
fi\n\
\n\
# FastAPI 서버 실행\n\
echo "FastAPI 서버 시작 중..."\n\
exec python3 run.py\n\
' > /app/start.sh && chmod +x /app/start.sh

# 시작 스크립트 실행
CMD ["/app/start.sh"]

