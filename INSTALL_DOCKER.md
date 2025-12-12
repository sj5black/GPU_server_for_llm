# Docker 설치 가이드

로컬에서 Docker 이미지를 빌드하려면 Docker가 필요합니다.

## 방법 1: Dockerfile Build 방식 사용 (권장 - Docker 설치 불필요)

웹 인터페이스에서 "Dockerfile build" 방식을 사용하면 **로컬에 Docker가 필요 없습니다**!

```bash
# 소스 패키지 준비
./prepare-source-package.sh

# 생성된 gpu-llm-server-source.tar.gz 파일을 웹 인터페이스에 업로드
```

## 방법 2: Docker 설치 후 Tar 파일 생성

로컬에서 이미지를 빌드하고 tar 파일로 저장하려면 Docker를 설치해야 합니다.

### Ubuntu/Debian에 Docker 설치

```bash
# 1. 기존 Docker 제거 (있는 경우)
sudo apt-get remove docker docker-engine docker.io containerd runc

# 2. 필수 패키지 설치
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 3. Docker 공식 GPG 키 추가
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 4. Docker 저장소 추가
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Docker 설치
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Docker 그룹에 사용자 추가 (sudo 없이 실행)
sudo usermod -aG docker $USER

# 7. 새 그룹 권한 적용 (로그아웃 후 다시 로그인하거나)
newgrp docker

# 8. 설치 확인
docker --version
docker run hello-world
```

### 간단한 설치 (apt 사용)

```bash
# Docker.io 설치 (간단하지만 최신 버전이 아닐 수 있음)
sudo apt-get update
sudo apt-get install -y docker.io

# Docker 서비스 시작
sudo systemctl start docker
sudo systemctl enable docker

# 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER
newgrp docker

# 설치 확인
docker --version
```

### Snap으로 설치

```bash
sudo snap install docker

# 사용자 권한 설정
sudo addgroup --system docker
sudo adduser $USER docker
newgrp docker

# 설치 확인
docker --version
```

## 설치 후 이미지 빌드

Docker 설치가 완료되면:

```bash
# 이미지 빌드 및 tar 파일 생성
./build-and-export.sh
```

## 권장 방법

**Dockerfile Build 방식**을 사용하는 것을 권장합니다:
- ✅ 로컬에 Docker 설치 불필요
- ✅ 서버 측에서 최적화된 환경에서 빌드
- ✅ 더 빠르고 안정적

```bash
./prepare-source-package.sh
```

생성된 `gpu-llm-server-source.tar.gz` 파일을 웹 인터페이스에 업로드하세요!



