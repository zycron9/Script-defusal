
-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║                   PasteWare V2 - Rayfield Edition (COMPLETO)                  ║
-- ║                        github.com/FakeAngles/PasteWare                         ║
-- ║                                                                               ║
-- ║  Removido: Redirecionamento Mobile + UI local                               ║
-- ║  Adicionado: Rayfield UI + Todas as funcionalidades originais               ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

if not game:IsLoaded() then
    game.Loaded:Wait()
end

if not syn or not protectgui then
    getgenv().protectgui = function() end
end

-- ===========================
-- INICIALIZAÇÃO DE SERVIÇOS
-- ===========================

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    GuiService = game:GetService("GuiService"),
    UserInputService = game:GetService("UserInputService"),
    HttpService = game:GetService("HttpService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Lighting = game:GetService("Lighting"),
    SoundService = game:GetService("SoundService")
}

local Players = Services.Players
local RunService = Services.RunService
local GuiService = Services.GuiService
local UserInputService = Services.UserInputService
local HttpService = Services.HttpService
local ReplicatedStorage = Services.ReplicatedStorage
local SoundService = Services.SoundService
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Client = LocalPlayer

local GetChildren = game.GetChildren
local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GuiInset = GuiService.GetGuiInset
local GetMouseLocation = UserInputService.GetMouseLocation

-- ===========================
-- ESTADO GLOBAL DO SCRIPT
-- ===========================

if not getgenv().ScriptState then
    getgenv().ScriptState = {
        isLockedOn = false,
        targetPlayer = nil,
        lockEnabled = false,
        lockTimeEnabled = false,
        aimLockKeyMode = "Toggle",
        aimLockVisibleCheck = false,
        aimLockAliveCheck = false,
        aimLockTeamCheck = false,
        smoothingFactor = 0.1,
        predictionFactor = 0.0,
        bodyPartSelected = "Head",
        ClosestHitPart = nil,
        previousHighlight = nil,
        lockedTime = 12,
        reverseResolveIntensity = 5,
        Desync = false,
        antiLockEnabled = false,
        resolverIntensity = 1.0,
        resolverMethod = "Recalculate",
        fovEnabled = false,
        fovMode = "Mouse",
        nebulaEnabled = false,
        fovValue = 70,
        SelfChamsEnabled = false,
        RainbowChamsEnabled = false,
        SelfChamsColor = Color3.fromRGB(255, 255, 255),
        ChamsEnabled = false,
        isSpeedActive = false,
        isFlyActive = false,
        isNoClipActive = false,
        flySpeed = 1,
        Cmultiplier = 1,
        strafeEnabled = false,
        strafeSpeed = 50,
        strafeRadius = 5,
        strafeMode = "Horizontal",
        strafeTargetPart = nil,
        originalCameraMode = nil,
    }
end

local ScriptState = getgenv().ScriptState

local SilentAimSettings = {
    Enabled = false,
    ClassName = "PasteWare | github.com/FakeAngles",
    ToggleKey = "None",
    KeyMode = "Toggle",
    TeamCheck = false,
    VisibleCheck = false,
    AliveCheck = false,
    TargetPart = "HumanoidRootPart",
    SilentAimMethod = "Raycast",
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = false,
    HitChance = 100,
    MultiplyUnitBy = 1000,
    BlockedMethods = {},
    Include = { Character = true, Camera = true },
    Origin = { Camera = true },
    BulletTP = false,
    CheckForFireFunc = false,
}

getgenv().SilentAimSettings = SilentAimSettings

-- ===========================
-- CONSTANTES E CONFIGURAÇÕES
-- ===========================

local ValidTargetParts = {"Head", "HumanoidRootPart"}
local PredictionAmount = 0.165

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 180
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

local ExpectedArguments = {
    ViewportPointToRay = {ArgCountRequired = 2, Args = { "number", "number" }},
    ScreenPointToRay = {ArgCountRequired = 2, Args = { "number", "number" }},
    Raycast = {ArgCountRequired = 3, Args = { "Instance", "Vector3", "Vector3", "RaycastParams" }},
    FindPartOnRay = {ArgCountRequired = 2, Args = { "Ray", "Instance?", "boolean?", "boolean?" }},
    FindPartOnRayWithIgnoreList = {ArgCountRequired = 2, Args = { "Ray", "table", "boolean?", "boolean?" }},
    FindPartOnRayWithWhitelist = {ArgCountRequired = 2, Args = { "Ray", "table", "boolean?" }},
}

-- ===========================
-- FUNÇÕES UTILITÁRIAS GERAIS
-- ===========================

function CalculateChance(Percentage)
    Percentage = math.floor(Percentage)
    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100
    return chance <= Percentage / 100
end

local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then
        return false
    end
    for Pos, Argument in next, Args do
        local Expected = RayMethod.Args[Pos]
        if not Expected then break end
        local IsOptional = Expected:sub(-1) == "?"
        local BaseType = IsOptional and Expected:sub(1, -2) or Expected
        if typeof(Argument) == BaseType then
            Matches = Matches + 1
        elseif IsOptional and Argument == nil then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit
end

local function getMousePosition()
    return GetMouseLocation(UserInputService)
end

local function getFovOrigin()
    if ScriptState.fovMode == "Center" then
        local viewportSize = Camera.ViewportSize
        return Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    end
    return getMousePosition()
end

local function getTeamComparisonOption()
    local esp = rawget(getgenv(), "ExunysDeveloperESP")
    if esp and esp.DeveloperSettings and esp.DeveloperSettings.TeamCheckOption then
        return esp.DeveloperSettings.TeamCheckOption
    end
end

local function playersOnSameTeam(player)
    if not player then return false end
    local option = getTeamComparisonOption()
    if option then
        local okLocal, localValue = pcall(function() return LocalPlayer[option] end)
        local okTarget, targetValue = pcall(function() return player[option] end)
        if okLocal and okTarget and localValue ~= nil and targetValue ~= nil then
            return targetValue == localValue
        end
    end
    local okLocalTeam, localTeam = pcall(function() return LocalPlayer.Team end)
    local okTargetTeam, targetTeam = pcall(function() return player.Team end)
    if okLocalTeam and okTargetTeam and localTeam and targetTeam then
        return targetTeam == localTeam
    end
    local okLocalColor, localColor = pcall(function() return LocalPlayer.TeamColor end)
    local okTargetColor, targetColor = pcall(function() return player.TeamColor end)
    if okLocalColor and okTargetColor and localColor and targetColor then
        return targetColor == localColor
    end
    return false
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player and Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    if not (PlayerCharacter and LocalPlayerCharacter) then return false end
    local targetPartOption = SilentAimSettings.TargetPart or "HumanoidRootPart"
    local PlayerRoot = FindFirstChild(PlayerCharacter, targetPartOption) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    if not PlayerRoot then return false end
    local CastPoints, IgnoreList = { PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter }, { LocalPlayerCharacter, PlayerCharacter }
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)
    return ObscuringObjects == 0
end

local function normalizeSelection(selection)
    if not selection then return {} end
    local normalized = {}
    if type(selection) ~= "table" then
        normalized[selection] = true
        return normalized
    end
    local hasNumericKeys = false
    for key in pairs(selection) do
        if type(key) == "number" then
            hasNumericKeys = true
            break
        end
    end
    if hasNumericKeys then
        for _, value in ipairs(selection) do
            normalized[value] = true
        end
    else
        for key, value in pairs(selection) do
            if type(key) == "string" then
                if value == true then
                    normalized[key] = true
                elseif type(value) == "string" then
                    normalized[value] = true
                end
            end
        end
    end
    return normalized
end

local function isSelectionActive(selection, option)
    return selection and selection[option] or false
end

SilentAimSettings.BlockedMethods = normalizeSelection(SilentAimSettings.BlockedMethods)
SilentAimSettings.Include = normalizeSelection(SilentAimSettings.Include)
SilentAimSettings.Origin = normalizeSelection(SilentAimSettings.Origin)

-- ===========================
-- FUNÇÕES DE DETECÇÃO DE ALVO
-- ===========================

