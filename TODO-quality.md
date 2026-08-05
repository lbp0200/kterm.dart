# TODO — 质量改进项（2026-07 审计）

> 基于 2026-07 代码质量审计（`dart analyze` 0 问题 + 独立 subagent 审计 + pub.dev score 140/160）。
> 状态标记：⬜ 未做 / 🔨 进行中 / ✅ 已完成

## 一、pub.dev 评分（140/160 → 目标 ≥150）

- [x] **P1 · example 未打包导致丢 10 分** — `example/` 在仓库存在，但被 `.pubignore` 排除，pub.dev 判定"无 example"。
  修复：`.pubignore` 保留 `example/lib` + `example/pubspec.yaml`，排除 `example/build`（635M）、平台目录、assets/fonts、pubspec.lock。
- [x] **P2 · 公共 API 文档覆盖率仅 25.8%**（丢 10 分，要求 ≥20% 得满分 10 分但当前 25.8% 只得了 10/20——因为 example 缺失扣的是另 10 分，文档部分本身 10/10 已满足。核对：pub score 显示 Documentation 10/20 = dartdoc 10/10 + example 0/10。**因此文档达标，example 是唯一文档分缺口**）
  ⚠️ 更正：按 pana 明细，dartdoc 覆盖率 25.8% 已满足 20% 阈值（10/10）。文档缺口不影响评分，但影响开发者体验，仍值得补：
  - [x] `lib/src/core/escape/handler.dart` — `EscapeHandler` 130+ 接口方法零 dartdoc（最痛）
  - [x] `lib/src/core/graphics_manager.dart` — 30+ 公开方法无 doc（已补字段/构造器 doc）
  - [x] `lib/src/ui/controller.dart` — `TerminalController` 30+ 公开成员无 doc
  - [x] `lib/src/core/buffer/buffer.dart` — 约 25 个公开成员无 doc

## 二、健壮性（subagent 审计发现，无高危，中低危为主）

- [x] **P2 · keytab 解析器损坏输入崩溃** — `lib/src/core/input/keytab/keytab_parse.dart:96/153/157` 等处在 token 流截断时对 `null` 做 `!` 解包，抛 `TypeError` 而非 `ParseError`。修复 + 补损坏输入测试。
- [x] **P3 · `Observable.notifyListeners` 缺快照保护** — `lib/src/base/observable.dart:12` 直接遍历 `_listeners`，通知期间 add/removeListener 会抛 `ConcurrentModificationError`（对比 Flutter `ChangeNotifier` 的 `_listenersToNotify` 快照）。修复 + 补测试（现有测试 `'Given listener removed during notification...'` 是空用例，无断言）。
- [x] **P3 · `circular_buffer.dart:265` `swap()` 越界空解包** — `swap()` 的 `result!` 无 `RangeError.checkValueInInterval`（对比 `operator []` 有检查）。当前调用点数学上安全，但需防御。
- [x] **P3 · `line.dart:440/445` `CellAnchor` 用 assert 保护 detached 访问** — release 模式下 assert 被剥离，detached 访问直接空解包。应改为显式 `StateError`。
- [x] **P4 · `zmodem.dart` 异步 `_session!` 竞态** — `_reset()` 置 `_session = null` 后，异步事件链（`_handleZModem` await 后）仍解包 `_session!` 会崩。需要先判空再处理。
  修复：`_handleZModem`/`_handleFileAcceptedEvent`（await 前后 `identical(_session, session)` 防御）/`_moveToNextOffer`/`_closeSession`/`_createRemoteOffer` 回调全部判空。
- [x] **P4 · `controller.dart:338` catch 范围过大** — catch 包裹整个匹配循环（含 `_textOffsetToCellOffset`），会吞掉真正的 bug。
  修复：catch 只包 `RegExp` 编译，匹配循环异常不再被吞。

## 三、API 一致性

- [x] **P2 · `GraphicsManager` 是"暗 API"** — `terminal.dart:185` 公开字段 `late final GraphicsManager graphicsManager` 的类型未从 `core.dart`/`kterm.dart` export，包外使用者无法命名该类型。补 export。
- [x] **P3 · `terminal.dart:464` `resize` doc 过期** — 声称 "Text reflow is currently not implemented"，但 reflow 已实现（`buffer.dart` + `reflow_test.dart`）。更新 doc。

## 四、测试盲区

- [x] **P2 · `keytab_default.dart`（约 700 行默认按键布局）零直接测试** — 只有 `KeytabInputHandler` 间接覆盖。补：解析 `defaultKeytab` 不抛错 + 关键映射断言。
- [x] **P4 · `cell_flags.dart` 测试重复** — `test/src/core/buffer/cell_flags_test.dart` 与 `test/src/core/cell_flags_test.dart` 两份，去重。
  处理：合并到 `buffer/cell_flags_test.dart`（11 用例，含双方独有断言），删除旧文件。

## 五、代码结构（长期，风险高）

- [ ] **P5 · `terminal.dart` 1730 行超长** — ⚠️ 2026-08 验证：**Dart 语言限制，类无法跨 `part` 文件分片**（part 文件中的方法会变成顶层函数，无法访问类私有成员，analyzer 报 Undefined name）。唯一可行路径是把 EscapeHandler 实现改为 mixin 并提升 ~20 个私有字段——结构性大重构，风险远超收益，本轮放弃。保留单文件，待大规模重构专项处理。
- [x] **P5 · `terminal_view.dart` 重复分支** — `!widget.hardwareKeyboardOnly` 分支重复 4 次（282/308/445/577），提取辅助方法。
  实际仅 2 处（282 build 树分支保留，445 提取为 `_requestKeyboardFocus`）。
- [x] **P5 · `painter.dart:418-482` 反复 `_graphicsManager!`** — 字段无法 promote，用局部变量消除。
  处理：`renderBelowImages`/`renderAboveImages` 合并为 `_renderImages`（overlay + filterQuality 参数），消除全部 `_graphicsManager!` 与约 60 行重复。

## 六、已知风险与经验教训（v1.5.4 发布复盘）

- [ ] **P3 · `Terminal.write()` plain-text fast path 的副作用盲区** — `ac78686`（2026-07-10）引入的 fast path 直接调 `_buffer.write(data)`，绕过 `writeChar`，连踩两个回归（v1.5.4 发布时才发现，CI 自 7-10 起一直红着）：
  1. C0 控制字符（`\r\n`/`\t` 等）被 `Buffer.writeChar` 过滤 → 换行丢失，破坏 line wrap / insertLines / deleteLines（已修复：fast path 增加 `_hasC0Control` 检查）
  2. `_precedingCodepoint` 不更新 → CSI `n b`（REP）失效（已修复：fast path 用 `data.runes.last` 同步）
  **经验：再做批量写优化前，先审计 `writeChar` 的全部副作用**（除 `_precedingCodepoint` 外，还有 `_buffer.writeChar` 内部的宽字符边界处理、`charset.translate` 等），并给 fast path 补"绕过路径语义等价"的专项测试。
