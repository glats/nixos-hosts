# T14 Quattro plugin adoption
Objective: replace t14 desktop components with Quattro shell plugins one at a time without breaking the session. Branch: master (consumer) and main (fork), no feature branches per user request. Delivery: one work-unit commit per component, fork first then consumer pin. Test runner: nix eval regression files under tests/, fork `nix flake check --no-build`, t14 toplevel build, live check after `nixos-build test`.

## Specs
- S1 Group A, additive bar widgets: "a me parace bien". Add media (MPRIS), indicators, weather. Exclude the agents widget: "epro el uso de agnetes yua lo tengo creo, teng oepcnode, claude y codex . pero me quedo con opecnode con herdr que se supone ya lo tengo".
- S2 Group B, visible daemons: "la aopcion b tambien la quiero". Candidates: notifications (replaces Mako), OSD (replaces SwayOSD), night light (wraps hyprsunset), low battery warning (replaces omarchy-battery-monitor), clipboard and emojis (today in Walker), Omarchy menu, background (replaces swaybg).
- S3 Group C last: "dejemos c para el final". Lock (hyprlock), idle (hypridle, port the mouse-wiggle inhibitor) and polkit are out of scope until S1-S2 are done and the user confirms.
- S4 Each replacement is its own commit that enables the Quattro plugin, disables the legacy equivalent and keybindings, and is revertible alone. Assumption: the v3 (non-Quattro) configuration stays byte-identical.
- S5 Preserve prior feature guarantees: HDM owns lid/dock, Hyprlang, greetd/ReGreet, wayvnc, mouse-wiggle, NetworkManager.

## Tasks
- T0 [S1-S5] delegated explore — pending: map how each candidate plugin integrates (config keys, IPC commands, keybindings, conflicts with legacy daemons, runtime dependencies). Mapping trigger: more than ~5 sequential lookups across fork and runtime.
- T1 [S1,S4] — pending: media, indicators, weather widgets.
- T2 [S2,S4] — pending: notifications replace Mako.
- T3 [S2,S4] — pending: OSD replaces SwayOSD.
- T4 [S2,S4] — pending: night light and battery services.
- T5 [S2,S4] — pending: clipboard and emojis overlays.
- T6 [S2,S4] — pending: Omarchy menu.
- T7 [S2,S4] — pending: background replaces swaybg.
- T8 [S3] — deferred: lock, idle, polkit.

## Log
- L1 (2026-10-17): "si me gusataria moverme un poco mas a quattro. evamos que podemos ir reemplzando sin romper. te parece?¿ ahcemos un new odd?" Answer to grouping question: "a me parace bien. epro el uso de agnetes yua lo tengo creo, teng oepcnode, claude y codex . pero me quedo con opecnode con herdr que se supone ya lo tengo . la aopcion b tambien la quiero. dejemos c para el final". Earlier: "que no nos enredemos en las ramas". Baseline: nixos-hosts master 3bac20db, fork main eb94d307d43ab0270ef4ec75c9c28ac563a4d44c. Next: T0 mapping.
