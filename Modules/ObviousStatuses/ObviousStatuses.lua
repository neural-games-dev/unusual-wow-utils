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

   local MIN_RANGE_SCALE, MAX_RANGE_SCALE = 0.5, 3
   local MIN_RANGE_CROSS_SCALE, MAX_RANGE_CROSS_SCALE = 0.5, 3

   local DEFAULTS = {
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
         -- the range indicator (the Range tab)
         rangeSpell = "", -- the name of the spell whose range is checked (blank hides the indicator)
         rangeScale = 1,
         rangeX = 0, -- its center, as an offset from the center of the screen (just below the statuses)
         rangeY = -150,
         rangeCross = false, -- draw a scope cross over it
         rangeCrossColor = { r = 1, g = 1, b = 1 },
         rangeCrossScale = 1, -- on top of the indicator's own scale
         rangeHideIcon = false, -- only allowed while the cross is on, so the indicator never draws nothing
      },
   }

   local database = LibStub("AceDB-3.0"):New("ObviousStatusesDB", DEFAULTS, true)
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
      db.rangeSpell = type(db.rangeSpell) == "string" and strtrim(db.rangeSpell) or ""
      db.rangeScale = Clamp(tonumber(db.rangeScale) or DEFAULTS.profile.rangeScale, MIN_RANGE_SCALE, MAX_RANGE_SCALE)
      db.rangeX = tonumber(db.rangeX) or DEFAULTS.profile.rangeX
      db.rangeY = tonumber(db.rangeY) or DEFAULTS.profile.rangeY
      db.rangeCross = db.rangeCross == true
      local crossColor = type(db.rangeCrossColor) == "table" and db.rangeCrossColor or {}
      db.rangeCrossColor = {
         r = Clamp(tonumber(crossColor.r) or 1, 0, 1),
         g = Clamp(tonumber(crossColor.g) or 1, 0, 1),
         b = Clamp(tonumber(crossColor.b) or 1, 0, 1),
      }
      db.rangeCrossScale = Clamp(
         tonumber(db.rangeCrossScale) or DEFAULTS.profile.rangeCrossScale,
         MIN_RANGE_CROSS_SCALE,
         MAX_RANGE_CROSS_SCALE
      )
      db.rangeHideIcon = db.rangeHideIcon == true and db.rangeCross
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
   -- Where a movable frame sits. It's saved as the frame's center offset from the screen's center, in screen
   -- (UIParent) units whatever its scale is, so the X/Y offsets in the settings always mean the same thing.
   -- `xKey` & `yKey` name its offsets in the settings, and `scaleKey` its scale (if it has one).
   local function CreatePlacement(target, xKey, yKey, scaleKey)
      local placement = {}

      function placement.Get()
         return db[xKey], db[yKey]
      end

      function placement.Apply()
         local scale = scaleKey and db[scaleKey] or 1
         target:ClearAllPoints()
         -- anchor offsets are in the frame's own (scaled) units
         target:SetPoint("CENTER", UIParent, "CENTER", db[xKey] / scale, db[yKey] / scale)
      end

      function placement.Set(x, y)
         target:StopMovingOrSizing()
         db[xKey], db[yKey] = x, y
         placement.Apply()
      end

      function placement.Reset()
         placement.Set(DEFAULTS.profile[xKey], DEFAULTS.profile[yKey])
      end

      -- Saves the frame's current spot as center offsets (after it's been dragged)
      local function SaveCenterPosition()
         local frameX, frameY = target:GetCenter()
         local screenX, screenY = UIParent:GetCenter()
         if not (frameX and screenX) then
            return
         end

         local frameScale, screenScale = target:GetEffectiveScale(), UIParent:GetEffectiveScale()
         db[xKey] = math.floor((frameX * frameScale - screenX * screenScale) / screenScale + 0.5)
         db[yKey] = math.floor((frameY * frameScale - screenY * screenScale) / screenScale + 0.5)
         placement.Apply() -- back to a single CENTER anchor
         LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName) -- refresh the offsets in the settings if open
      end

      -- `region` takes the mouse & moves the frame. Its tooltip is `title`, plus the lines `AddLines` adds.
      function placement.EnableDragging(region, title, AddLines)
         target:SetMovable(true) -- before SetUserPlaced, which errors on a frame that isn't movable
         target:SetUserPlaced(false) -- we save the position ourselves, not the game's layout cache
         target:SetClampedToScreen(true)
         region:EnableMouse(true)
         region:RegisterForDrag("LeftButton")
         -- locked by default; hold Shift while left-click dragging to move it
         region:SetScript("OnDragStart", function()
            if IsShiftKeyDown() then
               target:StartMoving()
            end
         end)
         region:SetScript("OnDragStop", function()
            target:StopMovingOrSizing()
            target:SetUserPlaced(false)
            SaveCenterPosition()
         end)

         region:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT")
            GameTooltip:SetText(title)
            if AddLines then
               AddLines(GameTooltip)
            end
            GameTooltip:AddLine("shift+left-mouse to drag", 1, 1, 1)
            GameTooltip:Show()
         end)
         region:SetScript("OnLeave", GameTooltip_Hide)
      end

      return placement
   end

   local statusesPlacement = CreatePlacement(frame, "x", "y")
   statusesPlacement.Apply()
   -- The background (only as big as the visible statuses) takes the mouse, not the frame (always the whole
   -- stack's size), so hidden statuses' empty space doesn't block clicks or show the tooltip.
   statusesPlacement.EnableDragging(background, "Obvious Statuses")

   --## ==========================================================================
   --## RANGE INDICATOR
   --## ==========================================================================
   -- A square showing whether your target is in range of the spell named in the Range tab, on its own frame
   -- (moved & scaled apart from the statuses). It's hidden while no spell is named.
   local RANGE_SIZE = 48 -- as tall as a status rectangle (at a scale of 1)
   local RANGE_INTERVAL = 0.1 -- range changes have no event, so it's checked this often (in seconds)
   local RANGE_ICONS = {
      inRange = "Interface\\Icons\\Spell_Shadow_MindSteal", -- an open eye: close enough
      outOfRange = "Interface\\Icons\\Spell_Nature_Sleep", -- a closed eye: too far away
      unknownSpell = "Interface\\Icons\\INV_Misc_QuestionMark", -- the game's red question mark
   }
   -- the slightly dark, semi-transparent colors laid over those icons (red, green, blue, opacity)
   local RANGE_TINTS = {
      inRange = { 0, 0.7, 0, 0.5 }, -- green
      outOfRange = { 0.7, 0, 0, 0.7 }, -- red
   }

   local rangeFrame = CreateFrame("Frame", "UWUObviousStatusesRangeFrame", UIParent)
   rangeFrame:SetSize(RANGE_SIZE, RANGE_SIZE)
   rangeFrame:SetScale(db.rangeScale)

   -- one layer below the statuses' strata (or the same, if theirs is already the lowest)
   local function ApplyRangeStrata()
      local index = tIndexOf(STRATA_ORDER, db.strata) or 1
      rangeFrame:SetFrameStrata(STRATA_ORDER[math.max(index - 1, 1)])
   end

   ApplyRangeStrata()

   local rangeIcon = rangeFrame:CreateTexture(nil, "ARTWORK")
   rangeIcon:SetAllPoints()

   -- a semi-transparent color over the icon while the target is in range (green) or too far away (red)
   local rangeTint = rangeFrame:CreateTexture(nil, "OVERLAY")
   rangeTint:SetAllPoints(rangeIcon)
   rangeTint:Hide()

   -- the optional scope cross over the icon: a ring with four hairs that stop short of the center. It's drawn
   -- with lines, on a child frame that doesn't take the mouse, so dragging & the tooltip still reach rangeFrame.
   local RANGE_CROSS_THICKNESS = 2
   local RANGE_CROSS_GAP = 4 -- from the center to where the hairs start
   local RANGE_CROSS_RING_RADIUS = 15
   local RANGE_CROSS_RING_SEGMENTS = 32

   -- anchored by its center, so scaling it grows & shrinks it around the middle of the icon
   local rangeCross = CreateFrame("Frame", nil, rangeFrame)
   rangeCross:SetSize(RANGE_SIZE, RANGE_SIZE)
   rangeCross:SetPoint("CENTER")
   local rangeCrossLines = {}

   -- the points are offsets from the indicator's center
   local function AddRangeCrossLine(startX, startY, endX, endY)
      local line = rangeCross:CreateLine(nil, "OVERLAY")
      line:SetThickness(RANGE_CROSS_THICKNESS)
      line:SetStartPoint("CENTER", rangeCross, startX, startY)
      line:SetEndPoint("CENTER", rangeCross, endX, endY)
      table.insert(rangeCrossLines, line)
   end

   local rangeEdge = RANGE_SIZE / 2
   AddRangeCrossLine(0, RANGE_CROSS_GAP, 0, rangeEdge)
   AddRangeCrossLine(0, -RANGE_CROSS_GAP, 0, -rangeEdge)
   AddRangeCrossLine(RANGE_CROSS_GAP, 0, rangeEdge, 0)
   AddRangeCrossLine(-RANGE_CROSS_GAP, 0, -rangeEdge, 0)

   local ringStep = 2 * math.pi / RANGE_CROSS_RING_SEGMENTS
   for i = 1, RANGE_CROSS_RING_SEGMENTS do
      local startAngle, endAngle = (i - 1) * ringStep, i * ringStep
      AddRangeCrossLine(
         RANGE_CROSS_RING_RADIUS * math.cos(startAngle),
         RANGE_CROSS_RING_RADIUS * math.sin(startAngle),
         RANGE_CROSS_RING_RADIUS * math.cos(endAngle),
         RANGE_CROSS_RING_RADIUS * math.sin(endAngle)
      )
   end

   local currentRangeTint -- the entry of RANGE_TINTS being shown, if any

   local function ApplyRangeCross()
      local color = db.rangeCrossColor
      local r, g, b = color.r, color.g, color.b
      -- with no icon to show the range, the cross takes on its color (opaque, as thin lines are hard to see through)
      if db.rangeHideIcon and currentRangeTint then
         r, g, b = currentRangeTint[1], currentRangeTint[2], currentRangeTint[3]
      end

      for _, line in ipairs(rangeCrossLines) do
         line:SetColorTexture(r, g, b)
      end
      rangeCross:SetScale(db.rangeCrossScale)
      rangeCross:SetShown(db.rangeCross)
   end

   ApplyRangeCross()

   -- the named spell's info, or nil if the game doesn't know a spell by that name
   local function GetRangeSpell()
      if db.rangeSpell == "" then
         return nil
      end
      return C_Spell.GetSpellInfo(db.rangeSpell)
   end

   -- true or false, or nil when it can't be told: no target, one the spell can't be cast on (e.g. a damage
   -- spell on a friend), a spell with no range, or a range the game keeps secret from addons
   local function IsTargetInRange(spellID)
      if not UnitExists("target") then
         return nil
      end

      local inRange = C_Spell.IsSpellInRange(spellID, "target")
      if issecretvalue and issecretvalue(inRange) then
         return nil
      end
      return inRange
   end

   -- `tint` is the color to lay over the icon, if any
   local function SetRangeIcon(texture, desaturated, tint)
      rangeIcon:SetTexture(texture)
      rangeIcon:SetDesaturated(desaturated == true)
      rangeIcon:SetShown(not db.rangeHideIcon)
      if tint then
         rangeTint:SetColorTexture(unpack(tint))
      end
      rangeTint:SetShown(tint ~= nil and not db.rangeHideIcon)

      -- this runs on every range check, so the cross is only recolored when the tint changes
      if tint ~= currentRangeTint then
         currentRangeTint = tint
         ApplyRangeCross()
      end
   end

   local function RefreshRange()
      local spell = GetRangeSpell()
      if not spell then
         SetRangeIcon(RANGE_ICONS.unknownSpell)
         return
      end

      local inRange = IsTargetInRange(spell.spellID)
      if inRange == nil then
         SetRangeIcon(spell.iconID, true) -- the spell's own icon, greyed out, until there's something to check
      elseif inRange then
         SetRangeIcon(RANGE_ICONS.inRange, false, RANGE_TINTS.inRange)
      else
         SetRangeIcon(RANGE_ICONS.outOfRange, false, RANGE_TINTS.outOfRange)
      end
   end

   local function UpdateRangeShown()
      rangeFrame:SetShown(db.rangeSpell ~= "")
      RefreshRange()
   end

   -- only runs while the indicator is showing
   local sinceRangeCheck = 0
   rangeFrame:SetScript("OnUpdate", function(_, elapsed)
      sinceRangeCheck = sinceRangeCheck + elapsed
      if sinceRangeCheck >= RANGE_INTERVAL then
         sinceRangeCheck = 0
         RefreshRange()
      end
   end)

   -- a new target shows straight away, instead of on the next check
   rangeFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
   rangeFrame:SetScript("OnEvent", RefreshRange)

   local rangePlacement = CreatePlacement(rangeFrame, "rangeX", "rangeY", "rangeScale")
   rangePlacement.Apply()
   rangePlacement.EnableDragging(rangeFrame, "Range Indicator", function(tooltip)
      local spell = GetRangeSpell()
      if spell then
         tooltip:AddLine("Checking: " .. spell.name, 1, 0.82, 0)
      else
         tooltip:AddLine('No spell called "' .. db.rangeSpell .. '" was found', 1, 0.2, 0.2)
      end
   end)

   local function SetRangeScale(scale)
      db.rangeScale = Clamp(scale, MIN_RANGE_SCALE, MAX_RANGE_SCALE)
      rangeFrame:SetScale(db.rangeScale)
      rangePlacement.Apply() -- keeps the same spot on screen
   end

   UpdateRangeShown()

   --## ==========================================================================
   --## SETTINGS WINDOW (/os, the /uwu cog & Options > AddOns)
   --## ==========================================================================
   local APP_NAME = "ObviousStatuses"

   --## Positioning tab ---------------------------------------------------------
   local POSITION_NUDGE = 1 -- how far the -/+ buttons move a frame

   -- `what` names the frame in descriptions, e.g. "the statuses"
   local function OffsetInput(placement, what, axis, label, order)
      return {
         order = order,
         name = label,
         desc = "Offset of the center of " .. what .. " from the center of the screen.",
         type = "input",
         get = function()
            local x, y = placement.Get()
            return tostring(axis == "x" and x or y)
         end,
         validate = function(_, value)
            return tonumber(value) ~= nil or "Please enter a number."
         end,
         set = function(_, value)
            local x, y = placement.Get()
            if axis == "x" then
               placement.Set(tonumber(value), y)
            else
               placement.Set(x, tonumber(value))
            end
         end,
      }
   end

   local function NudgeButton(placement, axis, direction, order)
      return {
         order = order,
         name = direction < 0 and "-" or "+",
         type = "execute",
         width = 0.5,
         func = function()
            local x, y = placement.Get()
            local delta = direction * POSITION_NUDGE
            if axis == "x" then
               placement.Set(x + delta, y)
            else
               placement.Set(x, y + delta)
            end
         end,
      }
   end

   -- forces the next options onto a new row
   local function LineBreak(order)
      return { order = order, name = "", type = "description", width = "full" }
   end

   -- Adds the X/Y offsets, nudge, centering & reset options for a placement to `args`, ordered from `order`.
   -- `what` names the frame in descriptions, and `defaultSpot` where Reset Position puts it.
   local function AddPositionOptions(args, placement, what, defaultSpot, order)
      args.xOffset = OffsetInput(placement, what, "x", "X Offset", order)
      args.yOffset = OffsetInput(placement, what, "y", "Y Offset", order + 1)
      args.nudgeBreak = LineBreak(order + 9)
      args.xMinus = NudgeButton(placement, "x", -1, order + 10)
      args.xPlus = NudgeButton(placement, "x", 1, order + 11)
      args.yMinus = NudgeButton(placement, "y", -1, order + 12)
      args.yPlus = NudgeButton(placement, "y", 1, order + 13)
      args.centerBreak = LineBreak(order + 19)
      args.centerHorizontally = {
         order = order + 20,
         name = "Center Horizontally",
         type = "execute",
         func = function()
            local _, y = placement.Get()
            placement.Set(0, y)
         end,
      }
      args.centerVertically = {
         order = order + 21,
         name = "Center Vertically",
         type = "execute",
         func = function()
            local x = placement.Get()
            placement.Set(x, 0)
         end,
      }
      args.resetBreak = LineBreak(order + 29)
      args.resetPosition = {
         order = order + 30,
         name = "Reset Position",
         desc = "Move " .. what .. " back to " .. defaultSpot .. ".",
         type = "execute",
         func = placement.Reset,
      }
      return args
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
      args = AddPositionOptions({
         intro = {
            order = 1,
            name = "Position the statuses precisely, relative to the center of the screen. "
               .. "You can also hold Shift and drag them with the left mouse button.",
            type = "description",
            width = "full",
         },
      }, statusesPlacement, "the statuses", "their default spot, the center of the screen", 10),
   }

   --## Range tab ---------------------------------------------------------------
   local rangeOptions = {
      name = "Range",
      type = "group",
      order = 3,
      args = AddPositionOptions({
         intro = {
            order = 1,
            name = "Shows whether your target is in range of a spell: an open eye under a green tint when it is, "
               .. "and a closed eye under a red tint when it's too far away. With no target (or one the spell can't be cast on), it shows the "
               .. "spell's icon, greyed out. A red question mark means no spell by that name was found.\n\n"
               .. "Hold Shift and drag it with the left mouse button to move it.\n ",
            type = "description",
            width = "full",
         },
         spell = {
            order = 2,
            name = "Spell",
            desc = "The name of the spell to check your target's range with, e.g. one of your attacks or heals. "
               .. "Leave it blank to hide the range indicator.",
            type = "input",
            width = "full",
            get = function()
               return db.rangeSpell
            end,
            set = function(_, value)
               db.rangeSpell = strtrim(value)
               UpdateRangeShown()
            end,
         },
         spellStatus = {
            order = 3,
            name = function()
               if db.rangeSpell == "" then
                  return "No spell set, so the range indicator is hidden."
               end

               local spell = GetRangeSpell()
               if not spell then
                  return '|cFFff3333No spell called "' .. db.rangeSpell .. '" was found.|r'
               end
               return "Checking: |T" .. spell.iconID .. ":0|t " .. spell.name
            end,
            type = "description",
            width = "full",
         },
         scale = {
            order = 4,
            name = "Scale",
            desc = "Resize the range indicator.",
            type = "range",
            min = MIN_RANGE_SCALE,
            max = MAX_RANGE_SCALE,
            step = 0.05,
            isPercent = true,
            width = "full",
            get = function()
               return db.rangeScale
            end,
            set = function(_, value)
               SetRangeScale(value)
            end,
         },
         cross = {
            order = 4.1,
            name = "Scope Cross",
            desc = "Draw a scope cross targeting symbol over the range indicator. "
               .. "It can't be turned off while the icon is hidden.",
            type = "toggle",
            disabled = function()
               return db.rangeHideIcon
            end,
            get = function()
               return db.rangeCross
            end,
            set = function(_, value)
               db.rangeCross = value
               ApplyRangeCross()
            end,
         },
         crossColor = {
            order = 4.2,
            name = "Cross Color",
            desc = "The color of the scope cross. While the icon is hidden, it's only used when there's no range "
               .. "to show; the cross turns green or red otherwise.",
            type = "color",
            disabled = function()
               return not db.rangeCross
            end,
            get = function()
               local color = db.rangeCrossColor
               return color.r, color.g, color.b
            end,
            set = function(_, r, g, b)
               local color = db.rangeCrossColor
               color.r, color.g, color.b = r, g, b
               ApplyRangeCross()
            end,
         },
         crossScale = {
            order = 4.3,
            name = "Cross Scale",
            desc = "Resize the scope cross. It stays centered on the range indicator.",
            type = "range",
            min = MIN_RANGE_CROSS_SCALE,
            max = MAX_RANGE_CROSS_SCALE,
            step = 0.05,
            isPercent = true,
            width = "full",
            disabled = function()
               return not db.rangeCross
            end,
            get = function()
               return db.rangeCrossScale
            end,
            set = function(_, value)
               db.rangeCrossScale = value
               ApplyRangeCross()
            end,
         },
         hideIcon = {
            order = 4.4,
            name = "Hide Icon",
            desc = "Hide the icon & its tint, leaving only the scope cross, which turns green when your target is "
               .. "in range and red when it's too far away. The scope cross has to be on to hide the icon. You can "
               .. "still hold Shift and drag the empty square to move it.",
            type = "toggle",
            width = "full",
            disabled = function()
               return not db.rangeCross
            end,
            get = function()
               return db.rangeHideIcon
            end,
            set = function(_, value)
               db.rangeHideIcon = value
               RefreshRange()
               ApplyRangeCross()
            end,
         },
         positionHeader = {
            order = 5,
            name = "Position",
            type = "header",
         },
      }, rangePlacement, "the range indicator", "its default spot, just below the center of the screen", 10),
   }

   local options = {
      type = "group",
      name = "UwU: Obvious Statuses",
      childGroups = "tab", -- General, Positioning & Range as tabs (in /os and in Options > AddOns)
      args = {
         positioning = positioningOptions,
         range = rangeOptions,
         general = {
            name = "General",
            type = "group",
            order = 1,
            args = {
               strata = {
                  order = 0,
                  name = "Strata",
                  desc = "Which layer of the screen the statuses are drawn on (the range indicator is drawn one "
                     .. "layer lower). Higher layers draw in front of lower ones.",
                  type = "select",
                  values = STRATA,
                  sorting = STRATA_ORDER,
                  get = function()
                     return db.strata
                  end,
                  set = function(_, value)
                     db.strata = value
                     frame:SetFrameStrata(value)
                     ApplyRangeStrata()
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
      statusesPlacement.Apply()
      UpdateAll()
      ApplyRangeStrata()
      rangeFrame:SetScale(db.rangeScale)
      rangePlacement.Apply()
      ApplyRangeCross()
      UpdateRangeShown()
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
