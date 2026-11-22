-- Wrapped as an Unusual WoW Utils module: this only runs when "Compass" is enabled.
local addonFolder, UWU = ...

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
         minimapOverlay = false, -- draw the Dial over the minimap instead of in its own frame
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
      db.minimapOverlay = db.minimapOverlay == true
      db.x = tonumber(db.x) or 0
      db.y = tonumber(db.y) or 0

      local color = db.color
      if type(color) ~= "table" or type(color.r) ~= "number" or type(color.g) ~= "number"
         or type(color.b) ~= "number" or type(color.a) ~= "number" then
         db.color = CopyTable(DEFAULT_COLOR)
      end
   end

   ValidateSettings()

   --## ==========================================================================
   --## HUD
   --## ==========================================================================
   local SIZE = 140
   local RING_RADIUS = 40 -- the Dial's letters, inside its tick marks

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

   local frame = CreateFrame("Frame", "UWUCompassFrame", UIParent)
   frame:SetSize(SIZE, SIZE)
   frame:SetFrameStrata("MEDIUM")
   frame:SetScale(db.scale)

   -- "As Minimap Overlay": the Dial drawn over the minimap, instead of in its own frame
   local function IsMinimapOverlay()
      return db.style == "dial" and db.minimapOverlay and Minimap ~= nil
   end

   -- with Rotate Minimap off, the minimap stays north-up (and its arrow turns instead)
   local function IsMinimapRotating()
      local GetCVarBool = C_CVar and C_CVar.GetCVarBool or GetCVarBool -- older clients only have the global
      return GetCVarBool("rotateMinimap") == true
   end

   --## Instrument skin ----------------------------------------------------------
   -- Both styles are skinned like an aircraft heading indicator: a charcoal case with rounded corners & a screw
   -- hole in each, around a window with a thin brass bezel, with the face (the Background color) inside it. The
   -- Bars' window is a rectangle the strip's size, and the Dial's is round. The case, bezel & face never overlap,
   -- so see-through colors stay even all over.
   local CASE_MARGIN = 6 -- the case's width around the window (and the Bars' case corners' radius)
   local BEZEL_WIDTH = 2
   local INSTRUMENT_INSET = CASE_MARGIN + BEZEL_WIDTH -- from the frame's edge to the face's
   local CASE_COLOR = { 0.16, 0.16, 0.16 } -- charcoal
   local BEZEL_COLOR = { 0.71, 0.57, 0.35 } -- brass
   local SCREW_COLOR = { 0.05, 0.05, 0.05 } -- the holes, darker than the case
   local BARS_SCREW_SIZE = 3 -- small enough to stay inside the corner's curve
   -- the Dial's square case has room to spare in its corners
   local DIAL_CASE_RADIUS = 14
   local DIAL_SCREW_SIZE = 5
   local DIAL_SCREW_INSET = 11 -- from the case's edges to a screw hole's center
   local DIAL_WINDOW_RADIUS = SIZE / 2 - CASE_MARGIN -- the bezel's outside edge
   local DIAL_FACE_RADIUS = DIAL_WINDOW_RADIUS - BEZEL_WIDTH
   -- round masks (anti-aliased): a circle, and its reverse, a round hole (made for this, as the game has none)
   local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
   local HOLE_MASK = "Interface\\AddOns\\" .. addonFolder .. "\\Modules\\Compass\\CircleInverse"
   -- the numerals' cream, for the in-between letters & the degrees, and the amber of the main directions
   local CREAM = { 0.93, 0.9, 0.82, 1 }
   local AMBER = { 0.91, 0.71, 0.23, 1 }

   -- cuts `texture` down by a mask of `file` (outside the mask, the texture shows), placed by `Place(mask)`
   local function AddMask(texture, file, Place)
      local mask = frame:CreateMaskTexture()
      mask:SetTexture(file, "CLAMPTOWHITE", "CLAMPTOWHITE")
      Place(mask)
      texture:AddMaskTexture(mask)
      return mask
   end

   -- a plain texture on `frame` between two of its points, each given as { point, x, y }
   local function Piece(list, layer, topLeft, bottomRight)
      local piece = frame:CreateTexture(nil, layer)
      piece:SetPoint("TOPLEFT", frame, unpack(topLeft))
      piece:SetPoint("BOTTOMRIGHT", frame, unpack(bottomRight))
      table.insert(list, piece)
      return piece
   end

   -- a quarter circle of `radius` in each of the frame's corners (cut out by the round mask), and a round screw
   -- hole of `screwSize`, `screwInset` in from the corner's edges
   local function AddCorners(skin, radius, screwSize, screwInset)
      for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
         local corner = frame:CreateTexture(nil, "BACKGROUND")
         corner:SetSize(radius, radius)
         corner:SetPoint(point, frame, point)
         AddMask(corner, CIRCLE_MASK, function(mask)
            mask:SetSize(radius * 2, radius * 2)
            mask:SetPoint(point, frame, point)
         end)
         table.insert(skin.case, corner)

         local screw = frame:CreateTexture(nil, "BORDER")
         screw:SetSize(screwSize, screwSize)
         local x = point:find("LEFT") and screwInset or -screwInset
         local y = point:find("TOP") and -screwInset or screwInset
         screw:SetPoint("CENTER", frame, point, x, y)
         AddMask(screw, CIRCLE_MASK, function(mask)
            mask:SetAllPoints(screw)
         end)
         table.insert(skin.screws, screw)
      end
   end

   -- The Bars' skin: the case is a band along each edge between its corners, around a rectangular window
   local barsSkin = { case = {}, screws = {}, bezel = {} }
   do
      local m, w = CASE_MARGIN, BEZEL_WIDTH
      AddCorners(barsSkin, m, BARS_SCREW_SIZE, m / 2) -- each screw centered in its corner's curve

      local case = barsSkin.case
      Piece(case, "BACKGROUND", { "TOPLEFT", m, 0 }, { "TOPRIGHT", -m, -m }) -- top
      Piece(case, "BACKGROUND", { "BOTTOMLEFT", m, m }, { "BOTTOMRIGHT", -m, 0 }) -- bottom
      Piece(case, "BACKGROUND", { "TOPLEFT", 0, -m }, { "BOTTOMLEFT", m, m }) -- left
      Piece(case, "BACKGROUND", { "TOPRIGHT", -m, -m }, { "BOTTOMRIGHT", 0, m }) -- right

      -- the bezel: a thin line around the inside of the case
      local bezel = barsSkin.bezel
      Piece(bezel, "BACKGROUND", { "TOPLEFT", m, -m }, { "TOPRIGHT", -m, -m - w }) -- top
      Piece(bezel, "BACKGROUND", { "BOTTOMLEFT", m, m + w }, { "BOTTOMRIGHT", -m, m }) -- bottom
      Piece(bezel, "BACKGROUND", { "TOPLEFT", m, -m - w }, { "BOTTOMLEFT", m + w, m + w }) -- left
      Piece(bezel, "BACKGROUND", { "TOPRIGHT", -m - w, -m - w }, { "BOTTOMRIGHT", -m, m + w }) -- right

      barsSkin.face = Piece({}, "BACKGROUND", { "TOPLEFT", m + w, -m - w }, { "BOTTOMRIGHT", -m - w, m + w })
   end

   -- The Dial's skin: the case is a rounded square with a round hole for the window, the bezel a ring around the
   -- hole's edge, and the face a circle inside it
   local dialSkin = { case = {}, screws = {}, bezel = {} }
   do
      local r = DIAL_CASE_RADIUS
      AddCorners(dialSkin, r, DIAL_SCREW_SIZE, DIAL_SCREW_INSET)

      -- the middle & the strips beside it, between the corners, all with the window's hole cut out of them
      local case = dialSkin.case
      local strips = {
         Piece(case, "BACKGROUND", { "TOPLEFT", r, 0 }, { "BOTTOMRIGHT", -r, 0 }), -- middle
         Piece(case, "BACKGROUND", { "TOPLEFT", 0, -r }, { "BOTTOMLEFT", r, r }), -- left
         Piece(case, "BACKGROUND", { "TOPRIGHT", -r, -r }, { "BOTTOMRIGHT", 0, r }), -- right
      }
      for _, strip in ipairs(strips) do
         AddMask(strip, HOLE_MASK, function(mask)
            mask:SetSize(DIAL_WINDOW_RADIUS * 2, DIAL_WINDOW_RADIUS * 2)
            mask:SetPoint("CENTER", frame)
         end)
      end

      -- the bezel: a circle the window's size, with a hole the face's size
      local bezel = frame:CreateTexture(nil, "BACKGROUND")
      bezel:SetSize(DIAL_WINDOW_RADIUS * 2, DIAL_WINDOW_RADIUS * 2)
      bezel:SetPoint("CENTER", frame)
      AddMask(bezel, CIRCLE_MASK, function(mask)
         mask:SetAllPoints(bezel)
      end)
      AddMask(bezel, HOLE_MASK, function(mask)
         mask:SetSize(DIAL_FACE_RADIUS * 2, DIAL_FACE_RADIUS * 2)
         mask:SetPoint("CENTER", frame)
      end)
      table.insert(dialSkin.bezel, bezel)

      local face = frame:CreateTexture(nil, "BACKGROUND")
      face:SetSize(DIAL_FACE_RADIUS * 2, DIAL_FACE_RADIUS * 2)
      face:SetPoint("CENTER", frame)
      AddMask(face, CIRCLE_MASK, function(mask)
         mask:SetAllPoints(face)
      end)
      dialSkin.face = face
   end

   local function SetSkinShown(skin, shown)
      for _, list in ipairs({ skin.case, skin.screws, skin.bezel }) do
         for _, piece in ipairs(list) do
            piece:SetShown(shown)
         end
      end
      skin.face:SetShown(shown)
   end

   -- the face is the background, and the case, screw holes & bezel are the border
   local function ApplyColor()
      local backgroundAlpha = db.hideBackground and 0 or db.color.a
      local borderAlpha = db.hideBorder and 0 or math.min(1, db.color.a + 0.3) -- keeps the edge readable
      for _, skin in ipairs({ barsSkin, dialSkin }) do
         skin.face:SetColorTexture(db.color.r, db.color.g, db.color.b, backgroundAlpha)
         for _, piece in ipairs(skin.case) do
            piece:SetColorTexture(CASE_COLOR[1], CASE_COLOR[2], CASE_COLOR[3], borderAlpha)
         end
         for _, piece in ipairs(skin.screws) do
            piece:SetColorTexture(SCREW_COLOR[1], SCREW_COLOR[2], SCREW_COLOR[3], borderAlpha)
         end
         for _, piece in ipairs(skin.bezel) do
            piece:SetColorTexture(BEZEL_COLOR[1], BEZEL_COLOR[2], BEZEL_COLOR[3], borderAlpha)
         end
      end
   end

   --## Position ---------------------------------------------------------------
   -- Saved as the frame's center offset from the screen's center, in screen (UIParent) units
   -- whatever the scale is, so the Positioning tab's X/Y offsets always mean the same thing.
   local function ApplyPosition()
      if IsMinimapOverlay() then
         return -- it's pinned to the minimap
      end
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

   -- the heading marker: fixed at the center, pointing "forward" (up) while the ring turns around it. It's turned
   -- from the game's gold to the numerals' cream.
   local arrow = frame:CreateTexture(nil, "ARTWORK")
   arrow:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")
   arrow:SetDesaturated(true)
   arrow:SetVertexColor(unpack(CREAM))

   -- the heading in degrees, below the arrow
   local degrees = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

   -- The letters & degrees are in a plain sans-serif, like an instrument's numerals (the standard font is the
   -- fallback), a little bigger than their font objects' since it runs small
   local INSTRUMENT_FONT = "Fonts\\ARIALN.TTF"
   local INSTRUMENT_FONT_GROWTH = 1.2
   local OVERLAY_LABEL_SHRINK = 2 -- points smaller, for the letters over the minimap

   degrees.baseFont = { degrees:GetFont() }
   degrees.color = CREAM

   local ringLabels = {}
   for i, heading in ipairs(HEADINGS) do
      local fontObject = heading.major and "GameFontNormalLarge" or "GameFontNormalSmall"
      local label = frame:CreateFontString(nil, "OVERLAY", fontObject)
      label:SetText(heading.label)
      label.baseFont = { label:GetFont() }
      label.color = heading.major and AMBER or CREAM -- the main directions are amber, the in-between ones cream
      ringLabels[i] = label
   end

   -- sets a label's (or the degrees') font & color, `shrink` points smaller than usual (if given)
   local function StyleText(fontString, outline, shrink)
      local file, size = unpack(fontString.baseFont)
      shrink = shrink or 0
      if not fontString:SetFont(INSTRUMENT_FONT, size * INSTRUMENT_FONT_GROWTH - shrink, outline) then
         fontString:SetFont(file, size - shrink, outline)
      end
      fontString:SetTextColor(unpack(fontString.color))
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

   -- dots between the bars, to mark the in-between degrees (like the instrument's smallest marks). They sit on the
   -- line the bars stand on.
   local TICK_STEP = 5
   local DOT_SIZE = 4

   local bars = {}
   for bearing = 0, 360 - TICK_STEP, TICK_STEP do
      local isBar = bearing % BAR_STEP == 0
      local isMajor = bearing % 45 == 0 -- the 8 labeled directions get taller, thicker bars
      -- crisp, solid white strokes like an instrument's tick marks
      local bar = frame:CreateTexture(nil, "ARTWORK")
      bar:SetColorTexture(1, 1, 1, 1)
      if isMajor then
         bar:SetSize(3, 24)
      elseif isBar then
         bar:SetSize(2, 14)
      else
         bar:SetSize(DOT_SIZE, DOT_SIZE)
         bar:SetColorTexture(0.6, 0.6, 0.6, 1) -- the dots are gray
         local mask = frame:CreateMaskTexture()
         mask:SetTexture(CIRCLE_MASK)
         mask:SetAllPoints(bar)
         bar:AddMaskTexture(mask)
      end
      table.insert(bars, { texture = bar, bearing = bearing })
   end

   -- The Dial's tick marks, the same as the Bars' (white lines, the 8 labeled directions' longest & thickest, and
   -- grey dots between), pointing in from the edge of the face & turning with the letters. On the minimap, the
   -- face is the minimap, so the ticks & letters keep the same distances in from its edge.
   local DIAL_TICK_INSET = 2 -- from the face's edge to where the ticks start
   local DIAL_LABEL_INSET = DIAL_FACE_RADIUS - RING_RADIUS -- from the face's edge to the letters' centers
   local DIAL_MAJOR_TICK_LENGTH = 9
   local DIAL_TICK_LENGTH = 5

   local dialTicks = {}
   for bearing = 0, 360 - TICK_STEP, TICK_STEP do
      local tick = frame:CreateTexture(nil, "ARTWORK")
      tick:SetColorTexture(1, 1, 1, 1)
      local length
      if bearing % 45 == 0 then
         length = DIAL_MAJOR_TICK_LENGTH
         tick:SetSize(3, length)
      elseif bearing % BAR_STEP == 0 then
         length = DIAL_TICK_LENGTH
         tick:SetSize(2, length)
      else
         length = DOT_SIZE
         tick:SetSize(DOT_SIZE, DOT_SIZE)
         tick:SetColorTexture(0.6, 0.6, 0.6, 1)
         AddMask(tick, CIRCLE_MASK, function(mask)
            mask:SetAllPoints(tick)
         end)
      end
      table.insert(dialTicks, { texture = tick, bearing = bearing, length = length })
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
      local faceRadius = DIAL_FACE_RADIUS
      if IsMinimapOverlay() then
         faceRadius = frame:GetWidth() / 2 -- the minimap's
         -- a north-up minimap keeps north at the top, and its arrow points at our heading on the ring instead
         if not IsMinimapRotating() then
            facing = 0
         end
      end

      -- each label sits at (its bearing - our heading) clockwise from the top of the ring
      local labelRadius = faceRadius - DIAL_LABEL_INSET
      for i, heading in ipairs(HEADINGS) do
         local angle = math.rad(heading.bearing) + facing
         ringLabels[i]:ClearAllPoints()
         ringLabels[i]:SetPoint("CENTER", frame, "CENTER", labelRadius * math.sin(angle), labelRadius * math.cos(angle))
      end

      -- and so does each tick, turned to point at the center (a texture turns counter-clockwise)
      for _, tick in ipairs(dialTicks) do
         local angle = math.rad(tick.bearing) + facing
         local radius = faceRadius - DIAL_TICK_INSET - tick.length / 2 -- its center's distance from the dial's
         tick.texture:ClearAllPoints()
         tick.texture:SetPoint("CENTER", frame, "CENTER", radius * math.sin(angle), radius * math.cos(angle))
         tick.texture:SetRotation(-angle)
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

   -- Puts the compass in its own frame on the screen, or (as a Minimap Overlay) over the minimap, its size. There
   -- it doesn't take the mouse, so the map can still be clicked, and it can't be moved or scaled on its own.
   local function ApplyHost(overlay)
      frame:ClearAllPoints()
      frame:EnableMouse(not overlay)
      frame:SetClampedToScreen(not overlay) -- the letters may stick out past a minimap at the screen's edge
      if overlay then
         frame:SetParent(Minimap)
         frame:SetFrameStrata(Minimap:GetFrameStrata())
         frame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
         frame:SetScale(1)
         frame:SetAllPoints(Minimap)
      else
         frame:SetParent(UIParent)
         frame:SetFrameStrata("MEDIUM")
         frame:SetScale(db.scale)
         ApplyPosition()
      end
   end

   -- lays out the HUD for the chosen style
   local function ApplyStyle()
      local isBars = db.style == "bars"
      local overlay = IsMinimapOverlay()
      ApplyHost(overlay)

      for _, bar in ipairs(bars) do
         bar.texture:SetShown(isBars)
      end
      for _, tick in ipairs(dialTicks) do
         tick.texture:SetShown(not isBars)
      end

      for _, label in ipairs(ringLabels) do
         label:SetAlpha(1)
         -- the game has no bold font, so a thick outline gives the letters their weight. Over the minimap, they're
         -- a little smaller, to cover less of the map.
         StyleText(label, "THICKOUTLINE", overlay and OVERLAY_LABEL_SHRINK or 0)
      end
      StyleText(degrees, overlay and "OUTLINE" or "") -- the outline keeps it readable over the world

      -- over the minimap, there's no case or face, and the minimap's own arrow marks us
      SetSkinShown(barsSkin, isBars)
      SetSkinShown(dialSkin, not isBars and not overlay)
      ApplyColor()

      arrow:SetShown(not isBars and not overlay) -- the strip's center bar position already marks the heading
      arrow:ClearAllPoints()
      degrees:ClearAllPoints()
      if overlay then
         degrees:SetShown(true)
         degrees:SetPoint("TOP", frame, "BOTTOM", 0, -4) -- just below the minimap
      elseif isBars then
         local layout = BarsLayout()
         -- the face is the strip's size, with the case & bezel around it
         frame:SetSize(BARS_SIZE.width + INSTRUMENT_INSET * 2, layout.height + INSTRUMENT_INSET * 2)
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
   frame:RegisterEvent("CVAR_UPDATE") -- Rotate Minimap being turned on or off
   frame:SetScript("OnEvent", function(_, event)
      if event == "CVAR_UPDATE" then
         lastFacing = nil -- redraw, in case the minimap's rotation changed
         return
      end
      inCombat = event == "PLAYER_REGEN_DISABLED"
      UpdateVisibility()
   end)

   -- the minimap being resized (in Edit Mode) resizes the overlay with it
   frame:SetScript("OnSizeChanged", function()
      lastFacing = nil
   end)

   local function SetShown(shown)
      db.hidden = not shown
      UpdateVisibility()
      LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName) -- refresh the Show checkbox if it's open
   end

   -- the keybind in Bindings.xml
   function Compass_Toggle()
      SetShown(db.hidden)
   end

   local function SetScale(scale)
      db.scale = Clamp(scale, MIN_SCALE, MAX_SCALE)
      if not IsMinimapOverlay() then -- the overlay is always the minimap's size
         frame:SetScale(db.scale)
         ApplyPosition() -- keeps the same spot on screen
      end
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
               minimapOverlay = {
                  order = 1.55,
                  name = "As Minimap Overlay",
                  desc = "Draw the Dial's tick marks & letters around the edge of the minimap, with your heading in "
                     .. "degrees below it, instead of in its own frame. With Rotate Minimap on, they turn with the "
                     .. "map; otherwise north stays at the top, and the minimap's arrow points at your heading.\n\n"
                     .. "It's the minimap's size and stays on it, so the scale, background, border & position "
                     .. "options don't apply.",
                  type = "toggle",
                  hidden = function()
                     return db.style ~= "dial"
                  end,
                  get = function()
                     return db.minimapOverlay
                  end,
                  set = function(_, value)
                     db.minimapOverlay = value
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

   -- the Minimap Overlay is the minimap's size & stays on it, with no frame of its own, so these don't apply to it
   for _, key in ipairs({ "scale", "background", "hideBackground", "hideBorder", "backgroundReset" }) do
      options.args.general.args[key].disabled = IsMinimapOverlay
   end
   positioningOptions.disabled = IsMinimapOverlay

   -- the Profiles tab (always last)
   options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(database)
   options.args.profile.order = -2

   -- switching, copying or resetting a profile redraws the compass with the new profile's settings
   local function OnProfileChanged()
      db = database.profile
      ValidateSettings()
      frame:SetScale(db.scale)
      ApplyPosition()
      ApplyStyle() -- colors it too
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
