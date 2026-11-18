#!/usr/bin/env python3
"""Headless OpenXR probe: prints what GTAVXR's frame gate looks at.

GTAVXR (code/bridge/session.h, readiness.h) only renders when shouldRender, the session is
FOCUSED, both views have POSITION/ORIENTATION VALID+TRACKED flags, eye separation is
45-85 mm, the eyes are parallel, and (before the first frame) the head moves < 2 cm and
< 2 deg per frame for 3 frames. Uses XR_MND_headless, so no graphics API is needed; Monado
runs no frame loop for headless sessions, so views are sampled at "now" (via
XR_KHR_convert_timespec_time) at ~60 Hz instead of xrWaitFrame's predicted time.

    XR_RUNTIME_JSON=/usr/share/openxr/1/openxr_monado.json python3 -I xr-probe.py [frames]
"""
import ctypes as C, math, sys, time

xr = C.CDLL("libopenxr_loader.so.1")
U32, U64, I64, P = C.c_uint32, C.c_uint64, C.c_int64, C.c_void_p
FRAMES = int(sys.argv[1]) if len(sys.argv) > 1 else 240

class AppInfo(C.Structure):
    _fields_ = [("appName", C.c_char * 128), ("appVer", U32), ("engName", C.c_char * 128), ("engVer", U32), ("api", U64)]
class InstanceCI(C.Structure):
    _fields_ = [("type", U32), ("next", P), ("flags", U64), ("app", AppInfo), ("nLayers", U32), ("layers", P),
                ("nExt", U32), ("exts", C.POINTER(C.c_char_p))]
class SystemGI(C.Structure): _fields_ = [("type", U32), ("next", P), ("formFactor", U32)]
class SessionCI(C.Structure): _fields_ = [("type", U32), ("next", P), ("flags", U64), ("system", U64)]
class Quat(C.Structure): _fields_ = [("x", C.c_float), ("y", C.c_float), ("z", C.c_float), ("w", C.c_float)]
class Vec3(C.Structure): _fields_ = [("x", C.c_float), ("y", C.c_float), ("z", C.c_float)]
class Pose(C.Structure): _fields_ = [("q", Quat), ("p", Vec3)]
class Fov(C.Structure): _fields_ = [("l", C.c_float), ("r", C.c_float), ("u", C.c_float), ("d", C.c_float)]
class RefSpaceCI(C.Structure): _fields_ = [("type", U32), ("next", P), ("refType", U32), ("pose", Pose)]
class EventBuf(C.Structure): _fields_ = [("type", U32), ("next", P), ("varying", C.c_uint8 * 4000)]
class StateEv(C.Structure): _fields_ = [("type", U32), ("next", P), ("session", P), ("state", U32), ("time", I64)]
class BeginInfo(C.Structure): _fields_ = [("type", U32), ("next", P), ("viewConfig", U32)]
class WaitInfo(C.Structure): _fields_ = [("type", U32), ("next", P)]
class FrameState(C.Structure): _fields_ = [("type", U32), ("next", P), ("time", I64), ("period", I64), ("shouldRender", U32)]
class FrameBegin(C.Structure): _fields_ = [("type", U32), ("next", P)]
class FrameEnd(C.Structure): _fields_ = [("type", U32), ("next", P), ("time", I64), ("blend", U32), ("nLayers", U32), ("layers", P)]
class LocateInfo(C.Structure): _fields_ = [("type", U32), ("next", P), ("viewConfig", U32), ("time", I64), ("space", P)]
class ViewState(C.Structure): _fields_ = [("type", U32), ("next", P), ("flags", U64)]
class View(C.Structure): _fields_ = [("type", U32), ("next", P), ("pose", Pose), ("fov", Fov)]

def ok(r, what):
    if r < 0: sys.exit(f"{what} failed: {r}")

inst, sysid, sess, space = P(), U64(), P(), P()
exts = (C.c_char_p * 2)(b"XR_MND_headless", b"XR_KHR_convert_timespec_time")
ci = InstanceCI(type=3, app=AppInfo(appName=b"gtavxr-linux xr-probe", api=(1 << 48) | (0 << 32)), nExt=2, exts=exts)
ok(xr.xrCreateInstance(C.byref(ci), C.byref(inst)), "xrCreateInstance")
ok(xr.xrGetSystem(inst, C.byref(SystemGI(type=4, formFactor=1)), C.byref(sysid)), "xrGetSystem")
ok(xr.xrCreateSession(inst, C.byref(SessionCI(type=8, system=sysid.value)), C.byref(sess)), "xrCreateSession")
ok(xr.xrCreateReferenceSpace(sess, C.byref(RefSpaceCI(type=37, refType=3, pose=Pose(q=Quat(w=1)))), C.byref(space)),
   "xrCreateReferenceSpace(STAGE)")

