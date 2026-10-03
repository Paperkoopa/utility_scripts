from pathlib import Path
import sys

if len(sys.argv) != 4:
    print("Usage: rename.py [PATH] [REPLACE] [REPLACEMENT]")
    print("\n[PATH]: Path to directory containing files to be renamed")
    print("[REPLACE]: String that is to be replaced by [REPLACEMENT]")
    print("\nExample: rename.py \"./Season 5\" 05. \"Series Name S05E\"")
    print("This would turn \"05.01 - Episode Title.mp4\" into \"Series Name S05E01 - Episode Title.mp4\" and so on for every file in relative folder \"Season 5\"")
    exit()

folder = Path(sys.argv[1])

for file in folder.iterdir():
    if not file.is_file:
        continue

    newFile = file.stem.replace(sys.argv[2], sys.argv[3]) + file.suffix

    newPath = file.parent.joinpath(newFile)

    print(file.name + " -> " + newFile)
    file.rename(newPath)

print("\nDone.")
