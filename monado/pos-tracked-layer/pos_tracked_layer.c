// OpenXR API layer for testing GTAVXR against Monado's simulated headset.
// Monado's simulated HMD reports views as ORIENTATION_VALID|POSITION_VALID|ORIENTATION_TRACKED
// but never POSITION_TRACKED. GTAVXR (code/bridge/session.h) requires all four bits before it
// renders, so it never submits a frame. This layer adds POSITION_TRACKED in xrLocateViews (and
// xrLocateSpace) whenever POSITION_VALID is already set. Test use only; real headsets need nothing.
#include <string.h>
#include <openxr/openxr.h>
#include <openxr/openxr_loader_negotiation.h>

#define LAYER_NAME "XR_APILAYER_GTAVXRLINUX_pos_tracked"
#define EXPORT __attribute__((visibility("default")))

static PFN_xrGetInstanceProcAddr next_gipa;
static PFN_xrLocateViews next_locate_views;
static PFN_xrLocateSpace next_locate_space;

static XRAPI_ATTR XrResult XRAPI_CALL layer_locate_views(XrSession s, const XrViewLocateInfo *info, XrViewState *state,
                                                         uint32_t cap, uint32_t *count, XrView *views) {
    XrResult r = next_locate_views(s, info, state, cap, count, views);
    if (XR_SUCCEEDED(r) && state && (state->viewStateFlags & XR_VIEW_STATE_POSITION_VALID_BIT))
        state->viewStateFlags |= XR_VIEW_STATE_POSITION_TRACKED_BIT;
    return r;
}

static XRAPI_ATTR XrResult XRAPI_CALL layer_locate_space(XrSpace sp, XrSpace base, XrTime t, XrSpaceLocation *loc) {
    XrResult r = next_locate_space(sp, base, t, loc);
    if (XR_SUCCEEDED(r) && loc && (loc->locationFlags & XR_SPACE_LOCATION_POSITION_VALID_BIT))
        loc->locationFlags |= XR_SPACE_LOCATION_POSITION_TRACKED_BIT;
    return r;
}

static XRAPI_ATTR XrResult XRAPI_CALL layer_gipa(XrInstance inst, const char *name, PFN_xrVoidFunction *fn) {
    if (!strcmp(name, "xrGetInstanceProcAddr")) { *fn = (PFN_xrVoidFunction)layer_gipa; return XR_SUCCESS; }
    if (!strcmp(name, "xrLocateViews") && next_locate_views) { *fn = (PFN_xrVoidFunction)layer_locate_views; return XR_SUCCESS; }
    if (!strcmp(name, "xrLocateSpace") && next_locate_space) { *fn = (PFN_xrVoidFunction)layer_locate_space; return XR_SUCCESS; }
    return next_gipa(inst, name, fn);
}

static XRAPI_ATTR XrResult XRAPI_CALL layer_create_instance(const XrInstanceCreateInfo *info, const XrApiLayerCreateInfo *li,
                                                            XrInstance *inst) {
    if (!li || !li->nextInfo || strcmp(li->nextInfo->layerName, LAYER_NAME)) return XR_ERROR_INITIALIZATION_FAILED;
    XrApiLayerCreateInfo down = *li;
    down.nextInfo = li->nextInfo->next;
    XrResult r = li->nextInfo->nextCreateApiLayerInstance(info, &down, inst);
    if (XR_FAILED(r)) return r;
    next_gipa = li->nextInfo->nextGetInstanceProcAddr;
    next_gipa(*inst, "xrLocateViews", (PFN_xrVoidFunction *)&next_locate_views);
    next_gipa(*inst, "xrLocateSpace", (PFN_xrVoidFunction *)&next_locate_space);
    return r;
}

EXPORT XRAPI_ATTR XrResult XRAPI_CALL xrNegotiateLoaderApiLayerInterface(const XrNegotiateLoaderInfo *loader, const char *name,
                                                                        XrNegotiateApiLayerRequest *req) {
    if (!loader || !req || strcmp(name, LAYER_NAME) ||
        loader->minInterfaceVersion > XR_CURRENT_LOADER_API_LAYER_VERSION ||
        loader->maxInterfaceVersion < XR_CURRENT_LOADER_API_LAYER_VERSION)
        return XR_ERROR_INITIALIZATION_FAILED;
    req->layerInterfaceVersion = XR_CURRENT_LOADER_API_LAYER_VERSION;
    req->layerApiVersion = XR_CURRENT_API_VERSION;
    req->getInstanceProcAddr = layer_gipa;
    req->createApiLayerInstance = layer_create_instance;
    return XR_SUCCESS;
}
