"""
运势相关 API 路由
"""
import json
from fastapi import APIRouter, HTTPException
from app.schemas.fortune import BirthFormRequest, FortuneResponse
from app.engines.fusion import get_full_fortune

router = APIRouter(prefix="/api/v1", tags=["fortune"])


@router.post("/fortune/daily", response_model=FortuneResponse)
async def calculate_daily_fortune(req: BirthFormRequest):
    """计算今日运势（游客模式）"""
    try:
        result = await get_full_fortune(
            birth_year=req.birth_year,
            birth_month=req.birth_month,
            birth_day=req.birth_day,
            birth_hour=req.birth_hour,
            gender=req.gender,
            birth_place=req.birth_place,
            birth_lat=req.birth_lat,
            health_summary=req.health_summary.model_dump() if req.health_summary else None,
        )
        return FortuneResponse(data=result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/huangli/today", response_model=FortuneResponse)
async def get_today_huangli_api():
    """获取今日黄历（无需用户信息）"""
    from app.engines.huangli import get_today_huangli
    try:
        result = get_today_huangli()
        return FortuneResponse(data=result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
