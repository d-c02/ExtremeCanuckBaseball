# Extreme Canuck Baseball

A 3D baseball auto-battler with billboard players, built with Godot 4.7.
Open the project in Godot and press F5. It starts on the buy screen: sign a team,
then Start game to play it against a rolled opponent. See
[buy_screen.md](docs/buy_screen.md) for the shop and
[simulation.md](docs/simulation.md) for controls, rules and simulation checks.

## Optional development tools

With [uv](https://docs.astral.sh/uv/) installed, run from the project root:

```sh
uv run gdformat data game tests          # Format GDScript
uv run gdformat --check data game tests  # Check formatting
uv run gdlint data game tests            # Lint GDScript
```

## Blender field

See [Blender setup and field controls](docs/blender.md) for the MCP connection,
Geometry Nodes source, and GLB/layout export workflow.
