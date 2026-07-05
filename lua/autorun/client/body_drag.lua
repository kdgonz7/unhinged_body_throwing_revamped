local BodyDragKeyConVar = CreateConVar("bg_body_drag_key", KEY_E, { FCVAR_USERINFO, FCVAR_ARCHIVE })
local BodyThrowKeyConVar = CreateConVar("bg_body_drag_throw", MOUSE_RIGHT, { FCVAR_USERINFO, FCVAR_ARCHIVE })
local BodyThrowGrenadeKeyConVar = CreateConVar("bg_body_throw_grenade", MOUSE_MIDDLE, { FCVAR_USERINFO, FCVAR_ARCHIVE })

local isDragging = false
local isThrowing = false
local isThrowingGrenade = false

-- Helper function to check if a specific key is currently pressed
local function IsKeyPressed(key)
	return input.IsKeyDown(key) or input.IsMouseDown(key)
end

concommand.Add("+startdrag", function(ply, cmd, args)
	if not ply:IsValid() then return end
	isDragging = true
end)

concommand.Add("-startdrag", function(ply, cmd, args)
	if not ply:IsValid() then return end
	if isDragging then
		net.Start("BD_Drop")
		net.SendToServer()
		isDragging = false
	end
end)

concommand.Add("+throwbody", function(ply, cmd, args)
	if not ply:IsValid() then return end
	isThrowing = true
end)

concommand.Add("-throwbody", function(ply, cmd, args)
	if not ply:IsValid() then return end
	if isThrowing then
		net.Start("BD_Throw")
		net.SendToServer()
		isThrowing = false
	end
end)

concommand.Add("+throwbodywithgrenade", function(ply, cmd, args)
	if not ply:IsValid() then return end
	isThrowingGrenade = true
end)

concommand.Add("-throwbodywithgrenade", function(ply, cmd, args)
	if not ply:IsValid() then return end
	if isThrowingGrenade then
		net.Start("BD_ThrowWithGrenade")
		net.SendToServer()
		isThrowingGrenade = false
	end
end)

hook.Add("Think", "BodyDragCommandCheck", function()
	local ply = LocalPlayer()
	if not ply:IsValid() then return end

	local dragKey = BodyDragKeyConVar:GetInt()
	local throwKey = BodyThrowKeyConVar:GetInt()
	local throwGrenadeKey = BodyThrowGrenadeKeyConVar:GetInt()

	-- Start Drag
	if IsKeyPressed(dragKey) and not isDragging then
		net.Start("BD_Start")
		net.SendToServer()
		isDragging = true
	end

	-- Drop Body if drag key is released and we were dragging
	if not IsKeyPressed(dragKey) and isDragging then
		net.Start("BD_Drop")
		net.SendToServer()
		isDragging = false
	end

	-- Throw Body
	if IsKeyPressed(throwKey) and not isThrowing and not isDragging then -- Only throw if not currently dragging
		net.Start("BD_Throw")
		net.SendToServer()
		isThrowing = true
	end
	if not IsKeyPressed(throwKey) and isThrowing then
		isThrowing = false
	end

	-- Throw Body with Grenade
	if IsKeyPressed(throwGrenadeKey) and not isThrowingGrenade and not isDragging then -- Only throw if not currently dragging
		net.Start("BD_ThrowWithGrenade")
		net.SendToServer()
		isThrowingGrenade = true
	end
	if not IsKeyPressed(throwGrenadeKey) and isThrowingGrenade then
		isThrowingGrenade = false
	end
end)
