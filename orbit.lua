-- UI ISNT MINE!!! full credits for arcane ui go to "192.0.0.2" on discord!
loadstring(game:HttpGet("https://raw.githubusercontent.com/debrainers/scripts/refs/heads/main/ArcaneUiNOTMINE"))()
repeat wait() until Arcane

local Window = Arcane:CreateWindow("@debrainers", Vector2.new(650, 350), "Default")

Window:CreateTabSection("Cheats")
local Tab = Window:CreateTab("Main")

local Players = game:GetService("Players")
local Mouse = Players.LocalPlayer:GetMouse()
local player = Players.LocalPlayer
local targetPlayer = nil
local orbitEnabled = false
local autoStompEnabled = false
local antiStompEnabled = false
local antiStompActive = false
local manualVoidEnabled = false
local teleporting = false
local autoVoidActive = false
local lastKnownTargetPosition = nil
local lastKnownTarget = nil
local lastKnownTargetName = nil
local voidStartPosition = nil
local orbitStartPosition = nil
local lastStompTime = 0
local stompActive = false
local stompEndTime = 0
local orbitActive = false
local orbitRadius = 15
local orbitSpeed = 0
local healthThreshold = 30
local healthSaveEnabled = true
local healthVoidActive = false
local knockedVoidActive = false
local knockedVoidDone = false
local deadVoidActive = false

local OFFSET = 0x18C
local OFF_PRIMITIVE = 0x148
local OFF_CFRAME = 0xC0

local playerNames = {}
local selectedPlayer = nil
local dropdown = nil

local groupMonitor = {}
groupMonitor.kickOnJoin = false
groupMonitor.kickOnJoinToggle = nil

groupMonitor.GROUPS = {
    {id = 8068202, name = "da hood stars", url = "https://groups.roblox.com/v1/groups/8068202/users?limit=100&sortOrder=Asc"},
    {id = 10604500, name = "da hood verified", url = "https://groups.roblox.com/v1/groups/10604500/users?limit=100&sortOrder=Asc"},
    {id = 17215700, name = "stars staff", url = "https://groups.roblox.com/v1/groups/17215700/users?limit=100&sortOrder=Asc"}
}
groupMonitor.trackedUsers = {}
groupMonitor.activeUsers = {}
groupMonitor.notifiedThisSession = {}
groupMonitor.loadingComplete = false
groupMonitor.groupsLoading = 0

local function getPrimitive(part)
    local addr = part.Address
    if not addr or addr == 0 then return nil end
    local prim = memory_read("uintptr_t", addr + OFF_PRIMITIVE)
    if not prim or prim == 0 then return nil end
    return prim
end

local function writeUprightRot(primAddr)
    local base = primAddr + OFF_CFRAME
    memory_write("float", base + 0x00, 1)
    memory_write("float", base + 0x04, 0)
    memory_write("float", base + 0x08, 0)
    memory_write("float", base + 0x0C, 0)
    memory_write("float", base + 0x10, 1)
    memory_write("float", base + 0x14, 0)
    memory_write("float", base + 0x18, 0)
    memory_write("float", base + 0x1C, 0)
    memory_write("float", base + 0x20, 1)
end

function teleportToTargetTorso()
    if not targetPlayer or not targetPlayer.Character then return end
    local targetPos = getTorsoPosition(targetPlayer)
    if not targetPos then return end
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = character.HumanoidRootPart
    hrp.Position = Vector3.new(targetPos.X, targetPos.Y + 2.5, targetPos.Z)
end

local function performStomp(targetPosition)
    if not targetPosition or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hrpPrim = getPrimitive(hrp)
    hrp.Position = Vector3.new(targetPosition.X, targetPosition.Y + 2.5, targetPosition.Z)
    if hrpPrim then
        writeUprightRot(hrpPrim)
    end
    keypress(0x45)
    task.wait(0.01)
    keyrelease(0x45)
end

function kickPlayer(targetPlayer)
    if not targetPlayer then return false end
    local playerAddr = targetPlayer.Address
    if not playerAddr then return false end
    local userIdOffset = 0x2C8
    local success = pcall(function()
        memory_write("int", playerAddr + userIdOffset, 0)
    end)
    if success then
        return true
    end
    pcall(function()
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
            local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
            local humanoidAddr = humanoid.Address
            if humanoidAddr then
                memory_write("float", humanoidAddr + 0x194, 0)
            end
        end
    end)
    return false
