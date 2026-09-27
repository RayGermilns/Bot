--// CyberHub Bot Script 
local OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

--// Config
local MAX_BOTS = 5
local botUsernames = {}          -- stored bot names (reference)
local admins = {[LocalPlayer.Name:lower()] = true}  -- permanent admins (you are auto admin)
local tempAdmins = {}            -- temporary admins
local runningCommands = {}       -- tracks active loops

local isOrbiting = false
local isFollowing = false
local orbitTarget = nil
local followTarget = nil
local autoDonateTarget = nil
local autoDonateConnection = nil
local orbitConnection = nil
local followConnection = nil
local noclipConnection = nil
local autoJoinEnabled = false

--// Chat function (works with both new & old chat)
local function botSay(msg)
    pcall(function()
        local channel = TextChatService.TextChannels and TextChatService.TextChannels.RBXGeneral
        if channel then
            channel:SendAsync(msg)
        else
            local events = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
            if events then
                events.SayMessageRequest:FireServer(msg, "All")
            end
        end
    end)
end

--// Noclip helper
local function setNoclip(state)
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    if state then
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name \~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

--// Stop everything
local function stopAll()
    isOrbiting = false
    isFollowing = false
    autoDonateTarget = nil

    if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
    if followConnection then followConnection:Disconnect() followConnection = nil end
    if autoDonateConnection then autoDonateConnection:Disconnect() autoDonateConnection = nil end
    setNoclip(false)

    runningCommands = {}
    botSay("Stopped All Running Command")
end

--// Orbit
local function startOrbit(targetName)
    stopAll()
    local target = Players:FindFirstChild(targetName)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        botSay("Target not found: " .. targetName)
        return
    end

    isOrbiting = true
    orbitTarget = target
    setNoclip(true)
    botSay("Orbiting " .. targetName .. "...")

    local angle = 0
    local distance = 8
    local height = 2
    local speed = 3

    orbitConnection = RunService.Heartbeat:Connect(function(dt)
        if not isOrbiting or not orbitTarget or not orbitTarget.Character then
            stopAll()
            return
        end
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local targetHRP = orbitTarget.Character:FindFirstChild("HumanoidRootPart")
        if not hrp or not targetHRP then return end

        angle = angle + speed * dt
        local offset = Vector3.new(math.cos(angle) * distance, height, math.sin(angle) * distance)
        hrp.CFrame = CFrame.new(targetHRP.Position + offset) * CFrame.Angles(0, angle + math.pi/2, 0)
    end)
end

--// Follow
local function startFollow(targetName)
    stopAll()
    local target = Players:FindFirstChild(targetName)
    if not target or not target.Character then
        botSay("Target not found: " .. targetName)
        return
    end

    isFollowing = true
    followTarget = target
    botSay("Following " .. targetName)

    followConnection = RunService.Heartbeat:Connect(function()
        if not isFollowing or not followTarget or not followTarget.Character then
            stopAll()
            return
        end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local targetHRP = followTarget.Character:FindFirstChild("HumanoidRootPart")
        if hum and targetHRP then
            hum:MoveTo(targetHRP.Position)
        end
    end)
end

--// Auto Donate
local function startAutoDonate(targetName)
    stopAll()
    autoDonateTarget = targetName
    botSay("AutoDonate started on " .. targetName)

    autoDonateConnection = task.spawn(function()
        while autoDonateTarget do
            botSay("Donate " .. autoDonateTarget .. " 50")
            task.wait(53)
        end
    end)
end

--// Admin check
local function isAdmin(playerName)
    local lower = playerName:lower()
    return admins[lower] or tempAdmins[lower]
end

local function isOwner(playerName)
    return playerName:lower() == LocalPlayer.Name:lower()
end

--// Chat command listener
local function onChatted(player, message)
    if not isAdmin(player.Name) then return end

    local msg = message:lower():gsub("%s+", " "):match("^%s*(.-)%s*$") -- trim
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word)
    end

    local cmd = args[1]
    local targetUser = args[2]

    if cmd == "!orbit" and targetUser then
        startOrbit(targetUser)
    elseif cmd == "!follow" and targetUser then
        startFollow(targetUser)
    elseif cmd == "!unfollow" and targetUser then
        if isFollowing then
            stopAll()
            botSay("Stopped Following " .. targetUser)
        end
    elseif cmd == "!autodonate" and targetUser then
        startAutoDonate(targetUser)
    elseif cmd == "!ad" and targetUser and isOwner(player.Name) then
        admins[targetUser:lower()] = true
        botSay("Admin Given To " .. targetUser)
    elseif cmd == "!ta" and targetUser and isOwner(player.Name) then
        tempAdmins[targetUser:lower()] = true
        botSay("Temporary Admin Given To " .. targetUser)
    elseif cmd == "!stop" then
        stopAll()
    end
