from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "中西合璧 · 每日运势分析系统"
    DEBUG: bool = True
    DATABASE_URL: str = "sqlite+aiosqlite:///./fortune.db"
    DEEPSEEK_API_KEY: str = ""
    DEEPSEEK_BASE_URL: str = "https://api.deepseek.com"
    DEEPSEEK_MODEL: str = "deepseek-chat"
    CORS_ORIGINS: list[str] = ["http://localhost:5173", "http://localhost:3000", "http://127.0.0.1:5173"]

    class Config:
        env_file = ".env"


settings = Settings()
