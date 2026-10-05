-- Wrapped as an Unusual WoW Utils module: this only runs when "QuestLogCounter" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("QuestLogCounter", function()
   -- NOTE :: see Lua `sndbx` script in game for more methods/ideas
   --
   -- Quest Log Counter Addon
   local addonName = "QuestLogCounter"

   -- Create the main frame
   local frame = CreateFrame("Frame", addonName .. "Frame", UIParent, "BackdropTemplate")
   frame:SetSize(160, 40) -- Initial size, will be updated dynamically

   -- Preset positions around the quest tracker, picked in the settings window (/qlc).
   -- Anchored to the tracker itself, so the counter follows the tracker if that's moved in Edit Mode.
   local DEFAULT_LOCATION = "left"
   local LOCATIONS = {
      -- counter's bottom-left on the tracker's top-left (shifted left)
      top = {
         point = "BOTTOMLEFT",
         relativePoint = "TOPLEFT",
         x = -24,
         y = 0,
         label = "Top",
      },
      -- counter's top-left on the tracker's top-right
      right = {
         point = "TOPLEFT",
         relativePoint = "TOPRIGHT",
         x = 0,
         y = 0,
         label = "Right",
      },
      -- counter's top-left on the tracker's bottom-left (shifted left)
      bot = {
         point = "TOPLEFT",
         relativePoint = "BOTTOMLEFT",
         x = -24,
         y = 0,
         label = "Bottom",
      },
      -- counter's top-right on the tracker's top-left (with a gap)
      left = {
         point = "TOPRIGHT",
         relativePoint = "TOPLEFT",
         x = -24,
         y = 0,
         label = "Left",
      },
   }
   -- the dropdown's order, clockwise (LOCATIONS' own order is lost, since Lua tables don't keep key order)
   local LOCATION_ORDER = { "top", "right", "bot", "left" }

   -- the chosen location is saved in UwU's settings so it survives a reload
   UWU.db.questLogCounter = UWU.db.questLogCounter or { hidden = false }
   local qlcDB = UWU.db.questLogCounter

   if not LOCATIONS[qlcDB.location] then
      qlcDB.location = DEFAULT_LOCATION
   end

   local function SetPresetPosition()
      local preset = LOCATIONS[qlcDB.location]
      frame:ClearAllPoints()

      if ObjectiveTrackerFrame then
         frame:SetPoint(preset.point, ObjectiveTrackerFrame, preset.relativePoint, preset.x, preset.y)
      else
         frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
      end
   end

   local function IsAtPresetPosition()
      local preset = LOCATIONS[qlcDB.location]
      local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
      return frame:GetNumPoints() == 1
         and point == preset.point
         and relativeTo == ObjectiveTrackerFrame
         and relativePoint == preset.relativePoint
         and math.abs(x - preset.x) < 0.5
         and math.abs(y - preset.y) < 0.5
   end

   SetPresetPosition()
   frame:SetMovable(true)
   frame:SetClampedToScreen(true) -- can't be dragged (or docked) off the edge of the screen
   frame:EnableMouse(true)
   frame:RegisterForDrag("LeftButton")
   -- locked by default; hold Shift while left-click dragging to move it
   frame:SetScript("OnDragStart", function(self)
      if IsShiftKeyDown() then
         self:StartMoving()
         self:SetUserPlaced(true) -- the game remembers a dragged position across reloads
      end
   end)
   frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

   -- Tooltip sits on top of the frame (its bottom-left corner on the frame's top-left corner)
   frame:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_NONE")
      GameTooltip:ClearAllPoints()
      GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT")
      GameTooltip:SetText("Quest Log Counter")
      GameTooltip:AddLine("shift+left-mouse to drag", 1, 1, 1)
      GameTooltip:Show()
   end)
   frame:SetScript("OnLeave", GameTooltip_Hide)

   -- Backdrop styles, picked on the Style tab. A border sets how far in the background starts
   -- (its insets); a background sets its own tiling & tint (white = the texture's own colors).
   local DEFAULT_BORDER = "goldDialog"
   local BORDERS = {
      goldDialog = {
         label = "Dialog (Gold)",
         edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
         edgeSize = 32,
         insets = { left = 11, right = 12, top = 12, bottom = 11 },
      },
      dialog = {
         label = "Dialog",
         edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
         edgeSize = 32,
         insets = { left = 11, right = 12, top = 12, bottom = 11 },
      },
      tooltip = {
         label = "Tooltip",
         edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
         edgeSize = 16,
         insets = { left = 5, right = 5, top = 5, bottom = 5 },
      },
      toast = {
         label = "Toast",
         edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border",
         edgeSize = 12,
         insets = { left = 5, right = 5, top = 5, bottom = 5 },
      },
      slider = {
         label = "Slider",
         edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
         edgeSize = 8,
         insets = { left = 3, right = 3, top = 6, bottom = 6 },
      },
      achievementWood = {
         label = "Achievement (Wood)",
         edgeFile = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder",
         edgeSize = 32, -- the game draws it at 64, which is too big for the counter
         insets = { left = 8, right = 8, top = 8, bottom = 8 },
      },
      none = {
         label = "None",
         insets = { left = 0, right = 0, top = 0, bottom = 0 },
      },
   }
   local BORDER_ORDER = { "goldDialog", "dialog", "tooltip", "toast", "slider", "achievementWood", "none" }

   local DEFAULT_BACKGROUND = "dark"
   local BACKGROUNDS = {
      dark = {
         label = "Dark",
         bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
         tileSize = 32,
         color = { 0, 0, 0, 0.8 },
      },
      dialog = {
         label = "Dialog",
         bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
         tileSize = 32,
      },
      dialogDark = {
         label = "Dialog (Dark)",
         bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
         tileSize = 32,
      },
      goldDialog = {
         label = "Dialog (Gold)",
         bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
         tileSize = 32,
      },
      tooltip = {
         label = "Tooltip",
         bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
         tileSize = 16,
         color = { 0.09, 0.09, 0.19, 1 }, -- the game's default tooltip tint
      },
      marble = {
         label = "Marble",
         bgFile = "Interface\\FrameGeneral\\UI-Background-Marble",
         tileSize = 64,
      },
      rock = {
         label = "Rock",
         bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
         tileSize = 64,
      },
      parchment = {
         label = "Parchment",
         bgFile = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
         -- a single image, so it's stretched rather than tiled
      },
      none = {
         label = "None",
      },
   }
   local BACKGROUND_ORDER =
      { "dark", "dialog", "dialogDark", "goldDialog", "tooltip", "marble", "rock", "parchment", "none" }

   -- outlines for the count text, as font flags
   local DEFAULT_OUTLINE = "none"
   local OUTLINES = {
      thin = { label = "Thin", flags = "OUTLINE" },
      thick = { label = "Thick", flags = "THICKOUTLINE" },
      none = { label = "None", flags = "" },
   }
   local OUTLINE_ORDER = { "thin", "thick", "none" }

   if not BORDERS[qlcDB.border] then
      qlcDB.border = DEFAULT_BORDER
   end

   if not OUTLINES[qlcDB.outline] then
      qlcDB.outline = DEFAULT_OUTLINE
   end

   if not BACKGROUNDS[qlcDB.background] then
      qlcDB.background = DEFAULT_BACKGROUND
   end

   -- Create text display
   local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
   text:SetPoint("CENTER", frame, "CENTER", 0, 0)
   text:SetTextColor(1, 1, 1, 1)
   local fontFile, fontSize = text:GetFont() -- GameFontNormalLarge's, kept when the outline changes

   local function ApplyStyle()
      local border = BORDERS[qlcDB.border]
      local background = BACKGROUNDS[qlcDB.background]

      frame:SetBackdrop({
         bgFile = background.bgFile,
         edgeFile = border.edgeFile,
         tile = background.tileSize ~= nil,
         tileSize = background.tileSize,
         edgeSize = border.edgeSize,
         insets = border.insets,
      })
      frame:SetBackdropColor(unpack(background.color or { 1, 1, 1, 1 }))
      text:SetFont(fontFile, fontSize, OUTLINES[qlcDB.outline].flags)
   end

   ApplyStyle()

   -- Function to update the quest count
   local function UpdateQuestCount()
      -- Count only real quests: log entries also include zone/category headers,
      -- hidden quests, and world quests/bonus objectives that don't use a quest slot
      local numQuests = 0
      for i = 1, C_QuestLog.GetNumQuestLogEntries() do
         local info = C_QuestLog.GetInfo(i)
         if info and not info.isHeader and not info.isHidden and not info.isTask and not info.isBounty then
            numQuests = numQuests + 1
         end
      end

      local maxQuests = C_QuestLog.GetMaxNumQuestsCanAccept()

      -- Determine color based on capacity
      local colorCode
      if numQuests >= maxQuests then
         colorCode = "|cFFFF0000" -- Red when full
      elseif numQuests >= maxQuests * 0.7 then
         colorCode = "|cFFFFFF00" -- Yellow when getting close
      else
         colorCode = "|cFF00FF00" -- Green when normal
      end

      text:SetText(colorCode .. numQuests .. "|r / " .. maxQuests)
      text:SetTextColor(1, 1, 1, 1) -- Set base color to white
   end

   -- True when Combat Interface Manager is running & set to hide the quest log in combat.
   -- Checked when combat starts, so toggling that CIM option takes effect on the next fight.
   local function IsCIMHidingQuestLog()
      local cim = LibStub("AceAddon-3.0"):GetAddon("CombatInterfaceManager", true) -- nil if CIM isn't loaded
      local isHiding = cim and cim.db and cim.db.profile.isHiding
      return isHiding and isHiding.objectiveTracker == true
   end

   local hiddenForCombat = false

   -- Register events
   frame:RegisterEvent("QUEST_ACCEPTED")
   frame:RegisterEvent("QUEST_REMOVED")
   frame:RegisterEvent("QUEST_LOG_UPDATE")
   frame:RegisterEvent("PLAYER_LOGIN")
   frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- entering combat
   frame:RegisterEvent("PLAYER_REGEN_ENABLED") -- leaving combat

   -- Event handler (a hidden frame still gets events, so the count keeps updating in combat)
   frame:SetScript("OnEvent", function(self, event, ...)
      if event == "PLAYER_REGEN_DISABLED" then
         -- hide along with the quest log when CIM hides it (if it's showing at all)
         if IsCIMHidingQuestLog() and self:IsShown() then
            hiddenForCombat = true
            self:Hide()
         end
      elseif event == "PLAYER_REGEN_ENABLED" then
         if hiddenForCombat then
            hiddenForCombat = false
            self:Show()
         end
      else
         UpdateQuestCount()
      end
   end)

   -- `/qlc hide` & `/qlc show` -- the choice is saved in UwU's settings so it survives a reload
   if qlcDB.hidden then
      frame:Hide()
   end

   local function SetFrameShown(shown)
      -- CIM's combat auto-hide owns the frame's visibility while it's on
      if IsCIMHidingQuestLog() then
         print(
            "|cFFffd100Quest Log Counter:|r /qlc "
               .. (shown and "show" or "hide")
               .. " has no effect while Combat Interface Manager is hiding the quest log in combat."
         )
         return
      end

      qlcDB.hidden = not shown
      frame:SetShown(shown)
   end

   local function MoveToPreset()
      frame:StopMovingOrSizing()
      frame:SetUserPlaced(false) -- forget any dragged position so the preset sticks after a reload
      SetPresetPosition()
   end

   -- `/qlc reset` -- back to the selected preset position (silent if already there)
   local function ResetPosition()
      if IsAtPresetPosition() then
         return
      end

      MoveToPreset()
      print("|cFF00FF00Quest Log Counter:|r Moved back to its location: " .. LOCATIONS[qlcDB.location].label .. ".")
   end

   --## ==========================================================================
   --## SETTINGS WINDOW (/qlc, the /uwu cog & Options > AddOns)
   --## ==========================================================================
   local APP_NAME = "Quest Log Counter"

   -- a dropdown's values ({ key = label }) from a table of presets
   local function LabelsOf(presets)
      local labels = {}
      for key, preset in pairs(presets) do
         labels[key] = preset.label
      end
      return labels
   end

   local options = {
      type = "group",
      name = "UwU: Quest Log Counter",
      childGroups = "tab",
      args = {
         positioning = {
            name = "Positioning",
            type = "group",
            order = 1,
            args = {
               location = {
                  order = 1,
                  name = "Location",
                  desc = "Where the counter docks on the quest log. It follows the quest log when that's moved in Edit Mode.",
                  type = "select",
                  values = function()
                     return LabelsOf(LOCATIONS)
                  end,
                  sorting = LOCATION_ORDER,
                  set = function(_, value)
                     -- picking a location (even the current one) also undoes a drag
                     qlcDB.location = value
                     MoveToPreset()
                  end,
                  get = function()
                     return qlcDB.location
                  end,
               },
               -- line break, so the button sits below the dropdown
               locationBreak = {
                  order = 2,
                  name = "",
                  type = "description",
                  width = "full",
               },
               reset = {
                  order = 3,
                  name = "Reset Position",
                  desc = "Move the counter back to its location after Shift + dragging it.",
                  type = "execute",
                  func = ResetPosition,
               },
               dragNote = {
                  order = 4,
                  name = "\nYou can also hold Shift and drag the counter with the left mouse button to move it anywhere.\n",
                  type = "description",
               },
            },
         },
         style = {
            name = "Style",
            type = "group",
            order = 2,
            args = {
               border = {
                  order = 1,
                  name = "Border",
                  type = "select",
                  values = function()
                     return LabelsOf(BORDERS)
                  end,
                  sorting = BORDER_ORDER,
                  set = function(_, value)
                     qlcDB.border = value
                     ApplyStyle()
                  end,
                  get = function()
                     return qlcDB.border
                  end,
               },
               -- line breaks, so each dropdown sits on its own row
               borderBreak = {
                  order = 2,
                  name = "",
                  type = "description",
                  width = "full",
               },
               background = {
                  order = 3,
                  name = "Background",
                  type = "select",
                  values = function()
                     return LabelsOf(BACKGROUNDS)
                  end,
                  sorting = BACKGROUND_ORDER,
                  set = function(_, value)
                     qlcDB.background = value
                     ApplyStyle()
                  end,
                  get = function()
                     return qlcDB.background
                  end,
               },
               backgroundBreak = {
                  order = 4,
                  name = "",
                  type = "description",
                  width = "full",
               },
               outline = {
                  order = 5,
                  name = "Outline",
                  desc = "An outline around the count text.",
                  type = "select",
                  values = function()
                     return LabelsOf(OUTLINES)
                  end,
                  sorting = OUTLINE_ORDER,
                  set = function(_, value)
                     qlcDB.outline = value
                     ApplyStyle()
                  end,
                  get = function()
                     return qlcDB.outline
                  end,
               },
            },
         },
      },
   }

   LibStub("AceConfig-3.0"):RegisterOptionsTable(APP_NAME, options)
   local aceConfigDialog = LibStub("AceConfigDialog-3.0")
   -- one dropdown wide; tall enough for the Style tab's 3 rows of dropdowns
   aceConfigDialog:SetDefaultSize(APP_NAME, 280, 280)
   -- its page under Unusual WoW Utils in Options > AddOns (Positioning & Style as tabs)
   -- is added by Core.lua (see AddSettingsPages)

   SLASH_QUESTLOGCOUNTER1 = "/qlc"
   SlashCmdList["QUESTLOGCOUNTER"] = function(msg)
      local command = string.lower(strtrim(msg or ""))

      if command == "" then
         if aceConfigDialog.OpenFrames[APP_NAME] then
            aceConfigDialog:Close(APP_NAME)
         else
            aceConfigDialog:Open(APP_NAME)
         end
      elseif command == "show" then
         SetFrameShown(true)
      elseif command == "hide" then
         SetFrameShown(false)
      elseif command == "reset" then
         ResetPosition()
      else
         print("|cFF00FF00Quest Log Counter:|r Use /qlc to open the options, or /qlc show, /qlc hide, or /qlc reset.")
      end
   end

   -- Initial update
   UpdateQuestCount()

   -- a sub-item under UwU's own "Loaded!" message, which prints just before the modules load
   print("  - |cFF00FF00Quest Log Counter|r loaded. Shift + drag the frame to move it.")
end)
