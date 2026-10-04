-- Wrapped as an Unusual WoW Utils module: this only runs when "ChatTabCycler" is enabled.
local _, UWU = ...

UWU:AddModuleChunk("ChatTabCycler", function()
   -- ChatTabCycler.lua

   -- Define the keybinding names and descriptions
   BINDING_HEADER_CHATTABCYCLER = "Chat Tab Cycler"
   BINDING_NAME_CHATTABCYCLER_NEXT = "Cycle to Next Chat Tab"
   BINDING_NAME_CHATTABCYCLER_PREV = "Cycle to Previous Chat Tab"

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
      FCF_Tab_OnClick(_G[dock.DOCKED_CHAT_FRAMES[nextIndex]:GetName() .. "Tab"], dock.DOCKED_CHAT_FRAMES[nextIndex])
   end

   -- Bindings for keybindings
   function ChatTabCycler_NextTab()
      cycleChatTab(1)
   end

   function ChatTabCycler_PrevTab()
      cycleChatTab(-1)
   end
end)
