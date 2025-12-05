# Docker 이미지 업로드 가이드

웹 인터페이스를 통해 Docker 이미지를 업로드하는 방법입니다.

## 방법 1: Tar 파일로 업로드 (권장)

### 1단계: Docker 이미지 빌드 및 Tar 파일 생성

```bash
# 자동 스크립트 실행
./build-and-export.sh
```

또는 수동으로:

```bash
# 1. 이미지 빌드
docker build -f Dockerfile.all-in-one -t gpu-llm-server:latest .

# 2. Tar 파일로 저장
docker save gpu-llm-server:latest -o gpu-llm-server.tar
```

### 2단계: 웹 인터페이스에서 업로드

1. **"Create Docker Image"** 버튼 클릭
2. **Docker Image Name** 입력
   - 예: `gpu-llm-server` 또는 `gpu-llm-server-v1.0`
   - 50자 이내
3. **Docker Image Description** (선택사항)
   - 예: "GPU LLM Server with Ollama and FastAPI"
4. **Docker Image Created Type** 선택
   - **"Tar"** 선택 (라디오 버튼)
5. **Tar 파일 업로드**
   - 생성된 `gpu-llm-server.tar` 파일 선택
6. **Release Type** 선택
   - **"Global"** 또는 **"Workspace"**
7. **"Create"** 버튼 클릭

## 방법 2: Dockerfile Build 방식

웹 인터페이스에서 직접 빌드하는 방법입니다.

### 1단계: 프로젝트 파일 준비

필요한 파일들:
- `Dockerfile.all-in-one`
- `main.py`
- `run.py`
- `requirements.txt`
- 기타 필요한 파일들

이 파일들을 압축 파일(zip 또는 tar.gz)로 만들어야 합니다.

```bash
# 프로젝트 파일 압축
tar -czf gpu-llm-server-source.tar.gz \
  Dockerfile.all-in-one \
  main.py \
  run.py \
  requirements.txt \
  .dockerignore
```

### 2단계: 웹 인터페이스에서 빌드

1. **"Create Docker Image"** 버튼 클릭
2. **Docker Image Name** 입력
3. **Docker Image Created Type** 선택
   - **"Dockerfile build"** 선택
4. **소스 파일 업로드**
   - 압축된 소스 파일 업로드
   - Dockerfile 경로 지정 (예: `Dockerfile.all-in-one`)
5. **Release Type** 선택
6. **"Create"** 버튼 클릭

## 방법 3: Pull 방식 (이미지가 레지스트리에 있는 경우)

Docker Hub나 다른 레지스트리에 이미지를 푸시한 경우:

1. **"Create Docker Image"** 버튼 클릭
2. **Docker Image Name** 입력
3. **Docker Image Created Type** 선택
   - **"Pull"** 선택
4. **Pull URL** 입력
   - 예: `docker.io/your-username/gpu-llm-server:latest`
   - 또는: `registry.example.com/gpu-llm-server:latest`
5. **Release Type** 선택
6. **"Create"** 버튼 클릭

## 파일 크기 제한 확인

Docker 이미지는 크기가 클 수 있습니다. 웹 인터페이스의 파일 크기 제한을 확인하세요.

- 일반적으로 tar 파일은 **압축 없이** 업로드하는 것이 좋습니다
- 필요시 `gzip`으로 압축할 수 있지만, 웹 인터페이스가 자동으로 압축 해제를 지원하는지 확인하세요

## 업로드 후 확인

1. **Docker Images** 목록에서 업로드한 이미지 확인
2. **Status**가 "Available"인지 확인
3. **Log** 링크를 클릭하여 빌드 로그 확인 (오류가 있는 경우)

## 트러블슈팅

### 이미지가 너무 큰 경우

```bash
# 불필요한 레이어 제거
docker image prune -a

# 멀티스테이지 빌드 사용 (Dockerfile 최적화)
# 또는 .dockerignore로 불필요한 파일 제외
```

### 업로드 실패 시

1. **로그 확인**: 웹 인터페이스의 "Log" 링크 클릭
2. **파일 무결성 확인**: 
   ```bash
   # Tar 파일 검증
   docker load -i gpu-llm-server.tar
   ```
3. **네트워크 확인**: 파일 크기가 네트워크 제한을 초과하지 않는지 확인

### 이미지 이름 규칙

- 50자 이내
- 영문자, 숫자, 하이픈(-), 언더스코어(_) 사용 가능
- 예: `gpu-llm-server`, `gpu-llm-server-v1.0`, `gpu_llm_server`

## 권장 워크플로우

1. **로컬에서 테스트**
   ```bash
   docker build -f Dockerfile.all-in-one -t gpu-llm-server:latest .
   docker run --gpus all -p 8001:8001 gpu-llm-server:latest
   ```

2. **이미지 저장**
   ```bash
   ./build-and-export.sh
   ```

3. **웹 인터페이스에 업로드**
   - Tar 방식 선택
   - `gpu-llm-server.tar` 파일 업로드

4. **배포 및 실행**
   - 업로드된 이미지로 컨테이너 생성 및 실행

## 참고사항

- **모델 파일**: Ollama 모델은 컨테이너 실행 시 다운로드되므로, 이미지에 포함되지 않습니다
- **볼륨 마운트**: 실행 시 모델 데이터를 저장할 볼륨을 마운트해야 합니다
- **GPU 설정**: 실행 시 GPU를 사용할 수 있도록 설정해야 합니다
- **환경 변수**: 실행 시 필요한 환경 변수를 설정해야 합니다

