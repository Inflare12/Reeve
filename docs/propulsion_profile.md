# Supplied propulsion profile interface

REEVE can read a user-supplied JSON time series for conceptual propulsion playback. It does not generate engine performance, combustion chemistry, injector or feed-system designs, or firing instructions.

## Schema

Example structure (zero-valued points are schema placeholders, not engine data):

    {
      "schema_version": 1,
      "profile_name": "User-labelled profile",
      "data_quality": "measured",
      "source_description": "Identify source document and test conditions",
      "points": [
        {"time_s": 0.0, "thrust_n": 0.0, "mass_flow_kg_s": 0.0},
        {"time_s": 1.0, "thrust_n": 0.0, "mass_flow_kg_s": 0.0}
      ]
    }

Accepted data-quality labels are measured, supplied, estimated, and synthetic_test. Every point must contain finite, non-negative thrust and mass flow, with strictly increasing non-negative time. The module linearly interpolates between samples, returns zero outside the supplied time interval, and calculates total impulse and integrated propellant mass using trapezoidal integration.

A profile must identify its source and conditions before its results can be interpreted. The module does not validate whether the supplied curve represents a real engine or is suitable for any vehicle. Do not treat an estimated curve as measured performance.

## Flight Lab workflow

The Flight Lab can load this JSON profile through its file picker. The user must separately enter propellant mass. The workshop vehicle mass is treated as dry mass; the initial wet mass is dry mass plus the user-entered propellant mass. A loaded profile with zero propellant mass is rejected, and non-zero propellant mass without a loaded profile is also rejected. The profile is played back as supplied data; it is not generated or validated as a real engine curve.

During playback, REEVE records actual capped mass flow from the integrator and derives instantaneous specific impulse as `Isp = thrust / (mass_flow * g0)`, with effective exhaust velocity `ve = Isp * g0`. These derived values are meaningful only to the extent that the supplied thrust and mass-flow series are consistent and sourced.
