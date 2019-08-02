require("lib/units/enemies/cop/logics/CopLogicIdle")
require("lib/units/enemies/cop/logics/CopLogicTravel")
local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()
local tmp_vec3 = Vector3()
TeamAILogicIdle = TeamAILogicIdle or class(TeamAILogicBase)
function TeamAILogicIdle.enter(data, new_logic_name, enter_params)
	TeamAILogicBase.enter(data, new_logic_name, enter_params)
	local my_data = {
		unit = data.unit
	}
	my_data.detection = data.char_tweak.detection.idle
	my_data.enemy_detect_slotmask = managers.slot:get_mask("enemies")
	my_data.rsrv_pos = {}
	local old_internal_data = data.internal_data
	if old_internal_data then
		my_data.rsrv_pos = old_internal_data.rsrv_pos or my_data.rsrv_pos
		if old_internal_data.best_cover then
			my_data.best_cover = old_internal_data.best_cover
			managers.navigation:reserve_cover(my_data.best_cover[1], data.pos_rsrv_id)
		end
		if old_internal_data.nearest_cover then
			my_data.nearest_cover = old_internal_data.nearest_cover
			managers.navigation:reserve_cover(my_data.nearest_cover[1], data.pos_rsrv_id)
		end
	end
	data.internal_data = my_data
	local key_str = tostring(data.key)
	my_data.detection_task_key = "TeamAILogicIdle._upd_enemy_detection" .. key_str
	CopLogicBase.queue_task(my_data, my_data.detection_task_key, TeamAILogicIdle._upd_enemy_detection, data, data.t)
	if my_data.nearest_cover or my_data.best_cover then
		my_data.cover_update_task_key = "CopLogicIdle._update_cover" .. key_str
		CopLogicBase.add_delayed_clbk(my_data, my_data.cover_update_task_key, callback(CopLogicTravel, CopLogicTravel, "_update_cover", data), data.t + 1)
	end
	my_data.stare_path_search_id = "stare" .. key_str
	my_data.relocate_chk_t = 0
	CopLogicBase._reset_attention(data)
	if data.unit:movement():stance_name() == "cbt" then
		data.unit:movement():set_stance("hos")
	end
	data.unit:movement():set_allow_fire(false)
	local objective = data.objective
	local entry_action = enter_params and enter_params.action
	if objective then
		if objective.type == "revive" then
			if objective.action_start_clbk then
				objective.action_start_clbk(data.unit)
			end
			local success
			local revive_unit = objective.follow_unit
			if revive_unit:interaction() then
				if revive_unit:interaction():active() and data.unit:brain():action_request(objective.action) then
					revive_unit:interaction():interact_start(data.unit)
					success = true
				end
			elseif revive_unit:character_damage():arrested() then
				if data.unit:brain():action_request(objective.action) then
					revive_unit:character_damage():pause_arrested_timer()
					success = true
				end
			elseif revive_unit:character_damage():need_revive() and data.unit:brain():action_request(objective.action) then
				revive_unit:character_damage():pause_downed_timer()
				success = true
			end
			if success then
				my_data.performing_act_objective = objective
				my_data.reviving = revive_unit
				my_data.acting = true
				my_data.revive_complete_clbk_id = "TeamAILogicIdle_revive" .. tostring(data.key)
				local revive_t = TimerManager:game():time() + (objective.action_duration or 0)
				CopLogicBase.add_delayed_clbk(my_data, my_data.revive_complete_clbk_id, callback(TeamAILogicIdle, TeamAILogicIdle, "clbk_revive_complete", data), revive_t)
				if not revive_unit:character_damage():arrested() then
					local suffix = "a"
					local downed_time = revive_unit:character_damage():down_time()
					if downed_time <= tweak_data.player.damage.DOWNED_TIME_MIN then
						suffix = "c"
					elseif downed_time <= tweak_data.player.damage.DOWNED_TIME / 2 + tweak_data.player.damage.DOWNED_TIME_DEC then
						suffix = "b"
					end
					data.unit:sound():say("s09" .. suffix, true)
				end
			else
				data.unit:brain():set_objective()
				return
			end
		else
			if objective.action_duration then
				my_data.action_timeout_clbk_id = "TeamAILogicIdle_action_timeout" .. key_str
				local action_timeout_t = data.t + objective.action_duration
				CopLogicBase.add_delayed_clbk(my_data, my_data.action_timeout_clbk_id, callback(CopLogicIdle, CopLogicIdle, "clbk_action_timeout", data), action_timeout_t)
			end
			if objective.type == "act" then
				if data.unit:brain():action_request(objective.action) then
					my_data.acting = true
				end
				my_data.performing_act_objective = objective
				if objective.action_start_clbk then
					objective.action_start_clbk(data.unit)
				end
			end
		end
		if objective.scan then
			my_data.scan = true
			if not my_data.acting then
				my_data.wall_stare_task_key = "CopLogicIdle._chk_stare_into_wall" .. tostring(data.key)
				CopLogicBase.queue_task(my_data, my_data.wall_stare_task_key, CopLogicIdle._chk_stare_into_wall_1, data, data.t)
			end
		end
	end
