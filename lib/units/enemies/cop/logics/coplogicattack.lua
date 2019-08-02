local mvec3_set = mvector3.set
local mvec3_set_z = mvector3.set_z
local mvec3_sub = mvector3.subtract
local mvec3_dir = mvector3.direction
local mvec3_dot = mvector3.dot
local mvec3_dis = mvector3.distance
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_lerp = mvector3.lerp
local temp_vec1 = Vector3()
local temp_vec2 = Vector3()
local temp_vec3 = Vector3()
CopLogicAttack = class(CopLogicBase)
CopLogicAttack.on_alert = CopLogicIdle.on_alert
CopLogicAttack.on_intimidated = CopLogicIdle.on_intimidated
function CopLogicAttack.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()
	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}
	data.internal_data = my_data
	my_data.detection = data.char_tweak.detection.combat
	my_data.rsrv_pos = {}
	if old_internal_data then
		my_data.rsrv_pos = old_internal_data.rsrv_pos or my_data.rsrv_pos
		my_data.attention_unit = old_internal_data.attention_unit
		CopLogicAttack._set_best_cover(data, my_data, old_internal_data.best_cover)
	end
	my_data.cover_test_step = 1
	local key_str = tostring(data.key)
	my_data.detection_task_key = "CopLogicAttack._upd_enemy_detection" .. key_str
	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicAttack._upd_enemy_detection, data, data.t)
	local allowed_actions
	if data.unit:movement():chk_action_forbidden("walk") and data.unit:movement()._active_actions[2] then
		allowed_actions = CopLogicTravel.allowed_transitional_actions_nav_link
		my_data.wants_stop_old_walk_action = true
	else
		allowed_actions = CopLogicTravel.allowed_transitional_actions
	end
	local idle_body_part = CopLogicTravel.reset_actions(data, my_data, old_internal_data, allowed_actions)
	local upper_body_action = data.unit:movement()._active_actions[3]
	if (not upper_body_action or upper_body_action:type() ~= "shoot") and idle_body_part == 1 then
		data.unit:movement():set_stance("hos")
	end
	if data.unit:anim_data().stand and (data.char_tweak.no_stand or not data.objective or data.objective.attitude ~= "engage") then
		CopLogicAttack._chk_request_action_crouch(data)
	end
	my_data.attitude = data.objective and data.objective.attitude or "avoid"
	my_data.weapon_range = data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].range
	data.unit:brain():set_update_enabled_state(true)
	data.unit:movement():set_cool(false)
	if my_data ~= data.internal_data then
		return
	end
	data.unit:brain():set_attention_settings({cbt = true})
end
function CopLogicAttack.exit(data, new_logic_name, enter_params)
	CopLogicBase.exit(data, new_logic_name, enter_params)
	local my_data = data.internal_data
	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	CopLogicBase.cancel_delayed_clbks(my_data)
	if my_data.best_cover then
		managers.navigation:release_cover(my_data.best_cover[1])
	end
	local rsrv_pos = my_data.rsrv_pos
	if rsrv_pos.path then
		managers.navigation:unreserve_pos(rsrv_pos.path)
		rsrv_pos.path = nil
	end
	if rsrv_pos.move_dest then
		managers.navigation:unreserve_pos(rsrv_pos.move_dest)
		rsrv_pos.move_dest = nil
	end
	data.unit:brain():set_update_enabled_state(true)
end
function CopLogicAttack.update(data)
	local my_data = data.internal_data
	if my_data.wants_stop_old_walk_action then
		if not data.unit:movement():chk_action_forbidden("walk") then
			data.unit:movement():action_request({type = "idle", body_part = 2})
			my_data.wants_stop_old_walk_action = nil
		end
		return
	end
	if CopLogicIdle._chk_relocate(data) then
		return
	end
	CopLogicAttack._process_pathing_results(data, my_data)
	if not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_AIM then
		CopLogicAttack._upd_enemy_detection(data, true)
		if my_data ~= data.internal_data or not data.attention_obj then
			return
		end
	end
	if data.attention_obj.reaction >= AIAttentionObject.REACT_COMBAT then
		my_data.want_to_take_cover = CopLogicAttack._chk_wants_to_take_cover(data, my_data)
		CopLogicAttack._update_cover(data)
		CopLogicAttack._upd_combat_movement(data)
	end
	if not my_data.update_queue_id then
		data.unit:brain():set_update_enabled_state(false)
		my_data.update_queue_id = "CopLogicAttack.queued_update" .. tostring(data.key)
		CopLogicAttack.queue_update(data, my_data)
	end
