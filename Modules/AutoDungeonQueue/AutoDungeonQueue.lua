-- Wrapped as an Unusual WoW Utils module: this only runs when "AutoDungeonQueue" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("AutoDungeonQueue", function()
   -- AutoDungeonQueue.lua
   -- Addon to automatically join dungeon queue with last selected role
   -- WoW Forever has no Dungeon Finder queue, so there it lists you in its Looking for Group window (the Create
   -- Listing tab) instead. The game-specific calls for each are in `retail` & `forever` below.

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

   -- WoW Forever only (added later, so older saved tables are filled in here)
   local LIST_DUNGEONS_CHOICES = { level = true, last = true }
   if not LIST_DUNGEONS_CHOICES[AutoDungeonQueueDB.listDungeons] then
      AutoDungeonQueueDB.listDungeons = "level" -- which dungeons to list for (see GetDungeonsToList)
   end
   if type(AutoDungeonQueueDB.lastActivityIDs) ~= "table" then
      AutoDungeonQueueDB.lastActivityIDs = {} -- the dungeons of the last listing made in Looking for Group
   end

   -- the playstyle to list with, by its Enum.LFGEntryGeneralPlaystyle name ("None" lists without one, which
   -- dungeon listings allow), labelled with the game's own names for them
   local PLAYSTYLE_ORDER = { "None", "Learning", "FunRelaxed", "FunSerious", "Expert" }
   local PLAYSTYLES = {
      None = "None",
      Learning = GROUP_FINDER_GENERAL_PLAYSTYLE1 or "Learning",
      FunRelaxed = GROUP_FINDER_GENERAL_PLAYSTYLE2 or "Relaxed",
      FunSerious = GROUP_FINDER_GENERAL_PLAYSTYLE3 or "Competitive",
      Expert = GROUP_FINDER_GENERAL_PLAYSTYLE4 or "Carry Offered",
   }
   if not PLAYSTYLES[AutoDungeonQueueDB.playstyle] then
      AutoDungeonQueueDB.playstyle = "None"
   end

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
      return value and "|cff00ff00Yes|r" or "|cffff0000No|r"
   end

   --## ==========================================================================
   --## RETAIL: the Dungeon Finder's random dungeon queue
   --## ==========================================================================
   local retail = {
      help = {
         window = "Open or close the Dungeon Finder",
         join = "Join the dungeon queue with saved roles (opens the Dungeon Finder if none are saved)",
         leave = "Leave the dungeon queue",
         saveCurrent = "Save the roles currently ticked in the Dungeon Finder",
      },
   }

   function retail.GetRoles()
      local _, tankRole, healerRole, dpsRole = GetLFGRoles() -- 1st return is the leader flag
      return tankRole, healerRole, dpsRole
   end

   -- also ticks the role check boxes in the Dungeon Finder
   function retail.ApplyRoles(tankRole, healerRole, dpsRole)
      local isLeader = GetLFGRoles() -- keep whatever leader flag is already set
      SetLFGRoles(isLeader, tankRole, healerRole, dpsRole)

      -- refresh the check boxes right away if the Dungeon Finder has been loaded
      if LFG_UpdateAllRoleCheckboxes then
         LFG_UpdateAllRoleCheckboxes()
      end
   end

   -- Leader is informational only: it's the game's current Dungeon Finder setting, not saved by ADQ
   function retail.GetLeaderLine()
      local isLeader = GetLFGRoles()
      return "- Leader: " .. YesNo(isLeader) .. " |cffb0b0b0(set in the Dungeon Finder, not by ADQ)|r"
   end

   local function OpenDungeonFinder()
      if not PVEFrame:IsShown() then
         PVEFrame_ShowFrame("GroupFinderFrame", LFDParentFrame)
      end
   end

   -- With no saved roles there's nothing to queue with, so let the player pick in the Dungeon Finder
   function retail.OnNoSavedRoles()
      OpenDungeonFinder()
      print(PREFIX .. "No saved roles yet. Pick your roles here, or use /adq save <tank||healer||DPS>.")
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

   -- `ApplySavedRoles` sets the saved roles just before joining
   function retail.Join(ApplySavedRoles)
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

   -- Dungeon queue modes that count as "waiting in the queue". Others (a dungeon is ready,
   -- already in a dungeon group, etc.) aren't something leaving the queue should touch.
   local LEAVABLE_QUEUE_MODES = {
      queued = true,
      suspended = true,
      rolecheck = true,
   }

   function retail.IsInQueue()
      return LEAVABLE_QUEUE_MODES[GetLFGMode(LE_LFG_CATEGORY_LFD)] == true
   end

   function retail.Leave()
      if not retail.IsInQueue() then
         print(ERROR_PREFIX .. "Not queued for a dungeon.")
         return
      end

      LeaveLFG(LE_LFG_CATEGORY_LFD)
      print(PREFIX .. "Left the dungeon queue.")
   end

   -- Same as the game's Dungeon Finder key
   function retail.ToggleWindow()
      PVEFrame_ToggleFrame("GroupFinderFrame", LFDParentFrame)
   end

   -- Auto-save roles when they change. `SaveCurrentRoles` reads & saves the game's roles.
   function retail.WatchRoles(SaveCurrentRoles)
      local roleFrame = CreateFrame("Frame")
      roleFrame:RegisterEvent("LFG_ROLE_CHECK_ROLE_CHOSEN")
      roleFrame:SetScript("OnEvent", function(self, event, ...)
         if event == "LFG_ROLE_CHECK_ROLE_CHOSEN" then
            C_Timer.After(0.1, SaveCurrentRoles) -- Small delay to ensure roles are set
         end
      end)
   end

   --## ==========================================================================
   --## WOW FOREVER: a listing in the Looking for Group window
   --## ==========================================================================
   -- Addon code may create & remove listings, as long as it's straight from a key press or click (so never
   -- from a timer). Opening or driving the window itself is left alone: that can break its Browse search
   -- until a /reload, so the roles & dungeons are set through the API instead.
   local forever = {
      help = {
         window = "Open or close the ADQ options",
         join = "List yourself in Looking for Group with saved roles",
         leave = "Remove your Looking for Group listing",
         saveCurrent = "Save the roles currently ticked in Looking for Group",
      },
   }

   local OPTIONS_APP = "AutoDungeonQueue"
   local DUNGEONS_CATEGORY = 2 -- Looking for Group's "Dungeons" category

   -- true while ADQ makes its own listing, which isn't saved as the last listing made in the window
   local isListingFromADQ = false

   function forever.GetRoles()
      local roles = C_LFGListRoles.GetRoles()
      if type(roles) ~= "table" then
         return false, false, false
      end
      return roles.tank == true, roles.healer == true, roles.dps == true
   end

   -- also ticks the role check boxes in Create Listing
   function forever.ApplyRoles(tankRole, healerRole, dpsRole)
      C_LFGListRoles.SetRoles({ tank = tankRole, healer = healerRole, dps = dpsRole })
   end

   -- Forever's listings have no leader role
   function forever.GetLeaderLine()
      return nil
   end

   function forever.OnNoSavedRoles()
      print(
         PREFIX
            .. "No saved roles yet. Tick your roles in Looking for Group's Create Listing, or use "
            .. "/adq save <tank||healer||DPS>."
      )
   end

   local function GetActivityInfo(activityID)
      return C_LFGList.GetActivityInfoTable(activityID)
   end

   -- the dungeons whose suggested levels fit yours (0 means no limit), as Create Listing filters them
   local function GetDungeonsForLevel()
      local level = UnitLevel("player")
      local activityIDs = {}

      for _, activityID in ipairs(C_LFGList.GetAvailableActivities(DUNGEONS_CATEGORY) or {}) do
         local info = GetActivityInfo(activityID)
         local minLevel = info and info.minLevelSuggestion or 0
         local maxLevel = info and info.maxLevelSuggestion or 0
         if info and (minLevel == 0 or level >= minLevel) and (maxLevel == 0 or level <= maxLevel) then
            table.insert(activityIDs, activityID)
         end
      end
      return activityIDs
   end

   -- The dungeons to list for, picked on the options page, or nothing & why
   local function GetDungeonsToList()
      if AutoDungeonQueueDB.listDungeons == "last" then
         local activityIDs = AutoDungeonQueueDB.lastActivityIDs
         if #activityIDs == 0 then
            return activityIDs,
               "No saved dungeons yet. List yourself once in Looking for Group's Create Listing, or pick "
                  .. '"All dungeons for my level" in /adq.'
         end
         return activityIDs
      end

      local activityIDs = GetDungeonsForLevel()
      if #activityIDs == 0 then
         return activityIDs, "No dungeons in Looking for Group suit your level."
      end
      return activityIDs
   end

   function forever.IsInQueue()
      return C_LFGList.HasActiveEntryInfo() == true
   end

   function forever.Join(ApplySavedRoles)
      if forever.IsInQueue() then
         print(ERROR_PREFIX .. "Already listed in Looking for Group!")
         return
      end

      local activityIDs, problem = GetDungeonsToList()
      if problem then
         print(ERROR_PREFIX .. problem)
         return
      end

      -- nil for "None" (or a playstyle this client doesn't have), which lists without one
      local playstyles = Enum.LFGEntryGeneralPlaystyle
      local playstyle = playstyles and playstyles[AutoDungeonQueueDB.playstyle]

      ApplySavedRoles()
      isListingFromADQ = true
      local listed = C_LFGList.CreateListing({ activityIDs = activityIDs, generalPlaystyle = playstyle })
      isListingFromADQ = false

      if listed == false then
         print(ERROR_PREFIX .. "Looking for Group couldn't list you.")
         return
      end

      local count = #activityIDs
      print(PREFIX .. "Listed you for " .. count .. (count == 1 and " dungeon" or " dungeons") .. " in Looking for Group!")
   end

   function forever.Leave()
      if not forever.IsInQueue() then
         print(ERROR_PREFIX .. "Not listed in Looking for Group.")
         return
      end

      C_LFGList.RemoveListing()
      -- The Browse tab keeps the last search's results (even through a /reload), so it would go on showing the
      -- listing as delisted, with no way to close it. The window's own delist doesn't leave that behind, so the
      -- results are cleared (the whole list; the next search fills it again).
      C_LFGList.ClearSearchResults()
      print(PREFIX .. "Removed your Looking for Group listing.")
   end

   function forever.ToggleWindow()
      local dialog = LibStub("AceConfigDialog-3.0")
      if dialog.OpenFrames[OPTIONS_APP] then
         dialog:Close(OPTIONS_APP)
      else
         dialog:Open(OPTIONS_APP)
      end
   end

   -- Create Listing's role check boxes set the roles through SetRoles, so they're saved from there. Unchanged
   -- roles (e.g. ADQ applying its own) are skipped, and so is unticking every role (as `/adq clear` does).
   function forever.WatchRoles(_, SaveRolesIfAny)
      hooksecurefunc(C_LFGListRoles, "SetRoles", function(roles)
         if type(roles) ~= "table" then
            return
         end

         local tankRole, healerRole, dpsRole = roles.tank == true, roles.healer == true, roles.dps == true
         local isUnchanged = tankRole == AutoDungeonQueueDB.lastTankRole
            and healerRole == AutoDungeonQueueDB.lastHealerRole
            and dpsRole == AutoDungeonQueueDB.lastDPSRole
         if not isUnchanged then
            SaveRolesIfAny(tankRole, healerRole, dpsRole)
         end
      end)
   end

   -- Saves the dungeons of each listing made (or changed) in the Looking for Group window, for "My last
   -- listing's dungeons". Anything that isn't a dungeon (quests, battlegrounds, etc.) is left out.
   local function SaveListingDungeons(createData)
      if isListingFromADQ or type(createData) ~= "table" or type(createData.activityIDs) ~= "table" then
         return
      end

      local activityIDs = {}
      for _, activityID in ipairs(createData.activityIDs) do
         local info = GetActivityInfo(activityID)
         if info and info.categoryID == DUNGEONS_CATEGORY then
            table.insert(activityIDs, activityID)
         end
      end

      if #activityIDs > 0 then
         AutoDungeonQueueDB.lastActivityIDs = activityIDs
         LibStub("AceConfigRegistry-3.0"):NotifyChange(OPTIONS_APP) -- refresh the list on the options page
      end
   end

   --## Options page (/adq, the /uwu cog & Options > AddOns) --------------------
   local function RegisterForeverOptions()
      hooksecurefunc(C_LFGList, "CreateListing", SaveListingDungeons)
      hooksecurefunc(C_LFGList, "UpdateListing", SaveListingDungeons)

      local options = {
         type = "group",
         name = "UwU: Auto Dungeon Queue",
         args = {
            intro = {
               order = 1,
               name = "The List/Delist keybind (or /adq join) lists you in Looking for Group with your saved "
                  .. "roles, without opening any windows. Pressed while you're listed, it delists you.\n ",
               type = "description",
               fontSize = "medium",
               width = "full",
            },
            listDungeons = {
               order = 2,
               name = "Dungeons to list for",
               desc = "All dungeons for my level: every dungeon whose suggested levels fit yours, like "
                  .. "Create Listing shows them.\n\nMy last listing's dungeons: the dungeons you ticked the "
                  .. "last time you listed yourself in Create Listing.",
               type = "select",
               style = "radio",
               width = "full",
               values = { level = "All dungeons for my level", last = "My last listing's dungeons" },
               sorting = { "level", "last" },
               get = function()
                  return AutoDungeonQueueDB.listDungeons
               end,
               set = function(_, value)
                  AutoDungeonQueueDB.listDungeons = value
               end,
            },
            lastDungeons = {
               order = 3,
               name = function()
                  local names = {}
                  for _, activityID in ipairs(AutoDungeonQueueDB.lastActivityIDs) do
                     local info = GetActivityInfo(activityID)
                     table.insert(names, info and (info.fullName or info.shortName) or tostring(activityID))
                  end

                  if #names == 0 then
                     return "\nLast listing: |cffb0b0b0none yet (list yourself once in Create Listing)|r\n "
                  end
                  return "\nLast listing: " .. table.concat(names, ", ") .. "\n "
               end,
               type = "description",
               width = "full",
            },
            playstyle = {
               order = 3.5,
               name = "Playstyle",
               desc = "The playstyle your listing is made with, the same choices as Create Listing's. Dungeon "
                  .. "listings don't need one, so None lists you without it.\n\nIt's applied to your listing, but "
                  .. "not necessarily displayed: Create Listing's own Playstyle dropdown doesn't change to match, "
                  .. "and the Browse tab doesn't show playstyles.",
               type = "select",
               values = PLAYSTYLES,
               sorting = PLAYSTYLE_ORDER,
               get = function()
                  return AutoDungeonQueueDB.playstyle
               end,
               set = function(_, value)
                  AutoDungeonQueueDB.playstyle = value
               end,
            },
            playstyleBreak = { order = 3.6, name = "", type = "description", width = "full" },
            keybinds = {
               order = 4,
               name = "Key Bindings",
               desc = "Set the List/Delist & Clear Saved Roles keybinds.",
               type = "execute",
               func = function()
                  LibStub("AceConfigDialog-3.0"):Close(OPTIONS_APP)
                  UWU.modules.AutoDungeonQueue.openKeyBindings()
               end,
            },
         },
      }

      LibStub("AceConfig-3.0"):RegisterOptionsTable(OPTIONS_APP, options)
      LibStub("AceConfigDialog-3.0"):SetDefaultSize(OPTIONS_APP, 420, 360)
   end

   --## ==========================================================================
   --## SHARED: saved roles, slash commands & keybindings
   --## ==========================================================================
   local backend = UWU.IS_FOREVER and forever or retail

   local function PrintSavedRoles()
      local leaderLine = backend.GetLeaderLine()

      print(
         PREFIX
            .. "Saved Roles"
            .. (leaderLine and "\n" .. leaderLine or "")
            .. "\n- Tank: "
            .. YesNo(AutoDungeonQueueDB.lastTankRole)
            .. "\n- Healer: "
            .. YesNo(AutoDungeonQueueDB.lastHealerRole)
            .. "\n- DPS: "
            .. YesNo(AutoDungeonQueueDB.lastDPSRole)
      )
   end

   -- Applies the saved roles to the game, which also ticks its role check boxes
   local function ApplySavedRoles()
      backend.ApplyRoles(
         AutoDungeonQueueDB.lastTankRole,
         AutoDungeonQueueDB.lastHealerRole,
         AutoDungeonQueueDB.lastDPSRole
      )
   end

   local function SaveRolesIfAny(tankRole, healerRole, dpsRole)
      if tankRole or healerRole or dpsRole then
         AutoDungeonQueueDB.lastTankRole = tankRole
         AutoDungeonQueueDB.lastHealerRole = healerRole
         AutoDungeonQueueDB.lastDPSRole = dpsRole
         PrintSavedRoles()
      end
   end

   -- Function to save current role selection (from the game's role check boxes)
   local function SaveCurrentRoles()
      SaveRolesIfAny(backend.GetRoles())
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

   -- Forgets the saved roles and unticks the game's role check boxes,
   -- so the next /adq join asks for roles again
   local function ClearSavedRoles()
      AutoDungeonQueueDB.lastTankRole = false
      AutoDungeonQueueDB.lastHealerRole = false
      AutoDungeonQueueDB.lastDPSRole = false

      ApplySavedRoles()

      print(PREFIX .. "Cleared your saved roles.")
      PrintSavedRoles()
   end

   -- Function to auto-join dungeon queue (or, on Forever, list yourself)
   local function AutoJoinDungeonQueue()
      if not HasSavedRoles() then
         backend.OnNoSavedRoles()
         return
      end

      -- Check if we're already in a group
      if IsInGroup() then
         print(ERROR_PREFIX .. "Already in a group!")
         return
      end

      backend.Join(ApplySavedRoles)
   end

   -- Slash command handler
   local function SlashCommandHandler(msg)
      local command, args = string.lower(msg or ""):match("^%s*(%S*)%s*(.-)%s*$")

      if command == "" then
         backend.ToggleWindow()
      elseif command == "join" then
         AutoJoinDungeonQueue()
      elseif command == "leave" then
         backend.Leave()
      elseif command == "save" then
         if args == "" then
            SaveCurrentRoles()
         else
            SaveRoles(args)
         end
      elseif command == "roles" then
         PrintSavedRoles()
      elseif command == "clear" then
         ClearSavedRoles()
      elseif command == "help" then
         print("|cff00ff00AutoDungeonQueue Commands:|r")
         print("  |cffffffff/adq|r - " .. backend.help.window)
         print("  |cffffffff/adq join|r - " .. backend.help.join)
         print("  |cffffffff/adq leave|r - " .. backend.help.leave)
         print("  |cffffffff/adq save <tank||healer||DPS>|r - Save the given role(s)")
         print("  |cffffffff/adq save|r - " .. backend.help.saveCurrent)
         print("  |cffffffff/adq roles|r - Show saved roles")
         print("  |cffffffff/adq clear|r - Clear saved roles")
         print("  |cffffffff/adq help|r - Show this help")
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

   -- Global functions for keybindings
   -- The single join/leave binding: leaves while waiting in the queue (on Forever, delists you while
   -- listed), joins otherwise
   function AutoDungeonQueue_ToggleQueue()
      if backend.IsInQueue() then
         backend.Leave()
      else
         AutoJoinDungeonQueue()
      end
   end

   function AutoDungeonQueue_ClearRoles()
      ClearSavedRoles()
   end

   backend.WatchRoles(SaveCurrentRoles, SaveRolesIfAny)

   if UWU.IS_FOREVER then
      RegisterForeverOptions()
   end
end)
