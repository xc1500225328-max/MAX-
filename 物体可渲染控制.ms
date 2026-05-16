try(destroydialog roll_RenderableControl)catch()

rollout roll_RenderableControl "Vantage 对象控制" width:200
(
    group "操作 (Operation)"
    (
        button btn_on "开启可渲染 (Set ON)" width:160 height:30 toolTip:"开启渲染并强制刷新 Vantage"
        button btn_off "关闭可渲染 (Set OFF)" width:160 height:30 toolTip:"关闭渲染并强制刷新 Vantage"
        button btn_toggle "反转状态 (Toggle)" width:160 height:30 toolTip:"切换状态并强制刷新 Vantage"
    )
    
    group "信息 (Info)"
    (
        label lbl_status "请选择物体..." align:#center
    )

    -- 辅助函数：更新标签并强制刷新
    -- 这里的 move [0,0,0] 就是用来欺骗 Vantage 进行更新的
    fn forceUpdate obj = (
        move obj [0,0,0] 
    )

    fn updateLabel count actionStr = (
        lbl_status.text = "已更新 " + (count as string) + " 个对象: " + actionStr
    )

    -- 按钮：开启
    on btn_on pressed do
    (
        if selection.count > 0 then
        (
            undo "Set Renderable ON" on
            (
                for obj in selection do 
                (
                    obj.renderable = true
                    forceUpdate obj -- 移动0操作
                )
            )
            updateLabel selection.count "开启"
        )
        else (lbl_status.text = "未选择任何对象")
    )

    -- 按钮：关闭
    on btn_off pressed do
    (
        if selection.count > 0 then
        (
            undo "Set Renderable OFF" on
            (
                for obj in selection do 
                (
                    obj.renderable = false
                    forceUpdate obj -- 移动0操作
                )
            )
            updateLabel selection.count "关闭"
        )
        else (lbl_status.text = "未选择任何对象")
    )

    -- 按钮：切换
    on btn_toggle pressed do
    (
        if selection.count > 0 then
        (
            undo "Toggle Renderable" on
            (
                for obj in selection do 
                (
                    obj.renderable = not obj.renderable
                    forceUpdate obj -- 移动0操作
                )
            )
            updateLabel selection.count "切换"
        )
        else (lbl_status.text = "未选择任何对象")
    )
)

createDialog roll_RenderableControl