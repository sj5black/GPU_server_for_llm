#!/usr/bin/env python3
"""
GPU Server 실행 스크립트
"""

import uvicorn
import os

def strtobool(val: str) -> bool:
    """간단한 truthy 문자열 판별"""
    return val.lower() in {"1", "true", "t", "yes", "y", "on"}


if __name__ == "__main__":
    # 환경 변수에서 설정 읽기
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8001"))
    reload = strtobool(os.getenv("UVICORN_RELOAD", "false"))
    
    print(f"GPU LLM Server 시작: {host}:{port}")
    print(f"Reload 모드: {reload}")
    
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=reload,
        log_level="info"
    )

