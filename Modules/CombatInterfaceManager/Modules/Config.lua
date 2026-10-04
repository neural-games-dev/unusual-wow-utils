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
      -- Ace's default window (700x500) is mostly empty space for these few options
      LibStub("AceConfigDialog-3.0"):SetDefaultSize("CombatInterfaceManager", 410, 250)
      self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
         "CombatInterfaceManager",
         "Combat Interface Manager"
      )
   end

   -- `cim` that's passed in is a reference to CombatInterfaceManager's `self`
   function Config:GetBlizzOptionsFrame(cim)
      local db = cim.db.profile

      return {
         desc = "Select the UI elements you want to hide when you're in combat.",
         name = "UwU: Combat Interface Manager",
         type = "group",
         args = {
            uiElements = {
               desc = "",
               name = "Hide in Combat",
               order = 100,
               type = "group",
               args = {
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
            },
            chatOptions = {
               desc = "",
               name = "Chat",
               order = 200,
               type = "group",
               args = {
                  startupGreeting = {
                     desc = "This will hide/show the initial greeting in chat when the game starts or reloads.",
                     get = function()
                        return cim.utils:GetDbValue("showGreeting")
                     end,
                     name = "Show startup greeting in chat?",
                     order = 201,
                     set = function(info, value)
                        cim.utils:SetDbValue("showGreeting", value)
                     end,
                     type = "toggle",
                     width = "full",
                  },
                  slashCommandOutput = {
                     desc = "This will hide/show the chat output after triggering certain "
                        .. cim.chalk:badass("CIM")
                        .. " commands or actions.\n\n"
                        .. cim.chalk:blue("Think of this like INFO level logging."),
                     get = function()
                        return cim.utils:GetDbValue("showCommandOutput")
                     end,
                     name = "Show CIM command output?",
                     order = 202,
                     set = function(info, value)
                        cim.utils:SetDbValue("showCommandOutput", value)
                     end,
                     type = "toggle",
                     width = "full",
                  },
               },
            },
         },
      }
   end
end)
