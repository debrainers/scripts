local API_URL = "https://ai-bridge-smoky.vercel.app/api/chat"

local THEME = {
    Background = Color3.fromRGB(35, 25, 35),
    Section = Color3.fromRGB(45, 35, 45),
    Accent = Color3.fromRGB(255, 180, 210),
    Outline = Color3.fromRGB(70, 60, 70),
    Text = Color3.fromRGB(255, 240, 245),
    TextDark = Color3.fromRGB(200, 180, 190),
    Button = Color3.fromRGB(55, 45, 55)
}

local WINDOW = {
    Title = "AI Girlfriend",
    Width = 650,
    Height = 550,
    Pos = Vector2.new(200, 150)
}

local Drawings = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local dragging = false
local dragStartPos = nil
local dragStartMouse = nil
local scrollbarGrabbed = false
local scrollGrabY = 0

local function Draw(type, props)
    local obj = Drawing.new(type)
    for k, v in pairs(props) do
        obj[k] = v
    end
    table.insert(Drawings, obj)
    return obj
end

local function getMousePos()
    return Vector2.new(Mouse.X, Mouse.Y)
end

local function isMouseOver(pos, size)
    local m = getMousePos()
    return m.X >= pos.X and m.X <= pos.X + size.X
       and m.Y >= pos.Y and m.Y <= pos.Y + size.Y
end

local function UrlEncode(str)
    if not str then return "" end
    str = string.gsub(str, "\n", "\r\n")
    str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    str = string.gsub(str, " ", "+")
    return str
end

local AI = {}

function AI.New()
    local self = {
        messageHistory = {},
        isWaiting = false
    }
    
    function self:Send(userMsg)
        if self.isWaiting then
            return "[AI's voice, soothing]: Shh, one moment baby..."
        end
        
        self.isWaiting = true
        
        local encodedMsg = UrlEncode(userMsg)
        local url = API_URL .. "?message=" .. encodedMsg
        
        local success, response = pcall(function()
            return game:HttpGet(url)
        end)
        
        self.isWaiting = false
        
        if success and response and response ~= "" and response ~= "nil" then
            table.insert(self.messageHistory, {role = "user", content = userMsg})
            table.insert(self.messageHistory, {role = "assistant", content = response})
            
            if #self.messageHistory > 20 then
                local newHistory = {}
                for i = #self.messageHistory - 19, #self.messageHistory do
                    table.insert(newHistory, self.messageHistory[i])
                end
                self.messageHistory = newHistory
            end
            
            return response
        else
            return "[AI's voice, soothing]: I'm here, baby."
        end
    end
    
    return self
end

