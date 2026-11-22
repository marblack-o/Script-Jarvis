local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Visual = {}
Visual.__index = Visual
local rgb = Color3.fromRGB

local CFG = { NAME = "J.A.R.V.I.S.", SIZE = 0.25, MIN_PX = 120, MAX_PX = 280 }

local STATES = {
	idle = { label = "SYSTEM ONLINE", main = rgb(0, 255, 255), light = rgb(180, 240, 255), speed = 0.5, pulse = 1 },
	listening = { label = "AUDIO RECEPTORS ACTIVE", main = rgb(0, 255, 255), light = rgb(255, 255, 255), speed = 1.2, pulse = 1.2 },
	thinking = { label = "PROCESSING DATA...", main = rgb(255, 170, 0), light = rgb(255, 220, 100), speed = 2.5, pulse = 1.5 },
	speaking = { label = "VOCALIZING...", main = rgb(0, 255, 255), light = rgb(180, 240, 255), speed = 1.5, pulse = 1.3 },
	error = { label = "SYSTEM ERROR", main = rgb(255, 50, 50), light = rgb(255, 150, 150), speed = 0.2, pulse = 0.8 },
}
STATES.talking = STATES.speaking
STATES.hack = STATES.thinking
STATES.done = { label = "TASK COMPLETE", main = rgb(0, 255, 150), light = rgb(180, 255, 200), speed = 1.0, pulse = 1.0 }

local function tween(inst, time, goal)
	TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

function Visual.new(gui, Assets, Theme)
	local self = setmetatable({}, Visual)
	self.gui, self.Assets, self.Theme = gui, Assets, Theme
	self.state, self.onClick, self.tinted = "idle", nil, {}
	self.curMain, self.curLight = STATES.idle.main, STATES.idle.light
	self:_build()
	return self
end