class Timespec(C.Structure): _fields_ = [("sec", C.c_long), ("nsec", C.c_long)]
librt = C.CDLL(None)
fn = P()
ok(xr.xrGetInstanceProcAddr(inst, b"xrConvertTimespecTimeToTimeKHR", C.byref(fn)), "xrGetInstanceProcAddr")
to_xr_time = C.CFUNCTYPE(C.c_int32, P, C.POINTER(Timespec), C.POINTER(I64))(fn.value)
def now():
    ts = Timespec(); librt.clock_gettime(1, C.byref(ts))  # CLOCK_MONOTONIC
    t = I64(); ok(to_xr_time(inst, C.byref(ts), C.byref(t)), "xrConvertTimespecTimeToTimeKHR"); return t.value

STATES = {1: "IDLE", 2: "READY", 3: "SYNCHRONIZED", 4: "VISIBLE", 5: "FOCUSED", 6: "STOPPING", 8: "EXITING"}
state, running = 0, False
def poll():
    global state, running
    while True:
        ev = EventBuf(type=16)
        if xr.xrPollEvent(inst, C.byref(ev)) != 0: return
        if ev.type == 18:
            state = C.cast(C.byref(ev), C.POINTER(StateEv)).contents.state
            print("STATE", STATES.get(state, state))
            if state == 2 and not running:
                ok(xr.xrBeginSession(sess, C.byref(BeginInfo(type=10, viewConfig=2))), "xrBeginSession"); running = True

FLAGS = {1: "ORI_VALID", 2: "POS_VALID", 4: "ORI_TRACKED", 8: "POS_TRACKED"}
prev, stable, frames, seen = None, 0, 0, {}
while frames < FRAMES:
    poll()
    if not running: continue
    time.sleep(1/60); fs = FrameState(type=44, time=now(), shouldRender=1)  # shouldRender: n/a headless
    vs, n, views = ViewState(type=11), U32(), (View * 2)(View(type=7), View(type=7))
    ok(xr.xrLocateViews(sess, C.byref(LocateInfo(type=6, viewConfig=2, time=fs.time, space=space)), C.byref(vs), 2,
                        C.byref(n), views), "xrLocateViews")
    frames += 1
    a, b = views[0].pose, views[1].pose
    ipd = math.dist((a.p.x, a.p.y, a.p.z), (b.p.x, b.p.y, b.p.z))
    par = abs(a.q.x*b.q.x + a.q.y*b.q.y + a.q.z*b.q.z + a.q.w*b.q.w)
    mid = ((a.p.x+b.p.x)/2, (a.p.y+b.p.y)/2, (a.p.z+b.p.z)/2)
    move = math.dist(mid, prev[0]) if prev else 0.0
    dot = min(1.0, abs(a.q.x*prev[1].x + a.q.y*prev[1].y + a.q.z*prev[1].z + a.q.w*prev[1].w)) if prev else 1.0
    turn = math.degrees(2*math.acos(dot))
    flags = "|".join(v for k, v in FLAGS.items() if vs.flags & k) or "none"
    tracked = (vs.flags & 15) == 15
    close = move <= .02 and dot >= math.cos(math.radians(1))
    stable = stable + 1 if (prev and close and tracked and .045 <= ipd <= .085 and par >= .99999) else 1
    prev = (mid, Quat(a.q.x, a.q.y, a.q.z, a.q.w))
    key = (flags, fs.shouldRender, STATES.get(state, state))
    seen[key] = seen.get(key, 0) + 1
    if frames <= 3 or frames % 60 == 0:
        print(f"frame {frames}: shouldRender={fs.shouldRender} state={STATES.get(state, state)} views={n.value} flags={flags} "
              f"ipd={ipd*1000:.1f}mm parallel={par:.6f} move={move*1000:.2f}mm/frame turn={turn:.3f}deg/frame stable={stable}")
print("summary:", {f"flags={k[0]} shouldRender={k[1]} state={k[2]}": v for k, v in seen.items()})
print("GTAVXR gate would pass" if stable >= 3 else "GTAVXR gate would NOT pass")
xr.xrRequestExitSession(sess)