end
function TeamAILogicIdle.exit(data, new_logic_name, enter_params)
	TeamAILogicBase.exit(data, new_logic_name, enter_params)
	local my_data = data.internal_data
	if my_data.delayed_clbks and my_data.delayed_clbks[my_data.revive_complete_clbk_id] then
		local revive_unit = my_data.reviving
		if alive(revive_unit) then
			if revive_unit:interaction() then
				revive_unit:interaction():interact_interupt(data.unit)
			elseif revive_unit:character_damage():arrested() then
				revive_unit:character_damage():unpause_arrested_timer()
			elseif revive_unit:character_damage():need_revive() then
				revive_unit:character_damage():unpause_downed_timer()
			end
		end
		my_data.performing_act_objective = nil
		local crouch_action = {
			type = "act",
			body_part = 1,
			variant = "crouch",
			blocks = {
				action = -1,
				walk = -1,
				hurt = -1,
				heavy_hurt = -1,
				aim = -1
			}
		}
		data.unit:movement():action_request(crouch_action)
	end
	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	CopLogicBase.cancel_delayed_clbks(my_data)
	if my_data.best_cover then
		managers.navigation:release_cover(my_data.best_cover[1])
	end
	if my_data.nearest_cover then
		managers.navigation:release_cover(my_data.nearest_cover[1])
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
end
function TeamAILogicIdle.update(data)
	local my_data = data.internal_data
	CopLogicIdle._upd_pathing(data, my_data)
	CopLogicIdle._upd_scan(data, my_data)
	local objective = data.objective
	if objective then
		if not my_data.acting then
			if objective.type == "follow" then
				if TeamAILogicIdle._check_should_relocate(data, my_data, objective) and not data.unit:movement():chk_action_forbidden("walk") then
					objective.in_place = nil
					TeamAILogicBase._exit(data.unit, "travel")
				end
			elseif objective.type == "revive" then
				objective.in_place = nil
				TeamAILogicBase._exit(data.unit, "travel")
			end
		end
	elseif not data.path_fail_t or data.t - data.path_fail_t > 6 then
		managers.groupai:state():on_criminal_jobless(data.unit)
	end
end
function TeamAILogicIdle.on_detected_enemy_destroyed(data, enemy_unit)
end
function TeamAILogicIdle.on_cop_neutralized(data, cop_key)
end
function TeamAILogicIdle.damage_clbk(data, damage_info)
	local attacker_unit = damage_info.attacker_unit
	if attacker_unit and attacker_unit:in_slot(data.enemy_slotmask) then
		local my_data = data.internal_data
		local attacker_key = attacker_unit:key()
		local enemy_data = data.detected_attention_objects[attacker_key]
		local t = TimerManager:game():time()
		if enemy_data then
			enemy_data.verified_t = t
			enemy_data.verified = true
			mvector3.set(enemy_data.verified_pos, attacker_unit:movement():m_stand_pos())
			enemy_data.verified_dis = mvector3.distance(enemy_data.verified_pos, data.unit:movement():m_stand_pos())
			enemy_data.dmg_t = t
			enemy_data.alert_t = t
			enemy_data.notice_delay = nil
			if not enemy_data.identified then
				enemy_data.identified = true
				enemy_data.identified_t = t
				enemy_data.notice_progress = nil
				enemy_data.prev_notice_chk_t = nil
				if enemy_data.settings.notice_clbk then
					enemy_data.settings.notice_clbk(data.unit, true)
				end
			end
		else
			local attention_info = managers.groupai:state():get_AI_attention_objects_by_filter(data.SO_access_str)[attacker_key]
			if attention_info then
				local settings = attention_info.handler:get_attention(data.SO_access, nil, nil)
				if settings then
					enemy_data = CopLogicBase._create_detected_attention_object_data(data, my_data, attacker_key, attention_info, settings)
					enemy_data.verified_t = t
					enemy_data.verified = true
					enemy_data.dmg_t = t
					enemy_data.alert_t = t
					enemy_data.notice_progress = nil
					enemy_data.prev_notice_chk_t = nil
					enemy_data.identified = true
					enemy_data.identified_t = t
					if enemy_data.settings.notice_clbk then
						enemy_data.settings.notice_clbk(data.unit, true)
					end
					data.detected_attention_objects[attacker_key] = enemy_data
				end
			end
		end
	end
	if (damage_info.result.type == "bleedout" or damage_info.variant == "tase") and data.name ~= "disabled" then
		CopLogicBase._exit(data.unit, "disabled")
	end
