try(destroyDialog EmissionController)catch()

rollout EmissionController "自发光强度统一控制器" width:320 height:140 (
    label lbl_info "支持 VRay 和 Corona 的专属灯光材质\n以及普通物理材质的自发光倍增通道" align:#center offset:[0,10]
    
    spinner spn_targetVal "目标强度值: " range:[0.0, 10000.0, 1.0] type:#float scale:0.1 align:#center offset:[0,10]
    button btn_apply "一键修改全局自发光强度" width:280 height:35 offset:[0,10]

    -- 【修复点】：将核心函数提升到 Rollout 层级，并将数组作为参数传入
    fn processMat m propName val matArray = (
        if hasProperty m propName do (
            setProperty m propName val
            appendIfUnique matArray m
        )
    )

    on btn_apply pressed do (
        -- 开启撤销记录，支持 Ctrl+Z 退回
        undo "修改自发光强度" on (
            local targetValue = spn_targetVal.value
            local modifiedMats = #()
            
            -- 1. VRayLightMtl (VRay 灯光材质)
            if VRayLightMtl != undefined do (
                for m in (getClassInstances VRayLightMtl) do processMat m "multiplier" targetValue modifiedMats
            )
            
            -- 3. CoronaLightMtl (CR 灯光材质)
            if CoronaLightMtl != undefined do (
                for m in (getClassInstances CoronaLightMtl) do processMat m "intensity" targetValue modifiedMats
            )

            messageBox ("全局自发光重置完成！\n\n共找到了 " + (modifiedMats.count as string) + " 个相关材质\n并将它们的强度统一修改为了：" + (targetValue as string)) title:"修改成功"
        )
    )
)

-- 创建并显示窗口
createDialog EmissionController