# Extreme Canuck Baseball

A baseball auto-battler built with Godot 4.7. Open the project in Godot, press
F5, then Space to start a game. See [simulation.md](docs/simulation.md) for
controls, rules and simulation checks.

## Optional development tools

With [uv](https://docs.astral.sh/uv/) installed, run from the project root:

```sh
uv run gdformat data game tests          # Format GDScript
uv run gdformat --check data game tests  # Check formatting
uv run gdlint data game tests            # Lint GDScript
```
