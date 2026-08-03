(
    undo "修改VRayColor原色模式" on 
    (
        local vrayColorMaps = getClassInstances VRayColor
        local changedCount = 0
        
        for vmap in vrayColorMaps do
        (
            -- 检查属性是否存在
            if hasProperty vmap "rgb_primaries" do
            (
                -- 0 = None(无) / 1 = sRGB / 2 = ACEScg
                vmap.rgb_primaries = 0
                changedCount += 1
            )
        )
        
        -- 弹出完成提示框
        messageBox ("处理完成！\n\n共将 " + changedCount as string + " 个 VRayColor 贴图的 [RGB 原色] 修改为了“无”。") title:"脚本执行结果"
    )
)