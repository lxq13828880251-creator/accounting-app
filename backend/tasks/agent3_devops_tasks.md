# Agent-3: 部署运维任务清单

> 负责人: devops
> 时间: Week 3 (5个工作日)

---

## Day 1: Docker部署优化

### 任务1.1: 优化Dockerfile

```dockerfile
# 后端Dockerfile
FROM python:3.11-slim

WORKDIR /app

# 安装依赖
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制代码
COPY ./app ./app
COPY ./main.py .

# 创建非root用户
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

EXPOSE 8000

# 使用gunicorn运行
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--threads", "2", "main:app"]
```

### 任务1.2: 优化docker-compose.yml

```yaml
version: '3.8'

services:
  backend:
    build: ./backend
    container_name: accounting-backend
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - SECRET_KEY=${SECRET_KEY}
    volumes:
      - ./uploads:/app/uploads
      - ./logs:/app/logs
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - accounting-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  postgres:
    image: postgres:16-alpine
    container_name: accounting-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: accounting
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "127.0.0.1:5432:5432"  # 只允许本地访问
    networks:
      - accounting-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: accounting-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
    ports:
      - "127.0.0.1:6379:6379"  # 只允许本地访问
    volumes:
      - redis-data:/data
    networks:
      - accounting-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  nginx:
    image: nginx:alpine
    container_name: accounting-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
      - ./uploads:/app/uploads:ro
    depends_on:
      - backend
    networks:
      - accounting-net

volumes:
  postgres-data:
  redis-data:

networks:
  accounting-net:
    driver: bridge
```

### 任务1.3: 环境变量文件

```bash
# .env.production
# 数据库
DATABASE_URL=postgresql+asyncpg://postgres:your_password@postgres:5432/accounting
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password

# Redis
REDIS_URL=redis://:your_redis_password@redis:6379/0
REDIS_PASSWORD=your_redis_password

# 安全
SECRET_KEY=your-super-secret-key-change-in-production

# AI服务
DEEPSEEK_API_KEY=sk-your-key
VOLC_API_KEY=your-volc-key
VOLC_ASR_KEY=your-asr-key
```

**验收标准**:
- [ ] Dockerfile构建成功
- [ ] docker-compose启动成功
- [ ] 健康检查正常

---

## Day 2: Nginx配置

### 任务2.1: Nginx主配置

```nginx
# nginx.conf
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    '$request_time';

    access_log /var/log/nginx/access.log main;

    # 基础设置
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript
               application/xml application/xml+rss text/javascript application/x-javascript;

    # 限流
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=10r/s;

    # 上传大小限制
    client_max_body_size 10M;

    include /etc/nginx/conf.d/*.conf;
}
```

### 任务2.2: 网站配置

```nginx
# conf.d/accounting.conf
upstream backend {
    server backend:8000;
    keepalive 32;
}

server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name accounting.example.com;

    # SSL配置
    ssl_certificate /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # API代理
    location /api/ {
        limit_req zone=api burst=50 nodelay;
        
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 登录限流
    location /api/auth/login {
        limit_req zone=login burst=5 nodelay;
        
        proxy_pass http://backend;
        # 其他proxy设置同上...
    }

    # Swagger文档
    location /docs {
        proxy_pass http://backend;
        proxy_set_header Host $host;
    }

    location /api/docs/oauth2-redirect {
        proxy_pass http://backend;
    }

    # 静态文件（上传的头像等）
    location /uploads {
        alias /app/uploads;
        expires 7d;
        add_header Cache-Control "public, immutable";
        
        # 禁止执行脚本
        location ~ \.(php|py|pl|sh|cgi)$ {
            deny all;
        }
    }

    # Web管理后台静态文件
    location /admin {
        alias /app/admin-web/dist;
        try_files $uri $uri/ /admin/index.html;
        
        # 缓存静态资源
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
        }
    }

    # 前端APP
    location / {
        root /app/web/dist;
        try_files $uri $uri/ /index.html;
        
        # 缓存静态资源
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
        }
    }

    # 健康检查
    location /health {
        access_log off;
        return 200 "healthy";
    }

    # 错误页面
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

**验收标准**:
- [ ] HTTPS正常访问
- [ ] API代理正常
- [ ] 限流生效
- [ ] 静态文件缓存正常

---

## Day 3: 数据库备份

### 任务3.1: 备份脚本

```bash
#!/bin/bash
# backup.sh - 数据库备份脚本

# 配置
BACKUP_DIR="/opt/backups/postgres"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="accounting"
DB_USER="postgres"
DB_HOST="localhost"

# S3配置（可选）
S3_BUCKET="s3://your-bucket/postgres-backups"
S3_ENABLED=false

# 创建备份目录
mkdir -p $BACKUP_DIR

# 执行备份
echo "[$(date)] 开始备份数据库..."
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME -Fc -f "$BACKUP_DIR/accounting_${DATE}.dump"

