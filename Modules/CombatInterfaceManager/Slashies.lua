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

      -- `/cim` by itself opens/closes the options window (the command list lives in `/uwu help`)
      if cmd == "" then
         self.utils:HandleConfigOptionsDisplay()
         return
      end

      if cmd == "debug" then
         local debugValue = not (self.db.profile.debugEnabled == true)
         local debugValueDisplay = string.upper(tostring(debugValue))

         self.utils:SetDbValue("debugEnabled", debugValue)
         self.logger:Print("Debug logging is now: " .. self.chalk:debug(debugValueDisplay))
         return
      end

      self.logger:Print('"' .. cmd .. '" is an unknown command.')
   end
end)
