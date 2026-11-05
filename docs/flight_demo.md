# Flight Lab gravity-only demonstration

The main Flight Lab includes a deterministic gravity-only drop demonstration to exercise the translational dynamics and live telemetry path without requiring an engine model.

## Scenario inputs

- Initial altitude: 20 m above the local ground plane.
- Initial velocity: zero.
- Vehicle mass: 25 kg (an explicit illustrative scenario input).
- Thrust: 0 N.
- Propellant flow: 0 kg/s.
- Drag coefficient: 0.5 (illustrative constant for this demonstration only).
- Reference area: circular frontal area calculated from the example visual diameter (0.56 m).
- Ground altitude: 0 m.
- Integration timestep: 1/120 s.

The demonstration is not a rocket launch and does not represent a propulsion system. It is a gravity/drag integration check. The model stops and records a ground-contact state when the simulated position crosses the configured ground altitude.

Use the Rocket Workshop to change conceptual geometry and material assumptions. The current Flight Lab demo does not yet automatically transfer the workshop configuration into a flight model.