function Visual:_mk(class, props, parent)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 elseif o:IsA("UIStroke") then o.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	for k, v in pairs(props) do
		if type(v) == "string" and v:sub(1, 1) == "@" and (k:find("Color")) then
			self.tinted[#self.tinted + 1] = { o, k, v:sub(2) }
			o[k] = v:sub(2) == "main" and self.curMain or self.curLight
		else o[k] = v end
	end
	o.Parent = parent
	return o
end

function Visual:_applyTint()
	for _, e in ipairs(self.tinted) do e[1][e[2]] = e[3] == "main" and self.curMain or self.curLight end
end

function Visual:_fireClick() if type(self.onClick) == "function" then self.onClick() end end

function Visual:_build()
	local gui = self.gui
	local function mk(c, p, parent) return self:_mk(c, p, parent) end
	local CENTER, ROUND = Vector2.new(0.5, 0.5), UDim.new(1, 0)

	local stage = mk("Frame", { Name = "JarvisStage", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.03, 0.95), BackgroundTransparency = 1, ZIndex = 10 }, gui)
	self.stage = stage

	local function resize()
		local v = gui.AbsoluteSize
		if v.X < 10 or v.Y < 10 then return end
		stage.Size = UDim2.fromOffset(math.clamp(math.min(v.X, v.Y) * CFG.SIZE, CFG.MIN_PX, CFG.MAX_PX), math.clamp(math.min(v.X, v.Y) * CFG.SIZE, CFG.MIN_PX, CFG.MAX_PX))
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	task.defer(resize)

	local core = mk("Frame", { Name = "Core", AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = "@main", BackgroundTransparency = 0.2, ZIndex = 5 }, stage)
	mk("UICorner", { CornerRadius = ROUND }, core)
	self.core = core

	local glow = mk("Frame", { Name = "Glow", AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.45, 0.45), BackgroundColor3 = "@main", BackgroundTransparency = 0.6, ZIndex = 4 }, stage)
	mk("UICorner", { CornerRadius = ROUND }, glow)
	self.glow = glow

	local function ring(name, thick, radius, trans)
		local f = mk("Frame", { Name = name, AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(radius, radius), BackgroundTransparency = 1, ZIndex = 3 }, stage)
		mk("UICorner", { CornerRadius = ROUND }, f)
		mk("UIStroke", { Color = "@main", Thickness = thick, Transparency = trans }, f)
		return f
	end

	self.ringOuter = ring("RingOuter", 1, 0.95, 0.2)
	self.ringMid = ring("RingMid", 2, 0.75, 0.4)
	self.ringInner = ring("RingInner", 1, 0.55, 0.3)

	local ticks = mk("Frame", { Name = "Ticks", AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.85, 0.85), BackgroundTransparency = 1, ZIndex = 3 }, stage)
	self.ticks = ticks
	for i = 1, 12 do
		local a = math.rad(i * 30)
		mk("Frame", { AnchorPoint = CENTER, BackgroundColor3 = "@main", BackgroundTransparency = 0.2, Size = UDim2.fromOffset(2, 10), Position = UDim2.fromScale(0.5 + math.cos(a) * 0.45, 0.5 + math.sin(a) * 0.45), Rotation = math.deg(a) + 90 }, ticks)
	end

	self.Theme.mkBrackets(stage, self.Theme.border, 2, 20)

	local hit = mk("TextButton", { Name = "Hitbox", AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 10 }, stage)
	hit.MouseButton1Click:Connect(function() self:_fireClick() end)

	local title = mk("TextLabel", { Text = CFG.NAME, Font = Enum.Font.Code, TextSize = 14, TextColor3 = "@main", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 5), Size = UDim2.fromOffset(150, 20), ZIndex = 5 }, stage)
	self.status = mk("TextLabel", { Text = STATES.idle.label, Font = Enum.Font.Code, TextSize = 11, TextColor3 = "@light", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 22), Size = UDim2.fromOffset(150, 14), ZIndex = 5 }, stage)

	local dragging, start, startPos = false, nil, nil
	stage.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging, start, startPos = true, i.Position, stage.Position end end)
	stage.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then stage.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + (i.Position - start).X, startPos.Y.Scale, startPos.Y.Offset + (i.Position - start).Y) end end)

	self._speed, self._t = 1, 0
	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		self._t = self._t + dt
		local S = STATES[self.state] or STATES.idle
		if self.curMain ~= S.main or self.curLight ~= S.light then
			self.curMain = self.curMain:Lerp(S.main, 1 - math.exp(-dt * 6))
			self.curLight = self.curLight:Lerp(S.light, 1 - math.exp(-dt * 6))
			self:_applyTint()
		end
		self._speed = self._speed + (S.speed - self._speed) * math.min(1, dt * 3)
		self.ringOuter.Rotation = (self.ringOuter.Rotation + dt * 15 * self._speed) % 360
		self.ringMid.Rotation = (self.ringMid.Rotation - dt * 25 * self._speed) % 360
		self.ringInner.Rotation = (self.ringInner.Rotation + dt * 40 * self._speed) % 360
		self.ticks.Rotation = (self.ticks.Rotation - dt * 10 * self._speed) % 360
		local pulse = 1 + math.sin(self._t * 4 * self._speed) * 0.1 * S.pulse
		self.core.Size = UDim2.fromScale(0.3 * pulse, 0.3 * pulse)
		self.glow.Size = UDim2.fromScale(0.45 * pulse, 0.45 * pulse)
		self.glow.BackgroundTransparency = 0.6 - math.sin(self._t * 4 * self._speed) * 0.2
	end)
end

function Visual:setFace() end
function Visual:flashCutin() end
function Visual:setExpression(state)
	local key = state or "idle"
	if not STATES[key] then key = "idle" end
	if key == self.state then return end
	self.state = key
	if self.status then self.status.Text = STATES[key].label tween(self.status, 0.25, { TextTransparency = 0 }) end
end
function Visual:setChatOpen() end

return Visual
