"""管理员API - 用户和全局数据管理"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_
from typing import Optional, List
from datetime import datetime, date
from pydantic import BaseModel

from app.db.database import get_db
from app.models.user import User
from app.models.record import Record
from app.models.category import Category
from app.schemas import UserResponse
from app.api.deps import get_current_superuser

router = APIRouter()


# ============ 响应模型 ============
class UserListItem(BaseModel):
    id: int
    username: str
    phone: Optional[str]
    email: Optional[str]
    is_superuser: bool
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserDetail(UserListItem):
    full_name: Optional[str]
    avatar_url: Optional[str]
    gender: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    location_name: Optional[str]
    record_count: int = 0
    total_income: float = 0
    total_expense: float = 0


class AdminStats(BaseModel):
    total_users: int
    active_users: int
    total_records: int
    today_records: int
    total_income: float
    total_expense: float
    total_balance: float
    total_categories: int


class UserUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    is_active: Optional[bool] = None
    is_superuser: Optional[bool] = None
    full_name: Optional[str] = None
    gender: Optional[str] = None


class RecordListItem(BaseModel):
    id: int
    user_id: int
    username: str
    category_name: str
    amount: float
    record_type: str
    description: Optional[str]
    record_date: date
    created_at: datetime

    class Config:
        from_attributes = True


# ============ 管理员统计 ============
@router.get("/stats", response_model=AdminStats)
async def get_admin_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """获取全局统计数据"""
    # 用户统计
    total_users_result = await db.execute(select(func.count(User.id)))
    total_users = total_users_result.scalar() or 0
    
    active_users_result = await db.execute(
        select(func.count(User.id)).filter(User.is_active == True)
    )
    active_users = active_users_result.scalar() or 0
    
    # 记录统计
    total_records_result = await db.execute(select(func.count(Record.id)))
    total_records = total_records_result.scalar() or 0
    
    today = date.today()
    today_records_result = await db.execute(
        select(func.count(Record.id)).filter(Record.record_date == today)
    )
    today_records = today_records_result.scalar() or 0
    
    # 收支统计
    income_result = await db.execute(
        select(func.coalesce(func.sum(Record.amount), 0))
        .filter(Record.record_type == 'income')
    )
    total_income = float(income_result.scalar() or 0)
    
    expense_result = await db.execute(
        select(func.coalesce(func.sum(Record.amount), 0))
        .filter(Record.record_type == 'expense')
    )
    total_expense = float(expense_result.scalar() or 0)
    
    # 分类统计
    categories_result = await db.execute(
        select(func.count(Category.id)).filter(Category.is_active == True)
    )
    total_categories = categories_result.scalar() or 0
    
    return AdminStats(
        total_users=total_users,
        active_users=active_users,
        total_records=total_records,
        today_records=today_records,
        total_income=total_income,
        total_expense=total_expense,
        total_balance=total_income - total_expense,
        total_categories=total_categories
    )


# ============ 用户管理 ============
@router.get("/users", response_model=List[UserListItem])
async def get_all_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    is_active: Optional[bool] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """获取所有用户列表"""
    query = select(User)
    
    # 搜索过滤
    if search:
        search_pattern = f"%{search}%"
        query = query.filter(
            or_(
                User.username.ilike(search_pattern),
                User.email.ilike(search_pattern),
                User.phone.ilike(search_pattern)
            )
        )
    
    # 状态过滤
    if is_active is not None:
        query = query.filter(User.is_active == is_active)
    
    # 排序和分页
    query = query.order_by(User.created_at.desc()).offset(skip).limit(limit)
    
    result = await db.execute(query)
    users = result.scalars().all()
    
    return users


@router.get("/users/count")
async def get_users_count(
    search: Optional[str] = None,
    is_active: Optional[bool] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """获取用户总数"""
    query = select(func.count(User.id))
    
    if search:
        search_pattern = f"%{search}%"
        query = query.filter(
            or_(
                User.username.ilike(search_pattern),
                User.email.ilike(search_pattern),
                User.phone.ilike(search_pattern)
            )
        )
    
    if is_active is not None:
        query = query.filter(User.is_active == is_active)
    
    result = await db.execute(query)
    count = result.scalar() or 0
    
    return {"count": count}


@router.get("/users/{user_id}", response_model=UserDetail)
async def get_user_detail(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """获取用户详情"""
    # 获取用户基本信息
    result = await db.execute(select(User).filter(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 获取用户记录统计
    record_count_result = await db.execute(
        select(func.count(Record.id)).filter(Record.user_id == user_id)
    )
    record_count = record_count_result.scalar() or 0
    
    income_result = await db.execute(
        select(func.coalesce(func.sum(Record.amount), 0))
        .filter(and_(Record.user_id == user_id, Record.record_type == 'income'))
    )
    total_income = float(income_result.scalar() or 0)
    
    expense_result = await db.execute(
        select(func.coalesce(func.sum(Record.amount), 0))
        .filter(and_(Record.user_id == user_id, Record.record_type == 'expense'))
    )
    total_expense = float(expense_result.scalar() or 0)
    
    return UserDetail(
        id=user.id,
        username=user.username,
        phone=user.phone,
        email=user.email,
        is_superuser=user.is_superuser,
        is_active=user.is_active,
        created_at=user.created_at,
        full_name=user.full_name,
        avatar_url=user.avatar_url,
        gender=user.gender,
        latitude=user.latitude,
        longitude=user.longitude,
        location_name=user.location_name,
        record_count=record_count,
        total_income=total_income,
        total_expense=total_expense
    )


@router.put("/users/{user_id}")
async def update_user(
    user_id: int,
    user_update: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """更新用户信息"""
    # 不能修改自己
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="不能修改自己的权限")
    
    result = await db.execute(select(User).filter(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 更新字段
    update_data = user_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(user, field, value)
    
    await db.commit()
    await db.refresh(user)
    
    return {"message": "更新成功", "user_id": user_id}


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """删除用户（软删除 - 设为 inactive）"""
    # 不能删除自己
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="不能删除自己")
    
    result = await db.execute(select(User).filter(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    # 软删除
    user.is_active = False
    await db.commit()
    
    return {"message": "用户已禁用"}


@router.post("/users/{user_id}/activate")
async def activate_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """激活用户"""
    result = await db.execute(select(User).filter(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    user.is_active = True
    await db.commit()
    
    return {"message": "用户已激活"}


# ============ 全局流水记录 ============
@router.get("/records", response_model=List[RecordListItem])
async def get_all_records(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    user_id: Optional[int] = None,
    record_type: Optional[str] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """获取所有用户的流水记录"""
    query = select(Record, User.username, Category.name.label('category_name')).join(
        User, Record.user_id == User.id
    ).join(
        Category, Record.category_id == Category.id
    )
    
    # 过滤条件
    if user_id:
        query = query.filter(Record.user_id == user_id)
    if record_type:
        query = query.filter(Record.record_type == record_type)
    if start_date:
        query = query.filter(Record.record_date >= start_date)
    if end_date:
        query = query.filter(Record.record_date <= end_date)
    
    query = query.order_by(Record.created_at.desc()).offset(skip).limit(limit)
    
    result = await db.execute(query)
    rows = result.all()
    
    return [
        RecordListItem(
            id=record.id,
            user_id=record.user_id,
            username=username,
            category_name=category_name,
            amount=float(record.amount),
            record_type=record.record_type,
            description=record.description,
            record_date=record.record_date,
            created_at=record.created_at
        )
        for record, username, category_name in rows
    ]


@router.get("/records/count")
async def get_records_count(
    user_id: Optional[int] = None,
    record_type: Optional[str] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """获取记录总数"""
    query = select(func.count(Record.id))
    
    if user_id:
        query = query.filter(Record.user_id == user_id)
    if record_type:
        query = query.filter(Record.record_type == record_type)
    if start_date:
        query = query.filter(Record.record_date >= start_date)
    if end_date:
        query = query.filter(Record.record_date <= end_date)
    
    result = await db.execute(query)
    count = result.scalar() or 0
    
    return {"count": count}


@router.delete("/records/{record_id}")
async def delete_record(
    record_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_superuser)
):
    """删除指定记录"""
    result = await db.execute(select(Record).filter(Record.id == record_id))
    record = result.scalar_one_or_none()
    
    if not record:
        raise HTTPException(status_code=404, detail="记录不存在")
    
    await db.delete(record)
    await db.commit()
    
    return {"message": "删除成功"}
