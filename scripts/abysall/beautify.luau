--==============================================================
-- Abysall 界面美化（从 mspaint appearance.lua 搬来）
-- 三块：窗口圆角 / 界面背景 / 自定义字体，各自 pcall 隔离。
-- 配置：abysall/bg.txt（贴图 id / 网址 / #颜色，空=内置图）
--       abysall/font.txt（on=1 file=anime1.ttf）
-- 日志：abysall/beautify-log.txt
--==============================================================

local LOG = "abysall/beautify-log.txt"
local function log(msg)
	pcall(function()
		local old = ""
		local ok, d = pcall(readfile, LOG)
		if ok and type(d) == "string" then old = d end
		if #old > 4000 then old = old:sub(-3000) end
		writefile(LOG, old .. string.format("[%s] %s\n", os.date("%H:%M:%S"), tostring(msg)))
	end)
end

local function getLib()
	local A = getgenv().Abysall
	local L = A and A.Interface and A.Interface.Library
	if type(L) ~= "table" then pcall(function() L = getgenv().Library end) end
	return type(L) == "table" and L or nil
end

local function getMain(L)
	local main = nil
	pcall(function() main = L.Window and L.Window.MainFrame end)
	if not main then pcall(function() main = L.ScreenGui:FindFirstChild("Main") end) end
	return main
end

local function readFile(p)
	local ok, d = pcall(readfile, p)
	if ok and type(d) == "string" then return d end
	return nil
end

local function writeFile(p, d)
	pcall(writefile, p, d)
end