end

function groupMonitor:fetchGroupMembers(group, cursor)
    local url = group.url
    if cursor and cursor ~= "" then
        url = url .. "&cursor=" .. cursor
    end
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    if success and result then
        local success2, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(result)
        end)
        if success2 and data and data.data then
            for _, member in ipairs(data.data) do
                local username = member.user.username
                local usernameLower = username:lower()
                local displayName = member.user.displayName or username
                local rank = member.role.name
                if not self.trackedUsers[usernameLower] then
                    self.trackedUsers[usernameLower] = {}
                end
                self.trackedUsers[usernameLower][group.name] = {
                    username = username,
                    displayName = displayName,
                    rank = rank,
                    group = group.name,
                    hasBadge = member.user.hasVerifiedBadge
                }
            end
            if data.nextPageCursor and data.nextPageCursor ~= "" then
                self:fetchGroupMembers(group, data.nextPageCursor)
            else
                self.groupsLoading = self.groupsLoading - 1
                if self.groupsLoading == 0 then
                    self:loadingComplete()
                end
            end
        end
    end
end

function groupMonitor:loadingComplete()
    self:checkCurrentPlayers()
    self:setupEventListeners()
    self.loadingComplete = true
end

function groupMonitor:getUserInfo(username)
    if not username then return nil end
    local userInfo = self.trackedUsers[username:lower()]
    if not userInfo then 
        return nil 
    end
    for _, group in ipairs(self.GROUPS) do
        if userInfo[group.name] then
            return userInfo[group.name]
        end
    end
    return nil
end

function groupMonitor:isUserTracked(username)
    if not username then return false end
    return self.trackedUsers[username:lower()] ~= nil
end

function groupMonitor:checkCurrentPlayers()
    local currentPlayers = Players:GetPlayers()
    for _, plr in ipairs(currentPlayers) do
        local username = plr.Name
        if self:isUserTracked(username) and not self.activeUsers[username] then
            self.activeUsers[username] = true
            local userInfo = self:getUserInfo(username)
            if userInfo then
                self:notifyUser(plr, userInfo, "already in server")
                if self.kickOnJoin then
                    local success = kickPlayer(plr)
                    if success then
                        notify("kicked " .. username, "kick if staff", 5)
                    end
                end
            end
        end
    end
end

function groupMonitor:setupEventListeners()
    Players.PlayerAdded:Connect(function(plr)
        wait(1)
        local username = plr.Name
        if self:isUserTracked(username) then
            local userInfo = self:getUserInfo(username)
            if userInfo and not self.activeUsers[username] then
                self.activeUsers[username] = true
                self:notifyUser(plr, userInfo, "joined")
                if self.kickOnJoin then
                    local success = kickPlayer(plr)
                    if success then
                        notify("kicked " .. username, "kick if staff", 5)
                    end
                end
            end
        end
    end)
end

function groupMonitor:notifyUser(plr, userInfo, action)
    local username = plr.Name
    local message
    local title = "rank: " .. userInfo.rank
    if action == "already in server" then
        if self.notifiedThisSession[username] then return end
        self.notifiedThisSession[username] = true
        message = string.format("%s (@%s) is in your server", userInfo.displayName, userInfo.username)
        notify(message, title, 60)
    elseif action == "joined" then
        message = string.format("%s (@%s) has joined your server", userInfo.displayName, userInfo.username)
        notify(message, title, 180)
    end
end

function groupMonitor:countUniqueUsers()
    local count = 0 for _ in pairs(self.trackedUsers) do count = count + 1 end return count
end

function groupMonitor:initialize()
    self.groupsLoading = #self.GROUPS
    for _, group in ipairs(self.GROUPS) do
        self:fetchGroupMembers(group)
    end
end

local function sortPlayerNames(names)
    table.sort(names, function(a, b)
        return a:lower() < b:lower()
    end)
    return names
end

local function updatePlayerList()
    local newNames = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            table.insert(newNames, plr.Name)
        end
    end
    playerNames = sortPlayerNames(newNames)
    if dropdown then
        dropdown:Refresh(playerNames)
    end
end

updatePlayerList()

