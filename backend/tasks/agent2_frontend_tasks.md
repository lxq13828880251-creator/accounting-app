# Agent-2: Web管理后台开发任务清单

> 负责人: web-dev
> 时间: Week 2 (5个工作日)
> 技术栈: Vue3 + Vite + Element Plus + ECharts + Pinia

---

## Day 1: 项目搭建

### 任务1.1: 项目初始化

```bash
# 创建项目
npm create vite@latest admin-web -- --template vue-ts
cd admin-web

# 安装依赖
npm install
npm install element-plus @element-plus/icons-vue
npm install echarts vue-echarts
npm install pinia vue-router
npm install axios @vueuse/core
npm install dayjs
npm install file-saver xlsx
```

### 任务1.2: 项目结构

```
src/
├── api/                 # API调用
│   ├── admin.ts        # 管理员API
│   ├── auth.ts         # 认证API
│   └── index.ts        # Axios配置
├── components/          # 通用组件
│   ├── layout/         # 布局组件
│   └── common/         # 通用组件
├── composables/        # 组合式函数
├── router/             # 路由
│   └── index.ts
├── stores/             # Pinia状态
│   ├── auth.ts
│   ├── user.ts
│   └── app.ts
├── styles/             # 样式
│   └── common.scss
├── types/              # TypeScript类型
├── utils/              # 工具函数
├── views/              # 页面
│   ├── login/
│   ├── dashboard/
│   ├── user/
│   ├── record/
│   ├── log/
│   ├── config/
│   └── notice/
└── App.vue
```

### 任务1.3: 路由权限控制

```typescript
// router/index.ts
const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/login/index.vue'),
    meta: { requiresAuth: false }
  },
  {
    path: '/admin',
    component: () => import('@/components/layout/MainLayout.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
    children: [
      { path: '', redirect: '/admin/dashboard' },
      { path: 'dashboard', name: 'Dashboard', component: () => import('@/views/dashboard/index.vue') },
      { path: 'users', name: 'UserList', component: () => import('@/views/user/list.vue') },
      { path: 'users/:id', name: 'UserDetail', component: () => import('@/views/user/detail.vue') },
      { path: 'records', name: 'RecordList', component: () => import('@/views/record/list.vue') },
      { path: 'logs/oper', name: 'OperLog', component: () => import('@/views/log/oper.vue') },
      { path: 'logs/login', name: 'LoginLog', component: () => import('@/views/log/login.vue') },
      { path: 'config', name: 'Config', component: () => import('@/views/config/index.vue') },
      { path: 'notices', name: 'Notice', component: () => import('@/views/notice/index.vue') },
    ]
  }
]
```

### 任务1.4: Axios配置

```typescript
// api/index.ts
import axios from 'axios'
import { ElMessage } from 'element-plus'
import router from '@/router'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://114.132.171.188:8000',
  timeout: 30000
})

// 请求拦截器 - 添加Token
api.interceptors.request.use(config => {
  const token = localStorage.getItem('admin_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// 响应拦截器 - 处理错误
api.interceptors.response.use(
  response => response,
  error => {
    if (error.response?.status === 401) {
      localStorage.removeItem('admin_token')
      router.push('/login')
    }
    ElMessage.error(error.response?.data?.detail || '请求失败')
    return Promise.reject(error)
  }
)

export default api
```

**验收标准**:
- [ ] 项目可正常启动
- [ ] 路由跳转正常
- [ ] 登录拦截正常

---

## Day 2: 登录 + 仪表盘

### 任务2.1: 登录页面

```vue
<!-- views/login/index.vue -->
<template>
  <div class="login-container">
    <el-card class="login-card">
      <h2>金算盘管理后台</h2>
      <el-form ref="formRef" :model="form" :rules="rules">
        <el-form-item prop="username">
          <el-input v-model="form.username" placeholder="用户名" prefix-icon="User" />
        </el-form-item>
        <el-form-item prop="password">
          <el-input v-model="form.password" type="password" placeholder="密码" prefix-icon="Lock" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="loading" @click="handleLogin" class="login-btn">
            登录
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>
```

**要求**:
- 简洁美观的登录界面
- 表单验证
- 登录按钮loading状态
- 错误提示

### 任务2.2: 主布局组件

