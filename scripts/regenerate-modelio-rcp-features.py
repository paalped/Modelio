#!/usr/bin/env python3
"""
Regenerate org.modelio.{e4.rcp,rcp,platform.feature} from Eclipse 4.24 upstream features.
"""
from __future__ import annotations

import re
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ECLIPSE_424_REPO = "https://download.eclipse.org/eclipse/updates/4.24/R-4.24-202206070700"
ROOT = Path(__file__).resolve().parent.parent
FEATURES_DIR = ROOT / "features" / "opensource"

TRANSFORMS = [
    {
        "upstream": "org.eclipse.e4.rcp",
        "upstream_version": "4.24.0.v20220530-1036",
        "target_id": "org.modelio.e4.rcp",
        "target_dir": FEATURES_DIR / "org.modelio.e4.rcp",
        "replacements": [
            (r'(<feature[^>]*\s)id="org\.eclipse\.e4\.rcp"', r'\1id="org.modelio.e4.rcp"'),
        ],
    },
    {
        "upstream": "org.eclipse.rcp",
        "upstream_version": "4.24.0.v20220607-0700",
        "target_id": "org.modelio.rcp",
        "target_dir": FEATURES_DIR / "org.modelio.rcp",
        "replacements": [
            (r'(<feature[^>]*\s)id="org\.eclipse\.rcp"', r'\1id="org.modelio.rcp"'),
            (
                r'<includes\s+id="org\.eclipse\.e4\.rcp"',
                '<includes id="org.modelio.e4.rcp"',
            ),
        ],
    },
    {
        "upstream": "org.eclipse.platform",
        "upstream_version": "4.24.0.v20220607-0700",
        "target_id": "org.modelio.platform.feature",
        "target_dir": FEATURES_DIR / "org.modelio.platform.feature",
        "replacements": [
            (r'id="org\.eclipse\.platform"(?=[^>]*>)', 'id="org.modelio.platform.feature"'),
            (r'(<feature[^>]*\s)id="org\.eclipse\.platform"', r'\1id="org.modelio.platform.feature"'),
            (
                r'<includes\s+id="org\.eclipse\.rcp"',
                '<includes id="org.modelio.rcp"',
            ),
        ],
    },
]


def download_feature_jar(feature_id: str, version: str, dest: Path) -> Path:
    jar_name = f"{feature_id}_{version}.jar"
    url = f"{ECLIPSE_424_REPO}/features/{jar_name}"
    print(f"  Downloading {url}")
    urllib.request.urlretrieve(url, dest / jar_name)
    return dest / jar_name


def extract_feature_xml(jar_path: Path) -> str:
    with zipfile.ZipFile(jar_path) as zf:
        return zf.read("feature.xml").decode("utf-8")


def apply_replacements(xml: str, replacements: list[tuple[str, str]]) -> str:
    for pattern, repl in replacements:
        xml = re.sub(pattern, repl, xml)
    return xml


def update_feature_version(xml: str, version: str) -> str:
    return re.sub(
        r'(<feature[^>]*\sversion=")[^"]+(")',
        rf"\g<1>{version}\2",
        xml,
        count=1,
    )


def update_includes_versions(xml: str, version_map: dict[str, str]) -> str:
    for feature_id, version in version_map.items():
        xml = re.sub(
            rf'(<includes[^>]*\s+id="{re.escape(feature_id)}"[^>]*\s+version=")[^"]+(")',
            rf"\g<1>{version}\2",
            xml,
        )
    return xml


def update_pom_version(pom_path: Path, version: str) -> None:
    text = pom_path.read_text(encoding="utf-8")
    text = re.sub(
        r"(<artifactId>org\.modelio\.[^<]+</artifactId>\s*<version>)[^<]+(</version>)",
        rf"\g<1>{version}\2",
        text,
        count=1,
    )
    # fallback: any version line after artifactId
    if version not in text:
        text = re.sub(
            r"(<version>)\d+\.\d+\.\d+\.v[^<]+(</version>)",
            rf"\g<1>{version}\2",
            text,
            count=1,
        )
    pom_path.write_text(text, encoding="utf-8")


def main() -> int:
    version_map: dict[str, str] = {}
    generated: dict[str, str] = {}

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        for spec in TRANSFORMS:
            jar = download_feature_jar(
                spec["upstream"], spec["upstream_version"], tmp_path
            )
            xml = extract_feature_xml(jar)
            for pattern, repl in spec["replacements"]:
                xml = re.sub(pattern, repl, xml)
            xml = update_feature_version(xml, spec["upstream_version"])
            version_map[spec["target_id"]] = spec["upstream_version"]
            generated[spec["target_id"]] = xml

    # Second pass: fix cross-references between modelio features
    modelio_versions = {
        "org.modelio.e4.rcp": TRANSFORMS[0]["upstream_version"],
        "org.modelio.rcp": TRANSFORMS[1]["upstream_version"],
        "org.modelio.platform.feature": TRANSFORMS[2]["upstream_version"],
    }

    for target_id, xml in generated.items():
        xml = update_includes_versions(xml, modelio_versions)
        spec = next(t for t in TRANSFORMS if t["target_id"] == target_id)
        feature_xml_path = spec["target_dir"] / "feature.xml"
        backup = feature_xml_path.with_suffix(".xml.bak-418")
        if not backup.exists():
            shutil.copy2(feature_xml_path, backup)
        feature_xml_path.write_text(xml, encoding="utf-8")
        update_pom_version(spec["target_dir"] / "pom.xml", spec["upstream_version"])
        print(f"Updated {feature_xml_path} -> {spec['upstream_version']}")

    print("\nDone. Eclipse platform upgraded to 4.24 in Modelio fork features.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
