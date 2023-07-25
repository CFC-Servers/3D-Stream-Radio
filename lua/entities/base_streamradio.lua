AddCSLuaFile()

DEFINE_BASECLASS("base_anim")

local StreamRadioLib = StreamRadioLib
local LIBNetwork = StreamRadioLib.Network
local LIBWire = StreamRadioLib.Wire

local WireLib = WireLib

local g_isLoaded = StreamRadioLib and StreamRadioLib.Loaded
local g_isWiremodLoaded = g_isLoaded and LIBWire.HasWiremod()

ENT.__IsRadio = true

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false

ENT.WireDebugName = "Stream Radio"

function ENT:AddDTNetworkVar(datatype, name, ...)
	if not g_isLoaded then
		return
	end

	return LIBNetwork.AddDTNetworkVar(self, datatype, name, ...)
end

function ENT:SetupDataTables()
	if not g_isLoaded then
		return
	end

	LIBNetwork.SetupDataTables(self)
end

function ENT:SetAnim( Animation, Frame, Rate )
	if not self.Animated or not self.AutomaticFrameAdvance then
		-- This must be run once on entities that will be animated
		self.Animated = true
		self:SetAutomaticFrameAdvance(true)
	end

	self:ResetSequence( Animation or 0 )
	self:SetCycle( Frame or 0 )
	self:SetPlaybackRate( Rate or 1 )
end

function ENT:EmitSoundIfExist( name, ... )
	name = name or ""
	if ( name == "" ) then
		return
	end

	self:EmitSound( name, ... )
end

function ENT:RegisterDupePose( name )
	self.DupePoses = self.DupePoses or {}
	self.DupePoses[name] = true
end

function ENT:GetDupePoses()
	self.DupePoses = self.DupePoses or {}

	local PoseParameter = {}
	for name, value in pairs( self.DupePoses ) do
		if ( not value ) then continue end
		PoseParameter[name] = self:GetPoseParameter( name )
	end

	return PoseParameter
end

function ENT:SetDupePoses( PoseParameter )
	PoseParameter = PoseParameter or {}

	for name, value in pairs( PoseParameter ) do
		if ( not value ) then continue end
		self:SetPoseParameter( name, value )
	end
end

function ENT:GetOrCreateStream()
	if not g_isLoaded then
		if IsValid(self.StreamObj) then
			self.StreamObj:Remove()
		end

		self.StreamObj = nil
		return nil
	end

	if IsValid(self.StreamObj) then
		return self.StreamObj
	end

	local stream = StreamRadioLib.CreateOBJ("stream")
	if not IsValid( stream ) then
		self.StreamObj = nil
		return nil
	end

	local function call(name, ...)
		if not IsValid( self ) then
			return
		end

		local func = self[name]

		if not isfunction(func) then
			return nil
		end

		return func(self, ...)
	end

	stream.OnConnect = function( ... )
		return call("StreamOnConnect", ...)
	end

	stream.OnError = function( ... )
		return call("StreamOnError", ...)
	end

	stream.OnClose = function( ... )
		return call("StreamOnClose", ...)
	end

	stream.OnRetry = function( ... )
		return call("StreamOnRetry", ...)
	end

	stream.OnSearch = function( ... )
		return call("StreamOnSearch", ...)
	end

	stream.OnMute = function( ... )
		return call("StreamOnMute", ...)
	end

	stream:SetEvent("OnPlayModeChange", tostring(self) .. "_base", function(...)
		return call("StreamOnPlayModeChange", ...)
	end)

	stream:SetName("stream")
	stream:SetNWName("str")
	stream:SetEntity(self)
	stream:ActivateNetworkedMode()
	stream:OnClose()

	self.StreamObj = stream
	return stream
end

function ENT:StreamOnConnect()
	self:CheckTransmitState()

	return true
end

function ENT:StreamOnSearch()
	self:CheckTransmitState()

	return true
