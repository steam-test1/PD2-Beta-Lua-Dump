ClientNetworkSession = ClientNetworkSession or class(BaseNetworkSession)
ClientNetworkSession.HOST_SANITY_CHECK_INTERVAL = 4
ClientNetworkSession.HOST_REQUEST_JOIN_INTERVAL = 2
function ClientNetworkSession:request_join_host(host_rpc, result_cb)
	print("[ClientNetworkSession:request_join_host]", host_rpc, result_cb)
	self._cb_find_game = result_cb
	local host_name = managers.network.matchmake:game_owner_name()
	local host_user_id = SystemInfo:platform() == self._ids_WIN32 and host_rpc:ip_at_index(0) or false
	local id, peer = self:add_peer(host_name, nil, nil, nil, nil, 1, nil, host_user_id, "", "")
	if SystemInfo:platform() == self._ids_WIN32 then
		peer:set_steam_rpc(host_rpc)
	end
	self._server_peer = peer
	Network:set_multiplayer(true)
	Network:set_client(host_rpc)
	local request_rpc = SystemInfo:platform() == self._ids_WIN32 and peer:steam_rpc() or host_rpc
	local xuid = SystemInfo:platform() == Idstring("X360") and managers.network.account:player_id() or ""
	local lvl = managers.experience:current_level()
	local gameversion = managers.network.matchmake.GAMEVERSION or -1
	local join_req_id = self:_get_join_attempt_identifier()
	self._join_request_params = {
		host_rpc = request_rpc,
		params = {
			self._local_peer:name(),
			managers.blackmarket:get_preferred_character(),
			managers.dlc:dlcs_string(),
			xuid,
			lvl,
			gameversion,
			join_req_id
		}
	}
	request_rpc:request_join(unpack(self._join_request_params.params))
	self._last_join_request_t = TimerManager:wall():time()
end
function ClientNetworkSession:on_join_request_reply(reply, my_peer_id, my_character, level_index, difficulty_index, state_index, server_character, user_id, mission, job_id_index, job_stage, alternative_job_stage, interupt_job_stage_level_index, xuid, sender)
	print("[ClientNetworkSession:on_join_request_reply] ", self._server_peer and self._server_peer:user_id(), user_id, sender:ip_at_index(0), sender:protocol_at_index(0))
	if not self._server_peer or not self._cb_find_game then
		return
	end
	if self._server_peer:ip() and sender:ip_at_index(0) ~= self._server_peer:ip() then
		print("[ClientNetworkSession:on_join_request_reply] wrong host replied", self._server_peer:ip(), sender:ip_at_index(0))
		return
	end
	self._last_join_request_t = nil
	if SystemInfo:platform() == self._ids_WIN32 then
		if self._server_peer:user_id() and user_id ~= self._server_peer:user_id() then
			print("[ClientNetworkSession:on_join_request_reply] wrong host replied", self._server_peer:user_id(), user_id)
			return
		else
			if sender:protocol_at_index(0) == "STEAM" then
				self._server_protocol = "STEAM"
			else
				self._server_protocol = "TCP_IP"
			end
			print("self._server_protocol", self._server_protocol)
			self._server_peer:set_rpc(sender)
			self._server_peer:set_ip_verified(true)
			Network:set_client(sender)
		end
	else
		self._server_protocol = "TCP_IP"
		self._server_peer:set_rpc(sender)
		self._server_peer:set_ip_verified(true)
		Network:set_client(sender)
	end
	local cb = self._cb_find_game
	self._cb_find_game = nil
	if reply == 1 then
		self._host_sanity_send_t = TimerManager:wall():time() + self.HOST_SANITY_CHECK_INTERVAL
		Global.game_settings.level_id = tweak_data.levels:get_level_name_from_index(level_index)
		Global.game_settings.difficulty = tweak_data:index_to_difficulty(difficulty_index)
		Global.game_settings.mission = mission
		self._server_peer:set_character(server_character)
		self._server_peer:set_xuid(xuid)
		if SystemInfo:platform() == Idstring("X360") then
			local xnaddr = managers.network.matchmake:external_address(self._server_peer:rpc())
			self._server_peer:set_xnaddr(xnaddr)
			managers.network.matchmake:on_peer_added(self._server_peer)
		end
		self._local_peer:set_id(my_peer_id)
		self._local_peer:set_character(my_character)
		self._server_peer:set_id(1)
		self._server_peer:set_in_lobby_soft(state_index == 1)
		self._server_peer:set_synched_soft(state_index ~= 1)
		if SystemInfo:platform() == Idstring("PS3") then
		end
		if job_id_index ~= 0 then
			local job_id = tweak_data.narrative:get_job_name_from_index(job_id_index)
			managers.job:activate_job(job_id, job_stage)
			if alternative_job_stage ~= 0 then
				managers.job:synced_alternative_stage(alternative_job_stage)
			end
			if interupt_job_stage_level_index ~= 0 then
				local interupt_level = tweak_data.levels:get_level_name_from_index(interupt_job_stage_level_index)
				managers.job:synced_interupt_stage(interupt_level)
			end
		end
		cb(state_index == 1 and "JOINED_LOBBY" or "JOINED_GAME", level_index, difficulty_index, state_index)
	elseif reply == 2 then
		self:remove_peer(self._server_peer, 1)
		cb("KICKED")
	elseif reply == 0 then
		self:remove_peer(self._server_peer, 1)
		cb("FAILED_CONNECT")
	elseif reply == 3 then
		self:remove_peer(self._server_peer, 1)
		cb("GAME_STARTED")
	elseif reply == 4 then
		self:remove_peer(self._server_peer, 1)
		cb("DO_NOT_OWN_HEIST")
	elseif reply == 5 then
		self:remove_peer(self._server_peer, 1)
		cb("GAME_FULL")
	elseif reply == 6 then
		self:remove_peer(self._server_peer, 1)
		cb("LOW_LEVEL")
	elseif reply == 7 then
		self:remove_peer(self._server_peer, 1)
		cb("WRONG_VERSION")
	end
