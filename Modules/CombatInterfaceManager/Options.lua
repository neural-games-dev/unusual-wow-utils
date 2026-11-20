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
         zoneMap = false,
      },
      -- which saved camera view (the "Set View n" keybindings, 1-5) to switch to; 0 means leave the camera alone
      cameraView = {
         onEnterCombat = 0,
         onLeaveCombat = 0,
         onMount = 0,
         onDismount = 0,
         -- leave the camera alone in these kinds of instance
         disableInArenas = false,
         disableInBattlegrounds = false,
         disableInDelves = false, -- Retail only (WoW Forever has no delves)
         disableInDungeons = false,
         disableInRaids = false,
      },
      isLoaded = {
         itemLock = nil,
         prat = nil,
      },
      playerInfo = {
         factionGroup = nil,
         name = "",
      },
   }
end)
