-- Always use the correct Lua functions for World of Warcraft Classic v1.12
-- https://wowwiki-archive.fandom.com/wiki/Lua_functions
-- https://wowwiki-archive.fandom.com/wiki/World_of_Warcraft_API
-- https://wowwiki-archive.fandom.com/wiki/Events_A-Z_(full_list)

OpenAllMail = {}

local addonName = "Open All Mail"
local button = nil -- Will hold our button frame

-- Constants
local DEBUG = true

-- NOTE: "Auction House" might need localization if not using an English client.
local AUCTION_HOUSE_SENDER = "Auction House"

local function debugPrint(message)
    if DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": " .. message, 1.0, 1.0, 0.0) -- Yellow text
    end
end

-- Function to create the button
local function CreateOpenAllButton()
    -- debugPrint("CreateOpenAllButton called.")

    if not MailFrame or not MailFrame:IsShown() then
        -- debugPrint("MailFrame not found or not shown. Button creation aborted.")
        return
    end

    if button and button:IsShown() then
        -- debugPrint("Button already exists and is shown.")
        return
    end

    -- If button exists but is hidden, just show it
    if button and not button:IsShown() then
        -- debugPrint("Button exists but is hidden. Showing it.")
        button:Show()
        return
    end

    -- Create the button if it doesn't exist
    -- debugPrint("Creating button frame...")
    button = CreateFrame("Button", "OpenAllMailButton", MailFrame, "UIPanelButtonTemplate")
    if not button then
        debugPrint("FAILED to create button frame!")
        return
    end
    -- debugPrint("Button frame created: ", button)
    button:SetText("Open All")
    button:SetWidth(80)
    button:SetHeight(22)
    -- Anchor to the bottom-center of the main MailFrame
    -- debugPrint("Setting button point...")
    button:SetPoint("BOTTOM", MailFrame, "BOTTOM", 0, 100)
    -- debugPrint("Button point set.")

    button:SetScript("OnClick", function(self)
        OpenAllMail:OpenAndProcessMail()
    end)

    -- Explicitly show it after creation, just in case
    button:Show()
    -- debugPrint("Button created, positioned, and shown.")
end

-- Function to handle opening and processing mail
function OpenAllMail:OpenAndProcessMail()
    -- debugPrint("'Open All' clicked.")
    local initialNumItems = GetInboxNumItems()
    local initialMoney = 0
    -- debugPrint("Found " .. initialNumItems .. " items in inbox initially.")

    if initialNumItems == 0 then
        debugPrint("No mail to process.")
        return
    end

    -- Iterate backwards because deleting/taking items shifts indices
    for i = initialNumItems, 1, -1 do
        -- debugPrint("Processing mail at index " .. i .. ", " .. GetInboxNumItems() .. " items remaining.")

        -- Get sender info BEFORE attempting to loot/delete
        -- canRead might be false if header info is unavailable (e.g., during rapid updates)
        local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(i);
        

        if sender ~= nil then
            -- debugPrint("Processing mail [" .. i .. "] From: " .. (sender or "Unknown") .. ", Subject: " .. (subject or "None"))
            
            -- Attempt to take item/money. This marks the mail as read.
            if hasItem then
              debugPrint("Processing mail [" .. i .. "] From: " .. (sender or "Unknown") .. ", Subject: " .. (subject or "None"))
              TakeInboxItem(i)
            end
            
            if money > 0 then
                debugPrint("Processing mail [" .. i .. "] From: " .. (sender or "Unknown") .. ", Subject: " .. (subject or "None"))
                initialMoney = initialMoney + money
                TakeInboxMoney(i)
            end
            -- debugPrint("Took items/money from mail index " .. i .. " (if any). Mail marked as read.")
            -- debugPrint("Loop After TakeInboxItem: Current GetInboxNumItems() = " .. GetInboxNumItems())
            
            -- Now check if it should be deleted (only AH mail) - DISABLED
            -- We use the sender info obtained *before* taking the item
            -- Check if the sender string contains AUCTION_HOUSE_SENDER (plain text search)
            if sender and string.find(sender, AUCTION_HOUSE_SENDER, 1, true) then
              -- debugPrint("Mail [" .. i .. "] sender ('" .. sender .. "') contains '" .. AUCTION_HOUSE_SENDER .. "'. Would delete (DISABLED).")
                 -- DeleteInboxItem(i) -- DISABLED
            else
                --  debugPrint("Mail [" .. i .. "] sender ('" .. (sender or "NIL") .. "') does not contain '" .. AUCTION_HOUSE_SENDER .. "'. Leaving as read.")
            end
            -- Consider adding a small delay here if experiencing "Internal Mail Error"
            -- C_Timer.After(0.1, function() end) -- C_Timer not available in 1.12
        else
            debugPrint("Could not read header info for mail index " .. i .. ". Skipping.")
        end
        -- debugPrint("Loop End: Finished processing index i = " .. i)
    end

    debugPrint("Finished processing mail. Money taken: " .. initialMoney)
    -- Update the inbox display after processing is complete - Temporarily Disabled
    -- CheckInbox()
end

--[[
  Initialize the addon
  Register events for the mail frame
--]]
function OpenAllMail:Init()
    -- debugPrint("Init called.")
    OpenAllMailMainFrame:RegisterEvent("MAIL_SHOW") -- Fired when the mail frame is opened
    OpenAllMailMainFrame:RegisterEvent("MAIL_INBOX_UPDATE") -- Fired when mail list changes (new mail, deletions)
    OpenAllMailMainFrame:RegisterEvent("MAIL_CLOSED") -- Fired when the mail frame is closed
    CreateOpenAllButton()
end

--[[
  Handle events for the mail frame.
--]]
function OpenAllMail:OnEvent(event)
    -- debugPrint("Direct event print:", event) -- Print event directly first
    -- debugPrint("OnEvent fired - Event: ", event)

    -- Temporarily disable the logic inside
    if event == "MAIL_SHOW" then
        -- debugPrint("MAIL_SHOW event received.")
        -- Check if MailFrame exists and is visible *when the event fires*
        if MailFrame and MailFrame:IsShown() then
            -- debugPrint("MailFrame exists and is shown. Proceeding to create/show button.")
            CreateOpenAllButton()
        else
            -- debugPrint("MailFrame not found or not shown when MAIL_SHOW fired.")
            -- Maybe try again slightly later?
            -- C_Timer.After(0.1, CreateOpenAllButton) -- Requires C_Timer, might not be in 1.12
        end
    elseif event == "MAIL_INBOX_UPDATE" then
        -- debugPrint("MAIL_INBOX_UPDATE event received.")
        -- If the inbox updates while it's open, ensure the button is still there
        if MailFrame and MailFrame:IsVisible() then
            CreateOpenAllButton() -- This will ensure it's shown if hidden, or created if missing
        end
    elseif event == "MAIL_CLOSED" then
        -- debugPrint("MAIL_CLOSED event received.")
        -- If the inbox closes, hide the button
        if button then
            button:Hide()
        end
    end
end

-- debugPrint("OpenAllMail AddOn loaded.") -- Keep this commented for now unless debugging load issues
