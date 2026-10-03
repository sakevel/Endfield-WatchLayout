# Endfield Watch Layout / ESC 菜单整理

适用于《明日方舟：终末地》的 ESC 主菜单布局自定义模组。提供原生风格的全屏可视化拖拽编辑器，让你可以自由调整主菜单中各项功能的排列顺序与可见性。

---

## 功能特性

- **可视化拖拽编辑**：在游戏内提供原生风格的拖拽配置界面，直接抓取功能卡片移动排序，松开鼠标自动保存。
- **自由分区管理**：支持在左侧大卡槽位、右侧双列按钮区以及隐藏区之间自由拖动卡片，可隐藏不常用的入口。
- **原生逻辑完整保留**：仅调整入口的排版与呈现，按钮的原生解锁条件、红点提示与点击跳转逻辑均不受影响。
- **即时生效**：保存后返回 ESC 菜单即可立即查看调整后的布局，无需重启游戏。

---

## 使用方法

1. 确保已安装 `Endfield-ModLoader` 与 `Endfield-ModMenu`。
2. 游戏内按 `ESC` →「模组菜单」→「ESC 菜单整理」→「模组配置」打开全屏编辑器。
3. 鼠标按住任意卡片拖动到目标位置；拖入右下角的「已隐藏」区域即可隐藏对应按钮。
4. 调整完毕后，点击左上角返回或按 `ESC` 即可应用新布局。

> **提示**：若不小心隐藏了「模组菜单」本身，可在退出游戏后在 `%LOCALAPPDATA%\EndfieldModLoader\mods\watch-layout\config.ini` 中将 `enabled` 改为 `false`，即可恢复游戏默认菜单排布。

---

## 构建与安装

### 构建

```powershell
.\tools\build.ps1
.\tools\package.ps1
```

构建产物位于 `build/package/Release/watch-layout`。

### 安装

退出游戏后，使用 ModLoader 的安装工具进行部署：

```powershell
..\Endfield-ModLoader\tools\install-mod.ps1 -ModPackage .\build\package\Release\watch-layout
```
