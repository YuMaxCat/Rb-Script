--============================================================
--  Yu Fly · 飞行脚本 V3（界面重制版）
--  悬停 / 摇杆加速移动 / 升降 / 速度档位
--============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function boot()
print("[YuFly] 1 boot start")

--------------------------------------------------------------
-- 主题
--------------------------------------------------------------
local T = {
    card     = Color3.fromRGB(255, 255, 255),
    cardEnd  = Color3.fromRGB(250, 250, 253),
    soft     = Color3.fromRGB(246, 246, 249),
    hover    = Color3.fromRGB(239, 239, 244),
    press    = Color3.fromRGB(231, 231, 238),
    line     = Color3.fromRGB(234, 234, 240),
    ink      = Color3.fromRGB(29, 29, 31),
    inkDim   = Color3.fromRGB(150, 150, 156),
    accent   = Color3.fromRGB(232, 150, 175),
    accentDk = Color3.fromRGB(220, 126, 154),
    track    = Color3.fromRGB(229, 229, 234),
    danger   = Color3.fromRGB(226, 96, 88),
    dangerBg = Color3.fromRGB(253, 236, 235),
}

local FONT_M, FONT_B = Enum.Font.GothamMedium, Enum.Font.GothamBold

local CARD_W, CARD_H = 216, 178
local BALL_SIZE      = 34

local TWEEN_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MID  = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_POP  = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_IN   = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TWEEN_MOVE = TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

--------------------------------------------------------------
-- 工具
--------------------------------------------------------------
local function tween(obj, info, goal)
    TweenService:Create(obj, info, goal):Play()
end

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
    return c
end

local function stroke(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function isPrimary(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function pressScale(btn, amount)
    local s = Instance.new("UIScale")
    s.Parent = btn
    btn.InputBegan:Connect(function(input)
        if isPrimary(input) then
            tween(s, TWEEN_FAST, {Scale = amount or 0.94})
        end
    end)
    btn.InputEnded:Connect(function(input)
        if isPrimary(input) then
            tween(s, TWEEN_FAST, {Scale = 1})
        end
    end)
end

local function pressFX(btn, base, hover, press)
    local current = base
    btn.BackgroundColor3 = base
    btn.MouseEnter:Connect(function()
        current = hover
        tween(btn, TWEEN_FAST, {BackgroundColor3 = hover})
    end)
    btn.MouseLeave:Connect(function()
        current = base
        tween(btn, TWEEN_FAST, {BackgroundColor3 = base})
    end)
    btn.InputBegan:Connect(function(input)
        if isPrimary(input) then
            tween(btn, TWEEN_FAST, {BackgroundColor3 = press})
        end
    end)
    btn.InputEnded:Connect(function(input)
        if isPrimary(input) then
            tween(btn, TWEEN_FAST, {BackgroundColor3 = current})
        end
    end)
end

local function makeButton(props)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.Text = ""
    for k, v in pairs(props) do
        b[k] = v
    end
    return b
end

--------------------------------------------------------------
-- 挂载点 & 清理旧实例
--------------------------------------------------------------
local old = playerGui:FindFirstChild("YuFly")
if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "YuFly"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
gui.Parent = playerGui
print("[YuFly] 2 ScreenGui mounted")

--------------------------------------------------------------
-- 根容器
--------------------------------------------------------------
local container = Instance.new("Frame")
container.Name = "Root"
container.BackgroundTransparency = 1
container.Size = UDim2.fromOffset(CARD_W, CARD_H)
container.Position = UDim2.fromOffset(40, 120)
container.ZIndex = 10
container.Parent = gui

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.92
shadow.Size = UDim2.fromOffset(CARD_W, CARD_H)
shadow.Position = UDim2.fromOffset(0, 5)
shadow.ZIndex = 1
shadow.Parent = container
corner(shadow, 16)

local card = Instance.new("Frame")
card.Name = "Card"
card.BackgroundColor3 = T.card
card.Size = UDim2.fromOffset(CARD_W, CARD_H)
card.ZIndex = 2
card.Parent = container
corner(card, 16)
stroke(card, T.line, 1, 0)

local cardGrad = Instance.new("UIGradient")
cardGrad.Rotation = 90
cardGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, T.card),
    ColorSequenceKeypoint.new(1, T.cardEnd),
}
cardGrad.Parent = card

local cardScale = Instance.new("UIScale")
cardScale.Parent = card
print("[YuFly] 3 card built")

