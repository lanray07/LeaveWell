"""Audit native screenshot exports and create review sheets plus a delivery archive."""
import hashlib
import json
import zipfile
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "marketing/duo"

def main():
    copy = json.loads((BASE / "copy.json").read_text(encoding="utf-8"))
    native = json.loads((BASE / "captures/manifest.json").read_text(encoding="utf-8"))
    manifest = json.loads((BASE / "exports/manifest.json").read_text(encoding="utf-8-sig"))
    rows = manifest["captures"]
    expected = {(locale, route) for locale in copy["locales"] for route in copy["routes"]}
    actual = {(r["locale"], Path(r["file"]).stem[3:]) for r in rows}
    assert native["status"] == "complete" and actual == expected
    assert len(rows) == len(expected) == 170
    assert set((BASE / "exports").rglob("*.png")) == {BASE / "exports" / row["file"] for row in rows}
    for row in rows:
        path = BASE / "exports" / row["file"]
        assert path.resolve().is_relative_to((BASE / "exports").resolve())
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row["sha256"]
        with Image.open(path) as image:
            assert image.size == (1398, 2034) and image.mode == "RGB", path
    previews = BASE / "previews"
    previews.mkdir(exist_ok=True)
    for locale in copy["locales"]:
        sheet = Image.new("RGB", (1750, 1090), "#e8e5df")
        draw = ImageDraw.Draw(sheet)
        for index, route in enumerate(copy["routes"]):
            with Image.open(BASE / "exports" / locale / "outer" / f"{index+1:02}-{route}.png") as source:
                thumb = source.copy()
                thumb.thumbnail((340, 500))
                x, y = (index % 5)*350, (index // 5)*545
                sheet.paste(thumb, (x+5,y+25))
                draw.text((x+6,y+5), f"{locale} / {index+1:02} {route}", fill="black")
        sheet.save(previews / f"{locale}.jpg", quality=92)
    for locale, name in [("en-GB", "english-preview.jpg"), ("fr", "french-preview.jpg")]:
        (BASE / name).write_bytes((previews / f"{locale}.jpg").read_bytes())
    target = ROOT / "marketing/LeaveWell-iPhone-Duo-17-locales.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for file in sorted((BASE / "exports").rglob("*")):
            if file.is_file(): archive.write(file, file.relative_to(BASE))
        for file in sorted(previews.glob("*.jpg")): archive.write(file, file.relative_to(BASE))
        archive.write(BASE / "README.md", "README.md")
        archive.write(BASE / "UPLOAD_MAP.csv", "UPLOAD_MAP.csv")
        archive.write(BASE / "SCREENSHOT_COPY.csv", "SCREENSHOT_COPY.csv")
        archive.write(BASE / "translations/coverage.json", "translations/coverage.json")
        archive.write(BASE / "captures/manifest.json", "native-provenance.json")
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert sum(name.startswith("exports/") and name.endswith(".png") for name in archive.namelist()) == 170
    delivery = dict(file=target.name, bytes=target.stat().st_size,
        sha256=hashlib.sha256(target.read_bytes()).hexdigest(), screenshots=170,
        locales=list(copy["locales"]), display="iPhone Duo outer", width=1398, height=2034,
        nativeCaptureRun=native["sourceRun"], innerDisplayIncluded=False,
        fullAppTranslation=False, independentNativeSpeakerReview=False)
    (BASE / "delivery.json").write_text(json.dumps(delivery, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Verified 170 RGB screenshots, generated 17 review sheets: {target}")

if __name__ == "__main__": main()