end
function CopLogicAttack._upd_combat_movement(data)
	local my_data = data.internal_data
	local t = data.t
	local unit = data.unit
	local focus_enemy = data.attention_obj
	local in_cover = my_data.in_cover
	local best_cover = my_data.best_cover
	local enemy_visible = focus_enemy.verified
	local enemy_visible_soft = focus_enemy.verified_t and t - focus_enemy.verified_t < 2
	local enemy_visible_softer = focus_enemy.verified_t and t - focus_enemy.verified_t < 15
	local alert_soft = data.is_suppressed
	local action_taken = data.logic.action_taken(data, my_data)
	local want_to_take_cover = my_data.want_to_take_cover
	if not action_taken then
		if want_to_take_cover and (not in_cover or not in_cover[4]) or data.char_tweak.no_stand then
			if not unit:anim_data().crouch then
				action_taken = CopLogicAttack._chk_request_action_crouch(data)
			end
		elseif unit:anim_data().crouch and (not data.char_tweak.allow_crouch or 2 < my_data.cover_test_step) then
			action_taken = CopLogicAttack._chk_request_action_stand(data)
		end
	end
	local move_to_cover, want_flank_cover
	if my_data.cover_test_step ~= 1 and not enemy_visible_softer and (action_taken or want_to_take_cover or not in_cover) then
		my_data.cover_test_step = 1
	end
	if my_data.stay_out_time and (enemy_visible_soft or not my_data.at_cover_shoot_pos or action_taken or want_to_take_cover) then
		my_data.stay_out_time = nil
	elseif my_data.attitude == "engage" and not my_data.stay_out_time and not enemy_visible_soft and my_data.at_cover_shoot_pos and not action_taken and not want_to_take_cover then
		my_data.stay_out_time = t + 7
	end
	if action_taken then
	elseif want_to_take_cover then
		move_to_cover = true
	elseif not enemy_visible_soft then
		if data.tactics and data.tactics.charge and data.objective and data.objective.grp_objective and data.objective.grp_objective.charge and (not my_data.charge_path_failed_t or data.t - my_data.charge_path_failed_t > 6) then
			if my_data.charge_path then
				local path = my_data.charge_path
				my_data.charge_path = nil
				action_taken = CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path)
			elseif not my_data.charge_path_search_id then
				my_data.charge_pos = CopLogicTravel._get_pos_on_wall(data.attention_obj.m_pos, my_data.weapon_range.optimal, 45, nil)
				if my_data.charge_pos then
					my_data.charge_path_search_id = "charge" .. tostring(data.key)
					unit:brain():search_for_path(my_data.charge_path_search_id, my_data.charge_pos, nil, nil, nil)
				else
					debug_pause_unit(data.unit, "failed to find charge_pos", data.unit)
					my_data.charge_path_failed_t = TimerManager:game():time()
				end
			end
		elseif in_cover then
			if 2 >= my_data.cover_test_step then
				local height
				if in_cover[4] then
					height = 150
				else
					height = 80
				end
				local my_tracker = unit:movement():nav_tracker()
				local shoot_from_pos = CopLogicAttack._peek_for_pos_sideways(data, my_data, my_tracker, focus_enemy.m_head_pos, height)
				if shoot_from_pos then
					local my_tracker = unit:movement():nav_tracker()
					local path = {
						my_tracker:position(),
						shoot_from_pos
					}
					action_taken = CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, math.random() < 0.5 and "run" or "walk")
				else
					my_data.cover_test_step = my_data.cover_test_step + 1
				end
			elseif not enemy_visible_softer and math.random() < 0.05 then
				move_to_cover = true
				want_flank_cover = true
			end
		elseif my_data.walking_to_cover_shoot_pos then
		elseif my_data.at_cover_shoot_pos then
			if t > my_data.stay_out_time then
				move_to_cover = true
			end
		else
			move_to_cover = true
		end
	end
	if not my_data.processing_cover_path and not my_data.cover_path and not my_data.charge_path_search_id and not action_taken and best_cover and (not in_cover or best_cover[1] ~= in_cover[1]) and (not my_data.cover_path_failed_t or data.t - my_data.cover_path_failed_t > 5) then
		CopLogicAttack._cancel_cover_pathing(data, my_data)
		local search_id = tostring(unit:key()) .. "cover"
		if data.unit:brain():search_for_path_to_cover(search_id, best_cover[1], best_cover[5]) then
			my_data.cover_path_search_id = search_id
			my_data.processing_cover_path = best_cover
		end
	end
	if not action_taken and move_to_cover and my_data.cover_path then
		action_taken = CopLogicAttack._chk_request_action_walk_to_cover(data, my_data)
	end
	if want_flank_cover then
		if not my_data.flank_cover then
			local sign = math.random() < 0.5 and -1 or 1
			local step = 30
			my_data.flank_cover = {
				step = step,
				angle = step * sign,
				sign = sign
			}
		end
	else
		my_data.flank_cover = nil
	end
	if not my_data.turning and not data.unit:movement():chk_action_forbidden("walk") and data.attention_obj.verified and (not in_cover or not in_cover[4]) then
		if data.is_suppressed and data.t - data.unit:character_damage():last_suppression_t() < 0.7 then
			action_taken = CopLogicBase.chk_start_action_dodge(data, "scared")
		end
		if not action_taken and focus_enemy.is_person and focus_enemy.dis < 2000 and (data.group and 1 < data.group.size or math.random() < 0.5) then
			local dodge
			if focus_enemy.is_local_player then
				local e_movement_state = focus_enemy.unit:movement():current_state()
				if not e_movement_state:_is_reloading() and not e_movement_state:_interacting() and not e_movement_state:is_equipping() then
					dodge = true
				end
			else
				local e_anim_data = focus_enemy.unit:anim_data()
				if (e_anim_data.move or e_anim_data.idle) and not e_anim_data.reload then
					dodge = true
				end
			end
			if dodge and focus_enemy.aimed_at then
				action_taken = CopLogicBase.chk_start_action_dodge(data, "preemptive")
			end
		end
	end
	if not action_taken and want_to_take_cover and not best_cover then
		action_taken = CopLogicAttack._chk_start_action_move_back(data, my_data, focus_enemy, false)
	end
	action_taken = action_taken or CopLogicAttack._chk_start_action_move_out_of_the_way(data, my_data)
end
function CopLogicAttack._chk_start_action_move_back(data, my_data, focus_enemy, engage)
	if focus_enemy and focus_enemy.nav_tracker and focus_enemy.verified and focus_enemy.dis < 250 then
		local from_pos = mvector3.copy(data.m_pos)
		local threat_tracker = focus_enemy.nav_tracker
		local threat_head_pos = focus_enemy.m_head_pos
		local max_walk_dis = 400
		local vis_required = engage
		local retreat_to = CopLogicAttack._find_retreat_position(from_pos, focus_enemy.m_pos, threat_head_pos, threat_tracker, max_walk_dis, vis_required)
		if retreat_to then
			CopLogicAttack._cancel_cover_pathing(data, my_data)
			local new_action_data = {
				type = "walk",
				nav_path = {from_pos, retreat_to},
				variant = "walk",
				body_part = 2
			}
			if data.unit:brain():action_request(new_action_data) then
				my_data.surprised = true
				local reservation = {
					position = retreat_to,
					radius = 60,
					filter = data.pos_rsrv_id
				}
				managers.navigation:add_pos_reservation(reservation)
				my_data.rsrv_pos.move_dest = reservation
				if my_data.rsrv_pos.stand then
					managers.navigation:unreserve_pos(my_data.rsrv_pos.stand)
					my_data.rsrv_pos.stand = nil
				end
				return true
			end
		end
	end
end
function CopLogicAttack._chk_start_action_move_out_of_the_way(data, my_data)
	local my_tracker = data.unit:movement():nav_tracker()
	local reservation = {
		position = data.m_pos,
		radius = 30,
		filter = data.pos_rsrv_id
	}
	if not managers.navigation:is_pos_free(reservation) then
		local to_pos = CopLogicTravel._get_pos_on_wall(data.m_pos, 500)
		if to_pos then
			local rsrv_pos = my_data.rsrv_pos
			if rsrv_pos.stand then
				managers.navigation:unreserve_pos(rsrv_pos.stand)
				rsrv_pos.stand = nil
			end
			if rsrv_pos.move_dest then
				managers.navigation:unreserve_pos(rsrv_pos.move_dest)
				rsrv_pos.move_dest = nil
			end
			if rsrv_pos.path then
				managers.navigation:unreserve_pos(rsrv_pos.path)
			end
			local reservation = {
				position = to_pos,
				radius = 60,
				filter = data.pos_rsrv_id
			}
			managers.navigation:add_pos_reservation(reservation)
			rsrv_pos.path = reservation
			local path = {
				my_tracker:position(),
				to_pos
			}
			CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, "run")
		end
	end
