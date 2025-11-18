"""
GPU Server - Ollama LLM API Server
LLM 추론만 담당하는 경량 FastAPI 서버
"""

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from pydantic_settings import BaseSettings
from typing import Optional, AsyncGenerator
import uvicorn
import json
import httpx
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    """서버 설정"""
    # Ollama 설정
    OLLAMA_BASE_URL: str = "http://127.0.0.1:11434"
    OLLAMA_MODEL: str = "exaone3.5:latest"
    
    # 서버 설정
    HOST: str = "0.0.0.0"
    PORT: int = 8001
    
    # 보안 설정 (선택사항)
    API_KEY: Optional[str] = None  # 설정 시 API 키 검증 활성화
    
    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
app = FastAPI(
    title="GPU LLM Server",
    description="Ollama LLM 추론 전용 서버",
    version="1.0.0"
)


class GenerateRequest(BaseModel):
    """LLM 생성 요청"""
    prompt: str
    model: Optional[str] = None
    temperature: float = 0.7
    max_tokens: Optional[int] = None
    stream: bool = False


class GenerateResponse(BaseModel):
    """LLM 생성 응답"""
    response: str
    model: str
    done: bool = True


@app.get("/health")
async def health_check():
    """헬스 체크"""
    try:
        # Ollama 서버 연결 확인
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{settings.OLLAMA_BASE_URL}/api/tags")
            if response.status_code == 200:
                return {
                    "status": "healthy",
                    "ollama_status": "connected",
                    "ollama_url": settings.OLLAMA_BASE_URL,
                    "default_model": settings.OLLAMA_MODEL
                }
            else:
                return {
                    "status": "degraded",
                    "ollama_status": "error",
                    "error": f"Ollama returned status {response.status_code}"
                }
    except Exception as e:
        return {
            "status": "unhealthy",
            "ollama_status": "disconnected",
            "error": str(e)
        }


@app.get("/models")
async def list_models():
    """사용 가능한 모델 목록"""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{settings.OLLAMA_BASE_URL}/api/tags")
            if response.status_code == 200:
                return response.json()
            else:
                raise HTTPException(status_code=500, detail="Ollama 서버 오류")
    except Exception as e:
        logger.error(f"모델 목록 조회 실패: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/generate", response_model=GenerateResponse)
async def generate(request: GenerateRequest):
    """
    LLM 텍스트 생성 (일반 응답)
    """
    try:
        model = request.model or settings.OLLAMA_MODEL
        
        logger.info(f"생성 요청 - 모델: {model}, 프롬프트 길이: {len(request.prompt)}")
        
        # Ollama API 호출
        payload = {
            "model": model,
            "prompt": request.prompt,
            "stream": False,
            "options": {
                "temperature": request.temperature
            }
        }
        
        if request.max_tokens:
            payload["options"]["num_predict"] = request.max_tokens
        
        timeout = httpx.Timeout(600.0, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                f"{settings.OLLAMA_BASE_URL}/api/generate",
                json=payload
            )
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Ollama API 오류: {response.text}"
                )
            
            result = response.json()
            
            return GenerateResponse(
                response=result.get("response", ""),
                model=model,
                done=True
            )
            
    except httpx.TimeoutException:
        logger.error("Ollama API 타임아웃")
        raise HTTPException(status_code=504, detail="LLM 서버 응답 시간 초과")
    except Exception as e:
        logger.error(f"생성 실패: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/generate_stream")
async def generate_stream(request: GenerateRequest):
    """
    LLM 텍스트 생성 (스트리밍 응답)
    """
    async def stream_generator() -> AsyncGenerator[str, None]:
        try:
            model = request.model or settings.OLLAMA_MODEL
            
            logger.info(f"스트리밍 생성 요청 - 모델: {model}")
            
            # Ollama API 스트리밍 호출
            payload = {
                "model": model,
                "prompt": request.prompt,
                "stream": True,
                "options": {
                    "temperature": request.temperature
                }
            }
            
            if request.max_tokens:
                payload["options"]["num_predict"] = request.max_tokens
            
            timeout = httpx.Timeout(600.0, connect=10.0)
            async with httpx.AsyncClient(timeout=timeout) as client:
                async with client.stream(
                    "POST",
                    f"{settings.OLLAMA_BASE_URL}/api/generate",
                    json=payload
                ) as response:
                    if response.status_code != 200:
                        error_data = json.dumps({
                            "error": f"Ollama API 오류: {response.status_code}"
                        }, ensure_ascii=False)
                        yield f"data: {error_data}\n\n"
                        return
                    
                    async for line in response.aiter_lines():
                        if not line:
                            continue
                        
                        try:
                            data = json.loads(line)
                            token = data.get('response', '')
                            
                            if token:
                                # SSE 형식으로 전송
                                token_data = json.dumps({
                                    "token": token
                                }, ensure_ascii=False)
                                yield f"data: {token_data}\n\n"
                            
                            if data.get('done', False):
                                done_data = json.dumps({
                                    "done": True,
                                    "model": model
                                }, ensure_ascii=False)
                                yield f"data: {done_data}\n\n"
                                break
                                
                        except json.JSONDecodeError:
                            continue
                            
        except httpx.TimeoutException:
            error_data = json.dumps({
                "error": "LLM 서버 응답 시간 초과"
            }, ensure_ascii=False)
            yield f"data: {error_data}\n\n"
        except Exception as e:
            logger.error(f"스트리밍 생성 실패: {str(e)}")
            error_data = json.dumps({
                "error": str(e)
            }, ensure_ascii=False)
            yield f"data: {error_data}\n\n"
    
    return StreamingResponse(
        stream_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"
        }
    )


@app.get("/")
async def root():
    """루트 엔드포인트"""
    return {
        "service": "GPU LLM Server",
        "version": "1.0.0",
        "status": "running",
        "ollama_url": settings.OLLAMA_BASE_URL,
        "default_model": settings.OLLAMA_MODEL,
        "endpoints": {
            "health": "/health",
            "models": "/models",
            "generate": "/generate (POST)",
            "generate_stream": "/generate_stream (POST)"
        }
    }


if __name__ == "__main__":
    logger.info(f"GPU LLM Server 시작 - {settings.HOST}:{settings.PORT}")
    logger.info(f"Ollama URL: {settings.OLLAMA_BASE_URL}")
    logger.info(f"기본 모델: {settings.OLLAMA_MODEL}")
    
    uvicorn.run(
        app,
        host=settings.HOST,
        port=settings.PORT,
        log_level="info"
    )

