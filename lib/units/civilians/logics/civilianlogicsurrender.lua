local tmp_vec1 = Vector3()
CivilianLogicSurrender = class(CopLogicBase)
CivilianLogicSurrender.wants_rescue = CivilianLogicFlee.wants_rescue
function CivilianLogicSurrender.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()
	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}
	data.internal_data = my_data
	my_data.rsrv_pos = {}
	if old_internal_data then
		my_data.rsrv_pos = old_internal_data.rsrv_pos or my_data.rsrv_pos
	end
	if data.unit:anim_data().tied then
		managers.groupai:state():on_hostage_state(true, data.key)
		my_data.is_hostage = true
	end
	if data.unit:anim_data().drop and not data.unit:anim_data().tied then
		data.unit:interaction():set_active(true, true)
		my_data.interaction_active = true
	end
	my_data.state_enter_t = TimerManager:game():time()
	if not data.unit:anim_data().move and managers.groupai:state():rescue_state() and managers.groupai:state():is_nav_seg_safe(data.unit:movement():nav_tracker():nav_segment()) then
		CivilianLogicFlee._add_delayed_rescue_SO(data, my_data)
	end
	local scare_max = data.char_tweak.scare_max
	my_data.scare_max = math.lerp(scare_max[1], scare_max[2], math.random())
	local submission_max = data.char_tweak.submission_max
	my_data.submission_max = math.lerp(submission_max[1], submission_max[2], math.random())
	my_data.scare_meter = 0
	my_data.submission_meter = 0
	my_data.last_upd_t = data.t
	my_data.nr_random_screams = 0
	if not my_data.rsrv_pos.stand then
		local pos_rsrv = {
			position = mvector3.copy(data.m_pos),
			radius = 60,
			filter = data.pos_rsrv_id
		}
		my_data.rsrv_pos.stand = pos_rsrv
		managers.navigation:add_pos_reservation(pos_rsrv)
	end
	data.run_away_next_chk_t = nil
	data.unit:brain():set_update_enabled_state(false)
	data.unit:movement():set_allow_fire(false)
	managers.groupai:state():add_to_surrendered(data.unit, callback(CivilianLogicSurrender, CivilianLogicSurrender, "queued_update", data))
	my_data.surrender_clbk_registered = true
	data.unit:movement():set_stance("hos")
	data.unit:movement():set_cool(false)
	if my_data ~= data.internal_data then
		return
	end
	local attention_settings
	if not managers.groupai:state():enemy_weapons_hot() then
		attention_settings = {
			"civ_enemy_cbt",
			"civ_civ_cbt"
		}
		my_data.enemy_weapons_hot_listen_id = "CivilianLogicSurrender" .. tostring(data.key)
		managers.groupai:state():add_listener(my_data.enemy_weapons_hot_listen_id, {
			"enemy_weapons_hot"
		}, callback(CivilianLogicIdle, CivilianLogicIdle, "clbk_enemy_weapons_hot", data))
	end
	data.unit:brain():set_attention_settings(attention_settings)
	if not data.been_outlined and data.char_tweak.outline_on_discover then
		my_data.outline_detection_task_key = "CivilianLogicIdle._upd_outline_detection" .. tostring(data.key)
		CopLogicBase.queue_task(my_data, my_data.outline_detection_task_key, CivilianLogicIdle._upd_outline_detection, data, data.t + 2)
	end
	if data.objective and data.objective.aggressor_unit then
		if not data.objective.initial_act then
			CivilianLogicSurrender.on_intimidated(data, data.objective.amount, data.objective.aggressor_unit, true)
		else
			if data.objective.initial_act == "halt" then
				managers.groupai:state():register_fleeing_civilian(data.key, data.unit)
			end
			CivilianLogicSurrender._do_initial_act(data, data.objective.amount, data.objective.aggressor_unit, data.objective.initial_act)
		end
	end
