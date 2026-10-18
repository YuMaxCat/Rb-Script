--[[
    Yu HUB  |  WindUI
    功能：飞行 / 速度提升 / 跳跃提升 / 传送到玩家 / 音乐播放器
    适用于 PC 与手机执行器（Delta 等）
--]]

-- 重复执行时先清掉上一个实例
if type(getgenv().YuHUBCleanup) == "function" then
    pcall(getgenv().YuHUBCleanup)
    getgenv().YuHUBCleanup = nil
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- 读取当前角色属性做默认值，避免一执行就把游戏的移速/跳跃重置
local defaultWalk, defaultJump = 16, 50
do
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.WalkSpeed >= 1 then
            defaultWalk = math.clamp(math.floor(hum.WalkSpeed + 0.5), 16, 500)
        end
        if hum.UseJumpPower and hum.JumpPower >= 50 then
            defaultJump = math.clamp(math.floor(hum.JumpPower + 0.5), 50, 500)
        end
    end
end

local defaultFov = 70
do
    local cam = workspace.CurrentCamera
    if cam and cam.FieldOfView >= 40 then
        defaultFov = math.clamp(math.floor(cam.FieldOfView + 0.5), 40, 120)
    end
end

local defaultGravity = workspace.Gravity
local defaultClock = Lighting.ClockTime
local defaultMaxZoom = LocalPlayer.CameraMaxZoomDistance

local state = {
    fly = false,
    flySpeed = 60,
    walkSpeed = defaultWalk,
    jumpPower = defaultJump,
    walkChanged = false,
    jumpChanged = false,
    infJump = false,
    noclip = false,
    freeze = false,
    fullbright = false,
    playerEsp = false,
    nameTags = false,
    hidePlayers = false,
    selfInvisible = false,
    espRange = 500,
    antiAfk = false,
    fov = defaultFov,
    gravity = defaultGravity,
    gravityChanged = false,
    clockChanged = false,
    zoomChanged = false,
    savedPos = nil,
    musicId = "",
    loopMusic = false,
}

-- ===== 工具函数 =====

local function notify(title, content)
    WindUI:Notify({
        Title = title,
        Content = content,
        Icon = "info",
        Duration = 3,
    })
end

local function getCharacter()
    local char = LocalPlayer.Character
    if not char then
        return nil
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then
        return nil
    end
    return char, hum, hrp
end

-- ===== 飞行（Yu-Fly 架构：PlatformStand + 状态锁定 + 陀螺仪朝向 + 直接平移） =====

local flyConnection = nil
local flyVelocity = nil
local flyGyro = nil
local flyToggle = nil