local function getClosestPlayer(config)
    config = config or {}
    local targetPartOption = config.targetPart or SilentAimSettings.TargetPart
    if not targetPartOption then return nil, nil end
    local ignoredPlayers = config.ignoredPlayers
    local radiusOption = config.radius or SilentAimSettings.FOVRadius or 2000
    local visibleCheck = config.visibleCheck
    if visibleCheck == nil then visibleCheck = SilentAimSettings.VisibleCheck end
    local aliveCheck = config.aliveCheck
    if aliveCheck == nil then aliveCheck = SilentAimSettings.AliveCheck end
    local teamCheck = config.teamCheck
    if teamCheck == nil then
        local silentAimTeamCheck = SilentAimSettings.TeamCheck
        local aimLockTeamCheck = ScriptState and ScriptState.aimLockTeamCheck
        teamCheck = silentAimTeamCheck or aimLockTeamCheck or false
    end
    local teamEvaluator = config.teamEvaluator
    if type(teamEvaluator) ~= "function" then teamEvaluator = playersOnSameTeam end
    local originPosition = config.origin
    if typeof(originPosition) == "function" then originPosition = originPosition() end
    originPosition = originPosition or getFovOrigin()
    local ClosestPart, ClosestPlayer, DistanceToMouse
    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if ignoredPlayers and ignoredPlayers[Player.Name] then continue end
        if teamCheck and teamEvaluator(Player) then continue end
        if visibleCheck and not IsPlayerVisible(Player) then continue end
        local Character = Player.Character
        if not Character then continue end
        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid then continue end
        if aliveCheck and Humanoid.Health <= 0 then continue end
        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then continue end
        local Distance = (originPosition - ScreenPosition).Magnitude
        if Distance <= (DistanceToMouse or radiusOption) then
            local targetPartName
            if targetPartOption == "Random" then
                targetPartName = ValidTargetParts[math.random(1, #ValidTargetParts)]
            else
                targetPartName = targetPartOption
            end
            local candidatePart = Character[targetPartName]
            if candidatePart then
                ClosestPart = candidatePart
                ClosestPlayer = Player
                DistanceToMouse = Distance
            end
        end
    end
    return ClosestPart, ClosestPlayer
end

local function getBodyPart(character, part)
    return character:FindFirstChild(part) and part or "Head"
end

local function getNearestPlayerToMouse()
    local _, player = getClosestPlayer({
        targetPart = ScriptState.bodyPartSelected,
        visibleCheck = ScriptState.aimLockVisibleCheck,
        aliveCheck = ScriptState.aimLockAliveCheck,
        teamCheck = ScriptState.aimLockTeamCheck
    })
    if player and player ~= LocalPlayer then return player end
    return nil
end

local function acquireLockTarget()
    local player = getNearestPlayerToMouse()
    if player and player.Character then
        local partName = getBodyPart(player.Character, ScriptState.bodyPartSelected)
        local targetPart = player.Character:FindFirstChild(partName)
        if targetPart then
            ScriptState.isLockedOn = true
            ScriptState.targetPlayer = player
            return true
        end
    end
    ScriptState.isLockedOn = false
    ScriptState.targetPlayer = nil
    return false
end

local function toggleLockOnPlayer(forceState)
    local desiredState = forceState
    if desiredState == nil then
        desiredState = not ScriptState.lockEnabled
    end
    ScriptState.lockEnabled = desiredState
    if desiredState then
        acquireLockTarget()
    else
        ScriptState.isLockedOn = false
        ScriptState.targetPlayer = nil
    end
end

-- ===========================
-- AIMLOCK - RENDERSTEPPED LOOP
-- ===========================

RunService.RenderStepped:Connect(function()
    if ScriptState.lockEnabled and not ScriptState.isLockedOn then
        acquireLockTarget()
    end
    if ScriptState.lockEnabled and ScriptState.isLockedOn and ScriptState.targetPlayer and ScriptState.targetPlayer.Character then
        if ScriptState.aimLockTeamCheck and ScriptState.targetPlayer.Team == LocalPlayer.Team then
            ScriptState.isLockedOn = false
            ScriptState.targetPlayer = nil
            return
        end
        if ScriptState.aimLockVisibleCheck and not IsPlayerVisible(ScriptState.targetPlayer) then
            ScriptState.isLockedOn = false
            ScriptState.targetPlayer = nil
            return
        end
        local partName = getBodyPart(ScriptState.targetPlayer.Character, ScriptState.bodyPartSelected)
        local part = ScriptState.targetPlayer.Character:FindFirstChild(partName)
        if part and ScriptState.targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * ScriptState.predictionFactor)
            local currentCameraPosition = Camera.CFrame.Position
            Camera.CFrame = CFrame.new(currentCameraPosition, predictedPosition) * CFrame.new(0, 0, ScriptState.smoothingFactor)
        else
            ScriptState.isLockedOn = false
            ScriptState.targetPlayer = nil
        end
    end
end)

-- ===========================
-- DESYNC - HEARTBEAT LOOP
-- ===========================

RunService.Heartbeat:Connect(function()
    if ScriptState.Desync then
        local player = game.Players.LocalPlayer
        local character = player.Character
        if not character then return end
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        local originalVelocity = humanoidRootPart.Velocity
        local randomOffset = Vector3.new(
            math.random(-1, 1) * ScriptState.reverseResolveIntensity * 1000,
            math.random(-1, 1) * ScriptState.reverseResolveIntensity * 1000,
            math.random(-1, 1) * ScriptState.reverseResolveIntensity * 1000
        )
        humanoidRootPart.Velocity = randomOffset
        humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.Angles(
            0,
            math.random(-1, 1) * ScriptState.reverseResolveIntensity * 0.001,
            0
        )
        RunService.RenderStepped:Wait()
        humanoidRootPart.Velocity = originalVelocity
    end
end)

-- ===========================
-- ANTI-LOCK RESOLVER
-- ===========================

RunService.RenderStepped:Connect(function()
    if ScriptState.isLockedOn and ScriptState.targetPlayer and ScriptState.targetPlayer.Character then
        local partName = getBodyPart(ScriptState.targetPlayer.Character, ScriptState.bodyPartSelected)
        local part = ScriptState.targetPlayer.Character:FindFirstChild(partName)
        if part and ScriptState.targetPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local predictedPosition = part.Position + (part.AssemblyLinearVelocity * ScriptState.predictionFactor)
            if ScriptState.antiLockEnabled then
                if ScriptState.resolverMethod == "Recalculate" then
                    predictedPosition = predictedPosition + (part.AssemblyLinearVelocity * ScriptState.resolverIntensity)
                elseif ScriptState.resolverMethod == "Randomize" then
                    predictedPosition = predictedPosition + Vector3.new(
                        math.random() * ScriptState.resolverIntensity - (ScriptState.resolverIntensity / 2),
                        math.random() * ScriptState.resolverIntensity - (ScriptState.resolverIntensity / 2),
                        math.random() * ScriptState.resolverIntensity - (ScriptState.resolverIntensity / 2)
                    )
                elseif ScriptState.resolverMethod == "Invert" then
                    predictedPosition = predictedPosition - (part.AssemblyLinearVelocity * ScriptState.resolverIntensity * 2)
                end
            end
            local currentCameraPosition = Camera.CFrame.Position
            Camera.CFrame = CFrame.new(currentCameraPosition, predictedPosition) * CFrame.new(0, 0, ScriptState.smoothingFactor)
        else
            ScriptState.isLockedOn = false
            ScriptState.targetPlayer = nil
        end
    end
end)

-- ===========================
-- HITSOUND SYSTEM
-- ===========================

local sounds = {
    ["RIFK7"] = "rbxassetid://9102080552",
    ["Bubble"] = "rbxassetid://9102092728",
    ["Minecraft"] = "rbxassetid://5869422451",
    ["Cod"] = "rbxassetid://160432334",
    ["Bameware"] = "rbxassetid://6565367558",
    ["Neverlose"] = "rbxassetid://6565370984",
    ["Gamesense"] = "rbxassetid://4817809188",
    ["Rust"] = "rbxassetid://6565371338",
}

local hitSound = Instance.new("Sound")
hitSound.Volume = 3
hitSound.Parent = SoundService
hitSound.SoundId = sounds["Neverlose"]

local soundPool = {}
local soundIndex = 1
local HitSoundEnabled = false
local CurrentHitSound = "Neverlose"

local function getNextSound()
    if soundIndex > #soundPool then
        local s = hitSound:Clone()
        s.Parent = workspace
        s.Looped = false
        table.insert(soundPool, s)
    end
    local s = soundPool[soundIndex]
    soundIndex = soundIndex + 1
    return s
end

local function playHitSound()
    local s = getNextSound()
    s:Stop()
    s:Play()
end

local function trackPlayer(plr)
    if plr == LocalPlayer then return end
    plr.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end
        local lastHealth = hum.Health
        hum.HealthChanged:Connect(function(newHp)
            if HitSoundEnabled then
                local closestPart, closestPlayer = getClosestPlayer()
                if closestPart and closestPlayer and closestPlayer == plr then
                    if newHp < lastHealth then
                        playHitSound()
                    end
                    if lastHealth > 0 and newHp <= 0 then
                        playHitSound()
                    end
                end
            end
            lastHealth = newHp
        end)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    trackPlayer(plr)
end
Players.PlayerAdded:Connect(trackPlayer)

-- ===========================
-- CHAMS SYSTEM
-- ===========================

local originalProperties = {}

local function HSVToRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    return Color3.new(r + m, g + m, b + m)
end

local function applyChams(char)
    if not char then return end
    originalProperties = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            originalProperties[part] = {
                Color = part.Color,
                Material = part.Material
            }
            part.Material = Enum.Material.ForceField
            part.Color = ScriptState.SelfChamsColor
        end
    end
end

local function restoreChams()
    for part, props in pairs(originalProperties) do
        if part and part.Parent then
            part.Color = props.Color
            part.Material = props.Material
        end
    end
    originalProperties = {}
end

local function updateChams()
    if not ScriptState.SelfChamsEnabled then return end
    for part, _ in pairs(originalProperties) do
        if part and part.Parent then
            if ScriptState.RainbowChamsEnabled then
                local hue = (tick() * 120) % 360
                part.Color = HSVToRGB(hue, 1, 1)
            else
                part.Color = ScriptState.SelfChamsColor
            end
        end
    end
end

RunService.RenderStepped:Connect(updateChams)

LocalPlayer.CharacterAdded:Connect(function(char)
    if ScriptState.SelfChamsEnabled then
        task.wait(1)
        applyChams(char)
    end
end)

-- ===========================
-- ENEMY CHAMS SYSTEM
-- ===========================

local ChamsOccludedColor = {Color3.fromRGB(128, 0, 128), 0.7}
local ChamsVisibleColor = {Color3.fromRGB(255, 0, 255), 0.3}
local AdornmentsCache = {}
local IgnoreNames = {["HumanoidRootPart"] = true}

local function CreateAdornment(part, isHead, vis)
    local adorn
    if isHead then
        adorn = Instance.new("CylinderHandleAdornment")
        adorn.Height = vis == 1 and 0.87 or 1.02
        adorn.Radius = vis == 1 and 0.5 or 0.65
    else
        adorn = Instance.new("BoxHandleAdornment")
        local offset = vis == 1 and -0.05 or 0.05
        adorn.Size = part.Size + Vector3.new(offset, offset, offset)
    end
    adorn.Adornee = part
    adorn.Parent = part
    adorn.ZIndex = vis == 1 and 2 or 1
    adorn.AlwaysOnTop = vis == 1
    adorn.Visible = false
    return adorn
end

local function IsEnemy(player)
    if LocalPlayer.Team and player.Team then
        return player.Team ~= LocalPlayer.Team
    end
    return true
end

local function ApplyChams(player)
    if player ~= LocalPlayer and player.Character then
        for _, part in pairs(player.Character:GetChildren()) do
            if part:IsA("BasePart") and not IgnoreNames[part.Name] then
                if not AdornmentsCache[part] then
                    AdornmentsCache[part] = {
                        CreateAdornment(part, part.Name=="Head", 1),
                        CreateAdornment(part, part.Name=="Head", 2)
                    }
                end
                local ad = AdornmentsCache[part]
                local visible = ScriptState.ChamsEnabled and IsEnemy(player)
                ad[1].Visible = visible
                ad[1].Color3 = ChamsOccludedColor[1]
                ad[1].Transparency = ChamsOccludedColor[2]
                ad[2].Visible = visible
                ad[2].AlwaysOnTop = true
                ad[2].ZIndex = 9e9
                ad[2].Color3 = ChamsVisibleColor[1]
                ad[2].Transparency = ChamsVisibleColor[2]
            end
        end
    end
end

local function UpdateAllChams()
    for _, player in pairs(Players:GetPlayers()) do
        ApplyChams(player)
    end
end

local function TrackPlayer(player)
    player:GetPropertyChangedSignal("Team"):Connect(function()
        if AdornmentsCache[player] then
            for _, ad in pairs(AdornmentsCache[player]) do
                ad.Visible = ScriptState.ChamsEnabled and IsEnemy(player)
            end
        end
    end)
end

Players.PlayerAdded:Connect(TrackPlayer)
for _, plr in pairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then TrackPlayer(plr) end
end

RunService.RenderStepped:Connect(UpdateAllChams)

-- ===========================
-- ESP SYSTEM (HIGHLIGHTS)
-- ===========================

local function removeOldHighlight()
    if ScriptState.previousHighlight then
        ScriptState.previousHighlight:Destroy()
        ScriptState.previousHighlight = nil
    end
end

task.spawn(function()
    RenderStepped:Connect(function()
        if SilentAimSettings.ShowSilentAimTarget then
            local visibleCheckActive = SilentAimSettings.VisibleCheck or ScriptState.aimLockVisibleCheck
            local teamCheckActive = SilentAimSettings.TeamCheck or ScriptState.aimLockTeamCheck
            local aliveCheckActive = SilentAimSettings.AliveCheck or ScriptState.aimLockAliveCheck
            local closestPart, closestPlayer = getClosestPlayer({
                visibleCheck = visibleCheckActive,
                teamCheck = teamCheckActive,
                aliveCheck = aliveCheckActive
            })
            if closestPart and closestPlayer then
                local char = closestPlayer.Character or closestPart.Parent
                if char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") then
                    if teamCheckActive and playersOnSameTeam(closestPlayer) then
                        removeOldHighlight()
                        return
                    end
                    if visibleCheckActive and not IsPlayerVisible(closestPlayer) then
                        removeOldHighlight()
                        return
                    end
                    local Root = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
                    if Root then
                        local RootToViewportPoint, IsOnScreen = WorldToViewportPoint(Camera, Root.Position)
                        removeOldHighlight()
                        if IsOnScreen then
                            local highlight = char:FindFirstChildOfClass("Highlight")
                            if not highlight then
                                highlight = Instance.new("Highlight")
                                highlight.Parent = char
                                highlight.Adornee = char
                            end
                            highlight.FillColor = Color3.fromRGB(54, 57, 241)
                            highlight.FillTransparency = 0.5
                            highlight.OutlineColor = Color3.fromRGB(54, 57, 241)
                            highlight.OutlineTransparency = 0
                            ScriptState.previousHighlight = highlight
                        end
                    end
                end
            else
                removeOldHighlight()
            end
        end
    end)
end)

-- ===========================
-- WEAPON MODIFICATION SYSTEM
-- ===========================

getgenv().WeaponOnHands = false
getgenv().WeaponModifyMethod = "Attribute"
getgenv().bulletSpeedValue = 10000

local function findSettingsModuleForWeapon(weapon, property)
    if not (weapon and weapon:IsA("Tool")) then return nil end
    local function moduleSupportsProperty(moduleScript)
        local success, module = pcall(require, moduleScript)
        if success and type(module) == "table" and module[property] ~= nil then
            return true
        end
        return false
    end
    for _, moduleScript in ipairs(weapon:GetDescendants()) do
        if moduleScript:IsA("ModuleScript") and moduleSupportsProperty(moduleScript) then
            return moduleScript
        end
    end
    local weaponName = weapon.Name
    local searchFolders = {}
    local configurations = ReplicatedStorage:FindFirstChild("Configurations")
    if configurations then
        table.insert(searchFolders, configurations)
    end
    local acsFolder = ReplicatedStorage:FindFirstChild("ACS_Guns", true)
    if acsFolder then
        table.insert(searchFolders, acsFolder)
    end
    table.insert(searchFolders, ReplicatedStorage)
    for _, container in ipairs(searchFolders) do
        if typeof(container) == "Instance" then
            local candidate = container:FindFirstChild(weaponName, true)
            if candidate then
                if candidate:IsA("ModuleScript") and moduleSupportsProperty(candidate) then
                    return candidate
                end
                for _, moduleScript in ipairs(candidate:GetDescendants()) do
                    if moduleScript:IsA("ModuleScript") and moduleSupportsProperty(moduleScript) then
                        return moduleScript
                    end
                end
            end
        end
    end
    return nil
end

local function modifyWeaponSettings(property, value)
    local player = Players.LocalPlayer
    local backpack = player:WaitForChild("Backpack")
    local character = player.Character or player.CharacterAdded:Wait()
    local function applyAttribute(weapon)
        if weapon and weapon:IsA("Tool") then
            pcall(function()
                weapon:SetAttribute(property, value)
            end)
        end
    end
    local function applyRequireModule(weapon)
        local settingsModule = findSettingsModuleForWeapon(weapon, property)
        if settingsModule then
            local success, module = pcall(require, settingsModule)
            if success and type(module) == "table" and module[property] ~= nil then
                module[property] = value
            end
        end
    end
    local function processWeapon(weapon)
        if not (weapon and weapon:IsA("Tool")) then return end
        if (getgenv().WeaponModifyMethod or "Attribute") == "Attribute" then
            applyAttribute(weapon)
        else
            applyRequireModule(weapon)
        end
    end
    local handledEquippedWeapon = false
    if getgenv().WeaponOnHands then
        local toolInHand = character:FindFirstChildOfClass("Tool")
        if toolInHand then
            processWeapon(toolInHand)
            handledEquippedWeapon = true
        end
    end
    if not handledEquippedWeapon then
        for _, item in ipairs(backpack:GetChildren()) do
            processWeapon(item)
        end
        local equippedTool = character:FindFirstChildOfClass("Tool")
        if equippedTool and equippedTool.Parent ~= backpack then
            processWeapon(equippedTool)
        end
    end
end

-- ===========================
-- SKYBOX SYSTEM
-- ===========================

local Lighting = Services.Lighting
local Visuals = {}
local Skyboxes = {}

function Visuals:NewSky(Data)
    local Name = Data.Name
    Skyboxes[Name] = {
        SkyboxBk = Data.SkyboxBk,
        SkyboxDn = Data.SkyboxDn,
        SkyboxFt = Data.SkyboxFt,
        SkyboxLf = Data.SkyboxLf,
        SkyboxRt = Data.SkyboxRt,
        SkyboxUp = Data.SkyboxUp,
        MoonTextureId = Data.Moon or "rbxasset://sky/moon.jpg",
        SunTextureId = Data.Sun or "rbxasset://sky/sun.jpg"
    }
end

function Visuals:SwitchSkybox(Name)
    local OldSky = Lighting:FindFirstChildOfClass("Sky")
    if OldSky then OldSky:Destroy() end
    local Sky = Instance.new("Sky", Lighting)
    for Index, Value in pairs(Skyboxes[Name]) do
        Sky[Index] = Value
    end
end

if Lighting:FindFirstChildOfClass("Sky") then
    local OldSky = Lighting:FindFirstChildOfClass("Sky")
    Visuals:NewSky({
        Name = "Game's Default Sky",
        SkyboxBk = OldSky.SkyboxBk,
        SkyboxDn = OldSky.SkyboxDn,
        SkyboxFt = OldSky.SkyboxFt,
        SkyboxLf = OldSky.SkyboxLf,
        SkyboxRt = OldSky.SkyboxRt,
        SkyboxUp = OldSky.SkyboxUp
    })
end

Visuals:NewSky({Name = "Sunset", SkyboxBk = "rbxassetid://600830446", SkyboxDn = "rbxassetid://600831635", SkyboxFt = "rbxassetid://600832720", SkyboxLf = "rbxassetid://600886090", SkyboxRt = "rbxassetid://600833862", SkyboxUp = "rbxassetid://600835177"})
Visuals:NewSky({Name = "Arctic", SkyboxBk = "http://www.roblox.com/asset/?id=225469390", SkyboxDn = "http://www.roblox.com/asset/?id=225469395", SkyboxFt = "http://www.roblox.com/asset/?id=225469403", SkyboxLf = "http://www.roblox.com/asset/?id=225469450", SkyboxRt = "http://www.roblox.com/asset/?id=225469471", SkyboxUp = "http://www.roblox.com/asset/?id=225469481"})
Visuals:NewSky({Name = "Space", SkyboxBk = "http://www.roblox.com/asset/?id=166509999", SkyboxDn = "http://www.roblox.com/asset/?id=166510057", SkyboxFt = "http://www.roblox.com/asset/?id=166510116", SkyboxLf = "http://www.roblox.com/asset/?id=166510092", SkyboxRt = "http://www.roblox.com/asset/?id=166510131", SkyboxUp = "http://www.roblox.com/asset/?id=166510114"})
Visuals:NewSky({Name = "Roblox Default", SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex", SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex", SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex", SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex", SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex", SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"})
Visuals:NewSky({Name = "Red Night", SkyboxBk = "http://www.roblox.com/Asset/?ID=401664839", SkyboxDn = "http://www.roblox.com/Asset/?ID=401664862", SkyboxFt = "http://www.roblox.com/Asset/?ID=401664960", SkyboxLf = "http://www.roblox.com/Asset/?ID=401664881", SkyboxRt = "http://www.roblox.com/Asset/?ID=401664901", SkyboxUp = "http://www.roblox.com/Asset/?ID=401664936"})
Visuals:NewSky({Name = "Deep Space", SkyboxBk = "http://www.roblox.com/asset/?id=149397692", SkyboxDn = "http://www.roblox.com/asset/?id=149397686", SkyboxFt = "http://www.roblox.com/asset/?id=149397697", SkyboxLf = "http://www.roblox.com/asset/?id=149397684", SkyboxRt = "http://www.roblox.com/asset/?id=149397688", SkyboxUp = "http://www.roblox.com/asset/?id=149397702"})
Visuals:NewSky({Name = "Pink Skies", SkyboxBk = "http://www.roblox.com/asset/?id=151165214", SkyboxDn = "http://www.roblox.com/asset/?id=151165197", SkyboxFt = "http://www.roblox.com/asset/?id=151165224", SkyboxLf = "http://www.roblox.com/asset/?id=151165191", SkyboxRt = "http://www.roblox.com/asset/?id=151165206", SkyboxUp = "http://www.roblox.com/asset/?id=151165227"})
Visuals:NewSky({Name = "Purple Sunset", SkyboxBk = "rbxassetid://264908339", SkyboxDn = "rbxassetid://264907909", SkyboxFt = "rbxassetid://264909420", SkyboxLf = "rbxassetid://264909758", SkyboxRt = "rbxassetid://264908886", SkyboxUp = "rbxassetid://264907379"})
Visuals:NewSky({Name = "Blue Night", SkyboxBk = "http://www.roblox.com/Asset/?ID=12064107", SkyboxDn = "http://www.roblox.com/Asset/?ID=12064152", SkyboxFt = "http://www.roblox.com/Asset/?ID=12064121", SkyboxLf = "http://www.roblox.com/Asset/?ID=12063984", SkyboxRt = "http://www.roblox.com/Asset/?ID=12064115", SkyboxUp = "http://www.roblox.com/Asset/?ID=12064131"})
Visuals:NewSky({Name = "Blossom Daylight", SkyboxBk = "http://www.roblox.com/asset/?id=271042516", SkyboxDn = "http://www.roblox.com/asset/?id=271077243", SkyboxFt = "http://www.roblox.com/asset/?id=271042556", SkyboxLf = "http://www.roblox.com/asset/?id=271042310", SkyboxRt = "http://www.roblox.com/asset/?id=271042467", SkyboxUp = "http://www.roblox.com/asset/?id=271077958"})
Visuals:NewSky({Name = "Blue Nebula", SkyboxBk = "http://www.roblox.com/asset?id=135207744", SkyboxDn = "http://www.roblox.com/asset?id=135207662", SkyboxFt = "http://www.roblox.com/asset?id=135207770", SkyboxLf = "http://www.roblox.com/asset?id=135207615", SkyboxRt = "http://www.roblox.com/asset?id=135207695", SkyboxUp = "http://www.roblox.com/asset?id=135207794"})
Visuals:NewSky({Name = "Blue Planet", SkyboxBk = "rbxassetid://218955819", SkyboxDn = "rbxassetid://218953419", SkyboxFt = "rbxassetid://218954524", SkyboxLf = "rbxassetid://218958493", SkyboxRt = "rbxassetid://218957134", SkyboxUp = "rbxassetid://218950090"})
Visuals:NewSky({Name = "Deep Space Alt", SkyboxBk = "http://www.roblox.com/asset/?id=159248188", SkyboxDn = "http://www.roblox.com/asset/?id=159248183", SkyboxFt = "http://www.roblox.com/asset/?id=159248187", SkyboxLf = "http://www.roblox.com/asset/?id=159248173", SkyboxRt = "http://www.roblox.com/asset/?id=159248192", SkyboxUp = "http://www.roblox.com/asset/?id=159248176"})

local SkyboxNames = {}
for Name, _ in pairs(Skyboxes) do
    table.insert(SkyboxNames, Name)
end

-- ===========================
-- TARGET STRAFE SYSTEM
-- ===========================

local function startTargetStrafe()
    local targetPart = getClosestPlayer()
    ScriptState.strafeTargetPart = targetPart
    if ScriptState.strafeTargetPart and ScriptState.strafeTargetPart.Parent then
        ScriptState.originalCameraMode = Players.LocalPlayer.CameraMode
        Players.LocalPlayer.CameraMode = Enum.CameraMode.Classic
        local targetPos = ScriptState.strafeTargetPart.Position
        LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(targetPos))
        Camera.CameraSubject = ScriptState.strafeTargetPart.Parent:FindFirstChild("Humanoid")
    end
