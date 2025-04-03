local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local MouseLocation = UserInputService:GetMouseLocation()

local Circle = Drawing.new('Circle')
Circle.Color = Color3.new(1, 1, 1)
Circle.Visible = true
Circle.Radius = 120

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
        Data.ToolTable.Recoil = 0; Data.ToolTable.Spread = 0

        if Settings.Redirect.Enabled then
            local Random = math.random(100)

            if Random > Settings.Redirect.Chance then
                print(Random)
                -- local Closest = GetClosest()

                -- if Closest then
                --     local Head = Closest.Character.Head
                --     return OldFire(Data, {Hit = {p = Head.Position}, Target = Head})
                -- end
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

local OldRequire; OldRequire = hookfunction(getrenv().require, newcclosure(function(Module)
    if Module.Name == 'Firearm' then
        local Result = HookFirearm(Module)
        return Result or OldRequire(Module)
    end

    return OldRequire(Module)
end))

local Firearm = GetModule('Firearm')

if Firearm then
    HookFirearm(Firearm)
end
