---@diagnostic disable: param-type-mismatch
-- Body Drag Improved --- the REAL SHIT
util.AddNetworkString("BD_Start")
util.AddNetworkString("BD_Throw")
util.AddNetworkString("BD_ThrowWithGrenade")
util.AddNetworkString("BD_Drop")

local GrabWhileAlive = CreateConVar("bg_grab_while_alive", "0", { FCVAR_ARCHIVE, FCVAR_NOTIFY })
local Enabled = CreateConVar("bg_body_drag_enabled", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY })
local AggressivePreset = CreateConVar("bg_preset", "hell", { FCVAR_ARCHIVE, FCVAR_NOTIFY })
local ThrowForceMultiplier = CreateConVar("bg_throw_force", "1.0", { FCVAR_ARCHIVE, FCVAR_NOTIFY })
local MaxDragDistance = CreateConVar("bg_max_drag_distance", "150", { FCVAR_ARCHIVE, FCVAR_NOTIFY })

local EntBlacklist = {
	["npc_combinedropship"] = true,
	["npc_combinegunship"] = true,
	["npc_helicopter"] = true,
	["npc_strider"] = true,
	["npc_turret_floor"] = true,
	["npc_turret_ground"] = true,
	["npc_turret_ceiling"] = true,
	["npc_rollermine"] = true,
	["npc_combine_camera"] = true,
	["npc_grenade_frag"] = true,
	["npc_manhack"] = true
}

print("Body Drag loaded v0.2.0")

-- Bimap for tracking players to rags and rags to players
local DraggingPlayers = {}  -- ply -> entity
local DraggingEntities = {} -- entity -> ply

local function GetThrowForce()
	local preset = AggressivePreset:GetString()
	local multiplier = ThrowForceMultiplier:GetFloat()

	if preset == "hell" then
		return 1000000 * multiplier
	elseif preset == "normal" then
		return 10000 * multiplier
	elseif preset == "sneaky-beaky-like" then
		return 32768 * multiplier
	else
		return 65536 * multiplier
	end
end

-- Helper function to create ragdoll from NPC
local function CreateRagdollFromNPC(npc, hitPos, hitNormal)
	if not IsValid(npc) then return end

	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return end

	rag:SetModel(npc:GetModel())
	rag:SetPos(hitPos)
	rag:SetAngles(hitNormal:Angle())
	rag:Spawn()
	rag:Activate()
	rag:SetSkin(npc:GetSkin())

	for i = 0, npc:GetNumBodyGroups() - 1 do
		rag:SetBodygroup(i, npc:GetBodygroup(i))
	end

	for i = 1, rag:GetPhysicsObjectCount() do
		local bone = rag:GetPhysicsObjectNum(i - 1)
		if IsValid(bone) then
			local boneId = rag:TranslatePhysBoneToBone(i - 1)
			local pos, ang = npc:GetBonePosition(boneId)
			if pos then
				bone:SetPos(pos)
				bone:SetAngles(ang)
				bone:Wake()
			end
		end
	end

	rag:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
	npc:Remove()

	return rag
end

local function StartDragging(ply, entity)
	if not IsValid(ply) or not IsValid(entity) then return false end

	local phys = entity:GetPhysicsObject()
	if not IsValid(phys) then return false end

	DraggingPlayers[ply] = entity
	DraggingEntities[entity] = ply

	entity:SetNWBool("thrown", false)

	phys:SetMass(10)
	phys:SetDamping(0.01, 10)
	phys:EnableGravity(false)
	phys:EnableMotion(true)

	for i = 0, entity:GetPhysicsObjectCount() - 1 do
		local bone = entity:GetPhysicsObjectNum(i)
		if IsValid(bone) then
			bone:EnableMotion(true)
			bone:EnableGravity(false)
			bone:Wake()
		end
	end

	phys:Wake()

	return true
end

