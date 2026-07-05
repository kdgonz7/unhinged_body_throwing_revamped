hook.Add("AddToolMenuCategories", "catty", function()
	spawnmenu.AddToolCategory("Options", "Unhinged", "#UNHINGED")
end)

hook.Add("PopulateToolMenu", "catty", function()
	--- @param panel Panel
	spawnmenu.AddToolMenuOption("Options", "Unhinged", "UnhingedConfig", "#Config", "", "", function(panel)
		panel:ClearControls()

		if LocalPlayer():IsSuperAdmin() then
			panel:CheckBox("Body Dragging Enabled", "bg_body_drag_enabled")
			panel:ControlHelp("Enables or disables body dragging (more like body throwing but who cares)")

			panel:CheckBox("Grab enemies while they're alive? (Will kill them)", "bg_grab_while_alive")
			panel:ControlHelp(
				"Pressing E on an enemy while they're alive will allow you to grab them if this is on. #Trepang2")

			local cb = panel:ComboBox("Preset", "bg_preset")
			panel:ControlHelp(
				"Choose your preset for throwing. This preset controls the force of ragdolls and how easily you can throw them across the world. Normal is the most similar to Trepang2, while HELL is the most fun one.")

			cb:AddChoice("Hell", "hell")
			cb:AddChoice("Normal", "normal")
			cb:AddChoice("Sneaky Beaky Like", "sneaky-beaky-like")
		end

		panel:KeyBinder("Body Drag Key", "bg_body_drag_key")
		panel:ControlHelp("What do you want to use to grab bodies? Default = E")
		panel:KeyBinder("Throw Key", "bg_body_throw_key")
		panel:ControlHelp("What do you want to use to absolutely yeet bodies? Default = RIGHT CLICK")
		panel:KeyBinder("Throw (w/ grenade attached) Key", "bg_body_throw_grenade_key")
		panel:ControlHelp(
			"What do you want to use to throw bodies with an attached grenade? (not trepang2 inspired at alllllll lol) Default = MIDDLE MOUSE BUTTOn")
	end)
end)