end
function CivilianLogicSurrender.exit(data, new_logic_name, enter_params)
	CopLogicBase.exit(data, new_logic_name, enter_params)
	local my_data = data.internal_data
	if data.unit:anim_data().tied and new_logic_name ~= "trade" and new_logic_name ~= "inactive" and (not data.objective or not data.objective.forced) then
		debug_pause_unit(data.unit, "[CivilianLogicSurrender.exit] tied civilian!!!", data.unit, "new_logic_name", new_logic_name)
	end
	CivilianLogicFlee._unregister_rescue_SO(data, my_data)
	managers.groupai:state():unregister_fleeing_civilian(data.key)
	if new_logic_name ~= "inactive" then
		data.unit:base():set_slot(data.unit, 21)
	end
	CopLogicBase.cancel_delayed_clbks(my_data)
	if new_logic_name ~= "trade" and my_data.interaction_active then
		data.unit:interaction():set_active(false, true)
		my_data.interaction_active = nil
		if data.has_outline then
			data.unit:base():set_contour(true)
		end
	end
	if my_data.surrender_clbk_registered then
		managers.groupai:state():remove_from_surrendered(data.unit)
	end
	CopLogicBase.cancel_queued_tasks(my_data)
	if my_data.is_hostage then
		managers.groupai:state():on_hostage_state(false, data.key)
		my_data.is_hostage = nil
	end
	CopLogicBase._reset_attention(data)
	if my_data.enemy_weapons_hot_listen_id then
		managers.groupai:state():remove_listener(my_data.enemy_weapons_hot_listen_id)
	end
end
function CivilianLogicSurrender.queued_update(rubbish, data)
	local my_data = data.internal_data
	CivilianLogicSurrender._update_enemy_detection(data, my_data)
	if my_data.submission_meter == 0 and not data.unit:anim_data().tied and (not data.unit:anim_data().react_enter or not not data.unit:anim_data().idle) then
		if data.unit:anim_data().drop then
			local new_action = {
				type = "act",
				variant = "stand",
				body_part = 1
			}
			data.unit:brain():action_request(new_action)
		end
		my_data.surrender_clbk_registered = false
		data.unit:brain():set_objective({type = "free", is_default = true})
		return
	else
		CivilianLogicFlee._chk_add_delayed_rescue_SO(data, my_data)
		managers.groupai:state():add_to_surrendered(data.unit, callback(CivilianLogicSurrender, CivilianLogicSurrender, "queued_update", data))
	end
	if data.unit:anim_data().act and my_data.rsrv_pos.stand then
		my_data.rsrv_pos.stand.position = mvector3.copy(data.m_pos)
		managers.navigation:move_pos_rsrv(my_data.rsrv_pos.stand)
	end
end
function CivilianLogicSurrender.on_tied(data, aggressor_unit, not_tied)
	local my_data = data.internal_data
	if my_data.is_hostage then
		return
	end
	if not_tied then
		if data.has_outline then
			data.unit:base():set_contour(false)
			data.has_outline = nil
		end
		data.unit:inventory():destroy_all_items()
		if my_data.interaction_active then
			data.unit:interaction():set_active(false, true)
			my_data.interaction_active = nil
		end
		data.unit:character_damage():drop_pickup()
		data.unit:character_damage():set_pickup(nil)
	else
		local action_data = {
			type = "act",
			body_part = 1,
			variant = "tied",
			blocks = {
				light_hurt = -1,
				hurt = -1,
				heavy_hurt = -1,
				hurt_sick = -1,
				walk = -1
			}
		}
		local action_res = data.unit:brain():action_request(action_data)
		if action_res then
			managers.groupai:state():on_hostage_state(true, data.key)
			my_data.is_hostage = true
			if data.has_outline then
				data.unit:base():set_contour(false)
				data.has_outline = nil
			end
			data.unit:inventory():destroy_all_items()
			managers.groupai:state():on_civilian_tied(data.unit:key())
			data.unit:base():set_slot(data.unit, 22)
			if data.unit:movement() then
				data.unit:movement():remove_giveaway()
			end
			if my_data.interaction_active then
				data.unit:interaction():set_active(false, true)
				my_data.interaction_active = nil
			end
			data.unit:character_damage():drop_pickup()
			data.unit:character_damage():set_pickup(nil)
			CivilianLogicFlee._chk_add_delayed_rescue_SO(data, my_data)
			if aggressor_unit == managers.player:player_unit() then
				managers.statistics:tied({
					name = data.unit:base()._tweak_table
				})
			else
				aggressor_unit:network():send_to_unit({
					"statistics_tied",
					data.unit:base()._tweak_table
				})
			end
		end
	end
