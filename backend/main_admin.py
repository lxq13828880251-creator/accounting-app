"""Personal Accounting App - FastAPI Backend"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import logging
import os

from app.db.database import init_db
from app.api.endpoints import auth
from app.api.endpoints import records
from app.api.endpoints import categories
from app.api.endpoints import stats
from app.api.endpoints import ai
from app.api.endpoints import bill
from app.api.endpoints import budget_api
from app.api.endpoints import fixed_expense_api
from app.api.endpoints import users
from app.api.admin import admin_api
from app.api.version import router as version_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting app...")
    await init_db()
    # 创建上传目录
    os.makedirs("/opt/accounting-app/uploads/avatars", exist_ok=True)
    yield
    logger.info("Shutting down...")

app = FastAPI(title="Personal Accounting API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态文件服务（头像等）
os.makedirs("/opt/accounting-app/uploads/avatars", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="/opt/accounting-app/uploads"), name="uploads")

app.include_router(auth.router, prefix="/api/auth", tags=["Auth"])
app.include_router(records.router, prefix="/api/records", tags=["Records"])
app.include_router(categories.router, prefix="/api/categories", tags=["Categories"])
app.include_router(stats.router, prefix="/api/stats", tags=["Stats"])
app.include_router(ai.router, prefix="/api/ai", tags=["AI"])
app.include_router(bill.router, prefix="/api/bill", tags=["Bill"])
app.include_router(budget_api.router, prefix="/api/budget", tags=["Budget"])
app.include_router(fixed_expense_api.router, prefix="/api/fixed-expenses", tags=["FixedExpenses"])
app.include_router(users.router, prefix="/api/users", tags=["Users"])
app.include_router(admin_api.router, prefix="/api/admin", tags=["Admin"])
app.include_router(version_router)

@app.get("/")
async def root():
    return {"message": "Personal Accounting API", "version": "1.0.0"}

@app.get("/health")
async def health():
    return {"status": "healthy"}
