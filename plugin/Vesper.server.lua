local VERSION = "0.2.0"
local ICON_ASSET_ID = "rbxassetid://83778785092785"

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local TweenService = game:GetService("TweenService")
if not RunService:IsEdit() then return end
local CoreGui = game:GetService("CoreGui")

local C_BG         = Color3.fromRGB(15, 15, 18)
local C_CARD       = Color3.fromRGB(24, 24, 29)
local C_ROW        = Color3.fromRGB(30, 30, 37)
local C_BORDER     = Color3.fromRGB(44, 44, 54)
local C_DIVIDER    = Color3.fromRGB(36, 36, 44)
local C_TEXT       = Color3.fromRGB(245, 245, 247)
local C_MUTED      = Color3.fromRGB(154, 154, 166)
local C_DIM        = Color3.fromRGB(132, 132, 145)
local C_VIOLET     = Color3.fromRGB(139, 92, 246)
local C_EMERALD    = Color3.fromRGB(52, 211, 153)
local C_EMERALD_BG = Color3.fromRGB(18, 42, 32)
local C_ROSE       = Color3.fromRGB(248, 113, 113)
local C_ROSE_BG    = Color3.fromRGB(48, 22, 22)

local FONT_DISPLAY = Enum.Font.BuilderSansBold
local FONT_UI      = Enum.Font.BuilderSansMedium
local FONT_REG     = Enum.Font.BuilderSans
local FONT_MONO    = Enum.Font.RobotoMono

local T_SPRING = TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local T_FAST   = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local isConnected    = false
local currentHost    = "http://127.0.0.1"
local currentPort    = 8910
local pollInterval   = 0.2
local OFFLINE_GRACE  = 30
local undoEnabled    = true

local toolbar = plugin:CreateToolbar("Vesper")
local toggleBtn = toolbar:CreateButton("Vesper", "Vesper AI Bridge", ICON_ASSET_ID)
toggleBtn.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false,
	false,
	340,
	480,
	280,
	360
)
local widget = plugin:CreateDockWidgetPluginGui("VesperWidget", widgetInfo)
widget.Title = "Vesper"

toggleBtn.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local toastGui = nil
pcall(function()
	local existing = CoreGui:FindFirstChild("VesperToastGui")
	if existing then existing:Destroy() end
	toastGui = Instance.new("ScreenGui")
	toastGui.Name = "VesperToastGui"
	toastGui.ResetOnSpawn = false
	toastGui.DisplayOrder = 999999
	toastGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	toastGui.Parent = CoreGui
end)

local activeToasts = 0

local function showToast(title, msg, toastType)
	if not toastGui then return end

	activeToasts = activeToasts + 1
	local currentSlot = activeToasts
	local yOffset = -56 - ((currentSlot - 1) * 54)
	local iconColor = toastType == "success" and C_EMERALD or (toastType == "error" and C_ROSE or C_VIOLET)

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(0, 260, 0, 44)
	toast.Position = UDim2.new(1, 20, 1, yOffset)
	toast.BackgroundColor3 = C_CARD
	toast.BorderSizePixel = 0
	toast.ZIndex = 10
	toast.ClipsDescendants = true
	toast.Parent = toastGui

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 10)
	tCorner.Parent = toast

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = C_BORDER
	tStroke.Thickness = 1
	tStroke.Parent = toast

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.Position = UDim2.new(0, 14, 0.5, -4)
	dot.BackgroundColor3 = iconColor
	dot.BorderSizePixel = 0
	dot.ZIndex = 11
	dot.Parent = toast

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local textFrame = Instance.new("Frame")
	textFrame.Name = "Text"
	textFrame.Size = UDim2.new(1, -38, 1, 0)
	textFrame.Position = UDim2.new(0, 30, 0, 0)
	textFrame.BackgroundTransparency = 1
	textFrame.ZIndex = 11
	textFrame.Parent = toast

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "Title"
	titleLbl.Size = UDim2.new(1, 0, 0, 16)
	titleLbl.Position = UDim2.new(0, 0, 0, 6)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = FONT_UI
	titleLbl.Text = title
	titleLbl.TextColor3 = C_TEXT
	titleLbl.TextSize = 11
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 12
	titleLbl.Parent = textFrame

	local msgLbl = Instance.new("TextLabel")
	msgLbl.Name = "Message"
	msgLbl.Size = UDim2.new(1, 0, 0, 14)
	msgLbl.Position = UDim2.new(0, 0, 0, 22)
	msgLbl.BackgroundTransparency = 1
	msgLbl.Font = FONT_REG
	msgLbl.Text = msg
	msgLbl.TextColor3 = C_MUTED
	msgLbl.TextSize = 10
	msgLbl.TextTruncate = Enum.TextTruncate.AtEnd
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.ZIndex = 12
	msgLbl.Parent = textFrame

	local targetPos = UDim2.new(1, -276, 1, yOffset)
	TweenService:Create(toast, T_SPRING, { Position = targetPos }):Play()

	task.delay(2.6, function()
		local exitPos = UDim2.new(1, 20, 1, yOffset)
		local exitTween = TweenService:Create(toast, T_SPRING, { Position = exitPos })
		exitTween:Play()
		exitTween.Completed:Connect(function()
			toast:Destroy()
			activeToasts = math.max(0, activeToasts - 1)
		end)
	end)
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = UDim2.new(1, 0, 1, 0)
mainFrame.BackgroundColor3 = C_BG
mainFrame.BorderSizePixel = 0
mainFrame.Parent = widget

local setupView = Instance.new("Frame")
setupView.Name = "SetupView"
setupView.Size = UDim2.new(1, 0, 1, 0)
setupView.BackgroundTransparency = 1
setupView.Visible = true
setupView.Parent = mainFrame

local sPad = Instance.new("UIPadding")
sPad.PaddingTop = UDim.new(0, 28)
sPad.PaddingBottom = UDim.new(0, 20)
sPad.PaddingLeft = UDim.new(0, 20)
sPad.PaddingRight = UDim.new(0, 20)
sPad.Parent = setupView

local sLayout = Instance.new("UIListLayout")
sLayout.FillDirection = Enum.FillDirection.Vertical
sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sLayout.SortOrder = Enum.SortOrder.LayoutOrder
sLayout.Padding = UDim.new(0, 18)
sLayout.Parent = setupView

local brandBox = Instance.new("Frame")
brandBox.Name = "Brand"
brandBox.Size = UDim2.new(1, 0, 0, 80)
brandBox.BackgroundTransparency = 1
brandBox.LayoutOrder = 1
brandBox.Parent = setupView

