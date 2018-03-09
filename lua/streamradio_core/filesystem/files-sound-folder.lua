local RADIOFS = RADIOFS
if not istable( RADIOFS ) then
	StreamRadioLib.Filesystem.Load()
	return
end

RADIOFS.name = "Sound File"
RADIOFS.type = "soundfile"
RADIOFS.icon = StreamRadioLib.GetPNGIcon("sound")

RADIOFS.rootfolder = "sound"

RADIOFS.priority = 99999
RADIOFS.nocreate = true

RADIOFS._validsoundtypes = {
	["mp3"] = true,
	["wav"] = true,
	["ogg"] = true,

	["aac"] = true,
	["aifc"] = true,
	["aiff"] = true,
	["it"] = true,
	["m4a"] = true,
	["mod"] = true,
	["wma"] = true,
	["xm"] = true,
}

function RADIOFS:GetSoundPath(vpath)
	if not self:IsInFolder(vpath) then
		return nil
	end

	local levels = self:GetPathLevels(vpath)
	local path = table.concat(levels, "/", 2)

	return path
end

function RADIOFS:IsInFolder(vfolder)
	local levels = self:GetPathLevels(vfolder)
	local firstlevel = levels[1] or ""

	if firstlevel ~= ":gamesounds" then
		return false
	end

	return true
end

function RADIOFS:IsFileInFolder(vpath)
	vpath = string.GetPathFromFilename(vpath)
	return self:IsInFolder(vpath)
end

function RADIOFS:IsType(globalpath, vpath)
	return self:IsFileInFolder(vpath)
end


function RADIOFS:GetFiles(findpath)
	local validfiles = {}

	local files = file.Find(findpath .. "/*", "GAME", "nameasc") or {}

	for i, v in ipairs(files) do
		local ext = string.GetExtensionFromFilename(v) or ""
		if not self._validsoundtypes[ext] then
			continue
		end

		validfiles[#validfiles + 1] = v
	end

	return validfiles
end

function RADIOFS:Find(globalpath, vfolder)
	if vfolder == "" then
		return nil, {":gamesounds"}
	end

	if not self:IsInFolder(vfolder) then
		return nil
	end

	globalpath = self:GetSoundPath(vfolder)

	if not globalpath then
		return nil
	end

	local findpath = self.rootfolder .. "/" .. globalpath
	local _, folders = file.Find(findpath .. "/*", "GAME", "nameasc")

	local files = self:GetFiles(findpath)

	if #files > 0 then
		files[#files + 1] = ":allfiles"
	end

	return files, folders
end

function RADIOFS:Exists(globalpath, vpath)
	globalpath = self:GetSoundPath(vpath)

	if not globalpath then
		return false
	end

	local findpath = self.rootfolder .. "/" .. globalpath
	local name = string.GetFileFromFilename(vpath)

	if name == ":allfiles" then
		return true
	end

	if file.Exists(findpath, "GAME") then
		return true
	end

	if file.IsDir(findpath, "GAME") then
		return true
	end

	return false
end

RADIOFS.Delete = nil

function RADIOFS:Read(globalpath, vpath, callback)
	globalpath = self:GetSoundPath(vpath)

	if not globalpath then
		callback(false, nil)
		return false
	end

	local findpath = self.rootfolder .. "/" .. globalpath
	local name = string.GetFileFromFilename(vpath)

	if name == "" then
		callback(false, nil)
		return false
	end

	if name == ":allfiles" then
		local playlist = {}

		local path = string.GetPathFromFilename(findpath)
		local urlpath = string.GetPathFromFilename(globalpath)

		local files = self:GetFiles(path)

		for i, v in ipairs(files) do
			playlist[#playlist + 1] = {
				name = v,
				url = urlpath .. v,
			}
		end

		callback(true, playlist)
		return true
	end

	local playlist = {
		{
			name = name,
			url = globalpath,
		},
	}

	callback(true, playlist)
	return true
end