end
function CopLogicAttack.queued_update(data)
	local my_data = data.internal_data
	data.t = TimerManager:game():time()
	CopLogicAttack.update(data)
	if data.internal_data == my_data then
		CopLogicAttack.queue_update(data, data.internal_data)
	end
end
function CopLogicAttack._peek_for_pos_sideways(data, my_data, from_racker, peek_to_pos, height)
	local unit = data.unit
	local my_tracker = from_racker
	local enemy_pos = peek_to_pos
	local my_pos = unit:movement():m_pos()
	local back_vec = my_pos - enemy_pos
	mvector3.set_z(back_vec, 0)
	mvector3.set_length(back_vec, 75)
	local back_pos = my_pos + back_vec
	local ray_params = {
		tracker_from = my_tracker,
		allow_entry = true,
		pos_to = back_pos,
		trace = true
	}
	local ray_res = managers.navigation:raycast(ray_params)
	back_pos = ray_params.trace[1]
	local back_polar = back_pos - my_pos:to_polar()
	local right_polar = back_polar:with_spin(back_polar.spin + 90):with_r(100 + 80 * my_data.cover_test_step)
	local right_vec = right_polar:to_vector()
	local right_pos = back_pos + right_vec
	ray_params.pos_to = right_pos
	local ray_res = managers.navigation:raycast(ray_params)
	local shoot_from_pos, found_shoot_from_pos
	local ray_softness = 150
	local stand_ray = World:raycast("ray", ray_params.trace[1] + math.UP * height, enemy_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")
	if not stand_ray or ray_softness > mvector3.distance(stand_ray.position, enemy_pos) then
		shoot_from_pos = ray_params.trace[1]
		found_shoot_from_pos = true
	end
	if not found_shoot_from_pos then
		local left_pos = back_pos - right_vec
		ray_params.pos_to = left_pos
		local ray_res = managers.navigation:raycast(ray_params)
		local stand_ray = World:raycast("ray", ray_params.trace[1] + math.UP * height, enemy_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")
		if not stand_ray or ray_softness > mvector3.distance(stand_ray.position, enemy_pos) then
			shoot_from_pos = ray_params.trace[1]
			found_shoot_from_pos = true
		end
	end
	return shoot_from_pos
end
function CopLogicAttack._cancel_cover_pathing(data, my_data)
	if my_data.processing_cover_path then
		if data.active_searches[my_data.cover_path_search_id] then
			managers.navigation:cancel_pathing_search(my_data.cover_path_search_id)
			data.active_searches[my_data.cover_path_search_id] = nil
		elseif data.pathing_results then
			data.pathing_results[my_data.cover_path_search_id] = nil
		end
		my_data.processing_cover_path = nil
		my_data.cover_path_search_id = nil
	end
	my_data.cover_path = nil
end
function CopLogicAttack._cancel_charge(data, my_data)
	my_data.charge_pos = nil
	my_data.charge_path = nil
	if my_data.charge_path_search_id then
		if data.active_searches[my_data.charge_path_search_id] then
			managers.navigation:cancel_pathing_search(my_data.charge_path_search_id)
			data.active_searches[my_data.charge_path_search_id] = nil
		elseif data.pathing_results then
			data.pathing_results[my_data.charge_path_search_id] = nil
		end
		my_data.charge_path_search_id = nil
	end
end
function CopLogicAttack._cancel_expected_pos_path(data, my_data)
	my_data.expected_pos_path = nil
	if my_data.expected_pos_path_search_id then
		if data.active_searches[my_data.expected_pos_path_search_id] then
			managers.navigation:cancel_pathing_search(my_data.expected_pos_path_search_id)
			data.active_searches[my_data.expected_pos_path_search_id] = nil
		elseif data.pathing_results then
			data.pathing_results[my_data.expected_pos_path_search_id] = nil
		end
		my_data.expected_pos_path_search_id = nil
	end
end
function CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, my_pos, enemy_pos)
	local fwd = data.unit:movement():m_rot():y()
	local target_vec = enemy_pos - my_pos
	local error_spin = target_vec:to_polar_with_reference(fwd, math.UP).spin
	if math.abs(error_spin) > 27 then
		local new_action_data = {}
		new_action_data.type = "turn"
		new_action_data.body_part = 2
		new_action_data.angle = error_spin
		if data.unit:brain():action_request(new_action_data) then
			my_data.turning = new_action_data.angle
			return true
		end
	end
end
function CopLogicAttack._cancel_walking_to_cover(data, my_data, skip_action)
	my_data.cover_path = nil
	if my_data.moving_to_cover then
		if not skip_action then
			local new_action = {type = "idle", body_part = 2}
			data.unit:brain():action_request(new_action)
		end
	elseif my_data.processing_cover_path then
		if my_data.rsrv_pos.path then
			managers.navigation:unreserve_pos(my_data.rsrv_pos.path)
			my_data.rsrv_pos.path = nil
		end
		data.unit:brain():cancel_all_pathing_searches()
		my_data.cover_path_search_id = nil
		my_data.processing_cover_path = nil
	end
end
function CopLogicAttack._chk_request_action_walk_to_cover(data, my_data)
	CopLogicAttack._correct_path_start_pos(data, my_data.cover_path)
	local haste
	if (not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_COMBAT or data.attention_obj.dis > 500) and mvector3.distance_sq(my_data.cover_path[#my_data.cover_path], data.m_pos) < 90000 then
		haste = "run"
	elseif data.attention_obj and data.attention_obj.reaction >= AIAttentionObject.REACT_COMBAT and data.attention_obj.dis > math.lerp(my_data.weapon_range.optimal, my_data.weapon_range.far, 0.75) then
		haste = "run"
	else
		haste = "walk"
	end
	local new_action_data = {
		type = "walk",
		nav_path = my_data.cover_path,
		variant = haste,
		body_part = 2
	}
	my_data.cover_path = nil
	if data.unit:brain():action_request(new_action_data) then
		my_data.moving_to_cover = my_data.best_cover
		my_data.at_cover_shoot_pos = nil
		my_data.in_cover = nil
		my_data.rsrv_pos.move_dest = my_data.rsrv_pos.path
		my_data.rsrv_pos.path = nil
		if my_data.rsrv_pos.stand then
			managers.navigation:unreserve_pos(my_data.rsrv_pos.stand)
			my_data.rsrv_pos.stand = nil
		end
	end
end
function CopLogicAttack._correct_path_start_pos(data, path)
	local first_nav_point = path[1]
	local my_pos = data.m_pos
	if first_nav_point.x ~= my_pos.x or first_nav_point.y ~= my_pos.y then
		table.insert(path, 1, mvector3.copy(my_pos))
	end
end
function CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, speed)
	CopLogicAttack._cancel_cover_pathing(data, my_data)
	CopLogicAttack._cancel_charge(data, my_data)
	CopLogicAttack._correct_path_start_pos(data, path)
	local new_action_data = {
		type = "walk",
		nav_path = path,
		variant = speed or "walk",
		body_part = 2
	}
	my_data.cover_path = nil
	local res = data.unit:brain():action_request(new_action_data)
	if res then
		my_data.walking_to_cover_shoot_pos = res
		my_data.at_cover_shoot_pos = nil
		my_data.in_cover = nil
		my_data.rsrv_pos.move_dest = my_data.rsrv_pos.path
		my_data.rsrv_pos.path = nil
		if my_data.rsrv_pos.stand then
			managers.navigation:unreserve_pos(my_data.rsrv_pos.stand)
			my_data.rsrv_pos.stand = nil
		end
	end
end
function CopLogicAttack._chk_request_action_crouch(data)
	if data.unit:movement():chk_action_forbidden("crouch") then
		return
	end
	local new_action_data = {type = "crouch", body_part = 4}
	local res = data.unit:brain():action_request(new_action_data)
	return res
end
function CopLogicAttack._chk_request_action_stand(data)
	if data.unit:movement():chk_action_forbidden("stand") then
		return
	end
	local new_action_data = {type = "stand", body_part = 4}
	local res = data.unit:brain():action_request(new_action_data)
	return res
end
function CopLogicAttack._update_cover(data)
	local my_data = data.internal_data
	local cover_release_dis_sq = 10000
	local best_cover = my_data.best_cover
	local satisfied = true
	local my_pos = data.m_pos
	if data.attention_obj and data.attention_obj.nav_tracker and data.attention_obj.reaction >= AIAttentionObject.REACT_COMBAT then
		local find_new = not my_data.moving_to_cover and not my_data.walking_to_cover_shoot_pos and not my_data.surprised
		if find_new then
			local enemy_tracker = data.attention_obj.nav_tracker
			local threat_pos = enemy_tracker:field_position()
			if data.objective and data.objective.type == "follow" then
				local near_pos = data.objective.follow_unit:movement():m_pos()
				if (not best_cover or not CopLogicAttack._verify_follow_cover(best_cover[1], near_pos, threat_pos, 200, 1000)) and not my_data.processing_cover_path and not my_data.charge_path_search_id then
					local follow_unit_area = managers.groupai:state():get_area_from_nav_seg_id(data.objective.follow_unit:movement():nav_tracker():nav_segment())
					local found_cover = managers.navigation:find_cover_in_nav_seg_3(follow_unit_area.nav_segs, data.objective.distance and data.objective.distance * 0.9 or nil, near_pos, threat_pos)
					if found_cover then
						if not follow_unit_area.nav_segs[found_cover[3]:nav_segment()] then
							debug_pause_unit(data.unit, "cover in wrong area")
						end
						satisfied = true
						local better_cover = {found_cover}
						CopLogicAttack._set_best_cover(data, my_data, better_cover)
						local offset_pos, yaw = CopLogicAttack._get_cover_offset_pos(data, better_cover, threat_pos)
						if offset_pos then
							better_cover[5] = offset_pos
							better_cover[6] = yaw
						end
					end
				end
			else
				local want_to_take_cover = my_data.want_to_take_cover
				local flank_cover = my_data.flank_cover
				local min_dis, max_dis
				if want_to_take_cover then
					min_dis = math.max(data.attention_obj.dis * 0.9, data.attention_obj.dis - 200)
				end
				if not my_data.processing_cover_path and not my_data.charge_path_search_id and (not best_cover or flank_cover or not CopLogicAttack._verify_cover(best_cover[1], threat_pos, min_dis, max_dis)) then
					satisfied = false
					local my_vec = my_pos - threat_pos
					if flank_cover then
						mvector3.rotate_with(my_vec, Rotation(flank_cover.angle))
					end
					local optimal_dis = my_vec:length()
					local max_dis
					if want_to_take_cover then
						if optimal_dis < my_data.weapon_range.far then
							optimal_dis = optimal_dis + 400
							mvector3.set_length(my_vec, optimal_dis)
						end
						max_dis = math.max(optimal_dis + 800, my_data.weapon_range.far)
					elseif optimal_dis > my_data.weapon_range.optimal * 1.2 then
						optimal_dis = my_data.weapon_range.optimal
						mvector3.set_length(my_vec, optimal_dis)
						max_dis = my_data.weapon_range.far
					end
					local my_side_pos = threat_pos + my_vec
					mvector3.set_length(my_vec, max_dis)
					local furthest_side_pos = threat_pos + my_vec
					if flank_cover then
						local angle = flank_cover.angle
						local sign = flank_cover.sign
						if math.sign(angle) ~= sign then
							angle = -angle + flank_cover.step * sign
							if math.abs(angle) > 90 then
								flank_cover.failed = true
							else
								flank_cover.angle = angle
							end
						else
							flank_cover.angle = -angle
						end
					end
					local min_threat_dis, cone_angle
					if flank_cover then
						cone_angle = flank_cover.step
					else
						cone_angle = math.lerp(90, 60, math.min(1, optimal_dis / 3000))
					end
					local search_nav_seg
					if data.objective and data.objective.type == "defend_area" then
						search_nav_seg = data.objective.area and data.objective.area.nav_segs or data.objective.nav_seg
					end
					local found_cover = managers.navigation:find_cover_in_cone_from_threat_pos_1(threat_pos, furthest_side_pos, my_side_pos, nil, cone_angle, min_threat_dis, search_nav_seg, nil, data.pos_rsrv_id)
					if found_cover and (not best_cover or CopLogicAttack._verify_cover(found_cover, threat_pos, min_dis, max_dis)) then
						satisfied = true
						local better_cover = {found_cover}
						CopLogicAttack._set_best_cover(data, my_data, better_cover)
						local offset_pos, yaw = CopLogicAttack._get_cover_offset_pos(data, better_cover, threat_pos)
						if offset_pos then
							better_cover[5] = offset_pos
							better_cover[6] = yaw
						end
					end
				end
			end
		end
		local in_cover = my_data.in_cover
		if in_cover then
			local threat_pos = data.attention_obj.verified_pos
			in_cover[3], in_cover[4] = CopLogicAttack._chk_covered(data, my_pos, threat_pos, data.visibility_slotmask)
		end
	elseif best_cover and cover_release_dis_sq < mvector3.distance_sq(best_cover[1][1], my_pos) then
		CopLogicAttack._set_best_cover(data, my_data, nil)
	end
end
function CopLogicAttack._verify_cover(cover, threat_pos, min_dis, max_dis)
	local threat_dis = mvector3.direction(temp_vec1, cover[1], threat_pos)
	if min_dis and min_dis > threat_dis or max_dis and max_dis < threat_dis then
		return
	end
	local cover_dot = mvector3.dot(temp_vec1, cover[2])
	if cover_dot < 0.67 then
		return
	end
	return true
end
function CopLogicAttack._verify_follow_cover(cover, near_pos, threat_pos, min_dis, max_dis)
	if CopLogicAttack._verify_cover(cover, threat_pos, min_dis, max_dis) and mvector3.distance(near_pos, cover[1]) < 600 then
		return true
	end
end
function CopLogicAttack._chk_covered(data, cover_pos, threat_pos, slotmask)
	local ray_from = temp_vec1
	mvec3_set(ray_from, math.UP)
	mvector3.multiply(ray_from, 80)
	mvector3.add(ray_from, cover_pos)
	local ray_to_pos = temp_vec2
	mvector3.step(ray_to_pos, ray_from, threat_pos, 300)
	local low_ray = World:raycast("ray", ray_from, ray_to_pos, "slot_mask", slotmask)
	local high_ray
	if low_ray then
		mvector3.set_z(ray_from, ray_from.z + 60)
		mvector3.step(ray_to_pos, ray_from, threat_pos, 300)
		high_ray = World:raycast("ray", ray_from, ray_to_pos, "slot_mask", slotmask)
	end
	return low_ray, high_ray
end
function CopLogicAttack._process_pathing_results(data, my_data)
	if not data.pathing_results then
		return
	end
	local pathing_results = data.pathing_results
	data.pathing_results = nil
	local path = pathing_results[my_data.cover_path_search_id]
	if path then
		if path ~= "failed" then
			my_data.cover_path = path
		else
			print(data.unit, "[CopLogicAttack._process_pathing_results] cover path failed", data.unit)
			CopLogicAttack._set_best_cover(data, my_data, nil)
			my_data.cover_path_failed_t = TimerManager:game():time()
		end
		my_data.processing_cover_path = nil
		my_data.cover_path_search_id = nil
	end
	path = pathing_results[my_data.charge_path_search_id]
	if path then
		if path ~= "failed" then
			my_data.charge_path = path
		else
			print("[CopLogicAttack._process_pathing_results] charge path failed", data.unit)
		end
		my_data.charge_path_search_id = nil
		my_data.charge_path_failed_t = TimerManager:game():time()
	end
	path = pathing_results[my_data.expected_pos_path_search_id]
	if path then
		if path ~= "failed" then
			my_data.expected_pos_path = path
		end
		my_data.expected_pos_path_search_id = nil
	end
end
function CopLogicAttack._upd_enemy_detection(data, is_synchronous)
	managers.groupai:state():on_unit_detection_updated(data.unit)
	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local delay = CopLogicBase._upd_attention_obj_detection(data, nil, nil)
	local new_attention, new_prio_slot, new_reaction = CopLogicIdle._get_priority_attention(data, data.detected_attention_objects, nil)
	local old_att_obj = data.attention_obj
	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)
	CopLogicAttack._chk_exit_attack_logic(data, new_reaction)
	if my_data ~= data.internal_data then
		return
	end
	if new_attention then
		if old_att_obj and old_att_obj.u_key ~= new_attention.u_key then
			CopLogicAttack._cancel_charge(data, my_data)
			my_data.flank_cover = nil
			if not data.unit:movement():chk_action_forbidden("walk") then
				CopLogicAttack._cancel_walking_to_cover(data, my_data)
			end
			CopLogicAttack._set_best_cover(data, my_data, nil)
		end
	elseif old_att_obj then
		CopLogicAttack._cancel_charge(data, my_data)
		my_data.flank_cover = nil
	end
	CopLogicBase._chk_call_the_police(data)
	if my_data ~= data.internal_data then
		return
	end
	CopLogicAttack._upd_aim(data, my_data)
	if not is_synchronous then
		CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicAttack._upd_enemy_detection, data, delay and data.t + delay, data.important and true)
	end
	CopLogicBase._report_detections(data.detected_attention_objects)
