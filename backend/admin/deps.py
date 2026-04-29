"""管理员权限依赖"""
from fastapi import Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.database import get_db
from app.models.user import User
from app.api.endpoints.auth import get_current_user


async def get_current_superuser(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> User:
    """验证当前用户是否为超级管理员"""
    # 重新从数据库获取用户，确保获取最新状态
    result = await db.execute(select(User).filter(User.id == current_user.id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=401,
            detail="用户不存在"
        )
    
    if not user.is_superuser:
        raise HTTPException(
            status_code=403,
            detail="管理员权限不足"
        )
    
    return user
