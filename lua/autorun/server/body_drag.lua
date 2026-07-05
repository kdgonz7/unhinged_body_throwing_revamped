-- Body Drag

util.AddNetworkString("BD_Start")
util.AddNetworkString("BD_Throw")
util.AddNetworkString("BD_ThrowWithGrenade")
util.AddNetworkString("BD_Drop")

local GrabWhileAlive = CreateConVar("bg_grab_while_alive", "0", { FCVAR_ARCHIVE, FCVAR_NOTIFY })
local Enabled = CreateConVar("bg_body_drag_enabled", "1", { FCVAR_ARCHIVE, FCVAR_NOTIFY })
local AggressivePreset = CreateConVar("bg_preset", "hell", { FCVAR_ARCHIVE, FCVAR_NOTIFY })
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

print("Body Drag loaded v0.0.1")

net.Receive("BD_Start", function(len, ply)
	if ! Enabled:GetBool() then return end

	if ply:GetNWBool("dragging", false) then return end

	local ps = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:EyeAngles():Forward() * 100,
		filter = ply
	})

	if GrabWhileAlive:GetBool() then
		if (IsValid(ps.Entity) and ps.Entity:GetClass() != "prop_ragdoll" and string.StartsWith(ps.Entity:GetClass(), "npc_")) and ! EntBlacklist[ps.Entity:GetClass()] then
			if ps.Entity:Health() <= 0 then return end

			-- ragdolify the entity
			local rag = ents.Create("prop_ragdoll")
			rag:SetModel(ps.Entity:GetModel())
			rag:SetPos(ps.HitPos)
			rag:SetAngles(ps.HitNormal:Angle())
			rag:Spawn()

			for k, v in pairs(ps.Entity:GetBodyGroups()) do
				rag:SetBodygroup(v.id, ps.Entity:GetBodygroup(v.id))
			end

			for k, v in pairs(ps.Entity:GetMaterials()) do
				rag:SetSubMaterial(k - 1, v)
			end

			-- set the bones
			for i = 1, rag:GetPhysicsObjectCount() do
				local bone = rag:GetPhysicsObjectNum(i - 1)

				if (IsValid(bone)) then
					local pos, ang = ps.Entity:GetBonePosition(rag:TranslatePhysBoneToBone(i - 1))

					if (pos) then
						bone:SetPos(pos)
						bone:SetAngles(ang)
						bone:Wake()
					end
				end
			end

			rag:SetSkin(ps.Entity:GetSkin())
			rag:Activate()

			rag:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

			ps.Entity:Remove()
		end
	end
	-- note: this is somewhat a hacky
	-- note: way to allow for other ragdoll mods,
	-- note: idk why they did ragdolls like this. I guess they didn't take
	-- note: into the fact the multiple kinds of ragdolls (server and client), I feel like ReAgdoll is
	-- note: a client predicted esque addon, which is why using a serverside trace
	-- note: doesn't work correct.
	local rag = false
	local cet = ents.FindAlongRay(ply:EyePos(), ply:EyePos() + ply:EyeAngles():Forward() * 200, ply)

	if cet then
		for _, v in pairs(cet) do
			if v:GetClass() == "prop_ragdoll" then
				rag = true
				cet = { v }
				break
			end
		end
	end

	local et = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:EyeAngles():Forward() * 100,
		filter = ply
	})

	if ! IsValid(et.Entity) and ! rag then
		return
	end

	local satisfied = (function()
		if (IsValid(et.Entity)) then
			return (et.Entity:GetClass() == "prop_ragdoll" and ! et.Entity:GetNWBool("thrown", false)) or rag
		else
			return rag
		end
	end)()

	if satisfied then
		if rag then et.Entity = cet[1] end

		local phys = et.Entity:GetPhysicsObject()
		if ! IsValid(phys) then return end

		et.Entity:SetNWBool("dragging", true)
		et.Entity:SetNWEntity("owner", ply)
		et.Entity:SetNWBool("thrown", false)

		phys:SetMass(10)
		phys:SetDamping(0.01, 10)

		ply:SetNWEntity("dragging", et.Entity)
	end
end)

local getForce = (function()
	if AggressivePreset:GetString() == "hell" then
		return 10000000
	elseif AggressivePreset:GetString() == "normal" then
		return 10000
	elseif AggressivePreset:GetString() == "sneaky-beaky-like" then
		return 1
	else
		return 0
	end
end)()

