"""Budget API"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from datetime import datetime

from app.db.database import get_db
from app.models.budget_model import Budget
from app.models.record import Record
from app.models.user import User
from app.api.endpoints.auth import get_current_user

router = APIRouter()

@router.get("")
async def get_budget(year: int = Query(...), month: int = Query(...),
                    current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """获取指定月份的预算"""
    result = await db.execute(
        select(Budget).filter(
            and_(Budget.user_id == current_user.id, Budget.year == year, Budget.month == month)
        )
    )
    budget = result.scalar_one_or_none()
    if budget:
        return budget.to_dict()
    return {"year": year, "month": month, "total_budget": 0, "warning_threshold": 0.8}

@router.post("")
async def save_budget(request: dict,
                     current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """保存或更新预算"""
    year = request.get('year')
    month = request.get('month')
    total_budget = request.get('total_budget') or request.get('totalBudget', 0)
    warning_threshold = request.get('warning_threshold') or request.get('warningThreshold', 0.8)
    result = await db.execute(
        select(Budget).filter(
            and_(Budget.user_id == current_user.id, Budget.year == year, Budget.month == month)
        )
    )
    budget = result.scalar_one_or_none()
    
    if budget:
        budget.total_budget = total_budget
        budget.warning_threshold = warning_threshold
    else:
        budget = Budget(
            user_id=current_user.id,
            year=year,
            month=month,
            total_budget=total_budget,
            warning_threshold=warning_threshold
        )
        db.add(budget)
    
    await db.commit()
    await db.refresh(budget)
    return budget.to_dict()

@router.get("/usage")
async def get_budget_usage(year: int = Query(...), month: int = Query(...),
                          current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """获取预算使用情况"""
    # 获取预算
    budget_result = await db.execute(
        select(Budget).filter(
            and_(Budget.user_id == current_user.id, Budget.year == year, Budget.month == month)
        )
    )
    budget = budget_result.scalar_one_or_none()
    
    # 计算已支出
    expense_result = await db.execute(
        select(func.coalesce(func.sum(Record.amount), 0)).filter(
            and_(Record.user_id == current_user.id, Record.record_type == "expense",
                 func.extract("year", Record.record_date) == year,
                 func.extract("month", Record.record_date) == month)
        )
    )
    total_spent = float(expense_result.scalar() or 0)
    
    total_budget = budget.total_budget if budget else 0
    remaining = total_budget - total_spent
    usage_ratio = total_spent / total_budget if total_budget > 0 else 0
    
    return {
        "budget": budget.to_dict() if budget else None,
        "total_spent": total_spent,
        "remaining": remaining,
        "usage_ratio": usage_ratio,
        "category_spent": {}
    }