end
function CopLogicAttack._confirm_retreat_position(retreat_pos, threat_pos, threat_head_pos, threat_tracker)
	local ray_params = {
		pos_from = retreat_pos,
		tracker_to = threat_tracker,
		trace = true
	}
	local walk_ray_res = managers.navigation:raycast(ray_params)
	if not walk_ray_res then
		return ray_params.trace[1]
	end
	local retreat_head_pos = mvector3.copy(retreat_pos)
	mvector3.add(retreat_head_pos, Vector3(0, 0, 150))
	local slotmask = managers.slot:get_mask("AI_visibility")
	local ray_res = World:raycast("ray", retreat_head_pos, threat_head_pos, "slot_mask", slotmask, "ray_type", "ai_vision")
	if not ray_res then
		return walk_ray_res or ray_params.trace[1]
	end
	return false
end
function CopLogicAttack._find_retreat_position(from_pos, threat_pos, threat_head_pos, threat_tracker, max_dist, vis_required)
	local nav_manager = managers.navigation
	local nr_rays = 5
	local ray_dis = max_dist or 1000
	local step = 180 / nr_rays
	local offset = math.random(step)
	local dir = math.random() < 0.5 and -1 or 1
	step = step * dir
	local step_rot = Rotation(step)
	local offset_rot = Rotation(offset)
	local offset_vec = mvector3.copy(threat_pos)
	mvector3.subtract(offset_vec, from_pos)
	mvector3.normalize(offset_vec)
	mvector3.multiply(offset_vec, ray_dis)
	mvector3.rotate_with(offset_vec, Rotation((90 + offset) * dir))
	local to_pos
	local from_tracker = nav_manager:create_nav_tracker(from_pos)
	local ray_params = {tracker_from = from_tracker, trace = true}
	local rsrv_desc = {radius = 60}
	local fail_position
	repeat
		to_pos = mvector3.copy(from_pos)
		mvector3.add(to_pos, offset_vec)
		ray_params.pos_to = to_pos
		local ray_res = nav_manager:raycast(ray_params)
		if ray_res then
			rsrv_desc.position = ray_params.trace[1]
			local is_free = nav_manager:is_pos_free(rsrv_desc)
			if is_free and (not vis_required or CopLogicAttack._confirm_retreat_position(ray_params.trace[1], threat_pos, threat_head_pos, threat_tracker)) then
				managers.navigation:destroy_nav_tracker(from_tracker)
				return ray_params.trace[1]
			else
			end
		elseif not fail_position then
			rsrv_desc.position = ray_params.trace[1]
			local is_free = nav_manager:is_pos_free(rsrv_desc)
			if is_free then
				fail_position = ray_params.trace[1]
			end
		end
		mvector3.rotate_with(offset_vec, step_rot)
		nr_rays = nr_rays - 1
	until nr_rays == 0
	managers.navigation:destroy_nav_tracker(from_tracker)
	if fail_position then
		return fail_position
	end
	return nil
