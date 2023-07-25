local StreamRadioLib = StreamRadioLib

StreamRadioLib.Util = StreamRadioLib.Util or {}
local LIB = StreamRadioLib.Util

local LIBNetURL = StreamRadioLib.NetURL

function LIB.IsDebug()
	local devconvar = GetConVar("developer")
	if not devconvar then return end

	return devconvar:GetInt() > 0
end

function LIB.GameIsPaused()
	local frametime = FrameTime()

	if frametime > 0 then
		return false
	end

	return true
end

function LIB.ErrorNoHaltWithStack(err)
	err = tostring(err or "")
	ErrorNoHaltWithStack(err)
end

local catchAndNohalt = function(err)
	local msgstring = tostring(err or "")
	msgstring = string.Trim(StreamRadioLib.AddonPrefix .. msgstring) .. "\n"

	LIB.ErrorNoHaltWithStack(err)

	return err
end

function LIB.CatchAndErrorNoHaltWithStack(func, ...)
	return xpcall(func, catchAndNohalt, ...)
end

function LIB.Hash(str)
	str = tostring(str or "")

	local salt = "StreamRadioLib_Hash20230723"

	local data = string.format(
		"[%s][%s]",
		salt,
		str
	)

	local hash = util.SHA256(data)
	return hash
end

local g_uid = 0
function LIB.Uid()
	g_uid = (g_uid + 1) % (2 ^ 30)
	return g_uid
end

function LIB.NormalizeNewlines(text, nl)
	nl = tostring(nl or "")
	text = tostring(text or "")

	local replacemap = {
		["\r\n"] = true,
		["\r"] = true,
		["\n"] = true,
	}

	if not replacemap[nl] then
		nl = "\n"
	end

	replacemap[nl] = nil

	for k, v in pairs(replacemap) do
		replacemap[k] = nl
	end

	text = string.gsub(text, "([\r]?[\n]?)", replacemap)

	return text
end

local g_createCacheArrayMeta = {
	Set = function(self, cacheid, data)
		if cacheid == nil then
			return
		end

		if data == nil then
			self:Remove(cacheid)
			return
		end

		local hadCache = false
		local cache = self.cache

		if cache[cacheid] then
			hadCache = true
		end

		if self.limit > 0 and self.count > self.limit then
			self:Empty()
		end

		cache[cacheid] = data

		if not hadCache then
			self.count = self.count + 1
		end
	end,

	Get = function(self, cacheid)
		if cacheid == nil then
			return nil
		end

		return self.cache[cacheid]
	end,

	Remove = function(self, cacheid)
		if cacheid == nil then
			return
		end

		local cache = self.cache

		if cache[cacheid] == nil then
			return
		end

		cache[cacheid] = nil
		self.count = math.max(self.count - 1, 0)
	end,

	Has = function(self, cacheid)
		if cacheid == nil then
			return false
		end

		return self.cache[cacheid] ~= nil
	end,

	Empty = function(self)
		LIB.EmptyTableSafe(self.cache)
		self.count = 0
	end,

	Count = function(self)
		return self.count
	end,
}

g_createCacheArrayMeta.__index = g_createCacheArrayMeta

function LIB.CreateCacheArray(limit)
	local cache = {}

	cache.cache = {}
	cache.limit = math.max(limit or 0, 0)
	cache.count = 0

	setmetatable(cache, g_createCacheArrayMeta)

	return cache
end

function LIB.IsBlockedURLCode( url )
	if ( not StreamRadioLib.BlockedURLCode ) then return false end
	if ( StreamRadioLib.BlockedURLCode == "" ) then return false end

	url = url or ""
	local blocked = StreamRadioLib.BlockedURLCode

	return url == blocked
end

function LIB.IsBlockedCustomURL(url)
	url = url or ""

	if url == "" then
		return false
	end

	if LIB.IsBlockedURLCode(url) then
		return true
	end

	if LIB.IsOfflineURL(url) then
		return false
	end

	if not StreamRadioLib.IsCustomURLsAllowed() then
		return true
	end

	return false
end

function LIB.FilterCustomURL(url)
	if LIB.IsBlockedCustomURL(url) then
		return StreamRadioLib.BlockedURLCode
	end

	return url
end

local function NormalizeOfflineFilename( path )
	path = path or ""
	path = string.Replace( path, "\r", "" )
	path = string.Replace( path, "\n", "" )
	path = string.Replace( path, "\t", "" )
	path = string.Replace( path, "\b", "" )

	path = string.Replace( path, "\\", "/" )
	path = string.Replace( path, "../", "" )
	path = string.Replace( path, "//", "/" )

	path = string.sub(path, 0, 260)
	return path
end

