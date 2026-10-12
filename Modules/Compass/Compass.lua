-- Wrapped as an Unusual WoW Utils module: this only runs when "Compass" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("Compass", function()
   local addonName = "Compass"

   local DEFAULT_COLOR = { r = 0, g = 0, b = 0, a = 0.5 } -- semi-transparent black
   local DEFAULT_SCALE = 1
   local MIN_SCALE, MAX_SCALE = 0.5, 3

   -- Settings live in a profile of our own saved variables (CompassDB), so they can be switched,
   -- copied & reset on the Profiles tab. `db` is always the current profile.
   local DEFAULT_STYLE = "bars"
   local STYLES = { dial = "Dial", bars = "Bars" }
   local STYLE_ORDER = { "bars", "dial" }

   local database = LibStub("AceDB-3.0"):New("CompassDB", {
      profile = {
         hidden = false,
         scale = DEFAULT_SCALE,
         style = DEFAULT_STYLE,
         color = DEFAULT_COLOR,
         hideBackground = false,
         hideBorder = false,
         invertBars = false,
         hideInCombat = false,
         hideDegrees = false,
         -- the compass's center, as an offset from the center of the screen (the default is dead center)
         x = 0,
         y = 0,
      },
   }, true)
   local db = database.profile

   -- settings from before profiles existed (kept in UwU's settings) become the first profile's
   if UWU.db.compass then
      for key, value in pairs(UWU.db.compass) do
         db[key] = type(value) == "table" and CopyTable(value) or value
      end
      UWU.db.compass = nil
   end

   -- fixes up bad saved values
   local function ValidateSettings()
      if type(db.scale) ~= "number" then
         db.scale = DEFAULT_SCALE
      end
      db.scale = Clamp(db.scale, MIN_SCALE, MAX_SCALE)

      if not STYLES[db.style] then
         db.style = DEFAULT_STYLE
      end

      db.hidden = db.hidden == true
      db.hideBackground = db.hideBackground == true
      db.hideBorder = db.hideBorder == true
      db.invertBars = db.invertBars == true
      db.hideInCombat = db.hideInCombat == true
      db.hideDegrees = db.hideDegrees == true
      db.x = tonumber(db.x) or 0
      db.y = tonumber(db.y) or 0

      if type(db.color) ~= "table" then
         db.color = CopyTable(DEFAULT_COLOR)
      end
   end

   ValidateSettings()

   --## ==========================================================================
   --## HUD
   --## ==========================================================================
   local SIZE = 140
   local RING_RADIUS = 50

   -- the 8 headings drawn on the ring, as a bearing in degrees clockwise from north
   local HEADINGS = {
      { label = "N", bearing = 0, major = true },
      { label = "NE", bearing = 45 },
      { label = "E", bearing = 90, major = true },
      { label = "SE", bearing = 135 },
      { label = "S", bearing = 180, major = true },
      { label = "SW", bearing = 225 },
      { label = "W", bearing = 270, major = true },
      { label = "NW", bearing = 315 },
   }

   -- the main directions' letter colors (the in-between ones stay grey)
   local DIRECTION_COLORS = {
      N = { 1, 0.2, 0.2, 1 }, -- red
      W = { 0.3, 0.55, 1, 1 }, -- blue
      E = { 0.2, 0.9, 0.2, 1 }, -- green
      S = { 1, 0.9, 0.1, 1 }, -- yellow
   }

   local frame = CreateFrame("Frame", "UWUCompassFrame", UIParent, "BackdropTemplate")
   frame:SetSize(SIZE, SIZE)
   frame:SetFrameStrata("MEDIUM")
   frame:SetScale(db.scale)
   frame:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", -- rounded corners
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
   })

   local function ApplyColor()
      local backgroundAlpha = db.hideBackground and 0 or db.color.a
      local borderAlpha = db.hideBorder and 0 or math.min(1, db.color.a + 0.3) -- keeps the edge readable
      frame:SetBackdropColor(db.color.r, db.color.g, db.color.b, backgroundAlpha)
      frame:SetBackdropBorderColor(1, 1, 1, borderAlpha)
   end

   ApplyColor()

   --## Position ---------------------------------------------------------------
   -- Saved as the frame's center offset from the screen's center, in screen (UIParent) units
   -- whatever the scale is, so the Positioning tab's X/Y offsets always mean the same thing.
   local function ApplyPosition()
      frame:ClearAllPoints()
      -- anchor offsets are in the frame's own (scaled) units
      frame:SetPoint("CENTER", UIParent, "CENTER", db.x / db.scale, db.y / db.scale)
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
      GameTooltip:SetText("Compass")
      GameTooltip:AddLine("shift+left-mouse to drag", 1, 1, 1)
      GameTooltip:Show()
   end)
   frame:SetScript("OnLeave", GameTooltip_Hide)

   -- the heading marker: fixed at the center, pointing "forward" (up) while the ring turns around it
   local arrow = frame:CreateTexture(nil, "ARTWORK")
   arrow:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")

   -- the heading in degrees, below the arrow
   local degrees = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
   degrees:SetTextColor(1, 1, 1, 1)

   local ringLabels = {}
   for i, heading in ipairs(HEADINGS) do
      local fontObject = heading.major and "GameFontNormalLarge" or "GameFontNormalSmall"
      local label = frame:CreateFontString(nil, "OVERLAY", fontObject)
      label:SetText(heading.label)
      local color = DIRECTION_COLORS[heading.label]
      if color then
         label:SetTextColor(unpack(color))
      elseif not heading.major then
         label:SetTextColor(0.8, 0.8, 0.8, 1)
      end
      ringLabels[i] = label
   end

   -- Bars style: a strip of vertical bars (one every BAR_STEP degrees) that slides sideways as you turn.
   -- The frame is just wide enough for the current heading in the middle & 3 bars on either side.
   local BAR_STEP = 15
   local BARS_SIZE = { width = 400, height = 76 }
   -- the bars are spread to fit 3 on either side of the center, with half a gap to spare at each edge
   local BAR_SPACING = BARS_SIZE.width / 7 -- pixels between bars
   local BARS_HALF_WIDTH = BARS_SIZE.width / 2
   local BARS_FADE_START = BARS_HALF_WIDTH - BAR_SPACING / 2 -- bars & labels fade out over the last half gap
   local BARS_PIXELS_PER_DEGREE = BAR_SPACING / BAR_STEP

   -- Heights (from the middle of the frame) of the letters, the bars' bottom & the degrees. With no
   -- degrees the frame is shorter, & the letters & bars shift down to stay centered in it.
   local function BarsLayout()
      if db.hideDegrees then
         return { height = 54, labelY = 14, bottomY = -20 }
      end
      return { height = BARS_SIZE.height, labelY = 24, bottomY = -10, degreesY = -24 }
   end

   -- smaller lines between the bars, to mark the in-between degrees
   local TICK_STEP = 5
   local TICK_HEIGHT = 8

   local bars = {}
   for bearing = 0, 360 - TICK_STEP, TICK_STEP do
      local isBar = bearing % BAR_STEP == 0
      local isMajor = bearing % 45 == 0 -- the 8 labeled directions get taller, thicker bars
      local bar = frame:CreateTexture(nil, "ARTWORK")
      bar:SetColorTexture(1, 1, 1, 1)
      if isMajor then
         bar:SetSize(2, 24)
         -- matches its letter's color
         for _, heading in ipairs(HEADINGS) do
            if heading.bearing == bearing then
               bar:SetColorTexture(unpack(DIRECTION_COLORS[heading.label] or { 0.8, 0.8, 0.8, 1 }))
            end
         end
      elseif isBar then
         bar:SetSize(1, 14)
      else
         bar:SetSize(1, TICK_HEIGHT)
         bar:SetColorTexture(0.6, 0.6, 0.6, 1) -- the smallest lines are gray
      end
      table.insert(bars, { texture = bar, bearing = bearing })
   end

   -- 1 in the middle of the strip, fading to 0 at its edges
   local function EdgeAlpha(x)
      return Clamp((BARS_HALF_WIDTH - math.abs(x)) / (BARS_HALF_WIDTH - BARS_FADE_START), 0, 1)
   end

   -- a bearing's signed distance (in degrees) from our heading, wrapped to -180..180
   local function OffsetFrom(bearing, heading)
      return (bearing - heading + 180) % 360 - 180
   end

   local function UpdateBars(heading)
      local layout = BarsLayout()

      for _, bar in ipairs(bars) do
         local x = OffsetFrom(bar.bearing, heading) * BARS_PIXELS_PER_DEGREE
         bar.texture:ClearAllPoints()
         if db.invertBars then
            bar.texture:SetPoint("TOP", frame, "CENTER", x, -layout.bottomY) -- hangs down from the top instead
         else
            bar.texture:SetPoint("BOTTOM", frame, "CENTER", x, layout.bottomY)
         end
         bar.texture:SetAlpha(EdgeAlpha(x))
      end

      for i, direction in ipairs(HEADINGS) do
         local x = OffsetFrom(direction.bearing, heading) * BARS_PIXELS_PER_DEGREE
         ringLabels[i]:ClearAllPoints()
         ringLabels[i]:SetPoint("CENTER", frame, "CENTER", x, db.invertBars and -layout.labelY or layout.labelY)
         ringLabels[i]:SetAlpha(EdgeAlpha(x))
      end
   end

   local function UpdateDial(facing)
      -- each label sits at (its bearing - our heading) clockwise from the top of the ring
      for i, heading in ipairs(HEADINGS) do
         local angle = math.rad(heading.bearing) + facing
         ringLabels[i]:ClearAllPoints()
         ringLabels[i]:SetPoint("CENTER", frame, "CENTER", RING_RADIUS * math.sin(angle), RING_RADIUS * math.cos(angle))
      end
   end

   local lastFacing
   local function UpdateHeading()
      local facing = GetPlayerFacing() -- radians counter-clockwise from north; nil where unavailable
      if not facing then
         return
      end

      if facing == lastFacing then
         return
      end
      lastFacing = facing

      local heading = (360 - math.deg(facing)) % 360
      if db.style == "bars" then
         UpdateBars(heading)
      else
         UpdateDial(facing)
      end

      degrees:SetText(string.format("%03d°", math.floor(heading + 0.5) % 360))
   end

   -- lays out the HUD for the chosen style
   local function ApplyStyle()
      local isBars = db.style == "bars"

      for _, bar in ipairs(bars) do
         bar.texture:SetShown(isBars)
      end

      for _, label in ipairs(ringLabels) do
         label:SetAlpha(1)
         -- the game has no bold font, so a thick outline gives the Bars' letters their weight
         local fontFile, fontSize = label:GetFont()
         label:SetFont(fontFile, fontSize, isBars and "THICKOUTLINE" or "")
      end

      arrow:SetShown(not isBars) -- the strip's center bar position already marks the heading
      arrow:ClearAllPoints()
      degrees:ClearAllPoints()
      if isBars then
         local layout = BarsLayout()
         frame:SetSize(BARS_SIZE.width, layout.height)
         degrees:SetShown(not db.hideDegrees)
         if layout.degreesY then
            degrees:SetPoint("CENTER", frame, "CENTER", 0, db.invertBars and -layout.degreesY or layout.degreesY)
         end
      else
         degrees:SetShown(true)
         frame:SetSize(SIZE, SIZE)
         arrow:SetSize(37.27, 37.27)
         arrow:SetPoint("CENTER", frame, "CENTER", 0, 6)
         degrees:SetPoint("CENTER", frame, "CENTER", 0, -14)
      end

      lastFacing = nil -- redraw for the new style
      UpdateHeading()
   end

   ApplyStyle()
   frame:SetScript("OnUpdate", UpdateHeading) -- only runs while the HUD is shown

   --## ==========================================================================
   --## VISIBILITY, SCALE & POSITION
   --## ==========================================================================
   local inCombat = InCombatLockdown()

   -- shown unless it's been hidden (by the keybind, /compass hide or the Show checkbox), or it's
   -- combat & "Hide in Combat" is on
   local function UpdateVisibility()
      frame:SetShown(not db.hidden and not (db.hideInCombat and inCombat))
   end

   UpdateVisibility()

   -- a hidden frame still gets events, so it comes back when combat ends
   frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- entering combat
   frame:RegisterEvent("PLAYER_REGEN_ENABLED") -- leaving combat
   frame:SetScript("OnEvent", function(_, event)
      inCombat = event == "PLAYER_REGEN_DISABLED"
      UpdateVisibility()
   end)

   local function SetShown(shown)
      db.hidden = not shown
      UpdateVisibility()
   end

   -- the keybind in Bindings.xml
   function Compass_Toggle()
      SetShown(db.hidden)
   end

   local function SetScale(scale)
      db.scale = Clamp(scale, MIN_SCALE, MAX_SCALE)
      frame:SetScale(db.scale)
      ApplyPosition() -- keeps the same spot on screen
   end

   local function SetPosition(x, y)
      frame:StopMovingOrSizing()
      db.x, db.y = x, y
      ApplyPosition()
   end

   local function ResetPosition()
      SetPosition(0, 0)
   end

   --## ==========================================================================
   --## SETTINGS WINDOW (/compass, the /uwu cog & Options > AddOns)
   --## ==========================================================================
   local APP_NAME = "Compass"

   --## Positioning tab ---------------------------------------------------------
   local POSITION_NUDGE = 1 -- how far the -/+ buttons move the compass

   local function OffsetInput(axis, label, order)
      return {
         order = order,
         name = label,
         desc = "Offset of the compass's center from the center of the screen.",
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

   local positioningOptions = {
      name = "Positioning",
      type = "group",
      order = 2,
      args = {
         intro = {
            order = 1,
            name = "Position the compass precisely, relative to the center of the screen. "
               .. "You can also hold Shift and drag it with the left mouse button.",
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
            desc = "Move the compass back to its default spot, the center of the screen.",
            type = "execute",
            func = ResetPosition,
         },
      },
   }

   local options = {
      type = "group",
      name = "UwU: Compass",
      childGroups = "tab", -- General & Positioning as tabs (in /compass and in Options > AddOns)
      args = {
         positioning = positioningOptions,
         general = {
            name = "General",
            type = "group",
            order = 1,
            args = {
               visible = {
                  order = 1,
                  name = "Show Compass",
                  desc = "Show or hide the compass. You can also bind a key to this in Key Bindings.",
                  type = "toggle",
                  get = function()
                     return not db.hidden
                  end,
                  set = function(_, value)
                     SetShown(value)
                  end,
               },
               hideInCombat = {
                  order = 1.1,
                  name = "Hide in Combat",
                  desc = "Hide the compass while you're in combat.",
                  type = "toggle",
                  get = function()
                     return db.hideInCombat
                  end,
                  set = function(_, value)
                     db.hideInCombat = value
                     UpdateVisibility()
                  end,
               },
               style = {
                  order = 1.5,
                  name = "Style",
                  type = "select",
                  values = STYLES,
                  sorting = STYLE_ORDER,
                  width = "half", -- leaves room for the Invert checkbox on the same row
                  get = function()
                     return db.style
                  end,
                  set = function(_, value)
                     db.style = value
                     ApplyStyle()
                  end,
               },
               invertBars = {
                  order = 1.6,
                  name = "Invert",
                  desc = "Put the letters below the bars & the degrees above them.",
                  type = "toggle",
                  width = "half",
                  hidden = function()
                     return db.style ~= "bars"
                  end,
                  get = function()
                     return db.invertBars
                  end,
                  set = function(_, value)
                     db.invertBars = value
                     ApplyStyle()
                  end,
               },
               hideDegrees = {
                  order = 1.7,
                  name = "Hide Degrees",
                  desc = "Hide the heading in degrees. The frame gets shorter to fit.",
                  type = "toggle",
                  width = "half",
                  hidden = function()
                     return db.style ~= "bars"
                  end,
                  get = function()
                     return db.hideDegrees
                  end,
                  set = function(_, value)
                     db.hideDegrees = value
                     ApplyStyle()
                  end,
               },
               scale = {
                  order = 2,
                  name = "Scale",
                  desc = "Resize the compass.",
                  type = "range",
                  min = MIN_SCALE,
                  max = MAX_SCALE,
                  step = 0.05,
                  isPercent = true,
                  width = "full",
                  get = function()
                     return db.scale
                  end,
                  set = function(_, value)
                     SetScale(value)
                  end,
               },
               background = {
                  order = 3,
                  name = "Background",
                  desc = "The background's color & opacity.",
                  type = "color",
                  hasAlpha = true,
                  width = 0.7, -- leaves room for the Hide BG & Hide Border checkboxes on the same row
                  get = function()
                     return db.color.r, db.color.g, db.color.b, db.color.a
                  end,
                  set = function(_, r, g, b, a)
                     db.color = { r = r, g = g, b = b, a = a }
                     ApplyColor()
                  end,
               },
               hideBackground = {
                  order = 3.5,
                  name = "Hide BG",
                  desc = "Hide the background, leaving just the compass (& its border).",
                  type = "toggle",
                  width = 0.7,
                  get = function()
                     return db.hideBackground
                  end,
                  set = function(_, value)
                     db.hideBackground = value
                     ApplyColor()
                  end,
               },
               hideBorder = {
                  order = 3.6,
                  name = "Hide Border",
                  desc = "Hide the border around the compass.",
                  type = "toggle",
                  width = 0.9,
                  get = function()
                     return db.hideBorder
                  end,
                  set = function(_, value)
                     db.hideBorder = value
                     ApplyColor()
                  end,
               },
               -- line break, so the button sits below the color picker
               backgroundBreak = LineBreak(4),
               backgroundReset = {
                  order = 4.5,
                  name = "Reset Background",
                  type = "execute",
                  func = function()
                     db.color = CopyTable(DEFAULT_COLOR)
                     ApplyColor()
                     LibStub("AceConfigRegistry-3.0"):NotifyChange(APP_NAME)
                  end,
               },
            },
         },
      },
   }

   -- the Profiles tab (always last)
   options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(database)
   options.args.profile.order = -2

   -- switching, copying or resetting a profile redraws the compass with the new profile's settings
   local function OnProfileChanged()
      db = database.profile
      ValidateSettings()
      frame:SetScale(db.scale)
      ApplyColor()
      ApplyPosition()
      ApplyStyle()
      UpdateVisibility()
      LibStub("AceConfigRegistry-3.0"):NotifyChange(APP_NAME)
   end

   database.RegisterCallback(frame, "OnProfileChanged", OnProfileChanged)
   database.RegisterCallback(frame, "OnProfileCopied", OnProfileChanged)
   database.RegisterCallback(frame, "OnProfileReset", OnProfileChanged)

   LibStub("AceConfig-3.0"):RegisterOptionsTable(APP_NAME, options)
   local aceConfigDialog = LibStub("AceConfigDialog-3.0")
   aceConfigDialog:SetDefaultSize(APP_NAME, 440, 420) -- a little taller for the tabs

   local PREFIX = "|cFF00FF00Compass:|r "

   SLASH_UWUCOMPASS1 = "/compass"
   SlashCmdList["UWUCOMPASS"] = function(msg)
      local command = string.lower(strtrim(msg or ""))

      if command == "" then
         if aceConfigDialog.OpenFrames[APP_NAME] then
            aceConfigDialog:Close(APP_NAME)
         else
            aceConfigDialog:Open(APP_NAME)
         end
      elseif command == "toggle" then
         Compass_Toggle()
      elseif command == "show" then
         SetShown(true)
      elseif command == "hide" then
         SetShown(false)
      elseif command == "reset" then
         ResetPosition()
         print(PREFIX .. "Moved back to the center of the screen.")
      else
         print(PREFIX .. "Use /compass to open the options, or /compass toggle, show, hide, or reset.")
      end
   end

   -- a sub-item under UwU's own "Loaded!" message, which prints just before the modules load
   print("  - |cFF00FF00Compass|r loaded. Shift + drag the frame to move it.")
end)
