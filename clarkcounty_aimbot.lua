--[[
    getgenv().Settings = {
        Redirect = {Chance = 100}, -- set to 0 to disable
        Weapon = {Recoil = 0, Spread = 0} -- set to -1 to disable
    }
    
    loadstring(game:HttpGet('https://raw.githubusercontent.com/bytism/scripts/main/clarkcounty_aimbot.lua'))()
]]

if Settings and Settings.Loaded then return end
Settings.Loaded = true

local FastFlag = getfflag('DebugRunParallelLuaOnMainThread')

if FastFlag == 'false' then
    setfflag('DebugRunParallelLuaOnMainThread', 'True')
    game:GetService('TeleportService'):TeleportToPlaceInstance(game.PlaceId, game.JobId)
    return
end

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local RaycastParams = RaycastParams.new()
RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character or nil, CollectionService:GetTagged('Glass')}

local Limbs = {'Head', 'Torso', 'Left Arm', 'Right Arm', 'Left Leg', 'Right Leg'}

local Tools = nil
local Target, TargetLimb = nil, nil

function DeepCopy(Original)
    if type(Original) ~= 'table' then return Original end
    
    local Copy = {}
    
    for Index, Value in pairs(Original) do
        if type(Value) == 'table' then
            Value = DeepCopy(Value)
        end
        
        Copy[Index] = Value
    end
    
    return Copy
end

function AddDrawing(Type, Properties)
    local DrawingObject = Drawing.new(Type)

    for Property, Value in pairs(Properties) do
        DrawingObject[Property] = Value
    end

    return DrawingObject
end

function GetClosest()
    local ClosestPlayer, ClosestLimb, ClosestDistance = nil, nil, math.huge
    local MouseLocation = UserInputService:GetMouseLocation()

    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end

        local PlayerRoot = Player.Character and Player.Character:FindFirstChild('HumanoidRootPart')
        if not PlayerRoot then continue end

        local PlayerHumanoid = Player.Character:FindFirstChild('Humanoid')
        if not PlayerHumanoid or PlayerHumanoid.Health < 0 then continue end

        for _, Limb in pairs(Player.Character:GetChildren()) do
            if not table.find(Limbs, Limb.Name) then continue end

            local Vector, OnScreen = Camera:WorldToScreenPoint(Limb.Position)
            if not OnScreen then continue end

            local MouseDistance = (Vector2.new(Vector.X, Vector.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
            if MouseDistance > 180 then continue end
            if MouseDistance > ClosestDistance then continue end

            ClosestPlayer = Player
            ClosestLimb = Limb
            ClosestDistance = MouseDistance
        end
    end

    return ClosestPlayer, ClosestLimb, ClosestDistance
end

function IsVisible(Part)
    local function GetBarrel()
        local Tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA('Configuration')
        if not Tool or not Tool:FindFirstChild('Barrel') then return false end
        return Tool.Barrel
    end

    local Barrel = GetBarrel()

    local Vector, OnScreen = Camera:WorldToScreenPoint(Part.Position)
    if not OnScreen then return false end

    local Origin = Barrel and Barrel.CFrame.Position or Camera.CFrame.Position
    local Direction = (Part.Position - Origin).Unit * (Part.Position - Origin).Magnitude

    local Raycast = workspace:Raycast(Origin, Direction, RaycastParams)
    if not Raycast.Instance:IsDescendantOf(Part.Parent) then return false end
    
    return true
end

function GetModule(Name)
    for _, Module in pairs(getloadedmodules()) do
        if Module.Name == Name then return Module end
    end

    return false
end

local Indicator = AddDrawing('Text', {
    Text = 'Target: None', Font = 3, Visible = true, Center = true, Outline = true,
    Color = Color3.new(1, 1, 1), OutlineColor = Color3.new(0, 0, 0)
})

local FovCircle = AddDrawing('Circle', {Visible = true, Radius = 180, Thickness = 1.5, Color = Color3.new(1, 1, 1), ZIndex = 4})
local FovOutlineCircle = AddDrawing('Circle', {Visible = true, Radius = 180, Thickness = 3.5, Color = Color3.new(0, 0, 0), ZIndex = 3})

Tools = DeepCopy(require(ReplicatedStorage.Databases.Tools))

RunService.Heartbeat:Connect(function()
    local Player, Limb = GetClosest()
    if not Player then
        Target = nil; Indicator.Text = 'None'; Indicator.Color = Color3.new(1, 1, 1)
        return
    end
    
    local Head = Player.Character and Player.Character:FindFirstChild('Head')
    if not Head then
        Target = nil; Indicator.Text = 'None'; Indicator.Color = Color3.new(1, 1, 1)
        return
    end

    Target = Player; TargetLimb = Limb

    local Visible = IsVisible(Head)
    Indicator.Text = string.format('%s; %s', Player.Name, Limb.Name)
    Indicator.Color = Visible and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
end)

RunService.RenderStepped:Connect(function()
    MouseLocation = UserInputService:GetMouseLocation()

    FovOutlineCircle.Position = MouseLocation; FovCircle.Position = MouseLocation
    Indicator.Position = FovCircle.Position + Vector2.new(0, 185)
end)

CollectionService:GetInstanceAddedSignal('Glass'):Connect(function()
    RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character or nil, CollectionService:GetTagged('Glass')}
end)

local Firearm = GetModule('Firearm')
local Required = require(Firearm)
local OldFire; OldFire = hookfunction(Required.Fire, function(Data, Mouse)
    Data.ToolTable.Recoil = Settings.Weapon.Recoil ~= -1 and Settings.Weapon.Recoil or Tools[Data.ToolTable.Asset].Recoil
    Data.ToolTable.Spread = Settings.Weapon.Spread ~= -1 and Settings.Weapon.Spread or Tools[Data.ToolTable.Asset].Spread

    if math.random(100) >= Settings.Redirect.Chance then return OldFire(Data, Mouse) end
    if not Target then return OldFire(Data, Mouse) end

    if not TargetLimb or not IsVisible(TargetLimb) then return OldFire(Data, Mouse) end

    return OldFire(Data, {Hit = {p = TargetLimb.Position}, Target = TargetLimb})
end)