end
function CopLogicAttack.action_complete_clbk(data, action)
	local my_data = data.internal_data
	local action_type = action:type()
	if action_type == "walk" then
		CopLogicAttack._cancel_cover_pathing(data, my_data)
		CopLogicAttack._cancel_charge(data, my_data)
		if action:expired() then
			my_data.rsrv_pos.stand = my_data.rsrv_pos.move_dest
		else
			local reservation = managers.navigation:reserve_pos(data.t, nil, data.m_pos, nil, 60, data.pos_rsrv_id)
			my_data.rsrv_pos.stand = reservation
			if my_data.rsrv_pos.move_dest then
				managers.navigation:unreserve_pos(my_data.rsrv_pos.move_dest)
			end
		end
		my_data.rsrv_pos.move_dest = nil
		if my_data.surprised then
			my_data.surprised = false
		elseif my_data.moving_to_cover then
			if action:expired() then
				my_data.in_cover = my_data.moving_to_cover
				my_data.cover_enter_t = data.t
			end
			my_data.moving_to_cover = nil
		elseif my_data.walking_to_cover_shoot_pos then
			my_data.walking_to_cover_shoot_pos = nil
			my_data.at_cover_shoot_pos = true
		end
	elseif action_type == "shoot" then
		my_data.shooting = nil
	elseif action_type == "turn" then
		my_data.turning = nil
	elseif action_type == "hurt" then
		CopLogicAttack._cancel_cover_pathing(data, my_data)
		if action:expired() and not CopLogicBase.chk_start_action_dodge(data, "hit") then
			CopLogicAttack._upd_aim(data, my_data)
		end
	elseif action_type == "dodge" then
		local timeout = action:timeout()
		if timeout then
			data.dodge_timeout_t = TimerManager:game():time() + math.lerp(timeout[1], timeout[2], math.random())
		end
		CopLogicAttack._cancel_cover_pathing(data, my_data)
		if my_data.rsrv_pos.stand then
			managers.navigation:unreserve_pos(my_data.rsrv_pos.stand)
		end
		local reservation = managers.navigation:reserve_pos(data.t, nil, data.m_pos, nil, 60, data.pos_rsrv_id)
		my_data.rsrv_pos.stand = reservation
	end