end

function ENT:StreamOnRetry()
	self:CheckTransmitState()

	return true
end

function ENT:StreamOnError()
	self:CheckTransmitState()
end

function ENT:StreamOnClose()
	self:CheckTransmitState()
end

function ENT:StreamOnPlayModeChange()
	self:CheckTransmitState()
end

function ENT:IsStreaming()
	if not IsValid( self.StreamObj ) then
		return false
	end

	if not IsValid( self.StreamObj:GetChannel() ) then
		return false
	end

	return true
end

function ENT:HasStream()
	if not IsValid( self.StreamObj ) then
		return false
	end

	return true
end

function ENT:GetStreamObject()
	if not self:HasStream() then
		return nil
	end

	return self.StreamObj
end

function ENT:SetSoundPosAngOffset(pos, ang)
	self.SoundPosOffset = pos
	self.SoundAngOffset = ang
end

function ENT:GetSoundPosAngOffset()
	return self.SoundPosOffset, self.SoundAngOffset
end

local ang_zero = Angle()
local vec_zero = Vector()

function ENT:CalcSoundPosAngWorld()
	local pos = self:GetPos()
	local ang = self:GetAngles()

	local spos, sang = LocalToWorld(self.SoundPosOffset or vec_zero, self.SoundAngOffset or ang_zero, pos, ang)

	self.SoundPos = spos
	self.SoundAng = sang

	return spos, sang
end

function ENT:DistanceToEntity(ent, pos1, pos2)
	if not g_isLoaded then
		return 0
	end

	if not pos1 then
		pos1 = self.SoundPos
	end

	if not pos1 then
		return 0
	end

	if pos2 then
		return pos2:Distance(pos1)
	end

	pos2 = StreamRadioLib.GetCameraPos(ent)

	if not pos2 then
		return 0
	end

	return pos2:Distance(pos1)
end

function ENT:DistToSqrToEntity(ent, pos1, pos2)
	if not g_isLoaded then
		return 0
	end

	if not pos1 then
		pos1 = self.SoundPos
	end

	if not pos1 then
		return 0
	end

	if pos2 then
		return pos2:DistToSqr(pos1)
	end

	pos2 = StreamRadioLib.GetCameraPos(ent)

	if not pos2 then
		return 0
	end

	return pos2:DistToSqr(pos1)
end

function ENT:CheckDistanceToEntity(ent, maxDist, pos1, pos2)
	local maxDistSqr = maxDist * maxDist
	local distSqr = self:DistToSqrToEntity(ent, pos1, pos2)

	if distSqr > maxDistSqr then
		return false
	end

	return true
end

function ENT:Initialize()
	if g_isLoaded then
		StreamRadioLib.RegisterRadio(self)
	end

	if SERVER then
		self._WireOutputCache = {}
	end

	self:GetOrCreateStream()
	self:CheckTransmitState()
end

function ENT:OnTakeDamage( dmg )
	self:TakePhysicsDamage( dmg )
end

function ENT:OnReloaded()
	if CLIENT then return end
	self:Remove()
end

function ENT:IsMutedForPlayer(ply)
	if not g_isLoaded then
		return true
	end

	if not IsValid(ply) and CLIENT then
		ply = LocalPlayer()
	end

	if not IsValid(ply) then return true end
	if not ply:IsPlayer() then return true end
	if ply:IsBot() then return true end

	if StreamRadioLib.IsMuted(ply, self:GetRealRadioOwner()) then
		return true
	end

	local mutedist = math.min(self:GetRadius() + 1000, StreamRadioLib.GetMuteDistance(ply))
	local camPos = nil

	if CLIENT then
		camPos = StreamRadioLib.GetCameraViewPos(ply)
	end

	if not self:CheckDistanceToEntity(ply, mutedist, nil, camPos) then
		return true
	end

	return false
end

