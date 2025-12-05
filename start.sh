#!/bin/bash
###############################################################################
# GPU LLM Server - 백그라운드 실행 스크립트
# 사용법: ./start.sh [start|stop|restart|status]
###############################################################################

# 스크립트 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 설정
PID_FILE="$SCRIPT_DIR/server.pid"
LOG_FILE="$SCRIPT_DIR/server.log"
PYTHON_SCRIPT="run.py"

# 색상 설정
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

###############################################################################
# 함수 정의
###############################################################################

# 서버 시작
start_server() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${YELLOW}[경고]${NC} 서버가 이미 실행 중입니다 (PID: $PID)"
            return 1
        else
            echo -e "${YELLOW}[정보]${NC} 이전 PID 파일 삭제 중..."
            rm -f "$PID_FILE"
        fi
    fi
    
    echo -e "${GREEN}[시작]${NC} GPU LLM Server 시작 중..."
    echo "로그 파일: $LOG_FILE"
    
    # nohup으로 백그라운드 실행
    nohup python3 "$PYTHON_SCRIPT" > "$LOG_FILE" 2>&1 &
    
    # PID 저장
    echo $! > "$PID_FILE"
    
    # 잠시 대기 후 실행 확인
    sleep 2
    
    if ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
        echo -e "${GREEN}[성공]${NC} 서버가 성공적으로 시작되었습니다"
        echo "PID: $(cat $PID_FILE)"
        echo ""
        echo "로그 확인: tail -f $LOG_FILE"
        echo "서버 중지: ./start.sh stop"
    else
        echo -e "${RED}[실패]${NC} 서버 시작에 실패했습니다"
        echo "로그를 확인하세요: cat $LOG_FILE"
        rm -f "$PID_FILE"
        return 1
    fi
}

# 서버 정지
stop_server() {
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${YELLOW}[경고]${NC} PID 파일이 없습니다. 서버가 실행 중이 아닙니다."
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    
    if ps -p "$PID" > /dev/null 2>&1; then
        echo -e "${YELLOW}[중지]${NC} 서버 종료 중... (PID: $PID)"
        kill "$PID"
        
        # 최대 10초 대기
        for i in {1..10}; do
            if ! ps -p "$PID" > /dev/null 2>&1; then
                break
            fi
            sleep 1
        done
        
        # 강제 종료가 필요한 경우
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${RED}[강제종료]${NC} 정상 종료되지 않아 강제 종료합니다..."
            kill -9 "$PID"
            sleep 1
        fi
        
        rm -f "$PID_FILE"
        echo -e "${GREEN}[성공]${NC} 서버가 종료되었습니다"
    else
        echo -e "${YELLOW}[경고]${NC} PID $PID의 프로세스가 실행 중이 아닙니다"
        rm -f "$PID_FILE"
    fi
}

# 서버 상태 확인
status_server() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${GREEN}[실행 중]${NC} GPU LLM Server"
            echo "PID: $PID"
            echo "메모리 사용량:"
            ps -p "$PID" -o pid,ppid,%cpu,%mem,cmd
            echo ""
            echo "로그 확인: tail -f $LOG_FILE"
        else
            echo -e "${RED}[중지됨]${NC} 서버가 실행 중이 아닙니다"
            rm -f "$PID_FILE"
        fi
    else
        echo -e "${RED}[중지됨]${NC} 서버가 실행 중이 아닙니다"
    fi
}

# 서버 재시작
restart_server() {
    echo -e "${YELLOW}[재시작]${NC} 서버 재시작 중..."
    stop_server
    sleep 2
    start_server
}

###############################################################################
# 메인 로직
###############################################################################

case "${1:-start}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        status_server
        ;;
    *)
        echo "사용법: $0 {start|stop|restart|status}"
        echo ""
        echo "  start   - 서버 시작"
        echo "  stop    - 서버 중지"
        echo "  restart - 서버 재시작"
        echo "  status  - 서버 상태 확인"
        exit 1
        ;;
esac

exit 0

