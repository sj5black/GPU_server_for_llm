# 여러 Ollama 인스턴스 구성 가이드

GPU 서버에서 여러 개의 LLM API 서버를 동시에 실행하는 방법입니다.

## 📋 목차

- [개요](#개요)
- [단일 GPU에서 여러 모델](#단일-gpu에서-여러-모델)
- [여러 Ollama 인스턴스](#여러-ollama-인스턴스)
- [포트 구성](#포트-구성)
- [VM 서버 연결](#vm-서버-연결)

## 개요

### 사용 사례

1. **여러 모델 제공**
   - 인스턴스 1 (포트 8001): exaone3.5:latest
   - 인스턴스 2 (포트 8002): llama3.2:latest
   - 인스턴스 3 (포트 8003): gemma2:9b

2. **모델 버전 관리**
   - 인스턴스 1 (포트 8001): 프로덕션 모델
   - 인스턴스 2 (포트 8002): 테스트 모델

3. **부하 분산**
   - 인스턴스 1-3 (포트 8001-8003): 같은 모델, 다른 인스턴스

## 방법 1: 단일 Ollama + 여러 API 서버

### 구조

```
GPU 서버
├── Ollama (포트 11434) - 여러 모델 로드
├── LLM API Server 1 (포트 8001) - exaone3.5
├── LLM API Server 2 (포트 8002) - llama3.2
└── LLM API Server 3 (포트 8003) - gemma2
```

### 1. Ollama에 여러 모델 다운로드

```bash
# Ollama 서비스 시작
ollama serve &

# 여러 모델 다운로드
ollama pull exaone3.5:latest
ollama pull llama3.2:latest
ollama pull gemma2:9b

# 확인
ollama list
```

### 2. GPU 서버 인스턴스 복사

```bash
cd ~
mkdir -p qrchatbot-gpu

# 인스턴스 1 (exaone3.5)
cp -r gpu-server qrchatbot-gpu/instance1
cd qrchatbot-gpu/instance1

cat > .env << EOF
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=exaone3.5:latest
HOST=0.0.0.0
PORT=8001
EOF

# 인스턴스 2 (llama3.2)
cd ~
cp -r gpu-server qrchatbot-gpu/instance2
cd qrchatbot-gpu/instance2

cat > .env << EOF
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=llama3.2:latest
HOST=0.0.0.0
PORT=8002
EOF

# 인스턴스 3 (gemma2)
cd ~
cp -r gpu-server qrchatbot-gpu/instance3
cd qrchatbot-gpu/instance3

cat > .env << EOF
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=gemma2:9b
HOST=0.0.0.0
PORT=8003
EOF
```

### 3. 각 인스턴스 실행

```bash
# 터미널 1
cd ~/qrchatbot-gpu/instance1
python run.py

# 터미널 2
cd ~/qrchatbot-gpu/instance2
python run.py

# 터미널 3
cd ~/qrchatbot-gpu/instance3
python run.py
```

또는 백그라운드 실행:

```bash
cd ~/qrchatbot-gpu/instance1 && nohup python run.py > gpu-server-8001.log 2>&1 &
cd ~/qrchatbot-gpu/instance2 && nohup python run.py > gpu-server-8002.log 2>&1 &
cd ~/qrchatbot-gpu/instance3 && nohup python run.py > gpu-server-8003.log 2>&1 &
```

### 4. Systemd 서비스로 관리 (권장)

**인스턴스 1:**
```bash
sudo nano /etc/systemd/system/qrchatbot-gpu-8001.service
```

```ini
[Unit]
Description=QRChatBot GPU LLM Server - Instance 1 (exaone3.5)
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/home/your-username/qrchatbot-gpu/instance1
Environment="PATH=/home/your-username/qrchatbot-gpu/instance1/venv/bin"
ExecStart=/home/your-username/qrchatbot-gpu/instance1/venv/bin/python run.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**인스턴스 2:**
```bash
sudo nano /etc/systemd/system/qrchatbot-gpu-8002.service
```

```ini
[Unit]
Description=QRChatBot GPU LLM Server - Instance 2 (llama3.2)
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/home/your-username/qrchatbot-gpu/instance2
Environment="PATH=/home/your-username/qrchatbot-gpu/instance2/venv/bin"
ExecStart=/home/your-username/qrchatbot-gpu/instance2/venv/bin/python run.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**인스턴스 3:**
```bash
sudo nano /etc/systemd/system/qrchatbot-gpu-8003.service
```

```ini
[Unit]
Description=QRChatBot GPU LLM Server - Instance 3 (gemma2)
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/home/your-username/qrchatbot-gpu/instance3
Environment="PATH=/home/your-username/qrchatbot-gpu/instance3/venv/bin"
ExecStart=/home/your-username/qrchatbot-gpu/instance3/venv/bin/python run.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**서비스 시작:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable qrchatbot-gpu-8001 qrchatbot-gpu-8002 qrchatbot-gpu-8003
sudo systemctl start qrchatbot-gpu-8001 qrchatbot-gpu-8002 qrchatbot-gpu-8003

# 상태 확인
sudo systemctl status qrchatbot-gpu-8001
sudo systemctl status qrchatbot-gpu-8002
sudo systemctl status qrchatbot-gpu-8003
```

## 방법 2: 여러 Ollama 인스턴스

더 격리된 환경이 필요한 경우 각각 다른 Ollama 인스턴스 사용:

### 구조

```
GPU 서버
├── Ollama 1 (포트 11434) + LLM API 1 (포트 8001)
├── Ollama 2 (포트 11435) + LLM API 2 (포트 8002)
└── Ollama 3 (포트 11436) + LLM API 3 (포트 8003)
```

### 설정

```bash
# Ollama 1 (기본)
OLLAMA_HOST=127.0.0.1:11434 ollama serve &

# Ollama 2
OLLAMA_HOST=127.0.0.1:11435 ollama serve &

# Ollama 3
OLLAMA_HOST=127.0.0.1:11436 ollama serve &

# 각 Ollama에 모델 다운로드
OLLAMA_HOST=127.0.0.1:11434 ollama pull exaone3.5:latest
OLLAMA_HOST=127.0.0.1:11435 ollama pull llama3.2:latest
OLLAMA_HOST=127.0.0.1:11436 ollama pull gemma2:9b
```

각 LLM API 서버의 `.env`:

```bash
# instance1/.env
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=exaone3.5:latest
PORT=8001

# instance2/.env
OLLAMA_BASE_URL=http://127.0.0.1:11435
OLLAMA_MODEL=llama3.2:latest
PORT=8002

# instance3/.env
OLLAMA_BASE_URL=http://127.0.0.1:11436
OLLAMA_MODEL=gemma2:9b
PORT=8003
```

## 포트 구성 요약

### 권장 포트 할당

```
# Ollama 포트
11434 - Ollama 기본 인스턴스
11435 - Ollama 인스턴스 2 (선택사항)
11436 - Ollama 인스턴스 3 (선택사항)

# LLM API 서버 포트
8001  - LLM API Server 1 (exaone3.5)
8002  - LLM API Server 2 (llama3.2)
8003  - LLM API Server 3 (gemma2)
8004+ - 추가 인스턴스
```

### 방화벽 설정

```bash
# VM 서버 IP에서만 접근 허용
sudo ufw allow from <VM서버_IP> to any port 8001
sudo ufw allow from <VM서버_IP> to any port 8002
sudo ufw allow from <VM서버_IP> to any port 8003

# 또는 iptables
sudo iptables -A INPUT -p tcp -s <VM서버_IP> --dport 8001:8003 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8001:8003 -j DROP
```

## VM 서버 연결

### 방법 1: 환경 변수로 특정 인스턴스 선택

VM 서버의 `.env`:

```env
# 인스턴스 1 (exaone3.5) 사용
GPU_LLM_URL=http://GPU_SERVER_IP:8001

# 또는 인스턴스 2 (llama3.2) 사용
# GPU_LLM_URL=http://GPU_SERVER_IP:8002

# 또는 인스턴스 3 (gemma2) 사용
# GPU_LLM_URL=http://GPU_SERVER_IP:8003
```

### 방법 2: 동적으로 인스턴스 선택 (고급)

여러 VM 서버에서 각기 다른 모델 사용:

**VM 서버 1:**
```env
GPU_LLM_URL=http://GPU_SERVER_IP:8001  # exaone3.5
```

**VM 서버 2:**
```env
GPU_LLM_URL=http://GPU_SERVER_IP:8002  # llama3.2
```

### 방법 3: 로드 밸런서 사용 (최고급)

같은 모델의 여러 인스턴스를 로드 밸런싱:

```bash
# Nginx 로드 밸런서 설정
upstream llm_backend {
    server 127.0.0.1:8001;
    server 127.0.0.1:8002;
    server 127.0.0.1:8003;
}

server {
    listen 8000;
    location / {
        proxy_pass http://llm_backend;
    }
}
```

VM 서버:
```env
GPU_LLM_URL=http://GPU_SERVER_IP:8000  # 로드 밸런서
```

## 테스트

### 각 인스턴스 테스트

```bash
# 인스턴스 1 (포트 8001)
curl http://GPU_SERVER_IP:8001/health
curl -X POST http://GPU_SERVER_IP:8001/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"안녕하세요","temperature":0.7}'

# 인스턴스 2 (포트 8002)
curl http://GPU_SERVER_IP:8002/health
curl -X POST http://GPU_SERVER_IP:8002/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Hello","temperature":0.7}'

# 인스턴스 3 (포트 8003)
curl http://GPU_SERVER_IP:8003/health
curl -X POST http://GPU_SERVER_IP:8003/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"你好","temperature":0.7}'
```

## 모니터링

### 모든 인스턴스 상태 확인

```bash
# Systemd 서비스
sudo systemctl status qrchatbot-gpu-* --no-pager

# 프로세스
ps aux | grep "python run.py"

# 포트
sudo netstat -tulpn | grep -E ":(8001|8002|8003)"

# GPU 사용량
nvidia-smi
watch -n 1 nvidia-smi
```

### 로그 확인

```bash
# Systemd
sudo journalctl -u qrchatbot-gpu-8001 -f
sudo journalctl -u qrchatbot-gpu-8002 -f
sudo journalctl -u qrchatbot-gpu-8003 -f

# 직접 실행
tail -f ~/qrchatbot-gpu/instance1/gpu-server-8001.log
tail -f ~/qrchatbot-gpu/instance2/gpu-server-8002.log
tail -f ~/qrchatbot-gpu/instance3/gpu-server-8003.log
```

## 리소스 관리

### GPU 메모리 고려사항

**한 번에 로드할 수 있는 모델 수는 GPU 메모리에 따라 다릅니다:**

- **24GB VRAM (RTX 3090/4090):**
  - 7B 모델 2-3개 동시 가능
  - 또는 13B 모델 1개 + 7B 모델 1개

- **48GB VRAM (A6000):**
  - 7B 모델 4-6개
  - 또는 13B 모델 2-3개

- **80GB VRAM (A100):**
  - 7B 모델 8-10개
  - 또는 70B 모델 1개

### 모델 언로드

Ollama는 기본적으로 5분 동안 사용하지 않으면 모델을 언로드합니다.

```bash
# 즉시 언로드
curl http://localhost:11434/api/generate -d '{
  "model": "exaone3.5:latest",
  "keep_alive": 0
}'
```

## 문제 해결

### 포트 충돌

```bash
# 포트 사용 확인
sudo lsof -i :8001
sudo lsof -i :8002
sudo lsof -i :8003

# 프로세스 종료
sudo kill -9 <PID>
```

### GPU 메모리 부족

```bash
# 실행 중인 모델 확인
curl http://localhost:11434/api/ps

# 특정 모델 언로드
curl http://localhost:11434/api/generate -d '{
  "model": "model-name",
  "keep_alive": 0
}'
```

### 인스턴스 재시작

```bash
# 전체 재시작
sudo systemctl restart qrchatbot-gpu-8001 qrchatbot-gpu-8002 qrchatbot-gpu-8003

# 개별 재시작
sudo systemctl restart qrchatbot-gpu-8001
```

## 베스트 프랙티스

1. **모델 선택**: 작은 모델부터 시작 (7B 모델)
2. **모니터링**: GPU 메모리 사용량 지속 모니터링
3. **로드 밸런싱**: 같은 모델을 여러 인스턴스로 부하 분산
4. **자동 재시작**: Systemd로 서비스 관리
5. **로그 관리**: 로그 로테이션 설정

---

**작성일:** 2025-11-17  
**버전:** 1.0.0

