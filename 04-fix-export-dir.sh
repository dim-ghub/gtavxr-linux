#!/usr/bin/env bash
# Clear the bogus PE export-directory entry in GTAVXR_SourceBaseline.exe, and tell the
# Suite about the new hash so Play doesn't refuse it ("A file is not the one expected").
#
# Why: GTAVXR 1.0.2's patched exe has an export data directory (RVA 0x277C0FC, size 4)
# that overlaps the import table, so it decodes as NumberOfNames=0x277CF08, AddressOfNames=0.
# When the game calls GetProcAddress() on itself, Windows faults inside the lookup, catches
# it and returns NULL. Wine's LdrGetProcedureAddress doesn't catch it, so the game dies at
# startup with c0000005 at ntdll+0x4d2d0 (read of base+0x4EF9E0C).
# Zeroing the directory entry makes GetProcAddress return NULL directly, same as Windows.
#
# The Suite checks the exe's sha256 against Suite/versions/<id>.json before every Play and
# against Suite/game/state.json in "Check files". Only that hash string is changed in both;
# the file size is unchanged. Originals go to backup/.
#
# Safe to re-run. Re-run after the Suite's "Check files", a GTAVXR update or reinstall,
# since those can restore the original exe or rewrite the Suite's records.
set -e
source "$(dirname "$0")/env.sh"
need_gta
exe="$GTA_DIR/GTAVXR_SourceBaseline.exe"
suite="$PFX/drive_c/users/steamuser/AppData/Local/GTAVXR/Suite"
[ -f "$exe" ] || { echo "No $exe yet. Install GTAVXR from the Suite first." >&2; exit 1; }
[ -f "$suite/game/state.json" ] || { echo "No Suite data at $suite" >&2; exit 1; }
pgrep -f '[G]TAVXR_SourceBaseline\.exe' >/dev/null && { echo "Close the game first." >&2; exit 1; }
pgrep -f '[G]TAVXR\.exe' >/dev/null && { echo "Close the GTAVXR Suite first (it may rewrite its records)." >&2; exit 1; }

mkdir -p "$HERE/backup"
python3 -I - "$exe" "$suite" "$HERE/backup" <<'PY'
import glob,hashlib,json,os,shutil,struct,sys,time
exe,suite,bk=sys.argv[1:4]
stamp=time.strftime('%Y%m%d-%H%M%S')

b=bytearray(open(exe,'rb').read())
pe=struct.unpack_from('<I',b,0x3c)[0]
assert b[pe:pe+4]==b'PE\0\0' and struct.unpack_from('<H',b,pe+24)[0]==0x20b, "not a PE32+ image"
exp=pe+24+112                      # DataDirectory[0] = export table
old=hashlib.sha256(b).hexdigest().upper()
rva,size=struct.unpack_from('<II',b,exp)
if rva or size:
    dst=os.path.join(bk,f"GTAVXR_SourceBaseline-{old[:12].lower()}.exe")
    if not os.path.exists(dst): shutil.copy2(exe,dst)
    print(f"Backed up original exe (sha256 {old}) to {dst}")
    print(f"Clearing export directory rva={rva:#x} size={size:#x}")
    struct.pack_into('<II',b,exp,0,0)
    open(exe,'r+b').write(b)
else:
    print("Export directory already cleared.")
new=hashlib.sha256(b).hexdigest().upper()
print("Exe sha256 now:",new)

# Point the Suite's records for this exe at the new hash.
records=[os.path.join(suite,'game','state.json')]+glob.glob(os.path.join(suite,'versions','*.json'))
for p in records:
    text=open(p,encoding='utf-8-sig').read()
    files=json.loads(text).get('files') or []
    stale={f['sha256'] for f in files if f.get('path')=='GTAVXR_SourceBaseline.exe' and f['sha256'].upper()!=new}
    if not stale:
        continue
    for f in files:
        if f.get('path')=='GTAVXR_SourceBaseline.exe': assert f['bytes']==len(b), f"size differs in {p}"
    shutil.copy2(p,os.path.join(bk,f"{os.path.basename(os.path.dirname(p))}-{os.path.basename(p)}.{stamp}"))
    for h in stale:
        assert text.count(h)==1 or os.path.basename(p)=='state.json', f"unexpected hash count in {p}"
        text=text.replace(h,new)
    json.loads(text)
    open(p,'w',encoding='utf-8').write(text)
    print("Updated Suite record:",os.path.relpath(p,suite))
PY
