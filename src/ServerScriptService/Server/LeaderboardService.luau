----!strict
----[[
--	LeaderboardService (server)

--	Global top-10 boards, written to OrderedDataStore and rendered on physical
--	signs in the lobby.

--	Physical boards rather than a menu on purpose: a leaderboard you have to
--	open is a stat screen, one you walk past on the way to the water is a
--	reason to throw again.

--	Writes are throttled and only happen when a value actually improves, so a
--	busy server does not burn its OrderedDataStore budget. Reads are cached and
--	shared by every player. Like Persistence, every call is wrapped -- with no
--	API access the boards simply show "unavailable" and nothing else breaks.
--]]

--local DataStoreService = game:GetService("DataStoreService")
--local Players = game:GetService("Players")
--local ReplicatedStorage = game:GetService("ReplicatedStorage")

--local Shared = ReplicatedStorage:WaitForChild("Shared")
--local Remotes = require(Shared:WaitForChild("Remotes"))

--local Profiles = require(script.Parent:WaitForChild("Profiles"))
--local ApiHealth = require(script.Parent:WaitForChild("ApiHealth"))

--local LeaderboardService = {}

--local REFRESH_INTERVAL = 75
--local TOP_COUNT = 10

--type Board = {
--	key: string,
--	title: string,
--	suffix: string,
--	store: OrderedDataStore?,
--	entries: {{name: string, value: number}},
--	-- Last value written per player, so an unchanged score is not rewritten.
--	written: {[number]: number},
--}

--local boards: {[string]: Board} = {
--	distance = {
--		key = "BestDistance_v1",
--		title = "FURTHEST THROW",
--		suffix = " studs",
--		store = nil,
--		entries = {},
--		written = {},
--	},
--	money = {
--		key = "TotalMoney_v1",
--		title = "MOST MONEY EARNED",
--		suffix = "",
--		store = nil,
--		entries = {},
--		written = {},
--	},
--}

----[[
--	Starts optimistic and is switched off by the first API-disabled error.
--	GetOrderedDataStore succeeds even with the API turned off, so deciding
--	availability up front made the signs claim "no scores yet" in Studio when
--	the truth was that they could never have any.
--]]
--local storesOk = true
--local nameCache: {[number]: string} = {}
--local signsDirty = false

--local function markUnavailable(err: any): boolean
--	if ApiHealth.isDisabled(err) then
--		if storesOk then
--			storesOk = false
--			signsDirty = true
--			warn("[Leaderboard] DataStore API is disabled -- boards will show as unavailable.")
--		end
--		return true
--	end
--	return false
--end

---- ============================================================================
---- Names
---- ============================================================================

--local function nameFor(userId: number): string
--	if nameCache[userId] then
--		return nameCache[userId]
--	end
--	-- A player on this server is free to resolve; otherwise ask Roblox once.
--	local player = Players:GetPlayerByUserId(userId)
--	if player then
--		nameCache[userId] = player.DisplayName
--		return player.DisplayName
--	end
--	local ok, result = pcall(function()
--		return Players:GetNameFromUserIdAsync(userId)
--	end)
--	local resolved = if ok and typeof(result) == "string" then result else ("Player " .. userId)
--	nameCache[userId] = resolved
--	return resolved
--end

---- ============================================================================
---- Reading and writing
---- ============================================================================

--local function refresh(board: Board)
--	if not board.store then
--		return
--	end
--	local ok, pages = pcall(function()
--		return (board.store :: OrderedDataStore):GetSortedAsync(false, TOP_COUNT)
--	end)
--	if not ok then
--		if not markUnavailable(pages) then
--			warn("[Leaderboard] read failed for " .. board.key .. ": " .. tostring(pages))
--		end
--		return
--	end

--	local ok2, page = pcall(function()
--		return pages:GetCurrentPage()
--	end)
--	if not ok2 then
--		return
--	end

--	local entries = {}
--	for _, row in page do
--		local userId = tonumber(row.key)
--		if userId then
--			table.insert(entries, {name = nameFor(userId), value = row.value})
--		end
--	end
--	board.entries = entries
--end

--local function write(board: Board, player: Player, value: number)
--	if not storesOk or not board.store or value <= 0 then
--		return
--	end
--	local previous = board.written[player.UserId]
--	if previous and value <= previous then
--		return -- no improvement; do not spend a write
--	end
--	board.written[player.UserId] = value

