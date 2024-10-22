NetworkMatchMakingPSN = NetworkMatchMakingPSN or class()
NetworkMatchMakingPSN.OPEN_SLOTS = 4
NetworkMatchMakingPSN.MAX_SEARCH_RESULTS = 20
function NetworkMatchMakingPSN:init()
	cat_print("lobby", "matchmake = NetworkMatchMakingPSN")
	self._players = {}
	self._TRY_TIME_INC = 10
	self._JOIN_SERVER_TRY_TIME_INC = 20
	self._room_id = nil
	self._join_cb_room = nil
	self._server_rpc = nil
	self._is_server_var = false
	self._is_client_var = false
	self._difficulty_filter = 0
	self._private = false
	self._callback_map = {}
	self._hidden = false
	self._server_joinable = true
	self._connection_info = {}
	local function f(info)
		self:_error_cb(info)
	end
	PSN:set_matchmaking_callback("error", f)
	self:_load_globals()
	self._cancelled = false
	self._peer_join_request_remove = {}
	local function f(...)
		self:_custom_message_cb(...)
	end
	PSN:set_matchmaking_callback("custom_message", f)
	PSN:set_matchmaking_callback("invitation_received_result", callback(self, self, "_invitation_received_result_cb"))
	PSN:set_matchmaking_callback("join_invite_accepted_xmb", callback(self, self, "_xmb_join_invite_cb"))
	PSN:set_matchmaking_callback("worlds_fetched", callback(self, self, "_worlds_fetched_cb"))
	local function js(...)
		self:cb_connection_established(...)
	end
	PSN:set_matchmaking_callback("connection_etablished", js)
end
function NetworkMatchMakingPSN:_xmb_join_invite_cb(message)
	local ok_func = function()
		if managers.network.account:signin_state() == "not signed in" then
			managers.network.account:show_signin_ui()
		end
	end
	managers.menu:show_invite_join_message({ok_func = ok_func})
end
function NetworkMatchMakingPSN:start_server_time_out_check()
	PSN:set_matchmaking_callback("fetch_session_attributes", callback(self, self, "_server_time_out_check_cb"))
	self:_trigger_time_out_check()
end
function NetworkMatchMakingPSN:_trigger_time_out_check()
	self._next_time_out_check_t = Application:time() + 4
	self._testing_connection = true
	PSN:get_session_attributes({
		self._room_id
	}, {
		numbers = {
			1,
			2,
			3,
			4,
			5,
			6,
			7,
			8
		}
	})
end
function NetworkMatchMakingPSN:_server_time_out_check_cb()
	self._server_last_alive_t = Application:time()
	self._testing_connection = nil
end
function NetworkMatchMakingPSN:_worlds_fetched_cb(...)
	print("_worlds_fetched_cb")
	self._getting_world_list = nil
	managers.system_menu:close("get_world_list")
	if Global.boot_invite and Global.boot_invite.pending then
		self:join_boot_invite()
	end
end
function NetworkMatchMakingPSN:_getting_world_list_failed()
	print("failed_getting_world_list")
	managers.menu:back(true)
	managers.menu:show_no_connection_to_game_servers_dialog()
	self:_worlds_fetched_cb()
end
function NetworkMatchMakingPSN:getting_world_list()
	print("getting_world_list")
	self._getting_world_list = true
	managers.menu:show_get_world_list_dialog({
		cancel_func = callback(self, self, "_getting_world_list_failed")
	})
end
function NetworkMatchMakingPSN:_session_destroyed_cb(room_id, ...)
	print("NetworkMatchMakingPSN:_session_destroyed_cb", room_id, ...)
	cat_print("lobby", "NetworkMatchMakingPSN:_session_destroyed_cb")
	if room_id == self._room_id then
		if not self._is_server_var then
			managers.network:queue_stop_network()
			PSN:leave_session(self._room_id)
			self._room_id = nil
			self:leave_game()
		end
		self._room_id = nil
		if Network:is_client() and managers.network:session() and managers.network:session():server_peer() then
			if game_state_machine:current_state().on_server_left then
				Global.on_server_left_message = "dialog_connection_to_host_lost"
				game_state_machine:current_state():on_server_left()
			end
		elseif self._joining_lobby then
			self:_error_cb({error = "80022b13"})
		end
	end
	self._skip_destroy_cb = nil
end
function NetworkMatchMakingPSN:room_id()
	return self._room_id
end
function NetworkMatchMakingPSN:create_private_game(settings)
	self._cancelled = false
	self._private = true
	if Global.psn_invite_id then
		Global.psn_invite_id = Global.psn_invite_id + 1
		if Global.psn_invite_id > 990 then
			Global.psn_invite_id = 1
		end
	end
	self._last_settings = settings
	self:_create_server(true)
end
function NetworkMatchMakingPSN:cancel_find()
	self._cancelled = true
	self._is_server_var = false
	self._is_client_var = false
	self._players = {}
	self._server_rpc = nil
	self._try_list = nil
	self._try_index = nil
	self._trytime = nil
	self:destroy_game()
	self._room_id = nil
	if managers.network.group:room_id() then
		managers.network.voice_chat:open_session(managers.network.group:room_id())
	end
	if not self._join_cb_room then
		self:_call_callback("cancel_done")
	else
		self._cancel_time = TimerManager:wall():time() + 10
	end
