try(destroyDialog timeNavRollout)catch() -- 如果窗口已存在，先关闭它

rollout timeNavRollout "灵感时间控制器" width:220 height:160
(
    -- 1. 顶部：实时信息显示
    group "当前状态"
    (
        label lbl_currentFrame "第 0 帧" style_sunken:true height:25 align:#center offset:[0,5] 
    )

    -- 2. 中部：步长设置
    group "跳转设置"
    (
        spinner spn_step "每次跳跃帧数:" range:[1, 10000, 30] type:#integer fieldwidth:50 align:#center
    )
    
    -- 3. 底部：控制按钮
    group "操作"
    (
        -- 使用 across:2 让两个按钮并排显示
        button btn_back "<< 后退" width:80 height:30 highlightColor:[255,100,0] across:2
        button btn_fwd "前进 >>" width:80 height:30 highlightColor:[0,255,0]
    )
    
    -- ------------------------------------------------
    -- 功能函数定义区
    -- ------------------------------------------------
    
    -- 定义一个更新界面的函数
    fn updateDisplay =
    (
        -- 获取当前时间并转为整数帧
        local curF = (currentTime.frame as integer)
        -- 更新标签文本
        lbl_currentFrame.text = "当前：第 " + (curF as string) + " 帧"
    )

    -- ------------------------------------------------
    -- 事件处理区
    -- ------------------------------------------------

    -- 窗口打开时：注册时间回调（让数字跟随时间轴变动）
    on timeNavRollout open do
    (
        updateDisplay() -- 打开时先刷新一次
        registerTimeCallback updateDisplay -- 注册“时间改变”监听器
    )

    -- 窗口关闭时：取消回调（节省资源，防止报错）
    on timeNavRollout close do
    (
        unregisterTimeCallback updateDisplay
    )

    -- 按钮：向后跳转
    on btn_back pressed do
    (
        sliderTime -= spn_step.value
        -- 注意：sliderTime 改变会自动触发上面的 timeCallback，所以不需要手动调用 updateDisplay
    )

    -- 按钮：向前跳转
    on btn_fwd pressed do
    (
        sliderTime += spn_step.value
    )
)

-- 创建对话框
createDialog timeNavRollout