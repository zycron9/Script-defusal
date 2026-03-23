local UIS = game:GetService("UserInputService")
if UIS.TouchEnabled and not UIS.MouseEnabled and not UIS.KeyboardEnabled then
    getgenv().bypass_adonis = true
    loadstring(game:HttpGet('https://raw.githubusercontent.com/FakeAngles/PasteWare-v2/refs/heads/main/PasteWareV2LegacyMobile.lua'))() return
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

if not syn or not protectgui then
    getgenv().protectgui = function() end
end

if bypass_adonis then
    task.spawn(function()
        local g = getinfo or debug.getinfo
        local d = false
        local h = {}
        local x, y
        setthreadidentity(2)
        for i, v in getgc(true) do
            if typeof(v) == "table" then
                local a = rawget(v, "Detected")
                local b = rawget(v, "Kill")

                if typeof(a) == "function" and not x then
                    x = a
                    local o; o = hookfunction(x, function(c, f, n)
                        if c ~= "_" then
                            if d then
                            end
                        end
                        return true
                    end)
                    table.insert(h, x)
                end

                if rawget(v, "Variables") and rawget(v, "Process") and typeof(b) == "function" and not y then
                    y = b
                    local o; o = hookfunction(y, function(f)
                        if d then
                        end
                    end)
                    table.insert(h, y)
                end
            end
        end
        local o; o = hookfunction(getrenv().debug.info, newcclosure(function(...)
            local a, f = ...
            if x and a == x then
                return coroutine.yield(coroutine.running())
            end
            return o(...)
        end))
        setthreadidentity(7)
    end)
end

if not getgenv().ScriptState then
    getgenv().ScriptState = {
        isLockedOn = false,
        targetPlayer = nil,
        lockEnabled = false,
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
    ViewportPointToRay = {
        ArgCountRequired = 2,
        Args = { "number", "number" }
    },
    ScreenPointToRay = {
        ArgCountRequired = 2,
        Args = { "number", "number" }
    },
    Raycast = {
        ArgCountRequired = 3,
        Args = { "Instance", "Vector3", "Vector3", "RaycastParams" }
    },
    FindPartOnRay = {
        ArgCountRequired = 2,
        Args = { "Ray", "Instance?", "boolean?", "boolean?" }
    },
    FindPartOnRayWithIgnoreList = {
        ArgCountRequired = 2,
        Args = { "Ray", "table", "boolean?", "boolean?" }
    },
    FindPartOnRayWithWhitelist = {
        ArgCountRequired = 2,
        Args = { "Ray", "table", "boolean?" }
    }
}

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
        if not Expected then
            break
        end

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
    if not player then
        return false
    end

    local option = getTeamComparisonOption()
    if option then
        local okLocal, localValue = pcall(function()
            return LocalPlayer[option]
        end)
        local okTarget, targetValue = pcall(function()
            return player[option]
        end)

        if okLocal and okTarget and localValue ~= nil and targetValue ~= nil then
            return targetValue == localValue
        end
    end

    local okLocalTeam, localTeam = pcall(function()
        return LocalPlayer.Team
    end)
    local okTargetTeam, targetTeam = pcall(function()
        return player.Team
    end)

    if okLocalTeam and okTargetTeam and localTeam and targetTeam then
        return targetTeam == localTeam
    end

    local okLocalColor, localColor = pcall(function()
        return LocalPlayer.TeamColor
    end)
    local okTargetColor, targetColor = pcall(function()
        return player.TeamColor
    end)

    if okLocalColor and okTargetColor and localColor and targetColor then
        return targetColor == localColor
    end

    return false
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player and Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character

    if not (PlayerCharacter and LocalPlayerCharacter) then
        return false
    end

    local targetPartOption = SilentAimSettings.TargetPart or "HumanoidRootPart"
    local PlayerRoot = FindFirstChild(PlayerCharacter, targetPartOption) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")

    if not PlayerRoot then
        return false
    end

    local CastPoints, IgnoreList = { PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter }, { LocalPlayerCharacter, PlayerCharacter }
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)

    return ObscuringObjects == 0
