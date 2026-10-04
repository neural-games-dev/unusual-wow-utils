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
   frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
   frame:SetMovable(true)
   frame:SetUserPlaced(true)
   frame:EnableMouse(true)
   frame:RegisterForDrag("LeftButton")
   -- locked by default; hold Shift while left-click dragging to move it
   frame:SetScript("OnDragStart", function(self)
      if IsShiftKeyDown() then
         self:StartMoving()
      end
   end)
   frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

   -- Tooltip sits on top of the frame (its bottom-left corner on the frame's top-left corner)
   frame:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_NONE")
      GameTooltip:ClearAllPoints()
      GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPLEFT")
      GameTooltip:SetText("Quest Log Counter")
      GameTooltip:AddLine("shift-left to drag", 1, 1, 1)
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

   -- Register events
   frame:RegisterEvent("QUEST_ACCEPTED")
   frame:RegisterEvent("QUEST_REMOVED")
   frame:RegisterEvent("QUEST_LOG_UPDATE")
   frame:RegisterEvent("PLAYER_LOGIN")

   -- Event handler
   frame:SetScript("OnEvent", function(self, event, ...)
      UpdateQuestCount()
   end)

   -- Initial update
   UpdateQuestCount()

   print("|cFF00FF00Quest Log Counter|r loaded. Shift + drag the frame to move it.")
end)