local logoImg = Instance.new("ImageLabel")
logoImg.Name = "Logo"
logoImg.Size = UDim2.new(0, 42, 0, 42)
logoImg.Position = UDim2.new(0.5, -21, 0, 0)
logoImg.BackgroundTransparency = 1
logoImg.Image = ICON_ASSET_ID
logoImg.Parent = brandBox

local brandTitle = Instance.new("TextLabel")
brandTitle.Name = "Title"
brandTitle.Size = UDim2.new(1, 0, 0, 20)
brandTitle.Position = UDim2.new(0, 0, 0, 48)
brandTitle.BackgroundTransparency = 1
brandTitle.Font = FONT_DISPLAY
brandTitle.Text = "Vesper"
brandTitle.TextColor3 = C_TEXT
brandTitle.TextSize = 16
brandTitle.TextXAlignment = Enum.TextXAlignment.Center
brandTitle.Parent = brandBox

local brandSub = Instance.new("TextLabel")
brandSub.Name = "Subtitle"
brandSub.Size = UDim2.new(1, 0, 0, 14)
brandSub.Position = UDim2.new(0, 0, 0, 68)
brandSub.BackgroundTransparency = 1
brandSub.Font = FONT_REG
brandSub.Text = "Roblox Studio AI Bridge · v" .. VERSION
brandSub.TextColor3 = C_MUTED
brandSub.TextSize = 11
brandSub.TextXAlignment = Enum.TextXAlignment.Center
brandSub.Parent = brandBox

local formCard = Instance.new("Frame")
formCard.Name = "FormCard"
formCard.Size = UDim2.new(1, 0, 0, 140)
formCard.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
formCard.BorderSizePixel = 0
formCard.LayoutOrder = 2
formCard.Parent = setupView

local formCorner = Instance.new("UICorner")
formCorner.CornerRadius = UDim.new(0, 10)
formCorner.Parent = formCard

local formStroke = Instance.new("UIStroke")
formStroke.Color = Color3.fromRGB(44, 44, 56)
formStroke.Thickness = 1
formStroke.Parent = formCard

local formPad = Instance.new("UIPadding")
formPad.PaddingTop = UDim.new(0, 12)
formPad.PaddingBottom = UDim.new(0, 12)
formPad.PaddingLeft = UDim.new(0, 14)
formPad.PaddingRight = UDim.new(0, 14)
formPad.Parent = formCard

local formLayout = Instance.new("UIListLayout")
formLayout.FillDirection = Enum.FillDirection.Vertical
formLayout.SortOrder = Enum.SortOrder.LayoutOrder
formLayout.Padding = UDim.new(0, 6)
formLayout.Parent = formCard

-- Host Field
local hostLabel = Instance.new("TextLabel")
hostLabel.Name = "HostLabel"
hostLabel.Size = UDim2.new(1, 0, 0, 14)
hostLabel.BackgroundTransparency = 1
hostLabel.Font = FONT_UI
hostLabel.Text = "HOST / ADDRESS"
hostLabel.TextColor3 = C_MUTED
hostLabel.TextSize = 10
hostLabel.TextXAlignment = Enum.TextXAlignment.Left
hostLabel.LayoutOrder = 1
hostLabel.Parent = formCard

local hostInput = Instance.new("TextBox")
hostInput.Name = "HostInput"
hostInput.Size = UDim2.new(1, 0, 0, 32)
hostInput.BackgroundColor3 = Color3.fromRGB(13, 13, 17)
hostInput.BorderSizePixel = 0
hostInput.Font = FONT_MONO
hostInput.Text = currentHost
hostInput.TextColor3 = C_TEXT
hostInput.PlaceholderText = "http://127.0.0.1"
hostInput.PlaceholderColor3 = Color3.fromRGB(132, 132, 145)
hostInput.TextSize = 12
hostInput.ClearTextOnFocus = false
hostInput.TextXAlignment = Enum.TextXAlignment.Left
hostInput.LayoutOrder = 2
hostInput.Parent = formCard

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 6)
hCorner.Parent = hostInput

local hStroke = Instance.new("UIStroke")
hStroke.Color = Color3.fromRGB(48, 48, 62)
hStroke.Thickness = 1
hStroke.Parent = hostInput

local hPad = Instance.new("UIPadding")
hPad.PaddingLeft = UDim.new(0, 10)
hPad.PaddingRight = UDim.new(0, 10)
hPad.Parent = hostInput

-- Port Field
local portLabel = Instance.new("TextLabel")
portLabel.Name = "PortLabel"
portLabel.Size = UDim2.new(1, 0, 0, 14)
portLabel.BackgroundTransparency = 1
portLabel.Font = FONT_UI
portLabel.Text = "PORT"
portLabel.TextColor3 = C_MUTED
portLabel.TextSize = 10
portLabel.TextXAlignment = Enum.TextXAlignment.Left
portLabel.LayoutOrder = 3
portLabel.Parent = formCard

local portInput = Instance.new("TextBox")
portInput.Name = "PortInput"
portInput.Size = UDim2.new(1, 0, 0, 32)
portInput.BackgroundColor3 = Color3.fromRGB(13, 13, 17)
portInput.BorderSizePixel = 0
portInput.Font = FONT_MONO
portInput.Text = tostring(currentPort)
portInput.TextColor3 = C_TEXT
portInput.PlaceholderText = "8910"
portInput.PlaceholderColor3 = Color3.fromRGB(132, 132, 145)
portInput.TextSize = 12
portInput.ClearTextOnFocus = false
portInput.TextXAlignment = Enum.TextXAlignment.Left
portInput.LayoutOrder = 4
portInput.Parent = formCard

local pCorner = Instance.new("UICorner")
pCorner.CornerRadius = UDim.new(0, 6)
pCorner.Parent = portInput

local pStroke = Instance.new("UIStroke")
pStroke.Color = Color3.fromRGB(48, 48, 62)
pStroke.Thickness = 1
pStroke.Parent = portInput

local pPad = Instance.new("UIPadding")
pPad.PaddingLeft = UDim.new(0, 10)
pPad.PaddingRight = UDim.new(0, 10)
pPad.Parent = portInput