Players.PlayerAdded:Connect(function(plr)
    updatePlayerList()
    if lastKnownTargetName and plr.Name == lastKnownTargetName then
        targetPlayer = plr
        lastKnownTarget = plr
        notify("target rejoined", "orbit", 5)
        if orbitEnabled then
            teleporting = false
            task.wait(0.1)
            startOrbit()
        end
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    updatePlayerList()
    if plr == targetPlayer or (lastKnownTargetName and plr.Name == lastKnownTargetName) then
        lastKnownTarget = targetPlayer
        lastKnownTargetName = targetPlayer and targetPlayer.Name or lastKnownTargetName
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            lastKnownTargetPosition = targetPlayer.Character.HumanoidRootPart.Position
        end
        targetPlayer = nil
        if orbitEnabled then
            stopOrbitAndReturn("target left - returning")
        end
    end
end)

function resetHumanoidState()
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    local addr = humanoid.Address
    if not addr then return end
    local v = Vector3.new(0, 0, 0)
    pcall(function()
        memory_write("float", addr + OFFSET,     v.X)
        memory_write("float", addr + OFFSET + 4, v.Y)
        memory_write("float", addr + OFFSET + 8, v.Z)
    end)
end

function checkAntiStomp()
    if not antiStompEnabled then 
        antiStompActive = false
        return 
    end
    local character = player.Character
    if not character then return end
    local bodyEffects = character:FindFirstChild("BodyEffects")
    if not bodyEffects then return end
    local koValue = bodyEffects:FindFirstChild("K.O")
    if koValue and koValue.Value then
        resetHumanoidState()
        if not antiStompActive then
            antiStompActive = true
            notify("anti stomp activated", "anti stomp", 5)
        end
    else
        antiStompActive = false
    end
end

task.spawn(function()
    while true do
        task.wait(0.1)
        pcall(checkAntiStomp)
    end
end)

function pressEKey()
    keypress(0x45)
    task.wait(0.01)
    keyrelease(0x45)
end

function returnToStartPosition()
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") and orbitStartPosition then
        pcall(function()
            character.HumanoidRootPart.Position = orbitStartPosition
        end)
        notify("returned to start", "orbit", 5)
    end
end

function returnToVoidStartPosition()
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") and voidStartPosition then
        pcall(function()
            character.HumanoidRootPart.Position = voidStartPosition
        end)
        voidStartPosition = nil
        notify("returned from void", "void", 5)
    end
end

function stopOrbitAndReturn(reason)
    if orbitEnabled or orbitActive then
        orbitEnabled = false
        orbitActive = false
        teleporting = false
        if orbitToggle then orbitToggle:SetValue(false) end
        returnToStartPosition()
        if reason then
            notify(reason, "orbit", 5)
        end
    end
end

function getPlayerStatus(plr)
    if not plr or not plr.Character then return "no char" end
    local bodyEffects = plr.Character:FindFirstChild("BodyEffects")
    if not bodyEffects then return "no body" end
    local koValue = bodyEffects:FindFirstChild("K.O")
    local deadValue = bodyEffects:FindFirstChild("Dead")
    local sDeathValue = bodyEffects:FindFirstChild("SDeath")
    if not koValue or not deadValue then return "no vals" end
    if deadValue.Value or (sDeathValue and sDeathValue.Value) then
        return "dead"
    elseif koValue.Value then
        return "ko"
    else
        return "alive"
    end
end

function getTorsoPosition(plr)
    if not plr or not plr.Character then return nil end
    local torso = plr.Character:FindFirstChild("UpperTorso")
    if not torso then
        torso = plr.Character:FindFirstChild("Torso")
    end
    if not torso then
        torso = plr.Character:FindFirstChild("LowerTorso")
    end
    if not torso then
        torso = plr.Character:FindFirstChild("HumanoidRootPart")
    end
    if torso then
        return torso.Position
    end
    return nil
end

function hasSpawnProtection(plr)
    if not plr or not plr.Character then return false end
    local character = plr.Character
    if character:FindFirstChildOfClass("ForceField") then
        return true
    end
    return false
end

function shouldAutoVoid()
    if targetPlayer and hasSpawnProtection(targetPlayer) then
        return true, "spawn protection"
    end
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health < healthThreshold then
            return true, "health below " .. healthThreshold
        end
    end
    return false, nil
end

function getRandomOrbitPoint(center, radius)
    local x = (math.random() * 2 - 1) * radius
    local y = (math.random() * 2 - 1) * radius
    local z = (math.random() * 2 - 1) * radius
    return Vector3.new(center.X + x, center.Y + y, center.Z + z)
