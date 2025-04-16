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

-- Timer related variables
local timerFrame = nil
local timerActive = false
local timerDelay = 0
local timerFunc = nil
local timerLastUpdateTime = 0 -- Added to track time for manual delta calculation

-- Localized functions
-- local After = C_Timer.After -- Removing this as C_Timer is unavailable

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
    local silver = math.floor(math.mod(copper, 10000) / 100)
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

-- Forward declarations
local ScheduleNextMailProcessing
local ScheduleDelayedFunction
local ProcessSingleMail

-- process a single mail message
ProcessSingleMail = function(index)
    if not MailFrame or not MailFrame:IsShown() then
        OpenAllMail:StopMailProcessing("Mail frame closed")
        return
    end

    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(index)

    if sender == nil then
        -- debugPrint("Could not read header info for mail index " .. index .. ". Scheduling next attempt.")
        ScheduleNextMailProcessing() -- Try to skip this mail after a delay
        return
    end

    local moneyText = money > 0 and " (" .. FormatMoney(money) .. ")" or ""
    debugPrint("Processing mail " .. index .. ": From: " .. (sender or "Unknown") .. ", Subject: " .. (subject or "None") .. moneyText)

    local tookSomething = false
    if hasItem then
        -- debugPrint("Taking item from mail " .. index)
        totalItemsTaken = totalItemsTaken + 1
        TakeInboxItem(index)
        tookSomething = true
    end

    if money > 0 then
        -- debugPrint("Taking money ("..FormatMoney(money)..") from mail " .. index)
        totalMoneyTaken = totalMoneyTaken + money
        TakeInboxMoney(index)
        tookSomething = true
    end

    -- If nothing was taken, MAIL_INBOX_UPDATE won't fire.
    -- Schedule the next processing step directly.
    if not tookSomething then
        -- debugPrint("Mail " .. index .. " had no items or money. Scheduling next.")
        ScheduleNextMailProcessing()
    end
    -- If something WAS taken, we wait for MAIL_INBOX_UPDATE to call ScheduleNextMailProcessing
end

-- Schedules the processing of the next mail item after a delay
ScheduleNextMailProcessing = function()
    if not isProcessing then return end

    -- Critical: Only schedule if a timer isn't already active
    if timerActive then
        -- debugPrint("Timer already active, skipping schedule request.")
        return
    end

    currentMessageIndex = currentMessageIndex - 1
    -- debugPrint("Scheduling next mail check for index: " .. currentMessageIndex)

    if currentMessageIndex > 0 then
        -- Schedule the *actual* processing call to happen after the delay
        ScheduleDelayedFunction(0.5, function()
            if isProcessing then -- Double check processing status after delay
               ProcessSingleMail(currentMessageIndex)
            end
        end)
    else
        -- debugPrint("Reached end of mail (index 0). Stopping processing.")
        OpenAllMail:StopMailProcessing("Finished processing all mail.")
    end
end

-- Custom timer function using OnUpdate - executes a function after a delay
ScheduleDelayedFunction = function(delay, func)
    if not timerFrame then
        debugPrint("Timer frame not initialized!")
        return
    end
    -- This function now ASSUMES it's safe to schedule, 
    -- the check is done in ScheduleNextMailProcessing
    -- if timerActive then debugPrint("Warning: Overwriting timer (This shouldn't happen with new logic)") end
    
    timerDelay = delay
    timerFunc = func
    timerLastUpdateTime = GetTime() -- Initialize start time
    timerActive = true
    -- debugPrint("Timer started for "..delay.." seconds.")
    timerFrame:Show() -- Ensure the frame is shown to receive OnUpdate events
end

-- start mail processing
function OpenAllMail:StartMailProcessing()
    if isProcessing then
        -- debugPrint("Already processing mail")
        return
    end

    local numItems = GetInboxNumItems()
    if numItems == 0 then
        -- debugPrint("No mail to process")
        return
    end

    debugPrint("Starting mail processing for " .. numItems .. " messages.")
    isProcessing = true
    totalMessagesToProcess = numItems
    currentMessageIndex = numItems -- Start with the highest index
    totalMoneyTaken = 0
    totalItemsTaken = 0
    
    -- Cancel any potentially lingering timer from a previous run or error
    timerActive = false
    timerFunc = nil
    if timerFrame then timerFrame:Hide() end

    -- Process the first mail item immediately (no initial delay)
    ProcessSingleMail(currentMessageIndex)
end

-- stop mail processing
function OpenAllMail:StopMailProcessing(reason)
    if not isProcessing then return end

    isProcessing = false
    local moneyFormatted = FormatMoney(totalMoneyTaken)
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
    -- Create the timer frame
    timerFrame = CreateFrame("Frame", "OpenAllMailTimerFrame")
    if not timerFrame then
        debugPrint("FAILED to create timer frame!")
        return
    end
    timerFrame:Hide() -- Start hidden
    -- Change OnUpdate handler to manually calculate delta time
    timerFrame:SetScript("OnUpdate", function(self) -- Removed 'elapsed' parameter as it's reported nil
        if not timerActive then
            timerFrame:Hide() -- Hide if not active to save resources
            return
        end

        local currentTime = GetTime()
        local delta = currentTime - timerLastUpdateTime
        timerLastUpdateTime = currentTime -- Update for the next frame

        -- Ensure delta is not negative or excessively large if GetTime() behaves strangely
        if delta < 0 then delta = 0 end
        if delta > 1 then delta = 1 end -- Cap delta to prevent huge jumps if game lags/resumes

        timerDelay = timerDelay - delta -- Use calculated delta

        if timerDelay <= 0 then
            timerActive = false
            local funcToRun = timerFunc
            timerFunc = nil -- Clear before running to prevent re-entrancy issues
            timerFrame:Hide()
            
            if funcToRun then
                funcToRun() -- Execute the scheduled function
            end
        end
    end)
    
    -- Register main addon events
    OpenAllMailMainFrame:RegisterEvent("MAIL_SHOW")
    OpenAllMailMainFrame:RegisterEvent("MAIL_INBOX_UPDATE")
    OpenAllMailMainFrame:RegisterEvent("MAIL_CLOSED")
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
            -- Mail state updated. Schedule the *next* processing step.
            -- debugPrint("MAIL_INBOX_UPDATE received during processing. Scheduling next.")
            ScheduleNextMailProcessing()
        elseif MailFrame and MailFrame:IsVisible() then
             -- Ensure button exists if not processing
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