end
function CivilianLogicSurrender._do_initial_act(data, amount, aggressor_unit, initial_act)
	local my_data = data.internal_data
	local adj_sumbission = amount * data.char_tweak.submission_intimidate
	my_data.submission_meter = math.min(my_data.submission_max, my_data.submission_meter + adj_sumbission)
	local adj_scare = amount * data.char_tweak.scare_intimidate
	my_data.scare_meter = math.max(0, my_data.scare_meter + adj_scare)
	local action_data = {
		type = "act",
		body_part = 1,
		variant = initial_act,
		clamp_to_graph = true
	}
	data.unit:brain():action_request(action_data)
end
function CivilianLogicSurrender.action_complete_clbk(data, action)
	local my_data = data.internal_data
	local action_type = action:type()
	if action_type == "walk" then
		if action:expired() then
			my_data.rsrv_pos.stand = my_data.rsrv_pos.move_dest
			my_data.rsrv_pos.move_dest = nil
		elseif my_data.rsrv_pos.move_dest then
			if not my_data.rsrv_pos.stand then
				my_data.rsrv_pos.stand = managers.navigation:add_pos_reservation({
					position = mvector3.copy(data.m_pos),
					radius = 45,
					filter = data.pos_rsrv_id
				})
			end
			managers.navigation:unreserve_pos(my_data.rsrv_pos.move_dest)
			my_data.rsrv_pos.move_dest = nil
		end
	elseif action_type == "act" and my_data.interaction_active then
		data.unit:interaction():set_active(false, true)
		my_data.interaction_active = nil
	end
end
function CivilianLogicSurrender.on_intimidated(data, amount, aggressor_unit, skip_delay)
	if data.unit:anim_data().tied then
		return
	end
	if not tweak_data.character[data.unit:base()._tweak_table].intimidateable or data.unit:base().unintimidateable or data.unit:anim_data().unintimidateable then
		return
	end
	local my_data = data.internal_data
	if not my_data.delayed_intimidate_id or not my_data.delayed_clbks or not my_data.delayed_clbks[my_data.delayed_intimidate_id] then
		if skip_delay then
			CivilianLogicSurrender._delayed_intimidate_clbk(nil, {
				data,
				amount,
				aggressor_unit
			})
		else
			my_data.delayed_intimidate_id = "intimidate" .. tostring(data.unit:key())
			local delay = math.max(0, 1 - amount) + math.random() * 0.2
			CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_intimidate_id, callback(CivilianLogicSurrender, CivilianLogicSurrender, "_delayed_intimidate_clbk", {
				data,
				amount,
				aggressor_unit
			}), TimerManager:game():time() + delay)
		end
	end
