"""Make field PNGs with ImageMagick.

Run without arguments to refresh chalk_dirt.png from the checked-in dirt.png.
Pass --from-bmps to also convert grass.bmp and dirt.bmp from --source-dir.
The active field uses separately edited grass_contrast.png and dirt_clay.png;
converting BMPs alone does not replace those images.
"""

import argparse
import shutil
import subprocess
from pathlib import Path


TEXTURES = Path(__file__).resolve().parents[2] / "art" / "blender" / "textures"


def convert(command: list[str]) -> None:
    subprocess.run(["magick", *command], check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from-bmps", action="store_true", help="also convert grass.bmp and dirt.bmp")
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path.home() / "Downloads",
        help="directory containing the original BMPs (default: ~/Downloads)",
    )
    args = parser.parse_args()

    if shutil.which("magick") is None:
        parser.error("ImageMagick's magick command is required")

    if args.from_bmps:
        missing = [name for name in ("grass.bmp", "dirt.bmp") if not (args.source_dir / name).is_file()]
        if missing:
            parser.error(f"missing BMPs in {args.source_dir}: {', '.join(missing)}")
        TEXTURES.mkdir(parents=True, exist_ok=True)
        for name in ("grass", "dirt"):
            output = TEXTURES / f"{name}.png"
            convert([str(args.source_dir / f"{name}.bmp"), "-strip", "-define", "png:color-type=2", str(output)])
            print(output)

    dirt = TEXTURES / "dirt.png"
    if not dirt.is_file():
        parser.error(f"missing {dirt}; pass --from-bmps to convert the original BMPs")

    chalk = TEXTURES / "chalk_dirt.png"
    convert(
        [
            str(dirt),
            "-colorspace", "Gray",
            "-colorspace", "sRGB",
            "-fill", "#f8f1df",
            "-colorize", "82%",
            "-strip",
            "-define", "png:color-type=2",
            str(chalk),
        ]
    )
    print(chalk)


if __name__ == "__main__":
    main()
