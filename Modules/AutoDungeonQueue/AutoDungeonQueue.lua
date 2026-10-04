-- Wrapped as an Unusual WoW Utils module: this only runs when "AutoDungeonQueue" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("AutoDungeonQueue", function()
   -- AutoDungeonQueue.lua
   -- Addon to automatically join dungeon queue with last selected role

   local addonName = "AutoDungeonQueue"
   local frame = CreateFrame("Frame", addonName .. "Frame")

   local PREFIX = "|cff00ff00AutoDungeonQueue:|r "
   local ERROR_PREFIX = "|cffff0000AutoDungeonQueue:|r "

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

         -- (the keybinding is in Bindings.xml, with its display name in Core.lua)

         frame:UnregisterEvent("ADDON_LOADED")
      end
   end

   local function HasSavedRoles()
      return AutoDungeonQueueDB.lastTankRole or AutoDungeonQueueDB.lastHealerRole or AutoDungeonQueueDB.lastDPSRole
   end

   local function YesNo(value)
      return value and "Yes" or "No"
   end

   local function PrintSavedRoles()
      print(
         PREFIX
            .. "Saved Roles"
            .. "\n- Tank: "
            .. YesNo(AutoDungeonQueueDB.lastTankRole)
            .. "\n- Healer: "
            .. YesNo(AutoDungeonQueueDB.lastHealerRole)
            .. "\n- DPS: "
            .. YesNo(AutoDungeonQueueDB.lastDPSRole)
      )
   end

   -- Applies the saved roles to the game, which also ticks the role check boxes in the Dungeon Finder
   local function ApplySavedRoles()
      local isLeader = GetLFGRoles() -- keep whatever leader flag is already set
      SetLFGRoles(
         isLeader,
         AutoDungeonQueueDB.lastTankRole,
         AutoDungeonQueueDB.lastHealerRole,
         AutoDungeonQueueDB.lastDPSRole
      )

      -- refresh the check boxes right away if the Dungeon Finder has been loaded
      if LFG_UpdateAllRoleCheckboxes then
         LFG_UpdateAllRoleCheckboxes()
      end
   end

   -- Function to save current role selection (from the Dungeon Finder check boxes)
   local function SaveCurrentRoles()
      local _, tankRole, healerRole, dpsRole = GetLFGRoles() -- 1st return is the leader flag
      if tankRole or healerRole or dpsRole then
         AutoDungeonQueueDB.lastTankRole = tankRole
         AutoDungeonQueueDB.lastHealerRole = healerRole
         AutoDungeonQueueDB.lastDPSRole = dpsRole
         PrintSavedRoles()
      end
   end

   -- `/adq save tank healer` etc. -- saves exactly the given role(s) without opening any windows
   local function SaveRoles(args)
      local canTank, canHeal, canDPS = UnitGetAvailableRoles("player")
      local roles = {}

      for word in args:gmatch("%S+") do
         if word == "tank" or word == "healer" or word == "dps" then
            roles[word] = true
         else
            print(ERROR_PREFIX .. '"' .. word .. '" is not a role. Use tank, healer, or DPS.')
            return
         end
      end

      if roles.tank and not canTank then
         print(ERROR_PREFIX .. "Your class can't be a Tank.")
         return
      elseif roles.healer and not canHeal then
         print(ERROR_PREFIX .. "Your class can't be a Healer.")
         return
      elseif roles.dps and not canDPS then
         print(ERROR_PREFIX .. "Your class can't be DPS.")
         return
      end

      AutoDungeonQueueDB.lastTankRole = roles.tank == true
      AutoDungeonQueueDB.lastHealerRole = roles.healer == true
      AutoDungeonQueueDB.lastDPSRole = roles.dps == true

      ApplySavedRoles()
      PrintSavedRoles()
   end

   local function OpenDungeonFinder()
      if not PVEFrame:IsShown() then
         PVEFrame_ShowFrame("GroupFinderFrame", LFDParentFrame)
      end
   end

   -- The random dungeon the Dungeon Finder would pick for you, or the first one you can join
   local function GetRandomDungeonToQueue()
      local bestChoice = GetRandomDungeonBestChoice()
      if bestChoice and IsLFGDungeonJoinable(bestChoice) then
         return bestChoice
      end

      for i = 1, GetNumRandomDungeons() do
         local id = GetLFGRandomDungeonInfo(i)
         if id and IsLFGDungeonJoinable(id) then
            return id
         end
      end
   end

   -- Function to auto-join dungeon queue
   local function AutoJoinDungeonQueue()
      -- With no saved roles there's nothing to queue with, so let the player pick in the Dungeon Finder
      if not HasSavedRoles() then
         OpenDungeonFinder()
         print(PREFIX .. "No saved roles yet. Pick your roles here, or use /adq save <tank|healer|DPS>.")
         return
      end

      -- Check if we're already in a group
      if IsInGroup() then
         print(ERROR_PREFIX .. "Already in a group!")
         return
      end

      -- Check if already queued
      if GetLFGMode(LE_LFG_CATEGORY_LFD) then
         print(ERROR_PREFIX .. "Already queued for dungeon!")
         return
      end

      local dungeonID = GetRandomDungeonToQueue()
      if not dungeonID then
         print(ERROR_PREFIX .. "No available dungeons found for your level.")
         return
      end

      ApplySavedRoles()
      JoinSingleLFG(LE_LFG_CATEGORY_LFD, dungeonID)
      print(PREFIX .. "Joined the dungeon queue!")
   end

   -- Slash command handler
   local function SlashCommandHandler(msg)
      local command, args = string.lower(msg or ""):match("^%s*(%S*)%s*(.-)%s*$")

      if command == "save" then
         if args == "" then
            SaveCurrentRoles()
         else
            SaveRoles(args)
         end
      elseif command == "roles" then
         PrintSavedRoles()
      elseif command == "help" then
         print("|cff00ff00AutoDungeonQueue Commands:|r")
         print("  |cffffffff/adq|r - Auto join dungeon queue with saved roles (opens the Dungeon Finder if none are saved)")
         print("  |cffffffff/adq save <tank|healer|DPS>|r - Save the given role(s)")
         print("  |cffffffff/adq save|r - Save the roles currently ticked in the Dungeon Finder")
         print("  |cffffffff/adq roles|r - Show saved roles")
         print("  |cffffffff/adq help|r - Show this help")
      elseif command == "" then
         AutoJoinDungeonQueue()
      else
         print(ERROR_PREFIX .. '"' .. command .. '" is an unknown command. Type /adq help for the list.')
      end
   end

   -- Event handlers
   frame:RegisterEvent("ADDON_LOADED")
   frame:SetScript("OnEvent", OnAddonLoaded)

   -- Register slash commands
   SLASH_AUTODUNGEONQUEUE1 = "/adq"
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