end
function CopLogicAttack._upd_aim(data, my_data)
	local shoot, aim, expected_pos
	local focus_enemy = data.attention_obj
	if focus_enemy and focus_enemy.reaction >= AIAttentionObject.REACT_AIM then
		local last_sup_t = data.unit:character_damage():last_suppression_t()
		if focus_enemy.verified or focus_enemy.nearly_visible then
			if data.unit:anim_data().run and focus_enemy.dis > math.lerp(my_data.weapon_range.close, my_data.weapon_range.optimal, 0) then
				local walk_to_pos = data.unit:movement():get_walk_to_pos()
				if walk_to_pos then
					mvector3.direction(temp_vec1, data.m_pos, walk_to_pos)
					mvector3.direction(temp_vec2, data.m_pos, focus_enemy.m_pos)
					local dot = mvector3.dot(temp_vec1, temp_vec2)
					if dot < 0.6 and dot > -0.6 then
						shoot = false
						aim = false
					end
				end
			end
			if aim == nil then
				aim = true
				if focus_enemy.reaction >= AIAttentionObject.REACT_SHOOT then
					if focus_enemy.verified then
						if focus_enemy.aimed_at and (focus_enemy.verified_dis < data.internal_data.weapon_range.close or focus_enemy.verified_dis < data.internal_data.weapon_range.optimal and not data.unit:anim_data().run) then
							shoot = true
						elseif last_sup_t and data.t - last_sup_t < 7 then
							shoot = true
						elseif focus_enemy.reaction == AIAttentionObject.REACT_SHOOT then
							shoot = true
						elseif my_data.attitude == "engage" then
							if focus_enemy.verified_dis < data.internal_data.weapon_range.far then
								shoot = true
							end
						elseif focus_enemy.verified_dis < data.internal_data.weapon_range.close then
							shoot = true
						elseif last_sup_t and data.t - last_sup_t < 20 and focus_enemy.verified_dis < data.internal_data.weapon_range.far then
							shoot = true
						end
					elseif last_sup_t and data.t - last_sup_t < 3 and data.unit:anim_data().still then
						shoot = true
					end
				end
			end
		elseif focus_enemy.verified_t then
			if data.t - focus_enemy.verified_t < (data.name == "travel" and 1.5 or 4) and focus_enemy.verified_dis < data.internal_data.weapon_range.optimal and math.abs(focus_enemy.verified_pos.z - data.m_pos.z) < 250 then
				aim = true
				if focus_enemy.reaction >= AIAttentionObject.REACT_SHOOT and my_data.shooting and 3 > data.t - focus_enemy.verified_t then
					shoot = true
				end
			else
				expected_pos = CopLogicAttack._get_expected_attention_position(data, my_data)
				if expected_pos then
					aim = true
				elseif 20 > data.t - focus_enemy.verified_t or focus_enemy.verified_dis < 1000 then
					aim = true
					if my_data.shooting and my_data.firing and last_sup_t and data.t - last_sup_t < 7 and focus_enemy.reaction >= AIAttentionObject.REACT_SHOOT and my_data.shooting and 3 > data.t - focus_enemy.verified_t then
						shoot = true
					end
				end
			end
		else
			expected_pos = CopLogicAttack._get_expected_attention_position(data, my_data)
			if expected_pos then
				aim = true
			end
		end
	end
	if data.logic.chk_should_turn(data, my_data) and (focus_enemy or expected_pos) then
		local enemy_pos = expected_pos or (focus_enemy.verified or focus_enemy.nearly_visible) and focus_enemy.m_pos or focus_enemy.verified_pos
		CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, enemy_pos)
	end
	if aim or shoot then
		if expected_pos then
			if my_data.attention_unit ~= expected_pos then
				CopLogicBase._set_attention_on_pos(data, mvector3.copy(expected_pos))
				my_data.attention_unit = mvector3.copy(expected_pos)
			end
		elseif focus_enemy.verified or focus_enemy.nearly_visible then
			if my_data.attention_unit ~= focus_enemy.u_key then
				CopLogicBase._set_attention(data, focus_enemy)
				my_data.attention_unit = focus_enemy.u_key
			end
		else
			local look_pos = focus_enemy.last_verified_pos or focus_enemy.verified_pos
			if my_data.attention_unit ~= look_pos then
				CopLogicBase._set_attention_on_pos(data, mvector3.copy(look_pos))
				my_data.attention_unit = mvector3.copy(look_pos)
			end
		end
		if not my_data.shooting and not data.unit:anim_data().reload and not data.unit:movement():chk_action_forbidden("action") then
			local shoot_action = {type = "shoot", body_part = 3}
			if data.unit:brain():action_request(shoot_action) then
				my_data.shooting = true
			end
		end
	else
		if my_data.shooting then
			local new_action
			if data.unit:anim_data().reload then
				new_action = {type = "reload", body_part = 3}
			else
				new_action = {type = "idle", body_part = 3}
			end
			data.unit:brain():action_request(new_action)
		end
		if my_data.attention_unit then
			CopLogicBase._reset_attention(data)
			my_data.attention_unit = nil
		end
	end
	CopLogicAttack.aim_allow_fire(shoot, aim, data, my_data)
