"""Build larger, seamless field textures from the edited grass and clay PNGs.

Run with Blender's Python (which includes NumPy):
blender --background --python tools/blender/varied_textures.py
ImageMagick's `magick` command reads and writes the PNG pixels.
"""

import subprocess
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[2]
TEXTURES = ROOT / "art/blender/textures"
PATCHES = 8
PATCH_SIZE = 256
SIZE = PATCHES * PATCH_SIZE
FEATHER = 40
CLAY_MEAN_RGB = np.array((122, 82, 64), dtype=np.float32)


def image_pixels(path):
    raw = subprocess.run(
        ["magick", str(path), "-resize", f"{PATCH_SIZE}x{PATCH_SIZE}!", "-depth", "8", "RGB:-"],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    return np.frombuffer(raw, dtype=np.uint8).reshape(PATCH_SIZE, PATCH_SIZE, 3)


def save_pixels(path, pixels):
    subprocess.run(
        [
            "magick", "-size", f"{SIZE}x{SIZE}", "-depth", "8", "RGB:-",
            "-strip", "-define", "png:color-type=2", str(path),
        ],
        input=pixels.tobytes(),
        check=True,
    )


def neighboring_patch(coordinate):
    cell = np.floor(coordinate / PATCH_SIZE).astype(np.int32) % PATCHES
    offset = coordinate % PATCH_SIZE
    neighbor = cell.copy()
    weight = np.zeros_like(offset, dtype=np.float32)
    low = offset < FEATHER
    high = offset >= PATCH_SIZE - FEATHER
    neighbor[low] = (cell[low] - 1) % PATCHES
    neighbor[high] = (cell[high] + 1) % PATCHES
    t = offset[low] / FEATHER
    weight[low] = 0.5 * (1 - t * t * (3 - 2 * t))
    t = (offset[high] - (PATCH_SIZE - FEATHER)) / FEATHER
    weight[high] = 0.5 * t * t * (3 - 2 * t)
    return cell, neighbor, offset.astype(np.int32), weight


def broad_variation(coordinate, grid_size):
    position = coordinate * grid_size / SIZE
    first = np.floor(position).astype(np.int32)
    fraction = position - first
    fraction = fraction * fraction * (3 - 2 * fraction)
    return first % grid_size, (first + 1) % grid_size, fraction


def grass_source():
    original = image_pixels(TEXTURES / "grass.png").astype(np.float32)
    detailed = image_pixels(TEXTURES / "grass_contrast.png").astype(np.float32)
    combined = original * 0.65 + detailed * 0.35
    combined += original.mean(axis=(0, 1)) - combined.mean(axis=(0, 1))
    luma = combined @ np.array((0.2126, 0.7152, 0.0722), dtype=np.float32)
    combined += 0.30 * (luma - luma.mean())[:, :, None]
    return np.clip(combined, 0, 255).astype(np.uint8)


def clay_source():
    source = image_pixels(TEXTURES / "dirt_clay.png").astype(np.float32)
    source *= CLAY_MEAN_RGB / source.mean(axis=(0, 1))
    return np.clip(source, 0, 255).astype(np.uint8)


def varied_texture(source, seed, drift):
    rng = np.random.default_rng(seed)
    variants = np.empty((PATCHES, PATCHES, PATCH_SIZE, PATCH_SIZE, 3), dtype=np.uint8)
    for row in range(PATCHES):
        for column in range(PATCHES):
            patch = np.rot90(source, int(rng.integers(4)))
            if rng.integers(2):
                patch = np.fliplr(patch)
            patch = np.roll(
                patch,
                (int(rng.integers(PATCH_SIZE)), int(rng.integers(PATCH_SIZE))),
                axis=(0, 1),
            )
            variants[row, column] = patch

    tone = rng.uniform(-1, 1, (4, 4)).astype(np.float32)
    result = np.empty((SIZE, SIZE, 3), dtype=np.uint8)
    x = np.arange(SIZE)
    mx0, mx1, mx = broad_variation(x, len(tone))
    for start in range(0, SIZE, PATCH_SIZE):
        y = np.arange(start, start + PATCH_SIZE)
        x_warped = x[None, :] + 14 * np.sin(2 * np.pi * 5 * y[:, None] / SIZE + 0.4)
        x_warped += 7 * np.sin(2 * np.pi * 11 * y[:, None] / SIZE + 1.2)
        y_warped = y[:, None] + 13 * np.sin(2 * np.pi * 7 * x[None, :] / SIZE + 0.8)
        y_warped += 7 * np.sin(2 * np.pi * 13 * x[None, :] / SIZE + 2.1)
        cx, nx, ix, x_mix = neighboring_patch(x_warped)
        cy, ny, iy, y_mix = neighboring_patch(y_warped)
        wx, wy = x_mix[:, :, None], y_mix[:, :, None]
        top = variants[cy, cx, iy, ix].astype(np.float32) * (1 - wx)
        top += variants[cy, nx, iy, ix] * wx
        bottom = variants[ny, cx, iy, ix].astype(np.float32) * (1 - wx)
        bottom += variants[ny, nx, iy, ix] * wx
        pixels = top * (1 - wy) + bottom * wy

        my0, my1, my = broad_variation(y, len(tone))
        tx = (1 - mx)[None, :] * tone[my0[:, None], mx0[None, :]]
        tx += mx[None, :] * tone[my0[:, None], mx1[None, :]]
        ty = (1 - mx)[None, :] * tone[my1[:, None], mx0[None, :]]
        ty += mx[None, :] * tone[my1[:, None], mx1[None, :]]
        variation = tx * (1 - my[:, None]) + ty * my[:, None]
        result[start:start + PATCH_SIZE] = np.clip(
            pixels * (1 + drift * variation[:, :, None]), 0, 255
        ).astype(np.uint8)
    return result


def main():
    for name, source, seed, drift in (
        ("grass", grass_source(), 139, 0.045),
        ("dirt", clay_source(), 271, 0.035),
    ):
        output = TEXTURES / f"{name}_varied.png"
        save_pixels(output, varied_texture(source, seed, drift))
        print(output)

    chalk = TEXTURES / "chalk_dirt_varied.png"
    subprocess.run(
        [
            "magick", str(TEXTURES / "dirt_varied.png"),
            "-colorspace", "Gray", "-colorspace", "sRGB",
            "-fill", "#f8f1df", "-colorize", "82%",
            "-strip", "-define", "png:color-type=2", str(chalk),
        ],
        check=True,
    )
    print(chalk)


if __name__ == "__main__":
    main()
