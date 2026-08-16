"""
Pydantic 请求/响应模型
"""
from pydantic import BaseModel, Field
from typing import Optional


class HealthSummary(BaseModel):
    """用户明确授权后由设备生成的当日汇总；不接收原始健康记录。"""
    date: str = Field(..., description="汇总日期 YYYY-MM-DD（Asia/Shanghai）")
    steps: Optional[int] = Field(default=None, ge=0)
    active_energy_kcal: Optional[float] = Field(default=None, ge=0)
    sleep_hours: Optional[float] = Field(default=None, ge=0, le=24)
    resting_heart_rate: Optional[float] = Field(default=None, ge=0)
    heart_rate_variability: Optional[float] = Field(default=None, ge=0)
    workout_minutes: Optional[int] = Field(default=None, ge=0)


class BirthFormRequest(BaseModel):
    birth_year: int = Field(..., ge=1900, le=2100, description="出生年份")
    birth_month: int = Field(..., ge=1, le=12, description="出生月份")
    birth_day: int = Field(..., ge=1, le=31, description="出生日期")
    birth_hour: int = Field(default=12, ge=0, le=23, description="出生时辰(0-23)")
    birth_minute: int = Field(default=0, ge=0, le=59)
    gender: str = Field(default="male", description="性别: male/female")
    birth_place: str = Field(default="北京", description="出生地")
    birth_lat: float = Field(default=39.9, description="出生地纬度")
    date: Optional[str] = Field(default=None, description="查询日期 YYYY-MM-DD")
    health_summary: Optional[HealthSummary] = Field(default=None, description="可选的、经用户授权的设备健康汇总")


class FortuneResponse(BaseModel):
    code: int = 0
    message: str = "success"
    data: Optional[dict] = None


class ErrorResponse(BaseModel):
    code: int = 1
    message: str
    data: None = None
