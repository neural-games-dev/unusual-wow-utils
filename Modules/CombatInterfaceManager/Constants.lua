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
   local chalk = CombatInterfaceManager:GetModule("Chalk")

   --## ==========================================================================
   --## DEFINING THE GLOBAL CONSTANTS TABLE TO BE USED THROUGHOUT THE ADDON
   --## ==========================================================================
   -- TODO **[G]** :: Can/should I attach this as part of the main addon/self as a property?
   CIM_Constants = {
      addOnName = chalk:ace("Combat Interface Manager"),
      addOnNameQuoted = chalk:ace('"Combat Interface Manager"'),
      slashCommand = "|cFFbada55/cim|r",
      slashCommandQuoted = '|cFFbada55"/cim"|r',
   }
end)
