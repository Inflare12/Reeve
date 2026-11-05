# Rocket workshop component representations

The workshop now displays separate conceptual meshes for the fuselage, nose, fins, fuel-tank representation, oxidizer-tank representation, engine, nozzle, payload, avionics, recovery compartment, external sensor and structural support.

The internal tank, engine, payload, avionics, recovery, sensor and support meshes are illustrative arrangement markers. Their shapes and positions are not manufacturing geometry, pressure-vessel definitions, engine construction drawings or structural interfaces.

Only the fuselage shell and fin plates receive geometry-derived mass estimates in the current workshop. The other component groups have explicit user-entered mass fields. A zero value means the component is not included in the mass roll-up; it does not mean the real assembly has zero mass. Enter a defensible mass estimate from an identified source before using the total vehicle mass.

The component list distinguishes mass-counted values from components that are visualized but not yet included in the bill of materials. The configuration file stores user-entered component masses and editable fuselage/fin parameters. A save-and-open action transfers the saved configuration to Flight Lab. The handoff carries total mass, fuselage length/diameter, frontal reference area and fin count/geometry for the Flight Lab visual. It does not infer a drag coefficient, propulsion profile or internal component placement. Full component-specific geometry editing remains future work.
