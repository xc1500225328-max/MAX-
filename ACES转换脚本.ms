/*
======================================================================
脚本名称: VRay ACEScg 助手 (v14.0 智能过滤版)
功能: 
1. [新增] "跳过已有 VR 贴图" 开关，可过滤已有 VRayBitmap 免受参数修改。
2. 贴图模糊值 (Blur) 统一修改开关与自定义数值输入。
3. 完美支持位图的 "剪切/放置" 参数转换。
======================================================================
*/

try(destroyDialog rol_ACESConverter)catch()

rollout rol_ACESConverter "ACEScg 助手 v14.0" width:240
(
    -- ================= 配置区 =================
    local raw_id_value = 3  -- Raw 对应的数值
    -- =========================================

    group "设置"
    (
        checkbox chk_fastMode "极速模式 (无撤销)" checked:true height:18 tooltip:"【推荐开启】\n大场景必备，转换速度极快。\n注意：开启后无法使用 Ctrl+Z 撤销。"
        checkbox chk_convertToVRay "转为 VRayBitmap" checked:true height:18 tooltip:"【深度转换】\n自动将 Standard Bitmap 转换为 VRayBitmap。"
        
        -- [新增] 跳过已有 VRayBitmap 的开关
        checkbox chk_skipExistingVRay "跳过已有 VR 贴图" checked:false height:18 tooltip:"【智能过滤】\n开启后，场景中原本就存在的 VRayBitmap 将保持原样（不修改色彩空间和模糊值）。\n脚本只对新转换的贴图应用规则。"
        
        -- 模糊值控制
        checkbox chk_overrideBlur "统一模糊值" checked:false width:130 across:2 tooltip:"开启后，将强制修改贴图的模糊值(Blur)"
        spinner spn_blurVal "" range:[0.0, 100.0, 0.01] width:50 align:#right
    )

    group "当前规则"
    (
        button btn_ruleC "Color: sRGB" width:100 height:22 across:2 tooltip:".rgbColorSpace = 1\n(漫反射/环境色等)"
        button btn_ruleD "Data: Raw"   width:100 height:22 tooltip:".rgbColorSpace = 3\n(法线/光泽/置换等)"
    )
    
    button btn_convertSel "仅转换选中" width:220 height:40 highlightColor:green tooltip:"只处理当前选中的物体材质"
    button btn_convertAll "转换全场景" width:220 height:25 tooltip:"扫描并处理场景中所有的材质"

    on rol_ACESConverter open do
    (
        btn_ruleD.text = "Data: Raw (" + (raw_id_value as string) + ")"
    )

    -- ================= 核心逻辑 =================

    fn setPropertySafe map propName value =
    (
        if isProperty map propName do setProperty map propName value
    )

    -- 安全修改模糊值函数
    fn applyBlur map blurValue =
    (
        try (
            if isProperty map "coords" and map.coords != undefined do
            (
                if isProperty map.coords "blur" do map.coords.blur = blurValue
            )
        ) catch()
    )

    -- 创建 VRayBitmap 函数 (增加剪切支持)
    fn createVRayBitmapFromStandard oldMap =
    (
        if classof oldMap == BitmapTexture and isProperty oldMap "filename" and oldMap.filename != undefined and oldMap.filename != "" then
        (
            try
            (
                local newMap = VRayBitmap()
                newMap.HDRIMapName = oldMap.filename 
                
                -- 1. 传递基础坐标
                if oldMap.coords != undefined do
                (
                    newMap.coords.u_tiling = oldMap.coords.u_tiling
                    newMap.coords.v_tiling = oldMap.coords.v_tiling
                    newMap.coords.u_offset = oldMap.coords.u_offset
                    newMap.coords.v_offset = oldMap.coords.v_offset
                    newMap.coords.W_angle = oldMap.coords.W_angle
                    newMap.coords.blur = oldMap.coords.blur
                )

                -- 2. 传递剪切/放置
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

    fn convertDeepBitmapsInMaterials targetMtlList =
    (
        local count = 0
        local allStdMaps = #()
        
        for mat in targetMtlList do
        (
            local mapsInMat = getClassInstances BitmapTexture target:mat
            for m in mapsInMat do appendIfUnique allStdMaps m
        )

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
            if mapSlot != undefined do
            (
                local vray_maps = getClassInstances VRayBitmap target:mapSlot
                for m in vray_maps do appendIfUnique targetArray m
                local std_maps = getClassInstances BitmapTexture target:mapSlot
                for m in std_maps do appendIfUnique targetArray m
            )
        )
    )

    fn setToColorMode map =
    (
        if classof map == VRayBitmap then
        (
            setPropertySafe map "color_space" 2      
            setPropertySafe map "rgbColorSpace" 1    
            setPropertySafe map "rgb_primaries" 1
            setPropertySafe map "primaries" 1
        )
        else if classof map == BitmapTexture then
        (
            try ( if isProperty map "bitmap" and map.bitmap != undefined do map.bitmap.gamma = 0 ) catch()
        )
    )

    fn setToDataMode map =
    (
        if classof map == VRayBitmap then
        (
            setPropertySafe map "color_space" 0      
            setPropertySafe map "rgbColorSpace" raw_id_value 
            setPropertySafe map "rgb_primaries" raw_id_value
            setPropertySafe map "primaries" raw_id_value
        )
        else if classof map == BitmapTexture then
        (
            try ( if isProperty map "bitmap" and map.bitmap != undefined do map.bitmap.gamma = 1.0 ) catch()
        )
    )

    -- [核心修改] 增加了 skipExisting 参数来过滤已有的贴图
    fn runMainProcess targetMtlList shouldConvert doBlur blurVal skipExisting =
    (
        -- [过滤逻辑 第一步] 预先收集现存的 VRayBitmap
        local existingVRayMaps = #()
        if skipExisting do
        (
            for mat in targetMtlList do
            (
                local vMaps = getClassInstances VRayBitmap target:mat
                for m in vMaps do appendIfUnique existingVRayMaps m
            )
        )

        -- 转换位图
        if shouldConvert do convertDeepBitmapsInMaterials targetMtlList

        -- 重新收集所有贴图 (包含刚转换出来的新贴图)
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
        
        -- [过滤逻辑 第二步] 在应用参数时进行跳过检查
        for map in color_maps do
        (
            -- 如果开启了跳过，且该贴图在最初记录的已有列表中，则直接跳过本次循环
            if skipExisting and (findItem existingVRayMaps map) != 0 do continue
            
            setToColorMode map
            if doBlur do applyBlur map blurVal
            count_color += 1
        )

        for map in data_maps do
        (
            -- 同理，跳过已有的老贴图
            if skipExisting and (findItem existingVRayMaps map) != 0 do continue
            
            if (findItem color_maps map) == 0 then
            (
                setToDataMode map
                if doBlur do applyBlur map blurVal
                count_data += 1
            )
        )
        
        return #(count_color, count_data)
    )

    fn getMaterialsFromSelection = 
    (
        local matList = #()
        for o in selection do
        (
            if o.material != undefined do
            (
                if classof o.material == Multimaterial then
                (
                    for m in o.material.materialList do
                    (
                        if classof m == VRayMtl do appendIfUnique matList m
                    )
                )
                else if classof o.material == VRayMtl do
                (
                    appendIfUnique matList o.material
                )
            )
        )
        return matList
    )

    fn executeConversion mode =
    (
        local useFastMode = chk_fastMode.checked
        local shouldConvert = chk_convertToVRay.checked
        local skipExisting = chk_skipExistingVRay.checked -- 获取跳过开关状态
        local doBlur = chk_overrideBlur.checked
        local blurVal = spn_blurVal.value
        
        local targetMtls = #()
        
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
                    local results = runMainProcess targetMtls shouldConvert doBlur blurVal skipExisting
                    format "修改 Color 参数: % 个 | 修改 Data 参数: % 个\n" results[1] results[2]
                )
            )
            else
            (
                undo "ACEScg Convert" on
                (
                    clearListener()
                    local results = runMainProcess targetMtls shouldConvert doBlur blurVal skipExisting
                    format "修改 Color 参数: % 个 | 修改 Data 参数: % 个\n" results[1] results[2]
                )
            )
            
            try(resumeEditing())catch()
        )
        
        messageBox ("转换执行完毕！\n已处理材质球: " + (targetMtls.count as string))
    )

    on btn_convertSel pressed do executeConversion #selection
    on btn_convertAll pressed do executeConversion #scene
)

createDialog rol_ACESConverter