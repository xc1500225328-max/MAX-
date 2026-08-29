try(destroyDialog AdvancedMatMerger) catch()

rollout AdvancedMatMerger "智能材质合并工具 (专业统计版)" width:320 height:350
(
    -- ==================== 存储数据的变量 ====================
    local mergePairs_cache = #()    -- 缓存要合并的材质对，格式：#( 旧材质, 新材质 )
    local targetObjs_cache = #()    -- 缓存要处理的物体（当勾选“仅处理当前显示”时）
    local isTargetedScope = true    -- 记录扫描时“仅处理当前显示”是否被勾选

    -- ==================== UI 界面设计 ====================
    groupBox grp1 "1. 合并条件 (必须满足所勾选的所有条件)" pos:[10,10] width:300 height:95
    checkbox chk_name "同名 (材质名称必须一致)" checked:false pos:[25,30]
    checkbox chk_param "同参数 (颜色、反射等所有数值一致)" checked:true pos:[25,55]
    checkbox chk_tex "同贴图 (贴图路径、贴图参数一致)" checked:true pos:[25,80]
    
    groupBox grp2 "2. 作用范围" pos:[10,115] width:300 height:70
    checkbox chk_visible "仅处理【当前显示的物体】" checked:true pos:[25,135]
    label lbl_tip "注：勾选后，隐藏模型和关闭图层的材质不受影响" pos:[25,155] style_sunkenedge:false
    
    button btn_scan "第一步: 扫描分析" pos:[10,195] width:145 height:40
    button btn_merge "第二步: 确认合并" pos:[165,195] width:145 height:40 enabled:false
    
    button btn_sel_dup "选择含重复材质的模型" pos:[10,245] width:300 height:30 enabled:false
    
    progressBar pb_bar "进度" pos:[10,285] width:300 height:15 color:green value:0
    label lbl_status "等待操作..." pos:[10,305] width:300 align:#center

    -- ==================== 核心逻辑函数 ====================
    
    -- 收集某物体身上包含的所有材质
    fn collectAllMats mat &matArray visited: = (
        if visited == unsupplied do visited = #()
        if mat == undefined do return OK
        if findItem visited mat > 0 do return OK
        
        append visited mat
        appendIfUnique matArray mat
        
        for i = 1 to getNumSubMtls mat do (
            local subMat = getSubMtl mat i
            collectAllMats subMat &matArray visited:visited
        )
    )

    -- 深度对比函数
    fn compareMats m1 m2 checkName checkParam checkTex depth:0 = (
        if depth > 10 do return false 
        if m1 == m2 do return true
        if m1 == undefined or m2 == undefined do return false
        if classof m1 != classof m2 do return false
        
        if checkName and (m1.name != m2.name) do return false
        if not checkParam and not checkTex do return true
        
        local props = getPropNames m1
        for p in props do (
            if p == #name do continue
            
            local v1, v2
            try (
                v1 = getProperty m1 p
                v2 = getProperty m2 p
            ) catch ( continue )
            
            if classof v1 != classof v2 do return false
            
            if isKindOf v1 TextureMap then (
                if checkTex do (
                    if not (compareMats v1 v2 checkName checkParam checkTex depth:(depth+1)) do return false
                )
            )
            else if isKindOf v1 Material then (
                if not (compareMats v1 v2 checkName checkParam checkTex depth:(depth+1)) do return false
            )
            else (
                if checkParam do (
                    if classof v1 == Float then (
                        if (abs (v1 - v2)) > 0.001 do return false
                    )
                    else if classof v1 == Array then (
                        if v1.count != v2.count do return false
                        for i = 1 to v1.count do ( if v1[i] != v2[i] do return false )
                    )
                    else (
                        if v1 != v2 do return false
                    )
                )
            )
        )
        return true
    )

    -- 仅替换目标物体身上的材质（及其子材质）
    fn replaceSubMat targetMat mOld mNew visited: = (
        if visited == unsupplied do visited = #()
        if findItem visited targetMat > 0 do return OK
        append visited targetMat
        
        for i = 1 to getNumSubMtls targetMat do (
            local subMat = getSubMtl targetMat i
            if subMat == mOld then (
                setSubMtl targetMat i mNew
            ) else if subMat != undefined then (
                replaceSubMat subMat mOld mNew visited:visited
            )
        )
    )

    -- 检查某个材质及其子材质是否在给定的列表中
    fn hasOldMat targetMat oldMatsList visited: = (
        if visited == unsupplied do visited = #()
        if targetMat == undefined do return false
        if findItem visited targetMat > 0 do return false
        append visited targetMat
        
        if findItem oldMatsList targetMat > 0 do return true
        
        for i = 1 to getNumSubMtls targetMat do (
            local subMat = getSubMtl targetMat i
            if hasOldMat subMat oldMatsList visited:visited do return true
        )
        return false
    )

    -- ==================== 第一步：扫描分析 ====================
    on btn_scan pressed do (
        if not chk_name.checked and not chk_param.checked and not chk_tex.checked do (
            messageBox "请至少勾选一种合并条件！" title:"警告"
            return false
        )
        
        -- 初始化界面状态和缓存
        btn_scan.enabled = false
        btn_merge.enabled = false
        btn_sel_dup.enabled = false
        mergePairs_cache = #()
        targetObjs_cache = #()
        isTargetedScope = chk_visible.checked  -- 记住扫描时的“作用范围”设置
        
        lbl_status.text = "正在收集材质池，请稍候..."
        
        local searchPool = #()
        
        if isTargetedScope then (
            targetObjs_cache = for obj in objects where not obj.isHidden collect obj
            for obj in targetObjs_cache do (
                if obj.mat != undefined do collectAllMats obj.mat &searchPool visited:#()
            )
        ) else (
            searchPool = getClassInstances Material
        )
        
        if searchPool.count == 0 do (
            lbl_status.text = "没有找到任何材质。"
            btn_scan.enabled = true
            return false
        )
        
        lbl_status.text = "正在深度比对(不修改模型)..."
        local uniqueMats = #()
        local total = searchPool.count
        
        for i = 1 to total do (
            local m = searchPool[i]
            local isDuplicate = false
            
            for u in uniqueMats do (
                if compareMats m u chk_name.checked chk_param.checked chk_tex.checked then (
                    isDuplicate = true
                    -- 发现相同材质，将其存入后台缓存，等待第二步执行
                    append mergePairs_cache #(m, u) 
                    exit
                )
            )
            
            if not isDuplicate do append uniqueMats m
            pb_bar.value = (i as float / total) * 100
        )
        
        pb_bar.value = 100
        btn_scan.enabled = true
        
        if mergePairs_cache.count > 0 then (
            -- 计算统计数据
            local uniqueTargets = #()
            for pair in mergePairs_cache do appendIfUnique uniqueTargets pair[2]
            
            local mergeableCount = mergePairs_cache.count          -- 将被消灭（合并）的材质数
            local targetCount = uniqueTargets.count                -- 这些重复材质指向的主材质数
            local totalDupInvolved = mergeableCount + targetCount  -- 参与重复的总材质数
            
            local remainCount = uniqueMats.count                   -- 最终整个场景剩余独立材质数
            local totalCount = total                               -- 扫描到的总数量
            
            lbl_status.text = "扫描完成！可合并:" + (mergeableCount as string) + " 剩余:" + (remainCount as string)
            btn_merge.enabled = true  -- 只有发现重复材质时，才允许点击第二步
            btn_sel_dup.enabled = true -- 允许选择重复材质的模型
            
            local msg = "分析完成！\n\n"
            msg += "场景总材质数: " + (totalCount as string) + " 个\n\n"
            
            msg += "【重复统计】\n"
            msg += "共有重复材质: " + (totalDupInvolved as string) + " 个\n"
            msg += "其中可合并的: " + (mergeableCount as string) + " 个\n"
            msg += "它们可以被合并为: " + (targetCount as string) + " 个材质\n\n"
            
            msg += "【结果预测】\n"
            msg += "合并后场景将剩余材质: " + (remainCount as string) + " 个\n\n"
            
            msg += "提示：点击【选择含重复材质的模型】按钮可以选中它们。\n"
            msg += "确认无误后点击【第二步: 确认合并】执行最终合并替换。"
            
            messageBox msg title:"分析结果"
        ) else (
            lbl_status.text = "扫描完成！当前场景没有符合条件的重复材质。"
            messageBox "您的场景非常干净，没有发现符合条件的重复材质！" title:"提示"
        )
    )
    
    -- ==================== 选择含重复材质的模型 ====================
    on btn_sel_dup pressed do (
        if mergePairs_cache.count == 0 do return false
        
        local oldMats = #()
        for pair in mergePairs_cache do append oldMats pair[1]
        
        local searchObjs = if isTargetedScope then targetObjs_cache else objects
        local objsToSelect = #()
        
        for obj in searchObjs do (
            if obj.mat != undefined and hasOldMat obj.mat oldMats visited:#() then (
                append objsToSelect obj
            )
        )
        
        if objsToSelect.count > 0 then (
            select objsToSelect
            lbl_status.text = "已选中 " + (objsToSelect.count as string) + " 个包含重复材质的模型。"
        ) else (
            lbl_status.text = "没有找到可以直接选中的模型(或模型被隐藏)。"
        )
    )

    -- ==================== 第二步：确认合并 ====================
    on btn_merge pressed do (
        btn_scan.enabled = false
        btn_merge.enabled = false
        btn_sel_dup.enabled = false
        lbl_status.text = "正在合并材质，请稍候..."
        pb_bar.value = 0
        
        local total = mergePairs_cache.count
        
        for i = 1 to total do (
            local pair = mergePairs_cache[i]
            local mOld = pair[1]
            local mNew = pair[2]
            
            if isTargetedScope then (
                -- 精准替换
                for obj in targetObjs_cache do (
                    if obj.mat == mOld then (
                        obj.mat = mNew
                    ) else if obj.mat != undefined then (
                        replaceSubMat obj.mat mOld mNew visited:#()
                    )
                )
            ) else (
                -- 暴力全局替换
                try ( replaceInstances mOld mNew ) catch ()
            )
            
            pb_bar.value = (i as float / total) * 100
        )
        
        -- 执行完毕，清理内存缓存
        mergePairs_cache = #()
        targetObjs_cache = #()
        
        lbl_status.text = "合并完成！共合并了 " + (total as string) + " 个材质。"
        messageBox ("任务成功完成！\n共清理合并了 " + (total as string) + " 个重复材质。") title:"成功"
        btn_scan.enabled = true
    )
)

createDialog AdvancedMatMerger