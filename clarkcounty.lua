--[[
    getgenv().Settings = {
        Redirect = {Chance = 100},
        Weapon = {Recoil = 0, Spread = 0}
    }
    
    loadstring(game:HttpGet('https://raw.githubusercontent.com/bytism/scripts/main/clarkcounty.lua'))()

    a good legit chance % is ~10 with decent aim
    adding get closest visible limb (from mouse) for hit part soon and toggles for weapon and redirect, that restores weapon mods to original state
    skid more
]]

--[[
    getgenv().Settings = {
        Redirect = {Chance = 100},
        Weapon = {Recoil = 0, Spread = 0}
    }
]]

if Settings then return end

local FastFlag = getfflag('DebugRunParallelLuaOnMainThread')

if FastFlag == 'false' then
    setfflag('DebugRunParallelLuaOnMainThread', 'True')
    game:GetService('TeleportService'):TeleportToPlaceInstance(game.PlaceId, game.JobId)
end

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local MouseLocation = UserInputService:GetMouseLocation()

local RaycastParams = RaycastParams.new()
RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
RaycastParams.FilterDescendantsInstances = {
    LocalPlayer.Character, CollectionService:GetTagged('Glass')
}

local Circle = Drawing.new('Circle')
Circle.Color = Color3.new(1, 1, 1)
Circle.Visible = true
Circle.Radius = 180

local Tools = require(ReplicatedStorage.Databases.Tools)

function DeepCopy(Original)
    if type(Original) ~= 'table' then return Original end
    
    local Copy = {}
    
    for Index, Value in pairs(Original) do
        if type(Value) == 'table' then
            Copy[Index] = DeepCopy(Value)
        else
            Copy[Index]
        end
    end
    
    return Copy
end


function GetClosest()
    local ClosestPlayer = nil
    local ClosestDistance = math.huge

    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end

        local PlayerRoot = Player.Character and Player.Character:FindFirstChild('HumanoidRootPart')
        if not PlayerRoot then continue end

        local PlayerHumanoid = Player.Character:FindFirstChild('Humanoid')
        if not PlayerHumanoid or PlayerHumanoid.Health < 0 then continue end

        local Vector, OnScreen = Camera:WorldToScreenPoint(PlayerRoot.Position)
        if not OnScreen then continue end

        local MouseDistance = (Vector2.new(Vector.X, Vector.Y) - MouseLocation).Magnitude
        
        if MouseDistance > Circle.Radius then continue end
        if MouseDistance > ClosestDistance then continue end

        ClosestPlayer = Player
        ClosestDistance = MouseDistance
    end

    return ClosestPlayer, ClosestDistance
end

function IsVisible(Position)
    local Vector, OnScreen = Camera:WorldToScreenPoint(Position)
    if not OnScreen then return false end

    local Origin = Camera.CFrame.Position
    local Direction = (Position - Origin).Unit * (Position - Origin).Magnitude

    return Workspace:Raycast(Origin, Direction, RaycastParams)
end

function GetModule(Name)
    for _, Module in pairs(getloadedmodules()) do
        if Module.Name == Name then
            return Module
        end
    end

    return false
end

function HookFirearm(Module)
    local Success, Result = pcall(function()
        return getgenv().require(Module)
    end)

    if not Success then return false end
    if isfunctionhooked(Result.Fire) then return Result end
            
    local OldFire; OldFire = hookfunction(Result.Fire, newcclosure(function(Data, Mouse)
        local SettingsRecoil, SettingsSpread = Settings.Weapon.Recoil, Data.ToolTable.Spread

        if SettingsRecoil == -1 then
            Data.ToolTable.Recoil = Tools[Data.ToolTable.Asset].Recoil
        else
            Data.ToolTable.Recoil = SettingsRecoil
        end

        if SettingsSpread == -1 then
            Data.ToolTable.Spread = Tools[Data.ToolTable.Asset].Spread
        else
            Data.ToolTable.Spread = SettingsSpread
        end

        local Random = math.random(100)

        if Random < Settings.Redirect.Chance then
            local Closest = GetClosest()

            if Closest then
                local Head = Closest.Character:FindFirstChild('Head')

                if Head and IsVisible(Head.Position) then
                    return OldFire(Data, {Hit = {p = Head.Position}, Target = Head})
                end
            end
        end

        return OldFire(Data, Mouse)
    end))

    return Result
end

RunService.RenderStepped:Connect(function()
    MouseLocation = UserInputService:GetMouseLocation()
    Circle.Position = MouseLocation
end)

CollectionService:GetInstanceAddedSignal('Glass'):Connect(function()
    RaycastParams.FilterDescendantsInstances = {
        LocalPlayer.Character, CollectionService:GetTagged('Glass')
    }
end)

local OldRequire; OldRequire = hookfunction(getrenv().require, newcclosure(function(Module)
    if Module.Name == 'Firearm' then
        local Result = HookFirearm(Module)
        return Result or OldRequire(Module)
    end

    return OldRequire(Module)
end))

local Firearm = GetModule('Firearm')
if Firearm then HookFirearm(Firearm) end
