-- Wrapped as an Unusual WoW Utils module: this only runs when "CooldownBarGlobal" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("CooldownBarGlobal", function()
   -- Generate my Ace Addon
   local CooldownBarGlobal = LibStub("AceAddon-3.0"):NewAddon("CooldownBarGlobal", "AceEvent-3.0")

   -- Lib stubs
   local aceConfigDialog = LibStub("AceConfigDialog-3.0")
   local media = LibStub("LibSharedMedia-3.0")

   -- Defaults for CooldownBarGlobalDB
   local defaults = {
      profile = {
         -- centered on screen
         x = 0,
         y = 0,
         p = "CENTER",
         rp = "CENTER",
         w = 250,
         h = 8,
         color = { r = 0, g = 1.0, b = 0, a = 1.0 },
         backgroundColor = { r = 0.3, g = 0.3, b = 0.3, a = 0.5 },
         lagColor = { r = 1.0, g = 0, b = 0, a = 1.0 },
         bartexture = "Blizzard",
         backgroundtexture = "Blizzard",
         lagtexture = "Blizzard",
         spark = true,
         combatOnly = true,
         barType = "HLR",
      },
   }

   -- Easy DB reference
   local profileDB

   -- The frame itself, containing the textures
   local gcdBarFrame

   -- Variables for the spell being monitored
   local start, duration

   -- Move mode boolean
   local moveMode = false

   -- Frame size
   local w, h

   -- Bar type
   local barType

   -- Options table for use of Ace-Config 3
   local options = {
      type = "group",
      name = "UwU: Cooldown Bar Global",
      childGroups = "tab", -- General & Profiles as tabs (in /cbg and in Options > AddOns)
      args = {
         general = {
            name = "General",
            type = "group",
            order = 1,
            args = {
               firstheader = {
                  order = 1,
                  name = "Position & Size",
                  type = "header",
               },
               width = {
                  order = 4,
                  name = "Width",
                  desc = "Width of global cooldown bar.",
                  type = "range",
                  min = 2,
                  max = 1000,
                  step = 1,
                  set = function(info, value)
                     profileDB.w = value
                     CooldownBarGlobal:SetupFrame()
                  end,
                  get = function(info)
                     return profileDB.w
                  end,
               },
               height = {
                  order = 5,
                  name = "Height",
                  desc = "Height of global cooldown bar.",
                  type = "range",
                  min = 2,
                  max = 1000,
                  step = 1,
                  set = function(info, value)
                     profileDB.h = value
                     CooldownBarGlobal:SetupFrame()
                  end,
                  get = function(info)
                     return profileDB.h
                  end,
               },
               barType = {
                  order = 6,
                  name = "Bar Type",
                  desc = "Select how the bar must function.",
                  type = "select",
                  values = {
                     ["HLR"] = "Horizontal, Left-to-right",
                     ["HRL"] = "Horizontal, Right-to-left",
                     ["VBT"] = "Vertical, Bottom-to-top",
                     ["VTB"] = "Vertical, Top-to-bottom",
                  },
                  set = function(info, value)
                     profileDB.barType = value
                     CooldownBarGlobal:SetupFrame()
                  end,
                  get = function(info)
                     return profileDB.barType
                  end,
               },
               secondheader = {
                  order = 7,
                  name = "Colors and Appearance",
                  type = "header",
               },
               color = {
                  order = 8,
                  name = "Color",
                  desc = "Color of bar.",
                  type = "color",
                  hasAlpha = true,
                  set = function(info, r, g, b, a)
                     profileDB.color.r = r
                     profileDB.color.g = g
                     profileDB.color.b = b
                     profileDB.color.a = a
                     CooldownBarGlobal:SetupFrame()
                  end,
                  get = function()
                     return profileDB.color.r, profileDB.color.g, profileDB.color.b, profileDB.color.a
                  end,
               },
               backgroundColor = {
                  order = 9,
                  name = "Background Color",
                  desc = "Background color of bar.",
                  type = "color",
                  hasAlpha = true,
                  set = function(info, r, g, b, a)
                     profileDB.backgroundColor.r = r
                     profileDB.backgroundColor.g = g
                     profileDB.backgroundColor.b = b
                     profileDB.backgroundColor.a = a
                     CooldownBarGlobal:SetupFrame()
                  end,
                  get = function()
                     return profileDB.backgroundColor.r, profileDB.backgroundColor.g, profileDB.backgroundColor.b, profileDB.backgroundColor.a
                  end,
               },
               lagColor = {
                  order = 10,
                  name = "Lag Color",
                  desc = "Color of lag part of bar.",
                  type = "color",
                  hasAlpha = true,
                  set = function(info, r, g, b, a)
                     profileDB.lagColor.r = r
                     profileDB.lagColor.g = g
                     profileDB.lagColor.b = b
                     profileDB.lagColor.a = a
                     CooldownBarGlobal:SetupFrame()
                  end,
                  get = function()
                     return profileDB.lagColor.r, profileDB.lagColor.g, profileDB.lagColor.b, profileDB.lagColor.a
                  end,
               },
               bartexture = {
                  order = 11,
                  type = 'select',
                  dialogControl = 'LSM30_Statusbar',
                  name = "Bar Texture",
                  desc = "The texture used by the global cooldown bar.",
                  values = AceGUIWidgetLSMlists.statusbar,
                  get = function()
                     return profileDB.bartexture
                  end,
                  set = function(info, value)
                     profileDB.bartexture = value
                     CooldownBarGlobal:SetupFrame()
                  end,
               },
               backgroundtexture = {
                  order = 12,
                  type = 'select',
                  dialogControl = 'LSM30_Statusbar',
                  name = "Background Texture",
                  desc = "The texture used for the background of the global cooldown bar.",
                  values = AceGUIWidgetLSMlists.statusbar,
                  get = function()
                     return profileDB.backgroundtexture
                  end,
                  set = function(info, value)
                     profileDB.backgroundtexture = value
                     CooldownBarGlobal:SetupFrame()
                  end,
               },
               lagtexture = {
                  order = 13,
                  type = 'select',
                  dialogControl = 'LSM30_Statusbar',
                  name = "Lag Texture",
                  desc = "The texture used by for the lag portion of the global cooldown bar.",
                  values = AceGUIWidgetLSMlists.statusbar,
                  get = function()
                     return profileDB.lagtexture
                  end,
                  set = function(info, value)
                     profileDB.lagtexture = value
                     CooldownBarGlobal:SetupFrame()
                  end,
               },
               thirdheader = {
                  order = 14,
                  name = "Other",
                  type = "header",
               },
               spark = {
                  order = 15,
                  name = "Spark",
                  desc = "Toggle to use a spark on cooldown bar or not.",
                  type = "toggle",
                  set = function(info, value)
                     profileDB.spark = value
                  end,
                  get = function(info)
                     return profileDB.spark
                  end,
               },
               combatOnly = {
                  order = 16,
                  name = "Combat Only",
                  desc = "Toggle to use a the global cooldown bar in combat only.",
                  type = "toggle",
                  set = function(info, value)
                     profileDB.combatOnly = value
                  end,
                  get = function(info)
                     return profileDB.combatOnly
                  end,
               },
               moveMode = {
                  order = 17,
                  name = "'Move' mode",
                  desc = "Enable 'move' mode where the cool down frame is visible at all times (for placing the frame properly).",
                  type = "toggle",
                  set = function(info, value)
                     moveMode = value
                     if value == true then
                        if gcdBarFrame == nil then
                           CooldownBarGlobal:SetupFrame()
                        end
                        gcdBarFrame:Show()
                     end
                  end,
                  get = function(info)
                     return moveMode
                  end,
               },
            },
         },
      },
   }

   function CooldownBarGlobal:OnInitialize()
      -- Register the DataBase
      self.db = LibStub("AceDB-3.0"):New("CooldownBarGlobalDB", defaults, true);
      profileDB = self.db.profile

      options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
      options.args.profile.order = -2

      -- Register various events for profiles
      self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
      self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
      self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

      -- And register the options
      LibStub("AceConfig-3.0"):RegisterOptionsTable("Cooldown Bar Global", options);

      -- /cbg just toggles the config window (AceConfig's own slash handler would
      -- expose the option groups, e.g. "general" & "profile", as subcommands)
      SLASH_COOLDOWNBARGLOBAL1 = "/cbg"
      SlashCmdList["COOLDOWNBARGLOBAL"] = function()
         if aceConfigDialog.OpenFrames["Cooldown Bar Global"] then
            aceConfigDialog:Close("Cooldown Bar Global")
         else
            aceConfigDialog:Open("Cooldown Bar Global")
         end
      end

      -- And add the options table to the actual interface UI
      -- one page under Unusual WoW Utils in Options > AddOns, with General & Profiles as tabs
      aceConfigDialog:AddToBlizOptions("Cooldown Bar Global", "Cooldown Bar Global", UWU.SETTINGS_CATEGORY)

      -- Add the event
      CooldownBarGlobal:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
   end

   function CooldownBarGlobal:SetupFrame()
      if gcdBarFrame then
         gcdBarFrame:Hide()
         gcdBarFrame = nil
      end

      -- Because the positioning is now changed so that y's will always be negative (as the frame is anchored on top left
      -- of entire screen, and anything to the right is negative), this should ensure that the current settings for people
      -- will work, altho the positioning might be strange
      -- (only for that old top-left anchor; a centered bar can legitimately sit above center)
      if profileDB.p == "TOPLEFT" and profileDB.y > 0 then
         profileDB.y = profileDB.y * -1
      end

      gcdBarFrame = CreateFrame("Frame", nil, UIParent)

      gcdBarFrame:SetFrameStrata("BACKGROUND")
      gcdBarFrame:SetSize(profileDB.w, profileDB.h)
      gcdBarFrame:SetPoint(profileDB.p, nil, profileDB.rp, profileDB.x, profileDB.y)

      gcdBarFrame:SetScript("OnUpdate", CooldownBarGlobal_OnUpdate)
      gcdBarFrame:SetScript("OnMouseDown", CooldownBarGlobal_OnMouseDown)
      gcdBarFrame:SetScript("OnMouseUp", CooldownBarGlobal_OnMouseUp)

      gcdBarFrame:SetMovable(true)

      w, h = gcdBarFrame:GetSize()

      -- Back drop - this is the 'grey bar' under the gcd bar
      gcdBarFrame.backdropTexture = gcdBarFrame:CreateTexture(nil, "BACKGROUND")
      gcdBarFrame.backdropTexture:SetDrawLayer("BACKGROUND", -8)
      gcdBarFrame.backdropTexture:SetTexture(media:Fetch('statusbar', profileDB.backgroundtexture))
      gcdBarFrame.backdropTexture:SetVertexColor(profileDB.backgroundColor.r, profileDB.backgroundColor.g, profileDB.backgroundColor.b, profileDB.backgroundColor.a)
      gcdBarFrame.backdropTexture:SetAllPoints(gcdBarFrame)

      -- Lag frame
      gcdBarFrame.lagBarTexture = gcdBarFrame:CreateTexture(nil, "BACKGROUND")
      gcdBarFrame.lagBarTexture:SetDrawLayer("BACKGROUND", 7)
      gcdBarFrame.lagBarTexture:SetTexture(media:Fetch('statusbar', profileDB.lagtexture))
      gcdBarFrame.lagBarTexture:SetVertexColor(profileDB.lagColor.r, profileDB.lagColor.g, profileDB.lagColor.b, profileDB.lagColor.a)

      -- Create main bar itself
      gcdBarFrame.barTexture = gcdBarFrame:CreateTexture(nil, "ARTWORK")
      gcdBarFrame.barTexture:SetTexture(media:Fetch('statusbar', profileDB.bartexture))
      gcdBarFrame.barTexture:SetVertexColor(profileDB.color.r, profileDB.color.g, profileDB.color.b, profileDB.color.a)

      -- Create spark overlay
      gcdBarFrame.sparkTexture = gcdBarFrame:CreateTexture(nil, "OVERLAY")
      gcdBarFrame.sparkTexture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
      gcdBarFrame.sparkTexture:SetBlendMode("ADD")

      -- Now set the things that will not change during updating
      barType = profileDB.barType

      -- Rotate spark if not horizontal
      if not CooldownBarGlobal:IsHorizontal() then
         gcdBarFrame.sparkTexture:SetRotation(90)
      end

      if CooldownBarGlobal:IsHorizontal() then
         -- Height of lag and gcd bars
         gcdBarFrame.lagBarTexture:SetHeight(h)
         gcdBarFrame.barTexture:SetHeight(h)

         -- Reference points for lag and gcd bar
         if barType == "HLR" then
            gcdBarFrame.lagBarTexture:SetPoint("RIGHT", gcdBarFrame, "RIGHT")
            gcdBarFrame.barTexture:SetPoint("LEFT", gcdBarFrame, "LEFT")
         else
            gcdBarFrame.lagBarTexture:SetPoint("LEFT", gcdBarFrame, "LEFT")
            gcdBarFrame.barTexture:SetPoint("RIGHT", gcdBarFrame, "RIGHT")
         end
      else
         -- Width of bars
         gcdBarFrame.barTexture:SetWidth(w)
         gcdBarFrame.lagBarTexture:SetWidth(w)

         -- Reference points
         if barType == "VBT" then
            gcdBarFrame.lagBarTexture:SetPoint("TOP", gcdBarFrame, "TOP")
            gcdBarFrame.barTexture:SetPoint("BOTTOM", gcdBarFrame, "BOTTOM")
         else
            gcdBarFrame.lagBarTexture:SetPoint("BOTTOM", gcdBarFrame, "BOTTOM")
            gcdBarFrame.barTexture:SetPoint("TOP", gcdBarFrame, "TOP")
         end
      end
   end

   function CooldownBarGlobal:ACTIONBAR_UPDATE_COOLDOWN()
      -- 61304 is the 'Global Cooldown' spell
      -- (the old GetSpellCooldown global was removed in 11.0; C_Spell returns a table instead)
      local cooldown = C_Spell.GetSpellCooldown(61304)
      if not cooldown then
         return
      end
      start, duration = cooldown.startTime, cooldown.duration

      -- Check for combat status and duration left (UnitAffectingCombat returns a boolean, not 1)
      if (UnitAffectingCombat("player") or profileDB.combatOnly == false) and duration > 0 then
         -- Make the frame if it isn't already there
         if not gcdBarFrame then
            CooldownBarGlobal:SetupFrame()
         end

         -- Check for showing spark
         if profileDB.spark then
            gcdBarFrame.sparkTexture:Show()
         else
            gcdBarFrame.sparkTexture:Hide()
         end

         -- Get the lag
         local _, _, homeLag, worldLag = GetNetStats()

         -- Now set the proportion of the lag of the duration and indicate it
         -- http://www.encyclopedia.com/topic/Reaction_Time.aspx
         -- 180 ms visual reaction time
         local lagBarLength

         if CooldownBarGlobal:IsHorizontal() then
            if worldLag + 180 >= duration * 1000 then
               lagBarLength = w
            else
               lagBarLength = w * (worldLag + 180) / (duration * 1000)
            end
            gcdBarFrame.lagBarTexture:SetWidth(lagBarLength)
         else
            if worldLag + 180 >= duration * 1000 then
               lagBarLength = h
            else
               lagBarLength = h * (worldLag + 180) / (duration * 1000)
            end
            gcdBarFrame.lagBarTexture:SetHeight(lagBarLength)
         end

         -- Show the frame, which will cause it's update to start getting events
         gcdBarFrame:Show()
      end
   end

   function CooldownBarGlobal:OnProfileChanged(event, database, newProfileKey)
      profileDB = database.profile
      CooldownBarGlobal:SetupFrame()
   end

   function CooldownBarGlobal_OnUpdate(self, elapsed)
      -- Start may not be initialized if the first thing done is to enable the move mode
      if start ~= nil and GetTime() - start < duration then
         -- Find the percentage complete
         local percentage = (GetTime() - start) / duration

         -- Show the bar
         if CooldownBarGlobal:IsHorizontal() then
            gcdBarFrame.barTexture:SetWidth(w * percentage)
         else
            gcdBarFrame.barTexture:SetHeight(h * percentage)
         end

         -- Show the spark if so configured
         if profileDB.spark then
            local sparkAlignment, sparkX, sparkY

            sparkX = 1
            sparkY = 1

            if barType == "HLR" then
               sparkAlignment = "LEFT"
               sparkX = w * percentage
            elseif barType == "HRL" then
               sparkAlignment = "RIGHT"
               sparkX = w * -percentage
            elseif barType == "VBT" then
               sparkAlignment = "BOTTOM"
               sparkY = h * percentage
            else
               sparkAlignment = "TOP"
               sparkY = h * -percentage
            end

            gcdBarFrame.sparkTexture:SetPoint("CENTER", gcdBarFrame, sparkAlignment, sparkX, sparkY)
         end
      else
         if not moveMode then
            gcdBarFrame:Hide()
         else
            if CooldownBarGlobal:IsHorizontal() then
               gcdBarFrame.lagBarTexture:SetWidth(0)
               gcdBarFrame.barTexture:SetWidth(0)
            else
               gcdBarFrame.lagBarTexture:SetHeight(0)
               gcdBarFrame.barTexture:SetHeight(0)
            end
         end
      end
   end

   function CooldownBarGlobal:IsHorizontal()
      if string.sub(barType, 1, 1) == "H" then
         return true
      else
         return false
      end
   end

   function CooldownBarGlobal_OnMouseDown(self, button)
      if button == "LeftButton" and not self.isMoving and not setburst then
         self:StartMoving()
         self.isMoving = true
      end
   end

   function CooldownBarGlobal_OnMouseUp(self, button)
      local p, _, rp, x, y = self:GetPoint()

      if button == "LeftButton" and self.isMoving then
         profileDB.x = x
         profileDB.y = y
         profileDB.p = p
         profileDB.rp = rp

         self:StopMovingOrSizing()
         self:SetUserPlaced(false)
         self.isMoving = false

         CooldownBarGlobal:SetupFrame()
      end
   end
end)