end
function NetworkMatchMakingPSN:remove_ping_watch()
	if self:_is_client() then
		if self._server_rpc then
		end
	else
		for k, v in pairs(self._players) do
			if v.rpc then
			end
		end
	end
end
function NetworkMatchMakingPSN:leave_game()
	local sent = false
	self:remove_ping_watch()
	self._server_last_alive_t = nil
	self._next_time_out_check_t = nil
	PSN:set_matchmaking_callback("fetch_session_attributes", function()
	end)
	if self:_is_client() then
		if self._server_rpc then
			sent = true
		end
		if managers.network.group:_is_client() then
			self:_call_callback("group_leader_left_match")
		end
	else
		for k, v in pairs(self._players) do
			if v.rpc then
				sent = true
			end
		end
	end
	if sent == true then
		if self._room_id then
			local dialog_data = {}
			dialog_data.title = managers.localization:text("dialog_leaving_lobby_title")
			dialog_data.text = managers.localization:text("dialog_wait")
			dialog_data.id = "leaving_game"
			dialog_data.no_buttons = true
			managers.system_menu:show(dialog_data)
		end
		self._leave_time = TimerManager:wall():time() + 2
	else
		self._leave_time = TimerManager:wall():time() + 0
	end
end
function NetworkMatchMakingPSN:register_callback(event, callback)
	self._callback_map[event] = callback
end
function NetworkMatchMakingPSN:join_game(id, private)
end
function NetworkMatchMakingPSN:start_game()
end
function NetworkMatchMakingPSN:end_game()
end
function NetworkMatchMakingPSN:destroy_game()
	if self._room_id then
		if self:_is_client() then
			PSN:leave_session(self._room_id)
		else
			self._server_last_alive_t = nil
			self._next_time_out_check_t = nil
			PSN:set_matchmaking_callback("fetch_session_attributes", function()
			end)
			PSN:destroy_session(self._room_id)
		end
	else
		cat_print("multiplayer", "Dont got a room id!?")
	end
end
function NetworkMatchMakingPSN:is_game_owner()
	return self:_is_server() == true
end
function NetworkMatchMakingPSN:game_owner_name()
	return tostring(self._game_owner_id)
end
function NetworkMatchMakingPSN:is_full()
	if #self._players == self.OPEN_SLOTS - 1 then
		return true
	end
	return false
end
function NetworkMatchMakingPSN:get_mm_id(name)
	if name == managers.network.account:username() then
		return managers.network.account:player_id()
	else
		for k, v in pairs(self._players) do
			if v.name == name then
				return v.pnid
			end
		end
	end
	return nil
end
function NetworkMatchMakingPSN:user_in_lobby(id)
	if not self._room_id then
		return false
	end
	local memberlist = PSN:get_info_session(self._room_id).memberlist
	for _, member in ipairs(memberlist) do
		if member.user_id == id then
			return true
		end
	end
	return false
end
function NetworkMatchMakingPSN:update(time)
	if self._no_longer_in_session then
		if self._no_longer_in_session == 0 then
			if Network:is_client() and managers.network:session() and managers.network:session():server_peer() then
				if game_state_machine:current_state().on_server_left then
					Global.on_server_left_message = "dialog_connection_to_host_lost"
					game_state_machine:current_state():on_server_left()
				end
			elseif Network:is_server() and managers.network:session() and game_state_machine:current_state().on_disconnected then
				game_state_machine:current_state():on_disconnected()
			end
			self._no_longer_in_session = nil
		else
			self._no_longer_in_session = self._no_longer_in_session - 1
		end
	end
	if self._is_server_var then
		if self._server_last_alive_t and self._server_last_alive_t + 20 < Application:time() then
			self._server_last_alive_t = nil
			if managers.network:session() and managers.network:session():_local_peer_in_lobby() then
				managers.menu:psn_disconnected()
			elseif managers.network:game() then
				managers.network:game():psn_disconnected()
			end
		elseif self._next_time_out_check_t and self._next_time_out_check_t < Application:time() then
			self:_trigger_time_out_check()
		end
	end
	if self._trytime and TimerManager:wall():time() > self._trytime then
		self._trytime = nil
		print("self._trytime run out!", inspect(self))
		do
			local is_server = self._is_server_var
			self._is_server_var = false
			self._is_client_var = false
			managers.platform:set_presence("Signed_in")
			self._players = {}
			self._server_rpc = nil
			if self._joining_lobby then
				self:_error_cb({error = "8002231d"})
			end
			if self._room_id then
				if not is_server then
					print(" LEAVE SESSION BECAUSE OF TIME OUT", self._room_id)
					self:leave_game()
				end
			elseif not self._last_settings then
				self:_call_callback("cancel_done")
			end
		end
	else
	end
	if self._leave_time and TimerManager:wall():time() > self._leave_time then
		local closed = false
		if self._room_id then
			closed = true
			if PSN:is_online() and managers.network.group:room_id() then
				managers.network.voice_chat:open_session(managers.network.group:room_id())
			end
			if not self._call_server_timed_out then
				self._leaving_timer = TimerManager:wall():time() + 10
			end
			if self:_is_client() then
				print("leave session HERE")
				PSN:leave_session(self._room_id)
			else
				PSN:destroy_session(self._room_id)
			end
		end
		self._players = {}
		self._game_owner_id = nil
		self._server_rpc = nil
		self._leave_time = nil
		self._is_client_var = false
		self._is_server_var = false
		if self._call_server_timed_out == true then
			self._call_server_timed_out = nil
			self:_call_callback("server_timedout")
		elseif closed == false then
			print("left game callback")
			managers.system_menu:close("leaving_game")
			if self._invite_room_id then
				self:join_server_with_check(self._invite_room_id, true)
			end
			self:_call_callback("left_game")
		end
	end
	if self._leaving_timer and TimerManager:wall():time() > self._leaving_timer then
		print("self._leaving_timer left_game")
		self._room_id = nil
		self._leaving_timer = nil
		self:_call_callback("left_game")
	end
	if self._cancel_time and TimerManager:wall():time() > self._cancel_time then
		self._cancel_time = nil
		self._join_cb_room = nil
		self:_call_callback("cancel_done")
	end