local startConnectBtn = Instance.new("TextButton")
startConnectBtn.Name = "StartConnectBtn"
startConnectBtn.Size = UDim2.new(1, 0, 0, 38)
startConnectBtn.BackgroundColor3 = C_VIOLET
startConnectBtn.BorderSizePixel = 0
startConnectBtn.Font = FONT_DISPLAY
startConnectBtn.Text = "Connect to Bridge"
startConnectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startConnectBtn.TextSize = 13
startConnectBtn.LayoutOrder = 3
startConnectBtn.Parent = setupView

local sBtnCorner = Instance.new("UICorner")
sBtnCorner.CornerRadius = UDim.new(0, 8)
sBtnCorner.Parent = startConnectBtn

startConnectBtn.MouseEnter:Connect(function()
	startConnectBtn.BackgroundColor3 = Color3.fromRGB(155, 112, 255)
end)
startConnectBtn.MouseLeave:Connect(function()
	startConnectBtn.BackgroundColor3 = C_VIOLET
end)

local setupStatusLabel = Instance.new("TextLabel")
setupStatusLabel.Name = "StatusMsg"
setupStatusLabel.Size = UDim2.new(1, 0, 0, 32)
setupStatusLabel.BackgroundTransparency = 1
setupStatusLabel.Font = FONT_REG
setupStatusLabel.Text = "Run 'vesper serve' in terminal to start the bridge"
setupStatusLabel.TextColor3 = C_MUTED
setupStatusLabel.TextSize = 11
setupStatusLabel.TextWrapped = true
setupStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
setupStatusLabel.LayoutOrder = 4
setupStatusLabel.Parent = setupView

local sessionView = Instance.new("Frame")
sessionView.Name = "SessionView"
sessionView.Size = UDim2.new(1, 0, 1, 0)
sessionView.BackgroundTransparency = 1
sessionView.Visible = false
sessionView.Parent = mainFrame

local sessPad = Instance.new("UIPadding")
sessPad.PaddingTop = UDim.new(0, 12)
sessPad.PaddingBottom = UDim.new(0, 12)
sessPad.PaddingLeft = UDim.new(0, 12)
sessPad.PaddingRight = UDim.new(0, 12)
sessPad.Parent = sessionView

local sessLayout = Instance.new("UIListLayout")
sessLayout.FillDirection = Enum.FillDirection.Vertical
sessLayout.SortOrder = Enum.SortOrder.LayoutOrder
sessLayout.Padding = UDim.new(0, 10)
sessLayout.Parent = sessionView

local sessHeader = Instance.new("Frame")
sessHeader.Name = "Header"
sessHeader.Size = UDim2.new(1, 0, 0, 34)
sessHeader.BackgroundTransparency = 1
sessHeader.LayoutOrder = 1
sessHeader.Parent = sessionView

local sHeaderLeft = Instance.new("Frame")
sHeaderLeft.Size = UDim2.new(0, 100, 1, 0)
sHeaderLeft.BackgroundTransparency = 1
sHeaderLeft.Parent = sessHeader

local sHLeftLayout = Instance.new("UIListLayout")
sHLeftLayout.FillDirection = Enum.FillDirection.Horizontal
sHLeftLayout.VerticalAlignment = Enum.VerticalAlignment.Center
sHLeftLayout.Padding = UDim.new(0, 8)
sHLeftLayout.Parent = sHeaderLeft

local sIcon = Instance.new("ImageLabel")
sIcon.Size = UDim2.new(0, 20, 0, 20)
sIcon.BackgroundTransparency = 1
sIcon.Image = ICON_ASSET_ID
sIcon.Parent = sHeaderLeft

local sTitle = Instance.new("TextLabel")
sTitle.Size = UDim2.new(0, 56, 1, 0)
sTitle.BackgroundTransparency = 1
sTitle.Font = FONT_DISPLAY
sTitle.Text = "Vesper"
sTitle.TextColor3 = C_TEXT
sTitle.TextSize = 13
sTitle.TextXAlignment = Enum.TextXAlignment.Left
sTitle.Parent = sHeaderLeft

local sVersion = Instance.new("TextLabel")
sVersion.Size = UDim2.new(0, 40, 1, 0)
sVersion.BackgroundTransparency = 1
sVersion.Font = FONT_MONO
sVersion.Text = "v" .. VERSION
sVersion.TextColor3 = C_DIM
sVersion.TextSize = 10
sVersion.TextXAlignment = Enum.TextXAlignment.Left
sVersion.Parent = sHeaderLeft

local segControl = Instance.new("Frame")
segControl.Name = "SegmentedControl"
segControl.Size = UDim2.new(0, 150, 0, 28)
segControl.Position = UDim2.new(1, -150, 0.5, -14)
segControl.BackgroundColor3 = C_CARD
segControl.BorderSizePixel = 0
segControl.Parent = sessHeader

local segCorner = Instance.new("UICorner")
segCorner.CornerRadius = UDim.new(0, 7)
segCorner.Parent = segControl

local segStroke = Instance.new("UIStroke")
segStroke.Color = C_BORDER
segStroke.Thickness = 1
segStroke.Parent = segControl

local segSlider = Instance.new("Frame")
segSlider.Name = "Slider"
segSlider.Size = UDim2.new(0.5, -2, 1, -4)
segSlider.Position = UDim2.new(0, 2, 0, 2)
segSlider.BackgroundColor3 = C_ROW
segSlider.BorderSizePixel = 0
segSlider.ZIndex = 2
segSlider.Parent = segControl

local sliderCorner = Instance.new("UICorner")
sliderCorner.CornerRadius = UDim.new(0, 5)
sliderCorner.Parent = segSlider

local sliderStroke = Instance.new("UIStroke")
sliderStroke.Color = C_BORDER
sliderStroke.Thickness = 1
sliderStroke.Parent = segSlider

local tabConsoleBtn = Instance.new("TextButton")
tabConsoleBtn.Name = "TabConsole"
tabConsoleBtn.Size = UDim2.new(0.5, 0, 1, 0)
tabConsoleBtn.Position = UDim2.new(0, 0, 0, 0)
tabConsoleBtn.BackgroundTransparency = 1
tabConsoleBtn.Font = FONT_UI
tabConsoleBtn.Text = "Activity"
tabConsoleBtn.TextColor3 = C_TEXT
tabConsoleBtn.TextSize = 11
tabConsoleBtn.ZIndex = 3
tabConsoleBtn.Parent = segControl

