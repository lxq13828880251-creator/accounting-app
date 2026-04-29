# Agent-1: 后端开发任务清单

> 负责人: db-dev
> 时间: Week 1 (5个工作日)

---

## Day 1: 数据库准备

### 任务1.1: 验证SQL脚本
```bash
# 上传并执行SQL脚本到服务器
ssh ubuntu@114.132.171.188
cd /opt/accounting-app
# 备份现有数据库
pg_dump -U postgres accounting > backup_$(date +%Y%m%d).sql
# 执行扩展脚本
psql -U postgres accounting -f sql/admin_extension.sql
```

### 任务1.2: 验证表结构
```python
# 测试连接和表创建
import asyncio
from app.db.database import engine

async def verify_tables():
    async with engine.connect() as conn:
        # 检查表是否存在
        tables = await conn.execute(text("""
            SELECT tablename FROM pg_tables
            WHERE schemaname = 'public'
        """))
        print([t[0] for t in tables])
```

**验收标准**:
- [ ] sys_oper_log 表创建成功
- [ ] sys_login_log 表创建成功
- [ ] sys_config 表创建成功，有初始数据
- [ ] sys_notice 表创建成功
- [ ] user_profile 表创建成功

---

## Day 2-3: API开发

### 任务2.1: 扩展admin_api.py

新增以下端点：

```python
# 1. 用户行为分析
@router.get("/users/{user_id}/activity")
async def get_user_activity(user_id: int, days: int = 30):
    """获取用户活跃度分析"""
    # 返回最近N天的登录次数、记录创建数等

# 2. 用户数据导出
@router.get("/export/users")
async def export_users(format: str = "excel"):
    """导出用户数据为Excel"""

# 3. 记录数据导出
@router.get("/export/records")
async def export_records(
    start_date: date,
    end_date: date,
    format: str = "excel"
):
    """导出记录数据为Excel"""
```

### 任务2.2: 新增日志API

创建文件: `app/api/admin/log_api.py`

```python
# 操作日志API
@router.get("/logs/oper")
async def get_oper_logs(
    page: int = 1,
    size: int = 20,
    operation: str = None,
    module: str = None,
    user_id: int = None,
    start_date: date = None,
    end_date: date = None
):
    """获取操作日志"""

@router.get("/logs/oper/{log_id}")
async def get_oper_log_detail(log_id: int):
    """获取操作日志详情"""

# 登录日志API
@router.get("/logs/login")
async def get_login_logs(...):
    """获取登录日志"""

@router.get("/logs/login/statistics")
async def get_login_statistics(days: int = 7):
    """获取登录统计"""
```

### 任务2.3: 新增配置API

创建文件: `app/api/admin/config_api.py`

```python
@router.get("/config")
async def get_all_config():
    """获取所有配置"""

@router.get("/config/{group}")
async def get_config_by_group(group: str):
    """按分组获取配置"""

@router.put("/config/{key}")
async def update_config(key: str, value: str):
    """更新配置"""

@router.post("/config/reload")
async def reload_config():
    """重新加载配置（通知各模块）"""
```

### 任务2.4: 新增公告API

创建文件: `app/api/admin/notice_api.py`

```python
@router.get("/notices")
async def get_notices(...):
    """获取公告列表"""

@router.post("/notices")
async def create_notice(...):
    """创建公告"""

@router.put("/notices/{id}")
async def update_notice(...):
    """更新公告"""

@router.post("/notices/{id}/publish")
async def publish_notice(id: int):
    """发布公告"""

@router.delete("/notices/{id}")
async def delete_notice(id: int):
    """删除公告"""
```

### 任务2.5: 中间件 - 自动记录操作日志

创建文件: `app/middleware/oper_log.py`

```python
from starlette.middleware.base import BaseHTTPMiddleware

class OperLogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        # 记录操作日志
        # 主要记录: POST/PUT/DELETE 请求
        pass
```

**验收标准**:
- [ ] 所有新增API可正常访问
- [ ] 日志自动记录功能正常
- [ ] 配置更新实时生效
- [ ] Excel导出功能正常

---

## Day 4: 测试与修复

### 任务3.1: API单元测试

```python
# tests/test_admin_api.py
import pytest

@pytest.mark.asyncio
async def test_get_admin_stats(client):
    response = await client.get("/api/admin/stats")
    assert response.status_code == 200

@pytest.mark.asyncio
async def test_get_users_list(client):
    response = await client.get("/api/admin/users")
    assert response.status_code == 200
```

### 任务3.2: 错误处理优化

- [ ] 统一错误响应格式
- [ ] 添加参数验证
- [ ] 添加请求日志

**验收标准**:
- [ ] 所有API通过单元测试
- [ ] 错误响应格式统一
- [ ] 无严重Bug

---

## Day 5: 代码审查与优化

### 任务4.1: 代码审查清单

- [ ] 所有函数有docstring
- [ ] 类型注解完整
- [ ] 异常处理完善
- [ ] 安全性检查（SQL注入、XSS等）

### 任务4.2: 性能优化

- [ ] 数据库查询优化（添加索引提示）
- [ ] 缓存热点数据（Redis）
- [ ] 大数据量分页优化

### 任务4.3: 文档更新

- [ ] 更新API文档（Swagger）
- [ ] 编写接口使用说明

**验收标准**:
- [ ] 代码通过审查
- [ ] 性能满足要求
- [ ] 文档完整

---

## 交付物清单

1. ✅ 执行后的SQL脚本日志
2. ✅ admin_api.py 扩展代码
3. ✅ 新增API文件：
   - log_api.py
   - config_api.py
   - notice_api.py
4. ✅ OperLogMiddleware 中间件
5. ✅ 单元测试文件
6. ✅ API测试报告

---

## 技术要求

### 数据库
- PostgreSQL 16
- 连接池: 10-50
- 索引优化

### API规范
- RESTful风格
- 统一响应格式
- JWT认证
- 限流: 100次/分钟

### 安全要求
- SQL注入防护
- XSS防护
- CSRF防护
- 敏感数据加密
