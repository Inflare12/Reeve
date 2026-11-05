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