--	task.spawn(function()
--		local ok, err = pcall(function()
--			(board.store :: OrderedDataStore):SetAsync(tostring(player.UserId), math.floor(value))
--		end)
--		if not ok and not markUnavailable(err) then
--			warn("[Leaderboard] write failed for " .. board.key .. ": " .. tostring(err))
--		end
--	end)
--end

---- ============================================================================
---- Client payload
---- ============================================================================

--function LeaderboardService.snapshot(): {[string]: any}
--	local payload = {available = storesOk, boards = {}}
--	for id, board in boards do
--		table.insert(payload.boards, {
--			id = id,
--			title = board.title,
--			suffix = board.suffix,
--			entries = board.entries,
--		})
--	end
--	return payload
--end

--local function broadcast()
--	Remotes.LeaderboardState:FireAllClients(LeaderboardService.snapshot())
--end

---- ============================================================================
---- Physical signs
---- ============================================================================

--local function buildSign(board: Board, position: Vector3, facing: Vector3): SurfaceGui
--	local post = Instance.new("Part")
--	post.Name = "LeaderboardSign_" .. board.key
--	post.Size = Vector3.new(24, 15, 1)
--	post.Anchored = true
--	-- Deliberately NOT collidable. The throw's solid-hit raycast runs with
--	-- RespectCanCollide, so a solid board next to spawn would end any throw
--	-- that clipped it -- and players could not walk past them either.
--	post.CanCollide = false
--	post.CanQuery = false
--	post.Material = Enum.Material.WoodPlanks
--	post.Color = Color3.fromRGB(48, 36, 28)
--	post.CFrame = CFrame.lookAt(position, position + facing)
--	post.Parent = workspace

--	local gui = Instance.new("SurfaceGui")
--	gui.Name = "Board"
--	gui.Face = Enum.NormalId.Front
--	gui.CanvasSize = Vector2.new(480, 300)
--	gui.AlwaysOnTop = false
--	gui.Parent = post

--	local bg = Instance.new("Frame")
--	bg.Size = UDim2.fromScale(1, 1)
--	bg.BackgroundColor3 = Color3.fromRGB(10, 16, 24)
--	bg.BorderSizePixel = 0
--	bg.Parent = gui

--	local heading = Instance.new("TextLabel")
--	heading.Name = "Heading"
--	heading.Size = UDim2.new(1, 0, 0, 44)
--	heading.BackgroundColor3 = Color3.fromRGB(90, 200, 255)
--	heading.BorderSizePixel = 0
--	heading.Text = board.title
--	heading.TextColor3 = Color3.fromRGB(10, 16, 24)
--	heading.Font = Enum.Font.GothamBlack
--	heading.TextSize = 26
--	heading.Parent = bg

--	local list = Instance.new("Frame")
--	list.Name = "List"
--	list.Position = UDim2.new(0, 10, 0, 50)
--	list.Size = UDim2.new(1, -20, 1, -58)
--	list.BackgroundTransparency = 1
--	list.Parent = bg

--	local layout = Instance.new("UIListLayout")
--	layout.Padding = UDim.new(0, 2)
--	layout.SortOrder = Enum.SortOrder.LayoutOrder
--	layout.Parent = list

--	return gui
--end

--local signs: {[string]: SurfaceGui} = {}

--local function renderSign(board: Board, id: string)
--	local gui = signs[id]
--	if not gui then
--		return
--	end
--	local list = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("List")
--	if not list then
--		return
--	end

--	for _, child in list:GetChildren() do
--		if child:IsA("TextLabel") then
--			child:Destroy()
--		end
--	end

--	if not storesOk then
--		local label = Instance.new("TextLabel")
--		label.Size = UDim2.new(1, 0, 0, 24)
--		label.BackgroundTransparency = 1
--		label.Text = "leaderboards unavailable"
--		label.TextColor3 = Color3.fromRGB(150, 168, 190)
--		label.Font = Enum.Font.GothamBold
--		label.TextSize = 18
--		label.Parent = list
--		return
--	end

