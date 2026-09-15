# Placeholder sounds

WAVs rendered with [Bfxr](https://www.bfxr.net/) and its Footsteppr generator.
The synthesizers come from [increpare/bfxr2](https://github.com/increpare/bfxr2),
commit `5bd2f9420d5997d53e03697cb5a219f0ab087334` (MIT). Footsteppr is Stephen
Lavelle's port of Obiwannabe's Pure Data footstep generator.

`presets/` contains editable `.bfxr` files. Open them using Bfxr's Open Data button.
The dirt/grass footsteps share heel, roll and toe settings, with a short stride.
Other effects use Bfxr noise, sine and triangle waves. Files are mono, 44.1 kHz,
16-bit PCM, normalized to a peak of 0.65 before the game's volume controls.

To reproduce the WAVs using a local checkout of that Bfxr revision:

```sh
node tools/render_sounds.cjs /path/to/bfxr2
```

The renderer uses Bfxr's published JavaScript synthesizers and WAV encoder.
Bfxr is only needed to regenerate assets; the game plays the checked-in WAVs.
Seeds live in each preset. They make local rendering repeatable; the website
may use a different random noise seed when you open a preset.

Select `Sounds` in `main.tscn` to replace clips, adjust the four mix levels or
mute effects with `enabled`. Footsteps and ball actions use AudioStreamPlayer3D at mapped field positions;
calls use a regular AudioStreamPlayer. Ball-flight pitch follows height.
`flight.wav.import` loops a steady section of the tone. Configure looping on any
replacement flight clip in Godot's Import panel. Audio is disabled in headless runs.
