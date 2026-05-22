/*
======================================================================
脚本名称: VRay ACEScg 助手 (v14.0 智能过滤版)
功能:
1. "跳过已有 VR 贴图" 开关，可过滤已有 VRayBitmap 免受参数修改。
2. 贴图模糊值 (Blur) 统一修改开关与自定义数值输入。
3. 支持 Standard Bitmap 转换为 VRayBitmap，并保留剪切/放置参数。
4. 递归扫描嵌套贴图，对多层包装节点里的位图同样生效。
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

        checkbox chk_skipExistingVRay "跳过已有 VR 贴图" checked:false height:18 tooltip:"【智能过滤】\n开启后，场景中原本就存在的 VRayBitmap 将保持原样（不修改色彩空间和模糊值）。\n脚本只对新转换的贴图应用规则。"

        checkbox chk_overrideBlur "统一模糊值" checked:false width:130 across:2 tooltip:"开启后，将强制修改贴图的模糊值(Blur)"
        spinner spn_blurVal "" range:[0.0, 100.0, 0.01] width:50 align:#right
    )

    group "当前规则"
    (
        button btn_ruleC "Color: sRGB" width:100 height:22 across:2 tooltip:".rgbColorSpace = 1\n(漫反射/环境色等)"
        button btn_ruleD "Data: Raw" width:100 height:22 tooltip:".rgbColorSpace = 3\n(法线/光泽/置换等)"
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

            setToColorMode map
            if doBlur do applyBlur map blurVal
            count_color += 1
        )

        for map in data_maps do
        (
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
            if o.material != undefined do collectVRayMtlsRecursive o.material matList
        )
        return matList
    )

    fn executeConversion mode =
    (
        local useFastMode = chk_fastMode.checked
        local shouldConvert = chk_convertToVRay.checked
        local skipExisting = chk_skipExistingVRay.checked
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
