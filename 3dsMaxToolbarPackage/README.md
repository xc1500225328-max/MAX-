# 3ds Max 工具条安装包

## 安装

1. 打开 3ds Max。
2. 执行 `Scripting > Run Script...`。
3. 选择工作目录里的 `安装到3dsMax工具条.ms`。
4. 安装完成后，打开 `Customize > Customize User Interface > Toolbars`。
5. 在 `Category` 里选择 `编码助手工具`，把下面 7 个命令拖到任意工具条：
   - `ACES v14.3`
   - `灯光`
   - `材质合并`
   - `组排序`
   - `渲染`
   - `相机`
   - `跳帧`

如果图标没有立即显示，重启 3ds Max 后再查看工具条。

## 安装内容

- 原 `.ms` 脚本会复制到当前 3ds Max 版本的用户脚本目录：
  `getDir #userScripts + "\\EncodingAssistantTools\\"`
- 工具条宏命令会写入用户宏命令目录：
  `getDir #userMacros + "\\编码助手工具-Macros.mcr"`
- PNG 图标会复制到当前 3ds Max 版本的用户图标目录：
  `getDir #userIcons + "\\Dark\\EncodingAssistantTools\\"`
  `getDir #userIcons + "\\Light\\EncodingAssistantTools\\"`

## 图标规则

宏命令使用 Max 2017+ 的 `iconName` 机制，例如：

```maxscript
iconName:"EncodingAssistantTools/ca_aces"
```

每个图标提供 `24/30/36/48` 四种 PNG 尺寸，适配常见 DPI。
