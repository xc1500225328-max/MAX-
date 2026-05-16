-- 定义一个名为 LightControlDialog 的 UI 卷展栏
rollout LightControlDialog "V-Ray 灯光控制"
(
    -- 组 1：数值控制 (通过前面的勾选框决定是否应用该项修改)
    group "数值控制 (勾选以应用)"
    (
        -- 亮度控制
        checkbox chk_apply_mult "修改亮度" checked:true across:2 align:#left
        spinner spn_multiplier "" range:[0,100000,30] type:#float width:80 align:#right
        
        -- 色温控制
        checkbox chk_apply_temp "修改色温" checked:true across:2 align:#left
        spinner spn_temperature "" range:[1000,12000,6500] type:#integer width:80 align:#right
        
        -- 方向性控制 (范围0-1，步长设置为0.01)
        checkbox chk_apply_dir "修改方向性" checked:false across:2 align:#left
        spinner spn_directional "" range:[0.0, 1.0, 0.8] type:#float scale:0.01 width:80 align:#right
    )
    
    -- 组 2：属性状态 (直接覆盖选中灯光的状态)
    group "属性控制"
    (
        checkbox chk_invisible "不可见" checked:true align:#left 
        checkbox chk_affect_diffuse "影响漫反射" checked:true align:#left 
        checkbox chk_affect_specular "影响高光" checked:true align:#left 
        checkbox chk_affect_reflections "影响反射" checked:false align:#left 
    )
    
    -- 应用按钮
    button btn_apply "应用到选中灯光" width:200 height:32 align:#center margin:[0,10,0,10]
    
    -- ==================== UI 交互逻辑 ====================
    on chk_apply_mult changed state do spn_multiplier.enabled = state
    on chk_apply_temp changed state do spn_temperature.enabled = state
    on chk_apply_dir changed state do spn_directional.enabled = state

    -- ==================== 执行应用逻辑 ====================
    on btn_apply pressed do
    (
        if selection.count == 0 do
        (
            messageBox "请先在场景中选择灯光！" title:"提示"
            return () 
        )

        local changeCount = 0 
        
        for obj in selection do
        (
            if classOf obj == VRayLight do
            (
                -- 1. 亮度设置
                if chk_apply_mult.checked do obj.multiplier = spn_multiplier.value
                
                -- 2. 色温设置
                if chk_apply_temp.checked do
                (
                    obj.color_mode = 1 
                    obj.color_temperature = spn_temperature.value
                )
                
                -- 3. 方向性设置 (添加了属性检查，防止球形灯等没有该属性的灯光报错)
                if chk_apply_dir.checked do
                (
                    if hasProperty obj "rect_directional" then 
                        obj.rect_directional = spn_directional.value
                )
                
                -- 4. 选项属性设置
                obj.invisible = chk_invisible.checked
                obj.affectDiffuse = chk_affect_diffuse.checked
                obj.affectSpecular = chk_affect_specular.checked
                obj.affectReflections = chk_affect_reflections.checked
                
                changeCount += 1 
            )
        )
        
        messageBox ("已成功处理 " + changeCount as string + " 个 V-Ray 灯光！") title:"完成"
    )
)

-- 如果之前打开了对话框，先关闭它
try(destroyDialog LightControlDialog)catch()

-- 创建并显示对话框
createDialog LightControlDialog width:240 height:310