end

function startVoid(isAutoVoid)
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end
    local humanoidRootPart = character.HumanoidRootPart
    if not isAutoVoid then
        if voidStartPosition == nil then
            voidStartPosition = humanoidRootPart.Position
        end
    end
    task.spawn(function()
        local voidActive = true
        while voidActive do
            if not player.Character then
                local timeout = 0
                while not player.Character and timeout < 200 do
                    task.wait(0.1)
                    timeout = timeout + 1
                end
                if player.Character then
                    humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
                    if not humanoidRootPart then
                        break
                    end
                else
                    break
                end
            end
            if isAutoVoid then
                local shouldStillVoid, voidReason = shouldAutoVoid()
                local targetValid = false
                local status = "no target"
                if lastKnownTargetName then
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr.Name == lastKnownTargetName then
                            targetValid = true
                            if targetPlayer ~= plr then
                                targetPlayer = plr
                            end
                            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                                status = getPlayerStatus(plr)
                            end
                            break
                        end
                    end
                end
                if not shouldStillVoid and targetValid and status == "alive" then
                    voidActive = false
                    autoVoidActive = false
                    notify("void conditions ended", "void", 5)
                    if orbitEnabled then
                        teleporting = false
                        task.wait(0.1)
                        startOrbit()
                    end
                else
                    pcall(function()
                        humanoidRootPart.Position = Vector3.new(
                            math.random(-999999, 999999),
                            math.random(0, 999999),
                            math.random(-999999, 999999)
                        )
                    end)
                end
            else
                if not manualVoidEnabled then
                    voidActive = false
                    returnToVoidStartPosition()
                else
                    pcall(function()
                        humanoidRootPart.Position = Vector3.new(
                            math.random(-999999, 999999),
                            math.random(0, 999999),
                            math.random(-999999, 999999)
                        )
                    end)
                end
            end
            task.wait(0.01)
        end
    end)
end

function startOrbit()
    if not player.Character then
        local timeout = 0
        while not player.Character and timeout < 100 do
            task.wait(0.1)
            timeout = timeout + 1
        end
    end
    if not targetPlayer then
        notify("no target selected", "orbit", 5)
        orbitEnabled = false
        if orbitToggle then orbitToggle:SetValue(false) end
        return
    end
    local targetStillExists = false
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name == targetPlayer.Name then
            targetStillExists = true
            targetPlayer = plr
            break
        end
    end
    if not targetStillExists then
        notify("target left the game", "orbit", 5)
        stopOrbitAndReturn()
        return
    end
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") and orbitStartPosition == nil then
        orbitStartPosition = character.HumanoidRootPart.Position
    end
    teleporting = true
    orbitActive = true
    knockedVoidDone = false
    deadVoidActive = false
    lastKnownTarget = targetPlayer
    lastKnownTargetName = targetPlayer.Name
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        teleporting = false
        return
    end
    local humanoidRootPart = character.HumanoidRootPart
    notify("orbit started", "orbit", 5)
    task.spawn(function()
        while teleporting and orbitEnabled and orbitActive do
            if not player.Character then
                local timeout = 0
                while not player.Character and timeout < 200 do
                    task.wait(0.1)
                    timeout = timeout + 1
                end
                if player.Character then
                    humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
                    if not humanoidRootPart then
                        break
                    end
                else
                    break
                end
            end
            local targetExists = false
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Name == lastKnownTargetName then
                    targetExists = true
                    if targetPlayer ~= plr then
                        targetPlayer = plr
                    end
                    break
                end
            end
            if not targetExists then
                stopOrbitAndReturn("target left - returning")
                break
            end
            if not targetPlayer then
                stopOrbitAndReturn("target lost - returning")
                break
            end
            local status = "no char"
            if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                status = getPlayerStatus(targetPlayer)
            end
            local voidReason
            autoVoidActive, voidReason = shouldAutoVoid()
            if autoVoidActive then
                teleporting = false
                orbitActive = false
                notify(voidReason, "void", 5)
                task.spawn(function()
                    startVoid(true)
                end)
                break
            end
            if autoStompEnabled then
                if status == "ko" then
                    if not knockedVoidDone then
                        knockedVoidActive = true
                        local startTime = tick()
                        while tick() - startTime < 0.5 and knockedVoidActive do
                            pcall(function()
                                humanoidRootPart.Position = Vector3.new(
                                    math.random(-999999, 999999),
                                    math.random(0, 999999),
                                    math.random(-999999, 999999)
                                )
                            end)
                            task.wait(0.01)
                        end
                        knockedVoidActive = false
                        knockedVoidDone = true
                    end
                    if knockedVoidDone and not deadVoidActive then
                        local targetPos = getTorsoPosition(targetPlayer)
                        if targetPos and humanoidRootPart then
                            performStomp(targetPos)
                            stompActive = true
                            stompEndTime = tick() + 0.05
                            while stompActive and tick() < stompEndTime do
                                if not player.Character then break end
                                if targetPlayer and targetPlayer.Character then
                                    if getPlayerStatus(targetPlayer) == "dead" then
                                        stompActive = false
                                        deadVoidActive = true
                                        teleporting = false
                                        orbitActive = false
                                        notify("dead - void activated", "void", 5)
                                        task.spawn(function()
                                            startVoid(true)
                                        end)
                                        break
                                    end
                                end
                                task.wait(0.01)
                            end
                            stompActive = false
                        end
                    end
                elseif status == "dead" and not deadVoidActive then
                    deadVoidActive = true
                    teleporting = false
                    orbitActive = false
                    notify("target dead - void activated", "void", 5)
                    task.spawn(function()
                        startVoid(true)
                    end)
                    break
                else
                    knockedVoidDone = false
                end
            end
            if status == "alive" and not stompActive then
                if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and humanoidRootPart then
                    local targetHRP = targetPlayer.Character.HumanoidRootPart
                    local targetPos = targetHRP.Position
                    lastKnownTargetPosition = targetPos
                    lastKnownTarget = targetPlayer
                    lastKnownTargetName = targetPlayer.Name
                    local newPos = getRandomOrbitPoint(targetPos, orbitRadius)
                    pcall(function()
                        humanoidRootPart.Position = newPos
                    end)
                end
            end
            if orbitSpeed <= 0 then
                task.wait()
            else
                task.wait(orbitSpeed / 100)
            end
        end
        teleporting = false
        orbitActive = false
    end)
