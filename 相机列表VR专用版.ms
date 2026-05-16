/* VRay 相机管理助手 v28.6 (比例锁定Bug修复版)
   1. [修复] 修复了手动修改比例后点击锁定按钮，比例会被旧宽高重置的Bug。
   2. [优化] 无论锁定与否，修改比例(R)时，高度(H)都会实时自动推算。
   作者：编码助手
*/

global vcm_syncSelectionFromScene
global ro_vcm_main
global ro_tags
global vcm_camList = #()
global vcm_presetArr = #()
global vcm_namePresetArr = #("客厅", "餐厅", "主卧")
global vcm_lockedViewID = 0
global vcm_autoName = false 
global vcm_sortByName = false 
global vcm_iniPath = getDir #plugcfg + "\\VRayCamPro_Presets.ini"

fn vcm_syncSelectionFromScene = (
    if ro_vcm_main != undefined and ro_vcm_main.isDisplayed then (
        if selection.count == 1 and classof selection[1] == VRayPhysicalCamera then (
            local targetCam = selection[1]
            local idx = findItem vcm_camList targetCam
            if idx == 0 then (
                if (ro_vcm_main != undefined) do ro_vcm_main.refreshCameraList()
                vcm_camList = for c in cameras where (classof c == VRayPhysicalCamera) collect c
                if vcm_sortByName do (
                    fn tempCompare c1 c2 = (
                        local n1 = toLower c1.name; local n2 = toLower c2.name
                        if n1 < n2 then -1 else if n1 > n2 then 1 else 0
                    )
                    qsort vcm_camList tempCompare
                )
                idx = findItem vcm_camList targetCam
            )
            if idx > 0 do (
                ro_vcm_main.lb_cams.selection = #{idx}
                local info = ro_vcm_main.vcm_getCameraResInfo targetCam
                if info[1] != undefined do ro_vcm_main.lbl_status.text = "选: " + (info[1] as integer) as string + "x" + (info[2] as integer) as string
            )
        )
    )
)

