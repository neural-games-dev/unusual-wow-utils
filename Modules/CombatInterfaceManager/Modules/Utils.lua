-- Wrapped as an Unusual WoW Utils module: this only runs when "CombatInterfaceManager" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("CombatInterfaceManager", function()
   --## ===============================================================================================
   --## ALL REQUIRED IMPORTS
   --## ===============================================================================================
   -- Libs / Packages
   local dialog = LibStub("AceConfigDialog-3.0")
   local CombatInterfaceManager = LibStub("AceAddon-3.0"):GetAddon("CombatInterfaceManager")

   --## ===============================================================================================
   --## INTERNAL VARS & SET UP
   --## ===============================================================================================
   local Utils = CombatInterfaceManager:NewModule("Utils")

   --## ===============================================================================================
   --## DEFINING ALL CUSTOM UTILS TO BE USED THROUGHOUT THE ADDON
   --## ===============================================================================================
   function Utils:Init(cim)
      self.cim = cim
   end

   function Utils:Capitalize(str)
      local lower = string.lower(str)
      return (lower:gsub("^%l", string.upper))
   end

   function Utils:HandleConfigOptionsDisplay()
      if dialog.OpenFrames["CombatInterfaceManager"] then
         self.cim.logger:Print("Hiding the config options window.")
         dialog:Close("CombatInterfaceManager")
      else
         self.cim.logger:Print("Showing the config options window.")
         dialog:Open("CombatInterfaceManager")
      end
   end

   --## --------------------------------------------------------------------------
   --## DATABASE OPERATION FUNCTIONS
   --## --------------------------------------------------------------------------
   function Utils:GetDbValue(key)
      local value
      -- the line below does a RegExp `match` for strings that look like 'someTable.someKey'
      local isMultiKey = key:match("%.")

      if isMultiKey then
         local table_name, key_name = string.match(key, "(.*)%.(.*)")
         self:VerifyDbTable(table_name, key_name)
         value = self.cim.db.profile[table_name][key_name]
      else
         value = self.cim.db.profile[key]
      end

      self.cim.logger:Debug(
         'GetDbValue: Returning "' .. tostring(value) .. '" for "' .. tostring(key) .. '".'
      )

      return value
   end

   function Utils:SetDbTableItem(table_name, key_name, value)
      self.cim.logger:Debug(
         'SetDbTableItem: Setting "'
            .. tostring(key_name)
            .. '" to "'
            .. tostring(value)
            .. '" in table "'
            .. tostring(table_name)
            .. '".'
      )

      self:VerifyDbTable(table_name, key_name)
      self.cim.db.profile[table_name][key_name] = value
   end

   function Utils:SetDbValue(key_name, value)
      self.cim.logger:Debug(
         'SetDbValue: Setting "' .. tostring(key_name) .. '" to "' .. tostring(value) .. '".'
      )

      self.cim.db.profile[key_name] = value
   end

   function Utils:VerifyDbTable(table_name, key_name)
      if not self.cim.db.profile[table_name] then
         self.cim.logger:Debug("VerifyDB: Table missing, creating an empty one...")
         self.cim.db.profile[table_name] = {}
      end

      if not self.cim.db.profile[table_name][key_name] then
         self.cim.logger:Debug("VerifyDB: Key missing, setting a starting nil value...")
         self.cim.db.profile[table_name][key_name] = nil
      end
   end
end)
