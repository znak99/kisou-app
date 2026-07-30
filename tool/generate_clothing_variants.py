"""Generate Flutter resolution variants from the non-bundled master icons."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MASTER_DIR = ROOT / "design_assets" / "clothing_icons_master"
ASSET_DIR = ROOT / "assets" / "icons"
SIZES = {
    "": 96,
    "2.0x": 192,
    "3.0x": 288,
    "4.0x": 384,
}


def main() -> None:
    masters = sorted(MASTER_DIR.glob("*.png"))
    if len(masters) != 16:
        raise RuntimeError(f"Expected 16 clothing masters, found {len(masters)}")

    for variant, edge in SIZES.items():
        output_dir = ASSET_DIR / variant
        output_dir.mkdir(parents=True, exist_ok=True)
        for source in masters:
            with Image.open(source) as image:
                resized = image.resize((edge, edge), Image.Resampling.LANCZOS)
                resized.save(
                    output_dir / source.name,
                    format="PNG",
                    optimize=True,
                    compress_level=9,
                )


if __name__ == "__main__":
    main()