end

local orbitToggle, orbitSpeedSlider, orbitRadiusSlider, stompToggle, voidToggle, antiStompToggle, healthSlider, healthToggle, kickOnJoinToggle
local orbitKeybind, stompKeybind, voidKeybind
local playerInput

local controlsSection = Window:CreateSection("Controls", "Main")

orbitSpeedSlider = controlsSection:AddSlider("Orbit Speed", {
    Min = 0, 
    Max = 100, 
    Default = 0, 
    Callback = function(v)
        orbitSpeed = v
    end
})

orbitRadiusSlider = controlsSection:AddSlider("Orbit Radius", {
    Min = 1, 
    Max = 30, 
    Default = 15, 
    Callback = function(v)
        orbitRadius = v
    end
})

healthToggle = controlsSection:AddToggle("Health Save", true, function(state)
    healthSaveEnabled = state
end)

healthSlider = controlsSection:AddSlider("Health Threshold", {
    Min = 1,
    Max = 99,
    Default = 30,
    Callback = function(v)
        healthThreshold = v
    end
})

local targetSection = Window:CreateSection("Target Selection", "Main")

dropdown = targetSection:AddDropdown("Select Player", playerNames, "", function(selected)
    if selected and selected ~= "" then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name == selected then
                targetPlayer = plr
                lastKnownTarget = targetPlayer
                lastKnownTargetName = targetPlayer and targetPlayer.Name
                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    lastKnownTargetPosition = targetPlayer.Character.HumanoidRootPart.Position
                end
                if orbitEnabled then
                    teleporting = false
                    orbitActive = false
                    autoVoidActive = false
                    task.wait(0.1)
                    startOrbit()
                end
                break
            end
        end
    end
end)

playerInput = targetSection:AddTextBox("Search Player", "", function(text)
    if text and text ~= "" then
        local found = false
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and string.find(plr.Name:lower(), text:lower()) then
                targetPlayer = plr
                lastKnownTarget = targetPlayer
                lastKnownTargetName = targetPlayer and targetPlayer.Name
                dropdown:SetValue(plr.Name)
                found = true
                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    lastKnownTargetPosition = targetPlayer.Character.HumanoidRootPart.Position
                end
                if orbitEnabled then
                    teleporting = false
                    orbitActive = false
                    autoVoidActive = false
                    task.wait(0.1)
                    startOrbit()
                end
                break
            end
        end
        if not found then
            notify("No player found with that name", "Search", 3)
        end
    end
end)

