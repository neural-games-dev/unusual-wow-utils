-- Wrapped as an Unusual WoW Utils module: this only runs when "CombatInterfaceManager" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("CombatInterfaceManager", function()
   --## ===============================================================================================
   --## ALL REQUIRED IMPORTS
   --## ===============================================================================================
   -- Libs / Packages
   local CombatInterfaceManager = LibStub('AceAddon-3.0'):GetAddon('CombatInterfaceManager');

   --## ===============================================================================================
   --## INTERNAL VARS & SET UP
   --## ===============================================================================================
   local Logger = CombatInterfaceManager:NewModule('Logger');

   --## ===============================================================================================
   --## DEFINING THE LOGGER METHODS
   --## ===============================================================================================
   function Logger:Init(cim)
      self.cim = cim;
      self.isPratLoaded = self.cim.utils:GetDbValue('isLoaded.prat');
   end

   function Logger:Debug(...)
      if (self.cim.db.profile.debugEnabled) then
         local prefix;

         if (self.isPratLoaded) then
            prefix = self.cim.chalk:debug('[DEBUG]');
         else
            prefix = self.cim.chalk:debug('[DEBUG] ') .. self.cim.chalk:ace('(' .. tostring(date()) .. ')');
         end

         self.cim:Print(prefix, ...);
      end
   end

   function Logger:Print(...)
      if (self.cim.utils:GetDbValue('debugEnabled')) then
         self:Debug(...);
      else
         self.cim:Print(...);
      end
   end
end)
