local json = require "json"

local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"

local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}
local client_fd

function REQUEST:get()
	print("get", self.what)
	local r = skynet.call("SIMPLEDB", "lua", "get", self.what)
	return { result = r }
end

function REQUEST:set()
	print("set", self.what, self.value)
	local r = skynet.call("SIMPLEDB", "lua", "set", self.what, self.value)
end

function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", client_fd)
end

local function request(name, args, response)
	local f = assert(REQUEST[name])
	local r = f(args)
	if response then
		return response(r)
	end
end

local function send_package(key, value)
    local value = json.encode(value)
    local buf = string.pack(">I4",#key)..key..string.char(0)..string.pack(">I4",#value)..value
	local package = string.pack(">s2", buf)
	socket.write(client_fd, package)
end


skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		msg = skynet.tostring(msg,sz)
		local name_size = string.unpack(">I4",msg)
		local name = string.sub(msg,5,name_size + 4)
		local isCompress = string.sub(msg,name_size+5,1)
		local msg_size = string.unpack(">I4",msg,name_size + 6)
		local msg = string.sub(msg,name_size+10) 
		return name,msg
	end,
	dispatch = function (_, _, name, msg)
		local room = skynet.uniqueservice("room")
        if name == 'EnterRoom' then 
	        skynet.call(room,"lua","enter", skynet.self(), client_fd)
		elseif name == 'UpdateRoomVar' then 
			skynet.call(room,"lua","UpdateRoomVar", skynet.self(), msg)
        end 
	end
}

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	skynet.fork(function()
		while true do
            send_package('heartbeat', 'heartbeat')
			skynet.sleep(5000)
		end
	end)
	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	local room = skynet.uniqueservice("room")
	skynet.call(room,"lua","exit",skynet.self())
	skynet.exit()
end

function CMD.send(key, value)
    send_package(key, value)
end 

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)

