-- Core.lua
-- Module registry & enable/disable settings for the utils bundled into Unusual WoW Utils.
--
-- Each module's files call `UWU:AddModuleChunk(key, fn)` instead of running at load time.
-- Once our SavedVariables are available (ADDON_LOADED), the chunks of every enabled module
-- are run in TOC order. Toggling a module takes effect after a UI reload.

local addonName, UWU = ...

UWU.modules = {}
UWU.moduleOrder = {}

-- Our category in Options > AddOns. Each loaded util with an options window (`configApp`) gets
-- a page under it, added by ShowAvailableModules in the same order as the /uwu settings page.
UWU.SETTINGS_CATEGORY = "Unusual WoW Utils"

-- WoW Forever runs the retail client & API with its own interface numbers (16000+), so it's told apart by those.
-- Its WOW_PROJECT_CAMELOT is checked too, in case a later build changes the numbering.
local INTERFACE_VERSION = select(4, GetBuildInfo())
UWU.IS_FOREVER = (INTERFACE_VERSION >= 16000 and INTERFACE_VERSION < 20000)
   or (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)

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

-- A `retailOnly` module needs something WoW Forever doesn't have, so there it never loads & is left out of
-- every list, as if it didn't exist. Fixed for the session, so it's safe to check before login.
function UWU:IsModuleSupported(key)
   return not (self.IS_FOREVER and self.modules[key].retailOnly)
end

-- A supported module can also have an `isAvailable` function, for things only known once the character has
-- logged in (e.g. its spells). Hidden while it returns false. Only check this after PLAYER_LOGIN.
function UWU:IsModuleAvailable(key)
   local mod = self.modules[key]
   return self:IsModuleSupported(key) and (not mod.isAvailable or mod.isAvailable())
end

-- supported module keys sorted alphabetically by title (independent of the load order)
function UWU:GetSortedModuleKeys()
   local sortedKeys = {}
   for _, key in ipairs(self.moduleOrder) do
      if self:IsModuleSupported(key) then
         table.insert(sortedKeys, key)
      end
   end
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
   desc = "Hides & restores UI elements (chat, minimap, quest tracker) and can switch your saved camera view when you enter & leave combat or mount & dismount.",
   slashCommands = { "/cim" },
   commandHelp = { -- listed by /uwu help
      { "/cim", "Open or close the options window" },
      { "/cim debug", "Toggle debug logging" },
   },
   configApp = "CombatInterfaceManager", -- its AceConfig app name, opened by the cog in /uwu
})

UWU:RegisterModule("Compass", {
   title = "Compass",
   desc = "A flight HUD that rotates to show the direction you're facing.",
   slashCommands = { "/compass" },
   commandHelp = {
      { "/compass", "Open or close the options window" },
      { "/compass toggle", "Show or hide the compass" },
      { "/compass show", "Show the compass" },
      { "/compass hide", "Hide the compass" },
      { "/compass reset", "Move the compass back to the center of the screen" },
   },
   configApp = "Compass",
})

UWU:RegisterModule("CooldownBarGlobal", {
   title = "Cooldown Bar Global",
   desc = "A customizable bar to visually track the global cooldown.",
   slashCommands = { "/cbg" },
   commandHelp = {
      { "/cbg", "Open or close the options window" },
      { "/cbg move", "Toggle 'Move' mode (keeps the bar visible so you can drag it)" },
   },
   configApp = "Cooldown Bar Global",
})

UWU:RegisterModule("MobileBankingTimer", {
   title = "Mobile Banking Timer",
   desc = "A countdown of how long your Mobile Banking guild chest has left, shown from when the cast finishes.",
   slashCommands = { "/mbt" },
   commandHelp = {
      { "/mbt", "Open or close the options window" },
      { "/mbt move", "Toggle the preview (keeps the timer visible so you can drag it)" },
      { "/mbt test", "Run the timer for 10 seconds" },
      { "/mbt reset", "Move the timer back to its default spot" },
   },
   configApp = "MobileBankingTimer",
   -- it's unknown whether WoW Forever has the Mobile Banking guild perk, so there it's only shown to characters
   -- who know the spell
   isAvailable = function()
      return not UWU.IS_FOREVER or IsPlayerSpell(83958)
   end,
})

UWU:RegisterModule("ObviousStatuses", {
   title = "Obvious Statuses",
   desc = UWU.IS_FOREVER -- WoW Forever has no flying or Zidormi, so only the combat status is shown there
      and "Shows whether you're in combat, plus whether your target is in range of a spell."
      or "Shows your flight, combat and Zidormi phase (past or present) states as a stack of rectangles, plus whether your target is in range of a spell.",
   slashCommands = { "/os" },
   commandHelp = {
      { "/os", "Open or close the options window" },
      { "/os debug", "List this zone's map IDs and your buffs (for setting up the phase status)" },
   },
   configApp = "ObviousStatuses",
})

UWU:RegisterModule("QuestLogCounter", {
   title = "Quest Log Counter",
   desc = "Displays a draggable counter showing how many quests you have in your log.",
   slashCommands = { "/qlc" },
   commandHelp = {
      { "/qlc", "Open or close the options window" },
      { "/qlc show", "Show the counter" },
      { "/qlc hide", "Hide the counter" },
      { "/qlc reset", "Move the counter back to its location after dragging it" },
   },
   configApp = "Quest Log Counter",
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
BINDING_NAME_COMPASS_TOGGLE = "Compass: Toggle Visibility"

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
   retailOnly = true, -- WoW Forever has no Dungeon Finder queue (its bindings are left out of Bindings_Camelot.xml)
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
   configWord = "Keybinds", -- the button's hover tooltip
   openConfig = function()
      OpenKeyBindings(AUTO_DUNGEON_QUEUE_BINDING_PREFIX)
   end,
})

