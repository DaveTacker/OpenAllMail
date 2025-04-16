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

-- State tracking variables
local isProcessing = false
local totalMessagesToProcess = 0
local currentMessageIndex = 0
local totalMoneyTaken = 0
local totalItemsTaken = 0

-- Money icon texture paths
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- format copper into gold/silver/copper with icons
local function FormatMoneyWithIcons(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.mod(copper, 10000) / 100
    local copperRem = math.mod(copper, 100)
    
    local result = ""
    if gold > 0 then
        result = result .. gold .. GOLD_ICON .. " "
    end
    if silver > 0 or gold > 0 then
        result = result .. silver .. SILVER_ICON .. " "
    end
    result = result .. copperRem .. COPPER_ICON
    return result
end

-- format copper into gold/silver/copper
local function FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.mod(copper, 10000) / 100
    local copperRem = math.mod(copper, 100)
    
    local result = ""
    if gold > 0 then
        result = result .. gold .. "g "
    end
    if silver > 0 or gold > 0 then
        result = result .. silver .. "s "
    end
    result = result .. copperRem .. "c"
    return result
end

local function debugPrint(message)
    if DEBUG then
        DEFAULT_CHAT_FRAME:AddMessage(addonName .. ": " .. message, 1.0, 1.0, 0.0) -- Yellow text
    end
end

-- create the button
local function CreateOpenAllButton()
    if not MailFrame or not MailFrame:IsShown() then
        return
    end

    if button and button:IsShown() then
        return
    end

    if button and not button:IsShown() then
        button:Show()
        return
    end

    button = CreateFrame("Button", "OpenAllMailButton", MailFrame, "UIPanelButtonTemplate")
    if not button then
        debugPrint("FAILED to create button frame!")
        return
    end
    
    button:SetText("Open All")
    button:SetWidth(80)
    button:SetHeight(22)
    button:SetPoint("BOTTOM", MailFrame, "BOTTOM", 0, 100)

    button:SetScript("OnClick", function(self)
        OpenAllMail:StartMailProcessing()
    end)

    button:Show()
end

-- Forward declaration for TryProcessNextMail
local TryProcessNextMail

-- process a single mail message
local function ProcessSingleMail(index)
    if not MailFrame or not MailFrame:IsShown() then
        OpenAllMail:StopMailProcessing("Mail frame closed")
        return
    end

    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(index)

    if sender == nil then
        debugPrint("Could not read header info for mail index " .. index .. ". Attempting to proceed to next.")
        TryProcessNextMail() -- Try to skip this mail
        return
    end

    local moneyText = money > 0 and " (" .. FormatMoney(money) .. ")" or ""
    debugPrint("Processing mail " .. index .. ": From: " .. (sender or "Unknown") .. ", Subject: " .. (subject or "None") .. moneyText .. " HasItem: " .. tostring(hasItem))

    local tookSomething = false
    if hasItem then
        totalItemsTaken = totalItemsTaken + 1
        TakeInboxItem(index)
        tookSomething = true
    end

    if money > 0 then
        totalMoneyTaken = totalMoneyTaken + money
        TakeInboxMoney(index)
        tookSomething = true
    end

    -- If nothing was taken, MAIL_INBOX_UPDATE might not fire, so manually advance.
    if not tookSomething then
        TryProcessNextMail()
    end
end

-- Tries to process the next mail item or stop if finished
TryProcessNextMail = function()
    if not isProcessing then return end

    currentMessageIndex = currentMessageIndex - 1
    debugPrint("Mail update received or manually advanced. Next index: " .. currentMessageIndex)

    if currentMessageIndex > 0 then
        if isProcessing then -- Check again in case processing was stopped during the delay
            ProcessSingleMail(currentMessageIndex)
        end
    else
        -- We've processed or attempted to process index 1, now stop.
        OpenAllMail:StopMailProcessing("Finished processing all mail.")
    end
end

-- start mail processing
function OpenAllMail:StartMailProcessing()
    if isProcessing then
        debugPrint("Already processing mail")
        return
    end

    local numItems = GetInboxNumItems()
    if numItems == 0 then
        debugPrint("No mail to process")
        return
    end

    debugPrint("Starting mail processing for " .. numItems .. " messages.")
    isProcessing = true
    totalMessagesToProcess = numItems
    currentMessageIndex = numItems -- Start with the highest index
    totalMoneyTaken = 0
    totalItemsTaken = 0 -- Reset item count here

    ProcessSingleMail(currentMessageIndex) -- Process the first one (highest index)
end

-- stop mail processing
function OpenAllMail:StopMailProcessing(reason)
    if not isProcessing then return end

    isProcessing = false
    local moneyFormatted = FormatMoneyWithIcons(totalMoneyTaken)
    debugPrint("Stopped: " .. reason .. " Processed ~" .. (totalMessagesToProcess - currentMessageIndex) .. "/" .. totalMessagesToProcess .." mails. Items: " .. totalItemsTaken .. ", Money: " .. moneyFormatted)

    -- Reset state
    totalMessagesToProcess = 0
    currentMessageIndex = 0
    totalMoneyTaken = 0
    totalItemsTaken = 0

    -- Re-enable button maybe?
    -- Refresh mail list or check minimap icon status
    if MiniMapMailFrame and MiniMapMailFrame:IsVisible() and GetInboxNumItems() == 0 then
        MiniMapMailFrame:Hide()
    end
end

--[[
  Initialize the addon
  Register events for the mail frame
--]]
function OpenAllMail:Init()
    OpenAllMailMainFrame:RegisterEvent("MAIL_SHOW")
    OpenAllMailMainFrame:RegisterEvent("MAIL_INBOX_UPDATE")
    OpenAllMailMainFrame:RegisterEvent("MAIL_CLOSED")
    CreateOpenAllButton()
end

--[[
  Handle events for the mail frame.
--]]
function OpenAllMail:OnEvent(event)
    if event == "MAIL_SHOW" then
        if MailFrame and MailFrame:IsShown() then
            CreateOpenAllButton()
        end
    elseif event == "MAIL_INBOX_UPDATE" then
        if isProcessing then
            -- Mail updated, likely means item/money taken. Try processing the next one.
            TryProcessNextMail()
        elseif MailFrame and MailFrame:IsVisible() then
             -- If not processing, but mail updates and frame is visible,
             -- ensure button exists (e.g., after deleting mail manually)
            CreateOpenAllButton()
        end
    elseif event == "MAIL_CLOSED" then
        OpenAllMail:StopMailProcessing("Mail frame closed")
        if button then
            button:Hide()
        end

        -- Hide MiniMapMailFrame if it's visible and inbox is empty
        if MiniMapMailFrame and MiniMapMailFrame:IsVisible() and GetInboxNumItems() == 0 then
            MiniMapMailFrame:Hide()
        end
    end
end