end

local function strafeAroundTarget()
    if not (ScriptState.strafeTargetPart and ScriptState.strafeTargetPart.Parent) then return end
    local targetPos = ScriptState.strafeTargetPart.Position
    local angle = tick() * (ScriptState.strafeSpeed / 10)
    local offset = ScriptState.strafeMode == "Horizontal"
        and Vector3.new(math.cos(angle) * ScriptState.strafeRadius, 0, math.sin(angle) * ScriptState.strafeRadius)
        or Vector3.new(math.cos(angle) * ScriptState.strafeRadius, ScriptState.strafeRadius, math.sin(angle) * ScriptState.strafeRadius)
    LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(targetPos + offset))
    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, targetPos)
end

local function stopTargetStrafe()
    Players.LocalPlayer.CameraMode = ScriptState.originalCameraMode or Enum.CameraMode.Classic
    Camera.CameraSubject = LocalPlayer.Character.Humanoid
    ScriptState.strafeEnabled, ScriptState.strafeTargetPart = false, nil
end

RunService.RenderStepped:Connect(function()
    if ScriptState.strafeEnabled then
        strafeAroundTarget()
    end
end)

-- ===========================
-- SILENT AIM HOOK
-- ===========================

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method, Arguments = getnamecallmethod(), {...}
    local self, chance = Arguments[1], CalculateChance(SilentAimSettings.HitChance)
    local BlockedMethods = SilentAimSettings.BlockedMethods or {}
    if Method == "Destroy" and self == Client then return end
    if BlockedMethods[Method] then return end
    local function getIgnoredList()
        if Method == "Raycast" then
            local params = Arguments[4]
            if typeof(params) == "RaycastParams" then
                return params.FilterDescendantsInstances
            end
        elseif Method == "FindPartOnRayWithIgnoreList" then
            return Arguments[3]
        end
    end
    local function getOriginalOrigin()
        if Method == "Raycast" then
            return Arguments[2]
        end
        if Method == "FindPartOnRayWithIgnoreList" or Method == "FindPartOnRayWithWhitelist" or Method == "FindPartOnRay" or Method == "findPartOnRay" then
            local ray = Arguments[2]
            if typeof(ray) == "Ray" then
                return ray.Origin
            end
        end
        return nil
    end
    local allowedFireCall = true
    if SilentAimSettings.CheckForFireFunc and (Method == "FindPartOnRay" or Method == "findPartOnRay" or Method == "FindPartOnRayWithWhitelist" or Method == "FindPartOnRayWithIgnoreList" or Method == "Raycast" or Method == "ViewportPointToRay" or Method == "ScreenPointToRay") then
        local trace = tostring(debug.traceback()):lower()
        if trace:find("bullet") or trace:find("gun") or trace:find("fire") then
            allowedFireCall = true
        else
            return oldNamecall(...)
        end
    end
    if SilentAimSettings.Enabled and self == workspace and not checkcaller() and chance and allowedFireCall then
        local HitPart = ScriptState.ClosestHitPart or getClosestPlayer()
        if HitPart then
            local ignoredList = getIgnoredList()
            local originOptions = SilentAimSettings.Origin
            local includeOptions = SilentAimSettings.Include
            local originalOrigin = getOriginalOrigin()
            if originalOrigin and originOptions and next(originOptions) then
                local matchesOrigin = false
                if isSelectionActive(originOptions, "Camera") and originalOrigin == Camera.CFrame.p then
                    matchesOrigin = true
                end
                if not matchesOrigin then
                    return oldNamecall(...)
                end
            end
            if ignoredList and includeOptions and next(includeOptions) then
                if isSelectionActive(includeOptions, "Camera") and not table.find(ignoredList, Camera) then
                    return oldNamecall(...)
                end
                local character = LocalPlayer.Character
                if character and isSelectionActive(includeOptions, "Character") and not table.find(ignoredList, character) then
                    return oldNamecall(...)
                end
            end
            local function computeRay(origin)
                local adjustedOrigin = origin
                if SilentAimSettings.BulletTP then
                    adjustedOrigin = (HitPart.CFrame * CFrame.new(0, 0, 1)).p
                end
                local multiplier = SilentAimSettings.MultiplyUnitBy or 1000
                local direction = getDirection(adjustedOrigin, HitPart.Position) * multiplier
                return adjustedOrigin, direction
            end
            if Method == "FindPartOnRayWithIgnoreList" and SilentAimSettings.SilentAimMethod == Method then
                if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                    local Origin, Direction = computeRay(Arguments[2].Origin)
                    Arguments[2] = Ray.new(Origin, Direction)
                    return oldNamecall(unpack(Arguments))
                end
            elseif Method == "FindPartOnRayWithWhitelist" and SilentAimSettings.SilentAimMethod == Method then
                if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then
                    local Origin, Direction = computeRay(Arguments[2].Origin)
                    Arguments[2] = Ray.new(Origin, Direction)
                    return oldNamecall(unpack(Arguments))
                end
            elseif (Method == "FindPartOnRay" or Method == "findPartOnRay") and SilentAimSettings.SilentAimMethod:lower() == Method:lower() then
                if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then
                    local Origin, Direction = computeRay(Arguments[2].Origin)
                    Arguments[2] = Ray.new(Origin, Direction)
                    return oldNamecall(unpack(Arguments))
                end
            elseif Method == "Raycast" and SilentAimSettings.SilentAimMethod == Method then
                if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
                    local Origin, Direction = computeRay(Arguments[2])
                    Arguments[2], Arguments[3] = Origin, Direction
                    return oldNamecall(unpack(Arguments))
                end
            elseif Method == "ViewportPointToRay" and SilentAimSettings.SilentAimMethod == Method then
                if ValidateArguments(Arguments, ExpectedArguments.ViewportPointToRay) then
                    local Origin = Camera.CFrame.p
                    local NewOrigin, Direction = computeRay(Origin)
                    return Ray.new(NewOrigin, Direction)
                end
            elseif Method == "ScreenPointToRay" and SilentAimSettings.SilentAimMethod == Method then
                if ValidateArguments(Arguments, ExpectedArguments.ScreenPointToRay) then
                    local Origin = Camera.CFrame.p
                    local NewOrigin, Direction = computeRay(Origin)
                    return Ray.new(NewOrigin, Direction)
                end
            elseif Method == "FindPartOnRayWithIgnoreList" and SilentAimSettings.SilentAimMethod == "CounterBlox" then
                local Origin, Direction = computeRay(Arguments[2].Origin)
                Arguments[2] = Ray.new(Origin, Direction)
                return oldNamecall(unpack(Arguments))
            end
        end
    end
    return oldNamecall(...)
