CopSound = CopSound or class()
function CopSound:init(unit)
	self._unit = unit
	self._speak_expire_t = 0
	local char_tweak = tweak_data.character[unit:base()._tweak_table]
	local nr_variations = char_tweak.speech_prefix_count
	self._prefix = (char_tweak.speech_prefix_p1 or "") .. (nr_variations and tostring(math.random(nr_variations)) or "") .. (char_tweak.speech_prefix_p2 or "") .. "_"
	unit:base():post_init()
end
function CopSound:destroy(unit)
	unit:base():pre_destroy(unit)
end
function CopSound:_play(sound_name, source_name)
	local source
	if source_name then
		source = Idstring(source_name)
	end
	local event = self._unit:sound_source(source):post_event(sound_name)
	return event
end
function CopSound:play(sound_name, source_name, sync)
	local event_id
	if type(sound_name) == "number" then
		event_id = sound_name
	end
	if sync then
		event_id = event_id or SoundDevice:string_to_id(sound_name)
		local sync_source_name = source_name or ""
		self._unit:network():send("unit_sound_play", event_id, sync_source_name)
	end
	local event = self:_play(event_id or sound_name, source_name)
	if not event then
		Application:error("[CopSound:play] event not found in Wwise", sound_name, event_id, self._unit)
		Application:stack_dump("error")
		return
	end
	return event
end
function CopSound:corpse_play(sound_name, source_name, sync)
	local event_id
	if type(sound_name) == "number" then
		event_id = sound_name
	end
	if sync then
		event_id = event_id or SoundDevice:string_to_id(sound_name)
		local sync_source_name = source_name or ""
		local u_id = managers.enemy:get_corpse_unit_data_from_key(self._unit:key()).u_id
		managers.network:session():send_to_peers_synched("corpse_sound_play", u_id, event_id, sync_source_name)
	end
	local event = self:_play(event_id or sound_name, source_name)
	if not event then
		Application:error("[CopSound:corpse_play] event not found in Wwise", sound_name, event_id, self._unit)
		Application:stack_dump("error")
		return
	end
	return event
end
function CopSound:stop(source_name)
	local source
	if source_name then
		source = Idstring(source_name)
	end
	self._unit:sound_source(source):stop()
end
function CopSound:say(sound_name, sync, skip_prefix)
	if self._last_speech then
		self._last_speech:stop()
	end
	local full_sound
	if skip_prefix then
		full_sound = sound_name
	else
		full_sound = self._prefix .. sound_name
	end
	local event_id
	if type(full_sound) == "number" then
		event_id = full_sound
	end
	if sync then
		event_id = event_id or SoundDevice:string_to_id(full_sound)
		self._unit:network():send("say", event_id)
	end
	self._last_speech = self:_play(event_id or full_sound)
	if not self._last_speech then
		Application:error("[CopSound:say] event not found in Wwise", full_sound, event_id, self._unit)
		Application:stack_dump("error")
		return
	end
	self._speak_expire_t = TimerManager:game():time() + 2
end
function CopSound:sync_say_str(full_sound)
	if self._last_speech then
		self._last_speech:stop()
	end
	self._last_speech = self:play(full_sound)
end
function CopSound:speaking(t)
	return t < self._speak_expire_t
end
function CopSound:anim_clbk_play_sound(unit, queue_name)
	self:_play(queue_name)
end