local function StopDragging(entity)
	if not IsValid(entity) then return end

	local ply = DraggingEntities[entity]

	if IsValid(ply) then
		DraggingPlayers[ply] = nil
	end

	DraggingEntities[entity] = nil

	local phys = entity:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(100)
		phys:SetDamping(0, 0)
		phys:EnableGravity(true)
		phys:Wake()

		for i = 0, entity:GetPhysicsObjectCount() - 1 do
			local bone = entity:GetPhysicsObjectNum(i)
			if IsValid(bone) then
				bone:EnableMotion(true)
				bone:EnableGravity(true)
				bone:Wake()
			end
		end
	end

	entity:SetNWBool("dragging", false)
	entity:SetNWEntity("owner", nil)
end

-- Network handlers
net.Receive("BD_Start", function(len, ply)
	if not Enabled:GetBool() then return end
	if not IsValid(ply) then return end

	if DraggingPlayers[ply] then return end

	local trace = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:EyeAngles():Forward() * 100,
		filter = ply
	})

	local targetEntity = trace.Entity

	-- Handle NPC to ragdoll conversion
	if GrabWhileAlive:GetBool() and IsValid(targetEntity) then
		local class = targetEntity:GetClass()
		if string.StartsWith(class, "npc_") and not EntBlacklist[class] then
			if targetEntity:Health() > 0 then
				targetEntity = CreateRagdollFromNPC(targetEntity, trace.HitPos, trace.HitNormal)
			end
		end
	end

	if not targetEntity or not IsValid(targetEntity) or targetEntity:GetClass() ~= "prop_ragdoll" then
		local entities = ents.FindInSphere(ply:EyePos(), 100)
		for _, ent in pairs(entities) do
			if ent:GetClass() == "prop_ragdoll" and not DraggingEntities[ent] then
				targetEntity = ent
				break
			end
		end
	end

	if not targetEntity or not IsValid(targetEntity) or targetEntity:GetClass() ~= "prop_ragdoll" then
		return
	end

	if DraggingEntities[targetEntity] then return end

	if StartDragging(ply, targetEntity) then
		ply:SetNWEntity("dragging", targetEntity)
		targetEntity:SetNWBool("dragging", true)
		targetEntity:SetNWEntity("owner", ply)
	end
end)

net.Receive("BD_Throw", function(len, ply)
	if not Enabled:GetBool() then return end
	if not IsValid(ply) then return end

	local ent = DraggingPlayers[ply]
	if not IsValid(ent) then return end

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return end

	-- Stop dragging
	StopDragging(ent)
	ply:SetNWEntity("dragging", nil)

	-- Visual feedback
	ply:ViewPunch(Angle(math.random(-10, 10), math.random(-10, 10), 0))
	ply:SetAnimation(PLAYER_ATTACK1)

	-- Apply throw force
	local force = GetThrowForce()
	local aimVec = ply:GetAimVector()

	phys:EnableMotion(true)
	phys:EnableGravity(true)
	phys:Wake()

	phys:ApplyForceCenter(aimVec * force)
	phys:ApplyTorqueCenter(aimVec * Vector(force, force, force) * 0.1)

	ent:SetNWBool("thrown", true)

	timer.Simple(2, function()
		if IsValid(ent) then
			ent:SetNWBool("thrown", false)
		end
	end)
end)

net.Receive("BD_ThrowWithGrenade", function(len, ply)
	if not Enabled:GetBool() then return end
	if not IsValid(ply) then return end

	local ent = DraggingPlayers[ply]
	if not IsValid(ent) then return end

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return end

	-- Stop dragging
	StopDragging(ent)
	ply:SetNWEntity("dragging", nil)

	-- Visual feedback
	ply:ViewPunch(Angle(math.random(-10, 10), math.random(-10, 10), 0))
	ply:SetAnimation(PLAYER_ATTACK1)

	-- Create and attach grenade
	local grenade = ents.Create("npc_grenade_frag")
	if IsValid(grenade) then
		grenade:SetPos(ent:GetPos() + Vector(0, 0, 20))
		grenade:SetAngles(Angle(0, 0, 0))
		grenade:SetModel("models/weapons/w_grenade.mdl")
		grenade:SetOwner(ply)
		grenade:SetPhysicsAttacker(ply)
		grenade:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		grenade:Spawn()
		grenade:Activate()

		grenade:Fire("SetTimer", "1.5", 0)

		timer.Simple(0, function()
			if IsValid(grenade) and IsValid(ent) then
				local boneId = ent:LookupBone("ValveBiped.Bip01_Spine2") or 0

				local weld = constraint.Weld(ent, grenade, boneId, 0, 0, true)
				if IsValid(weld) then
					weld:Fire("SetDamagePercent", "0", 0)
				end

				grenade:SetParent(ent)
				grenade:SetLocalPos(Vector(0, 0, 20))
			end
		end)
	end

	-- Apply throw force
	local force = GetThrowForce() * 1.5
	local aimVec = ply:GetAimVector()

	phys:EnableMotion(true)
	phys:EnableGravity(true)
	phys:Wake()

	phys:ApplyForceCenter(aimVec * force)
	phys:ApplyTorqueCenter(aimVec * Vector(force, force, force) * 0.1)

	ent:SetNWBool("thrown", true)

	timer.Simple(2, function()
		if IsValid(ent) then
			ent:SetNWBool("thrown", false)
		end
	end)
end)

