"""Bill Import API - 支付宝/微信账单导入"""
from fastapi import APIRouter, Depends, UploadFile, File, Form
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
import pandas as pd
import io

from app.db.database import get_db
from app.models.record import Record
from app.models.user import User
from app.api.endpoints.auth import get_current_user

router = APIRouter()

def parse_alipay_csv(content: str) -> list:
    """解析支付宝CSV账单"""
    records = []
    lines = content.strip().split('\n')
    for line in lines[1:]:  # 跳过表头
        parts = line.split(',')
        if len(parts) >= 6:
            try:
                # 格式: 时间,交易类型,交易对方,商品说明,金额(元),收/支,状态
                record = {
                    'date': parts[0].strip('"'),
                    'type': parts[1].strip('"'),
                    'counterparty': parts[2].strip('"'),
                    'description': parts[3].strip('"'),
                    'amount': float(parts[4].strip('"')),
                    'direction': parts[5].strip('"'),
                }
                if record['amount'] > 0:
                    records.append(record)
            except (ValueError, IndexError):
                continue
    return records

def parse_wechat_excel(content: bytes) -> list:
    """解析微信Excel账单"""
    records = []
    try:
        df = pd.read_excel(io.BytesIO(content))
        for _, row in df.iterrows():
            try:
                record = {
                    'date': str(row.get('交易时间', '')),
                    'type': str(row.get('交易类型', '')),
                    'counterparty': str(row.get('交易对方', '')),
                    'description': str(row.get('商品说明', '')),
                    'amount': float(row.get('金额(元)', 0)),
                    'direction': str(row.get('收/支', '')),
                }
                if record['amount'] > 0:
                    records.append(record)
            except (ValueError, KeyError):
                continue
    except Exception:
        pass
    return records

@router.post("/parse-alipay")
async def parse_alipay_bill(file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    """解析支付宝账单CSV"""
    try:
        content = await file.read()
        text = content.decode('utf-8')
        records = parse_alipay_csv(text)
        return {"success": True, "records": records, "count": len(records)}
    except Exception as e:
        return {"success": False, "error": str(e)}

@router.post("/parse-wechat")
async def parse_wechat_bill(file: UploadFile = File(...), current_user: User = Depends(get_current_user)):
    """解析微信账单Excel"""
    try:
        content = await file.read()
        records = parse_wechat_excel(content)
        return {"success": True, "records": records, "count": len(records)}
    except Exception as e:
        return {"success": False, "error": str(e)}

@router.post("/import")
async def import_bills(
    records: list,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """批量导入账单记录"""
    imported = 0
    for item in records:
        try:
            record_date = datetime.strptime(item.get('date', datetime.now().strftime('%Y-%m-%d')), '%Y-%m-%d')
            amount = float(item.get('amount', 0))
            direction = item.get('direction', '')
            description = item.get('description', item.get('counterparty', ''))
            
            record_type = 'expense' if direction in ['支出', '-'] else 'income'
            if amount < 0:
                amount = abs(amount)
            
            record = Record(
                user_id=current_user.id,
                record_type=record_type,
                amount=amount,
                description=description,
                record_date=record_date,
                category_id=1,  # 默认分类
            )
            db.add(record)
            imported += 1
        except Exception:
            continue
    
    await db.commit()
    return {"success": True, "imported": imported}
