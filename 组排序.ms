try(destroyDialog GroupChecker)catch()

rollout GroupChecker "组模型统计与清理器" width:350 height:480 (
    label lbl_info "提示：双击列表中的项目可以直接选中该组" align:#left offset:[0,5]
    
    -- 列表框
    listbox lb_groups "场景组列表 ( 组名称 | 包含对象数量 )：" height:22 offset:[0,10]
    
    -- 刷新与清理按钮
    button btn_refresh "刷新列表" width:310 height:30 offset:[0,5]
    button btn_cleanSingle "一键解散单对象组 (仅包含1个物体的组)" width:310 height:35 offset:[0,5]

    -- 存储对应的组节点
    local groupNodesArray = #() 

    -- 递归计算所有子对象数量
    fn getDescendantCount node = (
        local count = 0
        for c in node.children do (
            count += 1
            count += getDescendantCount c
        )
        return count
    )

    -- 加载并排序组
    fn loadGroups = (
        groupNodesArray = #()
        local groupData = #()

        for obj in objects where isGroupHead obj do (
            local childCount = getDescendantCount obj
            append groupData #(obj, childCount)
        )

        fn sortDesc a b = (
            if a[2] < b[2] then 1
            else if a[2] > b[2] then -1
            else 0
        )
        
        if groupData.count > 0 then (
            qsort groupData sortDesc
        )

        local listItems = #()
        for d in groupData do (
            append groupNodesArray d[1]
            local str = d[1].name + "  --->  [ " + (d[2] as string) + " 个对象 ]"
            append listItems str
        )

        if listItems.count == 0 then (
            listItems = #("场景中没有找到任何组！")
        )

        lb_groups.items = listItems
    )

    -- 打开窗口时加载
    on GroupChecker open do (
        loadGroups()
    )

    -- 刷新按钮事件
    on btn_refresh pressed do (
        loadGroups()
    )

    -- 列表双击选中事件
    on lb_groups doubleClicked itm do (
        if groupNodesArray.count > 0 and itm <= groupNodesArray.count do (
            select groupNodesArray[itm]
        )
    )

    -- 【新增】：清理单对象组的核心逻辑
    on btn_cleanSingle pressed do (
        -- 开启 Undo 记录，允许你反悔按 Ctrl+Z 撤销
        undo "清理单对象组" on (
            local cleanedCount = 0
            local keepChecking = true
            
            -- 使用 while 循环，解决“组套组套组”的嵌套问题
            while keepChecking do (
                keepChecking = false
                
                -- 找出所有子节点数量刚好等于 1 的组头
                local targets = for obj in objects where isGroupHead obj and obj.children.count == 1 collect obj
                
                if targets.count > 0 do (
                    keepChecking = true
                    for t in targets do (
                        if isValidNode t do (
                            setGroupOpen t false  -- 确保组是关闭状态再解散
                            ungroup t             -- 解散组
                            cleanedCount += 1
                        )
                    )
                )
            )
            
            -- 清理完毕后弹窗提示，并自动刷新上方的列表
            messageBox ("清理完成！\n共解散了 " + (cleanedCount as string) + " 个没有意义的“单对象组”。") title:"清理报告"
            loadGroups() 
        )
    )
)

-- 创建窗口
createDialog GroupChecker