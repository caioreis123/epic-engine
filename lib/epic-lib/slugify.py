#!/usr/bin/env python3
"""Free text -> lowercase ASCII slug separated by hyphens."""
import re
import sys
import unicodedata


def slugify(text):
    normalized = unicodedata.normalize("NFKD", text)
    ascii_only = normalized.encode("ascii", "ignore").decode("ascii")
    lowered = ascii_only.lower()
    hyphenated = re.sub(r"[^a-z0-9]+", "-", lowered)
    return hyphenated.strip("-")


if __name__ == "__main__":
    print(slugify(" ".join(sys.argv[1:])))
