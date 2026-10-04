-- Wrapped as an Unusual WoW Utils module: this only runs when "AutoDungeonQueue" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("AutoDungeonQueue", function()
   -- AutoDungeonQueue.lua
   -- Addon to automatically join dungeon queue with last selected role

   local addonName = "AutoDungeonQueue"
   local frame = CreateFrame("Frame", addonName .. "Frame")

   -- Saved variables (persisted between sessions)
   AutoDungeonQueueDB = AutoDungeonQueueDB
      or {
         lastTankRole = false,
         lastHealerRole = false,
         lastDPSRole = false,
         defaultKeybind = "CTRL-SHIFT-Q",
      }

   -- Initialize the addon
   local function OnAddonLoaded(self, event, loadedAddonName)
      if loadedAddonName == addonName then
         print("|cff00ff00AutoDungeonQueue|r loaded! Use /adq or your keybind to auto-queue.")

         -- Set up keybinding
         _G["BINDING_HEADER_AUTODUNGEONQUEUE"] = "Auto Dungeon Queue"
         _G["BINDING_NAME_AUTODUNGEONQUEUE_QUEUE"] = "Auto Join Dungeon Queue"

         frame:UnregisterEvent("ADDON_LOADED")
      end
   end

   -- Function to save current role selection
   local function SaveCurrentRoles()
      local tankRole, healerRole, dpsRole = GetLFGRoles()
      if tankRole or healerRole or dpsRole then
         AutoDungeonQueueDB.lastTankRole = tankRole
         AutoDungeonQueueDB.lastHealerRole = healerRole
         AutoDungeonQueueDB.lastDPSRole = dpsRole
         print(
            "|cff00ff00AutoDungeonQueue:|r Saved roles - Tank:"
               .. tostring(tankRole)
               .. " Healer:"
               .. tostring(healerRole)
               .. " DPS:"
               .. tostring(dpsRole)
         )
      end
   end

   -- Function to auto-join dungeon queue
   local function AutoJoinDungeonQueue()
      -- Check if we're already in a group
      if IsInGroup() then
         print("|cffff0000AutoDungeonQueue:|r Already in a group!")
         return
      end

      -- Check if already queued
      if GetLFGMode(LE_LFG_CATEGORY_LFD) then
         print("|cffff0000AutoDungeonQueue:|r Already queued for dungeon!")
         return
      end

      -- Open the LFG frame if not already open
      if not PVEFrame:IsShown() then
         PVEFrame_ShowFrame("GroupFinderFrame", LFDParentFrame)
      end

      -- Set the category to dungeons
      LFDQueueFrame_SetType(LE_LFG_CATEGORY_LFD)

      -- Set roles from saved data
      if AutoDungeonQueueDB.lastTankRole or AutoDungeonQueueDB.lastHealerRole or AutoDungeonQueueDB.lastDPSRole then
         SetLFGRoles(
            false, -- leader (not used for LFD)
            AutoDungeonQueueDB.lastTankRole,
            AutoDungeonQueueDB.lastHealerRole,
            AutoDungeonQueueDB.lastDPSRole
         )

         print(
            "|cff00ff00AutoDungeonQueue:|r Set roles - Tank:"
               .. tostring(AutoDungeonQueueDB.lastTankRole)
               .. " Healer:"
               .. tostring(AutoDungeonQueueDB.lastHealerRole)
               .. " DPS:"
               .. tostring(AutoDungeonQueueDB.lastDPSRole)
         )
      else
         print("|cffff0000AutoDungeonQueue:|r No saved roles found! Please select roles manually first.")
         return
      end

      -- Get all available dungeons for current level
      local numShown = 0
      for i = 1, GetNumRandomDungeons() do
         local id, name = GetLFGRandomDungeonInfo(i)
         if id and name then
            local isAvailable, isActive, isQueued = GetLFGDungeonInfo(id)
            if isAvailable and not isQueued then
               LFDQueueFrame_SetType(LE_LFG_CATEGORY_LFD)
               SetLFGDungeon(LE_LFG_CATEGORY_LFD, id)
               numShown = numShown + 1
            end
         end
      end

      if numShown > 0 then
         -- Join the queue
         JoinLFG(LE_LFG_CATEGORY_LFD)
         print("|cff00ff00AutoDungeonQueue:|r Joined dungeon queue!")
      else
         print("|cffff0000AutoDungeonQueue:|r No available dungeons found for your level.")
      end
   end

   -- Slash command handler
   local function SlashCommandHandler(msg)
      local command = string.lower(msg or "")

      if command == "save" then
         SaveCurrentRoles()
      elseif command == "roles" then
         print(
            "|cff00ff00AutoDungeonQueue:|r Saved roles - Tank:"
               .. tostring(AutoDungeonQueueDB.lastTankRole)
               .. " Healer:"
               .. tostring(AutoDungeonQueueDB.lastHealerRole)
               .. " DPS:"
               .. tostring(AutoDungeonQueueDB.lastDPSRole)
         )
      elseif command == "help" then
         print("|cff00ff00AutoDungeonQueue Commands:|r")
         print("  |cffffffff/adq|r - Auto join dungeon queue with saved roles")
         print("  |cffffffff/adq save|r - Save current role selection")
         print("  |cffffffff/adq roles|r - Show saved roles")
         print("  |cffffffff/adq help|r - Show this help")
      else
         AutoJoinDungeonQueue()
      end
   end

   -- Event handlers
   frame:RegisterEvent("ADDON_LOADED")
   frame:SetScript("OnEvent", OnAddonLoaded)

   -- Register slash commands
   SLASH_AUTODUNGEONQUEUE1 = "/autodungeonqueue"
   SLASH_AUTODUNGEONQUEUE2 = "/adq"
   SlashCmdList["AUTODUNGEONQUEUE"] = SlashCommandHandler

   -- Global function for keybinding
   function AutoDungeonQueue_Queue()
      AutoJoinDungeonQueue()
   end

   -- Auto-save roles when they change
   local roleFrame = CreateFrame("Frame")
   roleFrame:RegisterEvent("LFG_ROLE_CHECK_ROLE_CHOSEN")
   roleFrame:SetScript("OnEvent", function(self, event, ...)
      if event == "LFG_ROLE_CHECK_ROLE_CHOSEN" then
         C_Timer.After(0.1, SaveCurrentRoles) -- Small delay to ensure roles are set
      end
   end)
end)
