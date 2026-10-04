-- Core.lua
-- Module registry & enable/disable settings for the utils bundled into Unusual WoW Utils.
--
-- Each module's files call `UWU:AddModuleChunk(key, fn)` instead of running at load time.
-- Once our SavedVariables are available (ADDON_LOADED), the chunks of every enabled module
-- are run in TOC order. Toggling a module takes effect after a UI reload.

local addonName, UWU = ...

UWU.modules = {}
UWU.moduleOrder = {}

local function Print(msg)
   print("|cFF33ff99Unusual WoW Utils:|r " .. msg)
end

-- `key` is also the name of the standalone addon the module originally came from
function UWU:RegisterModule(key, info)
   info.key = key
   info.chunks = {}
   info.status = "pending"
   self.modules[key] = info
   table.insert(self.moduleOrder, key)
end

function UWU:AddModuleChunk(key, chunk)
   table.insert(self.modules[key].chunks, chunk)
end

function UWU:IsModuleEnabled(key)
   return self.db.modules[key] ~= false -- every module is enabled by default
end

function UWU:LoadModule(key)
   local mod = self.modules[key]

   if not self:IsModuleEnabled(key) then
      mod.status = "disabled"
      return
   end

   -- running both copies would clash (same Ace addon names, globals & frames)
   if C_AddOns.IsAddOnLoaded(key) then
      mod.status = "standalone"
      Print(mod.title .. ' was skipped because the standalone "' .. key .. '" addon is loaded. Disable one of them.')
      return
   end

   for _, chunk in ipairs(mod.chunks) do
      if not xpcall(chunk, geterrorhandler()) then
         mod.status = "error"
         return
      end
   end

   mod.status = "loaded"
end

--## ==========================================================================
--## MODULES (keep these in the same order as the TOC)
--## ==========================================================================
UWU:RegisterModule("CombatInterfaceManager", {
   title = "Combat Interface Manager",
   version = "v0.1.2",
   desc = "Hides & restores UI elements (chat, minimap, quest tracker) when you enter & leave combat. Options: /cim",
})

UWU:RegisterModule("CooldownBarGlobal", {
   title = "Cooldown Bar Global",
   version = "2.0",
   desc = "A customizable bar to visually track the global cooldown. Options: /cdgbar",
})

UWU:RegisterModule("QuestLogCounter", {
   title = "Quest Log Counter",
   version = "1.0.1",
   desc = "Displays a draggable counter showing how many quests you have in your log.",
})

UWU:RegisterModule("AutoDungeonQueue", {
   title = "Auto Dungeon Queue",
   version = "1.0",
   desc = "Joins the dungeon queue with your last selected roles via a keybind or /adq.",
})

UWU:RegisterModule("ChatTabCycler", {
   title = "Chat Tab Cycler",
   version = "1.0",
   desc = "Keybinds to cycle your chat tabs forward AND backward.",
})

--## ==========================================================================
--## SETTINGS WINDOW & SLASH COMMAND
--## ==========================================================================
local STATUS_TEXT = {
   loaded = "|cFF00FF00Running|r",
   disabled = "|cFFb0b0b0Disabled|r",
   standalone = "|cFFfa8200Skipped (standalone addon is loaded)|r",
   error = "|cFFff0000Failed to load (see Lua errors)|r",
   pending = "|cFFb0b0b0Not loaded|r",
}

function UWU:RegisterSettings()
   local args = {
      intro = {
         type = "description",
         name = "Turn individual utils on or off. Changes take effect after you reload your UI.\n",
         order = 1,
      },
      reload = {
         type = "execute",
         name = "Reload UI",
         func = ReloadUI,
         order = 1000,
      },
   }

   for i, key in ipairs(self.moduleOrder) do
      local mod = self.modules[key]

      args[key] = {
         type = "toggle",
         name = mod.title,
         desc = function()
            return mod.desc .. "\n\nCurrent session: " .. STATUS_TEXT[mod.status]
         end,
         get = function()
            return self:IsModuleEnabled(key)
         end,
         set = function(_, value)
            self.db.modules[key] = value
            Print(mod.title .. " will be " .. (value and "enabled" or "disabled") .. " after you /reload.")
         end,
         width = "full",
         order = 10 + i,
      }
   end

   LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, {
      type = "group",
      name = "Unusual WoW Utils",
      args = args,
   })
   LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "Unusual WoW Utils")
end

SLASH_UNUSUALWOWUTILS1 = "/uwu"
SlashCmdList["UNUSUALWOWUTILS"] = function()
   local dialog = LibStub("AceConfigDialog-3.0")

   if dialog.OpenFrames[addonName] then
      dialog:Close(addonName)
   else
      dialog:Open(addonName)
   end
end

--## ==========================================================================
--## START UP
--## ==========================================================================
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, loadedAddonName)
   if loadedAddonName ~= addonName then
      return
   end

   self:UnregisterEvent("ADDON_LOADED")

   UnusualWowUtilsDB = UnusualWowUtilsDB or {}
   UnusualWowUtilsDB.modules = UnusualWowUtilsDB.modules or {}
   UWU.db = UnusualWowUtilsDB

   for _, key in ipairs(UWU.moduleOrder) do
      UWU:LoadModule(key)
   end

   UWU:RegisterSettings()
end)