end
function NetworkMatchMakingPSN:_load_globals()
	if Global.psn and Global.psn.match then
		self._game_owner_id = Global.psn.match._game_owner_id
		self._room_id = Global.psn.match._room_id
		self._is_server_var = Global.psn.match._is_server
		self._is_client_var = Global.psn.match._is_client
		self._players = Global.psn.match._players
		self._server_rpc = Global.psn.match._server_ip and Network:handshake(Global.psn.match._server_ip, nil, "TCP_IP")
		self._attributes_numbers = Global.psn.match._attributes_numbers
		self._connection_info = Global.psn.match._connection_info
		self._hidden = Global.psn.match._hidden
		self._num_players = Global.psn.match._num_players
		Global.psn.match = nil
		if self._is_server_var then
			self:start_server_time_out_check()
		end
		if self._room_id then
			local info_session = PSN:get_info_session(self._room_id)
			if not info_session or #info_session.memberlist == 0 then
				self._no_longer_in_session = 1
			end
		end
	end
end
function NetworkMatchMakingPSN:_save_globals()
	if not Global.psn then
		Global.psn = {}
	end
	Global.psn.match = {}
	Global.psn.match._game_owner_id = self._game_owner_id
	Global.psn.match._room_id = self._room_id
	Global.psn.match._is_server = self._is_server_var
	Global.psn.match._is_client = self._is_client_var
	Global.psn.match._players = self._players
	Global.psn.match._server_ip = self._server_rpc and self._server_rpc:ip_at_index(0)
	Global.psn.match._attributes_numbers = self._attributes_numbers
	Global.psn.match._connection_info = self._connection_info
	Global.psn.match._hidden = self._hidden
	Global.psn.match._num_players = self._num_players
end
function NetworkMatchMakingPSN:_call_callback(name, ...)
	if self._callback_map[name] then
		return self._callback_map[name](...)
	else
		Application:error("Callback " .. name .. " not found.")
	end
end
function NetworkMatchMakingPSN:_clear_psn_callback(cb)
	local f = function()
	end
	PSN:set_matchmaking_callback(cb, f)
end
function NetworkMatchMakingPSN:psn_member_joined(info)
	print("psn_member_joined")
	print(inspect(info))
	if info and info.room_id == self._room_id then
		if not self._private then
			managers.network.voice_chat:open_session(self._room_id)
		end
		if info.user_id == managers.network.account:player_id() then
		else
			local time_left = 10
		end
	end
	if Network:is_server() then
		self._peer_join_request_remove[tostring(info.user_id)] = nil
		print("   remove from remove list", tostring(info.user_id))
	end
end
function NetworkMatchMakingPSN:psn_member_left(info)
	if info and info.room_id == self._room_id then
		if info.user_id == managers.network.account:player_id() then
			print("IT WAS ME WHO LEFT")
			self._skip_destroy_cb = true
			self._connection_info = {}
			managers.platform:set_presence("Signed_in")
			managers.system_menu:close("leaving_game")
			if self._try_time then
				self._trytime = nil
				if not self._last_settings then
					self:_call_callback("cancel_done")
				else
				end
				if self._invite_room_id then
					self:join_server_with_check(room_id, true)
				end
				return
			end
			if self._leaving_timer then
				self._room_id = nil
				self._leaving_timer = nil
				self:_call_callback("left_game")
				if self._invite_room_id then
					self:join_server_with_check(room_id, true)
				end
				return
			end
		else
			print("SOMEONE ELSE LEFT", info.user_id)
			local user_name = tostring(info.user_id)
			self:_remove_peer_by_user_id(info.user_id)
			if self:_is_server() then
				self:_call_callback("remove_reservation", info.user_id)
			end
		end
	end
end
function NetworkMatchMakingPSN:_remove_peer_by_user_id(user_id)
	self._connection_info[user_id] = nil
	if not managers.network:session() then
		return
	end
	local user_name = tostring(user_id)
	for pid, peer in pairs(managers.network:session():peers()) do
		if peer:name() == user_name then
			print(" _remove_peer_by_user_id on_peer_left", peer:id(), pid)
			managers.network:session():on_peer_left(peer, pid)
			return
		end
	end
	if Network:is_server() then
		self._peer_join_request_remove[user_id] = true
		print("queue to remove if we get a request", user_id)
	end
