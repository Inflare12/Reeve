class_name ReeveAtmosphere
extends RefCounted
## Simplified ISA-like dry-air model from -500 m to 20 km geopotential altitude.
## This is not a full US Standard Atmosphere 1976 implementation.

static func sample(altitude_m: float, conditions: Dictionary = {}) -> Dictionary:
	if not is_finite(altitude_m):
		return {"ok": false, "error": "Altitude must be finite."}
	if altitude_m < -500.0 or altitude_m > ReeveConstants.STRATOSPHERE_UPPER_LIMIT_M:
		return {
			"ok": false,
			"error": "Atmosphere model is only defined from -500 m to %.0f m geopotential altitude." % ReeveConstants.STRATOSPHERE_UPPER_LIMIT_M,
			"requested_altitude_m": altitude_m
		}
	var h: float = altitude_m
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

	var temperature_offset_k: float = float(conditions.get("temperature_offset_k", 0.0))
	var pressure_scale: float = float(conditions.get("pressure_scale", 1.0))
	if not is_finite(temperature_offset_k) or not is_finite(pressure_scale) or pressure_scale <= 0.0:
		return {"ok": false, "error": "Atmosphere temperature offset must be finite and pressure scale finite and positive."}
	temperature_k += temperature_offset_k
	pressure_pa *= pressure_scale
	if temperature_k <= 0.0 or pressure_pa <= 0.0:
		return {"ok": false, "error": "Atmosphere conditions produce non-positive absolute temperature or pressure."}
	var density_kg_m3: float = pressure_pa / (ReeveConstants.AIR_GAS_CONSTANT * temperature_k)
	var sutherland_mu0: float = 1.716e-5
	var sutherland_t0: float = 273.15
	var sutherland_s: float = 110.4
	var dynamic_viscosity_pa_s: float = sutherland_mu0 * pow(temperature_k / sutherland_t0, 1.5) * (sutherland_t0 + sutherland_s) / (temperature_k + sutherland_s)
	var speed_of_sound_m_s: float = sqrt(ReeveConstants.AIR_GAMMA * ReeveConstants.AIR_GAS_CONSTANT * temperature_k)

	return {
		"ok": true,
		"model": "REEVE simplified dry-air ISA-like profile with optional user offsets",
		"altitude_m": h,
		"temperature_offset_k": temperature_offset_k,
		"pressure_scale": pressure_scale,
		"temperature_k": temperature_k,
		"pressure_pa": pressure_pa,
		"density_kg_m3": density_kg_m3,
		"dynamic_viscosity_pa_s": dynamic_viscosity_pa_s,
		"speed_of_sound_m_s": speed_of_sound_m_s
	}

static func gravity_at_altitude(altitude_m: float) -> float:
	if not is_finite(altitude_m) or altitude_m <= -ReeveConstants.EARTH_MEAN_RADIUS_M:
		return NAN
	var radius: float = ReeveConstants.EARTH_MEAN_RADIUS_M + altitude_m
	return ReeveConstants.STANDARD_GRAVITY * pow(ReeveConstants.EARTH_MEAN_RADIUS_M / radius, 2.0)
