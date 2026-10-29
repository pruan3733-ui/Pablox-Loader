--====================================================
-- PABLOX KEY SYSTEM V10 — R2 PRIVADO
-- KEY ONLINE + CONTROLE V5
-- DELTA / XENO | PC + MOBILE
--====================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local CONTROL_URL = "https://pabloxhub-online-v5.pruan3733.workers.dev"
local API = CONTROL_URL .. "/api/public/validate"
local HUB_ENDPOINT = CONTROL_URL .. "/api/public/load-hub"

local IMAGE = "rbxassetid://129346114110422"
local KEY_FILE = "PABLOX_KEY_V5_" .. tostring(Player.UserId) .. ".txt"

-- Evita criar dois monitores ao executar o loader novamente.
if _G.PABLOX_V9_CONTROL then
    _G.PABLOX_V9_CONTROL.running = false
end
local Monitor = {running = false}
_G.PABLOX_V9_CONTROL = Monitor

for _, name in ipairs({"PABLOX_KEY_SYSTEM", "PABLOX_KEY_NOTIFICATION"}) do
    local old = PlayerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

local function SaveKey(key)
    if type(writefile) ~= "function" then return false end
    return pcall(function() writefile(KEY_FILE, key) end)
end

local function LoadKey()
    if type(readfile) ~= "function" then return nil end
    local ok, result = pcall(function() return readfile(KEY_FILE) end)
    if ok and type(result) == "string" then
        result = result:match("^%s*(.-)%s*$")
        if result ~= "" then return result end
    end
    return nil
end

local function DeleteKey()
    if type(delfile) == "function" then
        pcall(function() delfile(KEY_FILE) end)
    elseif type(writefile) == "function" then
        pcall(function() writefile(KEY_FILE, "") end)
    end
end

local function GetRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    return nil
end

local function HttpJson(url, method, body)
    local requestFn = GetRequest()
    if not requestFn then return nil, "HTTP INDISPONÍVEL" end
    local options = {
        Url = url,
        Method = method or "GET",
        Headers = {["Content-Type"] = "application/json"}
    }
    if body ~= nil then
        options.Body = HttpService:JSONEncode(body)
    end
    local ok, response = pcall(function() return requestFn(options) end)
    if not ok or type(response) ~= "table" then
        return nil, "ERRO DE CONEXÃO"
    end
    local statusCode = tonumber(response.StatusCode or response.Status)
    if not statusCode or statusCode >= 500 then
        return nil, "SERVIDOR INDISPONÍVEL"
    end
    local decoded, data = pcall(function()
        return HttpService:JSONDecode(response.Body or "")
    end)
    if not decoded or type(data) ~= "table" then
        return nil, "RESPOSTA INVÁLIDA"
    end
    return data, nil, statusCode
end

local function ValidateKey(key)
    local data, err, code = HttpJson(API, "POST", {
        key = key, userId = tostring(Player.UserId)
    })
    if not data then return false, err, "network" end
    if data.maintenance then
        return false, tostring(data.message or "O Hub está atualizando"), "maintenance"
    end
    if code == 200 and data.ok == true then
        return true, "KEY VÁLIDA", "valid"
    end
    return false, tostring(data.error or data.message or "KEY INVÁLIDA"),
        (code == 403 and "invalid" or "network")
end

local function CheckControl()
    return HttpJson(CONTROL_URL .. "/api/public/status", "GET")
end

local function SendHeartbeat()
    return HttpJson(CONTROL_URL .. "/api/public/heartbeat", "POST", {
        userId = tostring(Player.UserId),
        username = Player.Name,
        displayName = Player.DisplayName
    })
end

local function ControlMessage(data)
    if data.banned then return "ACESSO BLOQUEADO" end
    if data.maintenance then
        return tostring(data.message or "O Hub está atualizando")
    end
    return tostring(data.message or "SERVIDOR INDISPONÍVEL")
end

local function LoadHub(key)
    local requestFn = GetRequest()
    if not requestFn then return false, "HTTP INDISPONÍVEL" end
    local ok, response = pcall(function()
        return requestFn({
            Url = HUB_ENDPOINT,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                key = key,
                userId = tostring(Player.UserId)
            })
        })
    end)
    if not ok or type(response) ~= "table" then
        return false, "ERRO DE CONEXÃO COM O R2"
    end
    local statusCode = tonumber(response.StatusCode or response.Status) or 0
    local source = response.Body
    if statusCode ~= 200 then
        local parsed, info = pcall(function() return HttpService:JSONDecode(source or "") end)
        local reason = parsed and type(info) == "table" and (info.message or info.error)
        return false, tostring(reason or ("ERRO HTTP " .. statusCode))
    end
    if type(source) ~= "string" or #source < 100 then
        return false, "HUB VAZIA OU RESPOSTA INVÁLIDA"
    end
    local fn, compileError = loadstring(source)
    if type(fn) ~= "function" then
        return false, tostring(compileError or "ERRO AO COMPILAR HUB")
    end
    local executed, executionError = pcall(fn)
    if not executed then
        warn("[PABLOX KEY SYSTEM]", executionError)
        return false, "ERRO AO INICIAR HUB"
    end
    return true