end))

RunService.Heartbeat:Connect(function()
    if SilentAimSettings.Enabled then
        local closestPart = getClosestPlayer()
        ScriptState.ClosestHitPart = closestPart
    else
        ScriptState.ClosestHitPart = nil
    end
end)

-- ===========================
-- RAYFIELD UI INITIALIZATION
-- ===========================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "PasteWare v2 - Rayfield Edition",
    LoadingTitle = "PasteWare v2",
    LoadingSubtitle = "by FakeAngles | Converted to Rayfield",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "PasteWare_Config",
        FileName = "PasteWare_Settings"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false,
    IntroEnabled = true,
    IntroText = "PasteWare v2 Rayfield",
    IntroIcon = "rbxassetid://10723344830",
    Icon = "rbxassetid://10723344830",
})

-- ===========================
-- MAIN TAB - AIMLOCK
-- ===========================

local MainTab = Window:CreateTab("Main", 4483362458)
local AimlockSection = MainTab:CreateSection("AimLock Settings")

Rayfield:CreateToggle({
    Name = "Enable AimLock",
    CurrentValue = ScriptState.lockEnabled,
    Flag = "aimlockToggle",
    Callback = function(value)
        toggleLockOnPlayer(value)
    end,
}, AimlockSection)

Rayfield:CreateSlider({
    Name = "Camera Smoothing",
    MinValue = 0,
    MaxValue = 1,
    Increment = 0.05,
    Suffix = "",
    CurrentValue = ScriptState.smoothingFactor,
    Flag = "smoothingSlider",
    Callback = function(value)
        ScriptState.smoothingFactor = value
    end,
}, AimlockSection)