end
function NetworkMatchMakingPSN:check_peer_join_request_remove(user_id)
	local has = self._peer_join_request_remove[user_id]
	self._peer_join_request_remove[user_id] = nil
	return has
end
function NetworkMatchMakingPSN:_is_server(set)
	if set == true or set == false then
		self._is_server_var = set
	else
		return self._is_server_var
	end
end
function NetworkMatchMakingPSN:_is_client(set)
	if set == true or set == false then
		self._is_client_var = set
	else
		return self._is_client_var
	end
end
function NetworkMatchMakingPSN:_game_version()
	return managers.dlc:is_trial() and 7 or 8
end
function NetworkMatchMakingPSN:create_lobby(settings)
	print("NetworkMatchMakingPSN:create_group_lobby()", inspect(settings))
	self._server_joinable = true
	self._num_players = nil
	self._server_rpc = nil
	self._players = {}
	self._peer_join_request_remove = {}
	local world_list = PSN:get_world_list()
	local session_created = function(roomid)
		managers.network.matchmake:_created_lobby(roomid)
	end
	PSN:set_matchmaking_callback("session_created", session_created)
	if not settings or not settings.numbers then
		local numbers = {
			2,
			3,
			1,
			1,
			1,
			1,
			0,
			1
		}
	end
	numbers[4] = 1
	numbers[5] = self:_game_version()
	numbers[8] = 1
	local table_description = {numbers = numbers}
	self._attributes_numbers = numbers
	local dialog_data = {}
	dialog_data.title = managers.localization:text("dialog_creating_lobby_title")
	dialog_data.text = managers.localization:text("dialog_wait")
	dialog_data.id = "create_lobby"
	dialog_data.no_buttons = true
	managers.system_menu:show(dialog_data)
	self._creating_lobby = true
	PSN:create_session(table_description, world_list[1].world_id, 0, self.OPEN_SLOTS, 0)
end
function NetworkMatchMakingPSN:_create_lobby_failed()
	self:_create_lobby_done()
end
function NetworkMatchMakingPSN:_create_lobby_done()
	self._creating_lobby = nil
	managers.system_menu:close("create_lobby")
end
function NetworkMatchMakingPSN:_created_lobby(room_id)
	self:_create_lobby_done()
	managers.menu:created_lobby()
	print("NetworkMatchMakingPSN:_created_lobby( room_id )", room_id)
	self._trytime = nil
	self:_is_server(true)
	self:_is_client(false)
	self._room_id = room_id
	managers.network.voice_chat:open_session(self._room_id)
	local playerinfo = {}
	playerinfo.name = managers.network.account:username()
	playerinfo.player_id = managers.network.account:player_id()
	playerinfo.group_id = tostring(managers.network.group:room_id())
	playerinfo.rpc = Network:self("TCP_IP")
	self:_call_callback("found_game", self._room_id, true)
	self:_call_callback("player_joined", playerinfo)
	self:start_server_time_out_check()
end
function NetworkMatchMakingPSN:searching_friends_only()
	return self._friends_only
end
function NetworkMatchMakingPSN:difficulty_filter()
	return self._difficulty_filter
end
function NetworkMatchMakingPSN:set_difficulty_filter(filter)
	self._difficulty_filter = filter
end
function NetworkMatchMakingPSN:start_search_lobbys(friends_only)
	if self._searching_lobbys then
		return
	end
	self._searching_lobbys = true
	self._search_lobbys_index = 1
	self._lobbys_info_list = {}
	self._friends_only = friends_only
	if not self._friends_only then
		local function f(info)
			table.insert(self._lobbys_info_list, info)
			if self._search_lobbys_index > 100 or #info.room_list == 0 then
				print("search done")
				self:_call_callback("search_lobby", self._lobbys_info_list)
			else
				self._search_lobbys_index = self._search_lobbys_index + self.MAX_SEARCH_RESULTS
				self:search_lobby()
				print("search again", self._search_lobbys_index)
			end
		end
		PSN:set_matchmaking_callback("session_search", f)
		self:search_lobby()
	else
		print("start_search_lobbys friends")
		local function f(results, ...)
			local room_ids = {}
			local info = {}
			info.attribute_list = {}
			info.request_id = 0
			info.room_list = {}
			local reverse_lookup = {}
			for i_user, user_info in ipairs(results.users) do
				if user_info.joined_sessions then
					local room_id = user_info.joined_sessions[1]
					table.insert(room_ids, room_id)
					local friend_id = user_info.user_id
					reverse_lookup[tostring(room_id)] = friend_id
				end
			end
			local function f2(results)
				if results.rooms then
					local info = {}
					info.attribute_list = {}
					info.request_id = 0
					info.room_list = {}
					table.insert(self._lobbys_info_list, info)
					for _, room_info in ipairs(results.rooms) do
						local attributes = room_info.attributes
						local full = room_info.full
						local closed = room_info.closed
						local owner_id = room_info.owner
						local room_id = room_info.room_id
						local friend_id = reverse_lookup[tostring(room_id)]
						if not full and not closed and attributes.numbers[5] == self:_game_version() then
							table.insert(info.attribute_list, attributes)
							table.insert(info.room_list, {
								owner_id = owner_id,
								friend_id = friend_id,
								room_id = room_id
							})
						end
					end
				end
				self:_call_callback("search_lobby", self._lobbys_info_list)
			end
			if #room_ids > 0 then
				PSN:set_matchmaking_callback("fetch_session_attributes", f2)
				local wanted_attributes = {
					numbers = {
						1,
						2,
						3,
						4,
						5,
						6,
						7,
						8
					}
				}
				PSN:get_session_attributes(room_ids, wanted_attributes)
			else
				self:_call_callback("search_lobby", self._lobbys_info_list)
			end
		end
		local friends = managers.network.friends:get_npid_friends_list()
		PSN:set_matchmaking_callback("fetch_user_info", f)
		if #friends == 0 or not PSN:request_user_info(friends) then
			self:_call_callback("search_lobby", self._lobbys_info_list)
		end
	end