end
function ClientNetworkSession:on_join_request_timed_out()
	local cb = self._cb_find_game
	self._cb_find_game = nil
	cb("TIMED_OUT")
end
function ClientNetworkSession:on_join_request_cancelled()
	local cb = self._cb_find_game
	if cb then
		self._cb_find_game = nil
		if self._server_peer then
			self:remove_peer(self._server_peer, 1)
		end
		cb("CANCELLED")
	end
end
function ClientNetworkSession:discover_hosts()
	self._discovered_hosts = {}
	Network:broadcast(NetworkManager.DEFAULT_PORT):discover_host()
end
function ClientNetworkSession:on_host_discovered(new_host, new_host_name, level_name, my_ip, state, difficulty)
	if self._discovered_hosts then
		local new_host_data = {
			rpc = new_host,
			host_name = new_host_name,
			level_name = level_name,
			my_ip = my_ip,
			state = state,
			difficulty = difficulty
		}
		local already_known
		for i_host, host_data in ipairs(self._discovered_hosts) do
			if host_data.host_name == new_host_name and host_data.rpc:ip_at_index(0) == new_host:ip_at_index(0) then
				self._discovered_hosts[i_host] = new_host_data
				already_known = true
			else
			end
		end
		if not already_known then
			table.insert(self._discovered_hosts, new_host_data)
		end
	end
end
function ClientNetworkSession:on_server_up_received(host_rpc)
	if self._discovered_hosts then
		host_rpc:request_host_discover_reply()
	end
end
function ClientNetworkSession:discovered_hosts()
	return self._discovered_hosts
end
function ClientNetworkSession:send_to_host(...)
	if self._server_peer then
		self._server_peer:send(...)
	else
		print("[ClientNetworkSession:send_to_host] no host")
	end
end
function ClientNetworkSession:is_host()
	return false
end
function ClientNetworkSession:is_client()
	return true
end
function ClientNetworkSession:load_level(...)
	self:_load_level(...)
end
function ClientNetworkSession:load_lobby(...)
	self:_load_lobby(...)
end
function ClientNetworkSession:peer_handshake(name, peer_id, peer_user_id, in_lobby, loading, synched, character, mask_set, xuid, xnaddr)
	print("ClientNetworkSession:peer_handshake", name, peer_id, peer_user_id, in_lobby, loading, synched, character, mask_set, xuid, xnaddr)
	if self._peers[peer_id] then
		print("ALREADY HAD PEER returns here")
		local peer = self._peers[peer_id]
		if peer:ip_verified() then
			self._server_peer:send("connection_established", peer_id)
		end
		return
	end
	local rpc
	if self._server_protocol == "STEAM" then
		rpc = Network:handshake(peer_user_id, nil, "STEAM")
		Network:add_co_client(rpc)
	end
	if SystemInfo:platform() == Idstring("X360") then
		local ip = managers.network.matchmake:internal_address(xnaddr)
		rpc = Network:handshake(ip, managers.network.DEFAULT_PORT, "TCP_IP")
		Network:add_co_client(rpc)
	end
	if SystemInfo:platform() ~= self._ids_WIN32 or not peer_user_id then
		peer_user_id = false
	end
	local id, peer = self:add_peer(name, rpc, in_lobby, loading, synched, peer_id, character, peer_user_id, xuid, xnaddr)
	cat_print("multiplayer_base", "[ClientNetworkSession:peer_handshake]", name, peer_user_id, loading, synched, id, inspect(peer))
	local check_peer = SystemInfo:platform() == Idstring("X360") and peer or nil
	self:chk_send_connection_established(name, peer_user_id, check_peer)
	if managers.trade then
		managers.trade:handshake_complete(peer_id)
	end
end
function ClientNetworkSession:on_PSN_connection_established(name, ip)
	if SystemInfo:platform() ~= Idstring("PS3") then
		return
	end
	self:chk_send_connection_established(name, nil, false)
end
function ClientNetworkSession:on_peer_synched(peer_id)
	local peer = self._peers[peer_id]
	if not peer then
		cat_error("multiplayer_base", "[ClientNetworkSession:on_peer_synched] Unknown Peer:", peer_id)
		return
	end
	peer:set_loading(false)
	peer:set_synched(true)
	managers.network:game():on_peer_sync_complete(peer, peer_id)
