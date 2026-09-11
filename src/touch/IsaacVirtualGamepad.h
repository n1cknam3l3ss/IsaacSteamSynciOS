#pragma once

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, IVGButton) {
    IVGButtonA = 0,         // Shoot Down / Confirm
    IVGButtonB = 1,         // Shoot Right / Cancel
    IVGButtonX = 2,         // Shoot Left
    IVGButtonY = 3,         // Shoot Up
    IVGButtonLeftTrigger = 4,  // Bomb (LT)
    IVGButtonLeftShoulder = 5, // Active Item / Space (LB)
    IVGButtonRightShoulder = 6,// Pill / Card (RB)
    IVGButtonRightTrigger = 7, // Drop / Swap (RT)
    IVGButtonMenu = 8,         // Pause (Menu)
    IVGButtonOptions = 9       // Map (Options / Select)
};

#ifdef __cplusplus
extern "C" {
#endif

/// Initialize and swizzle [GCController controllers]
void IVGInstallVirtualGamepad(void);

/// Enable or disable virtual gamepad injection
void IVGSetEnabled(BOOL enabled);
BOOL IVGIsEnabled(void);

/// Set movement stick axis values (-1.0 to 1.0, Up is positive, Right is positive)
void IVGSetLeftStick(float x, float y);

/// Set shooting stick axis values (-1.0 to 1.0, Up is positive, Right is positive)
void IVGSetRightStick(float x, float y);

/// Set directional shooting buttons (for 4-button rollable mode)
void IVGSetShootButtons(BOOL up, BOOL down, BOOL left, BOOL right);

/// Set arbitrary button state
void IVGSetButton(IVGButton button, BOOL pressed);

/// Release all inputs (e.g. on pause or screen transition)
void IVGResetAllInputs(void);

#ifdef __cplusplus
}
#endif
