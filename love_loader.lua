--====================================================
-- LOVE HUB — KEY SYSTEM (carrega o LOVE_HUB.lua do R2 pelo Worker)
-- Mesmo sistema de Keys do PABLOX. Script: "love"
-- PC (Delta / Xeno). A Key precisa ser "Qualquer Hub" ou "Somente Love Hub".
--====================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Mesmo Worker dos loaders do PABLOX (copiado de PABLOX_LITE_LOADER.lua).
local CONTROL_URL = "https://pabloxhub-online-v5.pruan3733.workers.dev"
local API = CONTROL_URL .. "/api/public/validate"
local HUB_ENDPOINT = CONTROL_URL .. "/api/public/load-hub"
local VERSION_ENDPOINT = CONTROL_URL .. "/api/public/love-version"
local SCRIPT_NAME = "love"

local KEY_FILE = "LOVE_KEY_V1_" .. tostring(Player.UserId) .. ".txt"

-- Estado próprio: não mexe no monitor nem nas janelas do PABLOX.
local Env = (type(getgenv) == "function" and getgenv()) or _G
if Env.LOVE_LOADER_CONTROL then
    Env.LOVE_LOADER_CONTROL.running = false
end
local Monitor = {running = false}
Env.LOVE_LOADER_CONTROL = Monitor

for _, name in ipairs({"LOVE_KEY_SYSTEM", "LOVE_KEY_NOTIFICATION"}) do
    local old = PlayerGui:FindFirstChild(name)
    if old then old:Destroy() end
end

--------------------------------------------------------
-- Arquivo da Key (opcional, depende do executor)
--------------------------------------------------------
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

--------------------------------------------------------
-- HTTP
--------------------------------------------------------
local function GetRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    return nil
end

-- Devolve (tabela JSON, erro, status). Se o servidor respondeu um JSON, ele vem sempre,
-- para o motivo real (manutenção, Key, etc.) aparecer em vez de um erro genérico.
local function HttpJson(url, method, body)
    local requestFn = GetRequest()
    if not requestFn then return nil, "HTTP INDISPONÍVEL NESTE EXECUTOR" end
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
    local decoded, data = pcall(function()
        return HttpService:JSONDecode(response.Body or "")
    end)
    if decoded and type(data) == "table" then
        return data, nil, statusCode
    end
    if not statusCode or statusCode >= 500 then
        return nil, "SERVIDOR INDISPONÍVEL" .. (statusCode and (" (HTTP " .. statusCode .. ")") or ""), statusCode
    end
    return nil, "RESPOSTA INVÁLIDA (HTTP " .. tostring(statusCode) .. ")", statusCode
end

local function ValidateKey(key)
    local data, err, code = HttpJson(API, "POST", {
        key = key, userId = tostring(Player.UserId), script = SCRIPT_NAME,
        username = Player.Name, displayName = Player.DisplayName
    })
    if not data then return false, err, "network" end
    if data.maintenance then
        return false, tostring(data.message or "O Hub está atualizando"), "maintenance"
    end
    if code == 200 and data.ok == true then
        return true, "KEY VÁLIDA", "valid"
    end
    return false, tostring(data.error or data.message or "KEY INVÁLIDA"),
        ((code == 403 or code == 401) and "invalid" or "network")
end

local function CheckControl()
    return HttpJson(CONTROL_URL .. "/api/public/status", "GET")
end

local function SendHeartbeat(key)
    return HttpJson(CONTROL_URL .. "/api/public/heartbeat", "POST", {
        key = key,
        userId = tostring(Player.UserId),
        script = SCRIPT_NAME,
        username = Player.Name,
        displayName = Player.DisplayName
    })
end

local function ControlMessage(data)
    if data.banned then return "ACESSO BLOQUEADO" end
    if data.disabled then return "HUB DESATIVADO PELO ADMINISTRADOR" end
    if data.invalidKey then return "KEY CANCELADA OU EXPIRADA" end
    if data.maintenance then
        return tostring(data.message or "O Hub está atualizando")
    end
    return tostring(data.message or data.error or "SERVIDOR INDISPONÍVEL")
end