end
function TeamAILogicIdle.on_objective_unit_damaged(data, unit, attacker_unit)
	if attacker_unit ~= nil then
		TeamAILogicIdle.on_alert(data, {
			"aggression",
			attacker_unit:movement():m_pos(),
			nil,
			nil,
			attacker_unit
		})
	end
end
function TeamAILogicIdle.on_alert(data, alert_data)
	local alert_type = alert_data[1]
	local alert_unit = alert_data[5]
	if alert_unit:in_slot(data.enemy_slotmask) then
		local att_obj_data, is_new = CopLogicBase.identify_attention_obj_instant(data, alert_unit:key())
		if att_obj_data and (alert_type == "bullet" or alert_type == "aggression") then
			att_obj_data.alert_t = TimerManager:game():time()
		end
	end
end
function TeamAILogicIdle.on_long_dis_interacted(data, other_unit)
	local objective_type, objective_action, interrupt
	if other_unit:base().is_local_player then
		if other_unit:character_damage():need_revive() then
			objective_type = "revive"
			objective_action = "revive"
		elseif other_unit:character_damage():arrested() then
			objective_type = "revive"
			objective_action = "untie"
		else
			objective_type = "follow"
		end
	elseif other_unit:movement():need_revive() then
		objective_type = "revive"
		if other_unit:movement():current_state_name() == "arrested" then
			objective_action = "untie"
		else
			objective_action = "revive"
		end
	else
		objective_type = "follow"
	end
	local objective
	if objective_type == "follow" then
		objective = {
			type = objective_type,
			follow_unit = other_unit,
			called = true,
			destroy_clbk_key = false,
			scan = true
		}
		data.unit:sound():say("r01x_sin", true)
	else
		local followup_objective = {
			type = "act",
			scan = true,
			action = {
				type = "act",
				body_part = 1,
				variant = "crouch",
				blocks = {
					action = -1,
					walk = -1,
					hurt = -1,
					heavy_hurt = -1,
					aim = -1
				}
			}
		}
		objective = {
			type = "revive",
			follow_unit = other_unit,
			called = true,
			destroy_clbk_key = false,
			nav_seg = other_unit:movement():nav_tracker():nav_segment(),
			scan = true,
			action = {
				type = "act",
				variant = objective_action,
				body_part = 1,
				blocks = {
					action = -1,
					walk = -1,
					hurt = -1,
					light_hurt = -1,
					heavy_hurt = -1,
					aim = -1
				},
				align_sync = true
			},
			action_duration = tweak_data.interaction[objective_action == "untie" and "free" or objective_action].timer,
			followup_objective = followup_objective
		}
		data.unit:sound():say("r02a_sin", true)
	end
	data.unit:brain():set_objective(objective)
end
function TeamAILogicIdle.on_new_objective(data, old_objective)
	local new_objective = data.objective
	TeamAILogicBase.on_new_objective(data, old_objective)
	local my_data = data.internal_data
	if not my_data.exiting then
		if new_objective then
			if (new_objective.nav_seg or new_objective.follow_unit) and not new_objective.in_place then
				CopLogicBase._exit(data.unit, "travel")
			else
				CopLogicBase._exit(data.unit, "idle")
			end
		else
			CopLogicBase._exit(data.unit, "idle")
		end
	else
		debug_pause("[TeamAILogicIdle.on_new_objective] Already exiting", data.name, data.unit, old_objective and inspect(old_objective), new_objective and inspect(new_objective))
	end
	if new_objective and new_objective.stance then
		if new_objective.stance == "ntl" then
			data.unit:movement():set_cool(true)
		else
			data.unit:movement():set_cool(false)
		end
	end
	if old_objective and old_objective.fail_clbk then
		old_objective.fail_clbk(data.unit)
	end
