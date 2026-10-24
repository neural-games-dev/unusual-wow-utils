-- Wrapped as an Unusual WoW Utils module: this only runs when "ObviousStatuses" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("ObviousStatuses", function()
   local addonName = "ObviousStatuses"

   -- Settings live in a profile of our own saved variables (ObviousStatusesDB), so they can be switched,
   -- copied & reset on the Profiles tab. `db` is always the current profile.
   local DEFAULT_STRATA = "MEDIUM"
   -- every frame strata that can be set, from furthest back to furthest forward
   local STRATA_ORDER = {
      "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP",
   }
   local STRATA = {
      BACKGROUND = "Background",
      LOW = "Low",
      MEDIUM = "Medium",
      HIGH = "High",
      DIALOG = "Dialog",
      FULLSCREEN = "Fullscreen",
      FULLSCREEN_DIALOG = "Fullscreen Dialog",
      TOOLTIP = "Tooltip",
   }

   local database = LibStub("AceDB-3.0"):New("ObviousStatusesDB", {
      profile = {
         strata = DEFAULT_STRATA,
         alwaysShowPhase = false, -- show "Present" in zones that have no Zidormi phase (else hide the rectangle)
         reverse = false, -- stack the statuses top to bottom instead of bottom to top
         horizontal = false, -- line the statuses up side by side instead of stacking them
         hideIcons = false,
         hideDragonInCombat = false,
         hidePhaseInCombat = false,
         -- the stack's center, as an offset from the center of the screen (the default is dead center)
         x = 0,
         y = 0,
      },
   }, true)
   local db = database.profile

   -- fixes up bad saved values
   local function ValidateSettings()
      if not STRATA[db.strata] then
         db.strata = DEFAULT_STRATA
      end
      db.alwaysShowPhase = db.alwaysShowPhase == true
      db.reverse = db.reverse == true
      db.horizontal = db.horizontal == true
      db.hideIcons = db.hideIcons == true
      db.hideDragonInCombat = db.hideDragonInCombat == true
      db.hidePhaseInCombat = db.hidePhaseInCombat == true
      db.x = tonumber(db.x) or 0
      db.y = tonumber(db.y) or 0
   end

   ValidateSettings()

   --## ==========================================================================
   --## STATUSES
   --## ==========================================================================
   local FONT_SIZE = 24
   local PADDING = 12 -- around the text, inside each rectangle
   local SPACING = 8 -- between the rectangles
   local ICON_SPACING = 8 -- between a rectangle's icon and its text
   local ICON_GROWTH = 4 -- how much taller the icons are than the text
   local BACKGROUND_PADDING = 10 -- between the rectangles and the edge of the background behind them
   local SKYRIDING_AURA = "Flight Style: Skyriding"

   -- Zones where Zidormi can send you to the past, keyed by uiMapID. Zidormi has no API, so a zone is "in the
   -- past" when either of these is true (set whichever one the zone allows):
   --    pastAura   = the spell name or ID of the aura she gives you (some zones, like Dustwallow Marsh, have none)
   --    pastArtID  = the zone's C_Map.GetMapArtID() while you're in the past
   -- A zone that isn't listed has no phase. Use "/os debug" in each zone, in both states, to find the values:
   --    [<uiMapID>] = { pastAura = <name or spell ID>, pastArtID = <art ID> },
   local PHASE_ZONES = {}

   -- The icon for each state of the combat & phase rectangles. `coords` crops the texture, and `color` tints it
   -- (a white texture takes the color well, so those are desaturated first). The dragonriding rectangle uses the
   -- Skyriding aura's own icon instead.
   local ICONS = {
      -- crossed swords, cropped to the swords (the texture has a lot of empty space around them)
      Fighting = { texture = "Interface\\CharacterFrame\\UI-StateIcon", coords = { 0.56, 0.92, 0.06, 0.43 } },
      Roaming = { texture = 132540 }, -- a file ID
      Past = { texture = "Interface\\Icons\\INV_Misc_PocketWatch_01" }, -- a pocket watch
      Present = { -- a green arrow, a little bigger than the other icons
         texture = "Interface\\ChatFrame\\ChatFrameExpandArrow",
         desaturated = true,
         color = { 0.2, 1, 0.2 },
         extraSize = 2,
      },
   }
   local STEADY_AURA = "Flight Style: Steady"
   local DRAGON_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark" -- if no icon can be found at all

   -- the background color, by the player's faction (Neutral is a Pandaren who hasn't picked a side yet)
   local FACTION_COLORS = {
      Alliance = { 0.05, 0.25, 0.65 },
      Horde = { 0.65, 0.07, 0.07 },
   }
   local NEUTRAL_COLOR = { 0.3, 0.3, 0.3 }

   local frame = CreateFrame("Frame", "UWUObviousStatusesFrame", UIParent)
   frame:SetFrameStrata(db.strata)

   -- the rounded, bordered background behind the rectangles (like the Compass's). It's only as tall as the
   -- rectangles that are showing; the frame it sits in keeps the whole stack's size.
   local background = CreateFrame("Frame", nil, frame, "BackdropTemplate")
   background:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- rounded corners
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
   })
   background:SetBackdropColor(0, 0, 0, 0.5) -- semi-transparent black
   background:SetBackdropBorderColor(1, 1, 1, 0.8)

   local function CreateRectangle(texts)
      local rectangle = CreateFrame("Frame", nil, background)
      rectangle.background = rectangle:CreateTexture(nil, "BACKGROUND")
      rectangle.background:SetAllPoints()

      rectangle.icon = rectangle:CreateTexture(nil, "ARTWORK")

      local label = rectangle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      label:SetFont(STANDARD_TEXT_FONT, FONT_SIZE, "")
      label:SetTextColor(1, 1, 1, 1)
      label:SetJustifyH("LEFT")
      rectangle.label = label

      -- the widest this rectangle's text can be
      local width = 0
      for _, text in ipairs(texts) do
         label:SetText(text)
         width = math.max(width, label:GetStringWidth())
      end
      rectangle.textWidth = width
      rectangle.textHeight = label:GetStringHeight()
      return rectangle
   end

   -- bottom to top
   local combat = CreateRectangle({ "Fighting", "Roaming" })
   local dragon = CreateRectangle({ "Dragon", "Steady" })
   local phase = CreateRectangle({ "Past", "Present" })
   local rectangles = { combat, dragon, phase }

   -- every rectangle is as wide as the widest text of any of them, so a status changing never changes the size
   local maxTextWidth, textHeight, iconSize = 0, 0, 0
   for _, rectangle in ipairs(rectangles) do
      maxTextWidth = math.max(maxTextWidth, rectangle.textWidth)
      textHeight = math.max(textHeight, rectangle.textHeight)
   end

   iconSize = textHeight + ICON_GROWTH
   local rectangleHeight = textHeight + PADDING * 2
   local rectangleWidth

   -- The size of the background behind `count` rectangles, stacked vertically or (if horizontal) side by side.
   -- The frame is always the size of the whole stack, so a rectangle hiding never moves the rest of the stack's
   -- saved center.
   local function GetBackgroundSize(count)
      local gaps = SPACING * (count - 1)
      if db.horizontal then
         return rectangleWidth * count + gaps + BACKGROUND_PADDING * 2, rectangleHeight + BACKGROUND_PADDING * 2
      end
      return rectangleWidth + BACKGROUND_PADDING * 2, rectangleHeight * count + gaps + BACKGROUND_PADDING * 2
   end

   -- Left to right: padding, icon (a little taller than the text), spacing, text (left-aligned), padding.
   -- An icon that's bigger than that grows around its center, so the text stays put. Without icons, the
   -- rectangles are just the text & its padding.
   local function ApplySize()
      local textLeft = PADDING
      if not db.hideIcons then
         textLeft = PADDING + iconSize + ICON_SPACING
      end

      rectangleWidth = textLeft + maxTextWidth + PADDING
      for _, rectangle in ipairs(rectangles) do
         rectangle:SetSize(rectangleWidth, rectangleHeight)
         rectangle.icon:ClearAllPoints()
         rectangle.icon:SetPoint("CENTER", rectangle, "LEFT", PADDING + iconSize / 2, 0)
         rectangle.label:ClearAllPoints()
         rectangle.label:SetPoint("LEFT", textLeft, 0)
      end

      frame:SetSize(GetBackgroundSize(#rectangles))
   end

   local state = {
      inCombat = InCombatLockdown(),
      dragon = false,
      phase = nil, -- "Past", "Present", or nil when this zone has no phase
   }

   local function ApplyColor()
      local color = FACTION_COLORS[UnitFactionGroup("player")] or NEUTRAL_COLOR
      for _, rectangle in ipairs(rectangles) do
         rectangle.background:SetColorTexture(color[1], color[2], color[3], 1)
      end
   end

   -- The visible rectangles stack up from the bottom (or line up from the left, if horizontal) with no gaps,
   -- combat first, so hiding one shrinks the stack toward that edge. Reversed, it's the mirror image: they hang
   -- from the top (or line up from the right), combat first, and shrink toward that edge instead.
   local function Layout(visible)
      local anchor, direction
      if db.horizontal then
         anchor, direction = db.reverse and "RIGHT" or "LEFT", db.reverse and -1 or 1
      else
         anchor, direction = db.reverse and "TOP" or "BOTTOM", db.reverse and -1 or 1
      end

      background:ClearAllPoints()
      background:SetPoint(anchor, frame, anchor)

      local count = 0
      for i, rectangle in ipairs(rectangles) do
         rectangle:SetShown(visible[i])
         if visible[i] then
            local size = db.horizontal and rectangleWidth or rectangleHeight
            local offset = direction * (BACKGROUND_PADDING + count * (size + SPACING))
            rectangle:ClearAllPoints()
            if db.horizontal then
               rectangle:SetPoint(anchor, frame, anchor, offset, 0)
            else
               rectangle:SetPoint(anchor, frame, anchor, 0, offset)
            end
            count = count + 1
         end
      end
      background:SetSize(GetBackgroundSize(count))
   end

   local function SetIcon(rectangle, icon)
      local coords = icon.coords or { 0, 1, 0, 1 }
      local color = icon.color or { 1, 1, 1 }
      local size = iconSize + (icon.extraSize or 0)
      rectangle.icon:SetSize(size, size)
      rectangle.icon:SetShown(not db.hideIcons)
      rectangle.icon:SetTexture(icon.texture)
      rectangle.icon:SetTexCoord(unpack(coords))
      rectangle.icon:SetDesaturated(icon.desaturated == true)
      rectangle.icon:SetVertexColor(color[1], color[2], color[3])
   end

   local function Refresh()
      ApplySize() -- the icons being hidden changes the width

      local combatText = state.inCombat and "Fighting" or "Roaming"
      local phaseText = state.phase or "Present"
      combat.label:SetText(combatText)
      SetIcon(combat, ICONS[combatText])
      phase.label:SetText(phaseText)
      SetIcon(phase, ICONS[phaseText])

      -- the Skyriding aura's icon, at full strength whether or not it's on
      dragon.label:SetText(state.dragon and "Dragon" or "Steady")
      SetIcon(dragon, { texture = state.dragonIcon or DRAGON_FALLBACK_ICON })

      Layout({
         true,
         not (state.inCombat and db.hideDragonInCombat),
         state.phase ~= nil and not (state.inCombat and db.hidePhaseInCombat),
      })
   end

   --## State -------------------------------------------------------------------
   local function HasAura(aura)
      if type(aura) == "number" then
         return C_UnitAuras.GetPlayerAuraBySpellID(aura) ~= nil
      end
      return C_UnitAuras.GetAuraDataBySpellName("player", aura) ~= nil
   end

   local function GetPhase()
      local mapID = C_Map.GetBestMapForUnit("player")
      local zone = mapID and PHASE_ZONES[mapID]
      if not zone then
         return db.alwaysShowPhase and "Present" or nil
      end

      local inPast = (zone.pastAura ~= nil and HasAura(zone.pastAura))
         or (zone.pastArtID ~= nil and C_Map.GetMapArtID(mapID) == zone.pastArtID)
      return inPast and "Past" or "Present"
   end

   -- Zidormi can change the zone's art without a loading screen or a reliable event, so while we're in one
   -- of her zones the phase is also checked once a second
   local phaseTicker
   local function UpdatePhase()
      local mapID = C_Map.GetBestMapForUnit("player")
      local inPhaseZone = mapID ~= nil and PHASE_ZONES[mapID] ~= nil
      if inPhaseZone and not phaseTicker then
         phaseTicker = C_Timer.NewTicker(1, function()
            local phaseNow = GetPhase()
            if phaseNow ~= state.phase then
               state.phase = phaseNow
               Refresh()
            end
         end)
      elseif not inPhaseZone and phaseTicker then
         phaseTicker:Cancel()
         phaseTicker = nil
      end

      state.phase = GetPhase()
   end

   -- The Skyriding aura's icon. It's only readable while the aura is on, so it's saved (for all characters) to
   -- show while it's off. Until it has been seen, the spell's icon, then the Steady Flight aura's, stand in.
   local function GetDragonIcon(aura)
      local icon = aura and (aura.icon or (aura.spellId and C_Spell.GetSpellTexture(aura.spellId)))
      if icon then
         database.global.dragonIcon = icon
         return icon
      end

      local steady = C_UnitAuras.GetAuraDataBySpellName("player", STEADY_AURA)
      return database.global.dragonIcon or C_Spell.GetSpellTexture(SKYRIDING_AURA) or (steady and steady.icon)
   end

   local function UpdateAll()
      state.inCombat = InCombatLockdown()
      local aura = C_UnitAuras.GetAuraDataBySpellName("player", SKYRIDING_AURA)
      state.dragon = aura ~= nil
      state.dragonIcon = GetDragonIcon(aura)
      UpdatePhase()
      Refresh()
   end

   frame:RegisterEvent("PLAYER_ENTERING_WORLD")
   frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
   frame:RegisterEvent("ZONE_CHANGED")
   frame:RegisterEvent("ZONE_CHANGED_INDOORS")
   frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- entering combat
   frame:RegisterEvent("PLAYER_REGEN_ENABLED") -- leaving combat
   frame:RegisterUnitEvent("UNIT_AURA", "player")
   frame:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" then
         state.inCombat = true
         Refresh()
      elseif event == "PLAYER_REGEN_ENABLED" then
         state.inCombat = false
         Refresh()
      elseif event == "PLAYER_ENTERING_WORLD" then
         ApplyColor() -- the faction can change (a Pandaren picking a side)
         UpdateAll()
      else
         UpdateAll()
      end
   end)

   ApplyColor()
   UpdateAll()

   --## Position ---------------------------------------------------------------
   -- Saved as the frame's center offset from the screen's center, in screen (UIParent) units.
   local function ApplyPosition()
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
   end

   -- Saves the frame's current spot as center offsets (after it's been dragged)
   local function SaveCenterPosition()
      local frameX, frameY = frame:GetCenter()
      local screenX, screenY = UIParent:GetCenter()
      if not (frameX and screenX) then
         return
      end

      local frameScale, screenScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
      db.x = math.floor((frameX * frameScale - screenX * screenScale) / screenScale + 0.5)
      db.y = math.floor((frameY * frameScale - screenY * screenScale) / screenScale + 0.5)
      ApplyPosition() -- back to a single CENTER anchor
      LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName) -- refresh the Positioning tab if it's open
   end

   frame:SetMovable(true) -- before SetUserPlaced, which errors on a frame that isn't movable
   frame:SetUserPlaced(false) -- we save the position ourselves, not the game's layout cache
   ApplyPosition()
   frame:SetClampedToScreen(true)
   frame:EnableMouse(true)
   frame:RegisterForDrag("LeftButton")
   -- locked by default; hold Shift while left-click dragging to move it
   frame:SetScript("OnDragStart", function(self)
      if IsShiftKeyDown() then
         self:StartMoving()
      end
   end)
   frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      self:SetUserPlaced(false)
      SaveCenterPosition()
   end)

   frame:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_NONE")
      GameTooltip:ClearAllPoints()
      GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT")
      GameTooltip:SetText("Obvious Statuses")
      GameTooltip:AddLine("shift+left-mouse to drag", 1, 1, 1)
      GameTooltip:Show()
   end)
   frame:SetScript("OnLeave", GameTooltip_Hide)

   local function SetPosition(x, y)
      frame:StopMovingOrSizing()
      db.x, db.y = x, y
      ApplyPosition()
   end

   local function ResetPosition()
      SetPosition(0, 0)
   end

   --## ==========================================================================
   --## SETTINGS WINDOW (/os, the /uwu cog & Options > AddOns)
   --## ==========================================================================
   local APP_NAME = "ObviousStatuses"

   --## Positioning tab ---------------------------------------------------------
   local POSITION_NUDGE = 1 -- how far the -/+ buttons move the statuses

   local function OffsetInput(axis, label, order)
      return {
         order = order,
         name = label,
         desc = "Offset of the statuses' center from the center of the screen.",
         type = "input",
         get = function()
            return tostring(db[axis])
         end,
         validate = function(_, value)
            return tonumber(value) ~= nil or "Please enter a number."
         end,
         set = function(_, value)
            if axis == "x" then
               SetPosition(tonumber(value), db.y)
            else
               SetPosition(db.x, tonumber(value))
            end
         end,
      }
   end

   local function NudgeButton(axis, direction, order)
      return {
         order = order,
         name = direction < 0 and "-" or "+",
         type = "execute",
         width = 0.5,
         func = function()
            local delta = direction * POSITION_NUDGE
            if axis == "x" then
               SetPosition(db.x + delta, db.y)
            else
               SetPosition(db.x, db.y + delta)
            end
         end,
      }
   end

   -- forces the next options onto a new row
   local function LineBreak(order)
      return { order = order, name = "", type = "description", width = "full" }
   end

   local function Checkbox(order, name, desc, key)
      return {
         order = order,
         name = name,
         desc = desc,
         type = "toggle",
         width = "full",
         get = function()
            return db[key]
         end,
         set = function(_, value)
            db[key] = value
            UpdateAll()
         end,
      }
   end

   local positioningOptions = {
      name = "Positioning",
      type = "group",
      order = 2,
      args = {
         intro = {
            order = 1,
            name = "Position the statuses precisely, relative to the center of the screen. "
               .. "You can also hold Shift and drag them with the left mouse button.",
            type = "description",
            width = "full",
         },
         xOffset = OffsetInput("x", "X Offset", 10),
         yOffset = OffsetInput("y", "Y Offset", 11),
         nudgeBreak = LineBreak(19),
         xMinus = NudgeButton("x", -1, 20),
         xPlus = NudgeButton("x", 1, 21),
         yMinus = NudgeButton("y", -1, 22),
         yPlus = NudgeButton("y", 1, 23),
         centerBreak = LineBreak(29),
         centerHorizontally = {
            order = 30,
            name = "Center Horizontally",
            type = "execute",
            func = function()
               SetPosition(0, db.y)
            end,
         },
         centerVertically = {
            order = 31,
            name = "Center Vertically",
            type = "execute",
            func = function()
               SetPosition(db.x, 0)
            end,
         },
         resetBreak = LineBreak(39),
         resetPosition = {
            order = 40,
            name = "Reset Position",
            desc = "Move the statuses back to their default spot, the center of the screen.",
            type = "execute",
            func = ResetPosition,
         },
      },
   }

   local options = {
      type = "group",
      name = "UwU: Obvious Statuses",
      childGroups = "tab", -- General & Positioning as tabs (in /os and in Options > AddOns)
      args = {
         positioning = positioningOptions,
         general = {
            name = "General",
            type = "group",
            order = 1,
            args = {
               strata = {
                  order = 0,
                  name = "Strata",
                  desc = "Which layer of the screen the statuses are drawn on. "
                     .. "Higher layers draw in front of lower ones.",
                  type = "select",
                  values = STRATA,
                  sorting = STRATA_ORDER,
                  get = function()
                     return db.strata
                  end,
                  set = function(_, value)
                     db.strata = value
                     frame:SetFrameStrata(value)
                  end,
               },
               reverse = Checkbox(
                  0.25,
                  "Reverse",
                  "Reverse the order of the statuses. Normally combat is at the bottom (or the left, if "
                     .. "Horizontal) & phase is at the top (or the right); reversed, it's the other way around.",
                  "reverse"
               ),
               horizontal = Checkbox(
                  0.4,
                  "Horizontal",
                  "Line the statuses up side by side, combat on the left, instead of stacking them. "
                     .. "Works with Reverse.",
                  "horizontal"
               ),
               hideIcons = Checkbox(
                  0.5,
                  "Hide Icons",
                  "Hide the icons to the left of each status. The statuses get narrower to fit.",
                  "hideIcons"
               ),
               alwaysShowPhase = Checkbox(
                  1,
                  "Always Show Phase",
                  "Show \"Present\" in zones that Zidormi can't send you to the past in. "
                     .. "When unchecked, the phase status is hidden there.",
                  "alwaysShowPhase"
               ),
               hideDragonInCombat = Checkbox(
                  2,
                  "Hide Dragonriding in Combat",
                  "Hide the Dragon / Steady status while you're in combat.",
                  "hideDragonInCombat"
               ),
               hidePhaseInCombat = Checkbox(
                  3,
                  "Hide Phase in Combat",
                  "Hide the Past / Present status while you're in combat.",
                  "hidePhaseInCombat"
               ),
            },
         },
      },
   }

   -- the Profiles tab (always last)
   options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(database)
   options.args.profile.order = -2

   -- switching, copying or resetting a profile redraws the statuses with the new profile's settings
   local function OnProfileChanged()
      db = database.profile
      ValidateSettings()
      frame:SetFrameStrata(db.strata)
      ApplyPosition()
      UpdateAll()
      LibStub("AceConfigRegistry-3.0"):NotifyChange(APP_NAME)
   end

   database.RegisterCallback(frame, "OnProfileChanged", OnProfileChanged)
   database.RegisterCallback(frame, "OnProfileCopied", OnProfileChanged)
   database.RegisterCallback(frame, "OnProfileReset", OnProfileChanged)

   LibStub("AceConfig-3.0"):RegisterOptionsTable(APP_NAME, options)
   local aceConfigDialog = LibStub("AceConfigDialog-3.0")
   aceConfigDialog:SetDefaultSize(APP_NAME, 440, 330)

   local PREFIX = "|cFF00FF00Obvious Statuses:|r "

   -- Prints what's needed to fill in PHASE_ZONES: stand in a Zidormi zone, once in the past & once in the present
   local function PrintDebug()
      local mapID = C_Map.GetBestMapForUnit("player")
      print(PREFIX .. "uiMapID: " .. tostring(mapID) .. ", map art ID: "
         .. tostring(mapID and C_Map.GetMapArtID(mapID)) .. ", phase: " .. tostring(state.phase))
      print(PREFIX .. "Your buffs (name, spell ID):")
      local index = 1
      local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
      while aura do
         print("  " .. tostring(aura.name) .. " (" .. tostring(aura.spellId) .. ")")
         index = index + 1
         aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
      end
   end

   SLASH_UWUOBVIOUSSTATUSES1 = "/os"
   SlashCmdList["UWUOBVIOUSSTATUSES"] = function(msg)
      local command = string.lower(strtrim(msg or ""))

      if command == "" then
         if aceConfigDialog.OpenFrames[APP_NAME] then
            aceConfigDialog:Close(APP_NAME)
         else
            aceConfigDialog:Open(APP_NAME)
         end
      elseif command == "debug" then
         PrintDebug()
      else
         print(PREFIX .. "Use /os to open the options, or /os debug to list this zone's map & your buffs.")
      end
   end

   -- a sub-item under UwU's own "Loaded!" message, which prints just before the modules load
   print("  - |cFF00FF00Obvious Statuses|r loaded. Shift + drag the frame to move it.")
end)
