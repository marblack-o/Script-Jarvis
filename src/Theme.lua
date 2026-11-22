local Theme = {}

-- Paleta de colores J.A.R.V.I.S. (Cian Holográfico)
Theme.bg = Color3.fromRGB(0, 10, 20)
Theme.panel = Color3.fromRGB(2, 15, 25)
Theme.plate = Color3.fromRGB(5, 20, 35)
Theme.sidebar = Color3.fromRGB(0, 12, 22)
Theme.inputBg = Color3.fromRGB(5, 22, 38)
Theme.row = Color3.fromRGB(10, 35, 55)

-- Acentos
Theme.border = Color3.fromRGB(0, 255, 255) -- Cian Stark
Theme.accent = Color3.fromRGB(100, 220, 255)
Theme.chatGreen = Color3.fromRGB(0, 255, 255)
Theme.c2 = Color3.fromRGB(180, 240, 255)

-- Trabajo UAI (Naranja / Gold)
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

function Theme.mkCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 2)
	c.Parent = parent
	return c
end

function Theme.mkStroke(parent, color, thick, trans)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.border
	s.Thickness = thick or 1
	s.Transparency = trans or 0.2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Theme.tween(obj, props, time, style)
	local TweenService = game:GetService("TweenService")
	local info = TweenInfo.new(time or 0.22, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

-- HUD Brackets (Esquinas tecnológicas)
function Theme.mkBrackets(parent, color, thickness, size)
    local c = type(color) == "userdata" and color or Theme.border
    local t = thickness or 2
    local s = size or 15
    local z = parent.ZIndex + 1
    
    local positions = {
        {UDim2.fromOffset(0, 0), UDim2.fromOffset(0, 0), UDim2.fromOffset(s, t), UDim2.fromOffset(t, s)}, -- TL
        {UDim2.new(1, -s, 0, 0), UDim2.new(1, -t, 0, 0), UDim2.fromOffset(s, t), UDim2.fromOffset(t, s)}, -- TR
        {UDim2.new(0, 0, 1, -t), UDim2.new(0, 0, 1, -s), UDim2.fromOffset(s, t), UDim2.fromOffset(t, s)}, -- BL
        {UDim2.new(1, -s, 1, -t), UDim2.new(1, -t, 1, -s), UDim2.fromOffset(s, t), UDim2.fromOffset(t, s)}  -- BR
    }
    
    for _, pos in ipairs(positions) do
        for i = 1, 2 do
            local f = Instance.new("Frame")
            f.BackgroundColor3 = c
            f.BorderSizePixel = 0
            f.Position = pos[i]
            f.Size = pos[i+2]
            f.ZIndex = z
            f.Parent = parent
        end
    end
end

return Theme
