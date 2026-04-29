assert(queue_on_teleport, "Your executor does not support this method.")

local Queue = {}
local LocalPlayer = game:GetService("Players").LocalPlayer
local Source = nil
local isConnected = {false, conn = nil}

function Queue:SetSource(vararg)
	if type(vararg) ~= "string" or vararg == "" then return end
	Source = vararg
end

function Queue:GetSource()
	return Source
end

function Queue:Connect()
	if isConnected[1] == true then return end
	isConnected[1] = true
	isConnected.conn = LocalPlayer.OnTeleport:Connect(function(TeleportState)
		if TeleportState == Enum.TeleportState.Started then
			queue_on_teleport(Source)
		end
	end)
end

function Queue:Disconnect()
	if isConnected[1] == false then return end
	isConnected.conn:Disconnect()
	isConnected[1] = false
	isConnected.conn = nil
end

return Queue