-- Pergunta ao Worker se o LOVE HUB já foi publicado (rota pública, só metadados).
local function CheckPublished()
    local data = HttpJson(VERSION_ENDPOINT, "GET")
    if type(data) == "table" and data.ok == true then
        return data.published == true, tostring(data.version or "")
    end
    return nil, "" -- rota indisponível: deixa o load-hub responder
end

-- Baixa o LOVE_HUB.lua (entrega privada, exige Key válida) e executa.
local function LoadHub(key)
    local requestFn = GetRequest()
    if not requestFn then return false, "HTTP INDISPONÍVEL NESTE EXECUTOR" end
    local ok, response = pcall(function()
        return requestFn({
            Url = HUB_ENDPOINT,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                key = key,
                userId = tostring(Player.UserId),
                username = Player.Name,
                displayName = Player.DisplayName,
                script = SCRIPT_NAME
            })
        })
    end)
    if not ok or type(response) ~= "table" then
        return false, "ERRO DE CONEXÃO COM O WORKER"
    end
    local statusCode = tonumber(response.StatusCode or response.Status) or 0
    local source = response.Body
    if statusCode ~= 200 then
        local parsed, info = pcall(function() return HttpService:JSONDecode(source or "") end)
        local reason = parsed and type(info) == "table" and (info.message or info.error)
        return false, tostring(reason or ("ERRO HTTP " .. statusCode))
    end
    if type(source) ~= "string" or #source < 100 then
        return false, "LOVE HUB VAZIO OU RESPOSTA INVÁLIDA"
    end
    if type(loadstring) ~= "function" then
        return false, "LOADSTRING INDISPONÍVEL NESTE EXECUTOR"
    end
    local fn, compileError = loadstring(source)
    if type(fn) ~= "function" then
        return false, tostring(compileError or "ERRO AO COMPILAR O LOVE HUB")
    end
    local executed, executionError = pcall(fn)
    if not executed then
        warn("[LOVE LOADER]", executionError)
        return false, "ERRO AO INICIAR O LOVE HUB"
    end
    return true
end

--------------------------------------------------------
-- Interface (preto AMOLED + grafite)
--------------------------------------------------------
local BLACK = Color3.fromRGB(0, 0, 0)
local ROW = Color3.fromRGB(18, 18, 20)
local GRAPHITE = Color3.fromRGB(62, 65, 71)
local GRAPHITE_L = Color3.fromRGB(150, 154, 162)
local MUTED = Color3.fromRGB(150, 150, 160)

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
    local old = PlayerGui:FindFirstChild("LOVE_KEY_NOTIFICATION")
    if old then old:Destroy() end

    local gui = CreateGui("LOVE_KEY_NOTIFICATION")
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(250, 62)
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, 260, 0, 55)
    frame.BackgroundColor3 = BLACK
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = gui
    Corner(frame, 10)
    local stroke = Instance.new("UIStroke")
    stroke.Color = GRAPHITE_L
    stroke.Thickness = 1.5
    stroke.Parent = frame

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
    messageLabel.TextTruncate = Enum.TextTruncate.AtEnd
    messageLabel.Parent = frame

    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Position = UDim2.new(1, -12, 0, 55)
    }):Play()

    task.delay(duration, function()
        if not frame.Parent then return end
        local tweenOut = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Position = UDim2.new(1, 260, 0, 55)
        })
        tweenOut:Play()
        tweenOut.Completed:Wait()
        if gui.Parent then gui:Destroy() end
    end)
end

-- Encerra o LOVE HUB quando o Worker manda parar (manutenção, ban, Key cancelada...).
local function StopHub(reason)
    Monitor.running = false
    warn("[LOVE HUB CONTROL]", reason)
    local cleanup = Env.LOVE_HUB_CLEANUP
    if type(cleanup) == "function" then
        pcall(cleanup)
    end
    Notify("LOVE HUB", reason, 8)
end

local function StartControl(key)
    if Monitor.running then return end
    Monitor.running = true
    task.spawn(function()
        while Monitor.running do
            local data = SendHeartbeat(key)
            if data and (data.maintenance or data.banned or data.disabled or data.invalidKey or data.accountBlocked or data.ok == false) then
                StopHub(ControlMessage(data))
                break
            end
            task.wait(5)
        end
    end)
end

