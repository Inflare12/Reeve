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

## Mission event log

The simulation controller records timestamped events in the telemetry JSON output: simulation start, powered-flight start, engine cutoff, apogee, descent start, recovery deployment and ground contact. Events are detected from state transitions rather than a pre-scripted timeline. The current model does not include event logic for every real-world mission operation.
