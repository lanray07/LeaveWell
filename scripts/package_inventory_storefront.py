from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import zipfile

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
COPY = json.loads((ROOT / "marketing/duo/copy.json").read_text(encoding="utf-8"))
WORK = ROOT / "build/build90-storefront"
SIZES = {"outer": {(1398, 2034)}, "iphone": {(1179, 2556), (1206, 2622)},
         "ipad": {(2048, 2732), (2064, 2752)}}


def checked_image(path, digest, family, opaque=False):
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, path
    with Image.open(path) as image:
        assert image.size in SIZES[family], path
        if opaque:
            assert image.mode == "RGB", path


def collect_primary(run):
    for family in ("iphone", "ipad"):
        name = f"Gallery-en-GB-{family}"
        destination = WORK / family / "captures"
        if not (destination / "manifest.json").exists():
            destination.mkdir(parents=True, exist_ok=True)
            subprocess.run(["gh", "run", "download", str(run), "--name", name,
                            "--dir", str(destination)], check=True)
        capture = json.loads((destination / "manifest.json").read_text(encoding="utf-8"))
        records = capture["captures"]
        assert len(records) == 10 and {row["route"] for row in records} == set(COPY["routes"])
        for row in records:
            assert row["family"] == family
            assert row["locale"] == row["bundleLocale"] == "en-GB"
            source = (destination / row["file"]).resolve()
            assert source.is_relative_to(destination.resolve())
            checked_image(source, row["sha256"], family)
        subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        str(ROOT / "scripts/export_duo_screenshots.ps1"),
                        "-RawPath", str(destination), "-OutputPath", str(WORK / family / "exports"),
                        "-Families", family], check=True)


def package(duo_run, primary_run):
    groups = {"outer": list(COPY["locales"]), "iphone": ["en-GB"], "ipad": ["en-GB"]}
    delivery = WORK / "delivery"
    previews = delivery / "previews"
    previews.mkdir(parents=True, exist_ok=True)
    exported = []
    provenance = {}
    for family, locales in groups.items():
        assets = WORK / family
        manifest = json.loads((assets / "exports/manifest.json").read_text(encoding="utf-8-sig"))
        native = json.loads((assets / "captures/manifest.json").read_text(encoding="utf-8"))
        provenance[family] = native
        sources = {row["file"]: row["sha256"] for row in native["captures"]}
        assert len(manifest["captures"]) == 10 * len(locales)
        for row in manifest["captures"]:
            assert row["family"] == family and row["locale"] in locales
            assert sources[row["nativeSource"]] == row["sourceSha256"]
            path = (assets / "exports" / row["file"]).resolve()
            assert path.is_relative_to((assets / "exports").resolve())
            checked_image(path, row["sha256"], family, opaque=True)
            target = delivery / "screenshots" / row["file"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
            exported.append(row)
        for locale in locales:
            sheet = Image.new("RGB", (1750, 1090), "#e8e5df")
            draw = ImageDraw.Draw(sheet)
            for i, route in enumerate(COPY["routes"]):
                path = delivery / "screenshots" / locale / family / f"{i+1:02}-{route}.png"
                with Image.open(path) as source:
                    image = source.copy()
                    image.thumbnail((340, 500))
                    x, y = (i % 5) * 350, (i // 5) * 545
                    sheet.paste(image, (x + (350 - image.width) // 2, y + 25))
                    draw.text((x + 6, y + 5), f"{locale} / {i+1:02} {route}", fill="black")
            sheet.save(previews / f"{locale}-{family}.jpg", quality=92)
    assert len(exported) == len({row["file"] for row in exported}) == 190
    (delivery / "manifest.json").write_text(json.dumps({
        "releaseBuild": 90, "duoCaptureRun": duo_run, "primaryCaptureRun": primary_run,
        "scope": groups, "fictionalRecords": True, "fullAppTranslation": False,
        "exports": exported, "nativeProvenance": provenance,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    archive = WORK / "LeaveWell-build90-storefront.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted(delivery.rglob("*")):
            if path.is_file():
                bundle.write(path, path.relative_to(delivery))
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        assert sum(name.endswith(".png") for name in bundle.namelist()) == 190
    print(f"Validated and packaged 190 native storefront assets: {archive}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--duo-run", type=int, required=True)
    parser.add_argument("--primary-run", type=int, required=True)
    args = parser.parse_args()
    collect_primary(args.primary_run)
    package(args.duo_run, args.primary_run)