local togglesSection = Window:CreateSection("Toggles", "Main")

orbitToggle = togglesSection:AddToggle("Orbit", false, function(state)
    orbitEnabled = state
    if state then
        autoVoidActive = false
        knockedVoidDone = false
        deadVoidActive = false
        startOrbit()
    else
        teleporting = false
        orbitActive = false
        autoVoidActive = false
        returnToStartPosition()
        orbitStartPosition = nil
    end
end)

stompToggle = togglesSection:AddToggle("Auto Stomp", false, function(state)
    autoStompEnabled = state
    notify(state and "stomp on" or "stomp off", "stomp", 5)
end)

voidToggle = togglesSection:AddToggle("Manual Void", false, function(state)
    manualVoidEnabled = state
    if state then
        if orbitEnabled then
            orbitEnabled = false
            orbitActive = false
            orbitToggle:SetValue(false)
            teleporting = false
        end
        notify("manual void", "void", 5)
        startVoid(false)
    else
        returnToVoidStartPosition()
        notify("returned to start", "void", 5)
    end
end)

antiStompToggle = togglesSection:AddToggle("Anti Stomp", false, function(state)
    antiStompEnabled = state
    if not state then
        antiStompActive = false
    end
    notify(state and "anti stomp on" or "anti stomp off", "anti stomp", 5)
end)

kickOnJoinToggle = togglesSection:AddToggle("Kick if Staff", false, function(state)
    groupMonitor.kickOnJoin = state
end)

local keybindsSection = Window:CreateSection("Keybinds", "Main")

local function createToggleKeybind(name, defaultKey, toggleRef, toggleFunction)
    local isActive = false
    local keybindButton = keybindsSection:AddKeybind(name, defaultKey, function()
        isActive = not isActive
        toggleFunction(isActive)
    end, true)
    return keybindButton
end

orbitKeybind = createToggleKeybind("Orbit Key", "X", orbitToggle, function(state)
    if state then
        if not orbitEnabled then
            if targetPlayer then
                orbitEnabled = true
                orbitToggle:SetValue(true)
                autoVoidActive = false
                knockedVoidDone = false
                deadVoidActive = false
                startOrbit()
            else
                orbitEnabled = false
                orbitToggle:SetValue(false)
            end
        end
    else
        if orbitEnabled then
            orbitEnabled = false
            orbitToggle:SetValue(false)
            teleporting = false
            orbitActive = false
            autoVoidActive = false
            returnToStartPosition()
            orbitStartPosition = nil
        end
    end
end)

stompKeybind = createToggleKeybind("Stomp Key", "V", stompToggle, function(state)
    if state then
        if not autoStompEnabled then
            autoStompEnabled = true
            stompToggle:SetValue(true)
        end
    else
        if autoStompEnabled then
            autoStompEnabled = false
            stompToggle:SetValue(false)
        end
    end
end)

voidKeybind = createToggleKeybind("Void Key", "C", voidToggle, function(state)
    if state then
        if not manualVoidEnabled then
            manualVoidEnabled = true
            voidToggle:SetValue(true)
            if orbitEnabled then
                orbitEnabled = false
                orbitActive = false
                orbitToggle:SetValue(false)
                teleporting = false
            end
            startVoid(false)
        end
    else
        if manualVoidEnabled then
            manualVoidEnabled = false
            voidToggle:SetValue(false)
            returnToVoidStartPosition()
        end
    end
end)

Window:Finalize()
print("anti staff loooaded")
notify("ANTI STAFF YAY!!!", "debrainers made this!!", 12)
groupMonitor:initialize()

while true do
    wait(60)
    if groupMonitor.loadingComplete then
        local players = Players:GetPlayers()
        local currentUsernames = {}
        for _, plr in ipairs(players) do
            currentUsernames[plr.Name] = true
        end
        for username, isActive in pairs(groupMonitor.activeUsers) do
            if not currentUsernames[username] then
                groupMonitor.activeUsers[username] = nil
            end
        end
    end
end
