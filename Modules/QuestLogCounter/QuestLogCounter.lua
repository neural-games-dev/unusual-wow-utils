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

   -- Default position: just left of the quest tracker (with a gap), tops aligned.
   -- Anchored to the tracker itself, so it follows the tracker if that's moved in Edit Mode.
   local DEFAULT_RIGHT_MARGIN = 24 -- gap between the counter's right edge & the tracker's left edge

   local function SetDefaultPosition()
      frame:ClearAllPoints()

      if ObjectiveTrackerFrame then
         frame:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPLEFT", -DEFAULT_RIGHT_MARGIN, 0)
      else
         frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
      end
   end

   local function IsAtDefaultPosition()
      local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
      return frame:GetNumPoints() == 1
         and point == "TOPRIGHT"
         and relativeTo == ObjectiveTrackerFrame
         and relativePoint == "TOPLEFT"
         and math.abs(x + DEFAULT_RIGHT_MARGIN) < 0.5
         and math.abs(y) < 0.5
   end

   SetDefaultPosition()
   frame:SetMovable(true)
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

   -- Set up backdrop
   frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
   })
   frame:SetBackdropColor(0, 0, 0, 0.8)

   -- Create text display
   local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
   text:SetPoint("CENTER", frame, "CENTER", 0, 0)
   text:SetTextColor(1, 1, 1, 1)

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
   UWU.db.questLogCounter = UWU.db.questLogCounter or { hidden = false }
   local qlcDB = UWU.db.questLogCounter

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

   -- `/qlc reset` -- back to the default position next to the quest tracker (silent if already there)
   local function ResetPosition()
      if IsAtDefaultPosition() then
         return
      end

      frame:StopMovingOrSizing()
      frame:SetUserPlaced(false) -- forget the dragged position so the default sticks after a reload
      SetDefaultPosition()
      print("|cFF00FF00Quest Log Counter:|r Moved back to its default position next to the quest log.")
   end

   SLASH_QUESTLOGCOUNTER1 = "/qlc"
   SlashCmdList["QUESTLOGCOUNTER"] = function(msg)
      local command = string.lower(strtrim(msg or ""))

      if command == "show" then
         SetFrameShown(true)
      elseif command == "hide" then
         SetFrameShown(false)
      elseif command == "reset" then
         ResetPosition()
      else
         print("|cFF00FF00Quest Log Counter:|r Use /qlc show, /qlc hide, or /qlc reset.")
      end
   end

   -- Initial update
   UpdateQuestCount()

   -- a sub-item under UwU's own "Loaded!" message, which prints just before the modules load
   print("  - |cFF00FF00Quest Log Counter|r loaded. Shift + drag the frame to move it.")
end)