function ENT:IsMutedForAll()
	if not g_isLoaded then
		return true
	end

	if self:GetSVMute() then
		return true
	end

	local allplayers = player.GetHumans()

	for k, v in pairs(allplayers) do
		if not IsValid(v) then continue end

		local muted = self:IsMutedForPlayer(v)
		if muted then continue end

		return false
	end

	return true
end

function ENT:CheckTransmitState()
	if CLIENT then return end

	self._TransmitCheck = true
	self._LastTransmitCheck = CurTime()
end

function ENT:UpdateTransmitState()
	local stream = self.StreamObj

	if not IsValid(stream) then
		return TRANSMIT_PVS
	end

	if stream:IsStopMode() then return TRANSMIT_PVS end
	if stream:GetURL() == "" then return TRANSMIT_PVS end
	if self:IsMutedForAll() then return TRANSMIT_PVS end

	return TRANSMIT_ALWAYS
end

function ENT:PostFakeRemove( )
	if not g_isLoaded then
		return nil
	end

	StreamRadioLib.RegisterRadio(self)
end

function ENT:OnRemove()
	local Stream = self.StreamObj
	local creationID = self:GetCreationID()

	-- We run it in a timer to ensure the entity is actually gone
	timer.Simple( 0.05, function()
		if IsValid(self) then
			self:PostFakeRemove()
			return
		end

		if IsValid(Stream) then
			Stream:Remove()
			Stream = nil
		end

		if g_isLoaded then
			StreamRadioLib.UnregisterRadio(creationID)
		end
	end)

	if g_isWiremodLoaded and SERVER then
		WireLib.Remove(self)
	end

	BaseClass.OnRemove(self)
end

function ENT:NWOverflowKill()
	self:SetNoDraw(true)

	if SERVER then
		self:Remove()
	end
end

function ENT:NonDormantThink()
	-- Override me
end

function ENT:FastThink()
	local pos, ang = self:CalcSoundPosAngWorld()

	if SERVER then
		if g_isWiremodLoaded then
			self:WiremodThink()
		end
	else
		local stream = self.StreamObj

		if CLIENT and self:ShowDebug() then
			local channeltext = "no sound"

			if stream then
				channeltext = tostring(stream)
			end

			debugoverlay.Axis(pos, ang, 5, 0.05, color_white)
			debugoverlay.EntityTextAtPosition(pos, 1, "Sound pos: " .. channeltext, 0.05, color_white)
		end
	
		if IsValid(stream) then
			stream:Set3DPosition(pos, ang:Forward())
		end
	end
end

function ENT:Think()
	BaseClass.Think(self)

	local curtime = CurTime()

	if not g_isLoaded then
		if SERVER then
			self:NextThink(curtime + 0.1)
		end

		return true
	end

	self:InternalThink()

	if SERVER then
		self:NextThink(curtime + 0.1)
		return true
	end

	return true
end

function ENT:InternalThink()
	local now = CurTime()

	self._nextSlowThink = self._nextSlowThink or 0

	if self._nextSlowThink < now then
		self:InternalSlowThink()
		self._nextSlowThink = now + 0.20
	end
end

function ENT:InternalSlowThink()
	local now = CurTime()

	StreamRadioLib.RegisterRadio(self)

	self._isDebugCache = nil
	self._beingLookedAtCache = nil
	self._showDebugCache = nil

	if SERVER then
		if self._TransmitCheck then
			self:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
			self._TransmitCheck = nil
		end

		local nextTransmitCheck = (self._LastTransmitCheck or 0) + 2.5
		if now >= nextTransmitCheck then
			self:CheckTransmitState()
		end
	else
		if g_isWiremodLoaded then
			if now >= (self._NextRBUpdate or 0) then
				Wire_UpdateRenderBounds(self)
				self._NextRBUpdate = now + math.random(30, 100) / 10
			end
		end
	end
end