local function trim(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function notify(title, text, time)
	pcall(function()
		local L = getLib()
		if L and type(L.Notify) == "function" then
			L:Notify({ Title = title, Description = tostring(text), Time = time or 4 })
		end
	end)
end

-- 等库和窗口就绪（Main 是异步跑完的，最多等 30 秒）
local L = nil
for _ = 1, 300 do
	L = getLib()
	if L and getMain(L) then break end
	task.wait(0.1)
end
if not L then log("拿不到 Library，放弃"); return end
if not getMain(L) then log("等不到窗口 MainFrame，放弃"); return end

-- 上一次的 Stop 先收掉，避免重载叠加
pcall(function()
	if type(getgenv().AbysBeautifyStop) == "function" then getgenv().AbysBeautifyStop() end
end)

local conns = {}
local function keep(c)
	conns[#conns + 1] = c
	return c
end

-- 自己人的装饰件不参与调透/圆角
local function isOurs(inst)
	local n, i = inst, 0
	while n ~= nil and i < 4 do
		local nm = n.Name
		if nm ~= nil and (string.sub(nm, 1, 5) == "abys_" or string.sub(nm, 1, 8) == "mspaint_") then
			return true
		end
		n = n.Parent
		i = i + 1
	end
	return false
end

--==============================================================
-- ① 窗口圆角
--==============================================================
pcall(function()
	local NEW = 8
	local main = getMain(L)
	L.CornerRadius = NEW
	for _, ch in ipairs(main:GetChildren()) do
		if ch:IsA("UICorner") then
			pcall(function() ch.CornerRadius = UDim.new(0, NEW) end)
		end
	end
	log("圆角 → " .. NEW)
end)

--==============================================================
-- ② 界面背景
--==============================================================
local BG_CFG = "abysall/bg.txt"
local BUILTIN_IMAGE = "134617274502848"
local BG_TRANSPARENCY = 0.1
local BG_BLOCKER_TRANSPARENCY = 0.9
local BG_BLOCKER_MIN_AREA = 0.01

local function parseColor(raw)
	local s = trim(raw):lower()
	local hex = s:match("^#(%x%x?%x?%x?%x?%x)$")
	if hex then
		if #hex == 3 then
			hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
		end
		return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
	end
	local r, g, b = s:match("^rgb%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)$")
	if r then
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		if r and g and b and r <= 255 and g <= 255 and b <= 255 then
			return Color3.fromRGB(r, g, b)
		end
	end
	return nil
end

local faded = {}
local function fadeBlockers(main, on)
	if not on then
		for inst, old in pairs(faded) do
			pcall(function() inst.BackgroundTransparency = old end)
		end
		faded = {}
		return 0
	end
	local n = 0
	local mw = math.max(main.AbsoluteSize.X, 1)
	local mh = math.max(main.AbsoluteSize.Y, 1)
	for _, ch in ipairs(main:GetDescendants()) do
		if ch:IsA("GuiObject") and not isOurs(ch) then
			local ok, bt = pcall(function() return ch.BackgroundTransparency end)
			if ok and type(bt) == "number" and bt < 0.5 then
				local sz = ch.Size
				local xs = sz.X.Scale + sz.X.Offset / mw
				local ys = sz.Y.Scale + sz.Y.Offset / mh
				if xs * ys >= BG_BLOCKER_MIN_AREA then
					faded[ch] = bt
					pcall(function() ch.BackgroundTransparency = BG_BLOCKER_TRANSPARENCY end)
					n = n + 1
				end
			end
		end
	end
	return n
end

local function windowCorner(main)
	local r = 8
	pcall(function()
		for _, ch in ipairs(main:GetChildren()) do
			if ch:IsA("UICorner") then
				r = ch.CornerRadius.Offset
				break
			end
		end
	end)
	return r
end

local function clearBg()
	pcall(function() L:SetBackgroundImage("") end)
	pcall(function()
		local main = getMain(L)
		local img = main and main:FindFirstChild("abys_bg")
		if img then img:Destroy() end
	end)
	pcall(function() fadeBlockers(getMain(L), false) end)
	pcall(function()
		L.Scheme.BackgroundColor = Color3.fromRGB(15, 15, 15)
		L:UpdateColorsUsingRegistry()
	end)
end

local function placeInWindow(image)
	local main = getMain(L)
	if not main then return nil, "找不到窗口 MainFrame" end
	local img = nil
	pcall(function() img = main:FindFirstChild("abys_bg") end)
	if not img then
		img = Instance.new("ImageLabel")
		img.Name = "abys_bg"
		img.BackgroundTransparency = 1
		img.Position = UDim2.fromOffset(0, 0)
		img.Size = UDim2.fromScale(1, 1)
		img.ZIndex = -1
		img.Parent = main
	end
	pcall(function()
		local c = img:FindFirstChildWhichIsA("UICorner")
		if not c then
			c = Instance.new("UICorner")
			c.Parent = img
		end
		c.CornerRadius = UDim.new(0, windowCorner(main))
	end)
	img.Image = image or ""
	img.ScaleType = Enum.ScaleType.Stretch
	img.ImageTransparency = BG_TRANSPARENCY
	local n = fadeBlockers(main, true)
	log(string.format("背景放入窗口，调透 %d 块", n))
	return img
end

-- 从库里那张顶层背景图抠出已解析好的 Image 地址
local function findLibOverlay()
	local hit = nil
	pcall(function()
		local gui = L.ScreenGui
		if not gui then return end
		for _, ch in ipairs(gui:GetChildren()) do
			if ch:IsA("ImageLabel") and ch.Name ~= "abys_bg" and tostring(ch.Image) ~= "" then
				hit = ch
				break
			end
		end
	end)
	return hit
end

local function applyBg(raw, save)
	local value = trim(raw)
	if value == "" or value:lower() == "clear" or value:lower() == "off" then
		clearBg()
		if save ~= false then writeFile(BG_CFG, "") end
		notify("界面背景", "已复原默认", 3)
		log("背景 clear")
		return true
	end

	local color = parseColor(value)
	if color then
		pcall(function() L:SetBackgroundImage("") end)
		pcall(function()
			local main = getMain(L)
			local img = main and main:FindFirstChild("abys_bg")
			if img then img:Destroy() end
		end)
		fadeBlockers(getMain(L), false)
		pcall(function()
			L.Scheme.BackgroundColor = color
			L:UpdateColorsUsingRegistry()
		end)
		if save ~= false then writeFile(BG_CFG, value) end
		notify("界面背景", "底色已换成 " .. value, 3)
		log("背景颜色 " .. value)
		return true
	end

	local id = value:match("^(%d+)$") or value:match("^[Rr][Bb][Xx][Aa][Ss][Ss][Ee][Tt][Ii][Dd]://(%d+)$")
	if id then
		placeInWindow("rbxassetid://" .. id)
		if save ~= false then writeFile(BG_CFG, value) end
		notify("界面背景", "背景图已换成贴图 " .. id, 3)
		log("背景贴图 " .. id)
		return true
	end

	if value:match("^https?://") then
		pcall(function() L:SetBackgroundImage(value) end)
		task.wait(1)
		local lib = findLibOverlay()
		local src = lib and tostring(lib.Image) or ""
		if src == "" then
			notify("界面背景", "网图没下载成功，换个图床试试", 5)
			log("网图失败 " .. value)
			return false
		end
		pcall(function() L:SetBackgroundImage("") end)
		placeInWindow(src)
		if save ~= false then writeFile(BG_CFG, value) end
		notify("界面背景", "背景图已换成网图", 4)
		log("背景网图 " .. value)
		return true
	end

	notify("界面背景", "认不出这个值：贴图 id / 网址 / #颜色 / clear", 5)
	log("背景未知值 " .. value)
	return false
end

pcall(function()
	local boot = trim(readFile(BG_CFG) or "")
	if boot == "" then boot = BUILTIN_IMAGE end
	pcall(function() applyBg(boot, false) end)
	task.delay(3, function()
		pcall(function() applyBg(boot, false) end)
	end)
end)

--==============================================================
-- ③ 自定义字体
--==============================================================
local FONT_CFG = "abysall/font.txt"
local FONT_DIR = "Obsidian/custom_assets"
local DEFAULT_FONT = "anime1.ttf"

local function readFontCfg()
	local out = { on = true, file = DEFAULT_FONT }
	pcall(function()
		if type(isfile) ~= "function" or not isfile(FONT_CFG) then return end
		local txt = readfile(FONT_CFG)
		if type(txt) ~= "string" then return end
		for k, v in string.gmatch(txt, "([%w_]+)=([^\r\n]*)") do
			if k == "on" then
				out.on = (tonumber(v) == 1)
			elseif k == "file" and v ~= "" then
				out.file = v
			end
		end
	end)
	return out
end

local function writeFontCfg(c)
	pcall(function()
		writefile(FONT_CFG, string.format("on=%d\nfile=%s", c.on and 1 or 0, c.file))
	end)
end

local function buildFont(file)
	if type(file) ~= "string" or file == "" then return nil, "文件名为空" end
	if type(getcustomasset) ~= "function" or type(writefile) ~= "function"
		or type(isfile) ~= "function" or type(Font) ~= "table" or type(Font.new) ~= "function" then
		return nil, "执行器缺函数"
	end
	local ttfRel = FONT_DIR .. "/" .. file
	if not isfile(ttfRel) then return nil, "找不到 " .. ttfRel end
	local okT, ttfUri = pcall(getcustomasset, ttfRel)
	if not okT or type(ttfUri) ~= "string" then return nil, "getcustomasset(ttf) 失败" end

	local base = tostring(file):gsub("%.[%w]+$", "")
	local jsonRel = FONT_DIR .. "/abysall_font_" .. (tostring(base):gsub("[^%w_%-%.]", "_")) .. ".json"
	local body = string.format(
		'{"name":"AbysallCustom","faces":[{"name":"Regular","weight":400,"style":"normal","assetId":"%s"}]}',
		ttfUri
	)
	if not pcall(writefile, jsonRel, body) then return nil, "写家族 JSON 失败" end
	local okJ, jsonUri = pcall(getcustomasset, jsonRel)
	if not okJ or type(jsonUri) ~= "string" then return nil, "getcustomasset(json) 失败" end
	local okF, font = pcall(Font.new, jsonUri)
	if not okF or font == nil then return nil, "Font.new 失败" end
	return font
end

local fontCfg = readFontCfg()

local function applyFont(file, save)
	if type(L.SetFont) ~= "function" then return false, "这版库没有 SetFont" end
	local font, err = buildFont(file)
	if not font then return false, err end
	local g = getgenv()
	if g.__abysOrigFont == nil then
		pcall(function() g.__abysOrigFont = L.Scheme and L.Scheme.Font end)
	end
	local ok, e = pcall(function() L:SetFont(font) end)
	if not ok then return false, tostring(e) end
	if save then
		fontCfg.file = file
		writeFontCfg(fontCfg)
	end
	log("字体换成 " .. tostring(file))
	return true
end

local function revertFont()
	local g = getgenv()
	if type(L.SetFont) == "function" and g.__abysOrigFont ~= nil then
		pcall(function() L:SetFont(g.__abysOrigFont) end)
		log("字体还原")
	end
end

local function setFontOn(on)
	fontCfg.on = on and true or false
	writeFontCfg(fontCfg)
	if fontCfg.on then applyFont(fontCfg.file, false) else revertFont() end
end

-- 窗口完全起来后再换字体
if fontCfg.on then
	task.delay(3, function()
		pcall(function() applyFont(fontCfg.file, false) end)
	end)
end

--==============================================================
-- ④ UI 控件（Appearance 标签）
--==============================================================
local bgInput, fontInput = nil, nil
pcall(function()
	local tab = L.Window:AddTab("美化", "palette")
	local left = tab:AddLeftGroupbox("背景")
	local right = tab:AddRightGroupbox("字体")

	local shown = trim(readFile(BG_CFG) or "")
	if shown == "" then shown = BUILTIN_IMAGE end

	left:AddInput("AbysBgValue", {
		Text = "背景值（贴图 id / 网址 / #颜色）",
		Placeholder = BUILTIN_IMAGE .. " 或 https://… 或 #101018",
		Default = shown,
		Finished = true,
		Callback = function(v) applyBg(v, true) end,
	})
	bgInput = L.Options and L.Options.AbysBgValue

	left:AddButton({
		Text = "应用背景",
		Func = function()
			local text = bgInput and bgInput.Value
			pcall(function()
				local box = bgInput and bgInput.Holder and bgInput.Holder:FindFirstChildWhichIsA("TextBox", true)
				if box and box.Text ~= "" then text = box.Text end
			end)
			applyBg(text, true)
		end,
	})
	left:AddButton({
		Text = "复原默认背景",
		Func = function() applyBg("clear", true) end,
	})

	right:AddToggle("AbysFontOn", {
		Text = "启用自定义字体",
		Tooltip = "吃 " .. FONT_DIR .. " 里的 ttf 文件",
		Default = fontCfg.on,
		Func = function(v) setFontOn(v) end,
	})
	right:AddInput("AbysFontFile", {
		Text = "字体文件名",
		Placeholder = DEFAULT_FONT,
		Default = fontCfg.file,
		Finished = true,
		Callback = function(v) applyFont(v, true) end,
	})
	fontInput = L.Options and L.Options.AbysFontFile
	right:AddButton({
		Text = "应用字体",
		Func = function()
			local text = fontInput and fontInput.Value
			pcall(function()
				local box = fontInput and fontInput.Holder and fontInput.Holder:FindFirstChildWhichIsA("TextBox", true)
				if box and box.Text ~= "" then text = box.Text end
			end)
			applyFont(text, true)
		end,
	})
	log("Appearance 标签已添加")
end)

getgenv().AbysBeautifyStop = function()
	pcall(function() revertFont() end)
	pcall(function() clearBg() end)
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	getgenv().AbysBeautifyStop = nil
end