end
function CivilianLogicSurrender._delayed_intimidate_clbk(ignore_this, params)
	local data = params[1]
	local my_data = data.internal_data
	if my_data.delayed_intimidate_id then
		CopLogicBase.on_delayed_clbk(my_data, my_data.delayed_intimidate_id)
		my_data.delayed_intimidate_id = nil
	end
	if data.unit:movement():chk_action_forbidden("walk") then
		return
	end
	local amount = params[2]
	local anim_data = data.unit:anim_data()
	local adj_sumbission = amount * data.char_tweak.submission_intimidate
	my_data.submission_meter = math.min(my_data.submission_max, my_data.submission_meter + adj_sumbission)
	local adj_scare = amount * data.char_tweak.scare_intimidate
	my_data.scare_meter = math.max(0, my_data.scare_meter + adj_scare)
	if anim_data.drop or anim_data.react_enter and not anim_data.idle then
	elseif anim_data.react or anim_data.panic or anim_data.halt then
		local action_data = {
			type = "act",
			body_part = 1,
			clamp_to_graph = true,
			variant = anim_data.move and "halt" or "drop"
		}
		local action_res = data.unit:brain():action_request(action_data)
		if action_res and action_data.variant == "drop" then
			managers.groupai:state():unregister_fleeing_civilian(data.key)
			data.unit:interaction():set_active(true, true)
			my_data.interaction_active = true
		end
	else
		local action_data = {
			type = "act",
			body_part = 1,
			variant = "panic",
			clamp_to_graph = true
		}
		data.unit:brain():action_request(action_data)
		data.unit:sound():say("a02x_any", true)
		if data.unit:unit_data().mission_element then
			data.unit:unit_data().mission_element:event("panic", data.unit)
		end
		if not managers.groupai:state():enemy_weapons_hot() then
			local alert = {
				"vo_distress",
				data.unit:movement():m_head_pos(),
				200,
				data.SO_access,
				data.unit
			}
			managers.groupai:state():propagate_alert(alert)
		end
	end
end
function CivilianLogicSurrender.on_alert(data, alert_data)
	local alert_type = alert_data[1]
	if alert_type ~= "aggression" and alert_type ~= "bullet" then
		return
	end
	local anim_data = data.unit:anim_data()
	if anim_data.tied then
		return
	end
	if CopLogicBase.is_alert_aggressive(alert_data[1]) then
		local aggressor = alert_data[5]
		if aggressor and aggressor:base() then
			local is_intimidation
			if aggressor:base().is_local_player then
				if managers.player:has_category_upgrade("player", "civ_calming_alerts") then
					is_intimidation = true
				end
			elseif aggressor:base().is_husk_player and aggressor:base():upgrade_value("player", "civ_calming_alerts") then
				is_intimidation = true
			end
			if is_intimidation then
				data.unit:brain():on_intimidated(1, aggressor)
				return
			end
		end
	end
	data.t = TimerManager:game():time()
	if not CopLogicBase.is_alert_dangerous(alert_data[1]) then
		return
	end
	local my_data = data.internal_data
	local scare_modifier = data.char_tweak.scare_shot
	if anim_data.halt or anim_data.react then
		scare_modifier = scare_modifier * 4
	end
	my_data.scare_meter = math.min(my_data.scare_max, my_data.scare_meter + scare_modifier)
	if my_data.scare_meter == my_data.scare_max and 5 < data.t - my_data.state_enter_t then
		data.unit:sound():say("a01x_any", true)
		if not my_data.inside_intimidate_aura then
			data.unit:brain():set_objective({
				type = "free",
				is_default = true,
				alert_data = clone(alert_data)
			})
		end
	elseif not data.unit:sound():speaking(TimerManager:game():time()) then
		local rand = math.random()
		local alert_dis_sq = mvector3.distance_sq(data.m_pos, alert_data[2])
		local max_scare_dis_sq = 4000000
		if alert_dis_sq < max_scare_dis_sq then
			rand = math.lerp(rand, rand * 2, math.min(alert_dis_sq) / 4000000)
			local scare_mul = (max_scare_dis_sq - alert_dis_sq) / max_scare_dis_sq
			local max_nr_random_screams = 8
			scare_mul = scare_mul * math.lerp(1, 0.3, my_data.nr_random_screams / max_nr_random_screams)
			local chance_voice_1 = 0.3 * scare_mul
			local chance_voice_2 = 0.3 * scare_mul
			if data.char_tweak.female then
				chance_voice_1 = chance_voice_1 * 1.2
				chance_voice_2 = chance_voice_2 * 1.2
			end
			if rand < chance_voice_1 then
				data.unit:sound():say("a01x_any", true)
				my_data.nr_random_screams = math.min(my_data.nr_random_screams + 1, max_nr_random_screams)
			elseif rand < chance_voice_1 + chance_voice_2 then
				data.unit:sound():say("a02x_any", true)
				my_data.nr_random_screams = math.min(my_data.nr_random_screams + 1, max_nr_random_screams)
			end
		end
	end
