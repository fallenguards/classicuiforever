"""Standalone packages: the full addon's built zip made into one zip per package, ClassicUI Forever: Standalone <Name>.

    python tools/standalone.py <full addon zip, or a worktree> <out dir> [--only=Id,Id]
    python tools/standalone.py --list

Each package is the whole addon (every cross-call resolves) with a generated first file, Package.lua, that sets
ns.PACKAGE (Core/Package.lua keeps its rows, boxes and modules, every other setting off) and the guard: the full addon
or another standalone enabled leaves this copy inert, every file returning at its first line. Saved variables are
renamed per package; one copy of our code ever runs, so no other global needs a new name.
"""
import os
import re
import subprocess
import sys
import urllib.parse
import zipfile

SUITE = "ClassicUIForever"
# Where a package's players report problems: the full addon's tracker, the code being the same, its issue form's
# Which addon? picked by the link (.github/ISSUE_TEMPLATE, the dropdown id addon).
ISSUES = "https://github.com/fallenguards/classicuiforever/issues/new/choose?addon="
PREFIX = SUITE + "Standalone"
THEME = ["bronzeTheme"]

# id, name, pages (locale keys of options pages), roots (options rows, with every row under them), modules (modules
# with no options row), icon, forever (Forever only), project (CurseForge id once the project exists), notes.
PACKAGES = [
    # The bag bar rides the band: its rows (the Bags page's bag bar section) go with the bars. Classic fonts: the
    # buttons' key labels and counts. Era coins: bag money, quest rewards. Each piece takes the look it shows.
    dict(id="ActionBars", name="Action Bars", pages=["GROUP_ACTION_BARS"],
         roots=["showBags", "bagsBesideBars", "hideKeyRing", "keyRingWithBags", "keyRingArtHidden", "eraBagSize",
                "reagentBagSlot", "hideBagsArt", "bagsAboveRow", "classicFonts"], modules=[],
         icon="Interface\\Icons\\INV_Sword_04", notes="The 1.x gryphon bar: square buttons, micro menu, XP bar, key ring."),
    dict(id="Bags", name="Bags", pages=["GROUP_BAGS"], roots=["eraCoins"], modules=[],
         icon="Interface\\Icons\\INV_Misc_Bag_08", notes="1.x bag windows, one bag, and the bag bar."),
    dict(id="UnitFrames", name="Unit Frames", pages=["GROUP_UNIT_FRAMES"], roots=["classicFonts"], modules=["buffArrow"],
         icon="Interface\\Icons\\INV_Misc_Head_Human_01", notes="1.x unit frames and cast bars."),
    dict(id="Nameplates", name="Nameplates", pages=["GROUP_NAMEPLATES"], roots=["classicFonts"], modules=[],
         icon="Interface\\Icons\\Ability_Hunter_SniperShot", notes="1.x nameplates."),
    dict(id="Chat", name="Chat", pages=["GROUP_CHAT"], roots=[], modules=[],
         icon="Interface\\Icons\\INV_Misc_Note_01", notes="The 1.x chat frame look."),
    dict(id="Maps", name="Minimap & World Map", pages=["GROUP_MINIMAP", "GROUP_MAP"], roots=["eraCoins"],
         modules=["mapCoords"],
         icon="Interface\\Icons\\INV_Misc_Map_01", notes="The 1.x minimap and its ring buttons, and Era's world map."),
    dict(id="Quests", name="Quests", pages=["GROUP_QUESTS"], roots=["panelQuest", "panelGossip", "eraCoins"],
         modules=["questListFont", "panels"], icon="Interface\\Icons\\INV_Scroll_03",
         notes="The 1.x quest log, quest tracker look and quest giver windows."),
    dict(id="CharacterSheet", wave=2, name="Character Sheet", pages=[], roots=["characterSheet"], modules=[],
         icon="Interface\\Icons\\INV_Chest_Plate06", notes="The 1.x character sheet and its stat panes."),
    dict(id="Spellbook", wave=2, name="Spellbook", pages=[], roots=["spellBook"], modules=[],
         icon="Interface\\Icons\\INV_Misc_Book_09", notes="The 1.x spellbook."),
    dict(id="Talents", wave=2, name="Talents", pages=[], roots=["talents"], modules=[],
         icon="Interface\\Icons\\Ability_Marksmanship", notes="The 1.x talents window."),
    dict(id="LegacyWindow", wave=2, name="Legacy Window", pages=[], roots=["legacyWindow"], modules=[], forever=True,
         icon="Interface\\Icons\\INV_Misc_Book_11", notes="Forever's Legacy trees, challenges and rewards in the 1.x look."),
    dict(id="Professions", wave=2, name="Professions", pages=["GROUP_PROFESSIONS"], roots=[], modules=[],
         icon="Interface\\Icons\\Trade_BlackSmithing", notes="The 1.x professions book, trade skill window and trainer."),
    dict(id="Collections", wave=2, name="Collections", pages=[], roots=["collectionsWindow"], modules=[],
         icon="Interface\\Icons\\Ability_Mount_RidingHorse", notes="Mounts, pets, toys, heirlooms and looks in a 1.x window."),
    dict(id="Social", wave=2, name="Social", pages=["GROUP_SOCIAL"],
         roots=["groupFinder", "panelSocial", "panelCommunities", "panelGuildControl", "panelGroupFinder",
                        "panelChannels"],
         modules=["panels"], icon="Interface\\Icons\\INV_Misc_Note_02",
         notes="The 1.x social window, Who list, guild roster and group finder."),
    dict(id="DamageMeter", name="Damage Meter", pages=[], roots=["damageMeter"], modules=[],
         icon="Interface\\Icons\\INV_Misc_PocketWatch_01", notes="The game's damage meter in the classic look."),
    dict(id="Tooltips", wave=2, name="Tooltips", pages=[], roots=["eraCoins"], modules=["tooltips"],
         icon="Interface\\Icons\\INV_Misc_QuestionMark", notes="1.x tooltips."),
    dict(id="WindowsAndMenus", wave=2, name="Windows and Menus", pages=["GROUP_ALL_WINDOWS"],
         roots=["classicFonts", "windowLocksAlways"], modules=["panels", "clientMenus"],
         icon="Interface\\Icons\\INV_Misc_Book_08",
         notes="The game's own windows, game menu, settings and menus in 1.x frames."),
    # The theme alone, under the author's own brand: its own folder and title, not a ClassicUI Forever piece's.
    # broad: every texture of the game's windows takes the theme but what stays as drawn (Art/GameArt.lua).
    dict(id="UIColorPicker", name="Fallen's UI Color Picker", folder="FallensUIColorPicker", pages=[], roots=THEME,
         modules=[], title="Fallen's UI Color Picker", issues="https://github.com/fallenguards/fallens-ui-color-picker/issues",
         broad=True, icon="Interface\\Icons\\INV_Misc_Gem_Variety_01",
         notes="Recolor the game's whole UI: dark, a custom color or bronze, on Forever and retail. Originally "
               "developed as part of ClassicUI Forever."),
]
for pkg in PACKAGES:
    pkg.setdefault("forever", False)
    pkg.setdefault("project", None)
    # Every package keeps the minimap options button: players find a package there, not by its slash command.
    if "GROUP_MINIMAP" not in pkg["pages"] and "minimapButton" not in pkg["roots"]:
        pkg["roots"] = pkg["roots"] + ["minimapButton"]
    pkg.setdefault("folder", PREFIX + pkg["id"])
    pkg.setdefault("title", "ClassicUI Forever: Standalone %s" % pkg["name"])
    pkg.setdefault("issues", ISSUES + urllib.parse.quote(pkg["title"]))
    pkg.setdefault("wave", 1)
