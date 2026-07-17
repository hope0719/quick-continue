# Quick Continue

一键自动输入"继续"并回车，搭配 AI 对话工具使用。

**通用兼容** — 只要输入框支持粘贴 + 回车发送，就能用。微信、豆包、WorkBuddy、Trea、ChatGPT、Kimi、通义千问……任何 AI 聊天窗口都行，不挑软件。

两个平台都会自动保存/恢复剪贴板，不会覆盖你已复制的内容。后台运行，不占资源（macOS 约 2MB 内存，Windows 约 10MB）。启动时自动检查更新，有新版本会静默升级。

如果觉得好用，欢迎给个 Star ⭐

---

## macOS

### 安装

```bash
curl -fsSL https://raw.githubusercontent.com/hope0719/quick-continue/main/install.sh | bash
```

需要 Xcode Command Line Tools（首次运行会提示安装）。安装后自动配置开机启动。

**需要悬浮按钮？** 加 `--button`：

```bash
curl -fsSL https://raw.githubusercontent.com/hope0719/quick-continue/main/install.sh | bash -s -- --button
```

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd+Shift+J` | 触发输入"继续" + 回车 |
| `Cmd+Shift+B` | 显示/隐藏悬浮按钮（--button 模式） |

### 悬浮按钮（--button 模式）

- 左键点击：触发输入
- 拖拽移动：按住拖动到任意位置（每次启动重置到右下角）
- 右键菜单：隐藏按钮（程序继续后台运行，快捷键仍可用）

### 使用说明

- **自动运行**：已添加到登录项，重启电脑后自动启动
- **隐藏按钮**：右键点击按钮 →「隐藏」，或按 `Cmd+Shift+B`
- **重新显示**：按 `Cmd+Shift+B`
- **彻底退出**：`pkill -f quick_continue`（快捷键将同时失效）
- **重新启动**：`open ~/Applications/QuickContinue/QuickContinueLauncher.app`

### 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/hope0719/quick-continue/main/uninstall.sh | bash
```

---

## Windows

### 安装

```powershell
irm https://raw.githubusercontent.com/hope0719/quick-continue/main/install.ps1 | iex
```

需要 Python 3（[下载](https://python.org)，安装时勾选 Add to PATH）。安装后自动配置开机启动。

**需要悬浮按钮？** 运行前设置变量：

```powershell
$button=$true; irm https://raw.githubusercontent.com/hope0719/quick-continue/main/install.ps1 | iex
```

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Alt+J` | 触发输入"继续" + 回车 |

### 悬浮按钮（$button=$true 模式）

- 左键点击：触发输入
- 拖拽移动：按住拖动到任意位置
- 右键菜单：暂停/继续、退出程序

### 使用说明

- **自动运行**：已添加到启动文件夹，登录后自动启动
- **彻底退出**：任务管理器 → 结束 `python` 进程
- **重新启动**：运行 `pythonw "%LOCALAPPDATA%\QuickContinue\quick_continue_win.py"`（加 `--button` 启用悬浮按钮）

### 卸载

```powershell
irm https://raw.githubusercontent.com/hope0719/quick-continue/main/uninstall.ps1 | iex
```

---

## 工作原理

触发后（快捷键或点击）：保存当前剪贴板 → 将"继续"写入剪贴板 → 模拟粘贴（Cmd+V / Ctrl+V）+ 回车 → 恢复原来的剪贴板内容。

macOS 版用 Swift 编译，通过 CGEventTap 监听全局键盘事件，osascript 模拟输入，零第三方依赖。Windows 版纯 Python ctypes 调用 Win32 API，不需要 pip install 任何包。

## 注意事项

- macOS 首次使用需在「系统设置 → 隐私与安全 → 辅助功能」中允许终端应用
- 确保目标窗口的输入框已获得焦点

## 手动运行

不想安装为服务，也可以直接运行：

```bash
# macOS（仅快捷键）
git clone https://github.com/hope0719/quick-continue.git
cd quick-continue
swiftc -O -framework CoreGraphics -framework AppKit -o quick_continue src/mac/quick_continue.swift
./quick_continue

# macOS（快捷键 + 悬浮按钮）
./quick_continue --button
```

```powershell
# Windows（仅快捷键）
git clone https://github.com/hope0719/quick-continue.git
cd quick-continue
python src/windows/quick_continue_win.py

# Windows（快捷键 + 悬浮按钮）
python src/windows/quick_continue_win.py --button
```

## License

MIT