end
function TeamAILogicIdle._upd_enemy_detection(data)
	managers.groupai:state():on_unit_detection_updated(data.unit)
	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local max_reaction
	if data.cool then
		max_reaction = AIAttentionObject.REACT_SURPRISED
	end
	local delay = CopLogicBase._upd_attention_obj_detection(data, nil, max_reaction)
	local new_attention, new_prio_slot, new_reaction = TeamAILogicIdle._get_priority_attention(data, data.detected_attention_objects, nil)
	if (not my_data._intimidate_t or my_data._intimidate_t + 2 < data.t) and not data.cool and not my_data._turning_to_intimidate and not my_data.acting and (not new_attention or not (new_reaction >= AIAttentionObject.REACT_SCARED)) then
		local can_turn = not data.unit:movement():chk_action_forbidden("walk")
		local civ = TeamAILogicIdle.find_civilian_to_intimidate(data.unit, can_turn and 180 or 90, 1200)
		if civ then
			my_data._intimidate_t = data.t
			new_attention, new_prio_slot, new_reaction = nil, nil, nil
			if can_turn and CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, civ:movement():m_pos()) then
				my_data._turning_to_intimidate = true
				my_data._primary_intimidation_target = civ
			else
				TeamAILogicIdle.intimidate_civilians(data, data.unit, true, true)
			end
		end
	end
	TeamAILogicBase._set_attention_obj(data, new_attention, new_reaction)
	if new_reaction and new_reaction >= AIAttentionObject.REACT_SCARED then
		local objective = data.objective
		local wanted_state
		local allow_trans, obj_failed = CopLogicBase.is_obstructed(data, objective, nil, new_attention)
		if allow_trans then
			wanted_state = TeamAILogicBase._get_logic_state_from_reaction(data, new_reaction)
			local objective = data.objective
			if objective and objective.type == "revive" then
				local revive_unit = objective.follow_unit
				local timer
				if revive_unit:base().is_local_player then
					timer = revive_unit:character_damage()._downed_timer
				elseif revive_unit:interaction().get_waypoint_time then
					timer = revive_unit:interaction():get_waypoint_time()
				end
				if timer and timer <= 10 then
					wanted_state = nil
				end
			end
		end
		if wanted_state and wanted_state ~= data.name then
			if obj_failed then
				managers.groupai:state():on_criminal_objective_failed(data.unit, data.objective)
			end
			if my_data == data.internal_data then
				CopLogicBase._exit(data.unit, wanted_state)
			end
			return
		end
	end
	CopLogicBase.queue_task(my_data, my_data.detection_task_key, TeamAILogicIdle._upd_enemy_detection, data, data.t + delay)
end
function TeamAILogicIdle.find_civilian_to_intimidate(criminal, max_angle, max_dis)
	local best_civ = TeamAILogicIdle._find_intimidateable_civilians(criminal, false, max_angle, max_dis)
	return best_civ
end
function TeamAILogicIdle._find_intimidateable_civilians(criminal, use_default_shout_shape, max_angle, max_dis)
	local head_pos = criminal:movement():m_head_pos()
	local look_vec = criminal:movement():m_rot():y()
	local close_dis = 400
	local intimidateable_civilians = {}
	local best_civ
	local best_civ_wgt = false
	local best_civ_angle
	local highest_wgt = 1
	local my_tracker = criminal:movement():nav_tracker()
	local chk_vis_func = my_tracker.check_visibility
	for key, unit in pairs(managers.groupai:state():fleeing_civilians()) do
		if chk_vis_func(my_tracker, unit:movement():nav_tracker()) and tweak_data.character[unit:base()._tweak_table].intimidateable and not unit:base().unintimidateable and not unit:anim_data().unintimidateable then
			local u_head_pos = unit:movement():m_head_pos() + math.UP * 30
			local vec = u_head_pos - head_pos
			local dis = mvector3.normalize(vec)
			local angle = vec:angle(look_vec)
			if use_default_shout_shape then
				max_angle = math.max(8, math.lerp(90, 30, dis / 1200))
				max_dis = 1200
			end
			if close_dis > dis or dis < max_dis and angle < max_angle then
				local slotmask = managers.slot:get_mask("AI_visibility")
				local ray = World:raycast("ray", head_pos, u_head_pos, "slot_mask", slotmask, "ray_type", "ai_vision")
				if not ray then
					local inv_wgt = dis * dis * (1 - vec:dot(look_vec))
					table.insert(intimidateable_civilians, {
						unit = unit,
						key = key,
						inv_wgt = inv_wgt
					})
					if not best_civ_wgt or best_civ_wgt > inv_wgt then
						best_civ_wgt = inv_wgt
						best_civ = unit
						best_civ_angle = angle
					end
					if highest_wgt < inv_wgt then
						highest_wgt = inv_wgt
					end
				end
			end
		end
	end
	return best_civ, highest_wgt, intimidateable_civilians
