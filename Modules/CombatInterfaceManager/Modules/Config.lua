-- Wrapped as an Unusual WoW Utils module: this only runs when "CombatInterfaceManager" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("CombatInterfaceManager", function()
   --## ==========================================================================
   --## ALL REQUIRED IMPORTS
   --## ==========================================================================
   -- Libs / Packages
   local CombatInterfaceManager = LibStub("AceAddon-3.0"):GetAddon("CombatInterfaceManager")

   --## ===============================================================================================
   --## INTERNAL VARS & SET UP
   --## ===============================================================================================
   local Config = CombatInterfaceManager:NewModule("Config")

   -- 0 = leave the camera alone, 1-5 = the "Set View n" keybindings
   local cameraViewChoices = { [0] = "None", "Set View 1", "Set View 2", "Set View 3", "Set View 4", "Set View 5" }
   local cameraViewSorting = { 0, 1, 2, 3, 4, 5 }

   --## ==========================================================================
   --## DEFINING THE MAIN OPTIONS FRAME
   --## ==========================================================================
   -- `cim` is a passed in reference of CombatInterfaceManager's `self`
   function Config:Init(cim)
      LibStub("AceConfig-3.0"):RegisterOptionsTable(
         "CombatInterfaceManager",
         self:GetBlizzOptionsFrame(cim)
      )
      -- the smallest an Ace window can be; fits the labels, 9 toggles & 4 dropdowns (resizing is turned off in Core.lua)
      LibStub("AceConfigDialog-3.0"):SetDefaultSize("CombatInterfaceManager", 400, 485)
      -- its page under Unusual WoW Utils in Options > AddOns is added by Core.lua (see ShowAvailableModules)
   end

   -- `cim` that's passed in is a reference to CombatInterfaceManager's `self`
   function Config:GetBlizzOptionsFrame(cim)
      local db = cim.db.profile

      -- a single page of "hide in combat" toggles (no tabs)
      return {
         name = "UwU: Combat Interface Manager",
         type = "group",
         args = {
            intro = {
               name = "Hide these in combat:",
               order = 100,
               type = "description",
            },
            hideChat = {
               desc = "",
               get = function()
                  return cim.utils:GetDbValue("isHiding.chatFrame")
               end,
               name = "Chat",
               order = 101,
               set = function(info, value)
                  cim.utils:SetDbTableItem("isHiding", "chatFrame", value)
               end,
               type = "toggle",
            },
            hideMinimap = {
               desc = "",
               get = function()
                  return cim.utils:GetDbValue("isHiding.minimap")
               end,
               name = "Minimap",
               order = 102,
               set = function(info, value)
                  cim.utils:SetDbTableItem("isHiding", "minimap", value)
               end,
               type = "toggle",
            },
            hideObjectives = {
               desc = "",
               get = function()
                  return cim.utils:GetDbValue("isHiding.objectiveTracker")
               end,
               name = "Quest Log",
               order = 103,
               set = function(info, value)
                  cim.utils:SetDbTableItem("isHiding", "objectiveTracker", value)
               end,
               type = "toggle",
            },
            hideZoneMap = {
               desc = "The Zone Map (Shift+M). It's only shown again after combat if it was open before.",
               get = function()
                  return cim.utils:GetDbValue("isHiding.zoneMap")
               end,
               name = "Zone Map",
               order = 104,
               set = function(info, value)
                  cim.utils:SetDbTableItem("isHiding", "zoneMap", value)
               end,
               type = "toggle",
            },
            cameraIntro = {
               name = "Switch camera view in combat:",
               order = 200,
               type = "description",
            },
            cameraViewOnEnter = {
               desc = "The saved camera view to switch to when combat starts. Save views with the Save View keybindings; a view that was never saved does nothing.",
               get = function()
                  return cim.utils:GetDbValue("cameraView.onEnterCombat")
               end,
               name = "Entering",
               order = 201,
               set = function(info, value)
                  cim.utils:SetDbTableItem("cameraView", "onEnterCombat", value)
               end,
               sorting = cameraViewSorting,
               type = "select",
               values = cameraViewChoices,
            },
            cameraViewOnLeave = {
               desc = "The saved camera view to switch to when combat ends.",
               get = function()
                  return cim.utils:GetDbValue("cameraView.onLeaveCombat")
               end,
               name = "Leaving",
               order = 202,
               set = function(info, value)
                  cim.utils:SetDbTableItem("cameraView", "onLeaveCombat", value)
               end,
               sorting = cameraViewSorting,
               type = "select",
               values = cameraViewChoices,
            },
            cameraMountIntro = {
               name = "Switch camera view when riding:",
               order = 300,
               type = "description",
            },
            cameraViewOnMount = {
               desc = "The saved camera view to switch to when you mount. Ignored during combat.",
               get = function()
                  return cim.utils:GetDbValue("cameraView.onMount")
               end,
               name = "Mounted",
               order = 301,
               set = function(info, value)
                  cim.utils:SetDbTableItem("cameraView", "onMount", value)
               end,
               sorting = cameraViewSorting,
               type = "select",
               values = cameraViewChoices,
            },
            cameraViewOnDismount = {
               desc = "The saved camera view to switch to when you dismount. Ignored during combat.",
               get = function()
                  return cim.utils:GetDbValue("cameraView.onDismount")
               end,
               name = "Unmounted",
               order = 302,
               set = function(info, value)
                  cim.utils:SetDbTableItem("cameraView", "onDismount", value)
               end,
               sorting = cameraViewSorting,
               type = "select",
               values = cameraViewChoices,
            },
            cameraDisableIntro = {
               name = "Leave the camera alone in:",
               order = 400,
               type = "description",
            },
            cameraDisableInArenas = {
               desc = "None of the views above are switched to in arenas. Hiding in combat still works.",
               get = function()
                  return cim.utils:GetDbValue("cameraView.disableInArenas")
               end,
               name = "Arenas",
               order = 401,
               set = function(info, value)
                  cim.utils:SetDbTableItem("cameraView", "disableInArenas", value)
               end,
               type = "toggle",
            },
            cameraDisableInBattlegrounds = {
               desc = "None of the views above are switched to in battlegrounds. Hiding in combat still works.",
               get = function()
                  return cim.utils:GetDbValue("cameraView.disableInBattlegrounds")
               end,
               name = "Battlegrounds",
               order = 402,
               set = function(info, value)
                  cim.utils:SetDbTableItem("cameraView", "disableInBattlegrounds", value)
               end,
               type = "toggle",
            },
            cameraDisableInDelves = {
               desc = "None of the views above are switched to in delves. Hiding in combat still works.",
               get = function()
                  return cim.utils:GetDbValue("cameraView.disableInDelves")
               end,
               -- WoW Forever has no delves
               hidden = UWU.IS_FOREVER,
               name = "Delves",
               order = 403,
               set = function(info, value)
                  cim.utils:SetDbTableItem("cameraView", "disableInDelves", value)
               end,
               type = "toggle",
            },
            cameraDisableInDungeons = {
               desc = "None of the views above are switched to in dungeons. Hiding in combat still works.",
               get = function()
                  return cim.utils:GetDbValue("cameraView.disableInDungeons")
               end,
               name = "Dungeons",
               order = 404,
               set = function(info, value)
                  cim.utils:SetDbTableItem("cameraView", "disableInDungeons", value)
               end,
               type = "toggle",
            },
            cameraDisableInRaids = {
               desc = "None of the views above are switched to in raids. Hiding in combat still works.",
               get = function()
                  return cim.utils:GetDbValue("cameraView.disableInRaids")
               end,
               name = "Raids",
               order = 405,
               set = function(info, value)
                  cim.utils:SetDbTableItem("cameraView", "disableInRaids", value)
               end,
               type = "toggle",
            },
         },
      }
   end
end)