if [ $? -eq 0 ]; then
    echo "[$(date)] 备份成功: accounting_${DATE}.dump"
    
    # 压缩
    gzip "$BACKUP_DIR/accounting_${DATE}.dump"
    echo "[$(date)] 压缩完成: accounting_${DATE}.dump.gz"
    
    # 上传到S3
    if [ "$S3_ENABLED" = true ]; then
        aws s3 cp "$BACKUP_DIR/accounting_${DATE}.dump.gz" "$S3_BUCKET/"
        echo "[$(date)] 上传到S3完成"
    fi
    
    # 清理过期备份
    find $BACKUP_DIR -name "accounting_*.dump.gz" -mtime +$RETENTION_DAYS -delete
    echo "[$(date)] 清理过期备份完成"
    
    # 记录备份信息
    echo "$(date),$DB_NAME,accounting_${DATE}.dump.gz,SUCCESS" >> $BACKUP_DIR/backup_log.csv
else
    echo "[$(date)] 备份失败!"
    echo "$(date),$DB_NAME,accounting_${DATE}.dump,FAILED" >> $BACKUP_DIR/backup_log.csv
    exit 1
fi
```

### 任务3.2: 定时任务

```bash
# /etc/cron.d/accounting-backup
# 每天凌晨3点执行备份
0 3 * * * root /opt/scripts/backup.sh >> /var/log/backup.log 2>&1

# 每周日凌晨4点执行完整备份
0 4 * * 0 root /opt/scripts/backup_full.sh >> /var/log/backup_full.log 2>&1
```

### 任务3.3: 恢复脚本

```bash
#!/bin/bash
# restore.sh - 数据库恢复脚本

BACKUP_FILE=$1
if [ -z "$BACKUP_FILE" ]; then
    echo "用法: $0 <备份文件路径>"
    exit 1
fi

DB_NAME="accounting"
DB_USER="postgres"

# 解压
gunzip -c $BACKUP_FILE > /tmp/restore.dump

# 创建临时数据库
echo "[$(date)] 创建临时恢复数据库..."
psql -U $DB_USER -c "DROP DATABASE IF EXISTS ${DB_NAME}_restore;"
psql -U $DB_USER -c "CREATE DATABASE ${DB_NAME}_restore;"

# 恢复
echo "[$(date)] 开始恢复数据..."
pg_restore -U $DB_USER -d ${DB_NAME}_restore /tmp/restore.dump

if [ $? -eq 0 ]; then
    echo "[$(date)] 恢复成功!"
    echo "临时数据库: ${DB_NAME}_restore"
else
    echo "[$(date)] 恢复失败!"
    exit 1
fi

# 清理临时文件
rm -f /tmp/restore.dump
```

**验收标准**:
- [ ] 备份脚本可执行
- [ ] 定时任务配置正确
- [ ] 恢复脚本测试通过

---

## Day 4: 监控告警

### 任务4.1: 基础监控脚本

```python
# monitor.py - 基础监控脚本
import psutil
import requests
import time
from datetime import datetime
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# 配置
API_URL = "http://114.132.171.188:8000"
ADMIN_EMAIL = "admin@example.com"
SMTP_SERVER = "smtp.example.com"
SMTP_PORT = 587
SMTP_USER = "monitor@example.com"
SMTP_PASSWORD = "password"

def check_api_health():
    """检查API健康状态"""
    try:
        response = requests.get(f"{API_URL}/health", timeout=5)
        return response.status_code == 200
    except:
        return False

def check_disk_space():
    """检查磁盘空间"""
    disk = psutil.disk_usage('/')
    return disk.percent < 90

def check_memory():
    """检查内存使用"""
    memory = psutil.virtual_memory()
    return memory.percent < 85

def check_cpu():
    """检查CPU使用"""
    cpu = psutil.cpu_percent(interval=1)
    return cpu < 90

def send_alert(subject, message):
    """发送告警邮件"""
    msg = MIMEMultipart()
    msg['From'] = SMTP_USER
    msg['To'] = ADMIN_EMAIL
    msg['Subject'] = subject
    
    body = f"""
    金算盘监控系统告警
    =================
    
    时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
    
    {message}
    
    请及时处理!
    """
    msg.attach(MIMEText(body, 'plain'))
    
    try:
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
        print(f"[{datetime.now()}] 告警邮件已发送")
    except Exception as e:
        print(f"[{datetime.now()}] 邮件发送失败: {e}")

