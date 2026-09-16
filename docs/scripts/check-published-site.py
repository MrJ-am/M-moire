"""Compare the published application with the files that passed browser tests."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import sys
import time
from urllib.request import Request, urlopen


def digest(content):
    return hashlib.sha256(content).hexdigest()


def manifest(site):
    root = Path(site)
    files = [p for p in root.rglob("*") if p.is_file() and p.suffix in {".html", ".js", ".css", ".svg", ".json", ".woff", ".woff2", ".ttf"}]
    result = {p.relative_to(root).as_posix(): digest(p.read_bytes()) for p in sorted(files)}
    if "index.html" not in result or "data/bank.json" not in result:
        raise ValueError("L’accueil et la banque doivent être présents avant publication.")
    return result


def download(url):
    request = Request(url, headers={"Cache-Control": "no-cache", "User-Agent": "Regards-release-check"})
    with urlopen(request, timeout=10) as response:
        return response.read()


def mismatches(base_url, expected, fetch=download):
    if not expected:
        raise ValueError("Le manifeste de la version testée est vide.")

    def check(item):
        path, checksum = item
        # Versioned requests also avoid a cached 404 from the previous deployment.
        url = f"{base_url.rstrip('/')}/{path}?v={checksum[:12]}"
        try:
            return None if digest(fetch(url)) == checksum else f"{path} : contenu différent de la version testée"
        except OSError as error:
            return f"{path} : {error}"

    with ThreadPoolExecutor(max_workers=6) as pool:
        return [error for error in pool.map(check, expected.items()) if error]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("manifest").add_argument("site")
    commands.add_parser("verify")
    args = parser.parse_args()
    if args.command == "manifest":
        print(json.dumps(manifest(args.site), separators=(",", ":")))
        return 0

    expected = json.loads(os.environ["EXPECTED_SITE"])
    url = os.environ["SITE_URL"]
    if not url.startswith("https://"):
        raise ValueError("L’adresse HTTPS de la publication est requise.")
    for attempt in range(1, 7):
        errors = mismatches(url, expected)
        if not errors:
            print(f"Publication vérifiée : {len(expected)} fichiers identiques à la version testée.")
            return 0
        print(f"Contrôle {attempt}/6 : " + "; ".join(errors), flush=True)
        if attempt < 6:
            time.sleep(10)
    return 1


if __name__ == "__main__":
    sys.exit(main())
