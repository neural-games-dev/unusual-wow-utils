-- Wrapped as an Unusual WoW Utils module: this only runs when "CombatInterfaceManager" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("CombatInterfaceManager", function()
   --## ===============================================================================================
   --## ALL REQUIRED IMPORTS
   --## ===============================================================================================
   -- Libs / Packages
   local CombatInterfaceManager =
       LibStub("AceAddon-3.0"):NewAddon("CombatInterfaceManager", "AceConsole-3.0", "AceEvent-3.0")

   --## ===============================================================================================
   --## START UP & GREETING SCRIPTS
   --## ===============================================================================================

   function CombatInterfaceManager:OnInitialize()
      self.db = LibStub("AceDB-3.0"):New("CombatInterfaceManagerDB", { profile = CIM_Defaults }, true)

      -- calling all modules! all modules to the front! (keep in this order)
      self.chalk = self:GetModule("Chalk")
      -- self.dump = self:GetModule('Dump');
      -- self.inspecty = self:GetModule('Inspecty');
      self.utils = self:GetModule("Utils")
      self.config = self:GetModule("Config")
      self.logger = self:GetModule("Logger")

      -- do you init or not bro?! (keep in this order)
      self.config:Init(self)
      self.utils:Init(self)
      self.logger:Init(self)

      -- we're slashing prices so much it's like we're crazy!
      self:RegisterChatCommand("cim", "SlashCommandInfoConfig")
   end

   function CombatInterfaceManager:OnEnable()
      self:RegisterChatFramesListener()
      self:RegisterMinimapListener()
      self:RegisterObjectiveTrackerListener()
      self:RegisterZoneMapListener()

      -- checking for and storing loaded state of notable addons
      self.utils:SetDbTableItem("isLoaded", "itemLock", C_AddOns.IsAddOnLoaded("ItemLock"))
      self.utils:SetDbTableItem("isLoaded", "prat", C_AddOns.IsAddOnLoaded("Prat-3.0"))

      -- getting current player info
      self.utils:SetDbTableItem("playerInfo", "factionGroup", UnitFactionGroup("player"))
      local playerName = UnitName("player")
      self.utils:SetDbTableItem("playerInfo", "name", playerName)
   end

   function CombatInterfaceManager:RegisterChatFramesListener()
      -- TODO **[G]** :: Add some verbose debug logging here
      local num_chat_frames = FCF_GetNumActiveChatFrames()

      -- not sure what this incoming `self` is, but keeping for ref
      local function ToggleChatFrames(_self, event)
         local is_in_combat = event == "PLAYER_REGEN_DISABLED"
         local is_out_of_combat = event == "PLAYER_REGEN_ENABLED"

         if self.db.profile.isHiding.chatFrame then
            for i = 1, num_chat_frames, 1 do
               -- TODO **[G]** :: do something extra about the "voice" tab/chat frame that exists
               local chat_frame = _G["ChatFrame" .. i]
               self.logger:Debug(
                  "Processing chat frame -- "
                  .. "ID: "
                  .. chat_frame:GetName()
                  .. ", Name: "
                  .. chat_frame.name
               )

               if is_in_combat then
                  self.logger:Debug(self.chalk:warn("YOU'RE IN COMBAT!!! Hiding chat frame..."))
                  chat_frame:Hide()
               elseif is_out_of_combat then
                  self.logger:Debug(self.chalk:debug("You're out of combat. Showing chat frame..."))
                  chat_frame:Show()
               end
            end

            if is_out_of_combat then
               local chat_frame_1 = _G["ChatFrame1"]

               if chat_frame_1 then
                  FCF_SelectDockFrame(chat_frame_1)
               else
                  self.logger:Debug(self.chalk:warn("ToggleChatFrames: Chat frame 1 not found!"))
               end
            end
         end
      end

      local f = CreateFrame("Frame")
      f:RegisterEvent("PLAYER_REGEN_DISABLED") -- Event for entering combat
      f:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Event for leaving combat
      f:SetScript("OnEvent", ToggleChatFrames)
   end

   function CombatInterfaceManager:RegisterMinimapListener()
      -- TODO **[G]** :: Add some verbose debug logging here
      local mapFrame = Minimap

      -- not sure what this incoming `self` is, but keeping for ref
      local function ToggleMinimap(_self, event)
         if self.db.profile.isHiding.minimap then
            if event == "PLAYER_REGEN_DISABLED" then
               -- TODO **[G]** :: wrap this under debug and/or verbose logging
               -- self.logger:Print(self.chalk:warn("YOU'RE IN COMBAT!!! Hiding objective tracker..."));
               mapFrame:Hide() -- Hide on entering combat
            elseif event == "PLAYER_REGEN_ENABLED" then
               -- TODO **[G]** :: wrap this under debug and/or verbose logging
               -- self.logger:Print(self.chalk:info("You're out of combat. Showing objective tracker..."));
               mapFrame:Show() -- Show on exiting combat
            end
         end
      end

      local f = CreateFrame("Frame")
      f:RegisterEvent("PLAYER_REGEN_DISABLED") -- Event for entering combat
      f:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Event for leaving combat
      f:SetScript("OnEvent", ToggleMinimap)
   end

   function CombatInterfaceManager:RegisterObjectiveTrackerListener()
      -- TODO **[G]** :: Add some verbose debug logging here
      local questFrame = ObjectiveTrackerFrame

      -- not sure what this incoming `self` is, but keeping for ref
      local function ToggleObjectiveTracker(_self, event)
         if self.db.profile.isHiding.objectiveTracker then
            if event == "PLAYER_REGEN_DISABLED" then
               -- TODO **[G]** :: wrap this under debug and/or verbose logging
               -- self.logger:Print(self.chalk:warn("YOU'RE IN COMBAT!!! Hiding objective tracker..."));
               questFrame:Hide() -- Hide on entering combat
            elseif event == "PLAYER_REGEN_ENABLED" then
               -- TODO **[G]** :: wrap this under debug and/or verbose logging
               -- self.logger:Print(self.chalk:info("You're out of combat. Showing objective tracker..."));
               questFrame:Show() -- Show on exiting combat
            end
         end
      end

      local f = CreateFrame("Frame")
      f:RegisterEvent("PLAYER_REGEN_DISABLED") -- Event for entering combat
      f:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Event for leaving combat
      f:SetScript("OnEvent", ToggleObjectiveTracker)
   end

   function CombatInterfaceManager:RegisterZoneMapListener()
      -- the Zone Map (Shift+M) is load-on-demand, so its frame is looked up when combat starts
      local wasShown = false

      local function ToggleZoneMap(_self, event)
         local isHiding = self.db.profile.isHiding
         local zoneMap = BattlefieldMapFrame

         if not (isHiding and isHiding.zoneMap and zoneMap) then
            return
         end

         if event == "PLAYER_REGEN_DISABLED" then
            -- only restore it afterwards if it was open, so combat never opens a closed map
            wasShown = zoneMap:IsShown()
            zoneMap:Hide()
         elseif event == "PLAYER_REGEN_ENABLED" and wasShown then
            zoneMap:Show()
            wasShown = false
         end
      end

      local f = CreateFrame("Frame")
      f:RegisterEvent("PLAYER_REGEN_DISABLED") -- Event for entering combat
      f:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Event for leaving combat
      f:SetScript("OnEvent", ToggleZoneMap)
   end
end)