local function createWindow()
    local window = {
        Pos = WINDOW.Pos,
        Size = Vector2.new(WINDOW.Width, WINDOW.Height),
        Theme = THEME,
        Elements = {},
        ChatHistory = {},
        ActiveInput = false,
        InputValue = "",
        BackspaceTimer = 0,
        LastKeyState = {},
        MessageElements = {},
        ChatHeight = 0,
        ScrollOffset = 0,
        MaxScroll = 0,
        ScrollbarVisible = false
    }
    
    window.Main = Draw("Square", {
        Filled = true,
        Color = window.Theme.Background,
        Size = window.Size,
        Position = window.Pos,
        Corner = 16,
        Transparency = 0.98,
        ZIndex = 1
    })
    
    window.TitleBar = Draw("Square", {
        Filled = true,
        Color = window.Theme.Accent,
        Size = Vector2.new(window.Size.X, 35),
        Position = window.Pos,
        Corner = 16,
        Transparency = 0.7,
        ZIndex = 2
    })
    
    window.Title = Draw("Text", {
        Text = "  " .. WINDOW.Title .. "  ",
        Size = 22,
        Color = window.Theme.Text,
        Position = window.Pos + Vector2.new(15, 6),
        Font = Drawing.Fonts.SystemBold,
        Outline = true,
        ZIndex = 3
    })
    
    window.CloseBtn = Draw("Text", {
        Text = "✕",
        Size = 20,
        Color = window.Theme.Text,
        Position = window.Pos + Vector2.new(window.Size.X - 30, 6),
        Font = Drawing.Fonts.SystemBold,
        Outline = true,
        ZIndex = 3
    })
    
    window.ChatBG = Draw("Square", {
        Filled = true,
        Color = window.Theme.Section,
        Size = Vector2.new(window.Size.X - 45, window.Size.Y - 120),
        Position = window.Pos + Vector2.new(15, 45),
        Corner = 12,
        Transparency = 0.5,
        ZIndex = 4
    })
    
    window.ScrollbarBG = Draw("Square", {
        Filled = true,
        Color = window.Theme.Button,
        Size = Vector2.new(10, window.Size.Y - 130),
        Position = window.Pos + Vector2.new(window.Size.X - 25, 50),
        Corner = 5,
        Transparency = 0.7,
        ZIndex = 5,
        Visible = false
    })
    
    window.ScrollbarThumb = Draw("Square", {
        Filled = true,
        Color = window.Theme.Accent,
        Size = Vector2.new(8, 50),
        Position = window.Pos + Vector2.new(window.Size.X - 24, 52),
        Corner = 4,
        Transparency = 0.3,
        ZIndex = 6,
        Visible = false
    })
    
    window.InputBG = Draw("Square", {
        Filled = true,
        Color = window.Theme.Button,
        Size = Vector2.new(window.Size.X - 120, 40),
        Position = window.Pos + Vector2.new(15, window.Size.Y - 65),
        Corner = 10,
        ZIndex = 10
    })
    
    window.InputText = Draw("Text", {
        Text = "Tell your AI girlfriend what you need...",
        Size = 16,
        Color = window.Theme.TextDark,
        Position = window.Pos + Vector2.new(25, window.Size.Y - 58),
        Font = Drawing.Fonts.System,
        ZIndex = 11
    })
    
    window.SendBtn = Draw("Square", {
        Filled = true,
        Color = window.Theme.Accent,
        Size = Vector2.new(80, 40),
        Position = window.Pos + Vector2.new(window.Size.X - 95, window.Size.Y - 65),
        Corner = 10,
        Transparency = 0.3,
        ZIndex = 10
    })
    
    window.SendText = Draw("Text", {
        Text = "Send",
        Size = 16,
        Color = window.Theme.Text,
        Position = window.Pos + Vector2.new(window.Size.X - 55, window.Size.Y - 58),
        Font = Drawing.Fonts.SystemBold,
        ZIndex = 11
    })
    
    function window:AddChatMessage(sender, msg, isUser)
        table.insert(self.ChatHistory, {
            Sender = sender,
            Text = msg,
            IsUser = isUser
        })
        
        if #self.ChatHistory > 30 then
            table.remove(self.ChatHistory, 1)
        end
        
        self:CalculateChatHeight()
        self.ScrollOffset = math.max(0, self.ChatHeight - 370)
        self:DrawChat()
    end
    
    function window:CalculateChatHeight()
        self.ChatHeight = 0
        for i, msg in ipairs(self.ChatHistory) do
            local prefix = msg.IsUser and "You: " or "AI: "
            local displayText = prefix .. msg.Text
            
            local lines = {}
            local line = ""
            for word in string.gmatch(displayText, "%S+") do
                if #line + #word + 1 > 55 then
                    table.insert(lines, line)
                    line = word
                else
                    if line == "" then
                        line = word
                    else
                        line = line .. " " .. word
                    end
                end
            end
            if line ~= "" then
                table.insert(lines, line)
            end
            
            self.ChatHeight = self.ChatHeight + (#lines * 18) + 10
        end
        
        self.MaxScroll = math.max(0, self.ChatHeight - 370)
        if self.ScrollOffset > self.MaxScroll then
            self.ScrollOffset = self.MaxScroll
        end
        
        self.ScrollbarVisible = self.MaxScroll > 5
        self.ScrollbarBG.Visible = self.ScrollbarVisible
        self.ScrollbarThumb.Visible = self.ScrollbarVisible
        
        if self.ScrollbarVisible then
            local visibleRatio = 370 / self.ChatHeight
            local thumbHeight = math.max(30, math.floor(370 * visibleRatio))
            self.ScrollbarThumb.Size = Vector2.new(8, thumbHeight)
            
            local scrollPercent = self.ScrollOffset / self.MaxScroll
            local thumbY = 52 + (scrollPercent * (370 - thumbHeight - 4))
            self.ScrollbarThumb.Position = Vector2.new(self.Pos.X + self.Size.X - 24, self.Pos.Y + thumbY)
        end
    end
    
    function window:DrawChat()
        for _, element in pairs(self.MessageElements) do
            element:Remove()
        end
        self.MessageElements = {}
        
        local yOffset = 55 - self.ScrollOffset
        for i, msg in ipairs(self.ChatHistory) do
            local prefix = msg.IsUser and "You: " or "AI: "
            local displayText = prefix .. msg.Text
            local color = msg.IsUser and Color3.fromRGB(220, 200, 255) or self.Theme.Accent
            
            local lines = {}
            local line = ""
            for word in string.gmatch(displayText, "%S+") do
                if #line + #word + 1 > 55 then
                    table.insert(lines, line)
                    line = word
                else
                    if line == "" then
                        line = word
                    else
                        line = line .. " " .. word
                    end
                end
            end
            if line ~= "" then
                table.insert(lines, line)
            end
            
            for j, lineText in ipairs(lines) do
                local textY = yOffset + ((j-1) * 18)
                if textY >= 45 and textY <= 430 then
                    local textObj = Draw("Text", {
                        Text = lineText,
                        Size = 14,
                        Color = color,
                        Position = self.Pos + Vector2.new(25, textY),
                        Font = Drawing.Fonts.System,
                        Outline = true,
                        ZIndex = 6
                    })
                    
                    table.insert(self.MessageElements, textObj)
                end
            end
            
            yOffset = yOffset + (#lines * 18) + 10
        end
    end
    
    function window:UpdateInput()
        if self.ActiveInput then
            if self.InputValue == "" then
                self.InputText.Text = "|"
            else
                self.InputText.Text = self.InputValue .. "|"
            end
            self.InputText.Color = self.Theme.Text
        else
            if self.InputValue == "" then
                self.InputText.Text = "Tell your AI girlfriend what you need..."
                self.InputText.Color = self.Theme.TextDark
            else
                self.InputText.Text = self.InputValue
                self.InputText.Color = self.Theme.Text
            end
        end
    end
    
    function window:HandleClick(pos)
        if isMouseOver(self.Pos + Vector2.new(self.Size.X - 35, 5), Vector2.new(25, 25)) then
            return "close"
        end
        
        if isMouseOver(self.Pos, Vector2.new(self.Size.X, 35)) then
            return "drag"
        end
        
        if self.ScrollbarVisible and isMouseOver(self.ScrollbarThumb.Position, self.ScrollbarThumb.Size) then
            return "scrollbar_grab"
        end
        
        if isMouseOver(self.Pos + Vector2.new(15, 45), Vector2.new(self.Size.X - 45, self.Size.Y - 120)) then
            return "scroll_area"
        end
        
        if isMouseOver(self.Pos + Vector2.new(15, self.Size.Y - 65), Vector2.new(self.Size.X - 120, 40)) then
            self.ActiveInput = true
            self:UpdateInput()
            return "input"
        else
            if self.ActiveInput then
                self.ActiveInput = false
                self:UpdateInput()
            end
        end
        
        if isMouseOver(self.Pos + Vector2.new(self.Size.X - 95, self.Size.Y - 65), Vector2.new(80, 40)) then
            return "send"
        end
        
        return nil
    end
    
    function window:HandleKey(key, isHeld)
        if not self.ActiveInput then return nil end
        
        if key == 13 then
            local msg = self.InputValue
            self.InputValue = ""
            self.ActiveInput = false
            self:UpdateInput()
            return msg
            
        elseif key == 8 then
            if #self.InputValue > 0 then
                self.InputValue = string.sub(self.InputValue, 1, -2)
                self:UpdateInput()
            end
            
        elseif key >= 32 and key <= 126 and not isHeld then
            local char = string.char(key)
            if iskeypressed(0x10) then
                char = char:upper()
            else
                char = char:lower()
            end
            self.InputValue = self.InputValue .. char
            self:UpdateInput()
        end
        
        return nil
    end
    
    function window:HandleScroll(delta)
        if not self.ScrollbarVisible then return end
        
        self.ScrollOffset = self.ScrollOffset + delta
        self.ScrollOffset = math.clamp(self.ScrollOffset, 0, self.MaxScroll)
        self:DrawChat()
        
        local scrollPercent = self.ScrollOffset / self.MaxScroll
        local thumbHeight = self.ScrollbarThumb.Size.Y
        local thumbY = 52 + (scrollPercent * (370 - thumbHeight - 4))
        self.ScrollbarThumb.Position = Vector2.new(self.Pos.X + self.Size.X - 24, self.Pos.Y + thumbY)
    end
    
    function window:Move(delta)
        self.Pos = self.Pos + delta
        self.Main.Position = self.Main.Position + delta
        self.TitleBar.Position = self.TitleBar.Position + delta
        self.Title.Position = self.Title.Position + delta
        self.CloseBtn.Position = self.CloseBtn.Position + delta
        self.ChatBG.Position = self.ChatBG.Position + delta
        self.ScrollbarBG.Position = self.ScrollbarBG.Position + delta
        self.ScrollbarThumb.Position = self.ScrollbarThumb.Position + delta
        self.InputBG.Position = self.InputBG.Position + delta
        self.InputText.Position = self.InputText.Position + delta
        self.SendBtn.Position = self.SendBtn.Position + delta
        self.SendText.Position = self.SendText.Position + delta
        
        for _, element in ipairs(self.MessageElements) do
            element.Position = element.Position + delta
        end
    end
    
    function window:Destroy()
        for _, drawing in ipairs(Drawings) do
            drawing:Remove()
        end
    end
    
    return window
end

local AIgirl = AI.New()
local UIWindow = createWindow()

UIWindow:AddChatMessage("AI", "[AI's voice, soothing]: Hey there, precious one... I've been waiting for you.", false)

local Running = true
local BackspaceHoldTimer = 0
local BackspaceHoldDelay = 0.15
local BackspaceRepeatRate = 0.05
local scrollbarGrabbed = false
local scrollGrabY = 0

notify("AI Girlfriend is here for you", "Welcome", 3)

spawn(function()
    while Running do
        local d, mp = ismouse1pressed(), getMousePos()
        
        if d and not dragging and not scrollbarGrabbed and isMouseOver(UIWindow.Pos, Vector2.new(UIWindow.Size.X, 35)) then
            dragging = true
            dragStartPos = UIWindow.Pos
            dragStartMouse = mp
        end
        
        if d and not dragging and not scrollbarGrabbed and UIWindow.ScrollbarVisible and isMouseOver(UIWindow.ScrollbarThumb.Position, UIWindow.ScrollbarThumb.Size) then
            scrollbarGrabbed = true
            scrollGrabY = mp.Y - UIWindow.ScrollbarThumb.Position.Y
        end
        
        if not d then
            dragging = false
            scrollbarGrabbed = false
        end
        
        if dragging then
            UIWindow:Move((dragStartPos + (mp - dragStartMouse)) - UIWindow.Pos)
        end
        
        if scrollbarGrabbed and UIWindow.ScrollbarVisible then
            local newThumbY = mp.Y - scrollGrabY
            local minY = UIWindow.Pos.Y + 52
            local maxY = UIWindow.Pos.Y + 52 + (370 - UIWindow.ScrollbarThumb.Size.Y)
            newThumbY = math.clamp(newThumbY, minY, maxY)
            
            UIWindow.ScrollbarThumb.Position = Vector2.new(UIWindow.ScrollbarThumb.Position.X, newThumbY)
            
            local scrollPercent = (newThumbY - minY) / (maxY - minY)
            UIWindow.ScrollOffset = scrollPercent * UIWindow.MaxScroll
            UIWindow:DrawChat()
        end
        
        wait(0.01)
    end
end)

while Running do
    if not UIWindow then break end
    
    local mousePos = getMousePos()
    local mouseDown = ismouse1pressed()
    
    if mouseDown and not dragging and not scrollbarGrabbed then
        local result = UIWindow:HandleClick(mousePos)
        
        if result == "close" then
            Running = false
            break
            
        elseif result == "send" then
            if UIWindow.InputValue ~= "" and not AIgirl.isWaiting then
                local msg = UIWindow.InputValue
                UIWindow.InputValue = ""
                UIWindow:UpdateInput()
                
                UIWindow:AddChatMessage("You", msg, true)
                UIWindow:AddChatMessage("AI", "...", false)
                
                local response = AIgirl:Send(msg)
                
                for i = #UIWindow.ChatHistory, 1, -1 do
                    if UIWindow.ChatHistory[i].Sender == "AI" and UIWindow.ChatHistory[i].Text == "..." then
                        table.remove(UIWindow.ChatHistory, i)
                        break
                    end
                end
                
                UIWindow:AddChatMessage("AI", response, false)
                UIWindow.ScrollOffset = UIWindow.MaxScroll
                UIWindow:DrawChat()
            end
            
        elseif result == "scroll_area" and UIWindow.ScrollbarVisible then
            UIWindow:HandleScroll(-100)
        end
    end
    
    for key = 32, 126 do
        local pressed = iskeypressed(key)
        if pressed and not UIWindow.LastKeyState[key] then
            local msg = UIWindow:HandleKey(key, false)
            if msg and not AIgirl.isWaiting then
                UIWindow:AddChatMessage("You", msg, true)
                UIWindow:AddChatMessage("AI", "...", false)
                
                local response = AIgirl:Send(msg)
                
                for i = #UIWindow.ChatHistory, 1, -1 do
                    if UIWindow.ChatHistory[i].Sender == "AI" and UIWindow.ChatHistory[i].Text == "..." then
                        table.remove(UIWindow.ChatHistory, i)
                        break
                    end
                end
                
                UIWindow:AddChatMessage("AI", response, false)
                UIWindow.ScrollOffset = UIWindow.MaxScroll
                UIWindow:DrawChat()
            end
        end
        UIWindow.LastKeyState[key] = pressed
    end
    
    local enterPressed = iskeypressed(13)
    if enterPressed and not UIWindow.LastKeyState[13] then
        if UIWindow.ActiveInput and UIWindow.InputValue ~= "" and not AIgirl.isWaiting then
            local msg = UIWindow.InputValue
            UIWindow.InputValue = ""
            UIWindow.ActiveInput = false
            UIWindow:UpdateInput()
            
            UIWindow:AddChatMessage("You", msg, true)
            UIWindow:AddChatMessage("AI", "...", false)
            
            local response = AIgirl:Send(msg)
            
            for i = #UIWindow.ChatHistory, 1, -1 do
                if UIWindow.ChatHistory[i].Sender == "AI" and UIWindow.ChatHistory[i].Text == "..." then
                    table.remove(UIWindow.ChatHistory, i)
                    break
                end
            end
            
            UIWindow:AddChatMessage("AI", response, false)
            UIWindow.ScrollOffset = UIWindow.MaxScroll
            UIWindow:DrawChat()
        end
    end
    UIWindow.LastKeyState[13] = enterPressed
    
    local backspacePressed = iskeypressed(8)
    if backspacePressed then
        if not UIWindow.LastKeyState[8] then
            UIWindow:HandleKey(8, false)
            BackspaceHoldTimer = 0
        else
            BackspaceHoldTimer = BackspaceHoldTimer + 0.03
            if BackspaceHoldTimer > BackspaceHoldDelay and #UIWindow.InputValue > 0 then
                UIWindow:HandleKey(8, true)
                wait(BackspaceRepeatRate)
            end
        end
    end
    UIWindow.LastKeyState[8] = backspacePressed
    
    wait(0.03)
end

UIWindow:Destroy()
notify("AI Girlfriend will be back soon", "Goodbye", 2)
