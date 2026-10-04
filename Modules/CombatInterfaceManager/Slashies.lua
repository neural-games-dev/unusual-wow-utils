-- Wrapped as an Unusual WoW Utils module: this only runs when "CombatInterfaceManager" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("CombatInterfaceManager", function()
   --## ===============================================================================================
   --## ALL REQUIRED IMPORTS
   --## ===============================================================================================
   -- Libs / Packages
   local CombatInterfaceManager = LibStub("AceAddon-3.0"):GetAddon("CombatInterfaceManager")

   --## ===============================================================================================
   --## INTERNAL VARS & SET UP
   --## ===============================================================================================
   --## ===============================================================================================
   --## DEFINING ALL CUSTOM UTILS TO BE USED THROUGHOUT THE ADDON
   --## ===============================================================================================
   function CombatInterfaceManager:SlashCommandInfoConfig(command)
      local cmd = command:trim()

      -- Display the CombatInterfaceManager commands and notes
      if cmd == "" then
         self.logger:Print(
            self.chalk:cyan("----- COMMANDS -----")
               .. "\n"
               .. self.chalk:badass("/cim config (c)")
               .. " -- Shows the config window to customize this addon.\n"
               .. self.chalk:badass("/cim options (o)")
               .. ' -- This is an alias for "config".\n'
         )

         return
      end

      local isConfigOptionsCommand = cmd == "config" or cmd == "c" or cmd == "options" or cmd == "o"

      if isConfigOptionsCommand then
         self.utils:HandleConfigOptionsDisplay()
         return
      end

      local isDebugCommand = cmd == "debug" or cmd == "d"

      if isDebugCommand then
         local debugValue = not (self.db.profile.debugEnabled == true)
         local debugValueDisplay = string.upper(tostring(debugValue))

         if self.db.profile.showCommandOutput then
            self.logger:Print("Setting the debug value to: " .. self.chalk:debug(debugValueDisplay))
         end

         self.utils:SetDbValue("debugEnabled", debugValue)
         return
      end

      self.logger:Print('"' .. cmd .. '" is an unknown command.')
   end
end)
