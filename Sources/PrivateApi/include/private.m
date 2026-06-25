// This file exists purely because xcode doesn't like header only targets, SPM is fine with them
#import "private.h"
#import <dlfcn.h>

typedef CGError (*AS_SLPSSetFrontProcessWithOptions)(ProcessSerialNumber *psn, uint32_t wid, uint32_t mode);
typedef CGError (*AS_SLPSPostEventRecordTo)(ProcessSerialNumber *psn, uint8_t *bytes);

static void *ASSkyLightSymbol(const char *name) {
    static void *skyLight = NULL;
    if (skyLight == NULL) {
        skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
    }
    return skyLight == NULL ? NULL : dlsym(skyLight, name);
}

static AS_SLPSSetFrontProcessWithOptions ASGetSLPSSetFrontProcessWithOptions(void) {
    return (AS_SLPSSetFrontProcessWithOptions)ASSkyLightSymbol("_SLPSSetFrontProcessWithOptions");
}

static AS_SLPSPostEventRecordTo ASGetSLPSPostEventRecordTo(void) {
    return (AS_SLPSPostEventRecordTo)ASSkyLightSymbol("SLPSPostEventRecordTo");
}

static void ASAltTabMakeKeyWindow(ProcessSerialNumber *psn, uint32_t windowId) {
    enum {
        bufferSize = 0x100,
        lengthOffset = 0x04,
        recordLength = 0xf8,
        eventTypeOffset = 0x08,
        leftMouseDown = 0x01,
        leftMouseUp = 0x02,
        windowLocationOffset = 0x20,
        unknownFlagOffset = 0x3a,
        unknownFlagValue = 0x10,
        windowIdOffset = 0x3c,
    };

    CGPoint point = CGPointMake(-1, -1);
    uint8_t bytes[bufferSize] = {0};
    bytes[lengthOffset] = recordLength;
    bytes[unknownFlagOffset] = unknownFlagValue;
    memcpy(&bytes[windowIdOffset], &windowId, sizeof(windowId));
    memcpy(&bytes[windowLocationOffset], &point, sizeof(point));

    AS_SLPSPostEventRecordTo postEvent = ASGetSLPSPostEventRecordTo();
    if (postEvent == NULL) {
        return;
    }

    bytes[eventTypeOffset] = leftMouseDown;
    postEvent(psn, bytes);
    bytes[eventTypeOffset] = leftMouseUp;
    postEvent(psn, bytes);
}

void ASAltTabFocusWindow(pid_t pid, uint32_t windowId) {
    ProcessSerialNumber psn = {0, 0};
    if (GetProcessForPID(pid, &psn) != noErr) {
        return;
    }

    AS_SLPSSetFrontProcessWithOptions setFrontProcess = ASGetSLPSSetFrontProcessWithOptions();
    if (setFrontProcess == NULL) {
        return;
    }

    // Make the requested window key before fronting the process. In multi-monitor setups,
    // some apps (notably Safari) otherwise let WindowServer promote the app's previously-key
    // window on another monitor during the process-front step.
    ASAltTabMakeKeyWindow(&psn, windowId);

    // 0x200 is AltTab/yabai's user-generated front-process mode: front this
    // process for the specific window without bringing all app windows forward.
    setFrontProcess(&psn, windowId, 0x200);

    // Repeat after fronting, matching AltTab's intended final key-window state.
    ASAltTabMakeKeyWindow(&psn, windowId);
}