local FLY_STATES = {
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

local function setFlyStates(restore)
    local _, hum = getCharacter()
    if not hum then
        return
    end
    for _, flyState in ipairs(FLY_STATES) do
        pcall(function()
            hum:SetStateEnabled(flyState, restore)
        end)
    end
    pcall(function()
        hum:ChangeState(
            restore and Enum.HumanoidStateType.RunningNoPhysics or Enum.HumanoidStateType.Swimming
        )
    end)
end

local function setFlyAnimations(frozen)
    local char = LocalPlayer.Character
    if not char then
        return
    end
    local animate = char:FindFirstChild("Animate")
    if animate then
        animate.Disabled = frozen
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    pcall(function()
        local animator = hum:FindFirstChildOfClass("Animator")
        local tracks = animator and animator:GetPlayingAnimationTracks() or hum:GetPlayingAnimationTracks()
        for _, track in ipairs(tracks) do
            track:AdjustSpeed(frozen and 0 or 1)
        end
    end)
end

local function stopFly()
    if not state.fly and not flyConnection then
        return
    end
    state.fly = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if flyGyro then
        pcall(function()
            flyGyro:Destroy()
        end)
        flyGyro = nil
    end
    if flyVelocity then
        pcall(function()
            flyVelocity:Destroy()
        end)
        flyVelocity = nil
    end

    pcall(setFlyAnimations, false)
    pcall(setFlyStates, true)

    local _, hum = getCharacter()
    if hum then
        hum.PlatformStand = false
    end
end

local function autoStopFly(reason)
    if not state.fly then
        return
    end
    stopFly()
    if flyToggle then
        pcall(function()
            flyToggle:Set(false)
        end)
    end
    notify("飞行", reason)
end

local function startFly()
    stopFly()

    local char, hum = getCharacter()
    if not char or not hum then
        return false
    end

    local part
    if hum.RigType == Enum.HumanoidRigType.R6 then
        part = char:FindFirstChild("Torso")
    else
        part = char:FindFirstChild("UpperTorso")
    end
    part = part or char:FindFirstChild("HumanoidRootPart")
    if not part then
        return false
    end

    state.fly = true

    setFlyAnimations(true)
    setFlyStates(false)
    hum.PlatformStand = true

    local gyro = Instance.new("BodyGyro")
    gyro.Name = "YuHUB_FlyGyro"
    gyro.P = 9e4
    gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    gyro.CFrame = part.CFrame
    gyro.Parent = part
    flyGyro = gyro

    local bv = Instance.new("BodyVelocity")
    bv.Name = "YuHUB_FlyVelocity"
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = part
    flyVelocity = bv

    flyConnection = RunService.Heartbeat:Connect(function(dt)
        if not state.fly then
            return
        end

        local charNow, humNow = getCharacter()
        if not charNow or not humNow or humNow.Health <= 0 then
            autoStopFly("角色状态变化，飞行已关闭")
            return
        end
        if not flyGyro or not flyGyro.Parent then
            return
        end

        local cam = workspace.CurrentCamera

        -- 悬停姿态跟随相机
        if cam then
            flyGyro.CFrame = cam.CFrame
        end
        if flyVelocity then
            flyVelocity.Velocity = Vector3.zero
        end

        -- Yu-Fly 核心：直接平移角色，不走物理速度
        local move = humNow.MoveDirection
        local step = Vector3.zero
        if move.Magnitude > 0.05 then
            step = move.Unit * state.flySpeed * dt
        end

        -- 手机：摇杆前推时按视角俯仰升降；PC 再加空格 / Ctrl
        local vertical = 0
        if move.Magnitude > 0.05 and cam then
            local look = cam.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            if flat.Magnitude > 1e-3 then
                local forwardAmount = move.Unit:Dot(flat.Unit)
                vertical = look.Y * forwardAmount * state.flySpeed * dt
            end
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            vertical = vertical + state.flySpeed * dt
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            vertical = vertical - state.flySpeed * dt
        end

        if step.Magnitude > 0 or vertical ~= 0 then
            charNow:TranslateBy(step + Vector3.new(0, vertical, 0))
        end
    end)

    return true
end

-- ===== 无限跳 =====

local infJumpConn = nil

local function setInfiniteJump(on)
    state.infJump = on
    if infJumpConn then
        infJumpConn:Disconnect()
        infJumpConn = nil
    end
    if on then
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            local _, hum = getCharacter()
            if hum and hum.Health > 0 then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

-- ===== 穿墙 =====

local noclipConn = nil
local noclipSaved = setmetatable({}, { __mode = "k" })

local function setNoclip(on)
    state.noclip = on
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end

    if on then
        noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then
                return
            end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    noclipSaved[part] = true
                    part.CanCollide = false
                end
            end
        end)
    else
        for part in pairs(noclipSaved) do
            if part.Parent then
                pcall(function()
                    part.CanCollide = true
                end)
            end
        end
        noclipSaved = setmetatable({}, { __mode = "k" })
    end
end

-- ===== 冻结角色 =====

local function setFreeze(on)
    if state.freeze == on then
        return
    end
    state.freeze = on
    local _, _, hrp = getCharacter()
    if hrp then
        hrp.Anchored = on
    end
end

-- ===== 全亮 =====

local lightingSaved = nil

local function setFullbright(on)
    state.fullbright = on
    if on then
        if not lightingSaved then
            lightingSaved = {
                Brightness = Lighting.Brightness,
                ClockTime = Lighting.ClockTime,
                GlobalShadows = Lighting.GlobalShadows,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                ExposureCompensation = Lighting.ExposureCompensation,
                FogStart = Lighting.FogStart,
                FogEnd = Lighting.FogEnd,
            }
        end
        pcall(function()
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(200, 200, 200)
            Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
            Lighting.ExposureCompensation = 0
            Lighting.FogStart = 100000
            Lighting.FogEnd = 100000
        end)
    elseif lightingSaved then
        local saved = lightingSaved
        lightingSaved = nil
        pcall(function()
            for key, value in pairs(saved) do
                Lighting[key] = value
            end
        end)
    end
end

-- ===== 玩家视觉（高亮 / 名字距离 / 隐藏玩家） =====

local visualsConn = nil
local espHighlights = {}
local nameTags = {}
local hiddenParts = setmetatable({}, { __mode = "k" })

