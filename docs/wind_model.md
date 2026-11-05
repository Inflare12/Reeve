# Time-varying wind model

The optional `wind_model` configuration provides a deterministic, time-varying three-axis wind vector. It is sampled at the start of each fixed physics step and passed consistently into relative-airflow drag and telemetry.

Configuration keys are vectors:

- `base_velocity_m_s`: mean wind velocity in world coordinates.
- `gust_amplitude_m_s`: sinusoidal gust amplitude per axis.
- `gust_frequency_hz`: non-negative sinusoidal frequency per axis.
- `phase_rad`: initial phase per axis.

Each component is evaluated as:

`wind_i(t) = base_i + amplitude_i * sin(2*pi*frequency_i*t + phase_i)`

The model is deterministic and useful for controlled sensitivity studies. It is not a stochastic turbulence model, weather forecast, wind-shear profile or validated atmospheric boundary-layer simulation. All gust values are user-supplied.