--------------------------------------------------------------
-- 顶栏
--------------------------------------------------------------
local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 40)
header.ZIndex = 3
header.Parent = card

local dot = Instance.new("Frame")
dot.BackgroundColor3 = T.accent
dot.BorderSizePixel = 0
dot.Size = UDim2.fromOffset(8, 8)
dot.Position = UDim2.fromOffset(16, 16)
dot.ZIndex = 3
dot.Parent = header
corner(dot, 4)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(29, 0)
title.Size = UDim2.fromOffset(80, 40)
title.Font = FONT_B
title.Text = "Yu Fly"
title.TextColor3 = T.ink
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 3
title.Parent = header

local ver = Instance.new("TextLabel")
ver.BackgroundTransparency = 1
ver.Position = UDim2.fromOffset(80, 1)
ver.Size = UDim2.fromOffset(30, 40)
ver.Font = FONT_M
ver.Text = "V3.1"
ver.TextColor3 = T.inkDim
ver.TextSize = 10
ver.TextXAlignment = Enum.TextXAlignment.Left
ver.ZIndex = 3
ver.Parent = header

local minBtn = Instance.new("TextButton")
minBtn.Name = "Minimize"
minBtn.AutoButtonColor = false
minBtn.BackgroundColor3 = T.soft
minBtn.Position = UDim2.new(1, -72, 0, 6)
minBtn.Size = UDim2.fromOffset(28, 28)
minBtn.Font = FONT_M
minBtn.Text = "-"
minBtn.TextColor3 = T.inkDim
minBtn.TextSize = 14
minBtn.ZIndex = 3
minBtn.Parent = header
corner(minBtn, 9)

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.AutoButtonColor = false
closeBtn.BackgroundColor3 = T.soft
closeBtn.Position = UDim2.new(1, -40, 0, 6)
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Font = FONT_M
closeBtn.Text = "×"
closeBtn.TextColor3 = T.inkDim
closeBtn.TextSize = 15
closeBtn.ZIndex = 3
closeBtn.Parent = header
corner(closeBtn, 9)

local divider = Instance.new("Frame")
divider.BackgroundColor3 = T.line
divider.BorderSizePixel = 0
divider.BackgroundTransparency = 0.4
divider.Position = UDim2.fromOffset(16, 40)
divider.Size = UDim2.new(1, -32, 0, 1)
divider.ZIndex = 3
divider.Parent = card
print("[YuFly] 4 header built")

--------------------------------------------------------------
-- 飞行开关
--------------------------------------------------------------
local flyLabel = Instance.new("TextLabel")
flyLabel.BackgroundTransparency = 1
flyLabel.Position = UDim2.fromOffset(16, 48)
flyLabel.Size = UDim2.new(1, -80, 0, 24)
flyLabel.Font = FONT_M
flyLabel.Text = "飞行"
flyLabel.TextColor3 = T.ink
flyLabel.TextSize = 13
flyLabel.TextXAlignment = Enum.TextXAlignment.Left
flyLabel.ZIndex = 3
flyLabel.Parent = card

local track = Instance.new("TextButton")
track.Name = "Switch"
track.AutoButtonColor = false
track.BackgroundColor3 = T.track
track.Position = UDim2.new(1, -56, 0, 48)
track.Size = UDim2.fromOffset(40, 24)
track.Text = ""
track.ZIndex = 3
track.Parent = card
corner(track, 12)

local knob = Instance.new("TextButton")
knob.Name = "Knob"
knob.AutoButtonColor = false
knob.BackgroundColor3 = Color3.new(1, 1, 1)
knob.Text = ""
knob.Position = UDim2.fromOffset(3, 3)
knob.Size = UDim2.fromOffset(18, 18)
knob.ZIndex = 4
knob.Parent = track
corner(knob, 9)
stroke(knob, T.line, 1, 0.4)

--------------------------------------------------------------
-- 速度档位
--------------------------------------------------------------
local speedGroup = Instance.new("Frame")
speedGroup.BackgroundColor3 = T.soft
speedGroup.Position = UDim2.fromOffset(16, 84)
speedGroup.Size = UDim2.new(1, -32, 0, 34)
speedGroup.ZIndex = 3
speedGroup.Parent = card
corner(speedGroup, 10)

