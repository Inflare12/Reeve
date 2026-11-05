class_name ReeveAtmosphere
extends RefCounted
## Simplified ISA-like dry-air model from -500 m to 20 km geopotential altitude.
## This is not a full US Standard Atmosphere 1976 implementation.

static func sample(altitude_m: float) -> Dictionary:
	var h: float = clampf(altitude_m, -500.0, ReeveConstants.STRATOSPHERE_UPPER_LIMIT_M)
	var temperature_k: float
	var pressure_pa: float

	if h <= ReeveConstants.TROPOPAUSE_ALTITUDE_M:
		temperature_k = ReeveConstants.SEA_LEVEL_TEMPERATURE_K - ReeveConstants.TROPOSPHERE_LAPSE_K_PER_M * h
		var exponent: float = ReeveConstants.STANDARD_GRAVITY / (ReeveConstants.AIR_GAS_CONSTANT * ReeveConstants.TROPOSPHERE_LAPSE_K_PER_M)
		pressure_pa = ReeveConstants.SEA_LEVEL_PRESSURE_PA * pow(temperature_k / ReeveConstants.SEA_LEVEL_TEMPERATURE_K, exponent)
	else:
		temperature_k = 216.65
		var pressure_at_11km: float = 22632.06
		pressure_pa = pressure_at_11km * exp(
			-ReeveConstants.STANDARD_GRAVITY * (h - ReeveConstants.TROPOPAUSE_ALTITUDE_M)
			/ (ReeveConstants.AIR_GAS_CONSTANT * temperature_k)
		)

	var density_kg_m3: float = pressure_pa / (ReeveConstants.AIR_GAS_CONSTANT * temperature_k)
	var speed_of_sound_m_s: float = sqrt(ReeveConstants.AIR_GAMMA * ReeveConstants.AIR_GAS_CONSTANT * temperature_k)

	return {
		"altitude_m": h,
		"temperature_k": temperature_k,
		"pressure_pa": pressure_pa,
		"density_kg_m3": density_kg_m3,
		"speed_of_sound_m_s": speed_of_sound_m_s
	}

static func gravity_at_altitude(altitude_m: float) -> float:
	var radius: float = ReeveConstants.EARTH_MEAN_RADIUS_M + maxf(altitude_m, -500.0)
	return ReeveConstants.STANDARD_GRAVITY * pow(ReeveConstants.EARTH_MEAN_RADIUS_M / radius, 2.0)
