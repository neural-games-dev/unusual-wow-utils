-- Wrapped as an Unusual WoW Utils module: this only runs when "Compass" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("Compass", function()
   local addonName = "Compass"

   local DEFAULT_COLOR = { r = 0, g = 0, b = 0, a = 0.5 } -- semi-transparent black
   local DEFAULT_SCALE = 1
   local MIN_SCALE, MAX_SCALE = 0.5, 3

   -- saved in UwU's settings so it survives a reload
   UWU.db.compass = UWU.db.compass or {}
   local db = UWU.db.compass

   if db.hidden == nil then
      db.hidden = false
   end

   if type(db.scale) ~= "number" then
      db.scale = DEFAULT_SCALE
   end
   db.scale = Clamp(db.scale, MIN_SCALE, MAX_SCALE)

   local DEFAULT_STYLE = "dial"
   local STYLES = { dial = "Dial", bars = "Bars", arrow = "Arrow" }
   local STYLE_ORDER = { "dial", "bars", "arrow" }

   if not STYLES[db.style] then
      db.style = DEFAULT_STYLE
   end

   if type(db.color) ~= "table" then
      db.color = CopyTable(DEFAULT_COLOR)
   end

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
      frame:SetBackdropColor(db.color.r, db.color.g, db.color.b, db.color.a)
      frame:SetBackdropBorderColor(1, 1, 1, math.min(1, db.color.a + 0.3)) -- keeps the edge readable
   end

   ApplyColor()

   local function CenterFrame()
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
   end

   CenterFrame()
   frame:SetMovable(true)
   frame:SetClampedToScreen(true)
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
   arrow:SetSize(37.27, 37.27)
   arrow:SetPoint("CENTER", frame, "CENTER", 0, 6)

   -- the heading in degrees, below the arrow
   local degrees = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
   degrees:SetPoint("CENTER", frame, "CENTER", 0, -14)
   degrees:SetTextColor(1, 1, 1, 1)

   local ringLabels = {}
   for i, heading in ipairs(HEADINGS) do
      local fontObject = heading.major and "GameFontNormalLarge" or "GameFontNormalSmall"
      local label = frame:CreateFontString(nil, "OVERLAY", fontObject)
      label:SetText(heading.label)
      if heading.label == "N" then
         label:SetTextColor(1, 0.2, 0.2, 1) -- north stands out
      elseif not heading.major then
         label:SetTextColor(0.8, 0.8, 0.8, 1)
      end
      ringLabels[i] = label
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

      -- each label sits at (its bearing - our heading) clockwise from the top of the ring
      for i, heading in ipairs(HEADINGS) do
         local angle = math.rad(heading.bearing) + facing
         ringLabels[i]:ClearAllPoints()
         ringLabels[i]:SetPoint("CENTER", frame, "CENTER", RING_RADIUS * math.sin(angle), RING_RADIUS * math.cos(angle))
      end

      local heading = (360 - math.deg(facing)) % 360
      degrees:SetText(string.format("%03d°", math.floor(heading + 0.5) % 360))
   end

   frame:SetScript("OnUpdate", UpdateHeading) -- only runs while the HUD is shown
   UpdateHeading()

   frame:SetShown(not db.hidden)

   --## ==========================================================================
   --## VISIBILITY, SCALE & POSITION
   --## ==========================================================================
   local function SetShown(shown)
      db.hidden = not shown
      frame:SetShown(shown)
   end

   -- the keybind in Bindings.xml
   function Compass_Toggle()
      SetShown(not frame:IsShown())
   end

   local function SetScale(scale)
      db.scale = Clamp(scale, MIN_SCALE, MAX_SCALE)
      frame:SetScale(db.scale)
   end

   local function ResetPosition()
      frame:StopMovingOrSizing()
      frame:SetUserPlaced(false) -- forget any dragged position so the default sticks after a reload
      CenterFrame()
   end

   --## ==========================================================================
   --## SETTINGS WINDOW (/compass, the /uwu cog & Options > AddOns)
   --## ==========================================================================
   local APP_NAME = "Compass"

   local options = {
      type = "group",
      name = "UwU: Compass",
      args = {
         visible = {
            order = 1,
            name = "Show Compass",
            desc = "Show or hide the compass. You can also bind a key to this in Key Bindings.",
            type = "toggle",
            get = function()
               return frame:IsShown()
            end,
            set = function(_, value)
               SetShown(value)
            end,
         },
         style = {
            order = 1.5,
            name = "Style",
            type = "select",
            values = STYLES,
            sorting = STYLE_ORDER,
            get = function()
               return db.style
            end,
            set = function(_, value)
               db.style = value
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
            get = function()
               return db.color.r, db.color.g, db.color.b, db.color.a
            end,
            set = function(_, r, g, b, a)
               db.color = { r = r, g = g, b = b, a = a }
               ApplyColor()
            end,
         },
         -- line break, so the button sits below the color picker
         backgroundBreak = {
            order = 4,
            name = "",
            type = "description",
            width = "full",
         },
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
         positionBreak = {
            order = 5,
            name = "",
            type = "description",
            width = "full",
         },
         reset = {
            order = 6,
            name = "Reset Position",
            desc = "Move the compass back to the center of the screen after Shift + dragging it.",
            type = "execute",
            func = ResetPosition,
         },
         dragNote = {
            order = 7,
            name = "\nYou can also hold Shift and drag the compass with the left mouse button to move it anywhere.\n",
            type = "description",
         },
      },
   }

   LibStub("AceConfig-3.0"):RegisterOptionsTable(APP_NAME, options)
   local aceConfigDialog = LibStub("AceConfigDialog-3.0")
   aceConfigDialog:SetDefaultSize(APP_NAME, 340, 300)

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