local minusBtn = Instance.new("TextButton")
minusBtn.Name = "SpeedDown"
minusBtn.AutoButtonColor = false
minusBtn.BackgroundColor3 = T.soft
minusBtn.Position = UDim2.fromOffset(0, 0)
minusBtn.Size = UDim2.fromOffset(36, 34)
minusBtn.Font = FONT_M
minusBtn.Text = "-"
minusBtn.TextColor3 = T.ink
minusBtn.TextSize = 15
minusBtn.ZIndex = 4
minusBtn.Parent = speedGroup
corner(minusBtn, 10)

local levelLabel = Instance.new("TextLabel")
levelLabel.BackgroundTransparency = 1
levelLabel.Position = UDim2.fromOffset(36, 0)
levelLabel.Size = UDim2.new(1, -72, 0, 34)
levelLabel.Font = FONT_B
levelLabel.Text = "×1"
levelLabel.TextColor3 = T.ink
levelLabel.TextSize = 14
levelLabel.ZIndex = 4
levelLabel.Parent = speedGroup

local levelScale = Instance.new("UIScale")
levelScale.Parent = levelLabel

local plusBtn = Instance.new("TextButton")
plusBtn.Name = "SpeedUp"
plusBtn.AutoButtonColor = false
plusBtn.BackgroundColor3 = T.soft
plusBtn.Position = UDim2.new(1, -36, 0, 0)
plusBtn.Size = UDim2.fromOffset(36, 34)
plusBtn.Font = FONT_M
plusBtn.Text = "+"
plusBtn.TextColor3 = T.ink
plusBtn.TextSize = 15
plusBtn.ZIndex = 4
plusBtn.Parent = speedGroup
corner(plusBtn, 10)

--------------------------------------------------------------
-- 上 / 下
--------------------------------------------------------------
local upBtn = Instance.new("TextButton")
upBtn.Name = "Up"
upBtn.AutoButtonColor = false
upBtn.BackgroundColor3 = T.soft
upBtn.Position = UDim2.fromOffset(16, 130)
upBtn.Size = UDim2.fromOffset(88, 34)
upBtn.Font = FONT_M
upBtn.Text = "上"
upBtn.TextColor3 = T.ink
upBtn.TextSize = 13
upBtn.ZIndex = 3
upBtn.Parent = card
corner(upBtn, 10)

local downBtn = Instance.new("TextButton")
downBtn.Name = "Down"
downBtn.AutoButtonColor = false
downBtn.BackgroundColor3 = T.soft
downBtn.Position = UDim2.fromOffset(112, 130)
downBtn.Size = UDim2.fromOffset(88, 34)
downBtn.Font = FONT_M
downBtn.Text = "下"
downBtn.TextColor3 = T.ink
downBtn.TextSize = 13
downBtn.ZIndex = 3
downBtn.Parent = card
corner(downBtn, 10)

--------------------------------------------------------------
-- 收起后的悬浮球
--------------------------------------------------------------
local ball = makeButton({
    Name = "Ball",
    BackgroundColor3 = T.accent,
    Size = UDim2.fromOffset(BALL_SIZE, BALL_SIZE),
    Position = UDim2.fromOffset(0, 0),
    Visible = false,
    ZIndex = 12,
})
ball.Parent = container
corner(ball, BALL_SIZE / 2)

local ballGrad = Instance.new("UIGradient")
ballGrad.Rotation = 135
ballGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, T.accent),
    ColorSequenceKeypoint.new(1, T.accentDk),
}
ballGrad.Parent = ball

local ballIcon = Instance.new("ImageLabel")
ballIcon.Name = "Icon"
ballIcon.BackgroundTransparency = 1
ballIcon.AnchorPoint = Vector2.new(0.5, 0.5)
ballIcon.Position = UDim2.fromScale(0.5, 0.5)
ballIcon.Size = UDim2.fromScale(1, 1)
ballIcon.Image = "rbxassetid://132684760428971"
ballIcon.ScaleType = Enum.ScaleType.Crop
ballIcon.ZIndex = 13
ballIcon.Parent = ball
corner(ballIcon, BALL_SIZE / 2)

local ballScale = Instance.new("UIScale")
ballScale.Parent = ball
print("[YuFly] 5 controls built")

--------------------------------------------------------------
-- 交互修饰
--------------------------------------------------------------
pressFX(minBtn, T.soft, T.hover, T.press)
pressFX(closeBtn, T.soft, T.dangerBg, Color3.fromRGB(248, 222, 220))
pressFX(minusBtn, T.soft, T.hover, T.press)
pressFX(plusBtn, T.soft, T.hover, T.press)
pressFX(upBtn, T.soft, T.hover, T.press)
pressFX(downBtn, T.soft, T.hover, T.press)

