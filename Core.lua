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

-- module keys sorted alphabetically by title (independent of the load order)
function UWU:GetSortedModuleKeys()
   local sortedKeys = CopyTable(self.moduleOrder)
   table.sort(sortedKeys, function(a, b)
      return self.modules[a].title < self.modules[b].title
   end)
   return sortedKeys
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
   desc = "Hides & restores UI elements (chat, minimap, quest tracker) when you enter & leave combat.",
   slashCommands = { "/cim" },
   commandHelp = { -- listed by /uwu help
      { "/cim", "List the CIM commands" },
      { "/cim options", "Open the options window" },
      { "/cim debug", "Toggle debug logging" },
   },
   configApp = "CombatInterfaceManager", -- its AceConfig app name, opened by the cog in /uwu
})

UWU:RegisterModule("CooldownBarGlobal", {
   title = "Cooldown Bar Global",
   desc = "A customizable bar to visually track the global cooldown.",
   slashCommands = { "/cbg" },
   commandHelp = {
      { "/cbg", "Open or close the options window" },
   },
   configApp = "Cooldown Bar Global",
})

UWU:RegisterModule("QuestLogCounter", {
   title = "Quest Log Counter",
   desc = "Displays a draggable counter showing how many quests you have in your log.",
})

-- Display names for the bindings in Bindings.xml. They're defined here, not in the modules, so
-- they show in Key Bindings even while a module is disabled. Each util's prefix doubles as the
-- Key Bindings search term for its /uwu key button.
BINDING_HEADER_UNUSUALWOWUTILS = "Unusual WoW Utils" -- the Key Bindings category for all of our bindings
local AUTO_DUNGEON_QUEUE_BINDING_PREFIX = "AutoDungeonQueue"
BINDING_NAME_AUTODUNGEONQUEUE_QUEUE = AUTO_DUNGEON_QUEUE_BINDING_PREFIX .. ": Join Queue"
BINDING_NAME_AUTODUNGEONQUEUE_LEAVE = AUTO_DUNGEON_QUEUE_BINDING_PREFIX .. ": Leave Queue"
BINDING_NAME_AUTODUNGEONQUEUE_CLEAR = AUTO_DUNGEON_QUEUE_BINDING_PREFIX .. ": Clear Saved Roles"
local CHAT_TAB_CYCLER_BINDING_PREFIX = "ChatTabCycler"
BINDING_NAME_CHATTABCYCLER_NEXT = CHAT_TAB_CYCLER_BINDING_PREFIX .. ": Go To Next"
BINDING_NAME_CHATTABCYCLER_PREV = CHAT_TAB_CYCLER_BINDING_PREFIX .. ": Go To Prev"

local KEY_BINDINGS_ICON = "Interface\\Icons\\INV_Misc_Key_03"

-- Opens the game's Key Bindings with `searchText` prefilled in the Settings search box.
-- Used by the /uwu key buttons, which never grey out since bindings exist even while a module is disabled.
local function OpenKeyBindings(searchText)
   LibStub("AceConfigDialog-3.0"):Close(addonName)
   Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)

   -- prefill the Settings search (next frame, once the panel has finished opening)
   C_Timer.After(0, function()
      local searchBox = SettingsPanel and SettingsPanel.SearchBox
      if not searchBox then
         return
      end

      searchBox:SetText(searchText)
      -- SetText reports a non-user change; run the handler as if it was typed
      local onTextChanged = searchBox:GetScript("OnTextChanged")
      if onTextChanged then
         onTextChanged(searchBox, true)
      end
   end)
end

UWU:RegisterModule("AutoDungeonQueue", {
   title = "Auto Dungeon Queue",
   desc = "Joins the dungeon queue with your last selected roles via a keybind or slash command.",
   slashCommands = { "/adq" },
   commandHelp = {
      { "/adq", "Open or close the Dungeon Finder" },
      { "/adq join", "Join the dungeon queue with your saved roles (opens the Dungeon Finder if none are saved)" },
      { "/adq leave", "Leave the dungeon queue" },
      { "/adq save <tank||healer||DPS>", "Save the given role(s)" },
      { "/adq save", "Save the roles ticked in the Dungeon Finder" },
      { "/adq roles", "Show your saved roles" },
      { "/adq clear", "Clear your saved roles" },
      { "/adq help", "List the ADQ commands" },
   },
   -- no options window, so its /uwu button opens the game's Key Bindings instead
   configIcon = KEY_BINDINGS_ICON,
   configDesc = "Open Key Bindings to set the Auto Dungeon Queue key",
   openConfig = function()
      OpenKeyBindings(AUTO_DUNGEON_QUEUE_BINDING_PREFIX)
   end,
})

UWU:RegisterModule("ChatTabCycler", {
   title = "Chat Tab Cycler",
   desc = "Keybinds to cycle your chat tabs forward AND backward.",
   -- no options window, so its /uwu button opens the game's Key Bindings instead
   configIcon = KEY_BINDINGS_ICON,
   configDesc = "Open Key Bindings to set the Chat Tab Cycler keys",
   openConfig = function()
      OpenKeyBindings(CHAT_TAB_CYCLER_BINDING_PREFIX)
   end,
})

