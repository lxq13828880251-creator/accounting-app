-- =====================================================
-- 金算盘记账系统 - 管理员功能扩展SQL脚本
-- 数据库: PostgreSQL
-- 创建时间: 2026-04-29
-- =====================================================

-- 1. 操作日志表
CREATE TABLE IF NOT EXISTS sys_oper_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    username VARCHAR(100),
    operation VARCHAR(50) NOT NULL,  -- LOGIN/LOGOUT/CREATE/UPDATE/DELETE
    module VARCHAR(50),               -- 用户管理/记录管理/系统配置
    method VARCHAR(100),              -- 请求方法
    url VARCHAR(500),                 -- 请求URL
    params TEXT,                      -- 请求参数
    detail TEXT,                      -- 详细信息
    ip_address VARCHAR(50),
    user_agent TEXT,
    status VARCHAR(20) DEFAULT 'success',  -- success/failed
    error_msg TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE sys_oper_log IS '操作日志表';
COMMENT ON COLUMN sys_oper_log.operation IS '操作类型: LOGIN/LOGOUT/CREATE/UPDATE/DELETE/EXPORT';
COMMENT ON COLUMN sys_oper_log.module IS '模块: 用户管理/记录管理/分类管理/系统配置';

-- 2. 登录日志表
CREATE TABLE IF NOT EXISTS sys_login_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    username VARCHAR(100),
    login_type VARCHAR(20) DEFAULT 'normal',  -- normal/admin
    ip_address VARCHAR(50),
    user_agent TEXT,
    location VARCHAR(200),
    device_type VARCHAR(50),  -- ios/android/web
    status VARCHAR(20) DEFAULT 'success',  -- success/failed
    fail_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE sys_login_log IS '登录日志表';

-- 3. 系统配置表
CREATE TABLE IF NOT EXISTS sys_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT,
    config_type VARCHAR(20) DEFAULT 'string',  -- string/number/boolean/json
    config_name VARCHAR(100),
    config_group VARCHAR(50),  -- basic/email/sms/ai/storage
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE sys_config IS '系统配置表';
COMMENT ON COLUMN sys_config.config_key IS '配置键，必须唯一';
COMMENT ON COLUMN sys_config.config_group IS '配置分组: basic/basic/basic/basic/basic/ai/storage';