pressScale(minBtn, 0.92)
pressScale(closeBtn, 0.92)
pressScale(minusBtn, 0.94)
pressScale(plusBtn, 0.94)
pressScale(upBtn, 0.94)
pressScale(downBtn, 0.94)

ball.InputBegan:Connect(function(input)
    if isPrimary(input) then
        tween(ballScale, TWEEN_FAST, {Scale = 0.92})
    end
end)
ball.InputEnded:Connect(function(input)
    if isPrimary(input) then
        tween(ballScale, TWEEN_FAST, {Scale = 1})
    end
end)

closeBtn.MouseEnter:Connect(function()
    tween(closeBtn, TWEEN_FAST, {TextColor3 = T.danger})
end)
closeBtn.MouseLeave:Connect(function()
    tween(closeBtn, TWEEN_FAST, {TextColor3 = T.inkDim})
end)

local trackScale = Instance.new("UIScale")
trackScale.Parent = track
track.InputBegan:Connect(function(input)
    if isPrimary(input) then
        tween(trackScale, TWEEN_FAST, {Scale = 0.94})
    end
end)
track.InputEnded:Connect(function(input)
    if isPrimary(input) then
        tween(trackScale, TWEEN_FAST, {Scale = 1})
    end
end)

--------------------------------------------------------------
-- 飞行核心
--------------------------------------------------------------
local flying = false
local speedLevel = 1
local bodyGyro, bodyVelocity

local setSwitchVisual, stopFlight

local dotThread = false

setSwitchVisual = function(on)
    tween(track, TWEEN_MID, {BackgroundColor3 = on and T.accent or T.track})
    tween(knob, TWEEN_MID, {Position = on and UDim2.fromOffset(19, 3) or UDim2.fromOffset(3, 3)})
    dot.BackgroundColor3 = on and T.accent or T.accentDk
    dot.BackgroundTransparency = 0

    if on and not dotThread then
        dotThread = true
        task.spawn(function()
            while flying do
                tween(dot, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.55})
                task.wait(1.1)
                if not flying then break end
                tween(dot, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 0})
                task.wait(1.1)
            end
            dot.BackgroundTransparency = 0
            dotThread = false
        end)
    end
end

local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Yu Fly",
            Text = text,
            Duration = 2,
            Icon = "rbxthumb://type=Asset&id=5107182114&w=150&h=150",
        })
    end)
end

local STATES = {
    Enum.HumanoidStateType.Climbing,
    Enum.HumanoidStateType.FallingDown,
    Enum.HumanoidStateType.Flying,
    Enum.HumanoidStateType.Freefall,
    Enum.HumanoidStateType.GettingUp,
    Enum.HumanoidStateType.Jumping,
    Enum.HumanoidStateType.Landed,
    Enum.HumanoidStateType.Physics,
    Enum.HumanoidStateType.PlatformStanding,
    Enum.HumanoidStateType.Ragdoll,
    Enum.HumanoidStateType.Running,
    Enum.HumanoidStateType.RunningNoPhysics,
    Enum.HumanoidStateType.Seated,
    Enum.HumanoidStateType.StrafingNoPhysics,
    Enum.HumanoidStateType.Swimming,
}

local function getHumanoid()
    local char = player.Character
    return char, char and char:FindFirstChildOfClass("Humanoid")
end

local function setStates(restore)
    local _, hum = getHumanoid()
    if not hum then return end
    for _, state in ipairs(STATES) do
        pcall(function()
            hum:SetStateEnabled(state, restore)
        end)
    end
    local target = restore and Enum.HumanoidStateType.RunningNoPhysics or Enum.HumanoidStateType.Swimming
    pcall(function()
        hum:ChangeState(target)
    end)
end

local function setAnimationFrozen(frozen)
    local char = player.Character
    if not char then return end
    local animate = char:FindFirstChild("Animate")
    if animate then
        animate.Disabled = frozen
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        local animator = hum:FindFirstChildOfClass("Animator")
        local tracks = animator and animator:GetPlayingAnimationTracks() or hum:GetPlayingAnimationTracks()
        for _, animTrack in ipairs(tracks) do
            animTrack:AdjustSpeed(frozen and 0 or 1)
        end
    end)
end