```vue
<!-- components/layout/MainLayout.vue -->
<template>
  <el-container class="main-layout">
    <el-aside width="200px">
      <div class="logo">金算盘</div>
      <el-menu :default-active="route.path" router>
        <el-menu-item index="/admin/dashboard">
          <el-icon><DataAnalysis /></el-icon>
          <span>仪表盘</span>
        </el-menu-item>
        <el-menu-item index="/admin/users">
          <el-icon><User /></el-icon>
          <span>用户管理</span>
        </el-menu-item>
        <el-menu-item index="/admin/records">
          <el-icon><Document /></el-icon>
          <span>流水记录</span>
        </el-menu-item>
        <el-menu-item index="/admin/logs/oper">
          <el-icon><Operation /></el-icon>
          <span>操作日志</span>
        </el-menu-item>
        <el-menu-item index="/admin/logs/login">
          <el-icon><Key /></el-icon>
          <span>登录日志</span>
        </el-menu-item>
        <el-menu-item index="/admin/config">
          <el-icon><Setting /></el-icon>
          <span>系统配置</span>
        </el-menu-item>
        <el-menu-item index="/admin/notices">
          <el-icon><Bell /></el-icon>
          <span>公告管理</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header>
        <div class="header-right">
          <span>{{ username }}</span>
          <el-button @click="handleLogout">退出</el-button>
        </div>
      </el-header>
      <el-main>
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>
```

### 任务2.3: 仪表盘页面

```vue
<!-- views/dashboard/index.vue -->
<template>
  <div class="dashboard">
    <!-- 统计卡片 -->
    <el-row :gutter="20">
      <el-col :span="6">
        <el-card class="stat-card">
          <div class="stat-title">用户总数</div>
          <div class="stat-value">{{ stats.total_users }}</div>
          <div class="stat-sub">活跃: {{ stats.active_users }}</div>
        </el-card>
      </el-col>
      <!-- 其他统计卡片... -->
    </el-row>

    <!-- 图表区域 -->
    <el-row :gutter="20" class="chart-row">
      <el-col :span="12">
        <el-card>
          <template #header>收支趋势</template>
          <v-chart :option="trendOption" autoresize />
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card>
          <template #header>分类统计</template>
          <v-chart :option="categoryOption" autoresize />
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>
```

**要求**:
- 统计卡片：用户数、记录数、今日记录、收支概况
- 收支趋势图：近30天折线图
- 分类占比图：饼图

**验收标准**:
- [ ] 登录页面美观
- [ ] 侧边栏菜单正常
- [ ] 仪表盘数据展示正常
- [ ] 图表渲染正常

---

## Day 3: 用户管理模块

### 任务3.1: 用户列表页面

```vue
<!-- views/user/list.vue -->
<template>
  <div class="user-list">
    <!-- 搜索筛选 -->
    <el-card class="filter-card">
      <el-form inline>
        <el-form-item>
          <el-input v-model="searchForm.username" placeholder="搜索用户名" clearable />
        </el-form-item>
        <el-form-item>
          <el-select v-model="searchForm.is_active" placeholder="状态" clearable>
            <el-option label="全部" :value="null" />
            <el-option label="激活" :value="true" />
            <el-option label="禁用" :value="false" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">搜索</el-button>
          <el-button @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 数据表格 -->
    <el-card>
      <el-table :data="tableData" v-loading="loading">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="username" label="用户名" />
        <el-table-column prop="phone" label="手机号" />
        <el-table-column prop="email" label="邮箱" />
        <el-table-column prop="is_superuser" label="角色">
          <template #default="{ row }">
            <el-tag v-if="row.is_superuser" type="danger">管理员</el-tag>
            <el-tag v-else>普通用户</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="is_active" label="状态">
          <template #default="{ row }">
            <el-tag :type="row.is_active ? 'success' : 'danger'">
              {{ row.is_active ? '激活' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="注册时间" />
        <el-table-column label="操作" width="200">
          <template #default="{ row }">
            <el-button type="primary" link @click="handleView(row)">查看</el-button>
            <el-button type="warning" link @click="handleToggleStatus(row)">
              {{ row.is_active ? '禁用' : '激活' }}
            </el-button>
            <el-button type="danger" link @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <!-- 分页 -->
      <el-pagination
        v-model:current-page="pagination.page"
        v-model:page-size="pagination.size"
        :total="pagination.total"
        layout="total, prev, pager, next"
        @current-change="fetchData"
      />
    </el-card>
  </div>
</template>
```

### 任务3.2: 用户详情页面