function LIB.URIAddParameter(url, parameter)
	if not istable(parameter) then
		parameter = {parameter}
	end

	url = tostring(url or "")
	url = LIBNetURL.normalize(url)

	for k, v in pairs(parameter) do
		url.query[k] = v
	end

	url = tostring(url)
	return url
end

function LIB.NormalizeURL(url)
	url = tostring(url or "")
	url = LIBNetURL.normalize(url)
	url = tostring(url)

	return url
end

function LIB.IsOfflineURL( url )
	url = string.Trim( url or "" )
	local protocol = string.Trim( string.match( url, ( "([ -~]+):[//\\][//\\]" ) ) or "" )

	if ( protocol == "" ) then
		return true
	end

	if ( protocol == "file" ) then
		return true
	end

	return false
end

function LIB.ConvertURL( url )
	url = string.Trim(tostring(url or ""))

	if LIB.IsOfflineURL( url ) then
		local fileurl = string.Trim( string.match( url, ( ":[//\\][//\\]([ -~]+)" ) ) or "" )

		if ( fileurl ~= "" ) then
			url = fileurl
		end

		url = "sound/" .. url
		url = NormalizeOfflineFilename(url)
		return url, StreamRadioLib.STREAM_URLTYPE_FILE
	end

	local URLType = StreamRadioLib.STREAM_URLTYPE_ONLINE

	local Cachefile = StreamRadioLib.Cache.GetFile( url )
	if ( Cachefile ) then
		url = "data/" .. Cachefile
		url = NormalizeOfflineFilename(url)
		URLType = StreamRadioLib.STREAM_URLTYPE_CACHE
	end

	return url, URLType
end

function LIB.EmptyTableSafe(tab)
	if not tab then
		return
	end

	table.Empty(tab)
end

function LIB.DeleteFolder(path)
	if not StreamRadioLib.DataDirectory then
		return false
	end

	if StreamRadioLib.DataDirectory == "" then
		return false
	end

	if path == "" then
		return false
	end

	if not string.StartWith(path, StreamRadioLib.DataDirectory) then
		return false
	end

	local files, folders = file.Find(path .. "/*", "DATA")

	for k, v in pairs(folders or {}) do
		LIB.DeleteFolder(path .. "/" .. v)
	end

	for k, v in pairs(files or {}) do
		file.Delete(path .. "/" .. v)
	end

	file.Delete(path)

	if file.Exists(path, "DATA") then
		return false
	end

	if file.IsDir(path, "DATA") then
		return false
	end

	return true
end

local g_cache_IsValidModel = {}
local g_cache_IsValidModelFile = {}

function LIB.GetDefaultModel()
	local defaultModel = Model("models/sligwolf/grocel/radio/radio.mdl")
	return defaultModel
end

function LIB.IsValidModel(model)
	model = tostring(model or "")

	if g_cache_IsValidModel[model] then
		return true
	end

	g_cache_IsValidModel[model] = nil

	if not LIB.IsValidModelFile(model) then
		return false
	end

	util.PrecacheModel(model)

	if not util.IsValidModel(model) then
		return false
	end

	if not util.IsValidProp(model) then
		return false
	end

	g_cache_IsValidModel[model] = true
	return true
end

function LIB.IsValidModelFile(model)
	model = tostring(model or "")

	if g_cache_IsValidModelFile[model] then
		return true
	end

	g_cache_IsValidModelFile[model] = nil

	if model == "" then
		return false
	end

	if IsUselessModel(model) then
		return false
	end

	if not file.Exists(model, "GAME") then
		return false
	end

	g_cache_IsValidModelFile[model] = true
	return true
end

function LIB.FrameNumber()
	local frame = nil

	if CLIENT then
		frame = FrameNumber()
	else
		frame = engine.TickCount()
	end

	return frame
end

function LIB.RealFrameTime()
	local frameTime = nil

	if CLIENT then
		frameTime = RealFrameTime()
	else
		frameTime = FrameTime()
	end

	return frameTime
end

function LIB.RealTimeFps()
	local fps = LIB.RealFrameTime()

	if fps <= 0 then
		return 0
	end

	fps = 1 / fps

	return fps
end

local g_LastFrameRegister = {}
local g_LastFrameRegisterCount = 0

function LIB.IsSameFrame(id)
	local id = tostring(id or "")
	local lastFrame = g_LastFrameRegister[id]

	local frame = LIB.FrameNumber()

	if not lastFrame or frame ~= lastFrame then

		-- prevent the cache from overflowing
		if g_LastFrameRegisterCount > 1024 then
			LIB.EmptyTableSafe(g_LastFrameRegister)
			g_LastFrameRegisterCount = 0
		end

		g_LastFrameRegister[id] = frame

		if not lastFrame then
			g_LastFrameRegisterCount = g_LastFrameRegisterCount + 1
		end

		return false
	end

	return true
end