local function tagText(player, root)
    local _, _, myRoot = getCharacter()
    if not myRoot then
        return player.Name
    end
    local dist = math.floor((root.Position - myRoot.Position).Magnitude + 0.5)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        return string.format("%s  [%d]  %dHP", player.Name, dist, math.floor(hum.Health + 0.5))
    end
    return string.format("%s  [%d]", player.Name, dist)
end

local function ensureHighlight(player)
    if player == LocalPlayer then
        return
    end
    local char = player.Character
    if not char then
        return
    end

    local highlight = espHighlights[player]
    if highlight and highlight.Parent then
        if highlight.Adornee ~= char then
            highlight.Adornee = char
        end
        return
    end

    highlight = Instance.new("Highlight")
    highlight.Name = "YuHUB_ESP"
    highlight.FillColor = Color3.fromRGB(232, 150, 175)
    highlight.FillTransparency = 1
    highlight.OutlineColor = Color3.fromRGB(232, 150, 175)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = char
    highlight.Parent = LocalPlayer:WaitForChild("PlayerGui")
    espHighlights[player] = highlight
end

local function ensureNameTag(player)
    if player == LocalPlayer then
        return
    end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local tag = nameTags[player]
    if tag and tag.Parent then
        if tag.Adornee ~= root then
            tag.Adornee = root
        end
        local label = tag:FindFirstChildOfClass("TextLabel")
        if label then
            label.Text = tagText(player, root)
        end
        return
    end

    tag = Instance.new("BillboardGui")
    tag.Name = "YuHUB_Name"
    tag.Size = UDim2.fromOffset(160, 22)
    tag.StudsOffset = Vector3.new(0, 2.6, 0)
    tag.AlwaysOnTop = true
    tag.LightInfluence = 0
    tag.Adornee = root
    tag.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(232, 150, 175)
    label.TextStrokeTransparency = 0.45
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Text = tagText(player, root)
    label.Parent = tag

    nameTags[player] = tag
end

local function clearHighlights()
    for _, highlight in pairs(espHighlights) do
        if highlight then
            highlight:Destroy()
        end
    end
    espHighlights = {}
end

local function clearNameTags()
    for _, tag in pairs(nameTags) do
        if tag then
            tag:Destroy()
        end
    end
    nameTags = {}
end

local function restoreHiddenParts()
    for part, original in pairs(hiddenParts) do
        if part.Parent then
            pcall(function()
                part.LocalTransparencyModifier = original
            end)
        end
    end
    hiddenParts = setmetatable({}, { __mode = "k" })
end

local function hideCharacter(char)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if hiddenParts[part] == nil then
                hiddenParts[part] = part.LocalTransparencyModifier
            end
            part.LocalTransparencyModifier = 1
        end
    end
end

local function scanVisuals()
    local _, _, myRoot = getCharacter()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local close = true
            if root and myRoot then
                close = (root.Position - myRoot.Position).Magnitude <= state.espRange
            end

            if state.playerEsp then
                pcall(ensureHighlight, player)
                local highlight = espHighlights[player]
                if highlight then
                    highlight.Enabled = close
                end
            end

            if state.nameTags then
                pcall(ensureNameTag, player)
                local tag = nameTags[player]
                if tag then
                    tag.Enabled = close
                end
            end

            if state.hidePlayers and char then
                hideCharacter(char)
            end
        end
    end

    for player, highlight in pairs(espHighlights) do
        if player == LocalPlayer or not player.Parent then
            highlight:Destroy()
            espHighlights[player] = nil
        end
    end
    for player, tag in pairs(nameTags) do
        if player == LocalPlayer or not player.Parent then
            tag:Destroy()
            nameTags[player] = nil
        end
    end
end

local function refreshVisuals()
    local active = state.playerEsp or state.nameTags or state.hidePlayers

    if active and not visualsConn then
        local lastScan = 0
        visualsConn = RunService.Heartbeat:Connect(function()
            local now = os.clock()
            if now - lastScan < 0.5 then
                return
            end
            lastScan = now
            scanVisuals()
        end)
    elseif not active and visualsConn then
        visualsConn:Disconnect()
        visualsConn = nil
    end

    if not state.playerEsp then
        clearHighlights()
    end
    if not state.nameTags then
        clearNameTags()
    end
    if not state.hidePlayers then
        restoreHiddenParts()
    end

    if active then
        scanVisuals()
    end
end

local function setPlayerEsp(on)
    state.playerEsp = on
    refreshVisuals()
end

local function setPlayerNameTags(on)
    state.nameTags = on
    refreshVisuals()
end

local function setHidePlayers(on)
    state.hidePlayers = on
    refreshVisuals()
end

-- ===== 本地隐身 =====