end
function TeamAILogicIdle.intimidate_civilians(data, criminal, play_sound, play_action, primary_target)
	local best_civ, highest_wgt, intimidateable_civilians = TeamAILogicIdle._find_intimidateable_civilians(criminal, true)
	local plural = false
	if #intimidateable_civilians > 1 then
		plural = true
	elseif #intimidateable_civilians <= 0 then
		return false
	end
	local act_name, sound_name
	local sound_suffix = plural and "plu" or "sin"
	if best_civ:anim_data().move then
		act_name = "gesture_stop"
		sound_name = "f02x_" .. sound_suffix
	else
		act_name = "arrest"
		sound_name = "f02x_" .. sound_suffix
	end
	if play_sound then
		criminal:sound():say(sound_name, true)
	end
	if play_action and not criminal:movement():chk_action_forbidden("action") then
		local new_action = {
			type = "act",
			variant = act_name,
			body_part = 3,
			align_sync = true
		}
		if criminal:brain():action_request(new_action) then
			data.internal_data.gesture_arrest = true
		end
	end
	local intimidated_primary_target = false
	for _, civ in ipairs(intimidateable_civilians) do
		local amount = civ.inv_wgt / highest_wgt
		if best_civ == civ.unit then
			amount = 1
		end
		if primary_target == civ.unit then
			intimidated_primary_target = true
			amount = 1
		end
		civ.unit:brain():on_intimidated(amount, criminal)
	end
	if not intimidated_primary_target and primary_target then
		primary_target:brain():on_intimidated(1, criminal)
	end
	if not managers.groupai:state():enemy_weapons_hot() then
		local alert = {
			"vo_intimidate",
			data.m_pos,
			800,
			data.SO_access,
			data.unit
		}
		managers.groupai:state():propagate_alert(alert)
	end
	return primary_target or best_civ
end
function TeamAILogicIdle.action_complete_clbk(data, action)
	local my_data = data.internal_data
	local action_type = action:type()
	if action_type == "turn" then
		data.internal_data.turning = nil
		if my_data._turning_to_intimidate then
			my_data._turning_to_intimidate = nil
			TeamAILogicIdle.intimidate_civilians(data, data.unit, true, true, my_data._primary_intimidation_target)
			my_data._primary_intimidation_target = nil
		end
	elseif action_type == "act" then
		my_data.acting = nil
		if my_data.scan and not my_data.exiting and (not my_data.queued_tasks or not my_data.queued_tasks[my_data.wall_stare_task_key]) and not my_data.stare_path_pos then
			my_data.wall_stare_task_key = "CopLogicIdle._chk_stare_into_wall" .. tostring(data.key)
			CopLogicBase.queue_task(my_data, my_data.wall_stare_task_key, CopLogicIdle._chk_stare_into_wall_1, data, data.t)
		end
		if my_data.performing_act_objective then
			local old_objective = my_data.performing_act_objective
			my_data.performing_act_objective = nil
			if action:expired() then
				if not my_data.action_timeout_clbk_id then
					managers.groupai:state():on_objective_complete(data.unit, old_objective)
				end
			else
				managers.groupai:state():on_objective_failed(data.unit, old_objective)
			end
			if my_data.delayed_clbks and my_data.delayed_clbks[my_data.revive_complete_clbk_id] then
				CopLogicBase.cancel_delayed_clbk(my_data, my_data.revive_complete_clbk_id)
				my_data.revive_complete_clbk_id = nil
				local revive_unit = my_data.reviving
				if revive_unit:interaction() then
					if revive_unit:interaction():active() then
						revive_unit:interaction():interact_interupt(data.unit)
					end
				elseif revive_unit:character_damage():arrested() then
					revive_unit:character_damage():unpause_arrested_timer()
				elseif revive_unit:character_damage():need_revive() then
					revive_unit:character_damage():unpause_downed_timer()
				end
				my_data.reviving = nil
				managers.groupai:state():on_criminal_objective_failed(data.unit, old_objective)
			elseif action:expired() then
				if not my_data.action_timeout_clbk_id then
					managers.groupai:state():on_criminal_objective_complete(data.unit, old_objective)
				end
			else
				managers.groupai:state():on_criminal_objective_failed(data.unit, old_objective)
			end
		end
	end