# Every package's folder: the guard's list of copies of our code.
FOLDERS = [pkg["folder"] for pkg in PACKAGES]

# Files that still run while a package is inert: the notice needs its text (Core/Package.lua prints it).
LIVE = re.compile(r"^(Core/Localization\.lua|Core/Package\.lua|Locales/.*)$")
INERT_LINE = "if select(2, ...).INERT then return end "
SAVED = (("ForeverClassicUIDB", "DB"), ("ForeverClassicUICharDB", "CharDB"))


def lua_list(items):
    return "{ " + ", ".join('"%s"' % item for item in items) + " }" if items else "{}"


def package_lua(pkg):
    copies = ",\n".join('    "%s"' % folder for folder in FOLDERS)
    return "\n".join([
        "local ADDON, ns = ...",
        "-- %s, made by tools/standalone.py from the ClassicUI Forever build." % pkg["title"],
        'ns.PACKAGE = { title = "%s", pages = %s, roots = %s, modules = %s, broad = %s, piece = %s,' % (
            pkg["title"], lua_list(pkg["pages"]), lua_list(pkg["roots"]), lua_list(pkg["modules"]),
            "true" if pkg.get("broad") else "false", "true" if pkg["folder"].startswith(PREFIX) else "false"),
        '    curseforge = %s, issues = "%s" }' % (
            ('"https://www.curseforge.com/projects/%s"' % pkg["project"]) if pkg["project"] else "nil", pkg["issues"]),
        "-- One copy of our code runs: the full addon or another package enabled leaves this one inert.",
        "local COPIES = {",
        copies,
        "}",
        "local addons = C_AddOns",
        'if addons.GetAddOnEnableState("%s") > 0 then' % SUITE,
        '    ns.INERT = "full"',
        "else",
        "    for _, name in ipairs(COPIES) do",
        "        if name ~= ADDON and addons.GetAddOnEnableState(name) > 0 then",
        '            ns.INERT = "other"',
        "            break",
        "        end",
        "    end",
        "end",
        "-- Inert, the addon list's compartment entry still calls this; it does nothing unless the full addon set it.",
        "if ns.INERT and not ForeverClassicUI_OnAddonCompartmentClick then",
        "    ForeverClassicUI_OnAddonCompartmentClick = function() end",
        "end",
        "",
    ])