end

local function normalizeSelection(selection)
    if not selection then
        return {}
    end

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

local function getClosestPlayer(config)
    config = config or {}

    local targetPartOption = config.targetPart or SilentAimSettings.TargetPart
    if not targetPartOption then
        return nil, nil
    end

    local ignoredPlayers = config.ignoredPlayers
    local radiusOption = config.radius or SilentAimSettings.FOVRadius or 2000
    local visibleCheck = config.visibleCheck
    if visibleCheck == nil then
        visibleCheck = SilentAimSettings.VisibleCheck
    end
    local aliveCheck = config.aliveCheck
    if aliveCheck == nil then
        aliveCheck = SilentAimSettings.AliveCheck
    end
    local teamCheck = config.teamCheck
    if teamCheck == nil then
        local silentAimTeamCheck = SilentAimSettings.TeamCheck
        local aimLockTeamCheck = ScriptState and ScriptState.aimLockTeamCheck
        teamCheck = silentAimTeamCheck or aimLockTeamCheck or false
    end

    local teamEvaluator = config.teamEvaluator
    if type(teamEvaluator) ~= "function" then
        teamEvaluator = playersOnSameTeam
    end

    local originPosition = config.origin
    if typeof(originPosition) == "function" then
        originPosition = originPosition()
    end
    originPosition = originPosition or getFovOrigin()

    local ClosestPart
    local ClosestPlayer
    local DistanceToMouse

    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then
            continue
        end

        if ignoredPlayers and ignoredPlayers[Player.Name] then
            continue
        end

        if teamCheck and teamEvaluator(Player) then
            continue
        end

        if visibleCheck and not IsPlayerVisible(Player) then
            continue
        end

        local Character = Player.Character
        if not Character then
            continue
        end

        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")

        if not HumanoidRootPart or not Humanoid then
            continue
        end

        if aliveCheck and Humanoid.Health <= 0 then
            continue
        end

        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)
        if not OnScreen then
            continue
        end

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
    if player and player ~= LocalPlayer then
        return player
    end

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

-- Load Rayfield Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "PasteWare | github.com/FakeAngles",
    LoadingTitle = "PasteWare v2",
    LoadingSubtitle = "by FakeAngles",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "PasteWare",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink"
    },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", 4483362458)
local AimLockSection = MainTab:CreateSection("AimLock")

MainTab:CreateToggle({
    Name = "AimLock",
    CurrentValue = false,
    Flag = "aimLockToggle",
    Callback = function(Value)
        toggleLockOnPlayer(Value)
    end,
}):AddKeyPicker("AimLockKey", {Callback = function(Key)
    toggleLockOnPlayer(not ScriptState.lockEnabled)
end})

MainTab:CreateSlider({
    Name = "Camera Smoothing",
    Min = 0,
    Max = 1,
    Increment = 0.01,
    CurrentValue = 0.1,
    Flag = "SmoothingSlider",
    Callback = function(Value)
        ScriptState.smoothingFactor = Value
    end,
})

MainTab:CreateSlider({
    Name = "Prediction Factor",
    Min = 0,
    Max = 2,
    Increment = 0.01,
    CurrentValue = 0.0,
    Flag = "PredictionSlider",
    Callback = function(Value)
        ScriptState.predictionFactor = Value
    end,
})

MainTab:CreateToggle({
    Name = "Visible Check",
    CurrentValue = false,
    Flag = "aimLockVisibleCheck",
    Callback = function(Value)
        ScriptState.aimLockVisibleCheck = Value
    end,
})

MainTab:CreateToggle({
    Name = "Alive Check",
    CurrentValue = false,
    Flag = "aimLockAliveCheck",
    Callback = function(Value)
        ScriptState.aimLockAliveCheck = Value
    end,
})

MainTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "aimLockTeamCheck",
    Callback = function(Value)
        ScriptState.aimLockTeamCheck = Value
        if Value and ScriptState.lockEnabled and ScriptState.targetPlayer and ScriptState.targetPlayer.Team == LocalPlayer.Team then
            acquireLockTarget()
        end
    end,
})

MainTab:CreateDropdown({
    Name = "Target Body Part",
    Options = {"Head", "UpperTorso", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftUpperArm"},
    CurrentOption = {"Head"},
    MultipleOptions = false,
    Flag = "BodyPartSelect",
    Callback = function(Options)
        ScriptState.bodyPartSelected = Options[1]
    end,
})

local AntiLockSection = MainTab:CreateSection("Anti Lock")

MainTab:CreateToggle({
    Name = "Anti Lock Resolver",
    CurrentValue = false,
    Flag = "antiLockToggle",
    Callback = function(Value)
        ScriptState.antiLockEnabled = Value
    end,
})

MainTab:CreateSlider({
    Name = "Resolver Intensity",
    Min = 0,
    Max = 5,
    Increment = 0.1,
    CurrentValue = 1.0,
    Flag = "ResolverIntensity",
    Callback = function(Value)
        ScriptState.resolverIntensity = Value
    end,
})

MainTab:CreateDropdown({
    Name = "Resolver Method",
    Options = {"Recalculate", "Randomize", "Invert"},
    CurrentOption = {"Recalculate"},
    MultipleOptions = false,
    Flag = "ResolverMethod",
    Callback = function(Options)
        ScriptState.resolverMethod = Options[1]
    end,
})

local VelocitySection = MainTab:CreateSection("Velocity Desync")

MainTab:CreateToggle({
    Name = "Desync",
    CurrentValue = false,
    Flag = "desyncToggle",
    Callback = function(Value)
        ScriptState.Desync = Value
    end,
}):AddKeyPicker("DesyncKey", {Callback = function(Key)
    ScriptState.Desync = not ScriptState.Desync
end})

MainTab:CreateSlider({
    Name = "Velocity Intensity",
    Min = 1,
    Max = 10,
    Increment = 1,
    CurrentValue = 5,
    Flag = "VelocityIntensity",
    Callback = function(Value)
        ScriptState.reverseResolveIntensity = Value
    end,
})

local SilentAimTab = Window:CreateTab("Silent Aim", 4483362458)
local SilentAimSection = SilentAimTab:CreateSection("Silent Aim Settings")

SilentAimTab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = false,
    Flag = "silentAimToggle",
    Callback = function(Value)
        SilentAimSettings.Enabled = Value
    end,
}):AddKeyPicker("SilentAimKey", {Callback = function(Key)
    SilentAimSettings.Enabled = not SilentAimSettings.Enabled
end})

SilentAimTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = false,
    Flag = "silentAimTeamCheck",
    Callback = function(Value)
        SilentAimSettings.TeamCheck = Value
    end,
})

SilentAimTab:CreateToggle({
    Name = "Visible Check",
    CurrentValue = false,
    Flag = "silentAimVisibleCheck",
    Callback = function(Value)
        SilentAimSettings.VisibleCheck = Value
    end,
})

SilentAimTab:CreateToggle({
    Name = "Alive Check",
    CurrentValue = false,
    Flag = "silentAimAliveCheck",
    Callback = function(Value)
        SilentAimSettings.AliveCheck = Value
    end,
})

SilentAimTab:CreateToggle({
    Name = "Bullet Teleport",
    CurrentValue = false,
    Flag = "bulletTP",
    Callback = function(Value)
        SilentAimSettings.BulletTP = Value
    end,
})

SilentAimTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "Random"},
    CurrentOption = {"HumanoidRootPart"},
    MultipleOptions = false,
    Flag = "silentAimTargetPart",
    Callback = function(Options)
        SilentAimSettings.TargetPart = Options[1]
    end,
})

