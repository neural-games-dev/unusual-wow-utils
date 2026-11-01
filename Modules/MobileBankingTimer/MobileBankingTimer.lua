-- Wrapped as an Unusual WoW Utils module: this only runs when "Mobile Banking Timer" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("MobileBankingTimer", function()
   local APP_NAME = "MobileBankingTimer"

   local MOBILE_BANKING_SPELL_ID = 83958
   local CHEST_DURATION = 5 * 60 -- how long the summoned guild chest stays, in seconds
   local TEST_DURATION = 10
   local LABEL = "Mobile Bank:"

   local LSM = LibStub("LibSharedMedia-3.0")

   local MIN_FONT_SIZE, MAX_FONT_SIZE = 8, 32
   local DEFAULT_FONT_SIZE = 12
   local DEFAULT_OUTLINE = ""
   local OUTLINES = { [""] = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" }
   local OUTLINE_ORDER = { "", "OUTLINE", "THICKOUTLINE" }
   local DEFAULT_TEXT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
   -- same look as SexyMap's clock, coords & zone text: solid black, with a matching border
   local DEFAULT_BACKGROUND_COLOR = { r = 0, g = 0, b = 0, a = 1 }
   local DEFAULT_BORDER_COLOR = { r = 0, g = 0, b = 0, a = 1 }
   local DEFAULT_Y = 200

   -- Settings live in a profile, so they can be switched, copied & reset on the Profiles tab.
   -- The running timer's end is per character, so a /reload or relog doesn't lose it.
   local database = LibStub("AceDB-3.0"):New("MobileBankingTimerDB", {
      profile = {
         font = LSM:GetDefault("font"),
         fontSize = DEFAULT_FONT_SIZE,
         outline = DEFAULT_OUTLINE,
         textColor = DEFAULT_TEXT_COLOR,
         backgroundColor = DEFAULT_BACKGROUND_COLOR,
         borderColor = DEFAULT_BORDER_COLOR,
         -- the timer's center, as an offset from the center of the screen
         x = 0,
         y = DEFAULT_Y,
      },
   }, true)
   local db = database.profile

   local function ValidColor(color, fallback)
      if type(color) ~= "table" or type(color.r) ~= "number" or type(color.g) ~= "number"
         or type(color.b) ~= "number" or type(color.a) ~= "number" then
         return CopyTable(fallback)
      end
      return color
   end

   -- fixes up bad saved values
   local function ValidateSettings()
      if type(db.fontSize) ~= "number" then
         db.fontSize = DEFAULT_FONT_SIZE
      end
      db.fontSize = Clamp(db.fontSize, MIN_FONT_SIZE, MAX_FONT_SIZE)

      if not OUTLINES[db.outline] then
         db.outline = DEFAULT_OUTLINE
      end

      db.textColor = ValidColor(db.textColor, DEFAULT_TEXT_COLOR)
      db.backgroundColor = ValidColor(db.backgroundColor, DEFAULT_BACKGROUND_COLOR)
      db.borderColor = ValidColor(db.borderColor, DEFAULT_BORDER_COLOR)
      db.x = tonumber(db.x) or 0
      db.y = tonumber(db.y) or DEFAULT_Y
   end

   ValidateSettings()

   --## ==========================================================================
   --## TIMER FRAME
   --## ==========================================================================
   local frame = CreateFrame("Frame", "UWUMobileBankingTimerFrame", UIParent, "BackdropTemplate")
   frame:Hide() -- only shown while the timer's running or being previewed
   frame:SetFrameStrata("MEDIUM")
   frame:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
   })

   local text = frame:CreateFontString(nil, "OVERLAY")
   text:SetPoint("CENTER")

   local endTime -- when the running timer ends, in GetTime()'s clock; nil when it isn't running
   local previewing = false
   local lastSeconds -- what's currently displayed, so the text only changes when it needs to

   local function TimerText(seconds)
      return string.format("%s %d:%02d", LABEL, math.floor(seconds / 60), seconds % 60)
   end

   -- Shows the time left, or hides the frame the moment there's nothing left to show.
   -- Runs every frame while shown, so it can't linger past the end of the timer.
   local function Refresh()
      local remaining = endTime and endTime - GetTime()

      if remaining and remaining <= 0 then
         remaining = nil
         endTime = nil
         database.char.expiresAt = nil
      end

      if not remaining and not previewing then
         frame:Hide()
         return
      end

      local seconds = remaining and math.ceil(remaining) or CHEST_DURATION
      if seconds ~= lastSeconds then
         lastSeconds = seconds
         text:SetText(TimerText(seconds))
      end
   end

   -- sizes the frame for the text's widest time, so it doesn't jitter as the digits change
   local function FitFrame()
      text:SetText(LABEL .. " 8:88")
      frame:SetSize(text:GetStringWidth() + 24, text:GetStringHeight() + 16)
      lastSeconds = nil -- puts the real time back on the next Refresh
   end

   local function ApplyStyle()
      local color = db.textColor
      text:SetFont(LSM:Fetch("font", db.font), db.fontSize, db.outline)
      text:SetTextColor(color.r, color.g, color.b, color.a)

      color = db.backgroundColor
      frame:SetBackdropColor(color.r, color.g, color.b, color.a)
      color = db.borderColor
      frame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)

      FitFrame()
      Refresh()
   end

   frame:SetScript("OnShow", FitFrame)
   frame:SetScript("OnUpdate", Refresh) -- only runs while the frame is shown

   local function StartTimer(duration)
      endTime = GetTime() + duration
      database.char.expiresAt = GetServerTime() + duration
      frame:Show()
      Refresh()
   end

   local function SetPreview(value)
      previewing = value
      if previewing then
         frame:Show()
      end
      Refresh()
      LibStub("AceConfigRegistry-3.0"):NotifyChange(APP_NAME) -- refresh the Preview checkbox if it's open
   end

   --## Position ---------------------------------------------------------------
   local function ApplyPosition()
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
   end

   local function SetPosition(x, y)
      frame:StopMovingOrSizing()
      db.x, db.y = x, y
      ApplyPosition()
      LibStub("AceConfigRegistry-3.0"):NotifyChange(APP_NAME) -- refresh the offsets if they're open
   end

   local function ResetPosition()
      SetPosition(0, DEFAULT_Y)
   end

   frame:SetMovable(true) -- before SetUserPlaced, which errors on a frame that isn't movable
   frame:SetUserPlaced(false) -- we save the position ourselves, not the game's layout cache
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

      local frameX, frameY = self:GetCenter()
      local screenX, screenY = UIParent:GetCenter()
      SetPosition(math.floor(frameX - screenX + 0.5), math.floor(frameY - screenY + 0.5))
   end)

   frame:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_NONE")
      GameTooltip:ClearAllPoints()
      GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT")
      GameTooltip:SetText("Mobile Banking Timer")
      GameTooltip:AddLine("shift+left-mouse to drag", 1, 1, 1)
      GameTooltip:Show()
   end)
   frame:SetScript("OnLeave", GameTooltip_Hide)

   ApplyPosition()
   ApplyStyle()

   -- a hidden frame still gets events
   frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
   frame:SetScript("OnEvent", function(_, _, _, _, spellID)
      -- comparing a secret value errors, so those casts are skipped
      if issecretvalue and issecretvalue(spellID) then
         return
      end

      if spellID == MOBILE_BANKING_SPELL_ID then
         StartTimer(CHEST_DURATION)
      end
   end)

   -- pick the timer back up after a /reload or relog
   if type(database.char.expiresAt) == "number" then
      local remaining = database.char.expiresAt - GetServerTime()
      if remaining > 0 and remaining <= CHEST_DURATION then
         StartTimer(remaining)
      else
         database.char.expiresAt = nil
      end
   end

   -- a font from another addon may only get registered after we've loaded
   LSM.RegisterCallback(frame, "LibSharedMedia_Registered", function(_, mediaType, name)
      if mediaType == "font" and name == db.font then
         ApplyStyle()
      end
   end)

   --## ==========================================================================
   --## SETTINGS WINDOW (/mbt, the /uwu cog & Options > AddOns)
   --## ==========================================================================
   local function ColorOption(key, name, desc, order)
      return {
         order = order,
         name = name,
         desc = desc,
         type = "color",
         hasAlpha = true,
         width = 0.8,
         get = function()
            local color = db[key]
            return color.r, color.g, color.b, color.a
         end,
         set = function(_, r, g, b, a)
            db[key] = { r = r, g = g, b = b, a = a }
            ApplyStyle()
         end,
      }
   end

   local function OffsetInput(axis, label, order)
      return {
         order = order,
         name = label,
         desc = "Offset of the timer's center from the center of the screen.",
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

   -- forces the next options onto a new row
   local function LineBreak(order)
      return { order = order, name = "", type = "description", width = "full" }
   end

   local options = {
      type = "group",
      name = "UwU: Mobile Banking Timer",
      childGroups = "tab",
      args = {
         general = {
            name = "General",
            type = "group",
            order = 1,
            args = {
               intro = {
                  order = 1,
                  name = "Counts down the 5 minutes your Mobile Banking guild chest lasts, "
                     .. "from the moment the cast finishes.\n",
                  type = "description",
                  width = "full",
               },
               preview = {
                  order = 2,
                  name = "Preview",
                  desc = "Keep the timer visible so you can style it & hold Shift to drag it into place.",
                  type = "toggle",
                  get = function()
                     return previewing
                  end,
                  set = function(_, value)
                     SetPreview(value)
                  end,
               },
               test = {
                  order = 3,
                  name = "Test Timer",
                  desc = "Run the timer for " .. TEST_DURATION .. " seconds. Mobile Banking has a 1 hour cooldown.",
                  type = "execute",
                  disabled = function()
                     return endTime ~= nil
                  end,
                  func = function()
                     StartTimer(TEST_DURATION)
                  end,
               },
               styleHeader = { order = 10, name = "Style", type = "header" },
               font = {
                  order = 11,
                  name = "Font",
                  type = "select",
                  dialogControl = "LSM30_Font",
                  values = AceGUIWidgetLSMlists.font,
                  get = function()
                     return db.font
                  end,
                  set = function(_, value)
                     db.font = value
                     ApplyStyle()
                  end,
               },
               outline = {
                  order = 12,
                  name = "Outline",
                  type = "select",
                  values = OUTLINES,
                  sorting = OUTLINE_ORDER,
                  get = function()
                     return db.outline
                  end,
                  set = function(_, value)
                     db.outline = value
                     ApplyStyle()
                  end,
               },
               fontSize = {
                  order = 13,
                  name = "Font Size",
                  type = "range",
                  min = MIN_FONT_SIZE,
                  max = MAX_FONT_SIZE,
                  step = 1,
                  width = "full",
                  get = function()
                     return db.fontSize
                  end,
                  set = function(_, value)
                     db.fontSize = value
                     ApplyStyle()
                  end,
               },
               textColor = ColorOption("textColor", "Text", "The text's color & opacity.", 14),
               backgroundColor = ColorOption("backgroundColor", "Background", "The background's color & opacity.", 15),
               borderColor = ColorOption("borderColor", "Border", "The border's color & opacity.", 16),
               positionHeader = { order = 20, name = "Position", type = "header" },
               xOffset = OffsetInput("x", "X Offset", 21),
               yOffset = OffsetInput("y", "Y Offset", 22),
               resetBreak = LineBreak(29),
               resetPosition = {
                  order = 30,
                  name = "Reset Position",
                  desc = "Move the timer back to its default spot, above the center of the screen.",
                  type = "execute",
                  func = ResetPosition,
               },
            },
         },
      },
   }

   -- the Profiles tab (always last)
   options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(database)
   options.args.profile.order = -2

   -- switching, copying or resetting a profile redraws the timer with the new profile's settings
   local function OnProfileChanged()
      db = database.profile
      ValidateSettings()
      ApplyPosition()
      ApplyStyle()
      LibStub("AceConfigRegistry-3.0"):NotifyChange(APP_NAME)
   end

   database.RegisterCallback(frame, "OnProfileChanged", OnProfileChanged)
   database.RegisterCallback(frame, "OnProfileCopied", OnProfileChanged)
   database.RegisterCallback(frame, "OnProfileReset", OnProfileChanged)

   LibStub("AceConfig-3.0"):RegisterOptionsTable(APP_NAME, options)
   local aceConfigDialog = LibStub("AceConfigDialog-3.0")
   aceConfigDialog:SetDefaultSize(APP_NAME, 440, 520)

   local PREFIX = "|cFF00FF00Mobile Banking Timer:|r "

   SLASH_UWUMOBILEBANKINGTIMER1 = "/mbt"
   SlashCmdList["UWUMOBILEBANKINGTIMER"] = function(msg)
      local command = string.lower(strtrim(msg or ""))

      if command == "" then
         if aceConfigDialog.OpenFrames[APP_NAME] then
            aceConfigDialog:Close(APP_NAME)
         else
            aceConfigDialog:Open(APP_NAME)
         end
      elseif command == "move" then
         SetPreview(not previewing)
      elseif command == "test" then
         if endTime then
            print(PREFIX .. "The timer is already running.")
         else
            StartTimer(TEST_DURATION)
         end
      elseif command == "reset" then
         ResetPosition()
         print(PREFIX .. "Moved back to its default spot.")
      else
         print(PREFIX .. "Use /mbt to open the options, or /mbt move, test, or reset.")
      end
   end

   -- a sub-item under UwU's own "Loaded!" message, which prints just before the modules load
   print("  - |cFF00FF00Mobile Banking Timer|r loaded. Type /mbt for its options.")
end)
