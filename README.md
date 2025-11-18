# GPU LLM Server

Ollama LLM 추론 전용 서버 - QR ChatBot의 GPU 서버 컴포넌트

## 빠른 시작

### 1. 설치

```bash
# 의존성 설치
pip install -r requirements.txt

# Ollama 설치 (Linux)
curl -fsSL https://ollama.com/install.sh | sh

# 모델 다운로드
ollama pull exaone3.5:latest
```

### 2. 환경 변수 설정

`.env` 파일 생성:

```env
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=exaone3.5:latest
HOST=0.0.0.0
PORT=11435
```

### 3. 실행

```bash
# 직접 실행
python run.py

# 또는 백그라운드
nohup python run.py > gpu-server.log 2>&1 &
```

### 4. 테스트

```bash
curl http://localhost:11435/health
```

## API 엔드포인트

- `GET /` - 서버 정보
- `GET /health` - 헬스 체크
- `GET /models` - 모델 목록
- `POST /generate` - 텍스트 생성
- `POST /generate_stream` - 스트리밍 생성

## 자세한 문서

전체 가이드는 [GPU_SERVER_SETUP.md](../GPU_SERVER_SETUP.md)를 참조하세요.

## 구조

```
gpu-server/
├── main.py           # FastAPI 서버
├── run.py            # 실행 스크립트
├── requirements.txt  # 의존성
├── env.example       # 환경 변수 예시
└── README.md         # 이 파일
```

## 포트

- **8001**: GPU LLM API 서버 (기본, 변경 가능)
- **11434**: Ollama 서버 (내부)

## 여러 인스턴스 실행

여러 모델을 동시에 서빙하려면 [MULTI_INSTANCE_GUIDE.md](MULTI_INSTANCE_GUIDE.md)를 참조하세요.

