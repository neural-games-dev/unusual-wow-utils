-- Wrapped as an Unusual WoW Utils module: this only runs when "ChatTabCycler" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("ChatTabCycler", function()
   -- ChatTabCycler.lua

   -- (keybinding display names are defined in Core.lua so they show even while this module is disabled)

   -- Selects the docked chat tab at `index` (in the dock's left-to-right order)
   local function selectDockedTab(index)
      local frame = GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES[index]

      if not frame then
         return
      end

      FCF_Tab_OnClick(_G[frame:GetName() .. "Tab"], frame)
   end

   -- Function to cycle chat tabs
   local function cycleChatTab(direction)
      local currentFrame = SELECTED_CHAT_FRAME

      if not currentFrame then
         return
      end

      local dock = GENERAL_CHAT_DOCK
      local numTabs = #dock.DOCKED_CHAT_FRAMES
      -- Find the index of the currently selected tab
      local currentIndex

      for i, frame in ipairs(dock.DOCKED_CHAT_FRAMES) do
         if frame == currentFrame then
            currentIndex = i
            break
         end
      end

      if not currentIndex then
         return
      end

      -- Determine next index
      local nextIndex = currentIndex + direction

      if nextIndex > numTabs then
         nextIndex = 1
      elseif nextIndex < 1 then
         nextIndex = numTabs
      end

      -- Select the new chat tab
      selectDockedTab(nextIndex)
   end

   -- Bindings for keybindings
   function ChatTabCycler_NextTab()
      cycleChatTab(1)
   end

   function ChatTabCycler_PrevTab()
      cycleChatTab(-1)
   end

   -- for the Go To Tab 1-10 bindings; does nothing if there's no docked tab at `index`
   function ChatTabCycler_GoToTab(index)
      selectDockedTab(index)
   end
end)
