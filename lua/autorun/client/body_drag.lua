-- Body Drag Client v1.0.0
local BodyDragKeyConVar = CreateConVar("bg_body_drag_key", "38", { FCVAR_USERINFO, FCVAR_ARCHIVE })                 -- KEY_E = 38
local BodyThrowKeyConVar = CreateConVar("bg_body_throw_key", "2", { FCVAR_USERINFO, FCVAR_ARCHIVE })                -- MOUSE_RIGHT = 2
local BodyThrowGrenadeKeyConVar = CreateConVar("bg_body_throw_grenade_key", "4", { FCVAR_USERINFO, FCVAR_ARCHIVE }) -- MOUSE_MIDDLE = 4

-- Track key states to prevent duplicate messages
local keyState = {
	drag = false,
	throw = false,
	throwGrenade = false
}

-- Helper function to check if a key is pressed
local function IsKeyPressed(key)
	return input.IsKeyDown(key) or input.IsMouseDown(key)
end

-- Think hook for key handling
hook.Add("Think", "BodyDragKeyHandler", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	if not IsValid(ply:GetNWEntity("dragging", nil)) then
		keyState.drag = false
	end

	local dragKey = BodyDragKeyConVar:GetInt()
	local throwKey = BodyThrowKeyConVar:GetInt()
	local throwGrenadeKey = BodyThrowGrenadeKeyConVar:GetInt()

	local dragPressed = IsKeyPressed(dragKey)
	local throwPressed = IsKeyPressed(throwKey)
	local throwGrenadePressed = IsKeyPressed(throwGrenadeKey)

	if dragPressed and not keyState.drag then
		keyState.drag = true
		net.Start("BD_Start")
		net.SendToServer()
	elseif not dragPressed and keyState.drag then
		keyState.drag = false
		net.Start("BD_Drop")
		net.SendToServer()
	end

	if throwPressed and not keyState.throw then
		keyState.throw = true
		if keyState.drag then
			net.Start("BD_Throw")
			net.SendToServer()
		end
	elseif not throwPressed and keyState.throw then
		keyState.throw = false
	end

	-- Handle Throw with Grenade
	if throwGrenadePressed and not keyState.throwGrenade then
		keyState.throwGrenade = true
		if keyState.drag then
			net.Start("BD_ThrowWithGrenade")
			net.SendToServer()
		end
	elseif not throwGrenadePressed and keyState.throwGrenade then
		keyState.throwGrenade = false
	end
end)

hook.Add("HUDPaint", "BodyDragHUD", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local dragging = ply:GetNWEntity("dragging", nil)
	if IsValid(dragging) then
		-- Draw a simple indicator
		draw.SimpleText("Dragging: " .. (dragging:GetClass() or "Ragdoll"),
			"TargetID", ScrW() / 2, ScrH() - 100,
			Color(255, 255, 255), TEXT_ALIGN_CENTER)
	end
end)

print("[Body Drag Client] Loaded v1.0.0")