macroScript VRayCamManager
category:"_编码助手Tools"
toolTip:"VRay 相机管理助手"
buttonText:"VRayCam"
(
    try(callbacks.removeScripts id:#vcm_sync_sel)catch()
    try(destroyDialog ro_vcm_main)catch() 

    fn vcm_savePresets = ( setINISetting vcm_iniPath "Presets" "Data" (vcm_presetArr as string) )
    fn vcm_saveSettings = ( 
        setINISetting vcm_iniPath "Settings" "AutoName" (vcm_autoName as string) 
        setINISetting vcm_iniPath "Settings" "SortByName" (vcm_sortByName as string)
        setINISetting vcm_iniPath "Presets" "NameData" (vcm_namePresetArr as string)
    )

    fn vcm_loadPresets = (
        local str = getINISetting vcm_iniPath "Presets" "Data"
        if str != "" then ( 
            try ( vcm_presetArr = execute str ) 
            catch ( vcm_presetArr = #([3200,2400], [2880,2880], [3840,2160], [2000,1500]) ) 
        ) else ( 
            vcm_presetArr = #([3200,2400], [2880,2880], [3840,2160], [2000,1500]) 
        )
        
        local autoNameStr = getINISetting vcm_iniPath "Settings" "AutoName"
        if autoNameStr == "true" then vcm_autoName = true else vcm_autoName = false

        local sortStr = getINISetting vcm_iniPath "Settings" "SortByName"
        if sortStr == "true" then vcm_sortByName = true else vcm_sortByName = false

        local nameStr = getINISetting vcm_iniPath "Presets" "NameData"
        if nameStr != "" then (
            try ( 
                local tempArr = execute nameStr
                vcm_namePresetArr = for item in tempArr where item != "" collect item
                if vcm_namePresetArr.count == 0 do vcm_namePresetArr = #("客厅", "餐厅", "主卧")
            ) catch ( vcm_namePresetArr = #("客厅", "餐厅", "主卧") )
        )
    )
    vcm_loadPresets()

    rollout ro_vcm_main "VRay 相机助手 v28.6" (
        button btn_lock_view "锁定切换视口" width:102 height:22 across:2 align:#left offset:[0,5]
        checkbutton ckb_lock_render "锁定渲染视口" width:102 height:22 align:#right offset:[0,5] highlightColor:(color 255 100 100) 

        multilistbox lb_cams "" height:20 offset:[0,-2]
        
        button btn_refresh "刷新" width:50 across:4 offset:[-8,0] height:20
        checkbutton ckb_sort_name "排序" width:50 offset:[-5,0] height:20 highlightColor:(color 100 255 100)
        checkbutton ckb_auto_name "写名称" width:50 offset:[-2,0] height:20 highlightColor:(color 255 200 100) 
        button btn_help "帮助" width:50 offset:[1,0] height:20
        
        label lbl_status "准备就绪" style_sunkenedge:true width:210 height:18 color:green offset:[0,2]

        label lbl_div1 "─── 分辨率预设 ───" align:#center offset:[0,5]
        listbox lb_presets "" height:5 offset:[0,-2]
        
        spinner sp_rw "W:" range:[1,99999,2000] type:#integer fieldwidth:35 across:3 align:#left
        button btn_swap "互换" width:30 height:18 offset:[-4,-1] 
        spinner sp_rh "H:" range:[1,99999,1500] type:#integer fieldwidth:35 align:#right
        
        spinner sp_aspect "R:" range:[0.01, 100.0, 1.333] type:#float scale:0.001 fieldwidth:35 across:4 align:#left
        button btn_x2 "x2" width:25 height:18 offset:[-4,-1] 
        button btn_div2 "/2" width:25 height:18 offset:[-4,-1] 
        checkbutton ckb_lock "锁定" width:45 height:18 align:#right highlightColor:(color 255 200 100) 
        
        button btn_add "加" width:65 across:3 offset:[-8,4] height:20
        button btn_del "删" width:65 offset:[-8,4] height:20
        button btn_app "用" width:65 offset:[-8,4] height:20
        
        label lbl_div2 "─── 自定义命名预设 ───" align:#center offset:[0,5]
        
        edittext et_name "" fieldWidth:205 align:#center offset:[4,2]
        button btn_rename "重命名" width:100 height:22 across:2 align:#left offset:[6,2]
        button btn_add_tag "?标签" width:100 height:22 align:#right offset:[-6,2] toolTip:"将上方输入框的文字存为新标签"
        
        subRollout sub_tags "" width:220 height:95 offset:[0,4] align:#center

        button btn_save "绑定 F10" width:210 height:24 offset:[0,4] 

        fn vcm_getRatioStr w h = (
            local r = (w as float) / h
            local r_val = (floor (r * 1000 + 0.5)) / 1000.0
            return "(" + r_val as string + ")"
        )

        fn vcm_getCameraResInfo cam = (
            local w = undefined, h = undefined, source = "" 
            local p_w = #override_width, p_h = #override_height, p_en = #override_resolution
            if (isProperty cam p_w) and (isProperty cam p_h) do (
                local isEnabled = true
                if (isProperty cam p_en) do isEnabled = getProperty cam p_en
                if isEnabled == true or isEnabled == 1 or isEnabled == on do (
                    w = getProperty cam p_w; h = getProperty cam p_h; source = "VR"
                )
            )
            if (w == undefined) do (
                w = getUserProp cam "vray_script_w"; h = getUserProp cam "vray_script_h"
                if (w != undefined) do source = "手"
            )
            if (w != undefined and h != undefined) then (
                return #(w, h, (" [" + source + "] " + (w as integer) as string + "x" + (h as integer) as string + " " + vcm_getRatioStr w h), source)
            ) else return #(undefined, undefined, "", "")
        )

        fn compareCameraNames c1 c2 = (
            local n1 = toLower c1.name
            local n2 = toLower c2.name
            if n1 < n2 then -1 else if n1 > n2 then 1 else 0
        )

        fn refreshCameraList = (
            vcm_camList = for c in cameras where (classof c == VRayPhysicalCamera) collect c
            if ckb_sort_name.checked do ( qsort vcm_camList compareCameraNames )

            local oldSel = lb_cams.selection
            local rx = dotNetClass "System.Text.RegularExpressions.Regex"
            
            lb_cams.items = for c in vcm_camList collect (
                local info = vcm_getCameraResInfo c
                local suffix = info[3] 
                if info[1] != undefined do (
                    if rx.IsMatch c.name "_[0-9]+x[0-9]+\\([0-9\\.]+\\)$" do ( suffix = " [" + info[4] + "]" )
                )
                c.name + suffix
            )
            lb_cams.selection = oldSel
            lbl_status.text = "F10: " + renderWidth as string + "x" + renderHeight as string + " " + vcm_getRatioStr renderWidth renderHeight
        )

        fn applyNamePreset idx = (
            if idx > 0 and idx <= vcm_namePresetArr.count do (
                local nameStr = vcm_namePresetArr[idx]
                if nameStr != "" then (
                    local sel = lb_cams.selection as array
                    if sel.count > 0 do (
                        undo "Rename Preset" on (
                            for i in sel where isValidNode vcm_camList[i] do (
                                vcm_camList[i].name = uniqueName nameStr
                            )
                        )
                        refreshCameraList()
                    )
                )
            )
        )

        fn rebuildTagsUI = (
            for r in ro_vcm_main.sub_tags.rollouts do (
                removeSubRollout ro_vcm_main.sub_tags r
            )

            local str = "rollout ro_tags \"\" (\n"
            local x = 4; local y = 2
            local btnWidth = 38; local btnHeight = 22
            local xSpacing = 42; local ySpacing = 26
            local cols = 5
            
            str += "    label lbl_hint \"【操作提示】 左键: 应用 | 右键: 删除\" align:#center color:(color 130 130 130) offset:[0,2] height:15\n"
            y += 20
            
            for i = 1 to vcm_namePresetArr.count do (
                local row = (i - 1) / cols
                local col = mod (i - 1) cols
                local px = x + col * xSpacing
                local py = y + row * ySpacing
                
                local t = vcm_namePresetArr[i]
                local safeText = substituteString t "\"" "\\\""
                local displayTxt = if safeText.count > 3 then (substring safeText 1 2 + "..") else safeText
                
                str += "    button btn_tag_" + i as string + " \"" + displayTxt + "\" width:" + btnWidth as string + " height:" + btnHeight as string + " pos:[" + px as string + "," + py as string + "] toolTip:\"" + safeText + "\"\n"
                str += "    on btn_tag_" + i as string + " rightClick do ( if ro_vcm_main != undefined do ro_vcm_main.removeTag " + i as string + " )\n"
                str += "    on btn_tag_" + i as string + " pressed do ( if ro_vcm_main != undefined do ro_vcm_main.applyNamePreset " + i as string + " )\n"
            )
            str += ")\n"
            
            execute str
            addSubRollout ro_vcm_main.sub_tags ro_tags
        )

        fn removeTag idx = (
            if idx > 0 and idx <= vcm_namePresetArr.count do (
                deleteItem vcm_namePresetArr idx
                vcm_saveSettings()
                rebuildTagsUI()
            )
        )

        fn applyResToSelectedCamera w h = (
            renderWidth = w; renderHeight = h; renderSceneDialog.update()
            local selArr = (lb_cams.selection as array)
            local rx = dotNetClass "System.Text.RegularExpressions.Regex"
            
            for idx in selArr where idx <= vcm_camList.count do (
                local cam = vcm_camList[idx]
                local p_w = #override_width, p_h = #override_height, p_en = #override_resolution, p_lock = #override_lock_aspect
                
                if (isProperty cam p_w) do (
                    if (isProperty cam p_en) do setProperty cam p_en true
                    if (isProperty cam p_lock) do setProperty cam p_lock false 
                    setProperty cam p_w w; setProperty cam p_h h
                    setUserProp cam "vray_script_w" w; setUserProp cam "vray_script_h" h
                    
                    if ckb_auto_name.checked do (
                        local baseName = rx.Replace cam.name "_[0-9]+x[0-9]+\\([0-9\\.]+\\)$" ""
                        local rStr = vcm_getRatioStr w h
                        cam.name = baseName + "_" + (w as integer) as string + "x" + (h as integer) as string + rStr
                    )
                )
            )
            refreshCameraList()
        )

        fn updateAspectUI = ( if sp_rh.value != 0 do sp_aspect.value = (sp_rw.value as float) / sp_rh.value )
        fn refreshPresetsUI = ( lb_presets.items = for p in vcm_presetArr collect (p[1] as string + "x" + p[2] as string + " " + vcm_getRatioStr p[1] p[2]) )

        on ro_vcm_main open do ( 
            ckb_auto_name.checked = vcm_autoName
            ckb_sort_name.checked = vcm_sortByName
            refreshPresetsUI(); updateAspectUI(); refreshCameraList() 
            rebuildTagsUI()
            ckb_lock_render.checked = not rendUseActiveView
            callbacks.addScript #selectionSetChanged "vcm_syncSelectionFromScene()" id:#vcm_sync_sel
        )

        on ro_vcm_main close do ( callbacks.removeScripts id:#vcm_sync_sel )
        on ckb_lock_render changed state do ( rendUseActiveView = not state; renderSceneDialog.update() )
        on ckb_sort_name changed state do ( vcm_sortByName = state; vcm_saveSettings(); refreshCameraList() )

        on ckb_auto_name changed state do (
            vcm_autoName = state; vcm_saveSettings()
            if state == true do (
                local selArr = (lb_cams.selection as array)
                if selArr.count > 0 do (
                    local rx = dotNetClass "System.Text.RegularExpressions.Regex"
                    for idx in selArr where idx <= vcm_camList.count do (
                        local cam = vcm_camList[idx]
                        local info = vcm_getCameraResInfo cam
                        if info[1] != undefined do (
                            local w = info[1] as integer; local h = info[2] as integer
                            local baseName = rx.Replace cam.name "_[0-9]+x[0-9]+\\([0-9\\.]+\\)$" ""
                            cam.name = baseName + "_" + w as string + "x" + h as string + vcm_getRatioStr w h
                        )
                    )
                    refreshCameraList()
                )
            )
        )

        on lb_cams selected idx do ( if idx > 0 do ( local info = vcm_getCameraResInfo vcm_camList[idx]; if info[1] != undefined do lbl_status.text = "选: " + (info[1] as integer) as string + "x" + (info[2] as integer) as string ) )
        on lb_cams rightClick idx do ( 
            if idx > 0 do ( 
                lb_cams.selection = #{idx} 
                local info = vcm_getCameraResInfo vcm_camList[idx]
                if info[1] != undefined do ( 
                    renderWidth = info[1]; renderHeight = info[2]; renderSceneDialog.update() 
                    lbl_status.text = "选: " + (info[1] as integer) as string + "x" + (info[2] as integer) as string
                )
                local vID = if vcm_lockedViewID > 0 and viewport.numViews >= vcm_lockedViewID then vcm_lockedViewID else viewport.activeViewport
                try(viewport.activeViewport = vID; viewport.setCamera vcm_camList[idx]; completeRedraw())catch() 
            ) 
        )
        on btn_lock_view pressed do ( vcm_lockedViewID = viewport.activeViewport; lbl_status.text = "已锁定视口: " + vcm_lockedViewID as string )
        on btn_refresh pressed do refreshCameraList()
        on lb_cams doubleClicked idx do ( 
            if idx > 0 do (
                select vcm_camList[idx] 
                local vID = if vcm_lockedViewID > 0 and viewport.numViews >= vcm_lockedViewID then vcm_lockedViewID else viewport.activeViewport
                try(viewport.activeViewport = vID; viewport.setCamera vcm_camList[idx]; completeRedraw())catch() 
            )
        )
        on btn_help pressed do messageBox "操作说明:\n\n【动态标签预设】(修改版)\n- 在输入框打字（如“客厅”），点击【?标签】即可生成一个新的标签按钮。\n- 标签数量不限，超出显示范围会自动出现滚动条。\n- 左键点击标签：直接批量重命名选中相机。\n- 右键点击标签：永久删除该标签。\n\n【排序功能】\n- 勾选“排序”按钮，列表中相机将按名称拼音/字母强制排列。" title:"帮助"

        on lb_presets rightClick idx do ( if idx > 0 do applyResToSelectedCamera vcm_presetArr[idx][1] vcm_presetArr[idx][2] )
        on btn_swap pressed do ( local t = sp_rw.value; sp_rw.value = sp_rh.value; sp_rh.value = t; updateAspectUI() )
        on btn_x2 pressed do ( sp_rw.value = sp_rw.value * 2; sp_rh.value = sp_rh.value * 2; updateAspectUI() )
        on btn_div2 pressed do ( 
            local nw = sp_rw.value / 2; local nh = sp_rh.value / 2
            if nw < 1 do nw = 1; if nh < 1 do nh = 1
            sp_rw.value = nw; sp_rh.value = nh; updateAspectUI() 
        )

        -- [核心修改位置] 优化宽高、比例与锁定的联动逻辑
        on sp_rw changed val do ( if ckb_lock.checked then sp_rh.value = (val / sp_aspect.value) as integer else updateAspectUI() )
        on sp_rh changed val do ( if ckb_lock.checked then sp_rw.value = (val * sp_aspect.value) as integer else updateAspectUI() )
        on sp_aspect changed val do ( sp_rh.value = (sp_rw.value / val) as integer ) -- 无论是否锁定，修改比例都直接改变高度
        
        on lb_presets selected idx do ( if idx > 0 do ( sp_rw.value=vcm_presetArr[idx][1]; sp_rh.value=vcm_presetArr[idx][2]; updateAspectUI() ) )
        on lb_presets doubleClicked idx do ( if idx > 0 do applyResToSelectedCamera vcm_presetArr[idx][1] vcm_presetArr[idx][2] )
        on btn_add pressed do ( append vcm_presetArr [sp_rw.value, sp_rh.value]; vcm_savePresets(); refreshPresetsUI(); lb_presets.selection = vcm_presetArr.count )
        on btn_del pressed do ( if lb_presets.selection > 0 do ( deleteItem vcm_presetArr lb_presets.selection; vcm_savePresets(); refreshPresetsUI() ) )
        on btn_app pressed do ( applyResToSelectedCamera sp_rw.value sp_rh.value )
        
        on btn_rename pressed do ( 
            local sel = lb_cams.selection as array; 
            if sel.count > 0 and et_name.text != "" do ( 
                undo "Rename" on ( for i in sel where isValidNode vcm_camList[i] do vcm_camList[i].name = uniqueName et_name.text ); 
                refreshCameraList() 
            ) 
        )
        on btn_save pressed do ( applyResToSelectedCamera renderWidth renderHeight )

        on btn_add_tag pressed do (
            local txt = trimRight (trimLeft et_name.text)
            txt = substituteString txt "\"" ""
            txt = substituteString txt "\\" ""
            
            if txt != "" do (
                local idx = findItem vcm_namePresetArr txt
                if idx == 0 then (
                    append vcm_namePresetArr txt
                    vcm_saveSettings()
                    rebuildTagsUI()
                    et_name.text = "" 
                ) else (
                    messageBox "该标签已存在！" title:"提示"
                )
            )
        )
    )

    createDialog ro_vcm_main 240 760 style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
)

macros.run "_编码助手Tools" "VRayCamManager"