```vue
<!-- views/user/detail.vue -->
<template>
  <div class="user-detail">
    <el-row :gutter="20">
      <el-col :span="8">
        <el-card>
          <div class="user-info">
            <el-avatar :size="80" :src="user.avatar_url">
              {{ user.username?.[0]?.toUpperCase() }}
            </el-avatar>
            <h3>{{ user.username }}</h3>
            <p>{{ user.email || '-' }}</p>
            <p>{{ user.phone || '-' }}</p>
            <el-tag :type="user.is_superuser ? 'danger' : 'info'">
              {{ user.is_superuser ? '管理员' : '普通用户' }}
            </el-tag>
          </div>
        </el-card>
      </el-col>
      <el-col :span="16">
        <el-card>
          <template #header>统计数据</template>
          <el-row :gutter="20">
            <el-col :span="8">
              <div class="stat-item">
                <div class="stat-value">{{ user.record_count }}</div>
                <div class="stat-label">记录数</div>
              </div>
            </el-col>
            <el-col :span="8">
              <div class="stat-item">
                <div class="stat-value text-success">¥{{ user.total_income }}</div>
                <div class="stat-label">总收入</div>
              </div>
            </el-col>
            <el-col :span="8">
              <div class="stat-item">
                <div class="stat-value text-danger">¥{{ user.total_expense }}</div>
                <div class="stat-label">总支出</div>
              </div>
            </el-col>
          </el-row>
        </el-card>
      </el-col>
    </el-row>

    <el-card class="mt-20">
      <template #header>最近记录</template>
      <el-table :data="recentRecords">
        <!-- 列定义... -->
      </el-table>
    </el-card>
  </div>
</template>
```

**验收标准**:
- [ ] 用户列表分页正常
- [ ] 搜索筛选正常
- [ ] 用户详情数据完整
- [ ] 禁用/激活功能正常

---

## Day 4: 记录管理 + 日志模块

### 任务4.1: 全局记录列表

```vue
<!-- views/record/list.vue -->
<template>
  <div class="record-list">
    <el-card>
      <!-- 筛选表单 -->
      <el-form inline>
        <el-form-item label="用户">
          <el-select v-model="filters.user_id" placeholder="选择用户" clearable filterable>
            <el-option v-for="u in users" :key="u.id" :label="u.username" :value="u.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="filters.record_type" clearable>
            <el-option label="收入" value="income" />
            <el-option label="支出" value="expense" />
          </el-select>
        </el-form-item>
        <el-form-item label="日期">
          <el-date-picker v-model="dateRange" type="daterange" range-separator="至" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">查询</el-button>
          <el-button @click="handleExport">导出Excel</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card class="mt-20">
      <el-table :data="tableData">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="username" label="用户" />
        <el-table-column prop="category_name" label="分类" />
        <el-table-column prop="amount" label="金额">
          <template #default="{ row }">
            <span :class="row.record_type === 'income' ? 'text-success' : 'text-danger'">
              {{ row.record_type === 'income' ? '+' : '-' }}¥{{ row.amount }}
            </span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="说明" />
        <el-table-column prop="record_date" label="日期" />
        <el-table-column label="操作" width="100">
          <template #default="{ row }">
            <el-button type="danger" link @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>
```

### 任务4.2: 操作日志页面

```vue
<!-- views/log/oper.vue -->
<template>
  <div class="oper-log">
    <el-card>
      <el-form inline>
        <el-form-item label="操作类型">
          <el-select v-model="filters.operation" clearable>
            <el-option label="登录" value="LOGIN" />
            <el-option label="登出" value="LOGOUT" />
            <el-option label="创建" value="CREATE" />
            <el-option label="更新" value="UPDATE" />
            <el-option label="删除" value="DELETE" />
          </el-select>
        </el-form-item>
        <el-form-item label="模块">
          <el-select v-model="filters.module" clearable>
            <el-option label="用户管理" value="用户管理" />
            <el-option label="记录管理" value="记录管理" />
            <el-option label="系统配置" value="系统配置" />
          </el-select>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card class="mt-20">
      <el-table :data="tableData" :default-sort="{ prop: 'created_at', order: 'descending' }">
        <el-table-column prop="username" label="操作用户" />
        <el-table-column prop="operation" label="操作类型">
          <template #default="{ row }">
            <el-tag :type="getOperationType(row.operation)">{{ row.operation }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="module" label="模块" />
        <el-table-column prop="detail" label="详情" show-overflow-tooltip />
        <el-table-column prop="ip_address" label="IP地址" />
        <el-table-column prop="created_at" label="时间" sortable />
      </el-table>
    </el-card>
  </div>
</template>
```

### 任务4.3: 登录日志页面