Rayfield:CreateSlider({
    Name = "Prediction Factor",
    MinValue = 0,
    MaxValue = 2,
    Increment = 0.05,
    Suffix = "",
    CurrentValue = ScriptState.predictionFactor,
    Flag = "predictionSlider",
    Callback = function(value)
        ScriptState.predictionFactor = value
    end,
}, AimlockSection)

Rayfield:CreateToggle({
    Name = "Visible Check",
    CurrentValue = ScriptState.aimLockVisibleCheck,
    Flag = "aimLockVisibleCheck",
    Callback = function(value)
        ScriptState.aimLockVisibleCheck = value
    end,
}, AimlockSection)

Rayfield:CreateToggle({
    Name = "Alive Check",
    CurrentValue = ScriptState.aimLockAliveCheck,
    Flag = "aimLockAliveCheck",
    Callback = function(value)
        ScriptState.aimLockAliveCheck = value
    end,
}, AimlockSection)

Rayfield:CreateToggle({
    Name = "Team Check",
    CurrentValue = ScriptState.aimLockTeamCheck,
    Flag = "aimLockTeamCheck",
    Callback = function(value)
        ScriptState.aimLockTeamCheck = value
        if value and ScriptState.lockEnabled and ScriptState.targetPlayer and ScriptState.targetPlayer.Team == LocalPlayer.Team then
            acquireLockTarget()
        end
    end,
}, AimlockSection)