stopFlight = function(auto)
    if not flying then return end
    flying = false

    if bodyGyro then
        pcall(function() bodyGyro:Destroy() end)
        bodyGyro = nil
    end
    if bodyVelocity then
        pcall(function() bodyVelocity:Destroy() end)
        bodyVelocity = nil
    end

    setAnimationFrozen(false)
    setStates(true)

    local _, hum = getHumanoid()
    if hum then
        hum.PlatformStand = false
    end

    if auto then
        setSwitchVisual(false)
        notify("角色已重生，飞行已关闭")
    end
end

local function startFlight()
    local char, hum = getHumanoid()
    if not (char and hum) then return false end

    local part
    if hum.RigType == Enum.HumanoidRigType.R6 then
        part = char:FindFirstChild("Torso")
    else
        part = char:FindFirstChild("UpperTorso")
    end
    part = part or char:FindFirstChild("HumanoidRootPart")
    if not part then return false end

    flying = true

    setAnimationFrozen(true)
    setStates(false)
    hum.PlatformStand = true

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.P = 9e4
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.CFrame = part.CFrame
    bodyGyro.Parent = part

    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVelocity.Parent = part

    -- 摇杆加速移动
    task.spawn(function()
        while flying do
            RunService.Heartbeat:Wait()
            if not flying then break end
            local charNow = player.Character
            local humNow = charNow and charNow:FindFirstChildOfClass("Humanoid")
            if charNow and humNow and humNow.Parent and humNow.MoveDirection.Magnitude > 0 then
                for _ = 1, speedLevel do
                    charNow:TranslateBy(humNow.MoveDirection)
                end
            end
        end
    end)

    -- 悬停姿态跟随相机
    task.spawn(function()
        while flying do
            RunService.RenderStepped:Wait()
            if not flying then break end
            local charNow, humNow = getHumanoid()
            if not (charNow and humNow and humNow.Parent and humNow.Health > 0) then
                break
            end
            local camera = workspace.CurrentCamera
            if camera and bodyGyro then
                bodyGyro.CFrame = camera.CFrame
            end
            if bodyVelocity then
                bodyVelocity.Velocity = Vector3.zero
            end
        end
        if flying then
            stopFlight(true)
        end
    end)

    return true
end

local function toggleFlight()
    if flying then
        stopFlight(false)
        setSwitchVisual(false)
    else
        if startFlight() then
            setSwitchVisual(true)
        else
            notify("角色还没加载好")
        end
    end
end

local function setSpeedLevel(value)
    speedLevel = math.clamp(value, 1, 20)
    levelLabel.Text = "×" .. speedLevel
    levelScale.Scale = 1.18
    tween(levelScale, TWEEN_MID, {Scale = 1})
end

--------------------------------------------------------------
-- 上 / 下：按住持续升降（手机也能用）
--------------------------------------------------------------
local holdStops = {}