end

-- Connect chat for all players (including yourself)
for _, plr in ipairs(Players:GetPlayers()) do
    plr.Chatted:Connect(function(msg)
        onChatted(plr, msg)
    end)
end
Players.PlayerAdded:Connect(function(plr)
    plr.Chatted:Connect(function(msg)
        onChatted(plr, msg)
    end)
end)

--// Auto Join / Rejoin
local function setupAutoJoin()
    LocalPlayer.OnTeleport:Connect(function(State)
        if autoJoinEnabled and State == Enum.TeleportState.Failed then
            task.wait(1)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)

    game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
        if autoJoinEnabled and child.Name == "ErrorPrompt" then
            task.wait(2)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end
    end)
end
setupAutoJoin()

--// UI
local Window = OrionLib:MakeWindow({
    Name = "CyberHub | Bot Script",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "BotScriptOrion",
    IntroText = "Bot Script Loaded"
})

local MainTab = Window:MakeTab({
    Name = "Bot Control",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local BotSection = MainTab:AddSection({Name = "Spawn / Manage Bots"})

local currentBotInput = ""
BotSection:AddTextbox({
    Name = "Bot Username",
    Default = "",
    TextDisappear = true,
    Callback = function(Value)
        currentBotInput = Value
    end
})

BotSection:AddButton({
    Name = "Spawn Bot",
    Callback = function()
        if #botUsernames >= MAX_BOTS then
            OrionLib:MakeNotification({
                Name = "Limit Reached",
                Content = "Maximum 5 bots allowed!",
                Time = 4
            })
            return
        end
        if currentBotInput == "" then
            OrionLib:MakeNotification({
                Name = "Error",
                Content = "Enter a bot username first",
                Time = 3
            })
            return
        end
        table.insert(botUsernames, currentBotInput)
        botSay("Bot Spawned!")
        task.wait(0.6)
        botSay("Commands: !Orbit {PlayerUser}, !Follow {PlayerUser}, !UnFollow {PlayerUser}, !AutoDonate {PlayerUser}, !Ad {PlayerUser}, !Ta {PlayerUser}, !Stop")
        OrionLib:MakeNotification({
            Name = "Bot Spawned",
            Content = currentBotInput .. " added (" .. #botUsernames .. "/" .. MAX_BOTS .. ")",
            Time = 4
        })
    end
})

BotSection:AddButton({
    Name = "Clear Bot List",
    Callback = function()
        botUsernames = {}
        OrionLib:MakeNotification({
            Name = "Cleared",
            Content = "Bot list cleared",
            Time = 3
        })
    end
})

BotSection:AddParagraph("Current Bots", "None yet")

local function updateBotParagraph()
    local text = #botUsernames > 0 and table.concat(botUsernames, ", ") or "None yet"
    -- Orion doesn't have live paragraph update easily, so just notify
end

local SettingsTab = Window:MakeTab({
    Name = "Settings",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

SettingsTab:AddToggle({
    Name = "Auto Join (Rejoin on kick)",
    Default = false,
    Callback = function(Value)
        autoJoinEnabled = Value
        OrionLib:MakeNotification({
            Name = "Auto Join",
            Content = Value and "Enabled" or "Disabled",
            Time = 3
        })
    end
})

SettingsTab:AddButton({
    Name = "Stop All Commands",
    Callback = function()
        stopAll()
    end
})

SettingsTab:AddButton({
    Name = "Destroy UI",
    Callback = function()
        OrionLib:Destroy()
    end
})

local AdminTab = Window:MakeTab({
    Name = "Admins",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

AdminTab:AddParagraph("You are automatically Permanent Admin", "Credits: Phanz11zz, Mekotiyori, Germilns, Valkoiq")

AdminTab:AddButton({
    Name = "Print Current Admins",
    Callback = function()
        local list = {}
        for name in pairs(admins) do table.insert(list, name) end
        for name in pairs(tempAdmins) do table.insert(list, name .. " (temp)") end
        botSay("Admins: " .. table.concat(list, ", "))
    end
})

-- Init
OrionLib:Init()

OrionLib:MakeNotification({
    Name = "BotScript Loaded!",
    Content = "You are Permanent Admin. Type commands in chat or use the UI.",
    Time = 6
})

print("Bot script loaded | You are admin | Max bots: 5")