end
function NetworkMatchMakingPSN:search_lobby(settings)
	if not settings or not settings.numbers then
		local numbers = {
			1,
			2,
			3,
			4,
			5,
			6,
			7,
			8
		}
	end
	local table_description = {numbers = numbers}
	local filter = {
		closed = nil,
		full = false,
		numbers = {
			{
				3,
				"!=",
				3
			},
			{
				7,
				"<=",
				managers.experience:current_level()
			},
			{
				5,
				"==",
				self:_game_version()
			}
		}
	}
	if not NetworkManager.DROPIN_ENABLED then
		table.insert(filter.numbers, {
			4,
			"==",
			1
		})
	end
	if self._difficulty_filter and self._difficulty_filter ~= 0 then
		table.insert(filter.numbers, {
			2,
			"==",
			self._difficulty_filter
		})
	end
	PSN:search_session(table_description, filter, PSN:get_world_list()[1].world_id, self._search_lobbys_index, self.MAX_SEARCH_RESULTS)
end
function NetworkMatchMakingPSN:_search_lobby_failed()
	self:search_lobby_done()
end
function NetworkMatchMakingPSN:search_lobby_done()
	self._searching_lobbys = nil
	managers.system_menu:close("find_server")
end
function NetworkMatchMakingPSN:set_num_players(num)
	self._num_players = num
	if self._attributes_numbers then
		self:_set_attributes()
	end
end
function NetworkMatchMakingPSN:_set_attributes(settings)
	if not self._room_id then
		return
	end
	self._attributes_numbers = settings and settings.numbers or self._attributes_numbers
	local numbers = self._attributes_numbers
	numbers[8] = self._num_players or 1
	local attributes = {numbers = numbers}
	PSN:set_session_attributes(self._room_id, attributes)
end
function NetworkMatchMakingPSN:set_server_attributes(settings)
	if not self._room_id then
		return
	end
	self._attributes_numbers[1] = settings.numbers[1]
	self._attributes_numbers[2] = settings.numbers[2]
	self._attributes_numbers[3] = settings.numbers[3]
	self._attributes_numbers[6] = settings.numbers[6]
	self._attributes_numbers[7] = settings.numbers[7]
	self:_set_attributes({
		numbers = self._attributes_numbers
	})
end
function NetworkMatchMakingPSN:set_server_state(state)
	if not self._room_id then
		return
	end
	local state_id = tweak_data:server_state_to_index(state)
	self._attributes_numbers[4] = state_id
	self:_set_attributes({
		numbers = self._attributes_numbers
	})
end
function NetworkMatchMakingPSN:server_state_name()
	return tweak_data:index_to_server_state(self._attributes_numbers[4])
end
function NetworkMatchMakingPSN:test_search()
	local f = function(info)
		print(inspect(info))
		print(inspect(info.room_list[1]))
		print(inspect(info.room_list[1].owner_id))
		print(help(info.room_list[1].owner_id))
		print(inspect(info.room_list[1].room_id))
		print(help(info.room_list[1].room_id))
		print(inspect(PSN:get_info_session(info.room_list[1].room_id)))
	end
	PSN:set_matchmaking_callback("session_search", f)
end
function NetworkMatchMakingPSN:test_search_session()
	local search_params = {
		numbers = {
			1,
			2,
			3,
			4
		}
	}
	PSN:search_session(search_params, {}, PSN:get_world_list()[1].world_id)
end
function NetworkMatchMakingPSN:_custom_message_cb(message)
	print("_custom_message_cb")
	print(inspect(message.custom_table))
	print("message.sender", message.sender)
	print("message", inspect(message))
	if message.custom_table and message.custom_table.join_invite then
		if self._room_id == message.room_id then
			return
		end
		if message.custom_table.version ~= self:_game_version() then
			return
		end
		if (not self._game_owner_id or self._game_owner_id ~= message.sender) and not self._has_pending_invite then
			print("managers.platform:presence() ~= Idle", managers.platform:presence() ~= "Idle")
			if managers.platform:presence() ~= "Idle" then
				self:_recived_join_invite(message)
			end
		end
		if self._join_enable then
		end
	end