net.Receive("BD_Throw", function(len, ply)
	local ent = ply:GetNWEntity("dragging", nil)

	if IsValid(ent) then
		local phys = ent:GetPhysicsObject()

		ent:SetNWBool("dragging", false)
		ent:SetNWEntity("owner", nil)
		ply:SetNWEntity("dragging", nil)

		ply:ViewPunch(Angle(math.random(-10, 10), math.random(-10, 10), 0))

		-- stop player from holding down the key
		ply:SetAnimation(PLAYER_ATTACK1)

		phys:Wake()

		phys:EnableMotion(true)
		phys:EnableGravity(true)

		local force = getForce

		phys:ApplyForceCenter(ply:GetAimVector() * force)
		phys:ApplyTorqueCenter(ply:GetAimVector() * Vector(force, force, force))
	end
end)

net.Receive("BD_ThrowWithGrenade", function(len, ply)
	local ent = ply:GetNWEntity("dragging", nil)

	if IsValid(ent) then
		local phys = ent:GetPhysicsObject()

		ent:SetNWBool("dragging", false)
		ent:SetNWEntity("owner", nil)
		ply:SetNWEntity("dragging", nil)

		ply:ViewPunch(Angle(math.random(-10, 10), math.random(-10, 10), 0))

		-- stop player from holding down the key
		ply:SetAnimation(PLAYER_ATTACK1)

		phys:Wake()

		phys:EnableMotion(true)
		phys:EnableGravity(true)

		local force = getForce

		-- add a grenade
		local grenade = ents.Create("npc_grenade_frag")

		if IsValid(grenade) then
			grenade:SetPos(ent:GetPos())
			grenade:SetAngles(ent:GetAngles())
			grenade:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			grenade:SetModel("models/weapons/w_grenade.mdl")
			grenade:SetPhysicsAttacker(ply)

			grenade:Fire("SetTimer", 1, 0)
			grenade:Spawn()

			-- set the damage incredibly high

			local chestbone = ent:LookupBone("ValveBiped.Bip01_Spine4")

			grenade:SetParent(ent, chestbone)
			grenade:SetOwner(ply)

			grenade:GetPhysicsObject():Sleep()
		end
		phys:ApplyForceCenter(ply:GetAimVector() * force)
		phys:ApplyTorqueCenter(ply:GetAimVector() * Vector(force, force, force))
	end
end)

hook.Add("StartCommand", "BodyDrag", function(ply, cmd)
	if ! Enabled:GetBool() then return end

	local ent = ply:GetNWEntity("dragging", nil)

	if IsValid(ent) then
		cmd:RemoveKey(IN_ATTACK)
	end
end)

net.Receive("BD_Drop", function(len, ply)
	if ! Enabled:GetBool() then return end

	local ent = ply:GetNWEntity("dragging", nil)

	if IsValid(ent) then
		ent:SetNWBool("dragging", false)
		ent:SetNWEntity("owner", nil)
		ply:SetNWEntity("dragging", nil)
	end
end)

-- LMFAO, I DIDNT REALIZE THERE WAS A PICKUP FUNCTION ALREADY, HOLY SHIT LOL
-- SO THIS IS ME, DEADASS REIMPLEMENTING THE ENTIRE FUCKING ENTITY PICKUP SYSTEM.
-- GOOD GOING ME.
-- and to any devs that see this: take this as a lesson.
-- do not reinvent the wheel, unless there's ABSOLUTELY no other way
--
-- IF PICKUP SYSTEM BECOMES DEPRECATED, LEAVE THIS HERE
hook.Add("Think", "BodyDrag", function()
	if ! Enabled:GetBool() then return end

	for k, v in pairs(ents.FindByClass("prop_ragdoll")) do
		if v:GetNWBool("dragging", false) == true then
			local owner = v:GetNWEntity("owner", nil)

			if IsValid(owner) then
				if (owner:GetPos() - v:GetPos()):Length() < 150 then
					local pob = v:GetPhysicsObject()
					local targetPos = owner:EyePos() + owner:EyeAngles():Forward() * 50 + Vector(0, 0, 10)

					if ! IsValid(pob) then
						return
					end
					pob:Wake()

					local groundTrace = util.TraceLine({
						start = targetPos,
						endpos = targetPos - Vector(0, 0, 100),
						filter = { owner, v },
					})

					if groundTrace.Hit then
						targetPos.z = math.max(targetPos.z, groundTrace.HitPos.z + 15) -- Adjust the height if necessary
					end

					pob:SetPos(targetPos)
				else
					v:SetNWBool("dragging", false)
					v:SetNWEntity("owner", nil)
					owner:SetNWEntity("dragging", nil)
				end
			end
		end
	end
end)

hook.Add("CreateEntityRagdoll", "BodyDrag", function(entity, ragdoll)
	if ! Enabled:GetBool() then return end

	ragdoll:SetNWBool("dragging", false)
	ragdoll:SetNWEntity("owner", nil)
end)