-- 4. 系统公告表
CREATE TABLE IF NOT EXISTS sys_notice (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    notice_type VARCHAR(20) DEFAULT 'info',  -- info/warning/important
    target_type VARCHAR(20) DEFAULT 'all',    -- all/user/admin
    target_ids TEXT,                          -- JSON数组，指定用户ID
    priority INTEGER DEFAULT 0,               -- 优先级，数字越大越优先
    is_published BOOLEAN DEFAULT FALSE,
    published_at TIMESTAMP,
    expires_at TIMESTAMP,                     -- 过期时间，NULL表示永不过期
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE sys_notice IS '系统公告表';
COMMENT ON COLUMN sys_notice.notice_type IS '公告类型: info(通知)/warning(警告)/important(重要)';
COMMENT ON COLUMN sys_notice.target_type IS '目标类型: all(全部)/user(普通用户)/admin(管理员)';

-- 5. 用户扩展信息表
CREATE TABLE IF NOT EXISTS user_profile (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bio TEXT,                      -- 个人简介
    birthday DATE,                  -- 生日
    occupation VARCHAR(100),        -- 职业
    company VARCHAR(200),           -- 公司
    website VARCHAR(500),           -- 个人网站
    preferences JSONB DEFAULT '{}', -- 用户偏好设置
    notification_settings JSONB DEFAULT '{"email": true, "push": true}',  -- 通知设置
    last_login_at TIMESTAMP,       -- 上次登录时间
    login_count INTEGER DEFAULT 0,  -- 登录次数
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE user_profile IS '用户扩展信息表';

-- =====================================================
-- 索引创建
-- =====================================================

-- 操作日志索引
CREATE INDEX IF NOT EXISTS idx_oper_log_user_id ON sys_oper_log(user_id);
CREATE INDEX IF NOT EXISTS idx_oper_log_created_at ON sys_oper_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_oper_log_operation ON sys_oper_log(operation);
CREATE INDEX IF NOT EXISTS idx_oper_log_module ON sys_oper_log(module);

-- 登录日志索引
CREATE INDEX IF NOT EXISTS idx_login_log_user_id ON sys_login_log(user_id);
CREATE INDEX IF NOT EXISTS idx_login_log_created_at ON sys_login_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_login_log_username ON sys_login_log(username);

-- 系统配置索引
CREATE INDEX IF NOT EXISTS idx_sys_config_group ON sys_config(config_group);
CREATE INDEX IF NOT EXISTS idx_sys_config_key ON sys_config(config_key);

-- 公告索引
CREATE INDEX IF NOT EXISTS idx_notice_published ON sys_notice(is_published, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_notice_target ON sys_notice(target_type);

-- 用户扩展信息索引
CREATE INDEX IF NOT EXISTS idx_user_profile_user_id ON user_profile(user_id);

-- 现有表索引优化（如果不存在）
-- CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
-- CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
-- CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);
-- CREATE INDEX IF NOT EXISTS idx_records_user_date ON records(user_id, record_date DESC);

-- =====================================================
-- 初始数据
-- =====================================================

-- 系统配置初始数据
INSERT INTO sys_config (config_key, config_value, config_type, config_name, config_group, description, sort_order) VALUES
    ('app_name', '金算盘记账', 'string', '应用名称', 'basic', '应用显示名称', 1),
    ('app_version', '1.0.0', 'string', '应用版本', 'basic', '当前版本号', 2),
    ('maintenance_mode', 'false', 'boolean', '维护模式', 'basic', '开启后所有用户无法访问', 3),
    ('max_records_per_day', '100', 'number', '每日最大记录数', 'basic', '普通用户每天最多创建的记录数', 4),
    ('ai_enabled', 'true', 'boolean', 'AI功能', 'ai', '是否启用AI智能记账功能', 10),
    ('voice_enabled', 'true', 'boolean', '语音记账', 'ai', '是否启用语音记账功能', 11),
    ('import_enabled', 'true', 'boolean', '账单导入', 'ai', '是否启用账单导入功能', 12),
    ('export_limit', '10000', 'number', '导出限制', 'storage', '单次最大导出记录数', 20),
    ('file_upload_max_size', '10', 'number', '文件上传大小限制(MB)', 'storage', '单文件最大上传大小', 21)
ON CONFLICT (config_key) DO NOTHING;

-- 默认管理员公告
INSERT INTO sys_notice (title, content, notice_type, target_type, priority, is_published, published_at) VALUES
    ('欢迎使用金算盘管理后台', '金算盘记账系统管理后台正式上线，祝您使用愉快！', 'info', 'admin', 1, true, CURRENT_TIMESTAMP),
    ('系统维护通知', '系统将于每周日凌晨2:00-4:00进行例行维护，届时可能短暂无法访问。', 'warning', 'all', 0, true, CURRENT_TIMESTAMP)
ON CONFLICT DO NOTHING;

-- =====================================================
-- 函数和触发器
-- =====================================================

-- 自动更新updated_at的函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为配置表创建更新触发器
DROP TRIGGER IF EXISTS update_sys_config_updated_at ON sys_config;
CREATE TRIGGER update_sys_config_updated_at
    BEFORE UPDATE ON sys_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 为公告表创建更新触发器
DROP TRIGGER IF EXISTS update_sys_notice_updated_at ON sys_notice;
CREATE TRIGGER update_sys_notice_updated_at
    BEFORE UPDATE ON sys_notice
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 为用户扩展信息表创建更新触发器
DROP TRIGGER IF EXISTS update_user_profile_updated_at ON user_profile;
CREATE TRIGGER update_user_profile_updated_at
    BEFORE UPDATE ON user_profile
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 权限设置（可选，根据需要启用）
-- =====================================================

-- 创建只读用户（用于报表查询）
-- CREATE USER readonly_user WITH PASSWORD 'readonly_password';
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;

-- 为管理员表添加注释
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_superuser BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

COMMENT ON COLUMN users.is_superuser IS '是否为超级管理员';
COMMENT ON COLUMN users.is_active IS '账户是否激活';

-- =====================================================
-- 完成提示
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '金算盘数据库扩展脚本执行完成！';
    RAISE NOTICE '========================================';
    RAISE NOTICE '新增表：';
    RAISE NOTICE '  - sys_oper_log (操作日志)';
    RAISE NOTICE '  - sys_login_log (登录日志)';
    RAISE NOTICE '  - sys_config (系统配置)';
    RAISE NOTICE '  - sys_notice (系统公告)';
    RAISE NOTICE '  - user_profile (用户扩展信息)';
    RAISE NOTICE '';
    RAISE NOTICE 'users表已添加字段：';
    RAISE NOTICE '  - is_superuser (超级管理员标识)';
    RAISE NOTICE '  - is_active (账户激活状态)';
    RAISE NOTICE '========================================';
END $$;