function ENT:GetStreamURL()
	if not IsValid(self.StreamObj) then return "" end
	return self.StreamObj:GetURL()
end

function ENT:GetStreamName()
	if not IsValid(self.StreamObj) then return "" end
	return self.StreamObj:GetStreamName()
end

if SERVER then
	function ENT:SetStreamURL(...)
		if not IsValid(self.StreamObj) then return end
		self.StreamObj:SetURL(...)
	end

	function ENT:SetStreamName(...)
		if not IsValid(self.StreamObj) then return end
		self.StreamObj:SetStreamName(...)
	end
end


function ENT:IsDebug()
	if self._isDebugCache ~= nil then
		return self._isDebugCache
	end

	local isDebug = StreamRadioLib.Util.IsDebug()
	self._isDebugCache = isDebug

	return isDebug
end

function ENT:ShowDebug()
	if self._showDebugCache ~= nil then
		return self._showDebugCache
	end

	self._showDebugCache = false

	if not self:IsDebug() then
		return false
	end

	if CLIENT and not self:IsBeingLookedAt() then
		return false
	end

	self._showDebugCache = true
	return true
end

if CLIENT then
	function ENT:DrawTranslucent()
		self:DrawModel()

		if not g_isWiremodLoaded then return end
		Wire_Render(self)
	end

	function ENT:BeingLookedAtByLocalPlayer()
		local ply = LocalPlayer()
		if not IsValid( ply ) then
			return false
		end

		if not self:CheckDistanceToEntity(ply, 256) then
			return false
		end

		local tr = StreamRadioLib.Trace(ply)
		return tr.Entity == self
	end

	function ENT:IsBeingLookedAt()
		if self._beingLookedAtCache ~= nil then
			return self._beingLookedAtCache
		end

		local beingLookedAt = self:BeingLookedAtByLocalPlayer()
		self._beingLookedAtCache = beingLookedAt

		return beingLookedAt
	end

	return
