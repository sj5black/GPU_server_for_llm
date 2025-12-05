# Docker 가이드

GPU LLM 서버를 Docker로 실행하는 방법입니다.

## 사전 요구사항

1. **NVIDIA Docker 지원**
   ```bash
   # nvidia-docker2 설치 확인
   docker --version
   nvidia-docker --version
   
   # 또는 nvidia-container-toolkit
   docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
   ```

2. **Docker 및 Docker Compose 설치**
   ```bash
   docker --version
   docker-compose --version
   ```

## 실행 방법

### 방법 1: All-in-One (권장 - 간단함)

Ollama와 FastAPI 서버를 하나의 컨테이너에 함께 실행합니다.

```bash
# 이미지 빌드 및 실행
docker-compose -f docker-compose.all-in-one.yml up -d

# 로그 확인
docker-compose -f docker-compose.all-in-one.yml logs -f

# 중지
docker-compose -f docker-compose.all-in-one.yml down
```

### 방법 2: 분리된 서비스 (권장 - 확장성)

Ollama와 FastAPI 서버를 별도 컨테이너로 실행합니다.

```bash
# 이미지 빌드 및 실행
docker-compose up -d

# 로그 확인
docker-compose logs -f

# 특정 서비스 로그만 확인
docker-compose logs -f api-server
docker-compose logs -f ollama

# 중지
docker-compose down
```

### 방법 3: 직접 Docker 명령어 사용

```bash
# 이미지 빌드
docker build -f Dockerfile.all-in-one -t gpu-llm-server:latest .

# 컨테이너 실행
docker run -d \
  --name gpu-llm-server \
  --gpus all \
  -p 8001:8001 \
  -p 11434:11434 \
  -v ollama_data:/root/.ollama \
  -e OLLAMA_MODEL=exaone3.5:latest \
  gpu-llm-server:latest

# 로그 확인
docker logs -f gpu-llm-server

# 중지 및 삭제
docker stop gpu-llm-server
docker rm gpu-llm-server
```

## 환경 변수 설정

`.env` 파일을 생성하거나 환경 변수로 설정:

```env
# .env 파일
OLLAMA_MODEL=exaone3.5:latest
HOST=0.0.0.0
PORT=8001
```

또는 docker-compose.yml에서 직접 설정:

```yaml
environment:
  - OLLAMA_MODEL=exaone3.5:latest
  - HOST=0.0.0.0
  - PORT=8001
```

## 모델 관리

### 모델 다운로드

컨테이너 실행 후:

```bash
# All-in-One 방식
docker exec -it gpu-llm-server ollama pull exaone3.5:latest

# 분리된 서비스 방식
docker exec -it gpu-llm-ollama ollama pull exaone3.5:latest
```

### 모델 목록 확인

```bash
# All-in-One 방식
docker exec -it gpu-llm-server ollama list

# 분리된 서비스 방식
docker exec -it gpu-llm-ollama ollama list
```

## 볼륨 관리

모델 데이터는 Docker 볼륨에 저장됩니다:

```bash
# 볼륨 목록 확인
docker volume ls

# 볼륨 상세 정보
docker volume inspect gpu_server_for_llm_ollama_data

# 볼륨 삭제 (모델 데이터도 함께 삭제됨)
docker volume rm gpu_server_for_llm_ollama_data
```

## 이미지 저장 및 로드

### 이미지 저장

```bash
# 이미지 저장
docker save gpu-llm-server:latest | gzip > gpu-llm-server.tar.gz

# 또는 docker-compose로 빌드된 이미지
docker save gpu_server_for_llm_gpu-llm-server:latest | gzip > gpu-llm-server.tar.gz
```

### 이미지 로드 (서버 PC에 업로드 후)

```bash
# 압축 해제 및 로드
gunzip -c gpu-llm-server.tar.gz | docker load

# 또는 직접 로드
docker load < gpu-llm-server.tar.gz
```

## 트러블슈팅

### GPU가 인식되지 않는 경우

```bash
# GPU 확인
nvidia-smi

# Docker에서 GPU 테스트
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

### 포트 충돌

다른 포트 사용:

```yaml
ports:
  - "8002:8001"  # 호스트:컨테이너
  - "11435:11434"
```

### 메모리 부족

Ollama 모델 크기에 따라 충분한 메모리와 디스크 공간이 필요합니다.

```bash
# 디스크 사용량 확인
docker system df

# 볼륨 크기 확인
docker volume inspect gpu_server_for_llm_ollama_data
```

### 로그 확인

```bash
# 실시간 로그
docker-compose logs -f

# 특정 서비스 로그
docker logs -f gpu-llm-server

# 최근 100줄
docker logs --tail 100 gpu-llm-server
```

## 프로덕션 배포

### 1. 이미지 빌드 및 저장

```bash
# 이미지 빌드
docker-compose -f docker-compose.all-in-one.yml build

# 이미지 태그 지정
docker tag gpu_server_for_llm_gpu-llm-server:latest myregistry/gpu-llm-server:v1.0.0

# 이미지 저장
docker save myregistry/gpu-llm-server:v1.0.0 | gzip > gpu-llm-server-v1.0.0.tar.gz
```

### 2. 서버에 업로드 및 실행

```bash
# 서버에 파일 업로드 후
docker load < gpu-llm-server-v1.0.0.tar.gz

# 실행
docker run -d \
  --name gpu-llm-server \
  --gpus all \
  --restart unless-stopped \
  -p 8001:8001 \
  -p 11434:11434 \
  -v ollama_data:/root/.ollama \
  -e OLLAMA_MODEL=exaone3.5:latest \
  myregistry/gpu-llm-server:v1.0.0
```

## 참고사항

- **GPU 메모리**: 모델 크기에 따라 충분한 GPU 메모리가 필요합니다
- **디스크 공간**: 모델 파일은 볼륨에 저장되므로 충분한 디스크 공간이 필요합니다
- **네트워크**: Ollama와 FastAPI 서버 간 통신을 위해 네트워크 설정이 올바른지 확인하세요
- **보안**: 프로덕션 환경에서는 방화벽 및 보안 설정을 추가하세요

