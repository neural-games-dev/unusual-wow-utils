-- Wrapped as an Unusual WoW Utils module: this only runs when "CombatInterfaceManager" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("CombatInterfaceManager", function()
   --## ==========================================================================
   --## DEFINING THE DEFAULT DB PROFILE OPTIONS TABLE
   --## ==========================================================================
   CIM_Defaults = {
      debugEnabled = false,
      enableVerboseLogging = false,
      isHiding = {
         chatFrame = false,
         minimap = false,
         objectiveTracker = false,
      },
      isLoaded = {
         itemLock = nil,
         prat = nil,
      },
      playerInfo = {
         factionGroup = nil,
         name = "",
      },
      showCommandOutput = false,
      showGreeting = true,
   }
end)
