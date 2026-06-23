# DayDayUp

DayDayUp 是一个面向个人学习成长的 macOS 原生学习执行监督工具。

它不替你制定学习路线，也不自动拆解任务。学习路线、阶段目标和任务内容由使用者自己决定；DayDayUp 负责把已经写下来的学习任务变成可执行、可倒计时、可提醒、可追踪、可复盘的日常系统。

> 一个安静、克制、原生的 macOS 学习执行监督台。

## 核心功能

- 任务录入：记录任务名称、方向、内容、完成标准、资料链接、预计时长和备注。
- Deadline 管理：支持秒级截止时间、快捷 deadline、逾期状态和延期时长计算。
- 启动倒计时：打开应用后优先展示最近一个未完成任务和下一截止任务。
- 今日执行：聚合待完成任务、今日专注时长、逾期未完成数量和任务进度更新。
- 专注计时：按任务开始、暂停、结束学习时段，并沉淀学习备注。
- 提醒系统：使用系统通知提醒截止前和逾期任务；通知不可用时保留 App 内提醒和事件记录。
- 数据评分：展示执行力评分、闭环率、准时率、提前率、补完成率和任务日历。
- 学习历程：按任务归档计划、开始、截止、未按时完成、提醒、补完成、复盘等事件。
- 菜单栏组件：在 macOS 菜单栏查看当前任务倒计时。
- 小组件扩展：输出今日篮子、节奏风险和看板快照。
- 备份恢复：支持 JSON 备份导出、预览和导入合并。

## 技术栈

- SwiftUI
- SwiftData
- UserNotifications
- WidgetKit
- AppIntents
- Swift Testing
- macOS 原生菜单栏和窗口体验

## 运行环境

- macOS
- Xcode 17 或更新版本
- macOS 26 SDK

如果系统默认 `xcode-select` 指向 Command Line Tools，可以临时指定 Xcode：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -list -project DayDayUp.xcodeproj
```

## 本地运行

1. 用 Xcode 打开 `DayDayUp.xcodeproj`。
2. 选择 `DayDayUp` scheme。
3. 选择 `My Mac` 作为运行目标。
4. Build and Run。

命令行构建：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild build \
  -project DayDayUp.xcodeproj \
  -scheme DayDayUp \
  -destination 'platform=macOS'
```

## 测试

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -project DayDayUp.xcodeproj \
  -scheme DayDayUp \
  -destination 'platform=macOS'
```

当前测试覆盖任务状态、deadline 修正、逾期事件、提醒策略、通知授权状态、评分指标、任务日历、学习历程排序、备份恢复和 Widget 快照规则。

## 项目结构

- `DayDayUp/App`：应用入口与全局启动配置。
- `DayDayUp/Models`：SwiftData 模型、任务状态、deadline 和事件定义。
- `DayDayUp/Rules`：评分、日历、里程碑、逾期事件和提醒运行时策略。
- `DayDayUp/Services`：提醒调度、Widget 快照、备份导入导出。
- `DayDayUp/Design`：颜色、玻璃效果、小松鼠状态图和通用样式。
- `DayDayUp/Views`：启动倒计时、今日执行、任务管理、评分、历程、设置和共享组件。
- `DayDayUpWidgetsExtension`：macOS Widget 扩展。
- `DayDayUpTests`：核心规则和数据流测试。
- `docs`：产品定位、交互设计规范、Logo 与小松鼠 IP 简报。
- `design`：Stitch 视觉参考和生成图源，不参与 App 运行时资源加载。

## 产品原则

1. 用户自己规划任务，应用只监督执行。
2. 打开应用后，下一步要做什么必须一眼可见。
3. 倒计时提供压力，但界面不能制造焦虑。
4. 数据看板要具体、克制、可行动。
5. 优先遵循 macOS 原生交互和视觉习惯。

## 非目标

- 自动生成学习路线。
- 自动拆解 GitHub Roadmap。
- 社交打卡、排行榜、群组监督。
- 复杂项目管理，比如甘特图、多人协作、权限管理。
- 过度游戏化，比如大量徽章、积分、等级和动画奖励。

## 文档

- [产品说明](docs/PRODUCT.md)
- [设计规范](docs/DESIGN.md)
- [Logo 与小松鼠 IP 简报](docs/LOGO_IP_BRIEF.md)