UWU:RegisterModule("ChatTabCycler", {
   title = "Chat Tab Cycler",
   desc = "Keybinds to cycle your chat tabs forward AND backward.",
   -- no options window, so its /uwu button opens the game's Key Bindings instead
   configIcon = KEY_BINDINGS_ICON,
   configWord = "Keybinds",
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

-- An Ace "Icon" button that, on hover, shows its option's `arg` (one word) as a small tooltip to
-- its right, vertically centered on the icon, instead of Ace's usual tooltip above it.
local ICON_BUTTON_WIDGET = "UWU-IconButton"

do
   local AceGUI = LibStub("AceGUI-3.0")

   local function IconButton_OnEnter(frame)
      local option = frame.obj:GetUserData("option")
      local word = option and option.arg

      if word then
         GameTooltip:SetOwner(frame, "ANCHOR_NONE")
         GameTooltip:ClearAllPoints()
         GameTooltip:SetPoint("LEFT", frame.obj.image, "RIGHT", 4, 0)
         GameTooltip:SetText(word, 1, 1, 1)
         GameTooltip:Show()
      end
   end

   AceGUI:RegisterWidgetType(ICON_BUTTON_WIDGET, function()
      local widget = AceGUI.WidgetRegistry["Icon"]() -- a regular Ace Icon button...
      widget.type = ICON_BUTTON_WIDGET -- ...pooled under our own type when released
      widget.frame:SetScript("OnEnter", IconButton_OnEnter)
      widget.frame:SetScript("OnLeave", GameTooltip_Hide)
      return widget
   end, 1)
end

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
         name = "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:0|t Reload the UI for your toggle changes to take effect.\n\n\n", -- extra spacing before the toggles
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

      -- only drawn after login, so it's safe to check here
      local function IsUnavailable()
         return not self:IsModuleAvailable(key)
      end

      args[key] = {
         type = "toggle",
         name = mod.title,
         hidden = IsUnavailable,
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
         dialogControl = ICON_BUTTON_WIDGET, -- shows `arg` as a one-word tooltip to its right
         arg = mod.configWord or "Options",
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
         hidden = function()
            return not (mod.configApp or mod.openConfig) or IsUnavailable()
         end,
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
   -- the utils' own option pages are added under this one (see UWU.SETTINGS_CATEGORY)
   LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, UWU.SETTINGS_CATEGORY)
end

-- Once a loaded util is available (see IsModuleAvailable), this adds its page under our category
-- in Options > AddOns, if it has an options window, and runs its `OnAvailable` (set by the util).
-- The pages are added in the /uwu page's order, since the game lists them in the order they're
-- added. A util may register its options table later (e.g. in its Ace OnInitialize); Ace only
-- needs it once the page is shown. Runs at login & whenever spells change, so a util that only
-- becomes available later (e.g. a perk being learned) shows up then, at the end of the list.
-- A page can't be removed again, so one that stops being available keeps its page until a reload.
function UWU:ShowAvailableModules()
   for _, key in ipairs(self:GetSortedModuleKeys()) do
      local mod = self.modules[key]

      if mod.status == "loaded" and not mod.shown and self:IsModuleAvailable(key) then
         mod.shown = true

         if mod.configApp then
            LibStub("AceConfigDialog-3.0"):AddToBlizOptions(mod.configApp, mod.title, UWU.SETTINGS_CATEGORY)
         end

         if mod.OnAvailable then
            xpcall(mod.OnAvailable, geterrorhandler())
         end
      end
   end
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

      if self:IsModuleAvailable(key) then
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

-- Windows that can't be resized, however they're opened (slash command, /uwu cog, etc.).
-- Ace turns resizing back on whenever it reuses one of these pooled windows for anything else.
local FIXED_SIZE_WINDOWS = {
   [addonName] = true, -- the /uwu settings window
   CombatInterfaceManager = true, -- /cim
   Compass = true, -- /compass
   MobileBankingTimer = true, -- /mbt
   ["Quest Log Counter"] = true, -- /qlc
}

hooksecurefunc(LibStub("AceConfigDialog-3.0"), "Open", function(dialog, appName, container)
   local widget = not container and FIXED_SIZE_WINDOWS[appName] and dialog.OpenFrames[appName]
   if widget then
      widget:EnableResize(false)
   end
end)

--## ==========================================================================
--## START UP
--## ==========================================================================
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, loadedAddonName)
   -- the character's spells are known from login on, so each util's availability can be checked
   if event == "PLAYER_LOGIN" then
      self:UnregisterEvent("PLAYER_LOGIN")
      self:RegisterEvent("SPELLS_CHANGED")
      UWU:ShowAvailableModules()
      return
   elseif event == "SPELLS_CHANGED" then
      UWU:ShowAvailableModules()
      return
   end

   if loadedAddonName ~= addonName then
      return
   end

   self:UnregisterEvent("ADDON_LOADED")
   self:RegisterEvent("PLAYER_LOGIN")

   UnusualWowUtilsDB = UnusualWowUtilsDB or {}
   UnusualWowUtilsDB.modules = UnusualWowUtilsDB.modules or {}
   UWU.db = UnusualWowUtilsDB

   -- printed before the modules load, so their own startup lines show as sub-items under it
   Print("Loaded! Type |cFFbada55/uwu help|r for more info.")

   UWU:RegisterSettings() -- its module statuses are only read when the window is drawn

   for _, key in ipairs(UWU.moduleOrder) do
      if UWU:IsModuleSupported(key) then
         UWU:LoadModule(key)
      end
   end
   -- the running utils get their settings pages at login (ShowAvailableModules)
end)