end
function CivilianLogicSurrender._update_enemy_detection(data, my_data)
	managers.groupai:state():on_unit_detection_updated(data.unit)
	local t = TimerManager:game():time()
	local delta_t = t - my_data.last_upd_t
	local my_pos = data.unit:movement():m_head_pos()
	local enemies = managers.groupai:state():all_criminals()
	local visible, closest_dis, closest_enemy
	my_data.inside_intimidate_aura = nil
	local my_tracker = data.unit:movement():nav_tracker()
	local chk_vis_func = my_tracker.check_visibility
	for e_key, u_data in pairs(enemies) do
		if not u_data.is_deployable and chk_vis_func(my_tracker, u_data.tracker) then
			local enemy_unit = u_data.unit
			local enemy_pos = u_data.m_det_pos
			local my_vec = tmp_vec1
			local dis = mvector3.direction(my_vec, enemy_pos, my_pos)
			local inside_aura
			if u_data.unit:base().is_local_player then
				if managers.player:has_category_upgrade("player", "intimidate_aura") and dis < managers.player:upgrade_value("player", "intimidate_aura", 0) then
					inside_aura = true
				end
			elseif u_data.unit:base().is_husk_player and u_data.unit:base():upgrade_value("player", "intimidate_aura") and dis < u_data.unit:base():upgrade_value("player", "intimidate_aura") then
				inside_aura = true
			end
			if (inside_aura or dis < 700) and (not closest_dis or closest_dis > dis) then
				closest_dis = dis
				closest_enemy = enemy_unit
			end
			if inside_aura then
				my_data.inside_intimidate_aura = true
			elseif dis < 700 then
				local look_dir = enemy_unit:movement():m_head_rot():y()
				if mvector3.dot(my_vec, look_dir) > 0.65 then
					visible = true
				end
			end
		end
	end
	local attention = data.unit:movement():attention()
	local attention_unit = attention and attention.unit or nil
	if not attention_unit then
		if closest_enemy and closest_dis < 700 and data.unit:anim_data().ik_type then
			CopLogicBase._set_attention_on_unit(data, closest_enemy)
		end
	elseif mvector3.distance(my_pos, attention_unit:movement():m_head_pos()) > 900 or not data.unit:anim_data().ik_type then
		CopLogicBase._reset_attention(data)
	end
	if my_data.inside_intimidate_aura then
		my_data.submission_meter = my_data.submission_max
	elseif visible then
		my_data.submission_meter = math.min(my_data.submission_max, my_data.submission_meter + delta_t)
	else
		my_data.submission_meter = math.max(0, my_data.submission_meter - delta_t)
	end
	if managers.groupai:state():rescue_state() and managers.groupai:state():is_nav_seg_safe(data.unit:movement():nav_tracker():nav_segment()) then
		if not my_data.rescue_active then
			CivilianLogicFlee._add_delayed_rescue_SO(data, my_data)
		end
	elseif my_data.rescue_active then
		CivilianLogicFlee._unregister_rescue_SO(data, my_data)
	end
	my_data.scare_meter = math.max(0, my_data.scare_meter - delta_t)
	my_data.last_upd_t = t
end
function CivilianLogicSurrender.is_available_for_assignment(data, objective)
	if objective and objective.forced then
		return true
	end
	return not data.unit:anim_data().tied and (objective and objective.type == "revive" or data.t - data.internal_data.state_enter_t > 5 and data.internal_data.submission_meter / data.internal_data.submission_max < 0.95)
end
function CivilianLogicSurrender.on_new_objective(data, old_objective)
	CivilianLogicIdle.on_new_objective(data, old_objective)
end
function CivilianLogicSurrender.on_rescue_allowed_state(data, state)
	CivilianLogicFlee.on_rescue_allowed_state(data, state)
end
