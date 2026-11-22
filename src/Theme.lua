--[[
  Theme.lua
  Qué: tokens visuales J.A.R.V.I.S.
  - Cian holográfico.
  - Naranja para override/trabajo.
  - Rojo para errores.
  - Brackets HUD.
]]

local Theme = {}

-- Fondos / paneles
Theme.bg = Color3.fromRGB(0, 10, 20)
Theme.panel = Color3.fromRGB(2, 15, 25)
Theme.plate = Color3.fromRGB(5, 20, 35)
Theme.sidebar = Color3.fromRGB(0, 12, 22)
Theme.inputBg = Color3.fromRGB(5, 22, 38)
Theme.row = Color3.fromRGB(10, 35, 55)

-- Acentos
Theme.border = Color3.fromRGB(0, 255, 255)
Theme.accent = Color3.fromRGB(100, 220, 255)
Theme.chatGreen = Color3.fromRGB(0, 255, 255)
Theme.c2 = Color3.fromRGB(180, 240, 255)

-- Override / trabajo
Theme.uaiYellow = Color3.fromRGB(255, 170, 0)
Theme.glitch = Color3.fromRGB(255, 200, 50)

-- Estados
Theme.green = Color3.fromRGB(0, 255, 150)
Theme.danger = Color3.fromRGB(255, 50, 50)

-- Texto
Theme.text = Color3.fromRGB(220, 245, 255)
Theme.textDim = Color3.fromRGB(100, 160, 190)

-- Burbujas
Theme.bubbleUser = Color3.fromRGB(15, 45, 70)
Theme.bubbleAi = Color3.fromRGB(5, 25, 40)

function Theme.mkCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 3)
	corner.Parent = parent
	return corner
end

function Theme.mkStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.border
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0.3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Theme.tween(obj, props, time, style, direction)
	local TweenService = game:GetService("TweenService")

	local info = TweenInfo.new(
		time or 0.2,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)

	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

function Theme.mkBrackets(parent, color, thickness, size)
	local colorType = nil
	if type(typeof) == "function" then
		colorType = typeof(color)
	else
		colorType = type(color)
	end

	local c = Theme.border
	if colorType == "Color3" or colorType == "userdata" then
		c = color
	end

	local t = thickness or 2
	local s = size or 16
	local z = (parent.ZIndex or 0) + 1

	local pieces = {
		{
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(s, t),
		},
		{
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(t, s),
		},
		{
			Position = UDim2.new(1, -s, 0, 0),
			Size = UDim2.fromOffset(s, t),
		},
		{
			Position = UDim2.new(1, -t, 0, 0),
			Size = UDim2.fromOffset(t, s),
		},
		{
			Position = UDim2.new(0, 0, 1, -t),
			Size = UDim2.fromOffset(s, t),
		},
		{
			Position = UDim2.new(0, 0, 1, -s),
			Size = UDim2.fromOffset(t, s),
		},
		{
			Position = UDim2.new(1, -s, 1, -t),
			Size = UDim2.fromOffset(s, t),
		},
		{
			Position = UDim2.new(1, -t, 1, -s),
			Size = UDim2.fromOffset(t, s),
		},
	}

	for _, piece in ipairs(pieces) do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = c
		f.BackgroundTransparency = 0
		f.BorderSizePixel = 0
		f.Position = piece.Position
		f.Size = piece.Size
		f.ZIndex = z
		f.Parent = parent
	end
end

return Theme