SilentAimTab:CreateDropdown({
    Name = "Silent Aim Method",
    Options = {"ViewportPointToRay", "ScreenPointToRay", "Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "CounterBlox"},
    CurrentOption = {"Raycast"},
    MultipleOptions = false,
    Flag = "silentAimMethod",
    Callback = function(Options)
        SilentAimSettings.SilentAimMethod = Options[1]
    end,
})

SilentAimTab:CreateSlider({
    Name = "Hit Chance",
    Min = 0,
    Max = 100,
    Increment = 1,
    CurrentValue = 100,
    Flag = "hitChance",
    Callback = function(Value)
        SilentAimSettings.HitChance = Value
    end,
})

SilentAimTab:CreateSlider({
    Name = "Multiply Unit By",
    Min = 1,
    Max = 10000,
    Increment = 10,
    CurrentValue = 1000,
    Flag = "multiplyUnit",
    Callback = function(Value)
        SilentAimSettings.MultiplyUnitBy = Value
    end,
})

local FOVTab = Window:CreateTab("FOV", 4483362458)
local FOVSection = FOVTab:CreateSection("Field of View")

FOVTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = false,
    Flag = "showFOVCircle",
    Callback = function(Value)
        fov_circle.Visible = Value
        SilentAimSettings.FOVVisible = Value
    end,
})

FOVTab:CreateSlider({
    Name = "FOV Circle Radius",
    Min = 0,
    Max = 360,
    Increment = 5,
    CurrentValue = 130,
    Flag = "fovRadius",
    Callback = function(Value)
        fov_circle.Radius = Value
        SilentAimSettings.FOVRadius = Value
    end,
})

FOVTab:CreateDropdown({
    Name = "FOV Origin",
    Options = {"Mouse", "Center"},
    CurrentOption = {"Mouse"},
    MultipleOptions = false,
    Flag = "fovMode",
    Callback = function(Options)
        ScriptState.fovMode = Options[1]
    end,
})

FOVTab:CreateToggle({
    Name = "Show Silent Aim Target",
    CurrentValue = false,
    Flag = "showSilentAimTarget",
    Callback = function(Value)
        SilentAimSettings.ShowSilentAimTarget = Value
    end,
})

local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local WorldSection = VisualsTab:CreateSection("World")

local lighting = Services.Lighting
local originalAmbient, originalOutdoorAmbient = lighting.Ambient, lighting.OutdoorAmbient
local originalFogStart, originalFogEnd, originalFogColor = lighting.FogStart, lighting.FogEnd, lighting.FogColor

VisualsTab:CreateSlider({
    Name = "Clock Time",
    Min = 0,
    Max = 24,
    Increment = 0.5,
    CurrentValue = 12,
    Flag = "clockTime",
    Callback = function(Value)
        ScriptState.lockedTime = Value
        if ScriptState.lockTimeEnabled then
            lighting.ClockTime = Value
        end
    end,
})

VisualsTab:CreateToggle({
    Name = "Lock Time",
    CurrentValue = false,
    Flag = "lockTime",
    Callback = function(Value)
        ScriptState.lockTimeEnabled = Value
        if Value then
            lighting.ClockTime = ScriptState.lockedTime
        end
    end,
})

VisualsTab:CreateSlider({
    Name = "FOV",
    Min = 30,
    Max = 120,
    Increment = 1,
    CurrentValue = 70,
    Flag = "fovValue",
    Callback = function(Value)
        ScriptState.fovValue = Value
    end,
})

VisualsTab:CreateToggle({
    Name = "FOV Change",
    CurrentValue = false,
    Flag = "fovToggle",
    Callback = function(Value)
        ScriptState.fovEnabled = Value
    end,
})

local chamsSection = VisualsTab:CreateSection("Chams")