net.Receive("BD_Drop", function(len, ply)
	if not Enabled:GetBool() then return end
	if not IsValid(ply) then return end

	local ent = DraggingPlayers[ply]
	if IsValid(ent) then
		StopDragging(ent)
		ply:SetNWEntity("dragging", nil)
	end
end)

-- Hook to prevent attack while dragging
hook.Add("StartCommand", "BodyDrag_AttackBlock", function(ply, cmd)
	if not Enabled:GetBool() then return end
	if not IsValid(ply) then return end

	if DraggingPlayers[ply] then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
	end
end)

local function DragThink()
	if not Enabled:GetBool() then return end
	for ply, entity in pairs(DraggingPlayers) do
		if not IsValid(ply) or not IsValid(entity) then
			if IsValid(entity) then
				StopDragging(entity)
			end
			if IsValid(ply) then
				ply:SetNWEntity("dragging", nil)
			end
			DraggingPlayers[ply] = nil
			continue
		end

		-- Check distance
		local maxDistance = MaxDragDistance:GetInt()
		if ply:GetPos():Distance(entity:GetPos()) > maxDistance then
			StopDragging(entity)
			ply:SetNWEntity("dragging", nil)
			continue
		end

		local phys = entity:GetPhysicsObject()
		if not IsValid(phys) then
			StopDragging(entity)
			ply:SetNWEntity("dragging", nil)
			continue
		end

		local targetPos = ply:EyePos() + ply:EyeAngles():Forward() * 45 + Vector(0, 0, 5)
		phys:SetPos(targetPos)
	end
end
hook.Add("Think", "BodyDrag_Think", DragThink)

-- Cleanup hooks
hook.Add("PlayerDisconnected", "BodyDrag_Cleanup", function(ply)
	local ent = DraggingPlayers[ply]
	if IsValid(ent) then
		StopDragging(ent)
	end
	DraggingPlayers[ply] = nil
end)

hook.Add("EntityRemoved", "BodyDrag_EntityCleanup", function(entity)
	if DraggingEntities[entity] then
		local ply = DraggingEntities[entity]
		if IsValid(ply) then
			ply:SetNWEntity("dragging", nil)
		end
		DraggingPlayers[ply] = nil
		DraggingEntities[entity] = nil
	end
end)

hook.Add("OnNPCKilled", "BodyDrag_NPCCleanup", function(npc, attacker, inflictor)
	if DraggingEntities[npc] then
		local ply = DraggingEntities[npc]
		if IsValid(ply) then
			ply:SetNWEntity("dragging", nil)
		end
		StopDragging(npc)
	end
end)

-- Initialize ragdolls created by the game
hook.Add("CreateEntityRagdoll", "BodyDrag_RagdollInit", function(entity, ragdoll)
	if not Enabled:GetBool() then return end
	if not IsValid(ragdoll) then return end

	ragdoll:SetNWBool("dragging", false)
	ragdoll:SetNWEntity("owner", nil)
	ragdoll:SetNWBool("thrown", false)
end)

-- Clear all state on map change
hook.Add("ShutDown", "BodyDrag_MapChange", function()
	DraggingPlayers = {}
	DraggingEntities = {}
end)
