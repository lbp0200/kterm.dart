# TODO — 待修复问题 （已修复 ✅）

> 以下三个 Bug 已在 2026-07-10 修复，详见 `AGENTS.md` 中的提交记录。

## ~~Bug 1: reflow 时 CircularBuffer 空指针~~ ✅ 已修复

**位置**: `lib/src/core/reflow.dart:171` / `lib/src/utils/circular_buffer.dart:105`

**症状**: 快速 resize + reflow 时，`IndexAwareCircularBuffer._getChild(index)!` 返回 null
```
Null check operator used on a null value
  circular_buffer.dart:105  operator[]
  reflow.dart:171           reflow
  buffer.dart:491           Buffer.resize
  terminal.dart:471         Terminal.resize
```

**复现条件**:
- `reflowEnabled: true`
- 反复调用 `terminal.resize(cols, rows)` 且每次宽度变化触发 reflow
- CircularBuffer 几乎满时执行 `insert(0, …)` 操作（当 `_length >= _array.length` 时 `insert` 是空操作，但 `_length` 不增长，后续访问越界元素返回 null）

**可能根因**: `Buffer.resize` 中 height 调整使用 `lines.insert(0, …)`，当 CircularBuffer 已满时 insert 为空操作，但 reflow 仍然遍历 `lines.length` 个元素，其中实际物理数组存在 null slot。

**触发测试**: `test/stress/escape_fuzz_test.dart > resize stress > rapid resize during writes (no crash)`
（当前已缩小 resize 范围以避开此 bug）

---

## ~~Bug 2: eraseDisplayAbove RangeError~~ ✅ 已修复

**位置**: `lib/src/core/buffer/buffer.dart:217` / `lib/src/core/buffer/line.dart:72`

**症状**: `cursorX` 为负值时调用 `eraseLineToCursor` 导致 Uint32List 越界
```
RangeError: Not in inclusive range 0..1023: -5
  line.dart:72       BufferLine.getWidth ← Uint32List.[]
  line.dart:204      BufferLine.eraseRange
  buffer.dart:217    Buffer.eraseLineToCursor
  terminal.dart:706  Terminal.eraseLineLeft
  parser.dart:955    _csiHandleEraseDisplay
```

**复现条件**:
- 某些 CSI 序列（如退格 D、光标移动 H/f）将 `cursorX` 设为了负值
- `Buffer.cursorBack()` 虽然检查了 `< 0` 后设为 0，但某些其他路径可能跳过此检查
- 随后 `\x1b[1J`（erase display above）或 `\x1b[1K`（erase line left）试图用负的 cursorX 访问 line 内部数组

**可能根因**: `Buffer.cursorBack()` 中 `_cursorX -= count` 后检查 `< 0` 并设为 0，但如果 `_cursorX` 初始就是负值（之前就被设错了），则退格操作无法恢复。也可能有其他 CSI 序列直接设置了负的 cursorX，而 `setCursorX` 中的 `clamp(0, …)` 没有被正确调用。

**触发测试**: `test/stress/escape_fuzz_test.dart > escape fuzz > mixed printable + real escape sequences (no crash)`
（当前已去掉 `\x1b[1J` 和 `\x1b[1K` 以避免此 bug）

---

## ~~Bug 3: 快速 resize + reflow 的边界条件~~ ✅ 已修复

除了 Bug 1 之外，快速 resize 还可能触及其他 CircularBuffer 状态不一致问题。`Buffer.resize` 先调整 height（可能触发 `lines.pop()` / `lines.insert()`），再调整 width（触发 reflow），这两个阶段的 lines 状态可能不同步。

**建议修复方向**:
1. `circular_buffer.dart` 中 `operator[]` 将 `_getChild(index)!` 改为带 fallback 的访问，或确保 `_length` 与物理数组一致
2. `buffer.dart` 中 `eraseLineToCursor` / `eraseDisplayToCursor` 增加 `cursorX` / `cursorY` 的边界检查
3. 排查所有设置 `_cursorX` 的路径，确保 `clamp` 覆盖所有情况
