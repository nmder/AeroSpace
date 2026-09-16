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
        windowLocationOffset = 0x20,
        unknownFlagOffset = 0x3a,
        unknownFlagValue = 0x10,
        windowIdOffset = 0x3c,
    };

    // A down event alone is enough to make the window key. Omitting the up event prevents a
    // synthetic click from activating window content. Keep the point far beyond the bottom-right;
    // on macOS 27, points near the frame (including -1, -1) can hit the resize grab region.
    CGPoint point = CGPointMake(300000, 300000);
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

    // 0x200 is AltTab/yabai's user-generated front-process mode: front this
    // process for the specific window without bringing all app windows forward.
    setFrontProcess(&psn, windowId, 0x200);

    // Front first, then make the requested window key. A pre-front key event is not sufficient on
    // macOS 27; the front-process operation can replace the app's key window.
    ASAltTabMakeKeyWindow(&psn, windowId);
}