VisualsTab:CreateToggle({
    Name = "Self Chams",
    CurrentValue = false,
    Flag = "selfChams",
    Callback = function(Value)
        ScriptState.SelfChamsEnabled = Value
    end,
})

VisualsTab:CreateToggle({
    Name = "Rainbow Chams",
    CurrentValue = false,
    Flag = "rainbowChams",
    Callback = function(Value)
        ScriptState.RainbowChamsEnabled = Value
    end,
})

VisualsTab:CreateColorPicker({
    Name = "Self Chams Color",
    Color3 = Color3.fromRGB(255, 255, 255),
    Flag = "selfChamsColor",
    Callback = function(Value)
        ScriptState.SelfChamsColor = Value
    end
})

local MovementTab = Window:CreateTab("Movement", 4483362458)
local SpeedSection = MovementTab:CreateSection("Speed")

MovementTab:CreateToggle({
    Name = "Speed",
    CurrentValue = false,
    Flag = "speedToggle",
    Callback = function(Value)
        ScriptState.isSpeedActive = Value
    end,
}):AddKeyPicker("SpeedKey", {Callback = function(Key)
    ScriptState.isSpeedActive = not ScriptState.isSpeedActive
end})

MovementTab:CreateSlider({
    Name = "Speed Multiplier",
    Min = 1,
    Max = 20,
    Increment = 1,
    CurrentValue = 1,
    Flag = "speedMultiplier",
    Callback = function(Value)
        ScriptState.Cmultiplier = Value
    end,
})

local FlySection = MovementTab:CreateSection("Flight")

MovementTab:CreateToggle({
    Name = "Flight",
    CurrentValue = false,
    Flag = "flyToggle",
    Callback = function(Value)
        ScriptState.isFlyActive = Value
    end,
}):AddKeyPicker("FlyKey", {Callback = function(Key)
    ScriptState.isFlyActive = not ScriptState.isFlyActive
end})

MovementTab:CreateSlider({
    Name = "Flight Speed",
    Min = 1,
    Max = 50,
    Increment = 1,
    CurrentValue = 1,
    Flag = "flySpeed",
    Callback = function(Value)
        ScriptState.flySpeed = Value
    end,
})

local NoclipSection = MovementTab:CreateSection("NoClip")

MovementTab:CreateToggle({
    Name = "NoClip",
    CurrentValue = false,
    Flag = "noClipToggle",
    Callback = function(Value)
        ScriptState.isNoClipActive = Value
    end,
}):AddKeyPicker("NoClipKey", {Callback = function(Key)
    ScriptState.isNoClipActive = not ScriptState.isNoClipActive
end})

local WeaponTab = Window:CreateTab("Weapon", 4483362458)
local WeaponSection = WeaponTab:CreateSection("ACS Engine")

local function findSettingsModuleForWeapon(weapon, property)
    if not (weapon and weapon:IsA("Tool")) then
        return nil
    end

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
        if not (weapon and weapon:IsA("Tool")) then
            return
        end

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

WeaponTab:CreateToggle({
    Name = "Weapon In Hands",
    CurrentValue = false,
    Flag = "weaponInHands",
    Callback = function(Value)
        getgenv().WeaponOnHands = Value
    end,
})

WeaponTab:CreateDropdown({
    Name = "Weapon Modify Method",
    Options = {"Attribute", "Require"},
    CurrentOption = {"Attribute"},
    MultipleOptions = false,
    Flag = "weaponModifyMethod",
    Callback = function(Options)
        getgenv().WeaponModifyMethod = Options[1]
    end,
})

WeaponTab:CreateButton({
    Name = "Infinite Ammo",
    Callback = function()
        modifyWeaponSettings("Ammo", math.huge)
    end,
})

WeaponTab:CreateButton({
    Name = "No Recoil | No Spread",
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
    end,
})

WeaponTab:CreateButton({
    Name = "Infinite Bullet Distance",
    Callback = function()
        modifyWeaponSettings("Distance", 25000)
    end,
})