def main():
    """主监控逻辑"""
    print(f"[{datetime.now()}] 开始监控系统检查...")
    
    checks = [
        ("API健康检查", check_api_health),
        ("磁盘空间检查", check_disk_space),
        ("内存检查", check_memory),
        ("CPU检查", check_cpu),
    ]
    
    all_passed = True
    failed_checks = []
    
    for name, check_func in checks:
        try:
            result = check_func()
            status = "✓ 通过" if result else "✗ 失败"
            print(f"  {name}: {status}")
            if not result:
                all_passed = False
                failed_checks.append(name)
        except Exception as e:
            print(f"  {name}: ✗ 错误 ({e})")
            all_passed = False
            failed_checks.append(f"{name} (错误)")
    
    if not all_passed:
        send_alert(
            "⚠️ 金算盘系统告警",
            f"以下检查未通过:\n\n" + "\n".join(f"- {c}" for c in failed_checks)
        )
    else:
        print("所有检查通过!")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    exit(main())
```

### 任务4.2: Systemd服务

```ini
# /etc/systemd/system/accounting-monitor.service
[Unit]
Description=Accounting App Monitor
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/scripts
ExecStart=/usr/bin/python3 /opt/scripts/monitor.py
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
```

### 任务4.3: 监控定时任务

```bash
# /etc/cron.d/accounting-monitor
# 每5分钟执行一次监控检查
*/5 * * * * root /usr/bin/python3 /opt/scripts/monitor.py >> /var/log/monitor.log 2>&1
```

**验收标准**:
- [ ] API健康检查正常
- [ ] 资源监控正常
- [ ] 告警邮件发送正常
- [ ] Systemd服务正常运行

---

## Day 5: 最终测试与上线

### 任务5.1: 部署检查清单

```markdown
# 部署检查清单

## 部署前
- [ ] 代码已提交并打标签
- [ ] 数据库备份完成
- [ ] 测试环境验证通过
- [ ] 准备回滚方案

## 部署中
- [ ] 拉取最新代码
- [ ] 执行数据库迁移
- [ ] 重启后端服务
- [ ] 重启Nginx
- [ ] 验证健康检查

## 部署后
- [ ] 功能测试
- [ ] 性能测试
- [ ] 监控告警验证
- [ ] 日志检查
- [ ] 更新文档
```

### 任务5.2: 回滚脚本

```bash
#!/bin/bash
# rollback.sh - 回滚脚本

VERSION=$1
BACKUP_DIR="/opt/backups"

if [ -z "$VERSION" ]; then
    echo "用法: $0 <版本号>"
    exit 1
fi

echo "[$(date)] 开始回滚到版本: $VERSION"

# 停止服务
docker-compose down

# 恢复代码
cd /opt/accounting-app
git checkout $VERSION

# 恢复数据库（可选）
# psql -U postgres -c "DROP DATABASE accounting;"
# pg_restore -U postgres -C /opt/backups/accounting_${VERSION}.dump

# 重启服务
docker-compose up -d

echo "[$(date)] 回滚完成"
```

### 任务5.3: 部署文档

创建 `DEPLOY.md`:

```markdown
# 金算盘记账系统部署文档

## 环境要求
- Docker 24.0+
- Docker Compose 2.20+
- 2GB+ RAM
- 20GB+ 磁盘空间

## 快速部署

1. 克隆项目
```bash
git clone https://github.com/your-org/accounting-app.git
cd accounting-app
```

2. 配置环境变量
```bash
cp .env.example .env
# 编辑.env文件
```

3. 启动服务
```bash
docker-compose up -d
```

4. 验证部署
```bash
curl http://localhost:8000/health
```

## 常用命令

- 启动: `docker-compose up -d`
- 停止: `docker-compose down`
- 重启: `docker-compose restart`
- 查看日志: `docker-compose logs -f`
- 进入容器: `docker exec -it accounting-backend bash`

## 备份

```bash
./scripts/backup.sh
```

## 恢复

```bash
./scripts/restore.sh backup_20240101.dump.gz
```
```

**验收标准**:
- [ ] 部署文档完整
- [ ] 回滚脚本可用
- [ ] 监控正常运行
- [ ] 所有服务健康

---

## 交付物清单

1. ✅ 优化后的Dockerfile
2. ✅ docker-compose.yml
3. ✅ Nginx配置文件
4. ✅ 数据库备份脚本
5. ✅ 数据库恢复脚本
6. ✅ 监控脚本
7. ✅ Systemd服务配置
8. ✅ 部署文档
9. ✅ 回滚脚本
10. ✅ 检查清单

---

## 监控指标

### 基础指标
| 指标 | 阈值 | 处理方式 |
|------|------|----------|
| API响应时间 | >2s | 告警 |
| CPU使用率 | >90% | 告警 |
| 内存使用率 | >85% | 告警 |
| 磁盘使用率 | >90% | 告警 |
| API错误率 | >1% | 告警 |
| 数据库连接数 | >80% | 告警 |

### 业务指标
| 指标 | 阈值 | 处理方式 |
|------|------|----------|
| 日活用户 | 下降50% | 告警 |
| API请求量 | 下降50% | 告警 |
| 错误日志数量 | 增加100% | 告警 |
