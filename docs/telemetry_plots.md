# Telemetry plots

The Flight Lab creates lightweight plots for altitude, total speed, acceleration magnitude, dynamic pressure and vehicle mass. Each plot reads the telemetry recorder's actual sample array; it does not synthesize data or interpolate between render frames.

The plot x-axis is sample order (uniform fixed-step samples for a normal simulation run), and the y-axis auto-scales to finite values in the current run. Empty plots explicitly show that no simulation samples are available. The current plotting control is intended for compact live monitoring; it does not yet provide cursor readouts, zoom, selectable time windows, multi-run overlays or high-resolution scientific plotting.

Telemetry retention is bounded (default maximum 50,000 samples). When the limit is reached, the recorder keeps every second retained sample before appending new data. The plot uses actual sample timestamps on the horizontal axis, so older decimated samples remain correctly spaced relative to newer fixed-step samples. This is a memory/performance compromise; it reduces time resolution for older portions of long runs.