end
function TeamAILogicIdle.is_available_for_assignment(data, new_objective)
	if data.internal_data.exiting then
		return
	elseif data.path_fail_t and data.t < data.path_fail_t + 6 then
		return
	elseif data.objective then
		if data.internal_data.performing_act_objective and not data.unit:anim_data().act_idle then
			return
		end
		if new_objective and CopLogicBase.is_obstructed(data, new_objective, 0.2) then
			return
		end
		local old_objective_type = data.objective.type
		if not new_objective then
		elseif old_objective_type == "revive" then
			return
		elseif old_objective_type == "follow" and data.objective.called then
			return
		end
	end
	return true
end
function TeamAILogicIdle.clbk_heat(data)
	local inventory = data.unit:inventory()
	if inventory:is_selection_available(2) and inventory:equipped_selection() ~= 2 then
		inventory:equip_selection(2)
	end
end
function TeamAILogicIdle.clbk_revive_complete(ignore_this, data)
	local my_data = data.internal_data
	CopLogicBase.on_delayed_clbk(my_data, my_data.revive_complete_clbk_id)
	my_data.revive_complete_clbk_id = nil
	local revive_unit = my_data.reviving
	my_data.reviving = nil
	if alive(revive_unit) then
		managers.groupai:state():on_criminal_objective_complete(data.unit, my_data.performing_act_objective)
		if revive_unit:interaction() then
			if revive_unit:interaction():active() then
				revive_unit:interaction():interact(data.unit)
			end
		elseif revive_unit:character_damage() and (revive_unit:character_damage():need_revive() or revive_unit:character_damage():arrested()) then
			local hint = revive_unit:character_damage():need_revive() and 2 or 3
			managers.network:session():send_to_peers_synched("sync_teammate_helped_hint", hint, revive_unit, data.unit)
			revive_unit:character_damage():revive(data.unit)
		end
	else
		print("[TeamAILogicIdle.clbk_revive_complete] Revive unit dead.", revive_unit, data.unit)
		managers.groupai:state():on_criminal_objective_failed(data.unit, my_data.performing_act_objective)
	end
end
function TeamAILogicIdle.clbk_action_timeout(ignore_this, data)
	local my_data = data.internal_data
	CopLogicBase.on_delayed_clbk(my_data, my_data.action_timeout_clbk_id)
	my_data.action_timeout_clbk_id = nil
	local old_objective = data.objective
	if my_data.performing_act_objective then
		my_data.performing_act_objective = nil
		my_data.acting = nil
	end
	if not old_objective then
		debug_pause_unit(data.unit, "[TeamAILogicIdle.clbk_action_timeout] missing objective")
		return
	end
	managers.groupai:state():on_criminal_objective_complete(data.unit, old_objective)
end
function TeamAILogicIdle._check_should_relocate(data, my_data, objective)
	local follow_unit = objective.follow_unit
	local my_nav_seg_id = data.unit:movement():nav_tracker():nav_segment()
	local my_areas = managers.groupai:state():get_areas_from_nav_seg_id(my_nav_seg_id)
	local follow_unit_nav_seg_id = follow_unit:movement():nav_tracker():nav_segment()
	for _, area in ipairs(my_areas) do
		if area.nav_segs[follow_unit_nav_seg_id] then
			return
		end
	end
	local is_my_area_dangerous, is_follow_unit_area_dangerous
	for _, area in ipairs(my_areas) do
		if area.nav_segs[follow_unit_nav_seg_id] then
			is_my_area_dangerous = true
		else
		end
	end
	local follow_unit_areas = managers.groupai:state():get_areas_from_nav_seg_id(follow_unit_nav_seg_id)
	for _, area in ipairs(follow_unit_areas) do
		if next(area.police.units) then
			is_follow_unit_area_dangerous = true
		else
		end
	end
	if is_my_area_dangerous and not is_follow_unit_area_dangerous then
		return true
	end
	local max_allowed_dis_xy = 500
	local max_allowed_dis_z = 250
	mvector3.set(tmp_vec1, follow_unit:movement():m_pos())
	mvector3.subtract(tmp_vec1, data.m_pos)
	local too_far
	if max_allowed_dis_z < math.abs(mvector3.z(tmp_vec1)) then
		too_far = true
	else
		mvector3.set_z(tmp_vec1, 0)
		if max_allowed_dis_xy < mvector3.length(tmp_vec1) then
			too_far = true
		end
	end
	if too_far then
		return true
	end