local Gui = CreateGui("LOVE_KEY_SYSTEM")

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(320, 175)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.BackgroundColor3 = BLACK
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = Gui
Corner(Main, 12)
do
    local stroke = Instance.new("UIStroke")
    stroke.Color = GRAPHITE_L
    stroke.Thickness = 1.5
    stroke.Parent = Main
end

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -55, 0, 30)
Title.Position = UDim2.fromOffset(12, 5)
Title.BackgroundTransparency = 1
Title.Text = "LOVE HUB"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Active = true
Title.Parent = Main
do
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(70, 73, 79)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(190, 194, 202)),
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(70, 73, 79)),
    })
    grad.Parent = Title
end

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(30, 27)
Close.Position = UDim2.new(1, -39, 0, 5)
Close.BackgroundColor3 = ROW
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
Input.BackgroundColor3 = ROW
Input.BorderSizePixel = 0
Input.PlaceholderText = "INSIRA SUA KEY"
Input.PlaceholderColor3 = Color3.fromRGB(150, 150, 160)
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
Verify.BackgroundColor3 = GRAPHITE
Verify.BorderSizePixel = 0
Verify.Text = "VERIFICAR KEY"
Verify.TextColor3 = Color3.new(1, 1, 1)
Verify.Font = Enum.Font.GothamMedium
Verify.TextSize = 13
Verify.Parent = Main
Corner(Verify, 8)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -30, 0, 38)
Status.Position = UDim2.fromOffset(15, 128)
Status.BackgroundTransparency = 1
Status.Text = "AGUARDANDO KEY"
Status.TextColor3 = MUTED
Status.Font = Enum.Font.GothamMedium
Status.TextSize = 11
Status.TextWrapped = true
Status.Parent = Main

-- Bolinha para reabrir a janela depois de minimizar (PC: arrastável com o mouse).
local Open = Instance.new("TextButton")
Open.Size = UDim2.fromOffset(44, 44)
Open.AnchorPoint = Vector2.new(0.5, 0.5)
Open.Position = UDim2.new(0, 35, 0.5, 0)
Open.BackgroundColor3 = BLACK
Open.BorderSizePixel = 0
Open.Text = "LH"
Open.TextColor3 = Color3.new(1, 1, 1)
Open.Font = Enum.Font.GothamBlack
Open.TextSize = 14
Open.Visible = false
Open.Active = true
Open.Parent = Gui
Corner(Open, 22)
do
    local stroke = Instance.new("UIStroke")
    stroke.Color = GRAPHITE_L
    stroke.Thickness = 1.5
    stroke.Parent = Open
end

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
MakeDraggable(Open, Open)

local openMoved = false
local openStart
Open.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        openMoved = false
        openStart = input.Position
    end
end)
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

--------------------------------------------------------
-- Login
--------------------------------------------------------
local Busy = false

local function ShowError(text)
    Main.Visible = true
    Open.Visible = false
    Status.Text = string.upper(tostring(text))
end

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
        if not control or control.error then
            ShowError(controlError or (control and control.error) or "SERVIDOR INDISPONÍVEL")
        elseif control.maintenance then
            ShowError(ControlMessage(control))
        else
            local published, loveVersion = CheckPublished()
            if published == false then
                ShowError("O LOVE HUB AINDA NÃO FOI PUBLICADO NO PAINEL")
            else
                local heartbeat, heartbeatError = SendHeartbeat(key)
                if not heartbeat or heartbeat.ok ~= true then
                    ShowError(heartbeat and ControlMessage(heartbeat)
                        or heartbeatError or "ERRO NO CONTROLE ONLINE")
                else
                    SaveKey(key)
                    local loaded, loadError = LoadHub(key)
                    if loaded then
                        Notify("LOVE HUB",
                            (loveVersion ~= "" and ("v" .. loveVersion .. " • ") or "") .. "SHIFT DIREITO abre/fecha", 4)
                        StartControl(key)
                        Gui:Destroy()
                        Busy = false
                        return
                    end
                    ShowError(loadError or "ERRO AO CARREGAR O LOVE HUB")
                end
            end
        end
    else
        if resultType == "invalid" then DeleteKey() end
        Input.Text = key
        ShowError(message or "KEY INVÁLIDA")
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

print("[LOVE LOADER] Carregado.")