local selfInvisConn = nil
local selfInvisSaved = setmetatable({}, { __mode = "k" })

local function applySelfInvisible()
    local char = LocalPlayer.Character
    if not char then
        return
    end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if selfInvisSaved[part] == nil then
                selfInvisSaved[part] = part.LocalTransparencyModifier
            end
            part.LocalTransparencyModifier = 1
        end
    end
end

local function restoreSelfVisible()
    for part, original in pairs(selfInvisSaved) do
        if part.Parent then
            pcall(function()
                part.LocalTransparencyModifier = original
            end)
        end
    end
    selfInvisSaved = setmetatable({}, { __mode = "k" })
end

local function setSelfInvisible(on)
    state.selfInvisible = on
    if selfInvisConn then
        selfInvisConn:Disconnect()
        selfInvisConn = nil
    end
    if on then
        local lastScan = 0
        selfInvisConn = RunService.Heartbeat:Connect(function()
            local now = os.clock()
            if now - lastScan < 0.5 then
                return
            end
            lastScan = now
            applySelfInvisible()
        end)
        applySelfInvisible()
    else
        restoreSelfVisible()
    end
end

-- ===== 防挂机 =====

local antiAfkConn = nil

local function setAntiAfk(on)
    state.antiAfk = on
    if antiAfkConn then
        antiAfkConn:Disconnect()
        antiAfkConn = nil
    end
    if on then
        antiAfkConn = LocalPlayer.Idled:Connect(function()
            pcall(function()
                local virtualUser = game:GetService("VirtualUser")
                virtualUser:CaptureController()
                virtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end)
    end
end

-- ===== 传送 =====

local function getPlayerNames()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(list, player.Name)
        end
    end
    table.sort(list)
    return list
end

local function teleportToPlayer(name)
    local target = Players:FindFirstChild(name)
    if not target then
        notify("传送失败", "找不到玩家：" .. tostring(name))
        return
    end

    local targetChar = target.Character
    local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHrp then
        notify("传送失败", target.Name .. " 的角色还没加载好")
        return
    end

    local _, _, hrp = getCharacter()
    if not hrp then
        notify("传送失败", "你自己的角色还没加载好")
        return
    end

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 2, 3)
    notify("传送成功", "已传送到 " .. target.Name)
end

local function teleportToCoords(text)
    local xs, ys, zs = tostring(text or ""):match(
        "([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)"
    )
    local x, y, z = tonumber(xs), tonumber(ys), tonumber(zs)
    if not (x and y and z) then
        notify("坐标传送", "格式应为 x, y, z，例如 100, 20, 50")
        return
    end

    local _, _, hrp = getCharacter()
    if not hrp then
        notify("坐标传送", "角色还没加载好")
        return
    end

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(x, y, z)
    notify("坐标传送", string.format("已传送到 %.0f, %.0f, %.0f", x, y, z))
end

local function teleportToSpawn()
    local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
    if not spawn then
        notify("回出生点", "当前地图没有出生点")
        return
    end

    local _, _, hrp = getCharacter()
    if not hrp then
        notify("回出生点", "角色还没加载好")
        return
    end

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = spawn.CFrame * CFrame.new(0, 5, 0)
    notify("回出生点", "已回到出生点")
end

local function teleportToCrosshair()
    local cam = workspace.CurrentCamera
    local _, _, hrp = getCharacter()
    if not cam or not hrp then
        notify("准星传送", "角色或相机还没准备好")
        return
    end

    local center = cam.ViewportSize / 2
    local ray = cam:ViewportPointToRay(center.X, center.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }

    local hit = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
    local target = hit and (hit.Position + Vector3.new(0, 3, 0)) or (ray.Origin + ray.Direction * 300)

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(target)
    notify("准星传送", "已传送到准星位置")
end