end
function TeamAILogicIdle._get_priority_attention(data, attention_objects, reaction_func)
	reaction_func = reaction_func or TeamAILogicBase._chk_reaction_to_attention_object
	local best_target, best_target_priority_slot, best_target_priority, best_target_reaction
	for u_key, attention_data in pairs(attention_objects) do
		local att_unit = attention_data.unit
		local crim_record = attention_data.criminal_record
		if not attention_data.identified then
		elseif attention_data.pause_expire_t then
			if data.t > attention_data.pause_expire_t then
				attention_data.pause_expire_t = nil
			end
		elseif attention_data.stare_expire_t and data.t > attention_data.stare_expire_t then
			if attention_data.settings.pause then
				attention_data.stare_expire_t = nil
				attention_data.pause_expire_t = data.t + math.lerp(attention_data.settings.pause[1], attention_data.settings.pause[2], math.random())
			end
		else
			local distance = mvector3.distance(data.m_pos, attention_data.m_pos)
			local reaction = reaction_func(data, attention_data, not CopLogicAttack._can_move(data))
			local aimed_at = TeamAILogicIdle.chk_am_i_aimed_at(data, attention_data, attention_data.aimed_at and 0.95 or 0.985)
			attention_data.aimed_at = aimed_at
			local reaction_too_mild
			if not reaction or best_target_reaction and best_target_reaction > reaction then
				reaction_too_mild = true
			elseif distance < 150 and reaction <= AIAttentionObject.REACT_SURPRISED then
				reaction_too_mild = true
			end
			if not reaction_too_mild then
				local alert_dt = attention_data.alert_t and data.t - attention_data.alert_t or 10000
				local dmg_dt = attention_data.dmg_t and data.t - attention_data.dmg_t or 10000
				local mark_dt = attention_data.mark_t and data.t - attention_data.mark_t or 10000
				local near_threshold = 800
				if data.attention_obj and data.attention_obj.u_key == u_key then
					alert_dt = alert_dt * 0.8
					dmg_dt = dmg_dt * 0.8
					mark_dt = mark_dt * 0.8
					distance = distance * 0.8
				end
				local visible = attention_data.verified
				local near = near_threshold > distance
				local has_alerted = alert_dt < 5
				local has_damaged = dmg_dt < 2
				local been_marked = mark_dt < 8
				local dangerous_special = attention_data.is_very_dangerous
				local target_priority = distance
				local target_priority_slot = 0
				if visible and (dangerous_special or been_marked) and distance < 1600 then
					target_priority_slot = 1
				elseif visible and near and (has_alerted and has_damaged or been_marked) then
					target_priority_slot = 2
				elseif visible and near and has_alerted then
					target_priority_slot = 3
				elseif visible and has_alerted then
					target_priority_slot = 4
				elseif visible then
					target_priority_slot = 5
				elseif has_alerted then
					target_priority_slot = 6
				else
					target_priority_slot = 7
				end
				if reaction < AIAttentionObject.REACT_COMBAT then
					target_priority_slot = 10 + target_priority_slot + math.max(0, AIAttentionObject.REACT_COMBAT - reaction)
				end
				if target_priority_slot ~= 0 then
					local best = false
					if not best_target then
						best = true
					elseif best_target_priority_slot > target_priority_slot then
						best = true
					elseif target_priority_slot == best_target_priority_slot and best_target_priority > target_priority then
						best = true
					end
					if best then
						best_target = attention_data
						best_target_priority_slot = target_priority_slot
						best_target_priority = target_priority
						best_target_reaction = reaction
					end
				end
			end
		end
	end
	return best_target, best_target_priority_slot, best_target_reaction
end
