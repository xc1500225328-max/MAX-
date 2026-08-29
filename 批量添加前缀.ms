try(destroyDialog rol_BatchAddPrefix) catch()

-- 标签修改弹窗
global rol_BatchAddPrefix_RenameDialog
global g_BatchPrefix_RenameVal = ""

rollout rol_BatchAddPrefix_RenameDialog "修改标签名称" width:220 height:85
(
    edittext edt_newVal "新名称:" pos:[10,15] width:195 text:""
    button btn_ok "确定" pos:[25,48] width:75 height:24 default:true
    button btn_cancel "取消" pos:[120,48] width:75 height:24

    on rol_BatchAddPrefix_RenameDialog open do
    (
        edt_newVal.text = g_BatchPrefix_RenameVal
        setFocus edt_newVal
    )
    
    on btn_ok pressed do
    (
        g_BatchPrefix_RenameVal = edt_newVal.text
        destroyDialog rol_BatchAddPrefix_RenameDialog
    )
    
    on btn_cancel pressed do
    (
        g_BatchPrefix_RenameVal = undefined
        destroyDialog rol_BatchAddPrefix_RenameDialog
    )
)

-- 主界面
rollout rol_BatchAddPrefix "批量添加前缀工具 (含预设)" width:282 height:215
(
    -- 配置文件路径 (保存在本地配置文件夹)
    local iniPath = (getDir #plugcfg) + @"\BatchPrefixTool_Tags.ini"
    local defaultTags = #("GEO_", "SM_", "SK_", "CAM_", "LGT_", "DUMMY_", "GRP_", "REF_")
    
    -- UI 控件
    edittext edt_prefix "前缀内容:" pos:[10,12] width:262 labelOnTop:false text:""
    button btn_apply "为当前选中项添加前缀" pos:[10,42] width:262 height:30 tooltip:"手动输入前缀后点击应用"
    
    groupBox grp_tags "快捷预设标签 (左键使用 / 右键更名)" pos:[10,78] width:262 height:100
    
    -- 8个预设按钮 (使用 DotNet 控件以支持鼠标左/右键分别响应)
    dotNetControl btn_t1 "System.Windows.Forms.Button" pos:[18,100] width:57 height:28
    dotNetControl btn_t2 "System.Windows.Forms.Button" pos:[79,100] width:57 height:28
    dotNetControl btn_t3 "System.Windows.Forms.Button" pos:[140,100] width:57 height:28
    dotNetControl btn_t4 "System.Windows.Forms.Button" pos:[201,100] width:57 height:28
    
    dotNetControl btn_t5 "System.Windows.Forms.Button" pos:[18,136] width:57 height:28
    dotNetControl btn_t6 "System.Windows.Forms.Button" pos:[79,136] width:57 height:28
    dotNetControl btn_t7 "System.Windows.Forms.Button" pos:[140,136] width:57 height:28
    dotNetControl btn_t8 "System.Windows.Forms.Button" pos:[201,136] width:57 height:28
    
    label lbl_tip "提示: 左键应用 | 右键更名 | 支持 Ctrl+Z 撤销" pos:[10,188] width:262
    
    -- 执行添加前缀逻辑
    fn executeAddPrefix prefixStr =
    (
        if prefixStr == undefined or prefixStr == "" do return false
        local sel = selection as array
        
        if sel.count == 0 then
        (
            displayTempPrompt "已将前缀填入输入框 (未选中任何物体)" 2500
            return false
        )
        
        undo "批量添加前缀" on
        (
            for obj in sel do
            (
                obj.name = prefixStr + obj.name
            )
        )
        displayTempPrompt ("已成功为 " + (sel.count as string) + " 个对象添加前缀: " + prefixStr) 3000
    )
    
    -- 初始化按钮文本及样式
    fn initBtn btn index =
    (
        local savedTag = getINISetting iniPath "Tags" ("Tag_" + index as string)
        if savedTag == "" do savedTag = defaultTags[index]
        
        btn.text = savedTag
        btn.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Standard
        btn.UseVisualStyleBackColor = true
        btn.Margin = dotNetObject "System.Windows.Forms.Padding" 1
    )
    
    -- 统一处理标签点击事件
    fn handleTagEvent index btnCtrl mouseEvent =
    (
        -- 右键更名
        if mouseEvent.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right then
        (
            g_BatchPrefix_RenameVal = btnCtrl.text
            createDialog rol_BatchAddPrefix_RenameDialog modal:true
            if g_BatchPrefix_RenameVal != undefined and g_BatchPrefix_RenameVal != "" do
            (
                btnCtrl.text = g_BatchPrefix_RenameVal
                setINISetting iniPath "Tags" ("Tag_" + index as string) g_BatchPrefix_RenameVal
            )
        )
        -- 左键使用
        else if mouseEvent.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left then
        (
            edt_prefix.text = btnCtrl.text
            executeAddPrefix btnCtrl.text
        )
    )
    
    -- 窗口打开时初始化
    on rol_BatchAddPrefix open do
    (
        local btnList = #(btn_t1, btn_t2, btn_t3, btn_t4, btn_t5, btn_t6, btn_t7, btn_t8)
        for i = 1 to btnList.count do initBtn btnList[i] i
    )
    
    -- 主按钮事件
    on btn_apply pressed do
    (
        local prefixStr = edt_prefix.text
        if prefixStr == "" then
        (
            messageBox "前缀内容不能为空！" title:"提示"
            return false
        )
        if (selection as array).count == 0 then
        (
            messageBox "请先在场景中选择需要重命名的物体或组！" title:"提示"
            return false
        )
        executeAddPrefix prefixStr
    )
    
    -- 8 个预设标签的鼠标事件绑定
    on btn_t1 MouseUp sender e do handleTagEvent 1 btn_t1 e
    on btn_t2 MouseUp sender e do handleTagEvent 2 btn_t2 e
    on btn_t3 MouseUp sender e do handleTagEvent 3 btn_t3 e
    on btn_t4 MouseUp sender e do handleTagEvent 4 btn_t4 e
    on btn_t5 MouseUp sender e do handleTagEvent 5 btn_t5 e
    on btn_t6 MouseUp sender e do handleTagEvent 6 btn_t6 e
    on btn_t7 MouseUp sender e do handleTagEvent 7 btn_t7 e
    on btn_t8 MouseUp sender e do handleTagEvent 8 btn_t8 e
)

createDialog rol_BatchAddPrefix