end
function NetworkMatchMakingPSN:_invitation_received_cb(message, ...)
	print("_invitation_received_cb")
	print(inspect(message.custom_table))
	print("message.sender", message.sender)
	print("message", inspect(message))
	print("...", inspect(...))
end
function NetworkMatchMakingPSN:_invitation_received_result_cb(message)
	print("_invitation_received_result_cb")
	print(inspect(message.custom_table))
	print("message.sender", message.sender)
	print("message", inspect(message))
	if PSN:user_age() < MenuManager.ONLINE_AGE and PSN:parental_control_settings_active() then
		managers.menu:show_err_under_age()
		return
	end
	if not managers.menu:_enter_online_menus() then
		return
	end
	if self._room_id == message.room_id then
		return
	end
	if message.version ~= self:_game_version() then
		managers.menu:show_invite_wrong_version_message()
		return
	end
	self:_join_invite_accepted(message.room_id)
end
function NetworkMatchMakingPSN:join_boot_invite()
	print("[NetworkMatchMakingPSN:join_boot_invite]", inspect(Global.boot_invite))
	if not Global.boot_invite.pending then
		return
	end
	Global.boot_invite.used = true
	Global.boot_invite.pending = false
	if PSN:user_age() < MenuManager.ONLINE_AGE and PSN:parental_control_settings_active() then
		managers.menu:show_err_under_age()
		return
	end
	if not managers.menu:_enter_online_menus() then
		return
	end
	local message = PSN:get_boot_invitation()
	if not message then
		print("[NetworkMatchMakingPSN:join_boot_invite] PSN:get_boot_invitation failed")
		return
	end
	print("[NetworkMatchMakingPSN:join_boot_invite] message: ", message)
	for i, k in pairs(message) do
		print(i, k)
	end
	if self._room_id == message.room_id then
		print("[NetworkMatchMakingPSN:join_boot_invite] we are already joined")
		return
	end
	if message.version ~= self:_game_version() then
		print("[NetworkMatchMakingPSN:join_boot_invite] WRONG VERSION, INFORM USER")
		managers.menu:show_invite_wrong_version_message()
		return
	end
	managers.network:ps3_determine_voice(false)
	self:_join_invite_accepted(message.room_id)
end
function NetworkMatchMakingPSN:is_server_ok(friends_only, owner_id, attributes_numbers, skip_permission_check)
	local permission = attributes_numbers and tweak_data:index_to_permission(attributes_numbers[3]) or "public"
	if (attributes_numbers[6] ~= 1 or not NetworkManager.DROPIN_ENABLED) and attributes_numbers[4] ~= 1 then
		return false, 1
	end
	if managers.experience:current_level() < attributes_numbers[7] then
		return false, 3
	end
	if friends_only then
	end
	if skip_permission_check or permission == "public" then
		return true
	end
	if permission == "friends_only" then
		return managers.network.friends:is_friend(owner_id), 2
	end
	return false, 2
end
function NetworkMatchMakingPSN:check_server_attributes_failed()
	self:check_server_attributes_done()
end
function NetworkMatchMakingPSN:check_server_attributes_done()
	self._checking_server_attributes = nil
	self._check_room_id = nil
end
function NetworkMatchMakingPSN:join_server_with_check(room_id, skip_permission_check)
	self._joining_lobby = true
	if not managers.system_menu:is_active_by_id("join_server") then
		managers.menu:show_joining_lobby_dialog()
	end
	self._check_room_id = room_id
	self._checking_server_attributes = true
	local function f(results)
		local room_id = self._check_room_id
		self:check_server_attributes_done()
		if not results.rooms then
			self:join_server(room_id)
			return
		end
		local room_info = results.rooms[1]
		local attributes = room_info.attributes
		local owner_id = room_info.owner
		local server_ok, ok_error = self:is_server_ok(nil, owner_id, attributes.numbers, skip_permission_check)
		if server_ok then
			self:join_server(room_id)
		else
			self:_joining_lobby_done()
			if ok_error == 1 then
				managers.menu:show_game_started_dialog()
			elseif ok_error == 2 then
				managers.menu:show_game_permission_changed_dialog()
			elseif ok_error == 3 then
				managers.menu:show_too_low_level()
			elseif ok_error == 4 then
				managers.menu:show_does_not_own_heist()
			end
			managers.network.matchmake:start_search_lobbys(self._friends_only)
		end
	end
	PSN:set_matchmaking_callback("fetch_session_attributes", f)
	local wanted_attributes = {
		numbers = {
			1,
			2,
			3,
			4,
			5,
			6,
			7,
			8
		}
	}
	PSN:get_session_attributes({room_id}, wanted_attributes)
end
function NetworkMatchMakingPSN:join_server(room_id)
	local room = {}
	room.room_id = room_id
	self:_join_server(room)
end
function NetworkMatchMakingPSN:_join_server(room)
	self._connection_info = {}
	self._joining_lobby = true
	self._server_rpc = nil
	self._players = {}
	self:_is_server(false)
	self:_is_client(true)
	self._room_id = room.room_id
	if not managers.system_menu:is_active_by_id("join_server") then
		managers.menu:show_joining_lobby_dialog()
	end
	self._join_cb_room = self._room_id
	PSN:join_session(room.room_id)
	self._trytime = TimerManager:wall():time() + self._JOIN_SERVER_TRY_TIME_INC
