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

   -- each state's background color until another is picked (#171717)
   local DEFAULT_STATE_COLOR = { r = 0x17 / 255, g = 0x17 / 255, b = 0x17 / 255 }
   -- the states that can each have their own color, in the order they're picked in
   local STATE_ORDER = { "Roaming", "Fighting", "Dragon", "Steady", "Present", "Past" }

   local MIN_RANGE_SCALE, MAX_RANGE_SCALE = 0.5, 3
   local MIN_RANGE_CROSS_SCALE, MAX_RANGE_CROSS_SCALE = 0.5, 3

   -- the game's own sounds that can play when a target comes into range, as keys of SOUNDKIT (which has no "NONE")
   local RANGE_SOUND_ORDER = {
      "NONE", "RAID_WARNING", "UI_RAID_BOSS_WHISPER_WARNING", "READY_CHECK", "LFG_ROLE_CHECK", "PVP_THROUGH_QUEUE",
      "IG_PLAYER_INVITE", "TELL_MESSAGE", "MAP_PING", "ALARM_CLOCK_WARNING_1", "ALARM_CLOCK_WARNING_2",
      "ALARM_CLOCK_WARNING_3",
   }
   local RANGE_SOUNDS = {
      NONE = "None",
      RAID_WARNING = "Raid Warning",
      UI_RAID_BOSS_WHISPER_WARNING = "Boss Whisper",
      READY_CHECK = "Ready Check",
      LFG_ROLE_CHECK = "Role Check",
      PVP_THROUGH_QUEUE = "PvP Queue Ready",
      IG_PLAYER_INVITE = "Group Invite",
      TELL_MESSAGE = "Whisper",
      MAP_PING = "Map Ping",
      ALARM_CLOCK_WARNING_1 = "Alarm Clock 1",
      ALARM_CLOCK_WARNING_2 = "Alarm Clock 2",
      ALARM_CLOCK_WARNING_3 = "Alarm Clock 3",
   }

   -- Sounds that addons share through LibSharedMedia (saved as "lsm:<name>"), listed after the game's own.
   local LSM = LibStub("LibSharedMedia-3.0")
   local LSM_PREFIX = "lsm:"
   local LSM_NONE = "None" -- LibSharedMedia's own silent entry, which would repeat ours

   local function SharedSoundName(key)
      return type(key) == "string" and key:sub(1, #LSM_PREFIX) == LSM_PREFIX and key:sub(#LSM_PREFIX + 1) or nil
   end

   -- nil if it isn't a shared sound, or isn't registered (yet)
   local function SharedSoundFile(key)
      local name = SharedSoundName(key)
      return name and LSM:Fetch("sound", name, true)
   end

   -- the names of the shared sounds to list, sorted
   local function SharedSoundNames()
      local names = {}
      for _, name in ipairs(LSM:List("sound")) do
         if name ~= LSM_NONE then
            table.insert(names, name)
         end
      end
      return names
   end

   local MIN_FONT_SIZE, MAX_FONT_SIZE = 12, 40
   local DEFAULT_FONT_SIZE = 22

   local DEFAULTS = {
      profile = {
         strata = DEFAULT_STRATA,
         -- the statuses' text: a font's name in LibSharedMedia (the default is the game's standard font, Friz
         -- Quadrata TT, or the client's own where Friz Quadrata can't write its language)
         font = LSM:GetDefault("font"),
         fontSize = DEFAULT_FONT_SIZE,
         enableCombat = true,
         enableFlight = true,
         enablePhase = true,
         enableRange = true, -- off hides the range indicator & its sound, but keeps its settings
         alwaysShowPhase = false, -- show "Present" in zones that have no Zidormi phase (else hide the rectangle)
         reverse = false, -- stack the statuses top to bottom instead of bottom to top
         horizontal = false, -- line the statuses up side by side instead of stacking them
         separateFrames = false, -- give each status its own movable frame instead of stacking them
         hideIcons = false,
         hideFlightInCombat = false,
         hidePhaseInCombat = false,
         hideWithMap = false, -- hide the statuses & the range indicator while the world map is open
         -- the stack's center, as an offset from the center of the screen (the default is dead center)
         x = 0,
         y = 0,
         -- each status's center while they're on separate frames (the default is a stack around the screen's center)
         combatX = 0,
         combatY = -76,
         flightX = 0,
         flightY = 0,
         phaseX = 0,
         phaseY = 76,
         stateColors = {}, -- each state's background, by state (filled in below)
         -- the range indicator (the Range tab)
         rangeSpell = "", -- the name of the spell whose range is checked (blank hides the indicator)
         rangeSound = "NONE", -- a key of RANGE_SOUNDS, or "lsm:<name>" for a shared sound
         rangeScale = 1,
         rangeX = 0, -- its center, as an offset from the center of the screen (just below the statuses)
         rangeY = -150,
         rangeCross = false, -- draw a scope cross over it
         rangeCrossColor = { r = 1, g = 1, b = 1 },
         rangeCrossScale = 1, -- on top of the indicator's own scale
         rangeHideIcon = false, -- only allowed while the cross is on, so the indicator never draws nothing
         rangeHideInCombat = false,
      },
   }
   for _, stateText in ipairs(STATE_ORDER) do
      DEFAULTS.profile.stateColors[stateText] = CopyTable(DEFAULT_STATE_COLOR)
   end

   local database = LibStub("AceDB-3.0"):New("ObviousStatusesDB", DEFAULTS, true)
   local db = database.profile

   -- saved under its old name before "Dragonriding" became "Flight"
   if database.global.dragonIcon then
      database.global.flightIcon = database.global.dragonIcon
      database.global.dragonIcon = nil
   end

   -- fixes up bad saved values
   local function ValidateSettings()
      if not STRATA[db.strata] then
         db.strata = DEFAULT_STRATA
      end
      -- a font is kept even if its addon hasn't loaded yet (or is gone); the default stands in until it's registered
      if type(db.font) ~= "string" or db.font == "" then
         db.font = DEFAULTS.profile.font
      end
      db.fontSize = Clamp(math.floor((tonumber(db.fontSize) or DEFAULT_FONT_SIZE) + 0.5), MIN_FONT_SIZE, MAX_FONT_SIZE)
      db.enableCombat = db.enableCombat ~= false
      db.enableFlight = db.enableFlight ~= false
      db.enablePhase = db.enablePhase ~= false
      db.enableRange = db.enableRange ~= false
      db.alwaysShowPhase = db.alwaysShowPhase == true
      db.reverse = db.reverse == true
      db.horizontal = db.horizontal == true
      db.separateFrames = db.separateFrames == true
      for _, key in ipairs({ "combatX", "combatY", "flightX", "flightY", "phaseX", "phaseY" }) do
         db[key] = tonumber(db[key]) or DEFAULTS.profile[key]
      end
      local stateColors = type(db.stateColors) == "table" and db.stateColors or {}
      db.stateColors = {}
      for _, stateText in ipairs(STATE_ORDER) do
         local color = type(stateColors[stateText]) == "table" and stateColors[stateText] or {}
         db.stateColors[stateText] = {
            r = Clamp(tonumber(color.r) or DEFAULT_STATE_COLOR.r, 0, 1),
            g = Clamp(tonumber(color.g) or DEFAULT_STATE_COLOR.g, 0, 1),
            b = Clamp(tonumber(color.b) or DEFAULT_STATE_COLOR.b, 0, 1),
         }
      end
      db.hideIcons = db.hideIcons == true
      -- saved under its old name before "Dragonriding" became "Flight" (each profile moves over once it's used)
      if db.hideDragonInCombat ~= nil then
         db.hideFlightInCombat = db.hideDragonInCombat
         db.hideDragonInCombat = nil
      end
      db.hideFlightInCombat = db.hideFlightInCombat == true
      db.hidePhaseInCombat = db.hidePhaseInCombat == true
      db.hideWithMap = db.hideWithMap == true
      db.x = tonumber(db.x) or 0
      db.y = tonumber(db.y) or 0
      db.rangeSpell = type(db.rangeSpell) == "string" and strtrim(db.rangeSpell) or ""
      -- a shared sound is kept even if its addon hasn't loaded yet (or is gone); it's silent until it's registered
      if not RANGE_SOUNDS[db.rangeSound] and not SharedSoundName(db.rangeSound) then
         db.rangeSound = DEFAULTS.profile.rangeSound
      end
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
      db.rangeHideInCombat = db.rangeHideInCombat == true
   end

   ValidateSettings()

   --## ==========================================================================
   --## STATUSES
   --## ==========================================================================
   -- The look follows Material UI's dark theme: each status is a pill-shaped chip with a round icon, on a
   -- rounded, shadowed Paper (the background), spaced on an 8-unit grid.
   local PADDING = 8 -- above & below the text, inside each rectangle
   local PADDING_X = 18 -- left & right of the text, inside each rectangle (its rounded ends need the room)
   local SPACING = 8 -- between the rectangles
   local ICON_SPACING = 8 -- between a rectangle's icon and its text
   local ICON_GROWTH = 4 -- how much taller the icons are than the text
   local BACKGROUND_PADDING = 8 -- between the rectangles and the edge of the background behind them
   -- the background's color: Material's dark Paper at elevation 3 (#121212 under an 8% white overlay)
   local PAPER_COLOR = { 0x25 / 255, 0x25 / 255, 0x25 / 255, 1 }
   -- The background's drop shadow: layers of see-through black behind it, each one unit bigger than the last, so
   -- it fades out from the edge. It's shifted down a little, as if lit from above.
   local SHADOW_LAYERS = 5
   local SHADOW_ALPHA = 0.06 -- of each layer (they add up toward the edge)
   local SHADOW_OFFSET = 2 -- how far down it's shifted
   -- a round mask (anti-aliased) that cuts the rounded corners & the round icons
   local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
   local ROUND_ICON_COORDS = { 0.08, 0.92, 0.08, 0.92 } -- crops a square icon's border off before it's made round
   local SKYRIDING_AURA = "Flight Style: Skyriding"
   -- WoW Forever has no flying & no Zidormi, so only the combat status is shown there (and the options for the
   -- other two are hidden)
   local FLIGHT_AND_PHASE_SUPPORTED = not UWU.IS_FOREVER

   -- Zones where Zidormi can send you to the past, keyed by uiMapID. Zidormi has no API, so a zone is "in the
   -- past" when either of these is true (set whichever one the zone allows):
   --    pastAura   = the spell name or ID of the aura she gives you (some zones, like Dustwallow Marsh, have none)
   --    pastArtID  = the zone's C_Map.GetMapArtID() while you're in the past
   -- A zone that isn't listed has no phase. Use "/os debug" in each zone, in both states, to find the values:
   --    [<uiMapID>] = { pastAura = <name or spell ID>, pastArtID = <art ID> },
   local PHASE_ZONES = {}

   -- The icon for each state of the combat & phase rectangles. `coords` crops the texture, `color` tints it
   -- (a white texture takes the color well, so those are desaturated first), and `round` crops a square icon's
   -- border off and makes it round. The flight rectangle uses the Skyriding aura's own icon instead.
   local ICONS = {
      -- crossed swords, cropped to the swords (the texture has a lot of empty space around them)
      Fighting = { texture = "Interface\\CharacterFrame\\UI-StateIcon", coords = { 0.56, 0.92, 0.06, 0.43 } },
      Roaming = { texture = 132540, round = true }, -- a file ID
      Past = { texture = "Interface\\Icons\\INV_Misc_PocketWatch_01", round = true }, -- a pocket watch
      Present = { -- a green arrow, a little bigger than the other icons
         texture = "Interface\\ChatFrame\\ChatFrameExpandArrow",
         desaturated = true,
         color = { 0.2, 1, 0.2 },
         extraSize = 2,
      },
   }
   local STEADY_AURA = "Flight Style: Steady"
   local FLIGHT_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark" -- if no icon can be found at all

   local frame = CreateFrame("Frame", "UWUObviousStatusesFrame", UIParent)

   -- A rounded rectangle, drawn on `parent`'s `layer`. The game has no such shape, so it's pieced together from
   -- plain textures: a cross of three rectangles, with a quarter circle (cut out by the round mask) in each
   -- corner. None of the pieces overlap, so a see-through color stays even all over.
   -- Snapping each piece to whole pixels on its own could leave a pixel's gap or notch where they meet, as
   -- their sizes are often fractional
   local function StopPixelSnapping(region)
      if region.SetSnapToPixelGrid then
         region:SetSnapToPixelGrid(false)
         region:SetTexelSnappingBias(0)
      end
   end

   local function CreateRoundedRect(parent, layer, subLevel)
      local shape = { strips = {}, corners = {} }
      for i = 1, 3 do -- the middle, then the left & right strips between the corners
         shape.strips[i] = parent:CreateTexture(nil, layer, nil, subLevel)
         StopPixelSnapping(shape.strips[i])
      end
      for i = 1, 4 do
         local corner = parent:CreateTexture(nil, layer, nil, subLevel)
         corner.mask = parent:CreateMaskTexture()
         corner.mask:SetTexture(CIRCLE_MASK)
         corner:AddMaskTexture(corner.mask)
         StopPixelSnapping(corner)
         StopPixelSnapping(corner.mask)
         shape.corners[i] = corner
      end

      function shape.SetColor(r, g, b, a)
         for _, strip in ipairs(shape.strips) do
            strip:SetColorTexture(r, g, b, a)
         end
         for _, corner in ipairs(shape.corners) do
            corner:SetColorTexture(r, g, b, a)
         end
      end

      local function Apply(region, wantedRadius, grow, down)
         local height = region:GetHeight()
         -- up to half its height, which makes the ends fully round
         local radius = math.min(wantedRadius, height / 2 + grow)
         local left, right, top, bottom = -grow, grow, grow - down, -grow - down
         local middle, leftStrip, rightStrip = unpack(shape.strips)

         middle:ClearAllPoints()
         middle:SetPoint("TOPLEFT", region, "TOPLEFT", left + radius, top)
         middle:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", right - radius, bottom)

         -- with fully round ends, the strips between the corners have no height left
         local hasStrips = radius < height / 2 + grow - 0.01
         leftStrip:ClearAllPoints()
         leftStrip:SetPoint("TOPLEFT", region, "TOPLEFT", left, top - radius)
         leftStrip:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT", left + radius, bottom + radius)
         leftStrip:SetShown(hasStrips)
         rightStrip:ClearAllPoints()
         rightStrip:SetPoint("TOPLEFT", region, "TOPRIGHT", right - radius, top - radius)
         rightStrip:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", right, bottom + radius)
         rightStrip:SetShown(hasStrips)

         -- each corner shows one quarter of a circle the size of two corners
         local spots = {
            { "TOPLEFT", left, top },
            { "TOPRIGHT", right, top },
            { "BOTTOMLEFT", left, bottom },
            { "BOTTOMRIGHT", right, bottom },
         }
         for i, corner in ipairs(shape.corners) do
            local point, x, y = unpack(spots[i])
            corner:ClearAllPoints()
            corner:SetPoint(point, region, point, x, y)
            corner:SetSize(radius, radius)
            corner.mask:ClearAllPoints()
            corner.mask:SetPoint(point, region, point, x, y)
            corner.mask:SetSize(radius * 2, radius * 2)
         end
      end

      -- Covers `region`, grown by `grow` on every side and shifted down by `down`, with corners of `radius`. It's
      -- anchored to `region`, and redone whenever the region is resized (its height decides whether the ends
      -- are fully round).
      function shape.Layout(region, radius, grow, down)
         grow, down = grow or 0, down or 0
         shape.region, shape.radius, shape.grow, shape.down = region, radius, grow, down
         if not shape.hooked then
            shape.hooked = true
            region:HookScript("OnSizeChanged", function()
               Apply(shape.region, shape.radius, shape.grow, shape.down)
            end)
         end
         Apply(region, radius, grow, down)
      end

      return shape
   end

   -- A Material Paper to put rectangles on: an opaque, rounded background with a soft drop shadow. It's laid out
   -- by LayoutPaper, once the rectangles' height is known.
   local function CreatePaperFrame(name, parent)
      local paperFrame = CreateFrame("Frame", name, parent)
      paperFrame.shadowLayers = {}
      for i = 1, SHADOW_LAYERS do
         local layer = CreateRoundedRect(paperFrame, "BACKGROUND", -8)
         layer.SetColor(0, 0, 0, SHADOW_ALPHA)
         paperFrame.shadowLayers[i] = layer
      end
      paperFrame.paper = CreateRoundedRect(paperFrame, "BACKGROUND", 0)
      paperFrame.paper.SetColor(unpack(PAPER_COLOR))
      return paperFrame
   end

   -- The background behind the stacked rectangles. It's only as tall as the rectangles that are showing; the
   -- frame it sits in keeps the whole stack's size.
   local background = CreatePaperFrame(nil, frame)

   -- Each status's own frame, used instead of the stack while "Separate" is on. The rectangles move
   -- between the two, and the stack's `frame` stays around for the events.
   local STATUS_ORDER = { "combat", "flight", "phase" } -- the same order as `rectangles`
   local STATUS_TITLES = { combat = "Combat", flight = "Flight", phase = "Phase" }
   local separateFrames = {}
   for i, key in ipairs(STATUS_ORDER) do
      separateFrames[i] = CreatePaperFrame("UWUObviousStatuses" .. STATUS_TITLES[key] .. "Frame", UIParent)
   end

   local function ApplyStatusesStrata()
      frame:SetFrameStrata(db.strata)
      for _, separateFrame in ipairs(separateFrames) do
         separateFrame:SetFrameStrata(db.strata)
      end
   end

   ApplyStatusesStrata()

   -- with only the combat status (WoW Forever), there's nothing to put on separate frames
   local function IsSeparate()
      return FLIGHT_AND_PHASE_SUPPORTED and db.separateFrames
   end

   local function CreateRectangle(texts)
      local rectangle = CreateFrame("Frame", nil, background)
      rectangle.background = CreateRoundedRect(rectangle, "BACKGROUND", 0) -- laid out once its height is known

      rectangle.icon = rectangle:CreateTexture(nil, "ARTWORK")
      rectangle.iconMask = rectangle:CreateMaskTexture() -- for round icons
      rectangle.iconMask:SetTexture(CIRCLE_MASK)
      rectangle.iconMask:SetAllPoints(rectangle.icon)

      local label = rectangle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      label:SetTextColor(1, 1, 1, 1)
      label:SetJustifyH("LEFT")
      rectangle.label = label
      rectangle.texts = texts -- every text it can show, to measure (see ApplyFont)
      return rectangle
   end

   -- bottom to top
   local combat = CreateRectangle({ "Fighting", "Roaming" })
   local flight = CreateRectangle({ "Dragon", "Steady" })
   local phase = CreateRectangle({ "Past", "Present" })
   local rectangles = { combat, flight, phase }

   -- the sizes that follow from the font (see ApplyFont), and the rectangles' width (see ApplySize)
   local maxTextWidth, textHeight, iconSize, rectangleHeight, backgroundRadius = 0, 0, 0, 0, 0
   local rectangleWidth

   local function LayoutPaper(paperFrame)
      paperFrame.paper.Layout(paperFrame, backgroundRadius)
      for i, layer in ipairs(paperFrame.shadowLayers) do
         layer.Layout(paperFrame, backgroundRadius + i, i, SHADOW_OFFSET)
      end
   end

   -- Sets the text's font & size (from the States tab), then measures it: every rectangle is as wide as the widest
   -- text of any of them, so a status changing never changes the size. The rectangles' height, and so how round
   -- everything is, follows from the text's.
   local function ApplyFont()
      maxTextWidth, textHeight = 0, 0
      for _, rectangle in ipairs(rectangles) do
         local label = rectangle.label
         label:SetFont(LSM:Fetch("font", db.font), db.fontSize, "")
         for _, text in ipairs(rectangle.texts) do
            label:SetText(text)
            maxTextWidth = math.max(maxTextWidth, label:GetStringWidth())
            textHeight = math.max(textHeight, label:GetStringHeight())
         end
      end

      iconSize = textHeight + ICON_GROWTH
      rectangleHeight = textHeight + PADDING * 2

      -- The rectangles are pills (their ends fully round), and each background's corners curve around them,
      -- the same distance away all the way round.
      backgroundRadius = rectangleHeight / 2 + BACKGROUND_PADDING
      for _, rectangle in ipairs(rectangles) do
         rectangle.background.Layout(rectangle, rectangleHeight / 2)
      end
      LayoutPaper(background)
      for _, separateFrame in ipairs(separateFrames) do
         LayoutPaper(separateFrame)
      end
   end

   ApplyFont()

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

   -- Left to right: icon (a little taller than the text, centered in the rounded left end, like a Material
   -- chip's), spacing, text (left-aligned), padding. An icon that's bigger than that grows around its center,
   -- so the text stays put. Without icons, the rectangles are just the text & its padding.
   local function ApplySize()
      local iconCenter = rectangleHeight / 2
      local textLeft = PADDING_X
      if not db.hideIcons then
         textLeft = iconCenter + iconSize / 2 + ICON_SPACING
      end

      rectangleWidth = textLeft + maxTextWidth + PADDING_X
      for _, rectangle in ipairs(rectangles) do
         rectangle:SetSize(rectangleWidth, rectangleHeight)
         rectangle.icon:ClearAllPoints()
         rectangle.icon:SetPoint("CENTER", rectangle, "LEFT", iconCenter, 0)
         rectangle.label:ClearAllPoints()
         rectangle.label:SetPoint("LEFT", textLeft, 0)
      end

      frame:SetSize(GetBackgroundSize(FLIGHT_AND_PHASE_SUPPORTED and #rectangles or 1))
   end

   local state = {
      inCombat = InCombatLockdown(),
      skyriding = false,
      phase = nil, -- "Past", "Present", or nil when this zone has no phase
      mapOpen = false, -- the world map is showing
   }

   -- "Hide When Map Is Open" hides everything, the range indicator too
   local function IsHiddenByMap()
      return db.hideWithMap and state.mapOpen
   end

   local function MoveRectangleTo(rectangle, parent)
      if rectangle:GetParent() ~= parent then
         rectangle:SetParent(parent)
         rectangle:SetFrameLevel(parent:GetFrameLevel() + 1)
      end
   end

   -- The visible rectangles stack up from the bottom (or line up from the left, if horizontal) with no gaps,
   -- combat first, so hiding one shrinks the stack toward that edge. Reversed, it's the mirror image: they hang
   -- from the top (or line up from the right), combat first, and shrink toward that edge instead.
   local function Layout(visible)
      -- each visible status sits on its own frame, just like a stack of one
      if IsSeparate() then
         background:Hide()
         for i, rectangle in ipairs(rectangles) do
            local separateFrame = separateFrames[i]
            MoveRectangleTo(rectangle, separateFrame)
            rectangle:ClearAllPoints()
            rectangle:SetPoint("CENTER", separateFrame)
            rectangle:Show()
            separateFrame:SetSize(GetBackgroundSize(1))
            separateFrame:SetShown(visible[i])
         end
         return
      end

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
         separateFrames[i]:Hide()
         MoveRectangleTo(rectangle, background)
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
      background:SetShown(count > 0) -- with every status disabled, nothing is left to draw or to take the mouse
   end

   local function SetIcon(rectangle, icon)
      local round = icon.round == true
      local coords = icon.coords or (round and ROUND_ICON_COORDS) or { 0, 1, 0, 1 }
      local color = icon.color or { 1, 1, 1 }
      if round ~= rectangle.isIconRound then
         rectangle.isIconRound = round
         if round then
            rectangle.icon:AddMaskTexture(rectangle.iconMask)
         else
            rectangle.icon:RemoveMaskTexture(rectangle.iconMask)
         end
      end
      local size = iconSize + (icon.extraSize or 0)
      rectangle.icon:SetSize(size, size)
      rectangle.icon:SetShown(not db.hideIcons)
      rectangle.icon:SetTexture(icon.texture)
      rectangle.icon:SetTexCoord(unpack(coords))
      rectangle.icon:SetDesaturated(icon.desaturated == true)
      rectangle.icon:SetVertexColor(color[1], color[2], color[3])
   end

   -- each state has its own background color, picked on the States tab
   local function SetBackgroundColor(rectangle, stateText)
      local color = db.stateColors[stateText]
      rectangle.background.SetColor(color.r, color.g, color.b, 1)
   end

   local function Refresh()
      ApplySize() -- the icons being hidden changes the width

      local combatText = state.inCombat and "Fighting" or "Roaming"
      local phaseText = state.phase or "Present"
      local flightText = state.skyriding and "Dragon" or "Steady"
      combat.label:SetText(combatText)
      SetIcon(combat, ICONS[combatText])
      SetBackgroundColor(combat, combatText)
      phase.label:SetText(phaseText)
      SetIcon(phase, ICONS[phaseText])
      SetBackgroundColor(phase, phaseText)

      -- the Skyriding aura's icon, at full strength whether or not it's on
      flight.label:SetText(flightText)
      SetIcon(flight, { texture = state.flightIcon or FLIGHT_FALLBACK_ICON, round = true })
      SetBackgroundColor(flight, flightText)

      local shown = not IsHiddenByMap()
      Layout({
         shown and db.enableCombat,
         shown and FLIGHT_AND_PHASE_SUPPORTED and db.enableFlight and not (state.inCombat and db.hideFlightInCombat),
         shown and FLIGHT_AND_PHASE_SUPPORTED and db.enablePhase and state.phase ~= nil
            and not (state.inCombat and db.hidePhaseInCombat),
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
   local function GetFlightIcon(aura)
      local icon = aura and (aura.icon or (aura.spellId and C_Spell.GetSpellTexture(aura.spellId)))
      if icon then
         database.global.flightIcon = icon
         return icon
      end

      local steady = C_UnitAuras.GetAuraDataBySpellName("player", STEADY_AURA)
      return database.global.flightIcon or C_Spell.GetSpellTexture(SKYRIDING_AURA) or (steady and steady.icon)
   end

   local function UpdateAll()
      state.inCombat = InCombatLockdown()
      if FLIGHT_AND_PHASE_SUPPORTED then
         local aura = C_UnitAuras.GetAuraDataBySpellName("player", SKYRIDING_AURA)
         state.skyriding = aura ~= nil
         state.flightIcon = GetFlightIcon(aura)
         UpdatePhase()
      end
      Refresh()
   end

   frame:RegisterEvent("PLAYER_ENTERING_WORLD")
   frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
   frame:RegisterEvent("ZONE_CHANGED")
   frame:RegisterEvent("ZONE_CHANGED_INDOORS")
   frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- entering combat
   frame:RegisterEvent("PLAYER_REGEN_ENABLED") -- leaving combat
   if FLIGHT_AND_PHASE_SUPPORTED then
      frame:RegisterUnitEvent("UNIT_AURA", "player") -- the Skyriding & Zidormi auras
   end
   frame:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" then
         state.inCombat = true
         Refresh()
      elseif event == "PLAYER_REGEN_ENABLED" then
         state.inCombat = false
         Refresh()
      else
         UpdateAll()
      end
   end)

   UpdateAll()

   -- a font from another addon may only get registered after we've loaded
   LSM.RegisterCallback(frame, "LibSharedMedia_Registered", function(_, mediaType, name)
      if mediaType == "font" and name == db.font then
         ApplyFont()
         Refresh()
      end
   end)

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

   local separatePlacements = {} -- by status key
   for i, key in ipairs(STATUS_ORDER) do
      local placement = CreatePlacement(separateFrames[i], key .. "X", key .. "Y")
      placement.Apply()
      placement.EnableDragging(separateFrames[i], "Obvious Statuses: " .. STATUS_TITLES[key])
      separatePlacements[key] = placement
   end

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

   -- `soundKey` is a key of RANGE_SOUNDS or a shared sound's, played on the Sound Effects channel
   local function PlayRangeSound(soundKey)
      local soundKit = SOUNDKIT[soundKey] -- nil for "None" & shared sounds
      local sharedFile = SharedSoundFile(soundKey)
      if soundKit then
         PlaySound(soundKit, "SFX")
      elseif sharedFile then
         PlaySoundFile(sharedFile, "SFX")
      end
   end

   local lastInRange -- the last check's result, to tell when the same target comes into range

   local function RefreshRange()
      local spell = GetRangeSpell()
      if not spell then
         lastInRange = nil
         SetRangeIcon(RANGE_ICONS.unknownSpell)
         return
      end

      local inRange = IsTargetInRange(spell.spellID)
      if inRange and lastInRange == false then
         PlayRangeSound(db.rangeSound)
      end
      lastInRange = inRange

      if inRange == nil then
         SetRangeIcon(spell.iconID, true) -- the spell's own icon, greyed out, until there's something to check
      elseif inRange then
         SetRangeIcon(RANGE_ICONS.inRange, false, RANGE_TINTS.inRange)
      else
         SetRangeIcon(RANGE_ICONS.outOfRange, false, RANGE_TINTS.outOfRange)
      end
   end

   local function UpdateRangeShown()
      -- hidden, its checks & sound stop too
      rangeFrame:SetShown(
         db.enableRange and db.rangeSpell ~= "" and not (state.inCombat and db.rangeHideInCombat)
            and not IsHiddenByMap()
      )
      lastInRange = nil -- a different spell has a different range, so this isn't the target coming into range
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

   -- a new target shows straight away, instead of on the next check (and is silent if it's already in range)
   rangeFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
   -- entering & leaving combat, for "Hide in Combat" (the statuses' frame sets the same state, in whichever order
   -- the two frames get the event)
   rangeFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
   rangeFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
   rangeFrame:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
         state.inCombat = event == "PLAYER_REGEN_DISABLED"
         UpdateRangeShown()
         return
      end

      lastInRange = nil
      RefreshRange()
   end)

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
   --## WORLD MAP (for "Hide When Map Is Open")
   --## ==========================================================================
   local function SetMapOpen(isOpen)
      state.mapOpen = isOpen
      if db.hideWithMap then
         Refresh()
         UpdateRangeShown()
      end
   end

   local function WatchWorldMap()
      WorldMapFrame:HookScript("OnShow", function()
         SetMapOpen(true)
      end)
      WorldMapFrame:HookScript("OnHide", function()
         SetMapOpen(false)
      end)
      SetMapOpen(WorldMapFrame:IsShown())
   end

   -- the world map is load-on-demand, so it may not exist yet
   if WorldMapFrame then
      WatchWorldMap()
   else
      local mapLoader = CreateFrame("Frame")
      mapLoader:RegisterEvent("ADDON_LOADED")
      mapLoader:SetScript("OnEvent", function(self, _, loadedAddonName)
         if loadedAddonName == "Blizzard_WorldMap" then
            self:UnregisterEvent("ADDON_LOADED")
            WatchWorldMap()
         end
      end)
   end

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

   -- a regular Ace button with big, outlined text, so the nudge buttons' "+" & "-" are easy to read
   local LARGE_TEXT_BUTTON_WIDGET = "UWU-LargeTextButton"

   LibStub("AceGUI-3.0"):RegisterWidgetType(LARGE_TEXT_BUTTON_WIDGET, function()
      local widget = LibStub("AceGUI-3.0").WidgetRegistry["Button"]()
      widget.type = LARGE_TEXT_BUTTON_WIDGET -- pooled under our own type when released
      widget.frame:SetNormalFontObject("GameFontNormalHugeOutline")
      widget.frame:SetHighlightFontObject("GameFontHighlightHugeOutline")
      return widget
   end, 1)

   -- Adds the X/Y offsets, nudge, centering & reset options for a placement to `args`, ordered from `order`, with
   -- their keys starting with `prefix` (so several sets can share a tab). `what` names the frame in descriptions,
   -- and `defaultSpot` where Reset Position puts it.
   local function AddPositionOptions(args, prefix, placement, what, defaultSpot, order)
      local function Add(key, option)
         args[prefix .. key] = option
         return option
      end

      Add("XOffset", OffsetInput(placement, what, "x", "X Offset", order))
      Add("YOffset", OffsetInput(placement, what, "y", "Y Offset", order + 1))
      Add("NudgeBreak", LineBreak(order + 9))
      local nudges = {
         Add("XMinus", NudgeButton(placement, "x", -1, order + 10)),
         Add("XPlus", NudgeButton(placement, "x", 1, order + 11)),
         Add("YMinus", NudgeButton(placement, "y", -1, order + 12)),
         Add("YPlus", NudgeButton(placement, "y", 1, order + 13)),
      }
      Add("CenterBreak", LineBreak(order + 19))
      local centerHorizontally = Add("CenterHorizontally", {
         order = order + 20,
         name = "Center Horizontally",
         type = "execute",
         func = function()
            local _, y = placement.Get()
            placement.Set(0, y)
         end,
      })
      local centerVertically = Add("CenterVertically", {
         order = order + 21,
         name = "Center Vertically",
         type = "execute",
         func = function()
            local x = placement.Get()
            placement.Set(x, 0)
         end,
      })
      Add("ResetBreak", LineBreak(order + 29))
      Add("ResetPosition", {
         order = order + 30,
         name = "Reset Position",
         desc = "Move " .. what .. " back to " .. defaultSpot .. ".",
         type = "execute",
         func = placement.Reset,
      })

      for _, nudge in ipairs(nudges) do
         nudge.dialogControl = LARGE_TEXT_BUTTON_WIDGET
      end
      -- these buttons' tooltips would only repeat their labels (any descStyle but "tooltip" turns Ace's off)
      for _, button in ipairs({ centerHorizontally, centerVertically, unpack(nudges) }) do
         button.descStyle = "none"
      end
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

   -- The tab moves the stack, or (while they're on separate frames) whichever status is picked in its dropdown
   local positionedStatus = STATUS_ORDER[1]

   local function GetPositionedPlacement()
      return IsSeparate() and separatePlacements[positionedStatus] or statusesPlacement
   end

   local positionedPlacement = {
      Get = function()
         return GetPositionedPlacement().Get()
      end,
      Set = function(x, y)
         GetPositionedPlacement().Set(x, y)
      end,
      Reset = function()
         GetPositionedPlacement().Reset()
      end,
   }

   local function HideWithoutSeparateFrames()
      return not IsSeparate()
   end

   local statusBreak = LineBreak(4)
   statusBreak.hidden = HideWithoutSeparateFrames

   -- the statuses' position options, then the range indicator's (added just below), each under a header
   local positioningOptions = {
      name = "Positioning",
      type = "group",
      order = 3,
      args = AddPositionOptions({
         intro = {
            order = 1,
            name = "Position the statuses and the range indicator precisely, relative to the center of the "
               .. "screen. You can also hold Shift and drag them with the left mouse button.",
            type = "description",
            width = "full",
         },
         statesHeader = {
            order = 2,
            name = "States",
            type = "header",
         },
         status = {
            order = 3,
            name = "Status",
            desc = "Which status's frame these options move.",
            type = "select",
            values = STATUS_TITLES,
            sorting = STATUS_ORDER,
            hidden = HideWithoutSeparateFrames,
            get = function()
               return positionedStatus
            end,
            set = function(_, value)
               positionedStatus = value
            end,
         },
         statusBreak = statusBreak,
         rangeHeader = {
            order = 50,
            name = "Range",
            type = "header",
         },
      }, "states", positionedPlacement, "the statuses", "their default spot, around the center of the screen", 10),
   }
   AddPositionOptions(
      positioningOptions.args,
      "range",
      rangePlacement,
      "the range indicator",
      "its default spot, just below the center of the screen",
      60
   )

   --## Range tab ---------------------------------------------------------------
   -- A regular Ace dropdown row with a speaker button on its right that samples the row's sound, without
   -- selecting it or closing the list. "None" has nothing to sample, so its row has no button.
   local SOUND_ITEM_WIDGET = "UWU-Dropdown-Item-Sound"

   do
      local AceGUI = LibStub("AceGUI-3.0")

      local function SetPullout(widget, pullout)
         widget.baseSetPullout(widget, pullout)
         -- the row's value is only known by now, not when the row is created
         local value = widget.userdata.value
         widget.speaker:SetShown(SOUNDKIT[value] ~= nil or SharedSoundFile(value) ~= nil)
      end

      local function Speaker_OnClick(speaker)
         PlayRangeSound(speaker.row.userdata.value)
      end

      -- the speaker covers part of its row, so the row stays highlighted while hovering over it
      local function Speaker_OnEnter(speaker)
         local rowFrame = speaker.row.frame
         rowFrame:GetScript("OnEnter")(rowFrame)
      end

      local function Speaker_OnLeave(speaker)
         local rowFrame = speaker.row.frame
         rowFrame:GetScript("OnLeave")(rowFrame)
      end

      AceGUI:RegisterWidgetType(SOUND_ITEM_WIDGET, function()
         local widget = AceGUI.WidgetRegistry["Dropdown-Item-Toggle"]()
         widget.type = SOUND_ITEM_WIDGET -- pooled under our own type when released
         widget.baseSetPullout = widget.SetPullout
         widget.SetPullout = SetPullout

         local speaker = CreateFrame("Button", nil, widget.frame)
         speaker:SetSize(16, 16)
         speaker:SetPoint("RIGHT", widget.frame, "RIGHT", -4, 0)
         speaker:SetNormalTexture("Interface\\Common\\VoiceChat-Speaker")
         speaker:SetHighlightTexture("Interface\\Common\\VoiceChat-On")
         speaker:SetScript("OnClick", Speaker_OnClick)
         speaker:SetScript("OnEnter", Speaker_OnEnter)
         speaker:SetScript("OnLeave", Speaker_OnLeave)
         speaker.row = widget
         widget.speaker = speaker

         widget.text:SetPoint("BOTTOMRIGHT", widget.frame, "BOTTOMRIGHT", -24, 0) -- stops short of the speaker
         return widget
      end, 1)
   end

   -- Ace's option widths are fixed, so these controls set their own to take a share of their row, however wide the
   -- window is resized (or the Options > AddOns page is).
   local HALF_WIDTH_INPUT_WIDGET = "UWU-HalfWidth-EditBox"
   local HALF_WIDTH_SELECT_WIDGET = "UWU-HalfWidth-Dropdown"
   local HALF_WIDTH_TOGGLE_WIDGET = "UWU-HalfWidth-CheckBox"
   local QUARTER_WIDTH_TOGGLE_WIDGET = "UWU-QuarterWidth-CheckBox"
   local THIRD_WIDTH_TOGGLE_WIDGET = "UWU-ThirdWidth-CheckBox"
   local HALF_WIDTH_COLOR_WIDGET = "UWU-HalfWidth-ColorPicker"

   do
      local AceGUI = LibStub("AceGUI-3.0")

      local function RegisterRelativeWidthWidget(widgetType, baseType, share)
         AceGUI:RegisterWidgetType(widgetType, function()
            local widget = AceGUI.WidgetRegistry[baseType]()
            widget.type = widgetType -- pooled under our own type when released

            local baseOnAcquire = widget.OnAcquire
            widget.OnAcquire = function(self)
               baseOnAcquire(self)
               self:SetRelativeWidth(share)
            end
            return widget
         end, 1)
      end

      RegisterRelativeWidthWidget(HALF_WIDTH_INPUT_WIDGET, "EditBox", 0.5)
      RegisterRelativeWidthWidget(HALF_WIDTH_SELECT_WIDGET, "Dropdown", 0.5)
      RegisterRelativeWidthWidget(HALF_WIDTH_TOGGLE_WIDGET, "CheckBox", 0.5)
      RegisterRelativeWidthWidget(QUARTER_WIDTH_TOGGLE_WIDGET, "CheckBox", 0.25)
      RegisterRelativeWidthWidget(THIRD_WIDTH_TOGGLE_WIDGET, "CheckBox", 0.33) -- 3 exact thirds could round past the row
      RegisterRelativeWidthWidget(HALF_WIDTH_COLOR_WIDGET, "ColorPicker", 0.5)
   end

   -- Empty space above a row of options. It's its own widget since Ace's rows have fixed gaps, and an empty
   -- description row would add a whole line of text.
   local SPACER_WIDGET = "UWU-Spacer"
   local SPACER_HEIGHT = 8

   LibStub("AceGUI-3.0"):RegisterWidgetType(SPACER_WIDGET, function()
      local frame = CreateFrame("Frame", nil, UIParent)
      frame:Hide()

      return LibStub("AceGUI-3.0"):RegisterAsWidget({
         type = SPACER_WIDGET,
         frame = frame,
         OnAcquire = function(self)
            self:SetWidth(200)
            self:SetHeight(SPACER_HEIGHT)
         end,
         SetText = function() end, -- Ace sets every description's text & font; this one has none
         SetFontObject = function() end,
      })
   end, 1)

   local rangeOptions = {
      name = "Range",
      type = "group",
      order = 2,
      args = {
         intro = {
            order = 1,
            name = "Shows whether your target is in range of a spell: an open eye under a green tint when it is, "
               .. "and a closed eye under a red tint when it's too far away. With no target (or one the spell can't be cast on), it shows the "
               .. "spell's icon, greyed out. A red question mark means no spell by that name was found.\n\n"
               .. "Hold Shift and drag it with the left mouse button to move it, or use the Positioning tab.\n ",
            type = "description",
            width = "full",
         },
         spell = {
            order = 2,
            name = "Spell",
            desc = "The name of the spell to check your target's range with, e.g. one of your attacks or heals. "
               .. "Leave it blank to hide the range indicator.",
            type = "input",
            dialogControl = HALF_WIDTH_INPUT_WIDGET,
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
         sound = {
            order = 2.5,
            name = "Play Sound",
            desc = "A sound to play when your target comes into range, from the game or shared by your other "
               .. "addons. It stays silent when you select a target that's already in range.",
            type = "select",
            dialogControl = HALF_WIDTH_SELECT_WIDGET,
            itemControl = SOUND_ITEM_WIDGET,
            values = function()
               local labels = CopyTable(RANGE_SOUNDS)
               for _, name in ipairs(SharedSoundNames()) do
                  labels[LSM_PREFIX .. name] = name
               end
               return labels
            end,
            sorting = function()
               local order = CopyTable(RANGE_SOUND_ORDER)
               for _, name in ipairs(SharedSoundNames()) do
                  table.insert(order, LSM_PREFIX .. name)
               end
               return order
            end,
            get = function()
               return db.rangeSound
            end,
            set = function(_, value)
               db.rangeSound = value
               PlayRangeSound(value)
            end,
         },
         hideSpacer = {
            order = 3.4,
            name = "",
            type = "description",
            dialogControl = SPACER_WIDGET,
            width = "full",
         },
         hideInCombat = {
            order = 3.5,
            name = "Hide in Combat",
            desc = "Hide the range indicator (and silence its sound) while you're in combat.",
            type = "toggle",
            dialogControl = HALF_WIDTH_TOGGLE_WIDGET,
            get = function()
               return db.rangeHideInCombat
            end,
            set = function(_, value)
               db.rangeHideInCombat = value
               UpdateRangeShown()
            end,
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
            order = 3.6,
            name = "Hide Icon",
            desc = "Hide the icon & its tint, leaving only the scope cross, which turns green when your target is "
               .. "in range and red when it's too far away. The scope cross has to be on to hide the icon. You can "
               .. "still hold Shift and drag the empty square to move it.",
            type = "toggle",
            dialogControl = HALF_WIDTH_TOGGLE_WIDGET,
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
      },
   }

   -- A label over a group of options, in the same font as the Strata dropdown's, with some space above it. It's
   -- its own widget since Ace's rows have fixed gaps, and a spacer row would add more than this margin.
   local GROUP_LABEL_WIDGET = "UWU-GroupLabel"
   local GROUP_LABEL_TOP_MARGIN = 8

   LibStub("AceGUI-3.0"):RegisterWidgetType(GROUP_LABEL_WIDGET, function()
      local frame = CreateFrame("Frame", nil, UIParent)
      frame:Hide()

      local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      text:SetPoint("TOPLEFT", 0, -GROUP_LABEL_TOP_MARGIN)
      text:SetPoint("TOPRIGHT", 0, -GROUP_LABEL_TOP_MARGIN)
      text:SetJustifyH("LEFT")
      text:SetWordWrap(false)

      return LibStub("AceGUI-3.0"):RegisterAsWidget({
         type = GROUP_LABEL_WIDGET,
         frame = frame,
         OnAcquire = function(self)
            self:SetWidth(200)
            self:SetText("")
         end,
         SetText = function(self, value)
            text:SetText(value)
            self:SetHeight(GROUP_LABEL_TOP_MARGIN + text:GetStringHeight())
         end,
         SetFontObject = function() end, -- Ace sets every description's font; this one keeps its own
      })
   end, 1)

   local function GroupLabel(order, name)
      return {
         order = order,
         name = name,
         type = "description",
         dialogControl = GROUP_LABEL_WIDGET,
         width = "full",
      }
   end

   -- greys out an option that only applies while the statuses are stacked
   local function StackedOnly(option)
      option.disabled = function()
         return db.separateFrames
      end
      return option
   end

   -- hides an option for the flight or phase status, or for arranging several statuses, where only the combat
   -- status exists (WoW Forever)
   local function FlightAndPhaseOnly(option)
      option.hidden = not FLIGHT_AND_PHASE_SUPPORTED
      return option
   end

   -- for an option that applies to the range indicator too, which UpdateAll doesn't redraw
   local function AlsoUpdatesRange(option)
      local set = option.set
      option.set = function(info, value)
         set(info, value)
         UpdateRangeShown()
      end
      return option
   end

   -- one of the row of four checkboxes that turn a feature on or off
   local function EnableCheckbox(order, name, desc, key)
      local option = Checkbox(order, name, desc, key)
      option.width = nil
      option.dialogControl = QUARTER_WIDTH_TOGGLE_WIDGET
      return option
   end

   -- one of the row of three checkboxes that arrange the statuses
   local function LayoutCheckbox(order, name, desc, key)
      local option = Checkbox(order, name, desc, key)
      option.width = nil
      option.dialogControl = THIRD_WIDTH_TOGGLE_WIDGET
      return option
   end

   -- one state's background color, picked in pairs (one row per status)
   local function StateColor(order, stateText, statusTitle)
      return {
         order = order,
         name = stateText,
         desc = "The " .. statusTitle .. " status's background while it shows " .. stateText .. ".",
         type = "color",
         dialogControl = HALF_WIDTH_COLOR_WIDGET,
         get = function()
            local color = db.stateColors[stateText]
            return color.r, color.g, color.b
         end,
         set = function(_, r, g, b)
            local color = db.stateColors[stateText]
            color.r, color.g, color.b = r, g, b
            Refresh()
         end,
      }
   end

   local options = {
      type = "group",
      name = "UwU: Obvious Statuses",
      childGroups = "tab", -- States, Range & Positioning as tabs (in /os and in Options > AddOns)
      args = {
         positioning = positioningOptions,
         range = rangeOptions,
         general = {
            name = "States",
            type = "group",
            order = 1,
            args = {
               enableLabel = GroupLabel(0, "Enable/Disable"),
               enableCombat = EnableCheckbox(
                  0.01,
                  "Combat",
                  "Show the Fighting / Roaming status.",
                  "enableCombat"
               ),
               enableFlight = FlightAndPhaseOnly(EnableCheckbox(
                  0.02,
                  "Flight",
                  "Show the Dragon / Steady status.",
                  "enableFlight"
               )),
               enablePhase = FlightAndPhaseOnly(EnableCheckbox(
                  0.03,
                  "Phase",
                  "Show the Past / Present status.",
                  "enablePhase"
               )),
               enableRange = {
                  order = 0.04,
                  name = "Range",
                  desc = "Show the range indicator and play its sound. While this is off, the Range tab can still "
                     .. "be changed, but its settings have no effect.",
                  type = "toggle",
                  dialogControl = QUARTER_WIDTH_TOGGLE_WIDGET,
                  get = function()
                     return db.enableRange
                  end,
                  set = function(_, value)
                     db.enableRange = value
                     UpdateRangeShown()
                  end,
               },
               layoutLabel = FlightAndPhaseOnly(GroupLabel(0.05, "Layout")),
               separateFrames = FlightAndPhaseOnly(LayoutCheckbox(
                  0.06,
                  "Separate",
                  "Give each status its own frame, which you can hold Shift and drag anywhere (or position on the "
                     .. "Positioning tab), instead of stacking them. They look & behave the same either way.",
                  "separateFrames"
               )),
               reverse = FlightAndPhaseOnly(StackedOnly(LayoutCheckbox(
                  0.07,
                  "Reverse",
                  "Reverse the order of the statuses. Normally combat is at the bottom (or the left, if "
                     .. "Horizontal) & phase is at the top (or the right); reversed, it's the other way around.",
                  "reverse"
               ))),
               horizontal = FlightAndPhaseOnly(StackedOnly(LayoutCheckbox(
                  0.08,
                  "Horizontal",
                  "Line the statuses up side by side, combat on the left, instead of stacking them. "
                     .. "Works with Reverse.",
                  "horizontal"
               ))),
               font = {
                  order = 0.0802,
                  name = "Font",
                  desc = "The statuses' font: the game's own, plus any your other addons share through "
                     .. "LibSharedMedia.",
                  type = "select",
                  dialogControl = "LSM30_Font",
                  values = AceGUIWidgetLSMlists.font,
                  get = function()
                     return db.font
                  end,
                  set = function(_, value)
                     db.font = value
                     ApplyFont()
                     Refresh()
                  end,
               },
               fontSize = {
                  order = 0.0803,
                  name = "Size",
                  desc = "The statuses' text size. The statuses grow & shrink to fit it.",
                  type = "range",
                  min = MIN_FONT_SIZE,
                  max = MAX_FONT_SIZE,
                  step = 1,
                  get = function()
                     return db.fontSize
                  end,
                  set = function(_, value)
                     db.fontSize = value
                     ApplyFont()
                     Refresh()
                  end,
               },
               colorsLabel = GroupLabel(0.081, "Colors"),
               roamingColor = StateColor(0.082, "Roaming", "Combat"),
               fightingColor = StateColor(0.083, "Fighting", "Combat"),
               dragonColor = FlightAndPhaseOnly(StateColor(0.084, "Dragon", "Flight")),
               steadyColor = FlightAndPhaseOnly(StateColor(0.085, "Steady", "Flight")),
               presentColor = FlightAndPhaseOnly(StateColor(0.086, "Present", "Phase")),
               pastColor = FlightAndPhaseOnly(StateColor(0.087, "Past", "Phase")),
               visibilityLabel = GroupLabel(0.09, "Visibility"),
               alwaysShowPhase = FlightAndPhaseOnly(Checkbox(
                  1,
                  "Always Show Phase",
                  "Show \"Present\" in zones that Zidormi can't send you to the past in. "
                     .. "When unchecked, the phase status is hidden there.",
                  "alwaysShowPhase"
               )),
               hideFlightInCombat = FlightAndPhaseOnly(Checkbox(
                  2,
                  "Hide Flight in Combat",
                  "Hide the Dragon / Steady status while you're in combat.",
                  "hideFlightInCombat"
               )),
               hidePhaseInCombat = FlightAndPhaseOnly(Checkbox(
                  3,
                  "Hide Phase in Combat",
                  "Hide the Past / Present status while you're in combat.",
                  "hidePhaseInCombat"
               )),
               hideWithMap = AlsoUpdatesRange(Checkbox(
                  3.5,
                  "Hide When Map Is Open",
                  "Hide the statuses and the range indicator while the world map is open.",
                  "hideWithMap"
               )),
               hideIcons = Checkbox(
                  4,
                  "Hide Icons",
                  "Hide the icons to the left of each status. The statuses get narrower to fit.",
                  "hideIcons"
               ),
               strata = {
                  order = 5,
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
                     ApplyStatusesStrata()
                     ApplyRangeStrata()
                  end,
               },
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
      ApplyFont()
      ApplyStatusesStrata()
      statusesPlacement.Apply()
      for _, placement in pairs(separatePlacements) do
         placement.Apply()
      end
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
   aceConfigDialog:SetDefaultSize(APP_NAME, 440, 650) -- tall enough for the Range & Positioning tabs to fit without scrolling

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