end
function CopLogicAttack.aim_allow_fire(shoot, aim, data, my_data)
	local focus_enemy = data.attention_obj
	if shoot then
		if not my_data.firing then
			data.unit:movement():set_allow_fire(true)
			my_data.firing = true
			if not data.unit:in_slot(16) then
				managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "aggressive")
			end
		end
	elseif my_data.firing then
		data.unit:movement():set_allow_fire(false)
		my_data.firing = nil
	end
end
function CopLogicAttack.chk_should_turn(data, my_data)
	return not my_data.turning and not data.unit:movement():chk_action_forbidden("walk") and not my_data.moving_to_cover and not my_data.walking_to_cover_shoot_pos and not my_data.surprised
end
function CopLogicAttack._get_cover_offset_pos(data, cover_data, threat_pos)
	local threat_vec = threat_pos - cover_data[1][1]
	mvector3.set_z(threat_vec, 0)
	local threat_polar = threat_vec:to_polar_with_reference(cover_data[1][2], math.UP)
	local threat_spin = threat_polar.spin
	local rot
	if threat_spin < -20 then
		rot = Rotation(90)
	elseif threat_spin > 20 then
		rot = Rotation(-90)
	else
		rot = Rotation(180)
	end
	local offset_pos = mvector3.copy(cover_data[1][2])
	mvector3.rotate_with(offset_pos, rot)
	mvector3.set_length(offset_pos, 25)
	mvector3.add(offset_pos, cover_data[1][1])
	local ray_params = {
		tracker_from = cover_data[1][3],
		pos_to = offset_pos,
		trace = true
	}
	managers.navigation:raycast(ray_params)
	return ray_params.trace[1]
end
function CopLogicAttack._find_flank_pos(data, my_data, flank_tracker, max_dist)
	local pos = flank_tracker:position()
	local vec_to_pos = pos - data.m_pos
	mvector3.set_z(vec_to_pos, 0)
	local max_dis = max_dist or 1500
	mvector3.set_length(vec_to_pos, max_dis)
	local accross_positions = managers.navigation:find_walls_accross_tracker(flank_tracker, vec_to_pos, 160, 5)
	if accross_positions then
		local optimal_dis = max_dis
		local best_error_dis, best_pos, best_is_hit, best_is_miss, best_has_too_much_error
		for _, accross_pos in ipairs(accross_positions) do
			local error_dis = math.abs(mvector3.distance(accross_pos[1], pos) - optimal_dis)
			local too_much_error = error_dis / optimal_dis > 0.2
			local is_hit = accross_pos[2]
			if best_is_hit then
				if is_hit then
					if best_error_dis > error_dis then
						local reservation = {
							position = accross_pos[1],
							radius = 30,
							filter = data.pos_rsrv_id
						}
						if managers.navigation:is_pos_free(reservation) then
							best_pos = accross_pos[1]
							best_error_dis = error_dis
							best_has_too_much_error = too_much_error
						end
					end
				elseif best_has_too_much_error then
					local reservation = {
						position = accross_pos[1],
						radius = 30,
						filter = data.pos_rsrv_id
					}
					if managers.navigation:is_pos_free(reservation) then
						best_pos = accross_pos[1]
						best_error_dis = error_dis
						best_is_miss = true
						best_is_hit = nil
					end
				end
			elseif best_is_miss then
				if not too_much_error then
					local reservation = {
						position = accross_pos[1],
						radius = 30,
						filter = data.pos_rsrv_id
					}
					if managers.navigation:is_pos_free(reservation) then
						best_pos = accross_pos[1]
						best_error_dis = error_dis
						best_has_too_much_error = nil
						best_is_miss = nil
						best_is_hit = true
					end
				end
			else
				local reservation = {
					position = accross_pos[1],
					radius = 30,
					filter = data.pos_rsrv_id
				}
				if managers.navigation:is_pos_free(reservation) then
					best_pos = accross_pos[1]
					best_is_hit = is_hit
					best_is_miss = not is_hit
					best_has_too_much_error = too_much_error
					best_error_dis = error_dis
				end
			end
		end
		return best_pos
	end
end
function CopLogicAttack.damage_clbk(data, damage_info)
	CopLogicIdle.damage_clbk(data, damage_info)
end
function CopLogicAttack.is_available_for_assignment(data, new_objective)
	local my_data = data.internal_data
	if my_data.exiting then
		return
	end
	if new_objective and new_objective.forced then
		return true
	end
	if data.unit:movement():chk_action_forbidden("walk") then
		return
	end
	if data.path_fail_t and data.t < data.path_fail_t + 6 then
		return
	end
	if data.is_suppressed then
		return
	end
	local att_obj = data.attention_obj
	if not att_obj or att_obj.reaction < AIAttentionObject.REACT_AIM then
		return true
	end
	if not new_objective or new_objective.type == "free" then
		return true
	end
	if new_objective then
		local allow_trans, obj_fail = CopLogicBase.is_obstructed(data, new_objective, 0.2)
		if obj_fail then
			return
		end
	end
	return true
end
function CopLogicAttack._chk_wants_to_take_cover(data, my_data)
	if not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_COMBAT then
		return
	end
	if my_data.moving_to_cover or data.is_suppressed or my_data.attitude ~= "engage" or data.unit:anim_data().reload then
		return true
	end
	local ammo_max, ammo = data.unit:inventory():equipped_unit():base():ammo_info()
	if ammo / ammo_max < 0.2 then
		return true
	end
