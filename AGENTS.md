# Working on the game

Read [docs/simulation.md](docs/simulation.md) before changing the simulation.

- Keep docs and scripts in sync in the same change. Update rules, scoring,
  controls, scene layout and tuning notes when their behavior changes.
- Keep art as simple colored meshes and billboard sprite placeholders for the user to replace.
- Prefer Godot Resources for roster data, nodes for actors and presentation.
- Keep simulation changes deterministic for the same seed and physics timestep.
- Keep comments and tests focused on intent, baseball rules and regressions.
  Avoid tests that merely repeat implementation details.
- After GDScript changes, run `uv run --locked gdformat data game tests`, then
  `uv run --locked gdlint data game tests`. For a check without editing files, use
  `uv run --locked gdformat --check data game tests`.
- Run a headless editor import and the simulation checks when they make sense:
  ```sh
  godot --headless --path . --editor --quit
  godot --headless --path . --fixed-fps 60 --script tests/simulation_test.gd
  ```

  Use the installed Godot executable if `godot` is not on PATH.
  Inspect the output for script errors even if the process exits successfully.
  Check visible UI changes in a running game at times, but not often.