Rayfield:CreateDropdown({
    Name = "Target Body Part",
    Options = {"Head", "UpperTorso", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm", "Chest"},
    CurrentOption = {ScriptState.bodyPartSelected},
    Flag = "bodyPartDropdown",
    Callback = function(option)
        ScriptState.bodyPartSelected = option[1]
    end,
}, AimlockSection)

-- Anti-Lock Resolver Section
local AntiLockSection = MainTab:CreateSection("Anti-Lock Resolver")

Rayfield:CreateToggle({
    Name = "Enable Anti-Lock",
    CurrentValue = ScriptState.antiLockEnabled,
    Flag = "antiLockToggle",
    Callback = function(value)
        ScriptState.antiLockEnabled = value
    end,
}, AntiLockSection)

Rayfield:CreateSlider({
    Name = "Resolver Intensity",
    MinValue = 0,
    MaxValue = 5,
    Increment = 0.1,
    Suffix = "",
    CurrentValue = ScriptState.resolverIntensity,
    Flag = "resolverIntensitySlider",
    Callback = function(value)
        ScriptState.resolverIntensity = value
    end,
}, AntiLockSection)

Rayfield:CreateDropdown({
    Name = "Resolver Method",
    Options = {"Recalculate", "Randomize", "Invert"},
    CurrentOption = {ScriptState.resolverMethod},
    Flag = "resolverMethodDropdown",
    Callback = function(option)
        ScriptState.resolverMethod = option[1]
    end,
}, AntiLockSection)

-- Desync Section
local DesyncSection = MainTab:CreateSection("Desync Settings")

Rayfield:CreateToggle({
    Name = "Enable Desync",
    CurrentValue = ScriptState.Desync,
    Flag = "desyncToggle",
    Callback = function(value)
        ScriptState.Desync = value
    end,
}, DesyncSection)

Rayfield:CreateSlider({
    Name = "Desync Intensity",
    MinValue = 1,
    MaxValue = 20,
    Increment = 1,
    Suffix = "",
    CurrentValue = ScriptState.reverseResolveIntensity,
    Flag = "desyncIntensitySlider",
    Callback = function(value)
        ScriptState.reverseResolveIntensity = value
    end,
}, DesyncSection)

-- ===========================
-- SILENT AIM TAB
-- ===========================

local SilentAimTab = Window:CreateTab("Silent Aim", 4483362458)
local SilentAimSection = SilentAimTab:CreateSection("Silent Aim Configuration")

Rayfield:CreateToggle({
    Name = "Enable Silent Aim",
    CurrentValue = SilentAimSettings.Enabled,
    Flag = "silentAimToggle",
    Callback = function(value)
        SilentAimSettings.Enabled = value
    end,
}, SilentAimSection)

Rayfield:CreateToggle({
    Name = "Team Check",
    CurrentValue = SilentAimSettings.TeamCheck,
    Flag = "silentAimTeamCheck",
    Callback = function(value)
        SilentAimSettings.TeamCheck = value
    end,
}, SilentAimSection)

Rayfield:CreateToggle({
    Name = "Visible Check",
    CurrentValue = SilentAimSettings.VisibleCheck,
    Flag = "silentAimVisibleCheck",
    Callback = function(value)
        SilentAimSettings.VisibleCheck = value
    end,
}, SilentAimSection)

Rayfield:CreateToggle({
    Name = "Alive Check",
    CurrentValue = SilentAimSettings.AliveCheck,
    Flag = "silentAimAliveCheck",
    Callback = function(value)
        SilentAimSettings.AliveCheck = value
    end,
}, SilentAimSection)

Rayfield:CreateToggle({
    Name = "Bullet Teleport",
    CurrentValue = SilentAimSettings.BulletTP,
    Flag = "silentAimBulletTP",
    Callback = function(value)
        SilentAimSettings.BulletTP = value
    end,
}, SilentAimSection)

Rayfield:CreateToggle({
    Name = "Check For Fire Function",
    CurrentValue = SilentAimSettings.CheckForFireFunc,
    Flag = "silentAimCheckFire",
    Callback = function(value)
        SilentAimSettings.CheckForFireFunc = value
    end,
}, SilentAimSection)

Rayfield:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "Random", "UpperTorso", "LowerTorso"},
    CurrentOption = {SilentAimSettings.TargetPart},
    Flag = "silentAimTargetPart",
    Callback = function(option)
        SilentAimSettings.TargetPart = option[1]
    end,
}, SilentAimSection)

Rayfield:CreateDropdown({
    Name = "Silent Aim Method",
    Options = {"ViewportPointToRay", "ScreenPointToRay", "Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "CounterBlox"},
    CurrentOption = {SilentAimSettings.SilentAimMethod},
    Flag = "silentAimMethod",
    Callback = function(option)
        SilentAimSettings.SilentAimMethod = option[1]
    end,
}, SilentAimSection)

local FOVSection = SilentAimTab:CreateSection("FOV Settings")

Rayfield:CreateSlider({
    Name = "FOV Radius",
    MinValue = 0,
    MaxValue = 500,
    Increment = 10,
    Suffix = "",
    CurrentValue = SilentAimSettings.FOVRadius,
    Flag = "fovRadiusSlider",
    Callback = function(value)
        SilentAimSettings.FOVRadius = value
        fov_circle.Radius = value
    end,
}, FOVSection)

Rayfield:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = SilentAimSettings.FOVVisible,
    Flag = "showFOVCircle",
    Callback = function(value)
        SilentAimSettings.FOVVisible = value
        fov_circle.Visible = value
    end,
}, FOVSection)

Rayfield:CreateColor({
    Name = "FOV Color",
    CurrentColor = fov_circle.Color,
    Flag = "fovColorPicker",
    Callback = function(value)
        fov_circle.Color = value
    end,
}, FOVSection)

Rayfield:CreateDropdown({
    Name = "FOV Origin",
    Options = {"Mouse", "Center"},
    CurrentOption = {ScriptState.fovMode},
    Flag = "fovModeDropdown",
    Callback = function(option)
        ScriptState.fovMode = option[1]
    end,
}, FOVSection)

local SilentAimAdvSection = SilentAimTab:CreateSection("Advanced Settings")

Rayfield:CreateSlider({
    Name = "Hit Chance",
    MinValue = 0,
    MaxValue = 100,
    Increment = 1,
    Suffix = "%",
    CurrentValue = SilentAimSettings.HitChance,
    Flag = "hitChanceSlider",
    Callback = function(value)
        SilentAimSettings.HitChance = value
    end,
}, SilentAimAdvSection)

Rayfield:CreateSlider({
    Name = "Multiply Unit By",
    MinValue = 1,
    MaxValue = 10000,
    Increment = 100,
    Suffix = "",
    CurrentValue = SilentAimSettings.MultiplyUnitBy,
    Flag = "multiplyUnitSlider",
    Callback = function(value)
        SilentAimSettings.MultiplyUnitBy = value
    end,
}, SilentAimAdvSection)

Rayfield:CreateToggle({
    Name = "Show Silent Aim Target",
    CurrentValue = SilentAimSettings.ShowSilentAimTarget,
    Flag = "showSilentAimTarget",
    Callback = function(value)
        SilentAimSettings.ShowSilentAimTarget = value
    end,
}, SilentAimAdvSection)

-- ===========================
-- VISUALS TAB
-- ===========================

local VisualsTab = Window:CreateTab("Visuals", 4483362458)

local WorldSection = VisualsTab:CreateSection("World Settings")

Rayfield:CreateSlider({
    Name = "Clock Time",
    MinValue = 0,
    MaxValue = 24,
    Increment = 0.5,
    Suffix = "",
    CurrentValue = ScriptState.lockedTime,
    Flag = "clockTimeSlider",
    Callback = function(value)
        ScriptState.lockedTime = value
        if ScriptState.lockTimeEnabled then
            Services.Lighting.ClockTime = value
        end
    end,
}, WorldSection)