local tabSettingsBtn = Instance.new("TextButton")
tabSettingsBtn.Name = "TabSettings"
tabSettingsBtn.Size = UDim2.new(0.5, 0, 1, 0)
tabSettingsBtn.Position = UDim2.new(0.5, 0, 0, 0)
tabSettingsBtn.BackgroundTransparency = 1
tabSettingsBtn.Font = FONT_UI
tabSettingsBtn.Text = "Settings"
tabSettingsBtn.TextColor3 = C_MUTED
tabSettingsBtn.TextSize = 11
tabSettingsBtn.ZIndex = 3
tabSettingsBtn.Parent = segControl

local contentContainer = Instance.new("Frame")
contentContainer.Name = "Content"
contentContainer.Size = UDim2.new(1, 0, 1, -44)
contentContainer.BackgroundTransparency = 1
contentContainer.LayoutOrder = 2
contentContainer.Parent = sessionView

local termView = Instance.new("Frame")
termView.Name = "TermView"
termView.Size = UDim2.new(1, 0, 1, 0)
termView.BackgroundTransparency = 1
termView.Visible = true
termView.Parent = contentContainer

local termTop = Instance.new("Frame")
termTop.Name = "Bar"
termTop.Size = UDim2.new(1, 0, 0, 20)
termTop.BackgroundTransparency = 1
termTop.Parent = termView

local livePill = Instance.new("Frame")
livePill.Size = UDim2.new(0, 0, 0, 20)
livePill.AutomaticSize = Enum.AutomaticSize.X
livePill.BackgroundColor3 = C_EMERALD_BG
livePill.BorderSizePixel = 0
livePill.Parent = termTop

local lCorner = Instance.new("UICorner")
lCorner.CornerRadius = UDim.new(1, 0)
lCorner.Parent = livePill

local lPad = Instance.new("UIPadding")
lPad.PaddingLeft = UDim.new(0, 9)
lPad.PaddingRight = UDim.new(0, 10)
lPad.Parent = livePill

local lLayout = Instance.new("UIListLayout")
lLayout.FillDirection = Enum.FillDirection.Horizontal
lLayout.VerticalAlignment = Enum.VerticalAlignment.Center
lLayout.Padding = UDim.new(0, 6)
lLayout.Parent = livePill

local lDot = Instance.new("Frame")
lDot.Size = UDim2.new(0, 6, 0, 6)
lDot.LayoutOrder = 1
lDot.BackgroundColor3 = C_EMERALD
lDot.BorderSizePixel = 0
lDot.Parent = livePill

local lDotCorner = Instance.new("UICorner")
lDotCorner.CornerRadius = UDim.new(1, 0)
lDotCorner.Parent = lDot

local liveText = Instance.new("TextLabel")
liveText.Size = UDim2.new(0, 0, 1, 0)
liveText.AutomaticSize = Enum.AutomaticSize.X
liveText.LayoutOrder = 2
liveText.BackgroundTransparency = 1
liveText.Font = FONT_MONO
liveText.Text = "PORT 8910"
liveText.TextColor3 = C_EMERALD
liveText.TextSize = 10
liveText.TextXAlignment = Enum.TextXAlignment.Left
liveText.Parent = livePill

local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0, 48, 1, 0)
clearBtn.Position = UDim2.new(1, -48, 0, 0)
clearBtn.BackgroundTransparency = 1
clearBtn.Font = FONT_UI
clearBtn.Text = "Clear"
clearBtn.TextColor3 = C_DIM
clearBtn.TextSize = 11
clearBtn.TextXAlignment = Enum.TextXAlignment.Right
clearBtn.Parent = termTop

clearBtn.MouseEnter:Connect(function()
	clearBtn.TextColor3 = C_TEXT
end)
clearBtn.MouseLeave:Connect(function()
	clearBtn.TextColor3 = C_DIM
end)

local termBox = Instance.new("Frame")
termBox.Name = "FeedBox"
termBox.Size = UDim2.new(1, 0, 1, -26)
termBox.Position = UDim2.new(0, 0, 0, 26)
termBox.BackgroundColor3 = C_CARD
termBox.BorderSizePixel = 0
termBox.Parent = termView

local tBoxCorner = Instance.new("UICorner")
tBoxCorner.CornerRadius = UDim.new(0, 8)
tBoxCorner.Parent = termBox

local tBoxStroke = Instance.new("UIStroke")
tBoxStroke.Color = C_BORDER
tBoxStroke.Thickness = 1
tBoxStroke.Parent = termBox

local termScroll = Instance.new("ScrollingFrame")
termScroll.Size = UDim2.new(1, 0, 1, 0)
termScroll.BackgroundTransparency = 1
termScroll.BorderSizePixel = 0
termScroll.ScrollBarThickness = 3
termScroll.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 68)
termScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
termScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
termScroll.Parent = termBox

local tScrollPad = Instance.new("UIPadding")
tScrollPad.PaddingTop = UDim.new(0, 8)
tScrollPad.PaddingBottom = UDim.new(0, 8)
tScrollPad.PaddingLeft = UDim.new(0, 10)
tScrollPad.PaddingRight = UDim.new(0, 10)
tScrollPad.Parent = termScroll

local tScrollLayout = Instance.new("UIListLayout")
tScrollLayout.FillDirection = Enum.FillDirection.Vertical
tScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
tScrollLayout.Padding = UDim.new(0, 5)
tScrollLayout.Parent = termScroll

local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name = "EmptyPrompt"
emptyLabel.Size = UDim2.new(1, 0, 0, 60)
emptyLabel.Position = UDim2.new(0, 0, 0.4, -30)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Font = FONT_REG
emptyLabel.Text = "Listening for commands...\nRun 'vesper' in terminal"
emptyLabel.TextColor3 = C_DIM
emptyLabel.TextSize = 11
emptyLabel.TextWrapped = true
emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
emptyLabel.Parent = termBox

local prefsOverlay = Instance.new("ScrollingFrame")
prefsOverlay.Name = "PrefsOverlay"
prefsOverlay.Size = UDim2.new(1, 0, 1, 0)
prefsOverlay.BackgroundTransparency = 1
prefsOverlay.BorderSizePixel = 0
prefsOverlay.ScrollBarThickness = 2
prefsOverlay.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 68)
prefsOverlay.CanvasSize = UDim2.new(0, 0, 0, 0)
prefsOverlay.AutomaticCanvasSize = Enum.AutomaticSize.Y
prefsOverlay.Visible = false
prefsOverlay.Parent = contentContainer

local pOverLayout = Instance.new("UIListLayout")
pOverLayout.FillDirection = Enum.FillDirection.Vertical
pOverLayout.SortOrder = Enum.SortOrder.LayoutOrder
pOverLayout.Padding = UDim.new(0, 14)
pOverLayout.Parent = prefsOverlay

