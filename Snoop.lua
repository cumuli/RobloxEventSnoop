--
--	Snoop
--
--	Copyright 2024 by Fletcher Sandbeck
--	
--	Author: Fletcher Sandbeck, Cumuli, Inc.
--	Email: fletc3her@gmail.com
--	Release: 2024-07-08
--	License: MIT License
--
--	This script searches for RemoteEvents and BindableEvents and listens to all of them.
--
--	Installation - For best results place as a script in ReplicatedFirst and set the RunContext to "Server" or "Client".
--	The script can otherwise be placed anywhere it will run in the context you want to observe.
--
--	The script can be configured by changing the following preferences:

--	All reports will be preceded by this Name.
local Name = "Snoop"

--	If true (recommended) then this script will only run in studio, not in production.
local StudioOnly = true

--	Targets - By default this script listens to events in several global locations.
--	Comments can be used to control whether events in Players or Workspace are also listened for.
--	Constraining the targets to a single folder or individual events can be used to only
--	listen to select events.
local Targets = {
	game:GetService("ReplicatedFirst"), -- Find events in ReplicatedFirst
	game:GetService("ReplicatedStorage"), -- Find events in ReplicatedStorage
	game:GetService("Players"), -- Each Players folder
	workspace, -- Includes each Character folder
	--MyEvent, -- Alternately, list individual events
}

--	Types - By default listens to the client side of both BindableEvents and RemoteEvents.
--	Comments can be used to restrict to one or the other.
local Types = {
	"BindableEvent",
	"RemoteEvent",
}

--	Ignore strings will filter out any events which have that string as part of their name.
--	Supports pattern matching https://create.roblox.com/docs/luau/strings#string-pattern-reference
--	Ignore Instances will filter out specific events or any descendants of that Instance.
local Ignores = {
	--"LoudEvent", -- Filters instances with this string in their names
	--ReplicatedStorage.Folder, -- Filters instances in this particular folder
	--MyEvent, -- Filter out specific events
}

--	Sets the log level of each output to print/warn/nil
--	Note that the actual function is named here without quotes
--	Use nil to suppress output
local EventLog = print -- print/warn/nil (Default print)
local SummaryLog = print -- print/warn/nil (Default print)
local WelcomeLog = warn -- print/warn/nil (Default warn)

local RunService = game:GetService("RunService")

if StudioOnly and not RunService:IsStudio() then
	return
end

local IsClient = RunService:IsClient()
local IsServer = RunService:IsServer()

local Context
if IsClient then
	Context = game.Players.LocalPlayer.Name
elseif IsServer then
	Context = "Server"
end

if WelcomeLog then WelcomeLog(Name,"Listening For",Context,"Events") end

function Report(part,...)
	if not part then return end
	if EventLog then EventLog(Name,Context,part,...) end
end

--	Listens to a part only if is passes the rules
function Listen(part)
	if not part then return end	
	if table.find(Types,part.ClassName) then
		local ignore = false
		for _,rule in ipairs(Ignores) do
			if ignore then continue end
			if type(rule) == "string" then
				ignore = string.find(part.Name,rule)
			elseif typeof(rule) == "Instance" then
				ignore = (rule == part) or part:IsDescendantOf(rule)
			end
		end
		if ignore then
			return part, nil
		else
			if part:IsA("BindableEvent") then
				return part, part.Event:Connect(function(...)
					Report(part,...)
				end)
			elseif part:IsA("RemoteEvent") then
				if IsClient then
					return part, part.OnClientEvent:Connect(function(...)
						Report(part,...)
					end)	
				elseif IsServer then
					return part, part.OnServerEvent:Connect(function(...)
						Report(part,...)
					end)	
				end
			end
		end
	end
end

--	Periodically reports new Listens
--	Also maintains a list of _connections
local _lastsummary = os.clock()
local _listens = {}
local _ignores = {}
local _connections = {}
function SummarizeNow()
	_lastsummary = os.clock()
	if #_listens > 0 then
		if SummaryLog then SummaryLog(Name,Context,"Listens",_listens) end
		_listens = {}
	end	
	if #_ignores > 0 then
		if SummaryLog then SummaryLog(Name,Context,"Ignores",_ignores) end
		_ignores = {}
	end	
end
function Summarize(part,conn)
	if part then
		if conn then
			table.insert(_listens,part)
			_connections[part] = conn
		else
			table.insert(_ignores,part)
		end
	end
	if os.clock() < _lastsummary + 0.25 then return end
	task.delay(0.25,SummarizeNow)	
end

--	Check all target Descendants and listen for new Descendants
for _,target in ipairs(Targets) do
	-- Check targets directly to support individual events
	Summarize(Listen(target))
	-- Check all descendants of each target
	for _,part in ipairs(target:GetDescendants()) do
		Summarize(Listen(part))
	end
	-- Force first report
	SummarizeNow()
	-- Listen for any descendants added to targets	
	target.DescendantAdded:Connect(function(part)
		Summarize(Listen(part))
	end)
	-- Clean up connections when parts move or are destroyed
	target.DescendantRemoving:Connect(function(part)
		_connections[part] = nil
	end)
end
