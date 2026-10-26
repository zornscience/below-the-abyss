# BTA-013: read-only submarine instruments

The prototype needs vessel state that remains legible without the temporary
resource-testing UI. BTA-013 consumes the existing components; it introduces no
new survival or sonar rules. The implementation plan mentions sonar state, but
there is no sonar domain component yet: a static NOT IMPLEMENTED label makes
that boundary explicit instead of inventing readiness, cooldown or detections.

`SubmarineHud` is a reusable full-rect Control scene hosted in a CanvasLayer.
`bind_sources(resources, hull, damage)` connects typed domain signals and takes
an initial snapshot after the domain components are initialized. Resources can
already be depleted before binding. ResourceGauge converts native units into a
normalized bar while retaining one-decimal values and capacities. DEPLETED is a
persistent textual state, cleared only by a positive refill. No UI method
consumes, replenishes or damages a resource.

Depth, effective safe operating rating and warning state come from BTA-012 APIs
and signals, with the original threshold semantics unchanged. Grace has no
change signal, so the HUD samples only the pressure detail each presentation
frame. It never decrements that simulation clock. Settings/debug pause preserves
the warning and grace display. Pressure disabled by configuration is explicitly
labeled; no false damage message is shown.

Rebinding disconnects every previous connection and clears transient feedback.
Invalid binding arguments preserve an existing valid binding. Missing/freed
sources hide stale gauges and show INSTRUMENTS DISCONNECTED. Consumers bind after
ready; setup returns an Error instead of silently accepting unavailable nodes.

A cool ink/teal console with warm battery accents and blue oxygen accents uses
native panels, bars, the bundled Godot font and small authored vector glyphs.
No art/font dependency, generated art, shaders or external assets are added.
All critical information has words and values; color reinforces the labels.
Minimum font size is 16 pixels, primary values 28–30 pixels. Rounded dark cards
separate instruments from the cave without full-screen shading or flashing.

Controls anchor to viewport edges without stretching the world viewport. Window
minimum is 800×600; the reference remains 1280×800. Native font sizes remain
constant at smaller windows; secondary identity text hides below 1100 pixels.
The top-right depth pod and bottom three-card resource deck leave the center
clear. The HUD and every descendant ignore mouse input and cannot take focus.
All interaction stays with existing movement and settings navigation.

Impact and pressure have independent compact textual feedback lasting 2.5
presentation seconds since the last event. Pressure accumulates actual reported
loss across continuous exposure rather than replacing an impact or creating one
widget each physics tick. Once feedback expires, the next event starts a new
aggregate. Depletion never expires with these messages. No screen shake,
flashing, fade animation, audio or gameplay consequences are added.

`--debug-controls` (or the editor's opt-in `development_mode`) exposes a separate
DevelopmentUI CanvasLayer. Interact opens the original test requests; wrapped
buttons keep keyboard/controller order and freeze the existing simulation while
focused. Returning to piloting hides that panel. The normal scene has no visible
or focusable test buttons and Interact does not pause movement. Existing test
suites explicitly enable debug mode where testing those controls. Historical
BTA-012 label assertions now target the real HUD; no domain assertions are
removed. This is prototype presentation, not the later accessibility-settings,
illustrated-art pipeline, station, upgrade, sonar or game-over milestones.
