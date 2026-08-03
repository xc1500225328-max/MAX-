# 3dsmax-tools

一组面向 3ds Max / V-Ray 工作流的 MaxScript 小工具，包含工具条安装脚本和自定义图标。

## 工具列表

- `ACES转换脚本.ms`：VRay ACEScg 位图/材质辅助转换，支持 VRayColor 原色和 V-Ray GPU 凹凸兼容修复。
- `灯光控制.ms`：批量控制选中 V-Ray 灯光，并统一修改 VRay/Corona 材质的全局自发光强度。
- `材质合并.ms`：扫描重复材质，并通过两步确认流程安全合并。
- `组排序.ms`：统计并排序场景组，支持清理仅包含一个对象的组。
- `物体可渲染控制.ms`：批量切换选中物体的 `renderable` 状态。
- `相机列表VR专用版.ms`：VRayPhysicalCamera 管理、分辨率预设和命名辅助。
- `跳转帧.ms`：按指定步长前后跳转时间轴帧。

## 安装到 3ds Max 工具条

1. 打开 3ds Max。
2. 执行 `Scripting > Run Script...`。
3. 选择仓库根目录下的 `安装到3dsMax工具条.ms`。
4. 安装完成后打开 `Customize > Customize User Interface > Toolbars`。
5. 在 `Category` 中选择 `编码助手工具`，把需要的命令（包括 `ACES v14.3`）拖到任意工具条。

如果图标没有立即刷新，请重启 3ds Max。若旧按钮仍显示旧图标，删除工具条上的旧按钮后从 `编码助手工具` 分类重新拖入。

## 更新

拉取或下载新版本后，重新运行 `安装到3dsMax工具条.ms` 即可覆盖安装脚本、宏命令和图标。安装器会把文件复制到当前 3ds Max 用户配置目录：

- 脚本：`getDir #userScripts + "\\EncodingAssistantTools\\"`
- 宏命令：`getDir #userMacros + "\\编码助手工具-Macros.mcr"`
- 图标：`getDir #userIcons + "\\Dark\\EncodingAssistantTools\\"` 和 `getDir #userIcons + "\\Light\\EncodingAssistantTools\\"`

## 目录结构

```text
.
├── *.ms
├── 安装到3dsMax工具条.ms
└── 3dsMaxToolbarPackage/
    ├── README.md
    ├── icons/
    └── icons_preview_dark.png
```

## License

MIT License