WeaponTab:CreateInput({
    Name = "Bullet Speed",
    PlaceholderText = "10000",
    RemoveTextMarginCharacters = false,
    Flag = "bulletSpeedInput",
    Callback = function(Text)
        getgenv().bulletSpeedValue = tonumber(Text) or 10000
    end,
})

WeaponTab:CreateButton({
    Name = "Change Bullet Speed",
    Callback = function()
        modifyWeaponSettings("BSpeed", getgenv().bulletSpeedValue or 10000)
        modifyWeaponSettings("MuzzleVelocity", getgenv().bulletSpeedValue or 10000)
    end,
})

WeaponTab:CreateInput({
    Name = "Fire Rate",
    PlaceholderText = "8888",
    RemoveTextMarginCharacters = false,
    Flag = "fireRateInput",
    Callback = function(Text)
        getgenv().fireRateValue = tonumber(Text) or 8888
    end,
})

WeaponTab:CreateButton({
    Name = "Change Fire Rate",
    Callback = function()
        local rate = getgenv().fireRateValue or 8888
        modifyWeaponSettings("FireRate", rate)
        modifyWeaponSettings("ShootRate", rate)
    end,
})

WeaponTab:CreateInput({
    Name = "Bullets Count",
    PlaceholderText = "50",
    RemoveTextMarginCharacters = false,
    Flag = "bulletsInput",
    Callback = function(Text)
        getgenv().bulletsValue = tonumber(Text) or 50
    end,
})

WeaponTab:CreateButton({
    Name = "Multi Bullets",
    Callback = function()
        modifyWeaponSettings("Bullets", getgenv().bulletsValue or 50)
    end,
})

WeaponTab:CreateInput({
    Name = "Fire Mode",
    PlaceholderText = "Auto",
    RemoveTextMarginCharacters = false,
    Flag = "fireModeInput",
    Callback = function(Text)
        getgenv().fireModeValue = Text or "Auto"
    end,
})

WeaponTab:CreateButton({
    Name = "Change Fire Mode",
    Callback = function()
        modifyWeaponSettings("Mode", getgenv().fireModeValue or "Auto")
    end,
})

-- Hit Sound
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

local HitSoundTab = Window:CreateTab("HitSound", 4483362458)
local HitSoundSection = HitSoundTab:CreateSection("HitSound [Beta]")

HitSoundTab:CreateToggle({
    Name = "Enable HitSound",
    CurrentValue = false,
    Flag = "hitSoundToggle",
    Callback = function(Value)
        -- HitSound logic
    end,
})

HitSoundTab:CreateDropdown({
    Name = "HitSound Select",
    Options = {"RIFK7","Bubble","Minecraft","Cod","Bameware","Neverlose","Gamesense","Rust"},
    CurrentOption = {"Neverlose"},
    MultipleOptions = false,
    Flag = "hitSoundSelect",
    Callback = function(Options)
        local id = sounds[Options[1]]
        if id then
            hitSound.SoundId = id
        end
    end,
})

hitSound.SoundId = sounds["Neverlose"]

-- Core Loops
RunService.Heartbeat:Connect(function()
    if getgenv().ScriptState.Desync then
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

RunService.RenderStepped:Connect(function()
    if ScriptState.fovEnabled then
        Camera.FieldOfView = ScriptState.fovValue
    end
end)

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method, Arguments = getnamecallmethod(), {...}
    local self, chance = Arguments[1], CalculateChance(SilentAimSettings.HitChance)

    local BlockedMethods = SilentAimSettings.BlockedMethods or {}
    if Method == "Destroy" and self == Client then
        return
    end
    if BlockedMethods[Method] then
        return
    end

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
end

Rayfield:Notify({
    Title = "PasteWare Loaded",
    Content = "PasteWare v2 with Rayfield UI loaded successfully!",
    Duration = 6.5,
    Image = 4483362458,
})