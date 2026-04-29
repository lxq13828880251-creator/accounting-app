"""Budget model"""
from sqlalchemy import Column, Integer, Float, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from app.db.database import Base

class Budget(Base):
    __tablename__ = "budgets"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    year = Column(Integer, nullable=False)
    month = Column(Integer, nullable=False)
    total_budget = Column(Float, default=0)
    warning_threshold = Column(Float, default=0.8)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    def to_dict(self):
        return {
            "id": self.id,
            "user_id": self.user_id,
            "year": self.year,
            "month": self.month,
            "total_budget": self.total_budget,
            "warning_threshold": self.warning_threshold,
        }