Rayfield:CreateToggle({
    Name = "Lock Time",
    CurrentValue = ScriptState.lockTimeEnabled,
    Flag = "lockTimeToggle",
    Callback = function(value)
        ScriptState.lockTimeEnabled = value
        if value then
            Services.Lighting.ClockTime = ScriptState.lockedTime
        end
    end,
}, WorldSection)

Rayfield:CreateSlider({
    Name = "Camera FOV",
    MinValue = 30,
    MaxValue = 120,
    Increment = 1,
    Suffix = "",
    CurrentValue = ScriptState.fovValue,
    Flag = "cameraFOVSlider",
    Callback = function(value)
        ScriptState.fovValue = value
    end,
}, WorldSection)

Rayfield:CreateToggle({
    Name = "Enable FOV Change",
    CurrentValue = ScriptState.fovEnabled,
    Flag = "fovChangeToggle",
    Callback = function(value)
        ScriptState.fovEnabled = value
    end,
}, WorldSection)

local SelfChamsSection = VisualsTab:CreateSection("Self Chams")

Rayfield:CreateToggle({
    Name = "Enable Self Chams",
    CurrentValue = ScriptState.SelfChamsEnabled,
    Flag = "selfChamsToggle",
    Callback = function(value)
        ScriptState.SelfChamsEnabled = value
        if value then
            if LocalPlayer.Character then
                applyChams(LocalPlayer.Character)
            end
        else
            restoreChams()
        end
    end,
}, SelfChamsSection)

Rayfield:CreateToggle({
    Name = "Rainbow Chams",
    CurrentValue = ScriptState.RainbowChamsEnabled,
    Flag = "rainbowChamsToggle",
    Callback = function(value)
        ScriptState.RainbowChamsEnabled = value
    end,
}, SelfChamsSection)

Rayfield:CreateColor({
    Name = "Self Chams Color",
    CurrentColor = ScriptState.SelfChamsColor,
    Flag = "selfChamsColorPicker",
    Callback = function(value)
        ScriptState.SelfChamsColor = value
    end,
}, SelfChamsSection)

local EnemyChamsSection = VisualsTab:CreateSection("Enemy Chams")

Rayfield:CreateToggle({
    Name = "Enable Enemy Chams",
    CurrentValue = ScriptState.ChamsEnabled,
    Flag = "enemyChamsToggle",
    Callback = function(value)
        ScriptState.ChamsEnabled = value
        for part, ad in pairs(AdornmentsCache) do
            ad[1].Visible = value
            ad[2].Visible = value
        end
    end,
}, EnemyChamsSection)

Rayfield:CreateColor({
    Name = "Chams Occluded Color",
    CurrentColor = ChamsOccludedColor[1],
    Flag = "chamsOccludedColorPicker",
    Callback = function(value)
        ChamsOccludedColor[1] = value
    end,
}, EnemyChamsSection)

Rayfield:CreateColor({
    Name = "Chams Visible Color",
    CurrentColor = ChamsVisibleColor[1],
    Flag = "chamsVisibleColorPicker",
    Callback = function(value)
        ChamsVisibleColor[1] = value
    end,
}, EnemyChamsSection)

Rayfield:CreateSlider({
    Name = "Occluded Transparency",
    MinValue = 0,
    MaxValue = 1,
    Increment = 0.05,
    Suffix = "",
    CurrentValue = ChamsOccludedColor[2],
    Flag = "chamsOccludedTransparencySlider",
    Callback = function(value)
        ChamsOccludedColor[2] = value
    end,
}, EnemyChamsSection)

Rayfield:CreateSlider({
    Name = "Visible Transparency",
    MinValue = 0,
    MaxValue = 1,
    Increment = 0.05,
    Suffix = "",
    CurrentValue = ChamsVisibleColor[2],
    Flag = "chamsVisibleTransparencySlider",
    Callback = function(value)
        ChamsVisibleColor[2] = value
    end,
}, EnemyChamsSection)

local SkyboxSection = VisualsTab:CreateSection("Skybox")

Rayfield:CreateDropdown({
    Name = "Select Skybox",
    Options = SkyboxNames,
    CurrentOption = {"Game's Default Sky"},
    Flag = "skyboxDropdown",
    Callback = function(option)
        if Skyboxes[option[1]] then
            Visuals:SwitchSkybox(option[1])
        end
    end,
}, SkyboxSection)

local NebulaSection = VisualsTab:CreateSection("Nebula Theme")

local nebulaThemeColor = Color3.fromRGB(173, 216, 230)
local originalAmbient, originalOutdoorAmbient = Lighting.Ambient, Lighting.OutdoorAmbient
local originalFogStart, originalFogEnd, originalFogColor = Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor

Rayfield:CreateToggle({
    Name = "Enable Nebula Theme",
    CurrentValue = ScriptState.nebulaEnabled,
    Flag = "nebulaThemeToggle",
    Callback = function(value)
        ScriptState.nebulaEnabled = value
        if value then
            local b = Instance.new("BloomEffect", Lighting)
            b.Intensity, b.Size, b.Threshold, b.Name = 0.7, 24, 1, "NebulaBloom"
            local c = Instance.new("ColorCorrectionEffect", Lighting)
            c.Saturation, c.Contrast, c.TintColor, c.Name = 0.5, 0.2, nebulaThemeColor, "NebulaColorCorrection"
            local a = Instance.new("Atmosphere", Lighting)
            a.Density, a.Offset, a.Glare, a.Haze, a.Color, a.Decay, a.Name = 0.4, 0.25, 1, 2, nebulaThemeColor, Color3.fromRGB(25, 25, 112), "NebulaAtmosphere"
            Lighting.Ambient, Lighting.OutdoorAmbient = nebulaThemeColor, nebulaThemeColor
            Lighting.FogStart, Lighting.FogEnd = 100, 500
            Lighting.FogColor = nebulaThemeColor
        else
            for _, v in pairs({"NebulaBloom", "NebulaColorCorrection", "NebulaAtmosphere"}) do
                local obj = Lighting:FindFirstChild(v)
                if obj then obj:Destroy() end
            end
            Lighting.Ambient, Lighting.OutdoorAmbient = originalAmbient, originalOutdoorAmbient
            Lighting.FogStart, Lighting.FogEnd = originalFogStart, originalFogEnd
            Lighting.FogColor = originalFogColor
        end
    end,
}, NebulaSection)

Rayfield:CreateColor({
    Name = "Nebula Color",
    CurrentColor = nebulaThemeColor,
    Flag = "nebulaColorPicker",
    Callback = function(value)
        nebulaThemeColor = value
        if ScriptState.nebulaEnabled then
            local nc = Lighting:FindFirstChild("NebulaColorCorrection")
            if nc then nc.TintColor = value end
            local na = Lighting:FindFirstChild("NebulaAtmosphere")
            if na then na.Color = value end
            Lighting.Ambient, Lighting.OutdoorAmbient = value, value
            Lighting.FogColor = value
        end
    end,
}, NebulaSection)

-- ===========================
-- MOVEMENT TAB
-- ===========================

local MovementTab = Window:CreateTab("Movement", 4483362458)

local SpeedSection = MovementTab:CreateSection("Speed")

Rayfield:CreateToggle({
    Name = "Enable Speed",
    CurrentValue = ScriptState.isSpeedActive,
    Flag = "speedToggle",
    Callback = function(value)
        ScriptState.isSpeedActive = value
    end,
}, SpeedSection)

Rayfield:CreateSlider({
    Name = "Speed Multiplier",
    MinValue = 1,
    MaxValue = 20,
    Increment = 0.5,
    Suffix = "x",
    CurrentValue = ScriptState.Cmultiplier,
    Flag = "speedMultiplierSlider",
    Callback = function(value)
        ScriptState.Cmultiplier = value
    end,
}, SpeedSection)

local FlySection = MovementTab:CreateSection("Flight")

Rayfield:CreateToggle({
    Name = "Enable Flight",
    CurrentValue = ScriptState.isFlyActive,
    Flag = "flyToggle",
    Callback = function(value)
        ScriptState.isFlyActive = value
    end,
}, FlySection)

Rayfield:CreateSlider({
    Name = "Flight Speed",
    MinValue = 1,
    MaxValue = 100,
    Increment = 1,
    Suffix = "",
    CurrentValue = ScriptState.flySpeed,
    Flag = "flySpeedSlider",
    Callback = function(value)
        ScriptState.flySpeed = value
    end,
}, FlySection)

local NoClipSection = MovementTab:CreateSection("NoClip")

Rayfield:CreateToggle({
    Name = "Enable NoClip",
    CurrentValue = ScriptState.isNoClipActive,
    Flag = "noClipToggle",
    Callback = function(value)
        ScriptState.isNoClipActive = value
    end,
}, NoClipSection)