end
function CopLogicAttack._set_best_cover(data, my_data, cover_data)
	local best_cover = my_data.best_cover
	if best_cover then
		managers.navigation:release_cover(best_cover[1])
		CopLogicAttack._cancel_cover_pathing(data, my_data)
	end
	if cover_data then
		managers.navigation:reserve_cover(cover_data[1], data.pos_rsrv_id)
		my_data.best_cover = cover_data
		if not my_data.in_cover and not my_data.walking_to_cover_shoot_pos and not my_data.moving_to_cover and mvec3_dis_sq(cover_data[1][1], data.m_pos) < 100 then
			my_data.in_cover = my_data.best_cover
			my_data.cover_enter_t = data.t
		end
	else
		my_data.best_cover = nil
		my_data.flank_cover = nil
	end
end
function CopLogicAttack._set_nearest_cover(my_data, cover_data)
	local nearest_cover = my_data.nearest_cover
	if nearest_cover then
		managers.navigation:release_cover(nearest_cover[1])
	end
	if cover_data then
		local pos_rsrv_id = my_data.unit:movement():pos_rsrv_id()
		managers.navigation:reserve_cover(cover_data[1], pos_rsrv_id)
		my_data.nearest_cover = cover_data
	else
		my_data.nearest_cover = nil
	end
end
function CopLogicAttack._can_move(data)
	return not data.objective or not data.objective.pos or not data.objective.in_place
end
function CopLogicAttack.on_new_objective(data, old_objective)
	CopLogicIdle.on_new_objective(data, old_objective)
end
function CopLogicAttack.queue_update(data, my_data)
	CopLogicBase.queue_task(my_data, my_data.update_queue_id, data.logic.queued_update, data, data.t + (data.important and 0.5 or 2), true)
end
function CopLogicAttack._get_expected_attention_position(data, my_data)
	local main_enemy = data.attention_obj
	local e_nav_tracker = main_enemy.nav_tracker
	if not e_nav_tracker then
		return
	end
	local my_nav_seg = data.unit:movement():nav_tracker():nav_segment()
	local e_pos = main_enemy.m_pos
	local e_nav_seg = e_nav_tracker:nav_segment()
	if e_nav_seg == my_nav_seg then
		mvec3_set(temp_vec1, e_pos)
		mvec3_set_z(temp_vec1, temp_vec1.z + 140)
		return temp_vec1
	end
	local expected_path = my_data.expected_pos_path
	local from_nav_seg, to_nav_seg
	if expected_path then
		local i_from_seg
		for i, k in ipairs(expected_path) do
			if k[1] == my_nav_seg then
				i_from_seg = i
			else
			end
		end
		if i_from_seg then
			local function _find_aim_pos(from_nav_seg, to_nav_seg)
				local closest_dis = 1000000000
				local closest_door
				local min_point_dis_sq = 10000
				local found_doors = managers.navigation:find_segment_doors(from_nav_seg, callback(CopLogicAttack, CopLogicAttack, "_chk_is_right_segment", to_nav_seg))
				for _, door in pairs(found_doors) do
					mvec3_set(temp_vec1, door.center)
					local dis = mvec3_dis_sq(e_pos, temp_vec1)
					if closest_dis > dis then
						closest_dis = dis
						closest_door = door
					end
				end
				if closest_door then
					mvec3_set(temp_vec1, closest_door.center)
					mvec3_sub(temp_vec1, data.m_pos)
					mvec3_set_z(temp_vec1, 0)
					if min_point_dis_sq < mvector3.length_sq(temp_vec1) then
						mvec3_set(temp_vec1, closest_door.center)
						mvec3_set_z(temp_vec1, temp_vec1.z + 140)
						return temp_vec1
					else
						return false, true
					end
				end
			end
			local i = #expected_path
			while i > 0 do
				if expected_path[i][1] == e_nav_seg then
					to_nav_seg = expected_path[math.clamp(i, i_from_seg - 1, i_from_seg + 1)][1]
					local aim_pos, too_close = _find_aim_pos(my_nav_seg, to_nav_seg)
					if aim_pos then
						do return aim_pos end
						break
					end
					if too_close then
						local next_nav_seg = expected_path[math.clamp(i, i_from_seg - 2, i_from_seg + 2)][1]
						if next_nav_seg ~= to_nav_seg then
							local from_nav_seg = to_nav_seg
							to_nav_seg = next_nav_seg
							aim_pos = _find_aim_pos(from_nav_seg, to_nav_seg)
						end
						return aim_pos
					end
					break
				end
				i = i - 1
			end
		end
		if not i_from_seg or not to_nav_seg then
			expected_path = nil
			my_data.expected_pos_path = nil
		end
	end
	if not expected_path and not my_data.expected_pos_path_search_id then
		my_data.expected_pos_path_search_id = "ExpectedPos" .. tostring(data.key)
		data.unit:brain():search_for_coarse_path(my_data.expected_pos_path_search_id, e_nav_seg)
	end
end
function CopLogicAttack._chk_is_right_segment(ignore_this, enemy_nav_seg, test_nav_seg)
	return enemy_nav_seg == test_nav_seg
end
function CopLogicAttack.is_advancing(data)
	if data.internal_data.moving_to_cover then
		return data.internal_data.moving_to_cover[1][1]
	end
	if data.internal_data.walking_to_cover_shoot_pos then
		return data.internal_data.walking_to_cover_shoot_pos._last_pos
	end
end
function CopLogicAttack._get_all_paths(data)
	return {
		cover_path = data.internal_data.cover_path,
		flank_path = data.internal_data.flank_path
	}
end
function CopLogicAttack._set_verified_paths(data, verified_paths)
	data.internal_data.cover_path = verified_paths.cover_path
	data.internal_data.flank_path = verified_paths.flank_path
end
function CopLogicAttack._chk_exit_attack_logic(data, new_reaction)
	if not data.unit:movement():chk_action_forbidden("walk") then
		local wanted_state = CopLogicBase._get_logic_state_from_reaction(data, new_reaction)
		if wanted_state ~= data.name then
			local allow_trans, obj_failed = CopLogicBase.is_obstructed(data, data.objective, nil, nil)
			if allow_trans then
				if obj_failed then
					managers.groupai:state():on_objective_failed(data.unit, data.objective)
				elseif wanted_state ~= "idle" or not managers.groupai:state():on_cop_jobless(data.unit) then
					CopLogicBase._exit(data.unit, wanted_state)
				end
				CopLogicBase._report_detections(data.detected_attention_objects)
			end
		end
	end
end
function CopLogicAttack.action_taken(data, my_data)
	return my_data.turning or my_data.moving_to_cover or my_data.walking_to_cover_shoot_pos or my_data.surprised or data.unit:movement():chk_action_forbidden("walk")
end
