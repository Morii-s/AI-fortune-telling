"""
用户模型和运势记录模型
"""
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean
from sqlalchemy.sql import func
from app.core.database import Base


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String(255), unique=True, nullable=True)
    password_hash = Column(String(255), nullable=True)
    is_guest = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())
    birth_year = Column(Integer, nullable=True)
    birth_month = Column(Integer, nullable=True)
    birth_day = Column(Integer, nullable=True)
    birth_hour = Column(Integer, nullable=True)
    birth_minute = Column(Integer, nullable=True, default=0)
    gender = Column(String(10), nullable=True)
    birth_place = Column(String(100), nullable=True)
    birth_lat = Column(Float, nullable=True, default=39.9)
    birth_lng = Column(Float, nullable=True, default=116.4)


class FortuneRecord(Base):
    __tablename__ = "fortune_records"
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, nullable=True)
    date = Column(String(20), nullable=False)
    birth_year = Column(Integer, nullable=False)
    birth_month = Column(Integer, nullable=False)
    birth_day = Column(Integer, nullable=False)
    birth_hour = Column(Integer, nullable=False)
    gender = Column(String(10), nullable=False)
    overall_score = Column(Integer, nullable=True)
    fortune_data = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