local function bindHold(button, direction)
    local holding = false
    holdStops[#holdStops + 1] = function()
        holding = false
    end

    button.InputBegan:Connect(function(input)
        if not isPrimary(input) or holding then return end
        holding = true
        task.spawn(function()
            while holding do
                RunService.Heartbeat:Wait()
                if not holding then break end
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = root.CFrame * CFrame.new(0, direction, 0)
                end
            end
        end)
    end)

    local function release(input)
        if isPrimary(input) then
            holding = false
        end
    end
    button.InputEnded:Connect(release)
    UserInputService.InputEnded:Connect(release)
end

bindHold(upBtn, 1)
bindHold(downBtn, -1)

--------------------------------------------------------------
-- 收起 / 展开
--------------------------------------------------------------
local minimized = false
local BALL_HOME   = UDim2.fromOffset(0, 0)
local BALL_CENTER = UDim2.fromOffset(
    math.floor((CARD_W - BALL_SIZE) / 2),
    math.floor((CARD_H - BALL_SIZE) / 2)
)

local setMinimized
setMinimized = function(value)
    if value == minimized then return end
    minimized = value

    if value then
        -- 卡片缩回中心，小窗从卡片中心飞向左上角
        tween(cardScale, TWEEN_IN, {Scale = 0.84})
        task.delay(0.16, function()
            if not minimized then return end
            card.Visible = false
            shadow.Visible = false
            container.Size = UDim2.fromOffset(BALL_SIZE, BALL_SIZE)
            ball.Position = BALL_CENTER
            ballScale.Scale = 0.5
            ball.Visible = true
            tween(ballScale, TWEEN_POP, {Scale = 1})
            tween(ball, TWEEN_MOVE, {Position = BALL_HOME})
        end)
    else
        -- 小窗飞回卡片中心，卡片从中心弹开
        tween(ball, TWEEN_MOVE, {Position = BALL_CENTER})
        tween(ballScale, TWEEN_IN, {Scale = 0.5})
        task.delay(0.26, function()
            if minimized then return end
            ball.Visible = false
            ball.Position = BALL_HOME
            container.Size = UDim2.fromOffset(CARD_W, CARD_H)
            card.Visible = true
            shadow.Visible = true
            cardScale.Scale = 0.84
            tween(cardScale, TWEEN_POP, {Scale = 1})
        end)
    end
end

--------------------------------------------------------------
-- 拖动
--------------------------------------------------------------
local function clampToScreen(x, y)
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local size = container.AbsoluteSize
    x = math.clamp(x, -size.X + 56, viewport.X - 56)
    y = math.clamp(y, 0, viewport.Y - 48)
    return x, y
end

local function makeDraggable(handle)
    local dragging = false
    local dragBegin, origin

    handle.InputBegan:Connect(function(input)
        if not isPrimary(input) then return end
        dragging = true
        dragBegin = input.Position
        origin = container.Position
    end)

    handle.InputEnded:Connect(function(input)
        if isPrimary(input) then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = input.Position - dragBegin
        local x, y = clampToScreen(origin.X.Offset + delta.X, origin.Y.Offset + delta.Y)
        container.Position = UDim2.fromOffset(x, y)
    end)

    UserInputService.InputEnded:Connect(function(input)
        if isPrimary(input) then
            dragging = false
        end
    end)
end

makeDraggable(header)
makeDraggable(ball)

--------------------------------------------------------------
-- 事件
--------------------------------------------------------------
track.MouseButton1Click:Connect(toggleFlight)
knob.MouseButton1Click:Connect(toggleFlight)

plusBtn.MouseButton1Click:Connect(function()
    setSpeedLevel(speedLevel + 1)
end)

minusBtn.MouseButton1Click:Connect(function()
    setSpeedLevel(speedLevel - 1)
end)

minBtn.MouseButton1Click:Connect(function()
    setMinimized(true)
end)

ball.MouseButton1Click:Connect(function()
    setMinimized(false)
end)

closeBtn.MouseButton1Click:Connect(function()
    for _, stop in ipairs(holdStops) do
        stop()
    end
    if flying then
        stopFlight(false)
    end
    gui:Destroy()
end)

player.CharacterAdded:Connect(function()
    task.wait(0.7)
    if not gui.Parent then return end
    local char = player.Character
    if char then
        local animate = char:FindFirstChild("Animate")
        if animate then
            animate.Disabled = false
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
        end
    end
    if flying then
        stopFlight(true)
    end
end)

--------------------------------------------------------------
-- 初始化
--------------------------------------------------------------
task.defer(function()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local x, y = clampToScreen(viewport.X * 0.08, viewport.Y * 0.30)
    container.Position = UDim2.fromOffset(x, y)
end)

setSpeedLevel(1)
setSwitchVisual(false)
cardScale.Scale = 0.90
tween(cardScale, TWEEN_POP, {Scale = 1})
notify("已加载 · 打开开关即可飞行")
print("[YuFly] 6 init done")

end

--------------------------------------------------------------
-- 启动 & 错误面板（构建失败时把原因直接显示在屏幕上）
--------------------------------------------------------------
local ok, err = xpcall(boot, function(message)
    return tostring(message) .. "\n" .. debug.traceback("", 2)
end)

if not ok then
    warn("[Yu Fly] " .. err)
    pcall(function()
        local oldError = playerGui:FindFirstChild("YuFlyError")
        if oldError then
            oldError:Destroy()
        end

        local errorGui = Instance.new("ScreenGui")
        errorGui.Name = "YuFlyError"
        errorGui.ResetOnSpawn = false
        errorGui.DisplayOrder = 100000
        errorGui.Parent = playerGui

        local panel = Instance.new("Frame")
        panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        panel.BorderColor3 = Color3.fromRGB(226, 96, 88)
        panel.BorderSizePixel = 1
        panel.Position = UDim2.new(0, 24, 0, 100)
        panel.Size = UDim2.new(1, -48, 0, 200)
        panel.Parent = errorGui

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Text = "Yu Fly 出错了：\n\n" .. err
        label.Font = Enum.Font.SourceSans
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(200, 50, 50)
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.Size = UDim2.new(1, -20, 1, -20)
        label.Position = UDim2.fromOffset(10, 10)
        label.Parent = panel
    end)
end