local sec1Label = Instance.new("TextLabel")
sec1Label.Size = UDim2.new(1, 0, 0, 14)
sec1Label.BackgroundTransparency = 1
sec1Label.Font = FONT_UI
sec1Label.Text = "BRIDGE PREFERENCES"
sec1Label.TextColor3 = C_MUTED
sec1Label.TextSize = 10
sec1Label.TextXAlignment = Enum.TextXAlignment.Left
sec1Label.LayoutOrder = 1
sec1Label.Parent = prefsOverlay

local sec1Card = Instance.new("Frame")
sec1Card.Name = "BridgeCard"
sec1Card.Size = UDim2.new(1, 0, 0, 88)
sec1Card.BackgroundColor3 = C_CARD
sec1Card.BorderSizePixel = 0
sec1Card.LayoutOrder = 2
sec1Card.Parent = prefsOverlay

local s1Corner = Instance.new("UICorner")
s1Corner.CornerRadius = UDim.new(0, 10)
s1Corner.Parent = sec1Card

local s1Stroke = Instance.new("UIStroke")
s1Stroke.Color = C_BORDER
s1Stroke.Thickness = 1
s1Stroke.Parent = sec1Card

local rowInterval = Instance.new("Frame")
rowInterval.Name = "IntervalRow"
rowInterval.Size = UDim2.new(1, 0, 0, 44)
rowInterval.Position = UDim2.new(0, 0, 0, 0)
rowInterval.BackgroundTransparency = 1
rowInterval.Parent = sec1Card

local rIntPad = Instance.new("UIPadding")
rIntPad.PaddingLeft = UDim.new(0, 14)
rIntPad.PaddingRight = UDim.new(0, 14)
rIntPad.Parent = rowInterval

local rIntLabel = Instance.new("TextLabel")
rIntLabel.Size = UDim2.new(0.6, 0, 1, 0)
rIntLabel.BackgroundTransparency = 1
rIntLabel.Font = FONT_UI
rIntLabel.Text = "Poll Interval"
rIntLabel.TextColor3 = C_TEXT
rIntLabel.TextSize = 12
rIntLabel.TextXAlignment = Enum.TextXAlignment.Left
rIntLabel.Parent = rowInterval

local intervalInput = Instance.new("TextBox")
intervalInput.Name = "IntervalInput"
intervalInput.Size = UDim2.new(0, 60, 0, 24)
intervalInput.Position = UDim2.new(1, -60, 0.5, -12)
intervalInput.BackgroundColor3 = C_ROW
intervalInput.BorderSizePixel = 0
intervalInput.Font = FONT_MONO
intervalInput.Text = tostring(pollInterval) .. "s"
intervalInput.TextColor3 = C_TEXT
intervalInput.TextSize = 11
intervalInput.ClearTextOnFocus = false
intervalInput.TextXAlignment = Enum.TextXAlignment.Center
intervalInput.Parent = rowInterval

local intCorn = Instance.new("UICorner")
intCorn.CornerRadius = UDim.new(0, 6)
intCorn.Parent = intervalInput

local intStroke = Instance.new("UIStroke")
intStroke.Color = C_BORDER
intStroke.Thickness = 1
intStroke.Parent = intervalInput

local div1 = Instance.new("Frame")
div1.Size = UDim2.new(1, -28, 0, 1)
div1.Position = UDim2.new(0, 14, 0, 44)
div1.BackgroundColor3 = C_DIVIDER
div1.BorderSizePixel = 0
div1.Parent = sec1Card

local rowUndo = Instance.new("Frame")
rowUndo.Name = "UndoRow"
rowUndo.Size = UDim2.new(1, 0, 0, 44)
rowUndo.Position = UDim2.new(0, 0, 0, 44)
rowUndo.BackgroundTransparency = 1
rowUndo.Parent = sec1Card

local rUndoPad = Instance.new("UIPadding")
rUndoPad.PaddingLeft = UDim.new(0, 14)
rUndoPad.PaddingRight = UDim.new(0, 14)
rUndoPad.Parent = rowUndo

local rUndoLabel = Instance.new("TextLabel")
rUndoLabel.Size = UDim2.new(0.6, 0, 1, 0)
rUndoLabel.BackgroundTransparency = 1
rUndoLabel.Font = FONT_UI
rUndoLabel.Text = "Record Undo History"
rUndoLabel.TextColor3 = C_TEXT
rUndoLabel.TextSize = 12
rUndoLabel.TextXAlignment = Enum.TextXAlignment.Left
rUndoLabel.Parent = rowUndo

local toggleSwitch = Instance.new("TextButton")
toggleSwitch.Name = "ToggleSwitch"
toggleSwitch.Size = UDim2.new(0, 42, 0, 24)
toggleSwitch.Position = UDim2.new(1, -42, 0.5, -12)
toggleSwitch.BackgroundColor3 = C_VIOLET
toggleSwitch.BorderSizePixel = 0
toggleSwitch.Text = ""
toggleSwitch.AutoButtonColor = false
toggleSwitch.Parent = rowUndo

local swCorner = Instance.new("UICorner")
swCorner.CornerRadius = UDim.new(1, 0)
swCorner.Parent = toggleSwitch

local swThumb = Instance.new("Frame")
swThumb.Name = "Thumb"
swThumb.Size = UDim2.new(0, 20, 0, 20)
swThumb.Position = UDim2.new(1, -22, 0.5, -10)
swThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
swThumb.BorderSizePixel = 0
swThumb.Parent = toggleSwitch

local thCorner = Instance.new("UICorner")
thCorner.CornerRadius = UDim.new(1, 0)
thCorner.Parent = swThumb

local function updateToggleVisual(animate)
	local targetBg = undoEnabled and C_VIOLET or C_BORDER
	local targetPos = undoEnabled and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)

	if animate then
		TweenService:Create(toggleSwitch, T_FAST, { BackgroundColor3 = targetBg }):Play()
		TweenService:Create(swThumb, T_FAST, { Position = targetPos }):Play()
	else
		toggleSwitch.BackgroundColor3 = targetBg
		swThumb.Position = targetPos
	end
end
updateToggleVisual(false)

