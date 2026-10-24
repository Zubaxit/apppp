#!/usr/bin/env python3
"""Dependency-free structural lint for Dart sources.

The real gate is `flutter analyze` in CI. This checker exists so that a
sandbox without the Dart SDK can still catch the mistakes that cost the most
time: unbalanced brackets, unterminated strings, imports that point nowhere,
duplicate top-level declarations, and calls to project classes that were never
imported.

It is deliberately conservative: it only reports things it is sure about.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKG = "bangladesh_newspaper_hub"


def strip_code(src: str) -> str:
    """Remove comments and string literals while keeping line structure."""
    out: list[str] = []
    i, n = 0, len(src)
    while i < n:
        ch = src[i]
        if ch == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
        elif ch == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                if src[i] == "\n":
                    out.append("\n")
                i += 1
            i += 2
        elif src.startswith("'''", i) or src.startswith('"""', i):
            quote = src[i : i + 3]
            i += 3
            while i < n and not src.startswith(quote, i):
                if src[i] == "\n":
                    out.append("\n")
                i += 1
            i += 3
        elif ch in "'\"":
            quote = ch
            i += 1
            while i < n and src[i] != quote:
                if src[i] == "\\":
                    i += 1
                i += 1
            i += 1
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def check_balance(path: Path, code: str) -> list[str]:
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[tuple[str, int]] = []
    line = 1
    for ch in code:
        if ch == "\n":
            line += 1
        elif ch in "([{":
            stack.append((ch, line))
        elif ch in ")]}":
            if not stack or stack[-1][0] != pairs[ch]:
                found = stack[-1][0] if stack else "nothing"
                return [f"{path}:{line} unmatched '{ch}' (open: {found})"]
            stack.pop()
    if stack:
        opener, open_line = stack[-1]
        return [f"{path}: unclosed '{opener}' from line {open_line}"]
    return []


def main() -> int:
    files = sorted(list(ROOT.glob("lib/**/*.dart")) + list(ROOT.glob("test/**/*.dart")))
    errors: list[str] = []
    declared: dict[str, str] = {}

    for path in files:
        rel = path.relative_to(ROOT)
        src = path.read_text(encoding="utf-8")
        code = strip_code(src)
        errors.extend(check_balance(rel, code))

        for match in re.finditer(r"^(?:abstract |final |sealed |base |mixin )*class (\w+)", code, re.M):
            name = match.group(1)
            if name in declared and declared[name] != str(rel):
                errors.append(f"{rel}: duplicate class {name} (also in {declared[name]})")
            declared[name] = str(rel)

        imports = set()
        for match in re.finditer(r"^import ['\"]([^'\"]+)['\"]", src, re.M):
            target = match.group(1)
            if target.startswith("package:"):
                pkg, _, rest = target[len("package:"):].partition("/")
                if pkg != PKG:
                    continue
                resolved = ROOT / "lib" / rest
            elif target.startswith("dart:"):
                continue
            else:
                resolved = (path.parent / target).resolve()
            imports.add(resolved)
            if not resolved.exists():
                errors.append(f"{rel}: import target missing: {target}")

    # Every project class used in a file must be reachable via an import.
    definitions = {name: Path(path) for name, path in declared.items()}
    for path in files:
        rel = path.relative_to(ROOT)
        src = path.read_text(encoding="utf-8")
        code = strip_code(src)
        imported = set()
        for match in re.finditer(r"^import ['\"]([^'\"]+)['\"]", src, re.M):
            target = match.group(1)
            if target.startswith("package:"):
                pkg, _, rest = target[len("package:"):].partition("/")
                if pkg == PKG:
                    imported.add((ROOT / "lib" / rest).resolve())
            elif not target.startswith("dart:"):
                imported.add((path.parent / target).resolve())
        local = {m.group(1) for m in re.finditer(r"class (\w+)", code)}
        for match in re.finditer(r"\b([A-Z]\w*)\b", code):
            name = match.group(1)
            if name in local or name not in definitions:
                continue
            home = definitions[name].resolve()
            if home not in imported:
                line = code[: match.start()].count("\n") + 1
                errors.append(f"{rel}:{line} uses {name} without importing {definitions[name]}")

    if errors:
        print(f"{len(errors)} problem(s):")
        for error in sorted(set(errors)):
            print(" -", error)
        return 1
    print(f"checked {len(files)} Dart files: structure, imports and class visibility OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
