SoundTweakData = SoundTweakData or class()
function SoundTweakData:init()
	self.acoustics = {}
	self.acoustics.pd2_acoustics_forest = {}
	self.acoustics.pd2_acoustics_forest.states = {
		acoustic_flag = "acoustic_forest"
	}
	self.acoustics.pd2_acoustics_flat = {}
	self.acoustics.pd2_acoustics_flat.states = {
		acoustic_flag = "acoustic_flat"
	}
	self.acoustics.pd2_acoustics_indoor_small = {}
	self.acoustics.pd2_acoustics_indoor_small.states = {
		acoustic_flag = "acoustic_indoors_small"
	}
	self.acoustics.pd2_acoustics_indoor_medium = {}
	self.acoustics.pd2_acoustics_indoor_medium.states = {
		acoustic_flag = "acoustic_indoors_medium"
	}
	self.acoustics.pd2_acoustics_indoor_large = {}
	self.acoustics.pd2_acoustics_indoor_large.states = {
		acoustic_flag = "acoustic_indoors_large"
	}
	self.acoustics.pd2_acoustics_outdoor_small_echo = {}
	self.acoustics.pd2_acoustics_outdoor_small_echo.states = {
		acoustic_flag = "acoustic_outdoors_small"
	}
	self.acoustics.pd2_acoustics_outdoor_medium_echo = {}
	self.acoustics.pd2_acoustics_outdoor_medium_echo.states = {
		acoustic_flag = "acoustic_outdoors_medium"
	}
	self.acoustics.pd2_acoustics_outdoor_large_echo = {}
	self.acoustics.pd2_acoustics_outdoor_large_echo.states = {
		acoustic_flag = "acoustic_outdoors_large"
	}
	self.acoustics.pd2_acoustics_tunnel_small = {}
	self.acoustics.pd2_acoustics_tunnel_small.states = {
		acoustic_flag = "acoustic_tunnel_small"
	}
	self.acoustics.pd2_acoustics_tunnel_medium = {}
	self.acoustics.pd2_acoustics_tunnel_medium.states = {
		acoustic_flag = "acoustic_tunnel_medium"
	}
end