local function savePosition()
    local _, _, hrp = getCharacter()
    if not hrp then
        notify("位置记录", "角色还没加载好")
        return
    end
    state.savedPos = hrp.CFrame
    notify(
        "位置记录",
        string.format("已记录 %.0f, %.0f, %.0f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
    )
end

local function returnToSavedPosition()
    if not state.savedPos then
        notify("位置记录", "还没有记录过位置")
        return
    end
    local _, _, hrp = getCharacter()
    if not hrp then
        notify("位置记录", "角色还没加载好")
        return
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = state.savedPos
    notify("位置记录", "已回到记录点")
end

local function teleportToRandomPlayer()
    local names = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                table.insert(names, player.Name)
            end
        end
    end
    if #names == 0 then
        notify("随机传送", "没有可传送的玩家")
        return
    end
    teleportToPlayer(names[math.random(1, #names)])
end

local function copyPosition()
    local _, _, hrp = getCharacter()
    if not hrp then
        notify("复制位置", "角色还没加载好")
        return
    end
    local text = string.format(
        "%.1f, %.1f, %.1f",
        hrp.Position.X,
        hrp.Position.Y,
        hrp.Position.Z
    )
    local ok = pcall(function()
        setclipboard(text)
    end)
    if ok then
        notify("复制位置", text)
    else
        notify("复制位置", "复制失败，执行器不支持 setclipboard")
    end
end

local function spectatePlayer(name)
    if not name or name == "" then
        notify("观战", "请先选择要观战的玩家")
        return
    end
    local target = Players:FindFirstChild(name)
    local char = target and target.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local cam = workspace.CurrentCamera
    if not (target and hum and cam) then
        notify("观战", "对方角色不可用")
        return
    end
    cam.CameraSubject = hum
    notify("观战", "正在观战 " .. target.Name)
end

local function resetCamera()
    local _, hum = getCharacter()
    local cam = workspace.CurrentCamera
    if hum and cam then
        cam.CameraSubject = hum
    end
end

local function serverHop()
    local ok, err = pcall(function()
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?limit=100",
            game.PlaceId
        )
        local body = game:HttpGet(url)
        local data = game:GetService("HttpService"):JSONDecode(body)
        local jobs = {}
        for _, server in ipairs(data.data or {}) do
            if server.id ~= game.JobId and (server.playing or 0) < (server.maxPlayers or 0) then
                table.insert(jobs, server.id)
            end
        end
        if #jobs == 0 then
            error("没有找到有空位的服务器")
        end
        TeleportService:TeleportToPlaceInstance(
            game.PlaceId,
            jobs[math.random(1, #jobs)],
            LocalPlayer
        )
    end)
    if not ok then
        notify("换服务器", tostring(err))
    end
end

-- ===== 音乐播放器 =====

local sound = Instance.new("Sound")
sound.Name = "YuHUB_Music"
sound.Volume = 1
sound.Looped = false
sound.Parent = SoundService

local function parseAssetId(text)
    local id = tostring(text or ""):match("%d+")
    return id
end

local function playMusic()
    local id = parseAssetId(state.musicId)
    if not id then
        notify("音乐", "请先输入数字音频 ID")
        return
    end
    sound:Stop()
    sound.SoundId = "rbxassetid://" .. id
    sound.Looped = state.loopMusic
    sound:Play()
    notify("音乐", "正在播放：" .. id)
end

-- ===== 界面 =====

local Window = WindUI:CreateWindow({
    Title = "Yu HUB",
    Icon = "sparkles",
    Author = "Yu HUB",
    Folder = "YuHUB",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Background = "rbxassetid://107212246112454",
    BackgroundImageTransparency = 0.15,
    Theme = "Dark",
    SideBarWidth = 200,
    HideSearchBar = true,
    OpenButton = {
        Title = "Yu HUB",
        Enabled = true,
        OnlyMobile = false,
        Draggable = true,
        CornerRadius = UDim.new(1, 0),
        Color = ColorSequence.new(
            Color3.fromHex("#E896AF"),
            Color3.fromHex("#F3B8CA")
        ),
    },
})

Window:Tag({
    Title = "v1.2",
    Icon = "sparkles",
    Color = Color3.fromHex("#E896AF"),
})

-- 收尾：重复执行/关闭时统一清理
local function cleanup()
    pcall(stopFly)
    pcall(setInfiniteJump, false)
    pcall(setNoclip, false)
    pcall(setFreeze, false)
    pcall(setFullbright, false)
    pcall(setPlayerEsp, false)
    pcall(setPlayerNameTags, false)
    pcall(setHidePlayers, false)
    pcall(setSelfInvisible, false)
    pcall(setAntiAfk, false)
    pcall(resetCamera)
    if state.gravityChanged then
        pcall(function()
            workspace.Gravity = defaultGravity
        end)
    end
    if state.clockChanged then
        pcall(function()
            Lighting.ClockTime = defaultClock
        end)
    end
    if state.zoomChanged then
        pcall(function()
            LocalPlayer.CameraMaxZoomDistance = defaultMaxZoom
        end)
    end
    if sound then
        pcall(function()
            sound:Stop()
            sound:Destroy()
        end)
        sound = nil
    end
    pcall(function()
        Window:Destroy()
    end)
end
getgenv().YuHUBCleanup = cleanup

-- ===== 移动 =====

local movementTab = Window:Tab({ Title = "移动", Icon = "move" })

local flySection = movementTab:Section({ Title = "飞行" })

flyToggle = flySection:Toggle({
    Title = "开启飞行",
    Desc = "Yu-Fly 架构：摇杆/WASD 平移，抬头低头升降；PC 空格上升、Ctrl 下降，重生自动关闭",
    Value = false,
    Callback = function(enabled)
        if enabled then
            if not startFly() then
                notify("飞行", "角色还没加载好，请稍后再试")
                pcall(function()
                    flyToggle:Set(false)
                end)
            end
        else
            stopFly()
        end
    end,
})

flySection:Slider({
    Title = "飞行速度",
    Desc = "开启飞行后实时生效",
    Step = 5,
    Value = {
        Min = 10,
        Max = 300,
        Default = 60,
    },
    Callback = function(value)
        state.flySpeed = value
    end,
})

local statsSection = movementTab:Section({ Title = "角色属性" })

statsSection:Slider({
    Title = "移动速度",
    Step = 1,
    Value = {
        Min = 16,
        Max = 500,
        Default = defaultWalk,
    },
    Callback = function(value)
        state.walkSpeed = value
        state.walkChanged = true
        local _, hum = getCharacter()
        if hum then
            hum.WalkSpeed = value
        end
    end,
})

statsSection:Slider({
    Title = "跳跃力度",
    Step = 5,
    Value = {
        Min = 50,
        Max = 500,
        Default = defaultJump,
    },
    Callback = function(value)
        state.jumpPower = value
        state.jumpChanged = true
        local _, hum = getCharacter()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = value
        end
    end,
})

local assistSection = movementTab:Section({ Title = "辅助移动" })

assistSection:Toggle({
    Title = "无限跳",
    Desc = "空中也能连续起跳",
    Value = false,
    Callback = setInfiniteJump,
})

assistSection:Toggle({
    Title = "穿墙",
    Desc = "关闭角色碰撞，可以直接穿过墙和地板",
    Value = false,
    Callback = setNoclip,
})

assistSection:Toggle({
    Title = "冻结角色",
    Desc = "把角色钉在原地，方便拍照或瞄准",
    Value = false,
    Callback = setFreeze,
})

local physicsSection = movementTab:Section({ Title = "物理" })

physicsSection:Slider({
    Title = "全局重力",
    Desc = "默认 " .. string.format("%.0f", defaultGravity) .. "，0 = 失重",
    Step = 5,
    Value = {
        Min = 0,
        Max = 300,
        Default = math.clamp(math.floor(defaultGravity + 0.5), 0, 300),
    },
    Callback = function(value)
        state.gravity = value
        state.gravityChanged = true
        workspace.Gravity = value
    end,
})

-- ===== 视觉 =====

local visualTab = Window:Tab({ Title = "视觉", Icon = "sun" })
local lightSection = visualTab:Section({ Title = "环境" })

lightSection:Toggle({
    Title = "全亮",
    Desc = "提高亮度、关闭阴影与雾",
    Value = false,
    Callback = setFullbright,
})

lightSection:Slider({
    Title = "时间",
    Desc = "0~24 点；全亮开启时会被设成 14 点",
    Step = 0.5,
    Value = {
        Min = 0,
        Max = 24,
        Default = math.clamp(defaultClock, 0, 24),
    },
    Callback = function(value)
        state.clockChanged = true
        Lighting.ClockTime = value
    end,
})

local cameraSection = visualTab:Section({ Title = "相机" })

cameraSection:Slider({
    Title = "视野 FOV",
    Step = 1,
    Value = {
        Min = 40,
        Max = 120,
        Default = defaultFov,
    },
    Callback = function(value)
        state.fov = value
        local cam = workspace.CurrentCamera
        if cam then
            cam.FieldOfView = value
        end
    end,
})

cameraSection:Slider({
    Title = "最远缩放",
    Desc = "第三人称可以拉多远",
    Step = 10,
    Value = {
        Min = 12,
        Max = 1000,
        Default = math.clamp(math.floor(defaultMaxZoom + 0.5), 12, 1000),
    },
    Callback = function(value)
        state.zoomChanged = true
        LocalPlayer.CameraMaxZoomDistance = math.max(value, LocalPlayer.CameraMinZoomDistance)
    end,
})

cameraSection:Button({
    Title = "第一人称",
    Icon = "camera",
    Callback = function()
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    end,
})

cameraSection:Button({
    Title = "第三人称",
    Icon = "camera",
    Callback = function()
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
    end,
})

local espSection = visualTab:Section({ Title = "玩家" })

espSection:Toggle({
    Title = "玩家高亮",
    Desc = "隔着墙显示其他玩家的粉色轮廓",
    Value = false,
    Callback = setPlayerEsp,
})

espSection:Toggle({
    Title = "玩家名字",
    Desc = "头顶显示名字、距离和血量",
    Value = false,
    Callback = setPlayerNameTags,
})

espSection:Slider({
    Title = "显示距离",
    Desc = "超出这个距离就隐藏高亮和名字",
    Step = 50,
    Value = {
        Min = 50,
        Max = 2000,
        Default = 500,
    },
    Callback = function(value)
        state.espRange = value
    end,
})

espSection:Toggle({
    Title = "隐藏其他玩家",
    Desc = "只在本机隐藏，降低画面负担",
    Value = false,
    Callback = setHidePlayers,
})

local selfSection = visualTab:Section({ Title = "自己" })

selfSection:Toggle({
    Title = "本地隐身",
    Desc = "仅自己视角看不见自己的角色",
    Value = false,
    Callback = setSelfInvisible,
})

-- ===== 传送 =====

local teleportTab = Window:Tab({ Title = "传送", Icon = "map-pin" })
local teleportSection = teleportTab:Section({ Title = "传送到玩家" })

local playerDropdown
playerDropdown = teleportSection:Dropdown({
    Title = "选择玩家",
    Desc = "选中后会直接传送到对方身后",
    Values = getPlayerNames(),
    AllowNone = true,
    Callback = function(name)
        if name and name ~= "" then
            teleportToPlayer(name)
        end
    end,
})

local function refreshPlayerDropdown()
    if playerDropdown then
        pcall(function()
            playerDropdown:Refresh(getPlayerNames())
        end)
    end
end

teleportSection:Button({
    Title = "刷新玩家列表",
    Icon = "refresh-cw",
    Callback = refreshPlayerDropdown,
})

teleportSection:Button({
    Title = "随机传送",
    Icon = "shuffle",
    Callback = teleportToRandomPlayer,
})

Players.PlayerAdded:Connect(refreshPlayerDropdown)
Players.PlayerRemoving:Connect(refreshPlayerDropdown)

local coordSection = teleportTab:Section({ Title = "坐标传送" })
local coordText = ""

coordSection:Input({
    Title = "坐标",
    Desc = "格式：x, y, z，输入后回车确认",
    Placeholder = "100, 20, 50",
    Value = "",
    Callback = function(text)
        coordText = text
    end,
})

coordSection:Button({
    Title = "传送到坐标",
    Icon = "crosshair",
    Callback = function()
        teleportToCoords(coordText)
    end,
})

coordSection:Button({
    Title = "传送到准星",
    Icon = "navigation",
    Callback = teleportToCrosshair,
})

coordSection:Button({
    Title = "回出生点",
    Icon = "home",
    Callback = teleportToSpawn,
})

local posSection = teleportTab:Section({ Title = "位置记录" })

posSection:Button({
    Title = "记录当前位置",
    Icon = "bookmark",
    Callback = savePosition,
})

posSection:Button({
    Title = "回到记录点",
    Icon = "history",
    Callback = returnToSavedPosition,
})

posSection:Button({
    Title = "复制当前位置",
    Icon = "copy",
    Callback = copyPosition,
})

local spectateSection = teleportTab:Section({ Title = "观战" })
local spectateName = nil

local spectateDropdown
spectateDropdown = spectateSection:Dropdown({
    Title = "选择目标",
    Values = getPlayerNames(),
    AllowNone = true,
    Callback = function(name)
        spectateName = name
    end,
})

spectateSection:Button({
    Title = "观战选中玩家",
    Icon = "eye",
    Callback = function()
        spectatePlayer(spectateName)
    end,
})

spectateSection:Button({
    Title = "恢复自己视角",
    Icon = "undo-2",
    Callback = resetCamera,
})

local function refreshSpectateDropdown()
    if spectateDropdown then
        pcall(function()
            spectateDropdown:Refresh(getPlayerNames())
        end)
    end
end

Players.PlayerAdded:Connect(refreshSpectateDropdown)
Players.PlayerRemoving:Connect(refreshSpectateDropdown)

-- ===== 音乐 =====

local musicTab = Window:Tab({ Title = "音乐", Icon = "music" })
local musicSection = musicTab:Section({ Title = "音乐播放器" })

musicSection:Input({
    Title = "音频 ID",
    Desc = "填 Roblox 音频数字 ID，回车确认",
    Placeholder = "例如 1837879082",
    Value = "",
    Callback = function(text)
        state.musicId = text
    end,
})

musicSection:Button({
    Title = "播放",
    Icon = "play",
    Callback = playMusic,
})

musicSection:Button({
    Title = "暂停",
    Icon = "pause",
    Callback = function()
        sound:Pause()
    end,
})

musicSection:Button({
    Title = "停止",
    Icon = "square",
    Callback = function()
        sound:Stop()
    end,
})

musicSection:Slider({
    Title = "音量",
    Step = 0.05,
    Value = {
        Min = 0,
        Max = 3,
        Default = 1,
    },
    Callback = function(value)
        sound.Volume = value
    end,
})

musicSection:Toggle({
    Title = "循环播放",
    Value = false,
    Callback = function(enabled)
        state.loopMusic = enabled
        sound.Looped = enabled
    end,
})

-- ===== 实用 =====

local utilTab = Window:Tab({ Title = "实用", Icon = "wrench" })

local afkSection = utilTab:Section({ Title = "挂机" })

afkSection:Toggle({
    Title = "防挂机",
    Desc = "空闲时模拟输入，避免被服务器踢出",
    Value = false,
    Callback = setAntiAfk,
})

local serverSection = utilTab:Section({ Title = "服务器" })

serverSection:Button({
    Title = "重进服务器",
    Desc = "断开并重新进入当前服务器",
    Icon = "refresh-cw",
    Callback = function()
        local ok, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
        if not ok then
            notify("重进服务器", tostring(err))
        end
    end,
})

serverSection:Button({
    Title = "复制服务器 ID",
    Icon = "copy",
    Callback = function()
        local ok = pcall(function()
            setclipboard(tostring(game.JobId))
        end)
        if ok then
            notify("服务器", "已复制当前服务器 ID")
        else
            notify("服务器", "复制失败，执行器不支持 setclipboard")
        end
    end,
})

serverSection:Button({
    Title = "换服务器",
    Desc = "随机加入一个有位置的服务器",
    Icon = "shuffle",
    Callback = serverHop,
})

local perfSection = utilTab:Section({ Title = "性能" })

perfSection:Dropdown({
    Title = "帧率上限",
    Desc = "依赖执行器的 setfpscap",
    Values = { "30", "60", "90", "120", "144", "无限制" },
    AllowNone = true,
    Callback = function(choice)
        if not choice then
            return
        end
        if type(setfpscap) ~= "function" then
            notify("帧率上限", "执行器不支持 setfpscap")
            return
        end
        local cap = choice == "无限制" and 999 or tonumber(choice)
        local ok, err = pcall(setfpscap, cap)
        if ok then
            notify(
                "帧率上限",
                choice == "无限制" and "已取消帧率限制" or ("已设为 " .. choice .. " FPS")
            )
        else
            notify("帧率上限", tostring(err))
        end
    end,
})

local themeSection = utilTab:Section({ Title = "主题" })

themeSection:Button({
    Title = "白色主题",
    Icon = "sun",
    Callback = function()
        WindUI:SetTheme("Light")
        notify("主题", "已切换为白色主题")
    end,
})

themeSection:Button({
    Title = "黑色主题",
    Icon = "moon",
    Callback = function()
        WindUI:SetTheme("Dark")
        notify("主题", "已切换为黑色主题")
    end,
})

local charSection = utilTab:Section({ Title = "角色" })

charSection:Button({
    Title = "重置角色",
    Icon = "rotate-ccw",
    Callback = function()
        local _, hum = getCharacter()
        if hum then
            hum.Health = 0
        else
            notify("重置角色", "角色还没加载好")
        end
    end,
})

local closeSection = utilTab:Section({ Title = "脚本" })

closeSection:Button({
    Title = "关闭 Yu HUB",
    Desc = "停止所有功能并关闭界面",
    Icon = "power",
    Color = Color3.fromHex("#EF4F1D"),
    Callback = function()
        cleanup()
        getgenv().YuHUBCleanup = nil
    end,
})

-- ===== 角色刷新后重新应用 =====

LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 10)
    local hrp = char:WaitForChild("HumanoidRootPart", 10)
    if hum then
        if state.walkChanged then
            hum.WalkSpeed = state.walkSpeed
        end
        if state.jumpChanged then
            hum.UseJumpPower = true
            hum.JumpPower = state.jumpPower
        end
    end
    if state.freeze and hrp then
        hrp.Anchored = true
    end
    if state.fly then
        autoStopFly("角色已重生，飞行已关闭")
    end
end)