```vue
<!-- views/log/login.vue -->
<template>
  <div class="login-log">
    <!-- 与操作日志类似，增加登录统计卡片 -->
  </div>
</template>
```

**验收标准**:
- [ ] 记录列表多条件筛选正常
- [ ] Excel导出正常
- [ ] 操作日志展示正常
- [ ] 登录日志展示正常

---

## Day 5: 配置 + 公告模块

### 任务5.1: 系统配置页面

```vue
<!-- views/config/index.vue -->
<template>
  <div class="config-page">
    <el-tabs v-model="activeTab">
      <el-tab-pane label="基础配置" name="basic">
        <el-form :model="config.basic" label-width="150">
          <el-form-item label="应用名称">
            <el-input v-model="config.basic.app_name" />
          </el-form-item>
          <el-form-item label="维护模式">
            <el-switch v-model="config.basic.maintenance_mode" />
          </el-form-item>
          <el-form-item label="每日最大记录数">
            <el-input-number v-model="config.basic.max_records_per_day" :min="1" />
          </el-form-item>
        </el-form>
      </el-tab-pane>
      <el-tab-pane label="AI配置" name="ai">
        <el-form :model="config.ai" label-width="150">
          <el-form-item label="启用AI功能">
            <el-switch v-model="config.ai.ai_enabled" />
          </el-form-item>
          <el-form-item label="启用语音记账">
            <el-switch v-model="config.ai.voice_enabled" />
          </el-form-item>
        </el-form>
      </el-tab-pane>
      <!-- 更多Tab... -->
    </el-tabs>

    <div class="form-actions">
      <el-button type="primary" @click="handleSave">保存配置</el-button>
      <el-button @click="handleReset">重置</el-button>
    </div>
  </div>
</template>
```

### 任务5.2: 公告管理页面

```vue
<!-- views/notice/index.vue -->
<template>
  <div class="notice-page">
    <el-card>
      <template #header>
        <el-button type="primary" @click="handleCreate">新建公告</el-button>
      </template>
      <el-table :data="tableData">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="title" label="标题" />
        <el-table-column prop="notice_type" label="类型">
          <template #default="{ row }">
            <el-tag :type="getNoticeType(row.notice_type)">{{ row.notice_type }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="target_type" label="目标" />
        <el-table-column prop="is_published" label="状态">
          <template #default="{ row }">
            <el-tag :type="row.is_published ? 'success' : 'info'">
              {{ row.is_published ? '已发布' : '草稿' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200">
          <template #default="{ row }">
            <el-button type="primary" link @click="handleEdit(row)">编辑</el-button>
            <el-button type="success" link @click="handlePublish(row)" v-if="!row.is_published">发布</el-button>
            <el-button type="danger" link @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 公告编辑对话框 -->
    <el-dialog v-model="dialogVisible" :title="isEdit ? '编辑公告' : '新建公告'">
      <el-form :model="form" label-width="80">
        <el-form-item label="标题">
          <el-input v-model="form.title" />
        </el-form-item>
        <el-form-item label="内容">
          <el-input v-model="form.content" type="textarea" :rows="4" />
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="form.notice_type">
            <el-option label="通知" value="info" />
            <el-option label="警告" value="warning" />
            <el-option label="重要" value="important" />
          </el-select>
        </el-form-item>
        <el-form-item label="目标">
          <el-select v-model="form.target_type">
            <el-option label="全部用户" value="all" />
            <el-option label="普通用户" value="user" />
            <el-option label="管理员" value="admin" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>
```

**验收标准**:
- [ ] 配置分组展示正常
- [ ] 配置保存/更新正常
- [ ] 公告CRUD正常
- [ ] 公告发布功能正常

---

## 交付物清单

1. ✅ Vue3管理后台项目源码
2. ✅ API调用模块（api/）
3. ✅ 页面组件：
   - 登录页
   - 仪表盘
   - 用户列表/详情
   - 记录列表
   - 操作日志
   - 登录日志
   - 系统配置
   - 公告管理
4. ✅ 单元测试（可选）
5. ✅ 部署配置

---

## 样式规范

### 主题色
```scss
$primary-color: #FF6B6B;      // 珊瑚粉
$success-color: #52C41A;
$danger-color: #FF4D4F;
$warning-color: #FAAD14;
$info-color: #1890FF;

$bg-color: #F5F5F5;
$card-bg: #FFFFFF;
$text-primary: #333333;
$text-secondary: #666666;
```

### 布局
- 侧边栏宽度：200px
- 卡片间距：20px
- 内容区内边距：20px