end
function NetworkMatchMakingPSN:_joining_lobby_done_failed()
	self:_joining_lobby_done()
end
function NetworkMatchMakingPSN:_joining_lobby_done()
	managers.system_menu:close("join_server")
	self._joining_lobby = nil
end
function NetworkMatchMakingPSN:cb_connection_established(info)
	if self._is_server_var then
		return
	end
	print("NetworkMatchMakingPSN:cb_connection_established")
	print(inspect(info))
	print("connection established to", info.user_id)
	self._connection_info[tostring(info.user_id)] = info
	if info.dead then
		if managers.network:session() then
			local peer = managers.network:session():peer_by_name(tostring(info.user_id))
			if peer then
				managers.network:session():on_peer_lost(peer, peer:id())
			end
		end
		return
	end
	self._invite_room_id = nil
	if info.room_id == self._room_id and info.user_id == info.owner_id then
		self:_joining_lobby_done()
		self._room_id = info.room_id
		self._game_owner_id = info.owner_id
		if info.external_ip and info.port then
			self._server_rpc = Network:handshake(info.external_ip, info.port, "TCP_IP")
			if not self._server_rpc then
				self._trytime = TimerManager:wall():time()
				return
			end
		else
			self._trytime = TimerManager:wall():time()
			return
		end
		self._trytime = nil
		managers.network:start_client()
		managers.menu:show_waiting_for_server_response({
			cancel_func = function()
				if managers.network:session() then
					managers.network:session():on_join_request_cancelled()
				end
			end
		})
		local function f(res, level_index, difficulty_index, state_index)
			managers.system_menu:close("waiting_for_server_response")
			if res == "JOINED_LOBBY" then
				managers.network.voice_chat:open_session(self._room_id)
				MenuCallbackHandler:crimenet_focus_changed(nil, false)
				managers.menu:on_enter_lobby()
			elseif res == "JOINED_GAME" then
				managers.network.voice_chat:set_drop_in({
					room_id = self._room_id
				})
				local level_id = tweak_data.levels:get_level_name_from_index(level_index)
				Global.game_settings.level_id = level_id
				managers.network:session():ok_to_load_level()
			elseif res == "KICKED" then
				managers.network.matchmake:leave_game()
				managers.network.voice_chat:destroy_voice()
				managers.network:queue_stop_network()
				managers.menu:show_peer_kicked_dialog()
			elseif res == "TIMED_OUT" or res == "FAILED_CONNECT" then
				managers.network.matchmake:leave_game()
				managers.network.voice_chat:destroy_voice()
				managers.network:queue_stop_network()
				managers.menu:show_request_timed_out_dialog()
			elseif res == "GAME_STARTED" then
				managers.network.matchmake:leave_game()
				managers.network.voice_chat:destroy_voice()
				managers.network:queue_stop_network()
				managers.menu:show_game_started_dialog()
			elseif res == "DO_NOT_OWN_HEIST" then
				managers.network.matchmake:leave_game()
				managers.network.voice_chat:destroy_voice()
				managers.network:queue_stop_network()
				managers.menu:show_does_not_own_heist()
			elseif res == "CANCELLED" then
				managers.network.matchmake:leave_game()
				managers.network.voice_chat:destroy_voice()
				managers.network:queue_stop_network()
			elseif res == "GAME_FULL" then
				managers.network.matchmake:leave_game()
				managers.network.voice_chat:destroy_voice()
				managers.network:queue_stop_network()
				managers.menu:show_game_is_full()
			elseif res == "LOW_LEVEL" then
				managers.network.matchmake:leave_game()
				managers.network.voice_chat:destroy_voice()
				managers.network:queue_stop_network()
				managers.menu:show_too_low_level()
			elseif res == "WRONG_VERSION" then
				managers.network.matchmake:leave_game()
				managers.network.voice_chat:destroy_voice()
				managers.network:queue_stop_network()
				managers.menu:show_wrong_version_message()
			else
				Application:error("[NetworkMatchMakingPSN:connect_to_host_rpc] FAILED TO START MULTIPLAYER!")
			end
		end
		managers.network:join_game_at_host_rpc(self._server_rpc, f)
	elseif info and managers.network:session() then
		managers.network:session():on_PSN_connection_established(tostring(info.user_id), info.external_ip .. ":" .. info.port)
	end
	if self._join_cb_room and info.room_id == self._join_cb_room then
		if self._cancelled == true then
			self._cancel_time = nil
			self:_call_callback("cancel_done")
		end
		self._join_cb_room = nil
	end
end
function NetworkMatchMakingPSN:get_connection_info(npid_name)
	return self._connection_info[npid_name]
end
function NetworkMatchMakingPSN:_in_list(id)
	for k, v in pairs(self._players) do
		if tostring(v.pnid) == tostring(id) then
			return true
		end
	end
	return false
end
function NetworkMatchMakingPSN:_translate_settings(settings, value)
	if value == "game_mode" then
		local game_mode_in_settings = settings.game_mode
		if game_mode_in_settings == "coop" then
			return 1
		end
		Application:error("Not a supported game mode")
	end
