# Working on the game

Read [docs/simulation.md](docs/simulation.md) before changing the simulation.
The [docs/](docs/) directory describes the implemented game, its controls and known limits.

- Keep docs and scripts in sync in the same change. Update rules, scoring,
  controls, scene layout and tuning notes when their behavior changes.
- Describe what runs today. Label approximations and missing rules explicitly;
  do not document planned behavior as implemented.
- Keep art as simple colored meshes and billboard sprite placeholders for the user to replace.
- Prefer Godot Resources for roster data, nodes for actors and presentation,
  and plain RefCounted objects for simulation rules. Do not mutate roster stats
  during a match or use presentation signals as the source of scoring truth.
- Keep simulation changes deterministic for the same seed and physics timestep.
- Keep comments and tests focused on intent, baseball rules and regressions.
  Avoid tests that merely repeat implementation details.
- Run a headless editor import and the simulation checks after script/scene changes:

  ```sh
  godot --headless --path . --editor --quit
  godot --headless --path . --fixed-fps 60 --script tests/simulation_test.gd
  godot --headless --path . --fixed-fps 60 --script tests/shop_test.gd
  ```

  Use the installed Godot executable if `godot` is not on PATH.
  Inspect the output for script errors even if the process exits successfully.
  Check visible UI changes in a running game too.