end

local function Corner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local function CreateGui(name)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 999
    gui.Parent = PlayerGui
    return gui
end

local function Notify(title, message, duration)
    duration = duration or 3
    local old = PlayerGui:FindFirstChild("PABLOX_KEY_NOTIFICATION")
    if old then old:Destroy() end

    local gui = CreateGui("PABLOX_KEY_NOTIFICATION")
    local frame = Instance.new("Frame")
    frame.Name = "Notification"
    frame.Size = UDim2.fromOffset(235, 62)
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, 245, 0, 55)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = gui
    Corner(frame, 10)

    local image = Instance.new("ImageLabel")
    image.Size = UDim2.fromScale(1, 1)
    image.BackgroundTransparency = 1
    image.Image = IMAGE
    image.ImageTransparency = 0.25
    image.ScaleType = Enum.ScaleType.Crop
    image.Parent = frame

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.4
    overlay.BorderSizePixel = 0
    overlay.Parent = frame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 24)
    titleLabel.Position = UDim2.fromOffset(10, 7)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = frame

    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -20, 0, 22)
    messageLabel.Position = UDim2.fromOffset(10, 30)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.Font = Enum.Font.GothamMedium
    messageLabel.TextSize = 11
    messageLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.Parent = frame

    local tweenIn = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Position = UDim2.new(1, -12, 0, 55)
    })
    tweenIn:Play()

    task.delay(duration, function()
        if not frame.Parent then return end
        local tweenOut = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Position = UDim2.new(1, 245, 0, 55)
        })
        tweenOut:Play()
        tweenOut.Completed:Wait()
        if gui.Parent then gui:Destroy() end
    end)
end

local function StopHub(reason)
    Monitor.running = false
    Notify("PABLOX HUB", reason, 8)
    local noticeGui = Instance.new("ScreenGui")
    noticeGui.Name = "PABLOX_MAINTENANCE_NOTICE"
    noticeGui.ResetOnSpawn = false
    noticeGui.DisplayOrder = 99999
    noticeGui.Parent = PlayerGui
    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(0.5, 0.5)
    label.Size = UDim2.new(0.85, 0, 0, 100)
    label.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.TextWrapped = true
    label.Text = reason
    label.Parent = noticeGui
    local radius = Instance.new("UICorner")
    radius.CornerRadius = UDim.new(0, 12)
    radius.Parent = label
    warn("[PABLOX HUB CONTROL]", reason)
    -- Para encerrar realmente a Hub V16, a própria Hub deve expor Cleanup:
    -- _G.PABLOX_HUB_CLEANUP = Cleanup
    if type(_G.PABLOX_HUB_CLEANUP) == "function" then
        pcall(_G.PABLOX_HUB_CLEANUP)
    end
end

local function StartControl()
    if Monitor.running then return end
    Monitor.running = true
    task.spawn(function()
        while Monitor.running do
            local data = SendHeartbeat()
            if data then
                if data.maintenance or data.banned or data.ok == false then
                    StopHub(ControlMessage(data))
                    break
                end
                if data.hubUrl and data.hubUrl ~= "" then
                    HubUrl = data.hubUrl
                end
            end
            task.wait(5)
        end
    end)
end

local Gui = CreateGui("PABLOX_KEY_SYSTEM")

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(320, 175)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = Gui
Corner(Main, 12)

local Background = Instance.new("ImageLabel")
Background.Size = UDim2.fromScale(1, 1)
Background.BackgroundTransparency = 1
Background.Image = IMAGE
Background.ScaleType = Enum.ScaleType.Crop
Background.Parent = Main

local Overlay = Instance.new("Frame")
Overlay.Size = UDim2.fromScale(1, 1)
Overlay.BackgroundColor3 = Color3.new(0, 0, 0)
Overlay.BackgroundTransparency = 0.78
Overlay.BorderSizePixel = 0
Overlay.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -55, 0, 30)
Title.Position = UDim2.fromOffset(12, 5)
Title.BackgroundTransparency = 1
Title.Text = "PABLOX KEY SYSTEM"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Active = true
Title.Parent = Main

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(30, 27)
Close.Position = UDim2.new(1, -39, 0, 5)
Close.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
Close.BorderSizePixel = 0
Close.Text = "−"
Close.TextColor3 = Color3.new(1, 1, 1)
Close.Font = Enum.Font.GothamBold
Close.TextSize = 20
Close.Parent = Main
Corner(Close, 8)