local sec2Label = Instance.new("TextLabel")
sec2Label.Size = UDim2.new(1, 0, 0, 14)
sec2Label.BackgroundTransparency = 1
sec2Label.Font = FONT_UI
sec2Label.Text = "CONNECTION"
sec2Label.TextColor3 = C_MUTED
sec2Label.TextSize = 10
sec2Label.TextXAlignment = Enum.TextXAlignment.Left
sec2Label.LayoutOrder = 3
sec2Label.Parent = prefsOverlay

local sec2Card = Instance.new("Frame")
sec2Card.Name = "ConnCard"
sec2Card.Size = UDim2.new(1, 0, 0, 44)
sec2Card.BackgroundColor3 = C_CARD
sec2Card.BorderSizePixel = 0
sec2Card.LayoutOrder = 4
sec2Card.Parent = prefsOverlay

local s2Corner = Instance.new("UICorner")
s2Corner.CornerRadius = UDim.new(0, 10)
s2Corner.Parent = sec2Card

local s2Stroke = Instance.new("UIStroke")
s2Stroke.Color = C_BORDER
s2Stroke.Thickness = 1
s2Stroke.Parent = sec2Card

local connRowPad = Instance.new("UIPadding")
connRowPad.PaddingLeft = UDim.new(0, 14)
connRowPad.PaddingRight = UDim.new(0, 14)
connRowPad.Parent = sec2Card

local connEndpointLbl = Instance.new("TextLabel")
connEndpointLbl.Size = UDim2.new(0.5, 0, 1, 0)
connEndpointLbl.BackgroundTransparency = 1
connEndpointLbl.Font = FONT_UI
connEndpointLbl.Text = "Daemon"
connEndpointLbl.TextColor3 = C_TEXT
connEndpointLbl.TextSize = 12
connEndpointLbl.TextXAlignment = Enum.TextXAlignment.Left
connEndpointLbl.Parent = sec2Card

local connHostValue = Instance.new("TextLabel")
connHostValue.Name = "HostValue"
connHostValue.Size = UDim2.new(0.5, 0, 1, 0)
connHostValue.Position = UDim2.new(0.5, 0, 0, 0)
connHostValue.BackgroundTransparency = 1
connHostValue.Font = FONT_MONO
connHostValue.Text = "127.0.0.1:8910"
connHostValue.TextColor3 = C_MUTED
connHostValue.TextSize = 11
connHostValue.TextXAlignment = Enum.TextXAlignment.Right
connHostValue.Parent = sec2Card

local disconnectBtn = Instance.new("TextButton")
disconnectBtn.Name = "DisconnectBtn"
disconnectBtn.Size = UDim2.new(1, 0, 0, 36)
disconnectBtn.BackgroundColor3 = C_CARD
disconnectBtn.BorderSizePixel = 0
disconnectBtn.Font = FONT_UI
disconnectBtn.Text = "Disconnect Bridge"
disconnectBtn.TextColor3 = C_ROSE
disconnectBtn.TextSize = 12
disconnectBtn.LayoutOrder = 5
disconnectBtn.Parent = prefsOverlay

local discCorner = Instance.new("UICorner")
discCorner.CornerRadius = UDim.new(0, 8)
discCorner.Parent = disconnectBtn

local discStroke = Instance.new("UIStroke")
discStroke.Color = C_BORDER
discStroke.Thickness = 1
discStroke.Parent = disconnectBtn

local linkLost = false
local lostSince = 0
local function setLive(live)
	linkLost = not live
	if linkLost then lostSince = os.clock() end
	livePill.BackgroundColor3 = live and C_EMERALD_BG or C_ROSE_BG
	lDot.BackgroundColor3 = live and C_EMERALD or C_ROSE
	liveText.TextColor3 = live and C_EMERALD or C_ROSE
	liveText.Text = live and ("PORT " .. currentPort) or "OFFLINE"
	disconnectBtn.Text = live and "Disconnect Bridge" or "Stop Reconnecting"
end

local function switchTab(tabName)
	if tabName == "console" then
		termView.Visible = true
		prefsOverlay.Visible = false
		tabConsoleBtn.TextColor3 = C_TEXT
		tabSettingsBtn.TextColor3 = C_MUTED
		TweenService:Create(segSlider, T_FAST, { Position = UDim2.new(0, 2, 0, 2) }):Play()
	else
		termView.Visible = false
		prefsOverlay.Visible = true
		tabConsoleBtn.TextColor3 = C_MUTED
		tabSettingsBtn.TextColor3 = C_TEXT
		TweenService:Create(segSlider, T_FAST, { Position = UDim2.new(0.5, 0, 0, 2) }):Play()
	end
end

tabConsoleBtn.MouseButton1Click:Connect(function()
	switchTab("console")
end)

tabSettingsBtn.MouseButton1Click:Connect(function()
	switchTab("settings")
end)

local logCount = 0
local function appendLog(prefix, msg, color)
	emptyLabel.Visible = false
	logCount = logCount + 1

	local line = Instance.new("TextLabel")
	line.Name = "Line" .. logCount
	line.Size = UDim2.new(1, 0, 0, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.BackgroundTransparency = 1
	line.Font = FONT_MONO
	line.TextSize = 11
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextWrapped = true
	line.RichText = true

	local hexColor = string.format("#%02X%02X%02X", math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255))
	local timeStr = os.date("%H:%M:%S")

	local escapedMsg = tostring(msg):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
	line.Text = string.format("<font color=\"#848491\">[%s]</font> <font color=\"%s\"><b>%s</b></font> <font color=\"#E4E4E7\">%s</font>",
		timeStr, hexColor, prefix, escapedMsg)
	line.LayoutOrder = logCount
	line.Parent = termScroll

	if logCount > 150 then
		local oldest = termScroll:FindFirstChild("Line" .. (logCount - 150))
		if oldest then oldest:Destroy() end
	end

	task.defer(function()
		termScroll.CanvasPosition = Vector2.new(0, 999999)
	end)
end

local function resolveInstance(pathStr)
	if not pathStr or pathStr == "" or pathStr == "workspace" or pathStr == "Workspace" then
		return workspace
	end
	if pathStr == "game" then
		return game
	end
	local target = game
	for seg in string.gmatch(pathStr, "[^%.]+") do
		target = target:FindFirstChild(seg)
		if not target then return nil end
	end
	return target
end

local TREE_MAX_LINES = 400

