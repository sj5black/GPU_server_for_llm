# GPU 서버 분리 가이드

QR ChatBot 프로젝트를 **VM 서버**(웹/RAG)와 **GPU 서버**(LLM 추론)로 분리하는 가이드입니다.

## 📋 목차

- [개요](#개요)
- [아키텍처](#아키텍처)
- [GPU 서버 설정](#gpu-서버-설정)
- [VM 서버 설정](#vm-서버-설정)
- [테스트](#테스트)
- [문제 해결](#문제-해결)

## 개요

### 분리 전
```
단일 서버
├── FastAPI Backend (웹, RAG, 벡터 DB)
├── Ollama LLM (GPU 사용)
├── Express Proxy
└── Nginx
```

### 분리 후
```
VM 서버 (웹/RAG)                GPU 서버 (LLM)
├── FastAPI Backend          ← API 호출 → ├── LLM API Server
├── RAG Service                              ├── Ollama
├── 벡터 DB (LanceDB)                        └── GPU 활용
├── Express Proxy
└── Nginx
```

### 장점

- ✅ GPU 리소스 효율적 활용
- ✅ VM 서버와 GPU 서버 독립적 확장
- ✅ LLM 서버 장애 시 VM 서버는 정상 작동 (컨텍스트만 반환)
- ✅ 여러 VM 서버가 하나의 GPU 서버 공유 가능
- ✅ LLM 모델 변경 시 VM 서버 재시작 불필요

## 아키텍처

### 통신 흐름

```
사용자 요청
    ↓
Nginx (HTTPS)
    ↓
Express Proxy (포트 3000)
    ↓
FastAPI Backend (포트 8000)
    ↓
RAG Service (문서 검색)
    ↓
LLM Client ← HTTP → GPU Server (포트 11435)
                        ↓
                     Ollama (포트 11434)
                        ↓
                     LLM 추론
```

### API 엔드포인트

**GPU 서버 (포트 11435):**
- `GET /health` - 헬스 체크
- `GET /models` - 사용 가능한 모델 목록
- `POST /generate` - 텍스트 생성 (일반)
- `POST /generate_stream` - 텍스트 생성 (스트리밍)

**VM 서버:**
- 기존 모든 엔드포인트 유지
- RAG Service가 내부적으로 GPU 서버 호출

## GPU 서버 설정

### 1. GPU 서버에 프로젝트 복사

GPU 서버에는 `gpu-server` 폴더만 필요합니다:

```bash
# GPU 서버에서
mkdir -p ~/qrchatbot-gpu
cd ~/qrchatbot-gpu

# gpu-server 폴더 복사 (또는 git clone 후 해당 폴더만 사용)
```

### 2. 의존성 설치

```bash
cd ~/qrchatbot-gpu/gpu-server

# Python 가상환경 생성 (선택사항)
python3 -m venv venv
source venv/bin/activate

# 패키지 설치
pip install -r requirements.txt
```

### 3. Ollama 설치 및 모델 다운로드

```bash
# Ollama 설치 (Linux)
curl -fsSL https://ollama.com/install.sh | sh

# Ollama 서비스 시작
ollama serve &

# 모델 다운로드
ollama pull exaone3.5:latest
# 또는 다른 모델: ollama pull llama3.2:latest
```

### 4. 환경 변수 설정

```bash
# gpu-server 디렉토리에 .env 파일 생성
cat > .env << EOF
# Ollama 설정
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=exaone3.5:latest

# 서버 설정
HOST=0.0.0.0
PORT=11435
EOF
```

### 5. GPU 서버 시작

```bash
# 직접 실행
python run.py

# 또는 백그라운드 실행
nohup python run.py > gpu-server.log 2>&1 &

# 또는 systemd 서비스로 실행 (권장)
```

#### Systemd 서비스 파일 (선택사항)

```bash
sudo nano /etc/systemd/system/qrchatbot-gpu.service
```

```ini
[Unit]
Description=QRChatBot GPU LLM Server
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/home/your-username/qrchatbot-gpu/gpu-server
Environment="PATH=/home/your-username/qrchatbot-gpu/gpu-server/venv/bin"
ExecStart=/home/your-username/qrchatbot-gpu/gpu-server/venv/bin/python run.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable qrchatbot-gpu
sudo systemctl start qrchatbot-gpu
sudo systemctl status qrchatbot-gpu
```

### 6. 방화벽 설정

GPU 서버의 포트 11435를 VM 서버 IP에서만 접근 가능하도록 설정:

```bash
# UFW 사용 시
sudo ufw allow from <VM서버_IP> to any port 11435

# iptables 사용 시
sudo iptables -A INPUT -p tcp -s <VM서버_IP> --dport 11435 -j ACCEPT
```

### 7. 테스트

```bash
# GPU 서버에서 로컬 테스트
curl http://localhost:11435/health

# 예상 출력:
# {"status":"healthy","ollama_status":"connected",...}

# 텍스트 생성 테스트
curl -X POST http://localhost:11435/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt":"안녕하세요. 자기소개를 해주세요.","temperature":0.7}'
```

## VM 서버 설정

### 1. RAG Service 변경

기존 `rag_service.py`를 새로운 GPU 서버용 버전으로 교체:

```bash
cd /home/mymeta_corp/QRchatbot/QRChatBot/app/services

# 기존 파일 백업
cp rag_service.py rag_service.py.backup

# 새 버전으로 교체
cp rag_service_gpu.py rag_service.py
```

또는 심볼릭 링크 생성:

```bash
cd /home/mymeta_corp/QRchatbot/QRChatBot/app/services
rm rag_service.py
ln -s rag_service_gpu.py rag_service.py
```

### 2. 환경 변수 설정

VM 서버의 `.env` 파일에 GPU 서버 URL 추가:

```bash
cd /home/mymeta_corp/QRchatbot/QRChatBot

# .env 파일 편집
nano .env
```

다음 내용 추가:

```env
# GPU LLM Server 설정
GPU_LLM_URL=http://<GPU서버_IP>:11435

# 기존 설정은 그대로 유지
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=exaone3.5:latest
```

**중요:** `GPU_LLM_URL`을 GPU 서버의 실제 IP 주소로 변경하세요.

### 3. VM 서버 재시작

```bash
cd /home/mymeta_corp/QRchatbot/QRChatBot
sudo ./restart-all.sh
```

### 4. 연결 확인

```bash
# VM 서버에서 GPU 서버 연결 테스트
curl http://<GPU서버_IP>:11435/health

# FastAPI 로그 확인
tail -f logs/backend.log

# 다음 메시지가 보여야 함:
# [OK] GPU LLM Client 초기화 완료: http://<GPU서버_IP>:11435
```

## 테스트

### 1. GPU 서버 단독 테스트

```bash
# 헬스 체크
curl http://<GPU서버_IP>:11435/health

# 모델 목록
curl http://<GPU서버_IP>:11435/models

# 텍스트 생성 (일반)
curl -X POST http://<GPU서버_IP>:11435/generate \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "한국의 수도는 어디인가요?",
    "temperature": 0.7
  }'

# 텍스트 생성 (스트리밍)
curl -X POST http://<GPU서버_IP>:11435/generate_stream \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "한국에 대해 간단히 설명해주세요.",
    "temperature": 0.7
  }'
```

### 2. 전체 시스템 테스트

```bash
# VM 서버를 통한 챗봇 테스트
# 1. 브라우저에서 https://your-vm-server 접속
# 2. 로그인
# 3. 폴더 생성 및 문서 업로드
# 4. 챗봇에 질문하기
# 5. 스트리밍 응답 확인
```

### 3. 로그 확인

**GPU 서버:**
```bash
# systemd 사용 시
sudo journalctl -u qrchatbot-gpu -f

# 직접 실행 시
tail -f gpu-server.log
```

**VM 서버:**
```bash
tail -f logs/backend.log
```

## 문제 해결

### GPU 서버에 연결할 수 없음

**증상:**
```
[WARNING] LLM Client 초기화 실패
AI 서버에 연결할 수 없습니다
```

**해결:**

1. **GPU 서버 상태 확인:**
   ```bash
   # GPU 서버에서
   curl http://localhost:11435/health
   ```

2. **방화벽 확인:**
   ```bash
   # GPU 서버에서
   sudo ufw status
   # 포트 11435가 VM 서버 IP에서 허용되어 있는지 확인
   ```

3. **네트워크 연결 확인:**
   ```bash
   # VM 서버에서
   telnet <GPU서버_IP> 11435
   # 또는
   nc -zv <GPU서버_IP> 11435
   ```

4. **GPU 서버 로그 확인:**
   ```bash
   sudo journalctl -u qrchatbot-gpu -n 100
   ```

### Ollama 연결 오류

**증상:**
```
{"status":"unhealthy","ollama_status":"disconnected"}
```

**해결:**

```bash
# GPU 서버에서 Ollama 상태 확인
ollama list

# Ollama 서비스 재시작
pkill ollama
ollama serve &

# 모델 다시 다운로드
ollama pull exaone3.5:latest
```

### GPU 메모리 부족

**증상:**
```
CUDA out of memory
```

**해결:**

1. **더 작은 모델 사용:**
   ```bash
   ollama pull llama3.2:latest  # 더 작은 모델
   ```

2. **양자화된 모델 사용:**
   ```bash
   ollama pull exaone3.5:8bit
   ```

3. **동시 요청 수 제한:**
   GPU 서버의 `main.py`에서 동시 요청 수 제한 추가

### 응답이 너무 느림

**증상:**
LLM 응답이 10초 이상 걸림

**해결:**

1. **GPU 사용 확인:**
   ```bash
   nvidia-smi
   ```

2. **모델 캐시 확인:**
   첫 요청은 모델 로딩으로 느릴 수 있음 (정상)

3. **네트워크 지연 확인:**
   ```bash
   ping <GPU서버_IP>
   ```

### VM 서버가 GPU 서버 없이도 작동하게 하기

GPU 서버 장애 시에도 VM 서버는 계속 작동합니다:
- 문서 검색은 정상 작동
- LLM 응답 대신 검색된 문서 내용만 반환
- "AI 서버 연결 문제" 메시지 표시

## 성능 최적화

### GPU 서버

1. **배치 처리:**
   - 여러 요청을 배치로 처리 (향후 구현)

2. **모델 캐싱:**
   - Ollama가 자동으로 모델을 메모리에 캐싱

3. **양자화:**
   ```bash
   ollama pull exaone3.5:8bit  # 메모리 사용량 감소
   ```

### VM 서버

1. **연결 풀:**
   - `llm_client.py`가 이미 httpx 타임아웃 최적화 적용

2. **캐싱:**
   - RAG Service의 벡터스토어 캐싱 (5분 TTL)

## 모니터링

### GPU 서버 모니터링

```bash
# GPU 사용량
watch -n 1 nvidia-smi

# 서비스 상태
sudo systemctl status qrchatbot-gpu

# 로그 실시간 확인
sudo journalctl -u qrchatbot-gpu -f

# 프로세스 확인
ps aux | grep "python run.py"
```

### VM 서버 모니터링

```bash
# 서비스 상태
sudo ./restart-all.sh

# 로그 확인
tail -f logs/backend.log

# GPU 서버 연결 상태
curl http://<GPU서버_IP>:11435/health
```

## 롤백 (원래 구조로 되돌리기)

GPU 서버 분리 전 상태로 돌아가려면:

```bash
cd /home/mymeta_corp/QRchatbot/QRChatBot/app/services

# 백업에서 복원
cp rag_service.py.backup rag_service.py

# .env에서 GPU_LLM_URL 제거
nano ../.env  # GPU_LLM_URL 라인 삭제

# VM 서버 재시작
cd /home/mymeta_corp/QRchatbot/QRChatBot
sudo ./restart-all.sh
```

## 추가 정보

### 프로덕션 체크리스트

- [ ] GPU 서버 방화벽 설정 완료
- [ ] GPU 서버 systemd 서비스 등록
- [ ] VM 서버 환경 변수 설정
- [ ] GPU 서버 모니터링 설정
- [ ] 백업 계획 수립
- [ ] 장애 복구 계획 수립
- [ ] 부하 테스트 완료

### 보안 권장사항

1. **API 키 인증 (선택사항):**
   ```env
   # GPU 서버 .env
   API_KEY=your-secret-key
   ```

2. **VPN 또는 Private Network:**
   - GPU 서버를 퍼블릭 인터넷에 노출하지 마세요
   - VPN 또는 클라우드 Private Network 사용 권장

3. **TLS/SSL:**
   - 프로덕션 환경에서는 GPU 서버에도 SSL 적용 고려

## 도움말

문제가 지속되면 다음을 확인하세요:

1. GPU 서버 로그
2. VM 서버 로그
3. 네트워크 연결
4. 방화벽 설정
5. 환경 변수 설정

---

**작성일:** 2025-11-17  
**버전:** 1.0.0  
**상태:** 프로덕션 준비 완료