local StrafeSection = MovementTab:CreateSection("Target Strafe")

Rayfield:CreateToggle({
    Name = "Enable Target Strafe",
    CurrentValue = ScriptState.strafeEnabled,
    Flag = "strafeToggle",
    Callback = function(value)
        ScriptState.strafeEnabled = value
        if value then
            startTargetStrafe()
        else
            stopTargetStrafe()
        end
    end,
}, StrafeSection)

Rayfield:CreateDropdown({
    Name = "Strafe Mode",
    Options = {"Horizontal", "UP"},
    CurrentOption = {ScriptState.strafeMode},
    Flag = "strafeModeDropdown",
    Callback = function(option)
        ScriptState.strafeMode = option[1]
    end,
}, StrafeSection)

Rayfield:CreateSlider({
    Name = "Strafe Radius",
    MinValue = 1,
    MaxValue = 50,
    Increment = 1,
    Suffix = "",
    CurrentValue = ScriptState.strafeRadius,
    Flag = "strafeRadiusSlider",
    Callback = function(value)
        ScriptState.strafeRadius = value
    end,
}, StrafeSection)

Rayfield:CreateSlider({
    Name = "Strafe Speed",
    MinValue = 10,
    MaxValue = 200,
    Increment = 5,
    Suffix = "",
    CurrentValue = ScriptState.strafeSpeed,
    Flag = "strafeSpeedSlider",
    Callback = function(value)
        ScriptState.strafeSpeed = value
    end,
}, StrafeSection)

-- ===========================
-- EXPLOITS TAB
-- ===========================

local ExploitsTab = Window:CreateTab("Exploits", 4483362458)

local ACSSection = ExploitsTab:CreateSection("ACS Engine Modifications")

Rayfield:CreateToggle({
    Name = "Apply to Weapon in Hands",
    CurrentValue = false,
    Flag = "weaponOnHands",
    Callback = function(value)
        getgenv().WeaponOnHands = value
    end,
}, ACSSection)

Rayfield:CreateDropdown({
    Name = "Weapon Modify Method",
    Options = {"Attribute", "Require"},
    CurrentOption = {"Attribute"},
    Flag = "weaponModifyMethod",
    Callback = function(option)
        getgenv().WeaponModifyMethod = option[1]
    end,
}, ACSSection)

Rayfield:CreateButton({
    Name = "INF AMMO",
    Callback = function()
        modifyWeaponSettings("Ammo", math.huge)
        Rayfield:Notify({Title = "Success", Content = "Infinite Ammo Applied", Duration = 2, Image = 4483362458})
    end,
}, ACSSection)

Rayfield:CreateButton({
    Name = "NO RECOIL | NO SPREAD",
    Callback = function()
        if getgenv().WeaponModifyMethod == "Attribute" then
            modifyWeaponSettings("VRecoil", Vector2.new(0, 0))
            modifyWeaponSettings("HRecoil", Vector2.new(0, 0))
        else
            modifyWeaponSettings("VRecoil", {0, 0})
            modifyWeaponSettings("HRecoil", {0, 0})
        end
        modifyWeaponSettings("MinSpread", 0)
        modifyWeaponSettings("MaxSpread", 0)
        modifyWeaponSettings("RecoilPunch", 0)
        modifyWeaponSettings("AimRecoilReduction", 0)
        Rayfield:Notify({Title = "Success", Content = "No Recoil/Spread Applied", Duration = 2, Image = 4483362458})
    end,
}, ACSSection)

Rayfield:CreateButton({
    Name = "INF BULLET DISTANCE",
    Callback = function()
        modifyWeaponSettings("Distance", 25000)
        Rayfield:Notify({Title = "Success", Content = "Infinite Distance Applied", Duration = 2, Image = 4483362458})
    end,
}, ACSSection)

Rayfield:CreateInput({
    Name = "Bullet Speed",
    CurrentValue = "10000",
    PlaceholderText = "Enter bullet speed",
    RemoveTextAfterFocusLost = false,
    Flag = "bulletSpeedInput",
    Callback = function(value)
        getgenv().bulletSpeedValue = tonumber(value) or 10000
    end,
}, ACSSection)

Rayfield:CreateButton({
    Name = "CHANGE BULLET SPEED",
    Callback = function()
        modifyWeaponSettings("BSpeed", getgenv().bulletSpeedValue or 10000)
        modifyWeaponSettings("MuzzleVelocity", getgenv().bulletSpeedValue or 10000)
        Rayfield:Notify({Title = "Success", Content = "Bullet Speed Changed", Duration = 2, Image = 4483362458})
    end,
}, ACSSection)

Rayfield:CreateInput({
    Name = "Fire Rate",
    CurrentValue = "8888",
    PlaceholderText = "Enter fire rate",
    RemoveTextAfterFocusLost = false,
    Flag = "fireRateInput",
    Callback = function(value)
        local rate = tonumber(value) or 8888
        modifyWeaponSettings("FireRate", rate)
        modifyWeaponSettings("ShootRate", rate)
    end,
}, ACSSection)

Rayfield:CreateInput({
    Name = "Multi Bullets",
    CurrentValue = "50",
    PlaceholderText = "Enter number of bullets",
    RemoveTextAfterFocusLost = false,
    Flag = "bulletsInput",
    Callback = function(value)
        local bulletsValue = tonumber(value) or 50
        modifyWeaponSettings("Bullets", bulletsValue)
    end,
}, ACSSection)

Rayfield:CreateInput({
    Name = "Fire Mode",
    CurrentValue = "Auto",
    PlaceholderText = "Enter fire mode",
    RemoveTextAfterFocusLost = false,
    Flag = "fireModeInput",
    Callback = function(value)
        modifyWeaponSettings("Mode", value or "Auto")
    end,
}, ACSSection)

local HitSoundSection = ExploitsTab:CreateSection("HitSound Settings")

Rayfield:CreateToggle({
    Name = "Enable HitSound",
    CurrentValue = HitSoundEnabled,
    Flag = "hitSoundToggle",
    Callback = function(value)
        HitSoundEnabled = value
    end,
}, HitSoundSection)

Rayfield:CreateDropdown({
    Name = "Select HitSound",
    Options = {"RIFK7", "Bubble", "Minecraft", "Cod", "Bameware", "Neverlose", "Gamesense", "Rust"},
    CurrentOption = {"Neverlose"},
    Flag = "hitSoundDropdown",
    Callback = function(option)
        CurrentHitSound = option[1]
        local id = sounds[option[1]]
        if id then
            hitSound.SoundId = id
        end
    end,
}, HitSoundSection)

-- ===========================
-- SETTINGS TAB
-- ===========================

local SettingsTab = Window:CreateTab("Settings", 4483362458)
local GeneralSettings = SettingsTab:CreateSection("General Settings")

Rayfield:CreateButton({
    Name = "Unload Script",
    Callback = function()
        print("[PasteWare] Script unloading...")
        Window:Close()
    end,
}, GeneralSettings)

Rayfield:CreateLabel("PasteWare v2 - Rayfield Edition")
Rayfield:CreateLabel("Converted by: github.com/FakeAngles")
Rayfield:CreateLabel("UI Framework: Rayfield")

-- ===========================
-- MAIN MOVEMENT LOOP
-- ===========================

local humanoid = nil

while true do
    task.wait()
    
    if ScriptState.isSpeedActive or ScriptState.isFlyActive or ScriptState.isNoClipActive then
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        
        if character and rootPart then
            humanoid = character:FindFirstChild("Humanoid")
            
            if ScriptState.isSpeedActive and humanoid and humanoid.MoveDirection.Magnitude > 0 then
                local moveDirection = humanoid.MoveDirection.Unit
                rootPart.CFrame = rootPart.CFrame + moveDirection * ScriptState.Cmultiplier
            end
            
            if ScriptState.isFlyActive then
                local flyDirection = Vector3.zero
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    flyDirection = flyDirection + Camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    flyDirection = flyDirection - Camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    flyDirection = flyDirection - Camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    flyDirection = flyDirection + Camera.CFrame.RightVector
                end
                
                if flyDirection.Magnitude > 0 then
                    flyDirection = flyDirection.Unit
                end
                
                local newPosition = rootPart.Position + flyDirection * ScriptState.flySpeed
                rootPart.CFrame = CFrame.new(newPosition)
                rootPart.Velocity = Vector3.new(0, 0, 0)
            end
            
            if ScriptState.isNoClipActive then
                for _, v in pairs(character:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then
                        v.CanCollide = false
                    end
                end
            end
        end
    end
    
    if SilentAimSettings.FOVVisible then
        fov_circle.Position = getFovOrigin()
    end
    
    if ScriptState.fovEnabled then
        Camera.FieldOfView = ScriptState.fovValue
    end
end