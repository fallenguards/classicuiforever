#!/usr/bin/env python3
"""Checks every client template our frames inherit against the client's own XML, Forever and retail.

  python tools/client_templates.py

Fetches the XML of the client source (github.com/Gethe/wow-ui-source, branches forever and live) into dev/client-xml,
finds each template name our CreateFrame/NewFrame calls pass, and writes the names both clients define to
tools/client_templates.txt, which the checker's CLIENTTEMPLATE rule reads. Exit 1 when a client lacks one.
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import check  # noqa: E402

REPO = "https://github.com/Gethe/wow-ui-source.git"
BRANCHES = (("forever", "Forever"), ("live", "retail"))
CACHE = os.path.join(ROOT, "dev", "client-xml")
LIST = os.path.join(HERE, "client_templates.txt")
TAG_RX = re.compile(r"<\w+\s[^>]*>", re.S)
NAME_RX = re.compile(r'\bname="([^"$]+)"')
KIND_RX = re.compile(r'\b(?:virtual|intrinsic)="true"')


def git(args, cwd=None):
    subprocess.run(["git"] + args, cwd=cwd, check=True, stdout=subprocess.DEVNULL)


def fetch(branch):
    """The branch's XML files only: a shallow, blobless, sparse checkout."""
    path = os.path.join(CACHE, branch)
    if not os.path.isdir(os.path.join(path, ".git")):
        os.makedirs(CACHE, exist_ok=True)
        git(["clone", "--quiet", "--depth", "1", "--filter=blob:none", "--no-checkout", "-b", branch, REPO, path])
        git(["sparse-checkout", "set", "--no-cone", "*.xml"], cwd=path)
        git(["checkout", "--quiet", branch], cwd=path)
    else:
        git(["fetch", "--quiet", "--depth", "1", "origin", branch], cwd=path)
        git(["reset", "--quiet", "--hard", "FETCH_HEAD"], cwd=path)
    return path


def defined(path):
    names = set()
    for base, _, files in os.walk(path):
        if ".git" in base:
            continue
        for name in files:
            if not name.lower().endswith(".xml"):
                continue
            with open(os.path.join(base, name), encoding="utf-8", errors="replace") as fh:
                for tag in TAG_RX.findall(fh.read()):
                    m = NAME_RX.search(tag)
                    if m and KIND_RX.search(tag):
                        names.add(m.group(1))
    return names


def used():
    names = {}
    for rel in [p for p in check.tracked_files(ROOT)[0] if check.in_scope(p)]:
        with open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
            for no, name in check.template_names(check.lex(fh.read())):
                names.setdefault(name, "%s:%d" % (rel, no))
    return names


def main():
    names = used()
    clients = [(label, defined(fetch(branch))) for branch, label in BRANCHES]
    missing = 0
    for name in sorted(names):
        lacking = [label for label, have in clients if name not in have]
        if lacking:
            missing += 1
            print("%s (%s): not on %s" % (name, names[name], ", ".join(lacking)))
    keep = sorted(n for n in names if all(n in have for _, have in clients))
    with open(LIST, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# Client templates our frames inherit, each defined on Forever and retail (tools/client_templates.py).\n")
        fh.write("\n".join(keep) + "\n")
    print("%d templates, %d on both clients, %d missing" % (len(names), len(keep), missing))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
