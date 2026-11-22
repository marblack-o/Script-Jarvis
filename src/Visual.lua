--[[
  Visual.lua
  Qué: HUD J.A.R.V.I.S.
  - Núcleo tipo Arc Reactor.
  - Anillos holográficos.
  - Estados por color/velocidad.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Visual = {}
Visual.__index = Visual

local rgb = Color3.fromRGB

local CFG = {
	NAME = "J.A.R.V.I.S.",
	SIZE = 0.25,
	MIN_PX = 120,
	MAX_PX = 280,
}

local STATES = {
	idle = {
		label = "SYSTEM ONLINE",
		main = rgb(0, 255, 255),
		light = rgb(180, 240, 255),
		speed = 0.5,
		pulse = 1,
	},
	listening = {
		label = "AUDIO RECEPTORS ACTIVE",
		main = rgb(0, 255, 255),
		light = rgb(255, 255, 255),
		speed = 1.2,
		pulse = 1.2,
	},
	thinking = {
		label = "PROCESSING DATA...",
		main = rgb(255, 170, 0),
		light = rgb(255, 220, 100),
		speed = 2.5,
		pulse = 1.5,
	},
	speaking = {
		label = "VOCALIZING...",
		main = rgb(0, 255, 255),
		light = rgb(180, 240, 255),
		speed = 1.5,
		pulse = 1.3,
	},
	error = {
		label = "SYSTEM ERROR",
		main = rgb(255, 50, 50),
		light = rgb(255, 150, 150),
		speed = 0.2,
		pulse = 0.8,
	},
	done = {
		label = "TASK COMPLETE",
		main = rgb(0, 255, 150),
		light = rgb(180, 255, 200),
		speed = 1,
		pulse = 1,
	},
}

STATES.talking = STATES.speaking
STATES.hack = STATES.thinking

local function tween(instance, time, goal)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

function Visual.new(gui, _Assets, Theme)
	local self = setmetatable({}, Visual)

	self.gui = gui
	self.Theme = Theme
	self.state = "idle"
	self.onClick = nil
	self.tinted = {}

	self.curMain = STATES.idle.main
	self.curLight = STATES.idle.light

	self:_build()

	return self
end

function Visual:_mk(class, props, parent)
	local object = Instance.new(class)

	if object:IsA("GuiObject") then
		object.BorderSizePixel = 0
	elseif object:IsA("UIStroke") then
		object.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end

	for key, value in pairs(props) do
		if type(value) == "string" and value:sub(1, 1) == "@" and key:find("Color") then
			local which = value:sub(2)
			table.insert(self.tinted, { object, key, which })
			object[key] = which == "main" and self.curMain or self.curLight
		else
			object[key] = value
		end
	end

	object.Parent = parent
	return object
end

function Visual:_applyTint()
	for _, entry in ipairs(self.tinted) do
		local object = entry[1]
		local property = entry[2]
		local which = entry[3]

		object[property] = which == "main" and self.curMain or self.curLight
	end
end

function Visual:_fireClick()
	if type(self.onClick) == "function" then
		self.onClick()
	end
end

function Visual:_build()
	local gui = self.gui
	local Theme = self.Theme

	local function mk(class, props, parent)
		return self:_mk(class, props, parent)
	end

	local CENTER = Vector2.new(0.5, 0.5)
	local ROUND = UDim.new(1, 0)

	local stage = mk("Frame", {
		Name = "JarvisStage",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.03, 0.95),
		Size = UDim2.fromOffset(180, 180),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 10,
	}, gui)

	self.stage = stage

	local function resize()
		local viewport = gui.AbsoluteSize
		if viewport.X < 10 or viewport.Y < 10 then
			return
		end

		local size = math.clamp(
			math.min(viewport.X, viewport.Y) * CFG.SIZE,
			CFG.MIN_PX,
			CFG.MAX_PX
		)

		stage.Size = UDim2.fromOffset(size, size)
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	task.defer(resize)

	local glow = mk("Frame", {
		Name = "Glow",
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.45, 0.45),
		BackgroundColor3 = "@main",
		BackgroundTransparency = 0.6,
		ZIndex = 4,
	}, stage)
	mk("UICorner", { CornerRadius = ROUND }, glow)
	self.glow = glow

	local core = mk("Frame", {
		Name = "Core",
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = "@main",
		BackgroundTransparency = 0.15,
		ZIndex = 5,
	}, stage)
	mk("UICorner", { CornerRadius = ROUND }, core)
	self.core = core

	local function makeRing(name, thickness, radius, transparency)
		local ring = mk("Frame", {
			Name = name,
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(radius, radius),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, stage)

		mk("UICorner", { CornerRadius = ROUND }, ring)
		mk("UIStroke", {
			Color = "@main",
			Thickness = thickness,
			Transparency = transparency,
		}, ring)

		return ring
	end

	self.ringOuter = makeRing("RingOuter", 1, 0.95, 0.2)
	self.ringMid = makeRing("RingMid", 2, 0.75, 0.4)
	self.ringInner = makeRing("RingInner", 1, 0.55, 0.3)

	local ticks = mk("Frame", {
		Name = "Ticks",
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.85, 0.85),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, stage)
	self.ticks = ticks

	for i = 1, 12 do
		local angle = math.rad(i * 30)

		mk("Frame", {
			AnchorPoint = CENTER,
			BackgroundColor3 = "@main",
			BackgroundTransparency = 0.2,
			Size = UDim2.fromOffset(2, 10),
			Position = UDim2.fromScale(
				0.5 + math.cos(angle) * 0.45,
				0.5 + math.sin(angle) * 0.45
			),
			Rotation = math.deg(angle) + 90,
		}, ticks)
	end

	Theme.mkBrackets(stage, Theme.border, 2, 20)

	local hit = mk("TextButton", {
		Name = "Hitbox",
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		ZIndex = 10,
	}, stage)

	mk("TextLabel", {
		Name = "Title",
		Text = CFG.NAME,
		Font = Enum.Font.Code,
		TextSize = 14,
		TextColor3 = "@main",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromOffset(170, 18),
		ZIndex = 5,
	}, stage)

	self.status = mk("TextLabel", {
		Name = "Status",
		Text = STATES.idle.label,
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = "@light",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 24),
		Size = UDim2.fromOffset(170, 14),
		ZIndex = 5,
	}, stage)

	local dragging = false
	local dragStart = nil
	local dragStartPosition = nil
	local dragMoved = false

	local function beginDrag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragMoved = false
			dragStart = input.Position
			dragStartPosition = stage.Position
		end
	end

	local function endDrag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end

	stage.InputBegan:Connect(beginDrag)
	hit.InputBegan:Connect(beginDrag)

	stage.InputEnded:Connect(endDrag)
	hit.InputEnded:Connect(endDrag)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart

			if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then
				dragMoved = true

				stage.Position = UDim2.new(
					dragStartPosition.X.Scale,
					dragStartPosition.X.Offset + delta.X,
					dragStartPosition.Y.Scale,
					dragStartPosition.Y.Offset + delta.Y
				)
			end
		end
	end)

	hit.MouseButton1Click:Connect(function()
		if not dragMoved then
			self:_fireClick()
		end
	end)

	self._speed = 1
	self._t = 0

	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		self._t = self._t + dt

		local stateData = STATES[self.state] or STATES.idle

		if self.curMain ~= stateData.main or self.curLight ~= stateData.light then
			local k = 1 - math.exp(-dt * 6)

			self.curMain = self.curMain:Lerp(stateData.main, k)
			self.curLight = self.curLight:Lerp(stateData.light, k)

			self:_applyTint()
		end

		self._speed = self._speed + (stateData.speed - self._speed) * math.min(1, dt * 3)

		self.ringOuter.Rotation = (self.ringOuter.Rotation + dt * 15 * self._speed) % 360
		self.ringMid.Rotation = (self.ringMid.Rotation - dt * 25 * self._speed) % 360
		self.ringInner.Rotation = (self.ringInner.Rotation + dt * 40 * self._speed) % 360
		self.ticks.Rotation = (self.ticks.Rotation - dt * 10 * self._speed) % 360

		local pulse = 1 + math.sin(self._t * 4 * self._speed) * 0.1 * stateData.pulse

		self.core.Size = UDim2.fromScale(0.3 * pulse, 0.3 * pulse)
		self.glow.Size = UDim2.fromScale(0.45 * pulse, 0.45 * pulse)
		self.glow.BackgroundTransparency = 0.6 - math.sin(self._t * 4 * self._speed) * 0.2
	end)
end

function Visual:setExpression(state)
	local key = state or "idle"

	if not STATES[key] then
		key = "idle"
	end

	if key == self.state then
		return
	end

	self.state = key

	if self.status then
		self.status.Text = STATES[key].label
		self.status.TextTransparency = 0.6
		tween(self.status, 0.25, { TextTransparency = 0 })
	end
end

function Visual:setChatOpen(_open)
	-- Compatible con App.lua, aunque el HUD no necesite cambiar texto aquí.
end

function Visual:setFace(_keys)
end

function Visual:flashCutin(_key)
end

return Visual