local function dumpTree(arg)
	local ok, opts = pcall(function() return HttpService:JSONDecode(arg) end)
	if not ok or type(opts) ~= "table" then opts = { path = arg } end
	local maxDepth = tonumber(opts.depth) or 4
	local target = resolveInstance(opts.path)
	if not target then return "ERROR: Instance not found: " .. tostring(opts.path) end
	local lines = {}
	local function scan(inst, depth)
		if depth > maxDepth or #lines >= TREE_MAX_LINES then return end
		local line = string.rep("  ", depth) .. inst.Name .. " [" .. inst.ClassName .. "]"
		if inst:IsA("BasePart") then
			local p, s = inst.Position, inst.Size
			line ..= string.format(" Pos(%.1f,%.1f,%.1f) Size(%.1f,%.1f,%.1f) Color(%d,%d,%d)",
				p.X, p.Y, p.Z, s.X, s.Y, s.Z,
				math.round(inst.Color.R * 255), math.round(inst.Color.G * 255), math.round(inst.Color.B * 255))
		end
		table.insert(lines, line)
		for _, c in ipairs(inst:GetChildren()) do scan(c, depth + 1) end
	end
	scan(target, 0)
	if #lines >= TREE_MAX_LINES then table.insert(lines, "... truncated at " .. TREE_MAX_LINES .. " lines, use a deeper path or lower depth") end
	return table.concat(lines, "\n")
end

local TEST_RUNNER = [[
local STS = game:GetService("StudioTestService")
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")
local args = HttpService:JSONDecode(STS:GetTestArgs())
local logs, done = {}, false
LogService.MessageOut:Connect(function(m, t)
	if t == Enum.MessageType.MessageOutput then table.insert(logs, m)
	elseif t == Enum.MessageType.MessageWarning then table.insert(logs, "[WARN] " .. m)
	elseif t == Enum.MessageType.MessageError then table.insert(logs, "[ERROR] " .. m) end
end)
local function finish(ok, res)
	if done then return end
	done = true
	STS:EndTest(HttpService:JSONEncode({ ok = ok, result = res ~= nil and tostring(res) or nil, logs = logs }))
end
task.delay(args.timeout, function() finish(false, "timeout after " .. args.timeout .. "s") end)
task.spawn(function()
	local ok, fn = pcall(require, script.UserTest)
	local res = fn
	if ok then ok, res = pcall(fn) end
	finish(ok, res)
end)
]]

local function runTest(arg)
	local okArg, opts = pcall(function() return HttpService:JSONDecode(arg) end)
	if not okArg or type(opts) ~= "table" or type(opts.code) ~= "string" then
		return "ERROR: test needs {code, timeout}"
	end
	local timeout = tonumber(opts.timeout) or 20
	local sss = game:GetService("ServerScriptService")
	local old = sss:FindFirstChild("__VesperTest")
	if old then old:Destroy() end

	local runner = Instance.new("Script")
	runner.Name = "__VesperTest"
	runner.Source = TEST_RUNNER
	local mod = Instance.new("ModuleScript")
	mod.Name = "UserTest"
	mod.Source = "return function()\n" .. opts.code .. "\nend"
	mod.Parent = runner
	runner.Parent = sss

	local ran, raw = pcall(function()
		return game:GetService("StudioTestService"):ExecutePlayModeAsync(HttpService:JSONEncode({ timeout = timeout }))
	end)
	runner:Destroy()

	if not ran then
		appendLog("FAIL", tostring(raw), C_ROSE)
		return "ERROR: " .. tostring(raw)
	end
	local decOk, r = pcall(function() return HttpService:JSONDecode(raw) end)
	if not decOk or type(r) ~= "table" then
		return "ERROR: test ended without a result (stopped early?)"
	end
	local out = table.concat(r.logs or {}, "\n")
	showToast("Play Test", r.ok and "Passed" or "Failed", r.ok and "success" or "error")
	appendLog(r.ok and "OK" or "FAIL", tostring(r.result or "done"), r.ok and C_EMERALD or C_ROSE)
	return (r.ok and "PASS" or "FAIL") .. (r.result and (": " .. r.result) or "") .. (out ~= "" and ("\nLOGS:\n" .. out) or "")
end

