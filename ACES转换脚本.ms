/*
======================================================================
脚本名称: VRay ACEScg 助手 (v14.3 终极统计版)
功能:
1. "跳过已有 VR 贴图" 开关，可过滤已有 VRayBitmap 免受参数修改。
2. 贴图模糊值 (Blur) 统一修改开关与自定义数值输入。
3. 支持 Standard Bitmap 转换为 VRayBitmap，并保留剪切/放置参数。
4. 递归扫描嵌套贴图，对多层包装节点里的位图同样生效。
5. 修复 VRayColor：将 RGB 原色强制设为 0 (Raw)。
6. 修复 凹凸贴图：普通凹凸贴图直接包裹，法线节点仅处理内部 bump_map。
7. [修复] 弹窗仅统计发生真实参数变动的贴图，重复转换不再计入数量。
======================================================================
*/

try(destroyDialog rol_ACESConverter)catch()

rollout rol_ACESConverter "ACEScg 助手 v14.3" width:250
(
    -- ================= 配置区 =================
    local raw_id_value = 3  -- 位图 Raw 对应的数值
    -- =========================================

    group "设置"
    (
        checkbox chk_fastMode "极速模式 (无撤销)" checked:true height:18 tooltip:"【推荐开启】\n大场景必备，转换速度极快。\n注意：开启后无法使用 Ctrl+Z 撤销。"
        checkbox chk_convertToVRay "转为 VRayBitmap" checked:true height:18 tooltip:"【深度转换】\n自动将 Standard Bitmap 转换为 VRayBitmap。"

        checkbox chk_skipExistingVRay "跳过已有 VR 贴图" checked:false height:18 tooltip:"【智能过滤】\n开启后，场景中原本就存在的 VRayBitmap 将保持原样（不修改色彩空间和模糊值）。\n脚本只对新转换的贴图应用规则。"

        checkbox chk_overrideBlur "统一模糊值" checked:false width:130 across:2 tooltip:"开启后，将强制修改贴图的模糊值(Blur)"
        spinner spn_blurVal "" range:[0.0, 100.0, 0.01] width:50 align:#right
    )
    
    group "额外修复功能 (V-Ray)"
    (
        checkbox chk_fixVRayColor "VRayColor 原色设为无 (Raw)" checked:false height:18 tooltip:"强制将 VRayColor 的 [RGB primaries] 设为 0 (Raw)。\n(解决色彩空间过曝问题)"
        
        checkbox chk_fixBump "V-Ray GPU 凹凸兼容修复" checked:false width:135 across:2 tooltip:"普通凹凸贴图将包裹进 VRayColor2Bump。\nVRayNormalMap / Normal Bump 只处理内部凹凸贴图，不改变法线贴图。"
        spinner spn_bumpHeight "" range:[0.001, 100.0, 1.0] type:#float width:50 align:#right tooltip:"设置包裹后的高度倍增值"
    )

    group "当前规则"
    (
        button btn_ruleC "Color: sRGB" width:100 height:22 across:2 tooltip:".rgbColorSpace = 1\n(漫反射/环境色等)"
        button btn_ruleD "Data: Raw" width:100 height:22 tooltip:".rgbColorSpace = 3\n(法线/光泽/置换等)"
    )

    button btn_convertSel "仅转换选中" width:230 height:40 highlightColor:green tooltip:"只处理当前选中的物体材质及其关联贴图"
    button btn_convertAll "转换全场景" width:230 height:25 tooltip:"扫描并处理场景中所有的材质"

    on rol_ACESConverter open do
    (
        btn_ruleD.text = "Data: Raw (" + (raw_id_value as string) + ")"
    )

    -- ================= 核心逻辑 =================

    -- [新增核心]: 用于对比当前值，只有发生真实修改才返回 true
    fn setPropertyIfDiff obj propName val =
    (
        if isProperty obj propName then
        (
            try
            (
                if (getProperty obj propName) != val then
                (
                    setProperty obj propName val
                    return true
                )
            ) catch()
        )
        return false
    )

    fn applyBlur map blurValue =
    (
        try
        (
            if isProperty map "coords" and map.coords != undefined do
            (
                if isProperty map.coords "blur" do map.coords.blur = blurValue
            )
        )
        catch()
    )

    fn createVRayBitmapFromStandard oldMap =
    (
        if classof oldMap == BitmapTexture and isProperty oldMap "filename" and oldMap.filename != undefined and oldMap.filename != "" then
        (
            try
            (
                local newMap = VRayBitmap()
                newMap.HDRIMapName = oldMap.filename

                if oldMap.coords != undefined do
                (
                    newMap.coords.u_tiling = oldMap.coords.u_tiling
                    newMap.coords.v_tiling = oldMap.coords.v_tiling
                    newMap.coords.u_offset = oldMap.coords.u_offset
                    newMap.coords.v_offset = oldMap.coords.v_offset
                    newMap.coords.W_angle = oldMap.coords.W_angle
                    newMap.coords.blur = oldMap.coords.blur
                )

                if isProperty oldMap "apply" and oldMap.apply == true do
                (
                    if isProperty newMap "cropplace_on" do newMap.cropplace_on = true
                    if isProperty oldMap "cropPlace" and isProperty newMap "cropplace_mode" do newMap.cropplace_mode = oldMap.cropPlace
                    if isProperty oldMap "clipu" and isProperty newMap "cropplace_u" do newMap.cropplace_u = oldMap.clipu
                    if isProperty oldMap "clipv" and isProperty newMap "cropplace_v" do newMap.cropplace_v = oldMap.clipv
                    if isProperty oldMap "clipw" and isProperty newMap "cropplace_width" do newMap.cropplace_width = oldMap.clipw
                    if isProperty oldMap "cliph" and isProperty newMap "cropplace_height" do newMap.cropplace_height = oldMap.cliph
                )

                newMap.name = "VR_" + oldMap.name
                return newMap
            )
            catch ( return undefined )
        )
        else return undefined
    )

    fn collectNestedBitmaps rootNode targetArray includeVRay includeStandard =
    (
        if rootNode == undefined then return false

        if includeVRay and (isKindOf rootNode VRayBitmap) do appendIfUnique targetArray rootNode
        if includeStandard and (classof rootNode == BitmapTexture) do appendIfUnique targetArray rootNode

        local subTexCount = 0
        try(subTexCount = getNumSubTexmaps rootNode)catch(subTexCount = 0)
        for i = 1 to subTexCount do
        (
            local subMap = undefined
            try(subMap = getSubTexmap rootNode i)catch(subMap = undefined)
            if subMap != undefined do collectNestedBitmaps subMap targetArray includeVRay includeStandard
        )

        local subMtlCount = 0
        try(subMtlCount = getNumSubMtls rootNode)catch(subMtlCount = 0)
        for i = 1 to subMtlCount do
        (
            local subMtl = undefined
            try(subMtl = getSubMtl rootNode i)catch(subMtl = undefined)
            if subMtl != undefined do collectNestedBitmaps subMtl targetArray includeVRay includeStandard
        )
    )

    fn collectVRayMtlsRecursive rootMtl targetArray =
    (
        if rootMtl == undefined then return false

        if classof rootMtl == VRayMtl do appendIfUnique targetArray rootMtl

        local subMtlCount = 0
        try(subMtlCount = getNumSubMtls rootMtl)catch(subMtlCount = 0)
        for i = 1 to subMtlCount do
        (
            local subMtl = undefined
            try(subMtl = getSubMtl rootMtl i)catch(subMtl = undefined)
            if subMtl != undefined do collectVRayMtlsRecursive subMtl targetArray
        )
    )

    fn convertDeepBitmapsInMaterials targetMtlList =
    (
        local count = 0
        local allStdMaps = #()

        for mat in targetMtlList do collectNestedBitmaps mat allStdMaps false true

        for oldMap in allStdMaps do
        (
            local newMap = createVRayBitmapFromStandard oldMap
            if newMap != undefined do
            (
                try ( replaceInstances oldMap newMap; count += 1 ) catch()
            )
        )
        return count
    )

    fn collectDeepBitmaps rootMat paramName targetArray =
    (
        if rootMat != undefined and hasProperty rootMat paramName do
        (
            local mapSlot = getProperty rootMat paramName
            if mapSlot != undefined do collectNestedBitmaps mapSlot targetArray true true
        )
    )

    fn setToColorMode map =
    (
        local isChanged = false
        if classof map == VRayBitmap then
        (
            if (setPropertyIfDiff map "color_space" 2) do isChanged = true
            if (setPropertyIfDiff map "rgbColorSpace" 1) do isChanged = true
            if (setPropertyIfDiff map "rgb_primaries" 1) do isChanged = true
            if (setPropertyIfDiff map "primaries" 1) do isChanged = true
        )
        else if classof map == BitmapTexture then
        (
            -- Standard Bitmap 较难稳定获取伽马状态，一旦触发通常算作修改
            isChanged = true 
            try ( if isProperty map "bitmap" and map.bitmap != undefined do map.bitmap.gamma = 0 ) catch()
        )
        return isChanged
    )

    fn setToDataMode map =
    (
        local isChanged = false
        if classof map == VRayBitmap then
        (
            if (setPropertyIfDiff map "color_space" 0) do isChanged = true
            if (setPropertyIfDiff map "rgbColorSpace" raw_id_value) do isChanged = true
            if (setPropertyIfDiff map "rgb_primaries" raw_id_value) do isChanged = true
            if (setPropertyIfDiff map "primaries" raw_id_value) do isChanged = true
        )
        else if classof map == BitmapTexture then
        (
            isChanged = true
            try ( if isProperty map "bitmap" and map.bitmap != undefined do map.bitmap.gamma = 1.0 ) catch()
        )
        return isChanged
    )

    fn runMainProcess targetMtlList shouldConvert doBlur blurVal skipExisting =
    (
        local existingVRayMaps = #()
        if skipExisting do
        (
            for mat in targetMtlList do collectNestedBitmaps mat existingVRayMaps true false
        )

        if shouldConvert do convertDeepBitmapsInMaterials targetMtlList

        local color_maps = #()
        local data_maps = #()

        for mat in targetMtlList do
        (
            collectDeepBitmaps mat "texmap_diffuse" color_maps
            collectDeepBitmaps mat "texmap_reflection" color_maps
            collectDeepBitmaps mat "texmap_refraction" color_maps
            collectDeepBitmaps mat "texmap_translucent" color_maps
            collectDeepBitmaps mat "texmap_self_illumination" color_maps
            collectDeepBitmaps mat "texmap_coat_color" color_maps
            collectDeepBitmaps mat "texmap_sheen_color" color_maps

            collectDeepBitmaps mat "texmap_reflectionGlossiness" data_maps
            collectDeepBitmaps mat "texmap_refractionGlossiness" data_maps
            collectDeepBitmaps mat "texmap_bump" data_maps
            collectDeepBitmaps mat "texmap_displacement" data_maps
            collectDeepBitmaps mat "texmap_opacity" data_maps
            collectDeepBitmaps mat "texmap_metalness" data_maps
            collectDeepBitmaps mat "texmap_anisotropy" data_maps
        )

        local count_color = 0
        local count_data = 0

        for map in color_maps do
        (
            if skipExisting and (findItem existingVRayMaps map) != 0 do continue

            local c_changed = setToColorMode map
            if doBlur do applyBlur map blurVal
            
            -- 只有当属性真实发生变动时，才计入统计
            if c_changed do count_color += 1
        )

        for map in data_maps do
        (
            if skipExisting and (findItem existingVRayMaps map) != 0 do continue

            if (findItem color_maps map) == 0 then
            (
                local d_changed = setToDataMode map
                if doBlur do applyBlur map blurVal
                
                -- 只有当属性真实发生变动时，才计入统计
                if d_changed do count_data += 1
            )
        )

        return #(count_color, count_data)
    )

    fn getMaterialsFromSelection =
    (
        local matList = #()
        for o in selection do
        (
            if o.material != undefined do collectVRayMtlsRecursive o.material matList
        )
        return matList
    )
    
    -- === 凹凸兼容修复逻辑 ===
    -- 法线节点已经负责解析向量数据，外层不能再转换成高度凹凸
    fn isNormalMapNode mapNode =
    (
        if mapNode == undefined then return false

        local className = toLower ((classOf mapNode) as string)
        className = substituteString className "_" ""
        className = substituteString className " " ""

        return className == "normalbump" or (findString className "vraynormalmap") == 1
    )

    fn wrapNormalNodeBump normalNode bumpHeight =
    (
        if not (hasProperty normalNode "bump_map") then return false

        local originalBumpMap = getProperty normalNode #bump_map
        if originalBumpMap == undefined or (classOf originalBumpMap) == VRayColor2Bump then return false

        local color2Bump = VRayColor2Bump()
        if hasProperty color2Bump "map" do color2Bump.map = originalBumpMap
        if hasProperty color2Bump "height" do color2Bump.height = bumpHeight
        setProperty normalNode #bump_map color2Bump
        return true
    )

    fn applyBumpFix targetMtlList bumpHeight =
    (
        local count = 0
        for mat in targetMtlList do
        (
            if isProperty mat "texmap_bump" and mat.texmap_bump != undefined do
            (
                local originalMap = mat.texmap_bump
                local normalNode = undefined
                local changed = false

                if isNormalMapNode originalMap then
                (
                    normalNode = originalMap
                )
                else if (classOf originalMap) == VRayColor2Bump and hasProperty originalMap "map" and isNormalMapNode originalMap.map then
                (
                    -- 修复旧版脚本可能形成的错误外层包裹
                    normalNode = originalMap.map
                    mat.texmap_bump = normalNode
                    changed = true
                )

                if normalNode != undefined then
                (
                    if wrapNormalNodeBump normalNode bumpHeight do changed = true
                )
                else if (classOf originalMap) != VRayColor2Bump then
                (
                    local color2Bump = VRayColor2Bump()
                    if hasProperty color2Bump "map" do color2Bump.map = originalMap
                    if hasProperty color2Bump "height" do color2Bump.height = bumpHeight
                    mat.texmap_bump = color2Bump
                    changed = true
                )

                if changed do count += 1
            )
        )
        return count
    )

    -- === VRayColor 深度收集与原色修复逻辑 ===
    fn collectVRayColor rootNode targetArr =
    (
        if rootNode == undefined do return false
        if classOf rootNode == VRayColor do appendIfUnique targetArr rootNode

        local subTexCount = 0
        try(subTexCount = getNumSubTexmaps rootNode)catch(subTexCount = 0)
        for i = 1 to subTexCount do
        (
            local subMap = undefined
            try(subMap = getSubTexmap rootNode i)catch()
            if subMap != undefined do collectVRayColor subMap targetArr
        )

        local subMtlCount = 0
        try(subMtlCount = getNumSubMtls rootNode)catch(subMtlCount = 0)
        for i = 1 to subMtlCount do
        (
            local subMtl = undefined
            try(subMtl = getSubMtl rootNode i)catch()
            if subMtl != undefined do collectVRayColor subMtl targetArr
        )
    )

    fn applyVRayColorFix targetMtlList mode =
    (
        local count = 0
        local vColors = #()

        if mode == #scene then vColors = getClassInstances VRayColor
        else for mat in targetMtlList do collectVRayColor mat vColors

        for vmap in vColors do
        (
            if hasProperty vmap "rgb_primaries" do
            (
                if vmap.rgb_primaries != 0 do
                (
                    vmap.rgb_primaries = 0
                    count += 1
                )
            )
        )
        return count
    )

    -- === 总执行入口 ===
    fn executeConversion mode =
    (
        local useFastMode = chk_fastMode.checked
        local shouldConvert = chk_convertToVRay.checked
        local skipExisting = chk_skipExistingVRay.checked
        local doBlur = chk_overrideBlur.checked
        local blurVal = spn_blurVal.value
        
        local doBumpFix = chk_fixBump.checked
        local bumpHeightVal = spn_bumpHeight.value
        local doVRayColorFix = chk_fixVRayColor.checked

        local targetMtls = #()
        local results = #(0, 0)
        local bumpCount = 0
        local vColorCount = 0

        if mode == #selection then
        (
            if selection.count == 0 do (messageBox "请先选择物体！" title:"提示"; return false)
            targetMtls = getMaterialsFromSelection()
            if targetMtls.count == 0 do (messageBox "选中的物体没有 VRayMtl 材质。" title:"提示"; return false)
        )
        else
        (
            targetMtls = getClassInstances VRayMtl
        )

        with redraw off
        (
            try(suspendEditing())catch()

            if useFastMode then
            (
                with undo off
                (
                    clearListener()
                    results = runMainProcess targetMtls shouldConvert doBlur blurVal skipExisting
                    if doBumpFix do bumpCount = applyBumpFix targetMtls bumpHeightVal
                    if doVRayColorFix do vColorCount = applyVRayColorFix targetMtls mode
                )
            )
            else
            (
                undo "ACEScg Convert & Fix" on
                (
                    clearListener()
                    results = runMainProcess targetMtls shouldConvert doBlur blurVal skipExisting
                    if doBumpFix do bumpCount = applyBumpFix targetMtls bumpHeightVal
                    if doVRayColorFix do vColorCount = applyVRayColorFix targetMtls mode
                )
            )

            try(resumeEditing())catch()
        )
        
        -- 侦听器输出
        format "本次真实变动 => Color: % 个 | Data: % 个 | 凹凸节点修复: % 个 | VRayColor修复: % 个\n" results[1] results[2] bumpCount vColorCount
        
        -- 弹窗提示
        local msg = "转换执行完毕！\n\n"
        msg += "【实际转换统计】\n"
        msg += "转为 Color 空间贴图: " + (results[1] as string) + " 个\n"
        msg += "转为 Data  空间贴图: " + (results[2] as string) + " 个\n"
        
        if doVRayColorFix do msg += "修复 VRayColor (Raw): " + (vColorCount as string) + " 个\n"
        if doBumpFix do msg += "修复凹凸贴图节点: " + (bumpCount as string) + " 个\n"
        
        msg += "\n(本次共扫描材质球: " + (targetMtls.count as string) + " 个)"
        
        messageBox msg title:"执行结果"
    )

    on btn_convertSel pressed do executeConversion #selection
    on btn_convertAll pressed do executeConversion #scene
)

createDialog rol_ACESConverter