def toc_text(text, pkg, folder):
    nl = "\r\n" if "\r\n" in text else "\n"
    out, listed = [], False
    for line in text.split(nl):
        head = line.split(":", 1)[0]
        piece = folder.startswith(PREFIX)
        if head == "## Title":
            line = "## Title: " + (pkg["title"] + " (Standalone)" if piece else pkg["title"])
        elif head == "## Notes":
            line = "## Notes: " + (pkg["notes"] + " Standalone edition of ClassicUI Forever." if piece else pkg["notes"])
        elif head == "## IconTexture":
            line = "## IconTexture: " + pkg["icon"]
        elif head == "## X-Curse-Project-ID":
            if not pkg["project"]:
                continue
            line = "## X-Curse-Project-ID: %s" % pkg["project"]
        elif head == "## Interface" and pkg["forever"]:
            line = "## Interface: 16001"
        elif head in ("## SavedVariables", "## SavedVariablesPerCharacter"):
            for old, tail in SAVED:
                line = re.sub(r"\b%s\b" % old, folder + tail, line)
        elif not listed and line.strip() and not line.startswith("#"):
            out.append("Package.lua")
            listed = True
        out.append(line)
    return nl.join(out)


def lua_text(path, text, folder):
    for old, tail in SAVED:
        text = re.sub(r"\b%s\b" % old, folder + tail, text)
    if not LIVE.match(path):
        text = INERT_LINE + text
    return text


def zip_files(full_zip):
    src = zipfile.ZipFile(full_zip)
    return {n[len(SUITE) + 1:]: src.read(n) for n in src.namelist() if n.startswith(SUITE + "/") and not n.endswith("/")}


# A worktree as it is now, for trying a package in game before a release (release.sh's skip lists, comments kept).
SKIP_DIRS = ("dev/", ".github/", "tools/", "docs/")
SKIP_FILES = {".gitignore", ".luacheckrc", "release.sh", "release.conf", "README.md", "ziptest.sh", "cf_upload.py",
              "process_changelog.py"}


def tree_files(root):
    listed = subprocess.run(["git", "-C", root, "ls-files", "--cached", "--others", "--exclude-standard"],
                            capture_output=True, text=True, check=True).stdout.split("\n")
    files = {}
    for rel in listed:
        if rel and not rel.startswith(SKIP_DIRS) and rel not in SKIP_FILES and os.path.isfile(os.path.join(root, rel)):
            with open(os.path.join(root, rel), "rb") as handle:
                files[rel] = handle.read()
    return files


def build(source, out_dir, only):
    files = tree_files(source) if os.path.isdir(source) else zip_files(source)
    toc = files[SUITE + ".toc"].decode("utf-8")
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
    # The release build's commit beside each package zip, for the zip test's pass mark; a worktree build has none.
    commit = None
    if not os.path.isdir(source) and os.path.isfile(source + ".commit"):
        with open(source + ".commit", encoding="utf-8") as handle:
            commit = handle.read()
    made = []
    for pkg in PACKAGES:
        if only and pkg["id"] not in only:
            continue
        folder = pkg["folder"]
        path = "%s/%s-%s.zip" % (out_dir, folder, version)
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as out:
            for rel, data in sorted(files.items()):
                if rel == SUITE + ".toc":
                    rel = folder + ".toc"
                    data = toc_text(data.decode("utf-8"), pkg, folder).encode("utf-8")
                elif rel.endswith(".lua"):
                    data = lua_text(rel, data.decode("utf-8"), folder).encode("utf-8")
                out.writestr(folder + "/" + rel, data)
            out.writestr(folder + "/Package.lua", package_lua(pkg).encode("utf-8"))
        if commit:
            with open(path + ".commit", "w", encoding="utf-8", newline="\n") as handle:
                handle.write(commit)
        elif os.path.exists(path + ".commit"):
            os.remove(path + ".commit")
        made.append(path)
    return made


if __name__ == "__main__":
    if "--list" in sys.argv:
        print(" ".join(pkg["id"] for pkg in PACKAGES))
        sys.exit(0)
    args = [a for a in sys.argv[1:] if not a.startswith("--only")]
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = set(a.split("=", 1)[1].split(","))
    if len(args) != 2 or (only and not only <= {pkg["id"] for pkg in PACKAGES}):
        sys.exit(__doc__ + "\nPackages: " + " ".join(pkg["id"] for pkg in PACKAGES))
    for path in build(args[0], args[1], only):
        print("built " + path)