local function handleCommand(raw)
	local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok or type(data) ~= "table" then
		appendLog("ERR", "Malformed payload", C_ROSE)
		showToast("Payload Error", "Malformed JSON", "error")
		return "ERROR: Invalid JSON payload"
	end

	if data.cmd == "tree" then
		appendLog("TREE", tostring(data.arg), C_MUTED)
		return dumpTree(data.arg)
	elseif data.cmd == "test" then
		appendLog("TEST", "play mode", C_VIOLET)
		return runTest(data.arg)
	elseif data.cmd == "run" or data.cmd == "exec" then
		local preview = string.sub(data.arg or "", 1, 55):gsub("[\n\r]", " ")
		appendLog("EXEC", preview .. (string.len(data.arg or "") > 55 and "..." or ""), C_VIOLET)

		local logs = {}
		local rec = nil
		if undoEnabled and RunService:IsEdit() then
			rec = ChangeHistoryService:TryBeginRecording("Vesper Edit")
		end

		local loadFn = loadstring
		if not loadFn then
			if rec then ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Cancel) end
			appendLog("ERR", "loadstring is unavailable in Studio. Turn on LoadStringEnabled or allow scripts.", C_ROSE)
			showToast("LoadString Disabled", "Cannot execute Luau", "error")
			return "ERROR: loadstring is unavailable in this Roblox Studio environment"
		end

		local fnOk, fnOrErr = pcall(loadFn, data.arg)
		if not fnOk or not fnOrErr then
			if rec then ChangeHistoryService:FinishRecording(rec, Enum.FinishRecordingOperation.Cancel) end
			appendLog("ERR", "Syntax: " .. tostring(fnOrErr), C_ROSE)
			showToast("Syntax Error", tostring(fnOrErr), "error")
			return "SYNTAX_ERROR: " .. tostring(fnOrErr)
		end

		local fn = fnOrErr
		local env = setmetatable({
			print = function(...)
				local t = {}
				for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
				local str = table.concat(t, " ")
				table.insert(logs, str)
				appendLog("LOG", str, C_MUTED)
			end,
			warn = function(...)
				local t = {}
				for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
				local str = table.concat(t, " ")
				table.insert(logs, "[WARN] " .. str)
				appendLog("WARN", str, C_ROSE)
			end,
		}, { __index = getfenv() })
		setfenv(fn, env)

		local runOk, res = pcall(fn)
		if rec then
			ChangeHistoryService:FinishRecording(rec, runOk and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
		end

		local out = table.concat(logs, "\n")
		if not runOk then
			appendLog("FAIL", tostring(res), C_ROSE)
			showToast("Execution Failed", tostring(res), "error")
			return "RUNTIME_ERROR: " .. tostring(res) .. (out ~= "" and ("\nLOGS:\n" .. out) or "")
		end
		appendLog("OK", res ~= nil and tostring(res) or "Done", C_EMERALD)
		showToast("Edit Applied", preview, "success")
		return "OK" .. (res ~= nil and (": " .. tostring(res)) or "") .. (out ~= "" and ("\n" .. out) or "")
	end
	return "ERROR: Unknown command: " .. tostring(data.cmd)
end

local isConnecting = false

local function connectToDaemon()
	if isConnected or isConnecting then return end
	isConnecting = true
	startConnectBtn.Text = "Connecting..."
	setupStatusLabel.TextColor3 = C_MUTED
	setupStatusLabel.Text = "Connecting to " .. currentHost .. ":" .. currentPort .. "..."

	task.spawn(function()
		local testUrl = string.format("%s:%d/status", currentHost, currentPort)
		local ok, res = pcall(function()
			return HttpService:RequestAsync({
				Url = testUrl,
				Method = "GET",
			})
		end)

		isConnecting = false
		startConnectBtn.Text = "Connect"

		if ok and res and res.Success then
			isConnected = true
			setupView.Visible = false
			sessionView.Visible = true
			switchTab("console")

			setLive(true)
			connHostValue.Text = currentHost:gsub("^https?://", "") .. ":" .. currentPort
			appendLog("SYS", "Connected to Vesper on port " .. currentPort, C_EMERALD)
			setupStatusLabel.Text = ""
		else
			isConnected = false
			setupStatusLabel.TextColor3 = C_ROSE
			local errMsg = tostring(res or "")
			if errMsg:lower():find("not enabled") then
				setupStatusLabel.Text = "Enable 'Allow HTTP Requests' in Game Settings -> Security"
			else
				setupStatusLabel.Text = "Cannot reach server. Run: vesper serve"
			end
		end
	end)
end

local function disconnectFromDaemon(reason)
	isConnected = false
	isConnecting = false
	startConnectBtn.Text = "Connect"
	sessionView.Visible = false
	setupView.Visible = true
	setupStatusLabel.TextColor3 = reason and C_ROSE or C_DIM
	setupStatusLabel.Text = reason or "Disconnected. Run 'vesper serve' to resume."
	for _, child in ipairs(termScroll:GetChildren()) do
		if child:IsA("TextLabel") and child ~= emptyLabel then child:Destroy() end
	end
	logCount = 0
	emptyLabel.Visible = true
end

startConnectBtn.MouseButton1Click:Connect(function()
	connectToDaemon()
end)

disconnectBtn.MouseButton1Click:Connect(function()
	disconnectFromDaemon()
end)

hostInput.Focused:Connect(function()
	hStroke.Color = C_VIOLET
end)

hostInput.FocusLost:Connect(function()
	hStroke.Color = Color3.fromRGB(48, 48, 62)
	local val = hostInput.Text:gsub("%s+", "")
	if val ~= "" then
		if not val:find("^https?://") then
			val = "http://" .. val
		end
		currentHost = val
		hostInput.Text = currentHost
	end
end)

portInput.Focused:Connect(function()
	pStroke.Color = C_VIOLET
end)

portInput.FocusLost:Connect(function()
	pStroke.Color = Color3.fromRGB(48, 48, 62)
	local num = tonumber(portInput.Text)
	if num and num > 0 and num <= 65535 then
		currentPort = math.floor(num)
		portInput.Text = tostring(currentPort)
	else
		portInput.Text = tostring(currentPort)
	end
end)

clearBtn.MouseButton1Click:Connect(function()
	for _, child in ipairs(termScroll:GetChildren()) do
		if child:IsA("TextLabel") and child ~= emptyLabel then child:Destroy() end
	end
	logCount = 0
	emptyLabel.Visible = true
	appendLog("SYS", "Console cleared", C_DIM)
end)

intervalInput.FocusLost:Connect(function()
	local cleaned = intervalInput.Text:gsub("[^%d%.]", "")
	local num = tonumber(cleaned)
	if num and num >= 0.05 and num <= 5.0 then
		pollInterval = num
		intervalInput.Text = tostring(pollInterval) .. "s"
		appendLog("CFG", "Interval set to " .. pollInterval .. "s", C_VIOLET)
	else
		intervalInput.Text = tostring(pollInterval) .. "s"
	end
end)

toggleSwitch.MouseButton1Click:Connect(function()
	undoEnabled = not undoEnabled
	updateToggleVisual(true)
	appendLog("CFG", "History recording " .. (undoEnabled and "enabled" or "disabled"), C_VIOLET)
end)

task.spawn(function()
	while true do
		if isConnected then
			local pollUrl = string.format("%s:%d/poll", currentHost, currentPort)
			local replyUrl = string.format("%s:%d/reply", currentHost, currentPort)

			local ok, res = pcall(function()
				return HttpService:RequestAsync({
					Url = pollUrl,
					Method = "GET",
				})
			end)

			if ok and res and res.Success then
				if linkLost then
					setLive(true)
					appendLog("NET", "Reconnected", C_EMERALD)
				end
				if res.Body and res.Body ~= "" and res.Body ~= "NOOP" then
					local idOk, idData = pcall(function() return HttpService:JSONDecode(res.Body) end)
					local cmdId = idOk and type(idData) == "table" and idData.id or ""
					local cmdOk, cmdResult = pcall(handleCommand, res.Body)
					local finalReply = cmdOk and tostring(cmdResult) or ("ERROR: " .. tostring(cmdResult))

					pcall(function()
						HttpService:RequestAsync({
							Url = replyUrl,
							Method = "POST",
							Headers = { ["Content-Type"] = "text/plain", ["X-Vesper-Id"] = tostring(cmdId) },
							Body = finalReply,
						})
					end)
				end
			else
				if isConnected then
					if not linkLost then
						setLive(false)
						appendLog("NET", "Lost connection to server", C_ROSE)
						showToast("Connection Lost", "Reconnecting...", "error")
					elseif os.clock() - lostSince > OFFLINE_GRACE then
						disconnectFromDaemon("Server unreachable. Run: vesper serve")
					end
					task.wait(1)
				end
			end
			task.wait(pollInterval)
		else
			task.wait(0.5)
		end
	end
end)

print("[Vesper] v" .. VERSION .. " ready")
