#!/usr/bin/env python3
"""Fail if any String Catalog entry is missing an Armenian or Russian translation,
or if a translation drops a format specifier (%@, %lld) its English key has."""
import json
import re
import sys

LANGUAGES = ("hy", "ru")
CATALOGS = ("App/Resources/Localizable.xcstrings", "Widget/Localizable.xcstrings")
SPECIFIER = re.compile(r"%(?:\d+\$)?(?:@|lld|d)")


def specifiers(text):
    return sorted(re.sub(r"\d+\$", "", s) for s in SPECIFIER.findall(text))


problems = []
for path in CATALOGS:
    with open(path, encoding="utf-8") as handle:
        strings = json.load(handle)["strings"]
    for key, entry in strings.items():
        for language in LANGUAGES:
            unit = entry.get("localizations", {}).get(language, {}).get("stringUnit", {})
            value = unit.get("value", "")
            if unit.get("state") != "translated" or not value:
                problems.append(f"{path}: '{key}' has no {language} translation")
            elif specifiers(value) != specifiers(key):
                problems.append(f"{path}: '{key}' → {language} '{value}' changes the placeholders")

for problem in problems:
    print(f"::error::{problem}")
print(f"Checked {len(CATALOGS)} catalogs: {'OK' if not problems else f'{len(problems)} problem(s)'}")
sys.exit(1 if problems else 0)
