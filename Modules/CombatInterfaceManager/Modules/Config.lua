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

   --## ==========================================================================
   --## DEFINING THE MAIN OPTIONS FRAME
   --## ==========================================================================
   -- `cim` is a passed in reference of CombatInterfaceManager's `self`
   function Config:Init(cim)
      LibStub("AceConfig-3.0"):RegisterOptionsTable(
         "CombatInterfaceManager",
         self:GetBlizzOptionsFrame(cim)
      )
      -- the smallest an Ace window can be; fits the label & 4 toggles (resizing is turned off in Core.lua)
      LibStub("AceConfigDialog-3.0"):SetDefaultSize("CombatInterfaceManager", 400, 200)
      -- its page under Unusual WoW Utils in Options > AddOns is added by Core.lua (see AddSettingsPages)
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
         },
      }
   end
end)