--## ==========================================================================
--## SETTINGS WINDOW & SLASH COMMAND
--## ==========================================================================
local STATUS_TEXT = {
   loaded = "|cFF00FF00Running|r",
   disabled = "|cFFfd4a4aDisabled|r",
   standalone = "|cFFfa8200Skipped (standalone addon is loaded)|r",
   error = "|cFFff0000Failed to load (see Lua errors)|r",
   pending = "|cFFb0b0b0Not loaded|r",
}

function UWU:RegisterSettings()
   local args = {
      tagline = {
         type = "description",
         name = C_AddOns.GetAddOnMetadata(addonName, "Notes") .. "\n\n", -- the TOC's "Notes"
         fontSize = "medium",
         order = 0,
      },
      intro = {
         type = "description",
         name = "Toggle individual items on or off.\n\n",
         order = 1,
      },
      reloadNote = {
         type = "description",
         name = "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:0|t Toggle changes take effect after you reload your UI.\n\n\n", -- extra spacing before the toggles
         order = 2,
      },
      reloadSpacer = {
         type = "description",
         name = " ",
         order = 999,
      },
      reload = {
         type = "execute",
         name = "Reload UI",
         func = ReloadUI,
         order = 1000,
      },
   }

   for i, key in ipairs(self:GetSortedModuleKeys()) do
      local mod = self.modules[key]

      args[key] = {
         type = "toggle",
         name = mod.title,
         desc = function()
            local text = mod.desc .. "\n\nCurrent session: " .. STATUS_TEXT[mod.status]

            if mod.slashCommands then
               local label = #mod.slashCommands > 1 and "Slash commands: " or "Slash command: "
               text = text .. "\n" .. label .. "|cFFbada55" .. table.concat(mod.slashCommands, ", ") .. "|r"
            end

            return text
         end,
         get = function()
            return self:IsModuleEnabled(key)
         end,
         set = function(_, value)
            self.db.modules[key] = value
            Print(mod.title .. " will be " .. (value and "enabled" or "disabled") .. " after you /reload.")
         end,
         width = 2, -- leaves room for the cog on the same row
         order = 10 + i * 2,
      }

      -- button to the right of the toggle: a cog that opens the util's own options window,
      -- or a module-specific icon & action (`configIcon` / `openConfig`)
      args[key .. "Config"] = {
         type = "execute",
         name = "",
         desc = function()
            if mod.openConfig then
               return mod.configDesc
            elseif mod.status == "loaded" then
               return "Open " .. mod.title .. " options"
            end
            return "Enable " .. mod.title .. " and reload your UI to configure it."
         end,
         image = mod.configIcon or "Interface\\Buttons\\UI-OptionsButton",
         imageWidth = 16,
         imageHeight = 16,
         func = function()
            if mod.openConfig then
               mod.openConfig()
            else
               LibStub("AceConfigDialog-3.0"):Open(mod.configApp)
            end
         end,
         disabled = function()
            -- an AceConfig options window only exists once its module has loaded
            return mod.configApp and mod.status ~= "loaded"
         end,
         hidden = not (mod.configApp or mod.openConfig),
         width = 0.2,
         order = 10 + i * 2 + 1,
      }
   end

   LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, {
      type = "group",
      name = "Unusual WoW Utils",
      args = args,
   })
   LibStub("AceConfigDialog-3.0"):SetDefaultSize(addonName, 440, 420) -- Ace's default (700x500) is mostly empty space
   LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "Unusual WoW Utils")
end

local COMMAND_COLOR = "|cFFbada55"
local UTIL_TITLE_COLOR = "|cFF00ffff"

local function PrintCommand(command, description)
   print("  " .. COMMAND_COLOR .. command .. "|r - " .. description)
end

function UWU:PrintHelp()
   Print("Commands")
   PrintCommand("/uwu", "Open or close the settings window")
   PrintCommand("/uwu help", "List the commands for UwU and all of its utils")

   for _, key in ipairs(self:GetSortedModuleKeys()) do
      local mod = self.modules[key]
      local status = mod.status == "loaded" and "" or " (" .. STATUS_TEXT[mod.status] .. ")"

      print(UTIL_TITLE_COLOR .. mod.title .. "|r" .. status)

      if mod.commandHelp then
         for _, entry in ipairs(mod.commandHelp) do
            PrintCommand(entry[1], entry[2])
         end
      else
         print("  |cFFb0b0b0No slash commands (keybinds only)|r")
      end
   end
end

SLASH_UNUSUALWOWUTILS1 = "/uwu"
SlashCmdList["UNUSUALWOWUTILS"] = function(msg)
   local command = string.lower(strtrim(msg or ""))

   if command == "help" then
      UWU:PrintHelp()
      return
   elseif command ~= "" then
      Print('"' .. command .. '" is an unknown command. Type /uwu help for the list.')
      return
   end

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