--	if #board.entries == 0 then
--		local label = Instance.new("TextLabel")
--		label.Size = UDim2.new(1, 0, 0, 24)
--		label.BackgroundTransparency = 1
--		label.Text = "no scores yet - be the first"
--		label.TextColor3 = Color3.fromRGB(150, 168, 190)
--		label.Font = Enum.Font.GothamBold
--		label.TextSize = 18
--		label.Parent = list
--		return
--	end

--	for rank, entry in board.entries do
--		local label = Instance.new("TextLabel")
--		label.Size = UDim2.new(1, 0, 0, 23)
--		label.BackgroundTransparency = 1
--		label.Text = string.format("%d.  %s", rank, entry.name)
--		label.TextColor3 = if rank == 1
--			then Color3.fromRGB(255, 215, 100)
--			else Color3.fromRGB(225, 238, 255)
--		label.Font = Enum.Font.GothamBold
--		label.TextSize = 19
--		label.TextXAlignment = Enum.TextXAlignment.Left
--		label.LayoutOrder = rank
--		label.Parent = list

--		local value = Instance.new("TextLabel")
--		value.Size = UDim2.fromScale(1, 1)
--		value.BackgroundTransparency = 1
--		value.Text = tostring(entry.value) .. board.suffix
--		value.TextColor3 = label.TextColor3
--		value.Font = Enum.Font.GothamBold
--		value.TextSize = 19
--		value.TextXAlignment = Enum.TextXAlignment.Right
--		value.Parent = label
--	end
--end

---- ============================================================================
---- Wiring
---- ============================================================================

--function LeaderboardService.start()
--	local ok = true
--	for _, board in boards do
--		local success, store = pcall(function()
--			return DataStoreService:GetOrderedDataStore(board.key)
--		end)
--		if success and store then
--			board.store = store
--		else
--			ok = false
--		end
--	end
--	storesOk = ok

--	-- Signs flank the spawn so they are seen on the way to the water.
--	local spawnPoint = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
--	local origin = spawnPoint and spawnPoint.Position or Vector3.new(0, 14, 0)
--	local base = origin + Vector3.new(0, 8, 0)

--	signs.distance = buildSign(boards.distance, base + Vector3.new(-4, 0, -26), Vector3.new(0, 0, 1))
--	signs.money = buildSign(boards.money, base + Vector3.new(-4, 0, 26), Vector3.new(0, 0, -1))

--	for id, board in boards do
--		renderSign(board, id)
--	end

--	-- Record improvements as they happen.
--	Profiles.onChanged(function(player)
--		local profile = Profiles.get(player)
--		if not profile.loaded then
--			return
--		end
--		write(boards.distance, player, profile.bestDistance)
--		write(boards.money, player, profile.totalMoney)
--	end)

--	Remotes.RequestLeaderboard.OnServerEvent:Connect(function(player)
--		Remotes.LeaderboardState:FireClient(player, LeaderboardService.snapshot())
--	end)

--	task.spawn(function()
--		while true do
--			if storesOk then
--				for id, board in boards do
--					refresh(board)
--					renderSign(board, id)
--				end
--				broadcast()
--			elseif signsDirty then
--				-- Availability just flipped; repaint once so the boards stop
--				-- claiming there are simply no scores.
--				signsDirty = false
--				for id, board in boards do
--					renderSign(board, id)
--				end
--				broadcast()
--			end
--			task.wait(if storesOk then REFRESH_INTERVAL else 5)
--		end
--	end)

--	-- Probe once at startup so the boards learn their true state promptly
--	-- instead of after a full refresh interval.
--	task.spawn(function()
--		task.wait(2)
--		for _, board in boards do
--			refresh(board)
--		end
--		for id, board in boards do
--			renderSign(board, id)
--		end
--		broadcast()
--	end)

--	-- Write on leave too, in case the last improvement fell inside the
--	-- cooldown window.
--	Players.PlayerRemoving:Connect(function(player)
--		if Profiles.has(player) then
--			local profile = Profiles.get(player)
--			if profile.loaded then
--				write(boards.distance, player, profile.bestDistance)
--				write(boards.money, player, profile.totalMoney)
--			end
--		end
--		nameCache[player.UserId] = nil
--	end)
--end

--return LeaderboardService


-- Legacy boards are intentionally disabled. Keep the bootstrap contract so
-- disabling their UI does not prevent unrelated gameplay services starting.
return {
	start = function() end,
}