local Input = Instance.new("TextBox")
Input.Size = UDim2.new(1, -30, 0, 35)
Input.Position = UDim2.fromOffset(15, 43)
Input.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
Input.BackgroundTransparency = 0.12
Input.BorderSizePixel = 0
Input.PlaceholderText = "INSIRA SUA KEY"
Input.PlaceholderColor3 = Color3.fromRGB(190, 190, 190)
Input.Text = ""
Input.TextColor3 = Color3.new(1, 1, 1)
Input.Font = Enum.Font.GothamMedium
Input.TextSize = 13
Input.ClearTextOnFocus = false
Input.Parent = Main
Corner(Input, 8)

local Verify = Instance.new("TextButton")
Verify.Size = UDim2.new(1, -30, 0, 35)
Verify.Position = UDim2.fromOffset(15, 87)
Verify.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
Verify.BorderSizePixel = 0
Verify.Text = "VERIFICAR KEY"
Verify.TextColor3 = Color3.new(1, 1, 1)
Verify.Font = Enum.Font.GothamMedium
Verify.TextSize = 13
Verify.Parent = Main
Corner(Verify, 8)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -30, 0, 30)
Status.Position = UDim2.fromOffset(15, 130)
Status.BackgroundTransparency = 1
Status.Text = "AGUARDANDO KEY"
Status.TextColor3 = Color3.fromRGB(210, 210, 210)
Status.Font = Enum.Font.GothamMedium
Status.TextSize = 11
Status.TextWrapped = true
Status.Parent = Main

local Open = Instance.new("ImageButton")
Open.Size = UDim2.fromOffset(48, 48)
Open.AnchorPoint = Vector2.new(0.5, 0.5)
Open.Position = UDim2.new(0, 35, 0.5, 0)
Open.BackgroundTransparency = 1
Open.Image = IMAGE
Open.ScaleType = Enum.ScaleType.Crop
Open.Visible = false
Open.Active = true
Open.Parent = Gui
local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(1, 0)
openCorner.Parent = Open

local function MakeDraggable(object, handle)
    local dragging = false
    local dragStart, startPos, dragInput

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = object.Position
            dragInput = input
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            object.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

MakeDraggable(Main, Title)
local openMoved = false
local openStart

Open.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        openMoved = false
        openStart = input.Position
    end
end)

MakeDraggable(Open, Open)

Open.InputChanged:Connect(function(input)
    if openStart and (
        input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement
    ) then
        if (input.Position - openStart).Magnitude > 10 then
            openMoved = true
        end
    end
end)

Close.MouseButton1Click:Connect(function()
    Main.Visible = false
    Open.Visible = true
end)

Open.MouseButton1Click:Connect(function()
    if openMoved then
        openMoved = false
        return
    end
    Open.Visible = false
    Main.Visible = true
end)

local Busy = false

local function Login(key, automatic)
    if Busy then return end
    Busy = true

    if automatic then
        Main.Visible = false
        Open.Visible = false
    else
        Verify.Text = "VERIFICANDO..."
        Status.Text = "VALIDANDO KEY..."
    end

    local valid, message, resultType = ValidateKey(key)

    if valid then
        local control, controlError = CheckControl()
        if not control then
            Main.Visible = true
            Open.Visible = false
            Status.Text = string.upper(controlError or "SERVIDOR INDISPONÍVEL")
        elseif control.maintenance then
            Main.Visible = true
            Open.Visible = false
            Status.Text = ControlMessage(control)
        else
            local heartbeat, heartbeatError = SendHeartbeat()
            if not heartbeat or heartbeat.ok ~= true then
                Main.Visible = true
                Open.Visible = false
                Status.Text = heartbeat and ControlMessage(heartbeat)
                    or heartbeatError or "ERRO NO CONTROLE ONLINE"
            else
                SaveKey(key)
                Notify("PABLOX HUB", "Key validada com sucesso!", 3)
                local loaded, loadError = LoadHub(key)
                if loaded then
                    StartControl()
                    Gui:Destroy()
                    Busy = false
                    return
                end
                Main.Visible = true
                Open.Visible = false
                Status.Text = string.upper(tostring(loadError or "ERRO AO CARREGAR HUB"))
            end
        end
    else
        if resultType == "invalid" then DeleteKey() end
        Main.Visible = true
        Open.Visible = false
        Input.Text = key
        Status.Text = string.upper(tostring(message or "KEY INVÁLIDA"))
    end

    Verify.Text = "VERIFICAR KEY"
    Busy = false
end

Verify.MouseButton1Click:Connect(function()
    local key = Input.Text:match("^%s*(.-)%s*$")
    if key == "" then
        Status.Text = "DIGITE SUA KEY"
        return
    end
    task.spawn(function() Login(key, false) end)
end)

task.spawn(function()
    local savedKey = LoadKey()
    if savedKey then Login(savedKey, true) end
end)

print("[PABLOX KEY SYSTEM V9 + CONTROL V5] Carregado.")