end
function NetworkMatchMakingPSN:_error_cb(info)
	if info then
		print(" _error_cb")
		print(inspect(info))
		managers.system_menu:close("join_server")
		self:_error_message_solver(info)
		if info.error == "8002232c" then
		end
		if info.error == "8002233a" or info.error == "8002231d" then
		end
		if self._checking_server_attributes then
			self:check_server_attributes_failed()
		end
		if self._searching_lobbys then
			self:_search_lobby_failed()
		end
		if self._creating_lobby then
			self:_create_lobby_failed()
		end
		if self._joining_lobby then
			self:_joining_lobby_done_failed()
		end
		if self._getting_world_list then
			self:_getting_world_list_failed()
		end
		if (info.error == "80022b19" or info.error == "80022b0f" or info.error == "80022b15" or info.error == "80022b13") and not self._invite_room_id then
			managers.network.matchmake:start_search_lobbys(self._friends_only)
		end
		self._invite_room_id = nil
		if info.error == "80022b19" or info.error == "80022b0f" or info.error == "80022328" or info.error == "8002232c" or info.error == "80022b13" or info.error == "80022b15" and self._trytime then
			self._trytime = 0
			self._room_id = nil
		end
	end
end
function NetworkMatchMakingPSN:_error_message_solver(info)
	if info.error == "8002232c" then
		return
	end
	if info.error == "8002233a" and self._testing_connection then
		self._testing_connection = nil
		return
	end
	local error_texts = {
		["80022b19"] = "dialog_err_room_is_full",
		["80022b0f"] = "dialog_err_room_is_closed",
		["80022328"] = "dialog_err_room_allready_joined",
		["80022b13"] = "dialog_err_room_no_longer_exists",
		["80022b15"] = "dialog_err_room_no_longer_exists",
		["8002233a"] = self._creating_lobby and "dialog_err_failed_creating_lobby" or self._searching_lobbys and "dialog_err_failed_searching_lobbys" or self._joining_lobby and "dialog_err_failed_joining_lobby" or nil,
		["8002231d"] = self._creating_lobby and "dialog_err_failed_creating_lobby" or self._searching_lobbys and "dialog_err_failed_searching_lobbys" or self._joining_lobby and "dialog_err_failed_joining_lobby" or nil
	}
	local text_id = error_texts[info.error]
	if not Application:production_build() and not text_id then
		return
	end
	local title = managers.localization:text("dialog_error_title") .. (Application:production_build() and " [" .. info.error .. "]" or "")
	local dialog_data = {}
	dialog_data.title = title
	dialog_data.text = text_id and managers.localization:text(text_id) or info.error_text
	local ok_button = {}
	ok_button.text = managers.localization:text("dialog_ok")
	dialog_data.button_list = {ok_button}
	managers.system_menu:show(dialog_data)
end
function NetworkMatchMakingPSN:send_join_invite(friend)
	if not self._room_id then
		return
	end
	local body = managers.localization:text("dialog_mp_invite_message")
	local len = string.len(body)
	for i = 1, 512 - len do
		body = body .. " "
	end
	PSN:send_message_gui({
		attachment = {
			version = self:_game_version(),
			room_id = self._room_id
		},
		body = body,
		subject = managers.localization:text("dialog_mp_invite_title"),
		type = "INVITE",
		list_npid = {
			tostring(friend)
		}
	})
end
function NetworkMatchMakingPSN:_recived_join_invite(message)
	self._has_pending_invite = true
	print("_recived_join_invite")
	local dialog_data = {}
	dialog_data.title = managers.localization:text("dialog_mp_groupinvite_title")
	dialog_data.text = managers.localization:text("dialog_mp_groupinvite_message", {
		GROUP = tostring(message.sender)
	})
	local yes_button = {}
	yes_button.text = managers.localization:text("dialog_yes")
	yes_button.callback_func = callback(self, self, "_join_invite_accepted", message.room_id)
	local no_button = {}
	no_button.text = managers.localization:text("dialog_no")
	function no_button.callback_func()
		self._has_pending_invite = nil
	end
	dialog_data.button_list = {yes_button, no_button}
	managers.system_menu:show(dialog_data)
end
function NetworkMatchMakingPSN:_join_invite_accepted(room_id)
	print("_join_invite_accepted", room_id)
	self._has_pending_invite = nil
	self._invite_room_id = room_id
	if self._room_id then
		print("MUST LEAVE ROOM")
		MenuCallbackHandler:_dialog_leave_lobby_yes()
		return
	end
	self:join_server_with_check(room_id, true)
end
function NetworkMatchMakingPSN:_set_room_hidden(set)
	if set == self._hidden or not self._room_id then
		return
	end
	PSN:set_session_visible(self._room_id, not set)
	PSN:set_session_open(self._room_id, not set)
	self._hidden = set
end
function NetworkMatchMakingPSN:_server_timed_out(rpc)
end
function NetworkMatchMakingPSN:_client_timed_out(rpc)
	for k, v in pairs(self._players) do
		if v.rpc:ip_at_index(0) == rpc:ip_at_index(0) then
			return
		end
	end
end
function NetworkMatchMakingPSN:set_server_joinable(state)
	self._server_joinable = state
	self:_set_room_hidden(not state)
end
function NetworkMatchMakingPSN:is_server_joinable()
	return self._server_joinable
end
