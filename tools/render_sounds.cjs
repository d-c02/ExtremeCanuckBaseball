const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = path.resolve(process.argv[2] || '../bfxr2');
const output = path.resolve(__dirname, '../assets/audio');
const { createBfxrContext } = require(path.join(source, 'tools/render/bfxr_context.js'));
const { encodeWav16 } = require(path.join(source, 'tools/render/wav.js'));
const bfxr = createBfxrContext();
const footsteps = vm.createContext({ console });
vm.runInContext('const SAMPLE_RATE = 44100; const CONVERSION_FACTOR = 2 * Math.PI / SAMPLE_RATE; const RealizedSound = { from_buffer: buffer => buffer };', footsteps);
for (const file of ['globals', 'synths/templates', 'synths/SynthBase', 'audio/puredata', 'audio/puredata_modules', 'audio/puredata_parser', 'synths/Footsteppr']) {
  vm.runInContext(fs.readFileSync(path.join(source, 'js', file + '.js'), 'utf8'), footsteps);
}

for (const file of fs.readdirSync(path.join(output, 'presets')).filter(file => file.endsWith('.bfxr'))) {
  const preset = JSON.parse(fs.readFileSync(path.join(output, 'presets', file), 'utf8'));
  let samples;
  if (preset.synth_type === 'Footsteppr') {
    footsteps.params = preset.params;
    footsteps.seed = preset.seed;
    samples = vm.runInContext(`
      Math.random = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296);
      var synth = new Footsteppr();
      synth.params = params;
      synth.generate_sound();
      synth.sound;
    `, footsteps);
  } else {
    samples = bfxr.render(preset.params, preset.seed);
  }
  let peak = 0;
  for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
  if (!Number.isFinite(peak) || peak === 0) throw new Error('Invalid sound: ' + file);
  // Leave headroom when several game sounds overlap.
  for (let i = 0; i < samples.length; i++) samples[i] *= 0.65 / peak;
  fs.writeFileSync(path.join(output, preset.file_name + '.wav'), encodeWav16(samples, 44100));
  console.log(preset.file_name, (samples.length / 44100).toFixed(2) + 's');
}