end
function ClientNetworkSession:ok_to_load_level()
	print("[ClientNetworkSession:ok_to_load_level]", self._recieved_ok_to_load_level, self._local_peer:id())
	if self._closing then
		return
	end
	self:send_to_host("set_loading_state", true)
	if self._recieved_ok_to_load_level then
		print("Allready recieved ok to load level, returns")
		return
	end
	self._recieved_ok_to_load_level = true
	if managers.menu:active_menu() then
		managers.menu:close_menu()
	end
	managers.system_menu:force_close_all()
	local level_id = Global.game_settings.level_id
	local level_name = level_id and tweak_data.levels[level_id].world_name
	local mission = Global.game_settings.mission ~= "none" and Global.game_settings.mission or nil
	managers.network:session():load_level(level_name, mission, nil, nil, level_id)
end
function ClientNetworkSession:ok_to_load_lobby()
	print("[ClientNetworkSession:ok_to_load_lobby]", self._recieved_ok_to_load_lobby, self._local_peer:id())
	if self._closing then
		return
	end
	if self:_local_peer_in_lobby() then
		return
	end
	self:send_to_host("set_loading_state", true)
	if self._recieved_ok_to_load_lobby then
		print("Allready recieved ok to load lobby, returns")
		return
	end
	self._recieved_ok_to_load_lobby = true
	if managers.menu:active_menu() then
		managers.menu:close_menu()
	end
	managers.system_menu:force_close_all()
	managers.network:session():load_lobby()
end
function ClientNetworkSession:on_mutual_connection(other_peer_id)
	local other_peer = self._peers[other_peer_id]
	if not other_peer then
		return
	end
	if self._local_peer:loaded() and other_peer:ip_verified() then
		other_peer:send_after_load("set_member_ready", self._local_peer:waiting_for_player_ready())
	end
end
function ClientNetworkSession:on_peer_requested_info(peer_id)
	local other_peer = self._peers[peer_id]
	if not other_peer then
		return
	end
	other_peer:set_ip_verified(true)
	Global.local_member:sync_lobby_data(other_peer)
	Global.local_member:sync_data(other_peer)
	other_peer:send("set_loading_state", self._local_peer:loading())
	other_peer:send("peer_exchange_info", self._local_peer:id())
end
function ClientNetworkSession:update()
	ClientNetworkSession.super.update(self)
	if not self._closing then
		local wall_time = TimerManager:wall():time()
		if self._server_peer and self._host_sanity_send_t and wall_time > self._host_sanity_send_t then
			self._server_peer:send("sanity_check_network_status")
			self._host_sanity_send_t = wall_time + self.HOST_SANITY_CHECK_INTERVAL
		end
		self:_upd_request_join_resend(wall_time)
	end
end
function ClientNetworkSession:_soft_remove_peer(peer)
	ClientNetworkSession.super._soft_remove_peer(self, peer)
	if peer:id() == 1 then
		Network:set_disconnected()
	end
end
function ClientNetworkSession:on_peer_save_received(event, event_data)
	if managers.network:stopping() then
		return
	end
	local packet_index = event_data.index
	local total_nr_packets = event_data.total
	print("[ClientNetworkSession:on_peer_save_received]", packet_index, "/", total_nr_packets)
	local kit_menu = managers.menu:get_menu("kit_menu")
	if not kit_menu or not kit_menu.renderer:is_open() then
		return
	end
	if packet_index == total_nr_packets then
		local is_ready = self._local_peer:waiting_for_player_ready()
		if is_ready then
			kit_menu.renderer:set_slot_ready(self._local_peer, self._local_peer:id())
		else
			kit_menu.renderer:set_slot_not_ready(self._local_peer, self._local_peer:id())
		end
	else
		local progress_ratio = packet_index / total_nr_packets
		local progress_percentage = math.floor(math.clamp(progress_ratio * 100, 0, 100))
		managers.menu:get_menu("kit_menu").renderer:set_dropin_progress(self._local_peer:id(), progress_percentage)
	end
end
function ClientNetworkSession:is_expecting_sanity_chk_reply()
	return self._host_sanity_send_t and true
end
function ClientNetworkSession:load(data)
	ClientNetworkSession.super.load(self, data)
end
function ClientNetworkSession:on_load_complete()
	ClientNetworkSession.super.on_load_complete(self)
	self._host_sanity_send_t = TimerManager:wall():time() + self.HOST_SANITY_CHECK_INTERVAL
end
function ClientNetworkSession:_get_join_attempt_identifier()
	if not self._join_attempt_identifier then
		self._join_attempt_identifier = math.random(1, 65536)
	end
	return self._join_attempt_identifier
end
function ClientNetworkSession:_upd_request_join_resend(wall_time)
	if self._last_join_request_t and wall_time - self._last_join_request_t > ClientNetworkSession.HOST_REQUEST_JOIN_INTERVAL then
		self._join_request_params.host_rpc:request_join(unpack(self._join_request_params.params))
		self._last_join_request_t = wall_time
	end
end
