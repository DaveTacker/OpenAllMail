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

-- Money icon texture paths
local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

-- Function to format copper into gold/silver/copper with icons
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

-- Function to format copper into gold/silver/copper
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

-- Function to create the button
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

-- Function to process a single mail message
local function ProcessSingleMail(index)
    if not MailFrame or not MailFrame:IsShown() then
        OpenAllMail:StopMailProcessing("Mail frame closed")
        return
    end

    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(index)
    
    if sender == nil then
        debugPrint("Could not read header info for mail index " .. index .. ". Skipping.")
        return
    end

    local moneyText = money > 0 and " (" .. FormatMoney(money) .. ")" or ""
    debugPrint("Processing mail [" .. index .. "] From: " .. (sender or "Unknown") .. ", Subject: " .. (subject or "None") .. moneyText)
    
    if hasItem then
        TakeInboxItem(index)
    end
    
    if money > 0 then
        totalMoneyTaken = totalMoneyTaken + money
        TakeInboxMoney(index)
    end
end

-- Function to start mail processing
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

    isProcessing = true
    totalMessagesToProcess = numItems
    currentMessageIndex = numItems
    totalMoneyTaken = 0
    
    debugPrint("Starting to process " .. numItems .. " mail messages")
    ProcessSingleMail(currentMessageIndex)
end

-- Function to stop mail processing
function OpenAllMail:StopMailProcessing(reason)
    if not isProcessing then return end
    
    isProcessing = false
    totalMessagesToProcess = 0
    currentMessageIndex = 0
    
    if reason then
        debugPrint("Stopped processing: " .. reason)
    end
    
    debugPrint("Total money taken: " .. FormatMoney(totalMoneyTaken))
    totalMoneyTaken = 0
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
            currentMessageIndex = currentMessageIndex - 1
            if currentMessageIndex > 0 then
                ProcessSingleMail(currentMessageIndex)
            else
                OpenAllMail:StopMailProcessing("All messages processed")
            end
        elseif MailFrame and MailFrame:IsVisible() then
            CreateOpenAllButton()
        end
    elseif event == "MAIL_CLOSED" then
        OpenAllMail:StopMailProcessing("Mail frame closed")
        if button then
            button:Hide()
        end
    end
end

-- debugPrint("OpenAllMail AddOn loaded.") -- Keep this commented for now unless debugging load issues
