require 'utils'
local skynet = require "skynet"
local size
local player = {}
local json = require "json"
local CMD = {}
local cache = {}

function CMD.enter(agent, client_fd)
    print('agent, client_fd', agent, client_fd)
   
    for k, _agent in pairs (player) do 
        if _agent == agent then 
            table.remove(player, k)
            break
        end
    end 
    table.insert(player, agent)

	for k, agent in pairs(player) do
		skynet.call(agent, "lua","send","EnterRoom", {result=true, client=client_fd})
	end	
end

function CMD.UpdateRoomVar(agent, var)
	local tb = json.decode(var)
	local key = tb.k
	local value = tb.v
	local sendValue = {k=key, v=value}
	for k, agent in pairs(player) do
		skynet.call(agent, "lua","send","UpdateRoomVar", sendValue)
	end	
end 

function CMD.exit(agent)
    for k, _agent in pairs (player) do 
        if _agent == agent then 
            table.remove(player, k)
            break
        end
    end 
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
	size = 0
end)