else
	function ENT:WiremodThink()
		-- Override me
	end

	function ENT:AddWireInput(name, ptype, desc)
		if not g_isWiremodLoaded then return end

		name = string.Trim(tostring(name or ""))
		ptype = string.upper(string.Trim(tostring(ptype or "NORMAL")))
		desc = string.Trim(tostring(desc or ""))

		self._wireports = self._wireports or {}
		self._wireports.In = self._wireports.In or {}
		self._wireports.In.names = self._wireports.In.names or {}
		self._wireports.In.types = self._wireports.In.types or {}
		self._wireports.In.descs = self._wireports.In.descs or {}

		self._wireports.In.once = self._wireports.In.once or {}
		if(self._wireports.In.once[name]) then return end

		self._wireports.In.names[#self._wireports.In.names + 1] = name
		self._wireports.In.types[#self._wireports.In.types + 1] = ptype
		self._wireports.In.descs[#self._wireports.In.descs + 1] = desc
		self._wireports.In.once[name] = true
	end

	function ENT:AddWireOutput(name, ptype, desc)
		if not g_isWiremodLoaded then return end

		name = string.Trim(tostring(name or ""))
		ptype = string.upper(string.Trim(tostring(ptype or "NORMAL")))
		desc = string.Trim(tostring(desc or ""))

		self._wireports = self._wireports or {}
		self._wireports.Out = self._wireports.Out or {}
		self._wireports.Out.names = self._wireports.Out.names or {}
		self._wireports.Out.types = self._wireports.Out.types or {}
		self._wireports.Out.descs = self._wireports.Out.descs or {}

		self._wireports.Out.once = self._wireports.Out.once or {}
		if(self._wireports.Out.once[name]) then return end

		self._wireports.Out.names[#self._wireports.Out.names + 1] = name
		self._wireports.Out.types[#self._wireports.Out.types + 1] = ptype
		self._wireports.Out.descs[#self._wireports.Out.descs + 1] = desc
		self._wireports.Out.once[name] = true
	end

	function ENT:InitWirePorts()
		if not g_isWiremodLoaded then return end

		if not self._wireports then return end

		if self._wireports.In then
			self.Inputs = WireLib.CreateSpecialInputs(self, self._wireports.In.names, self._wireports.In.types, self._wireports.In.descs)
		end

		if self._wireports.Out then
			self.Outputs = WireLib.CreateSpecialOutputs(self, self._wireports.Out.names, self._wireports.Out.types, self._wireports.Out.descs)
		end

		self._wireports = nil
	end

	function ENT:IsConnectedInputWire(name)
		if not g_isWiremodLoaded then return false end
		if not istable(self.Inputs) then return false end

		local wireinput = self.Inputs[name]
		if not istable(wireinput) then return false end
		if not IsValid(wireinput.Src) then return false end

		return true
	end

	function ENT:IsConnectedOutputWire(name)
		if not g_isWiremodLoaded then return false end
		if not istable(self.Outputs) then return false end
		local wireoutput = self.Outputs[name]

		if not istable(wireoutput) then return false end
		if not istable(wireoutput.Connected) then return false end
		if not istable(wireoutput.Connected[1]) then return false end
		if not IsValid(wireoutput.Connected[1].Entity) then return false end

		return true
	end

	function ENT:IsConnectedWirelink()
		return self:IsConnectedOutputWire("wirelink");
	end

	function ENT:TriggerWireOutput(name, value)
		if not g_isWiremodLoaded then return end

		if isbool(value) or value == nil then
			value = value and 1 or 0
		end

		if value == self._WireOutputCache[name] and not istable(value) then return end
		self._WireOutputCache[name] = value

		WireLib.TriggerOutput(self, name, value)
	end

	function ENT:TriggerInput(name, value)
		local wired = self:IsConnectedInputWire(name) or self:IsConnectedWirelink()
		self:OnWireInputTrigger(name, value, wired)
	end

	function ENT:OnWireInputTrigger(name, value, wired)
		-- Override me
	end

	function ENT:OnRestore()
		if not g_isWiremodLoaded then return end

		WireLib.Restored( self )
	end

	function ENT:SetDupeData(key, value)
		self.DupeData = self.DupeData or {}
		self.DupeData[key] = value
	end

	function ENT:GetDupeData(key)
		self.DupeData = self.DupeData or {}
		return self.DupeData[key]
	end

	function ENT:PermaPropSave()
		return {}
	end

	function ENT:PermaPropLoad(data)
		return true
	end

	function ENT:OnEntityCopyTableFinish(data)
		local done = {}

		-- Filter out all variables/members with an storable values
		-- to avoid any abnormal, invalid or unexpectedly shared entity stats on duping (especially for Garry-Dupe)
		local function recursive_filter(tab, newtable)
			if done[tab] then return tab end
			done[tab] = true

			if newtable then
				for k, v in pairs(tab) do
					if isfunction(k) or isfunction(v) then
						continue
					end

					if isentity(k) or isentity(v) then
						continue
					end

					if istable(k) then
						k = recursive_filter(k, {})
					end

					if istable(v) then
						newtable[k] = recursive_filter(v, {})
						continue
					end

					newtable[k] = v
				end

				return newtable
			end

			for k, v in pairs(tab) do
				if isfunction(k) or isfunction(v) then
					tab[k] = nil
					continue
				end

				if isentity(k) or isentity(v) then
					tab[k] = nil
					continue
				end

				if istable(k) then
					tab[k] = nil
					continue
				end

				if istable(v) then
					tab[k] = recursive_filter(v, {})
					continue
				end

				tab[k] = v
			end

			return tab
		end

		local EntityMods = data.EntityMods
		local PhysicsObjects = data.PhysicsObjects

		data.StreamObj = nil
		data._3dstreamradio_classobjs = nil
		data._3dstreamradio_classobjs_data = nil
		data._3dstraemradio_classobjs_nw_register = nil
		data.StreamRadioDT = nil
		data.pl = nil
		data.Owner = nil

		data.Inputs = nil
		data.Outputs = nil

		data.BaseClass = nil
		data.OnDieFunctions = nil
		data.PhysicsObjects = nil
		data.EntityMods = nil

		data.old = nil

		if self.OnSetupCopyData then
			self:OnSetupCopyData(data)
		end

		-- Filter out all variables/members with an underscore in the beginning
		-- to avoid any abnormal, invalid or unexpectedly shared entity stats on duping (especially for Garry-Dupe)
		for k, v in pairs(data) do
			if isstring(k) and #k > 0 and k[1] == "_" then
				data[k] = nil
				continue
			end
		end

		recursive_filter(data)
		data.EntityMods = EntityMods
		data.PhysicsObjects = PhysicsObjects
	end

	function ENT:PreEntityCopy()
		if g_isWiremodLoaded then
			self:SetDupeData("Wire", WireLib.BuildDupeInfo(self))
		end

		local classsystem_objs = {}

		for k, v in pairs(self._3dstreamradio_classobjs or {}) do
			if not IsValid(v) then continue end

			local name = v:GetName()
			local ent = v:GetEntity()

			if ent ~= self then continue end

			local func = v.PreDupe
			if not func then continue end

			classsystem_objs[name] = func(v, self)
		end

		self:SetDupeData("Classsystem", classsystem_objs)

		self:SetDupeData("Skin", {
			Color = self:GetColor(),
			Skin = self:GetSkin(),
		})

		self:SetDupeData("DupePoses", self:GetDupePoses())

		if self.OnPreEntityCopy then
			self:OnPreEntityCopy()
		end

		duplicator.StoreEntityModifier(self, "DupeData", self.DupeData)
	end

	function ENT:PostEntityPaste( ply, ent, CreatedEntities )
		if not IsValid(ent) then return end
		if not ent.EntityMods then return end

		ent.DupeData = ent.EntityMods.DupeData or {}

		ent._WireData = ent.DupeData.Wire
		ent.DupeData.Wire = nil

		if g_isWiremodLoaded and ent._WireData then
			timer.Simple(0.2, function()
				if not IsValid(ent) then return end
				if not ent._WireData then return end

				WireLib.ApplyDupeInfo(ply, ent, ent._WireData, function(id, default)
					if id == nil then return default end
					if id == 0 then return game.GetWorld() end

					local ident = CreatedEntities[id]

					if not IsValid(ident) then
						if isnumber(id) then
							ident = ents.GetByIndex(id)
						end
					end

					if not IsValid(ident) then
						ident = default
					end

					return ident
				end)

				ent._WireData = nil
			end)
		end

		ent._3dstreamradio_classobjs_data = ent.DupeData.Classsystem
		ent.DupeData.Classsystem = nil

		if ent._3dstreamradio_classobjs_data and ent.PostClasssystemPaste then
			timer.Simple(0.1, function()
				if not IsValid(ent) then return end
				if not ent._3dstreamradio_classobjs_data then return end
				if not ent.PostClasssystemPaste then return end

				ent:PostClasssystemPaste()
			end)
		end

		if ent.DupeData.Skin then
			ent:SetSkin(ent.DupeData.Skin.Skin or 0)
			ent:SetColor(ent.DupeData.Skin.Color or color_white)
		end

		ent.DupeData.Skin = nil

		ent:SetDupePoses(ent.DupeData.DupePoses)
		ent.DupeData.DupePoses = nil

		if not ent.DupeDataApply then return end

		for key, value in pairs(ent.DupeData) do
			ent:DupeDataApply(key, value)
		end
	end

	function ENT:PostClasssystemPaste()
		if not IsValid(self.StreamObj) then return end
		self.StreamObj:LoadFromDupe()
	end
end
