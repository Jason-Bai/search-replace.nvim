# Search-Replace.nvim Production Roadmap

## Phase 1: 基础设施 (Foundation)

### 1.1 Plugin Entry Point

- [x] 创建 `plugin/search-replace.lua` 入口文件
- [x] 添加加载保护 (防止重复加载)

### 1.2 User Configuration System

- [x] 创建 `lua/search-replace/config.lua` 配置模块
- [x] 支持自定义快捷键
- [x] 支持自定义窗口大小
- [x] 支持自定义 ripgrep 参数

### 1.3 Health Check

- [x] 创建 `lua/search-replace/health.lua`
- [x] 检测 ripgrep 是否安装
- [x] 检测依赖 (nui.nvim, plenary.nvim)

---

## Phase 2: 测试完善 (Testing)

### 2.1 Core Module Tests

- [x] 验证现有 `builder_spec.lua` 通过
- [x] 验证现有 `parser_spec.lua` 通过
- [x] 添加 `grouper_spec.lua`
- [x] 验证现有 `state_spec.lua` 通过
- [x] 验证现有 `diff_spec.lua` 通过

### 2.2 Integration Tests

- [x] 创建 `integration_spec.lua`
- [x] 测试搜索流程
- [x] 测试替换流程
- [x] 测试文件选择/取消选择

---

## Phase 3: 文档 (Documentation)

### 3.1 README.md

- [x] 功能介绍
- [x] 安装说明 (lazy.nvim, packer, vim-plug)
- [x] 配置选项
- [x] 快捷键说明
- [x] 依赖说明
- [ ] 截图/GIF

### 3.2 Vim Help

- [x] 创建 `doc/search-replace.txt`
- [x] 生成 help tags

### 3.3 其他文档

- [x] LICENSE (MIT)
- [x] CHANGELOG.md

---

## Phase 4: 错误处理与兼容性 (Robustness)

### 4.1 Error Handling

- [x] ripgrep 未安装时的友好提示
- [x] 文件权限错误处理
- [x] 无效正则表达式提示

### 4.2 Cross-Platform

- [x] Windows 路径兼容
- [x] 命令转义兼容
- [x] 测试 Linux/macOS/Windows

---

## Phase 5: 代码质量 (Code Quality)

### 5.1 Formatting & Linting

- [x] 添加 `stylua.toml`
- [ ] 添加 `.luacheckrc` 或 `selene.toml`
- [x] 格式化所有代码

### 5.2 CI/CD

- [x] 创建 `.github/workflows/ci.yml`
- [x] 自动运行测试
- [x] 自动 lint 检查

### 5.3 Type Annotations

- [x] 添加 LuaLS 类型注解
- [x] 完善函数文档注释

---

## Phase 6: 功能增强 (Optional)

### 6.1 UX Improvements

- [x] 搜索历史记录
- [x] Undo 支持
- [ ] 异步搜索 (大项目)

### 6.2 UI Enhancements

- [x] 可配置颜色
- [x] 文件图标 (nvim-web-devicons)
- [x] 预览语法高亮

---

## Execution Order

```
Phase 1.1 → Phase 2.1 (验证现有测试) → Phase 1.2 → Phase 1.3
    ↓
Phase 3.1 (README) → Phase 3.3 (LICENSE)
    ↓
Phase 4.1 → Phase 5.1 → Phase 5.2
    ↓
Phase 3.2 (Vim Help) → Phase 6 (Optional)
```

---

## Current Status

**已完成功能:**

- ✅ 基本搜索 (ripgrep)
- ✅ 预览 (上下文 / Diff)
- ✅ 文件分组显示
- ✅ 文件选择/取消选择 (Space)
- ✅ 执行替换 (C-r)
- ✅ Tab/Shift-Tab 导航
- ✅ Placeholder 提示
- ✅ Flags/Filter 支持 glob

**待改进:**

- ⏳ 用户配置系统
- ⏳ 错误处理
- ⏳ 文档
- ⏳ 测试覆盖
