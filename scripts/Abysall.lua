--[[
    Abysall 云端版加载器
    模块文件放在本仓库 scripts/abysall/ 下，首次运行自动下载并缓存到本地
    readfile("abysall/xxx") 会先读本地，没有就从仓库拉
    剩余零散联网走 gh-proxy
--]]

local RepoRaw = "https://raw.githubusercontent.com/YuMaxCat/Rb-Script/main/scripts/"
local M = "https://gh-proxy.com/"

local function m(u)
	if type(u) ~= "string" then return u end
	local r = u:match("^https?://raw%.githubusercontent%.com/(.+)$")
	if r then return M .. "https://raw.githubusercontent.com/" .. r end
	return u
end

local oldGet = game.HttpGet
pcall(function()
	game.HttpGet = function(self, u, ...)
		return oldGet(self, m(u), ...)
	end
end)

local oldReq = rawget(getfenv(), "request")
if type(oldReq) == "function" then
	request = function(opts)
		if type(opts) == "table" then opts.Url = m(opts.Url) end
		return oldReq(opts)
	end
end

-- 模块读取：本地优先，缺失时从仓库下载并写入本地缓存
local Cache = {}
local oldRead = readfile

readfile = function(path)
	local rel = type(path) == "string" and path:match("^abysall/(.+)$")
	if not rel then
		return oldRead(path)
	end
	if Cache[rel] then return Cache[rel] end

	local ok, data = pcall(oldRead, path)
	if ok and type(data) == "string" then
		Cache[rel] = data
		return data
	end

	local ok2, data2 = pcall(function()
		return game:HttpGet(RepoRaw .. "abysall/" .. rel)
	end)
	if not ok2 or type(data2) ~= "string" or data2 == "" then
		error("Abysall: 无法读取模块 " .. rel, 2)
	end

	Cache[rel] = data2
	pcall(writefile, path, data2)
	return data2
end

-- 主脚本会阻塞到游戏 MainUI 出现，放独立线程
task.spawn(function()
	loadstring(readfile("abysall/DOORS.luau"))()
end)

-- 默认主题 Nya~!（主题系统没读到默认文件时兜底应用一次）
task.delay(10, function()
	local A = getgenv().Abysall
	local TM = A and A.Interface and A.Interface.ThemeManager
	if TM and type(TM.ApplyTheme) == "function" then
		pcall(function() TM:ApplyTheme("Nya~!") end)
	end
end)
