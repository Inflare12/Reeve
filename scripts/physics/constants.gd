class_name ReeveConstants
extends RefCounted
## SI constants used by the educational simulation core.

const STANDARD_GRAVITY: float = 9.80665 # m/s^2
const EARTH_MEAN_RADIUS_M: float = 6371008.8 # m
const AIR_GAS_CONSTANT: float = 287.05287 # J/(kg K), dry air approximation
const AIR_GAMMA: float = 1.4
const SEA_LEVEL_TEMPERATURE_K: float = 288.15
const SEA_LEVEL_PRESSURE_PA: float = 101325.0
const SEA_LEVEL_DENSITY_KG_M3: float = 1.225
const TROPOSPHERE_LAPSE_K_PER_M: float = 0.0065
const TROPOPAUSE_ALTITUDE_M: float = 11000.0
const STRATOSPHERE_UPPER_LIMIT_M: float = 20000.0

static func km_to_m(value_km: float) -> float:
	return value_km * 1000.0

static func m_to_km(value_m: float) -> float:
	return value_m / 1000.0

static func celsius_to_kelvin(value_c: float) -> float:
	return value_c + 273.15

static func kelvin_to_celsius(value_k: float) -> float:
	return value_k - 273.15
