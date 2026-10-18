--[[
    Yu Perf · 右下角 FPS
    固定在屏幕右下角，只显示帧率；不依赖 mspaint / WindUI
    重复执行会先清掉旧实例
--]]

if getgenv().YuPerfStop then
    pcall(getgenv().YuPerfStop)
    getgenv().YuPerfStop = nil
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local COL = {
    TEXT = Color3.fromRGB(255, 255, 255),
    MUTED = Color3.fromRGB(142, 142, 147),
    WARN = Color3.fromRGB(255, 183, 77),
    BAD = Color3.fromRGB(255, 90, 80),
}

-- 清掉上一次执行残留的同名 ScreenGui
for _, child in ipairs(PlayerGui:GetChildren()) do
    if child.Name == "YuPerf" then
        child:Destroy()
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "YuPerf"
gui.ResetOnSpawn = false
gui.DisplayOrder = 9999
gui.Parent = PlayerGui

local panel = Instance.new("Frame")
panel.Name = "Pill"
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -12, 1, -4)
panel.Size = UDim2.fromOffset(0, 14)
panel.AutomaticSize = Enum.AutomaticSize.X
panel.BackgroundTransparency = 1
panel.Parent = gui

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.HorizontalAlignment = Enum.HorizontalAlignment.Left
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local fpsLabel = Instance.new("TextLabel")
fpsLabel.LayoutOrder = 1
fpsLabel.Size = UDim2.fromOffset(28, 14)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Font = Enum.Font.GothamMedium
fpsLabel.TextSize = 13
fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
fpsLabel.TextColor3 = COL.TEXT
fpsLabel.Text = "--"
fpsLabel.Parent = panel

local unitLabel = Instance.new("TextLabel")
unitLabel.LayoutOrder = 2
unitLabel.AutomaticSize = Enum.AutomaticSize.X
unitLabel.Size = UDim2.fromOffset(0, 14)
unitLabel.BackgroundTransparency = 1
unitLabel.Font = Enum.Font.GothamMedium
unitLabel.TextSize = 9
unitLabel.TextColor3 = COL.MUTED
unitLabel.Text = "FPS"
unitLabel.Parent = panel

-- ===== 数据 =====

local conns = {}
local running = true
local frames = 0
local lastT = os.clock()
local fpsVal = 0

local function tint(color)
    if fpsLabel.TextColor3 == color then
        return
    end
    TweenService:Create(
        fpsLabel,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { TextColor3 = color }
    ):Play()
end

local function update()
    fpsLabel.Text = fpsVal > 0 and tostring(fpsVal) or "--"
    if fpsVal <= 0 then
        tint(COL.MUTED)
    elseif fpsVal < 20 then
        tint(COL.BAD)
    elseif fpsVal < 60 then
        tint(COL.WARN)
    else
        tint(COL.TEXT)
    end
end

conns[#conns + 1] = RunService.RenderStepped:Connect(function()
    frames = frames + 1
end)

update()

task.spawn(function()
    while running do
        local now = os.clock()
        local dt = now - lastT
        if dt >= 0.5 then
            fpsVal = math.floor(frames / dt + 0.5)
            frames = 0
            lastT = now
            if panel and panel.Parent then
                update()
            end
        end
        task.wait(0.25)
    end
end)

-- ===== 清理 =====

local function stop()
    running = false
    for _, c in ipairs(conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    conns = {}
    if gui then
        pcall(function()
            gui:Destroy()
        end)
        gui = nil
    end
    panel = nil
end

getgenv().YuPerfStop = stop
