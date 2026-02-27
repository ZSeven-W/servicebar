# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
swift build                # 开发构建
swift build -c release     # 发布构建
swift run ServiceBar       # 本地运行
```

打包产物位于 `dist/ServiceBar.app`，分发包为 `dist/ServiceBar.zip`。

## Architecture

macOS 菜单栏应用（LSUIElement），使用 NSPopover 展示主界面，无 Dock 图标。

### Data Flow

```
lsof + ps (系统命令)
  → ServiceScanner (后台线程解析)
    → [ServiceInfo] (@Published)
      → StatusBarView (Combine 订阅，按组分类渲染)
        → ServiceRowView (单条服务卡片)
```

- **扫描**: `ServiceScanner` 在后台队列调用 `lsof -iTCP -sTCP:LISTEN` + `ps` 获取进程信息
- **发布**: 解析结果通过 `@Published var services` 推送到 UI
- **分组**: `StatusBarView.getGroupedData()` 按 `smartName` 聚合为 `AppGroup`，支持搜索/端口范围/标签过滤
- **进程控制**: 通过 `/bin/kill`(停止)、`/bin/zsh -c`(启动/重启) 管理进程

### Key Modules

```
Sources/ServiceBar/
├── ServiceBarApp.swift            # App 入口, AppDelegate, 状态栏 & Popover 管理
├── Models/
│   └── ServiceInfo.swift          # 服务数据模型 (pid, port, command, smartName...)
├── Services/
│   ├── ServiceScanner.swift       # 核心扫描引擎, 进程控制, 定时刷新
│   ├── HiddenItemsManager.swift   # 隐藏项持久化 (UserDefaults 单例)
│   └── GroupAliasManager.swift    # 分组别名 & 标签系统 (UserDefaults 单例)
├── Views/
│   ├── StatusBarView.swift        # 主弹窗 UI, 分组/过滤/拖拽排序
│   ├── ServiceRowView.swift       # 服务卡片 (停止/重启/隐藏/复制)
│   ├── SettingsView.swift         # 设置面板
│   └── RefreshButton.swift        # 刷新按钮组件
└── Resources/
    ├── Info.plist                  # Bundle 元数据 (v0.0.1)
    └── AppIcon.png
```

### State Management

- `@Published` — ServiceScanner 的响应式数据
- `@AppStorage` — 用户设置持久化 (UserDefaults)
- `HiddenItemsManager.shared` / `GroupAliasManager.shared` — 单例管理持久状态
- `@State` — 视图局部状态 (折叠、搜索、拖拽、已停止服务)

### Styling

- 原生 macOS SwiftUI，使用系统颜色
- 端口号: `.orange`, 粗体等宽字体
- 操作反馈: `.green`(成功/复制), `.red`(停止/危险)
- 标签色: DEV(橙) SYS(蓝) APP(绿) DB(紫) WEB(红)
- 字体: 系统字体 10-13pt，等宽用于端口/PID/路径
- 卡片: 圆角矩形(6pt)，quaternary 填充

## Code Style

- 单个文件不要超过 800 行。超出时应拆分为更小的模块。
- 每个文件只导出一个组件，每个组件只承担单一职责。
- Swift 5.9 兼容，不使用 async/await，并发通过 GCD + Combine 实现。

## Git Commit 规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
<type>(<scope>): <subject>

<body>
```

### Type

- `feat` — 新功能
- `fix` — Bug 修复
- `refactor` — 重构（不改变行为）
- `perf` — 性能优化
- `style` — 代码格式（不影响逻辑）
- `docs` — 文档
- `test` — 测试
- `chore` — 构建/工具/依赖变更

### Scope

按模块划分：`app`、`scanner`、`views`、`settings`、`models`。

### 规则

- subject 用英文，小写开头，不加句号，祈使语气（如 `add`、`fix`、`remove`）。
- body 可选，解释 **why** 而非 what，可用中英文。
- 一个 commit 只做一件事。不要把不相关的改动混在一起。

## License

MIT License. See [LICENSE](./LICENSE) for details.
