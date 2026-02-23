loadstring(game:HttpGet("https://arcanecheats.xyz/api/matcha/uilib"))()
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

local OFFSET = 0x18C

local playerNames = {}
local selectedPlayer = nil
local dropdown = nil

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
    task.wait(0.05)
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

function teleportToTargetTorso()
    if not targetPlayer or not targetPlayer.Character then return end
    local targetPos = getTorsoPosition(targetPlayer)
    if not targetPos then return end
    
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = character.HumanoidRootPart
    hrp.Position = Vector3.new(targetPos.X, targetPos.Y + 2.5, targetPos.Z)
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
                    local targetPos = getTorsoPosition(targetPlayer)
                    if targetPos and humanoidRootPart then
                        pcall(function()
                            humanoidRootPart.Position = Vector3.new(targetPos.X, targetPos.Y + 2.5, targetPos.Z)
                        end)
                        pressEKey()
                        stompActive = true
                        stompEndTime = tick() + 0.05
                        
                        while stompActive and tick() < stompEndTime do
                            if not player.Character then break end
                            if targetPlayer and targetPlayer.Character then
                                if getPlayerStatus(targetPlayer) == "dead" then
                                    stompActive = false
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
                    
                elseif status == "dead" then
                    teleporting = false
                    orbitActive = false
                    notify("target dead - void activated", "void", 5)
                    task.spawn(function()
                        startVoid(true)
                    end)
                    break
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

local orbitToggle, orbitSpeedSlider, orbitRadiusSlider, stompToggle, voidToggle, antiStompToggle, healthSlider, healthToggle
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

notify("WOW NEW UI! YAYYY!", "debrainers made this!!", 12)

Window:Finalize()
