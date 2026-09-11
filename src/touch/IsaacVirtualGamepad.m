#import "IsaacVirtualGamepad.h"
#import <objc/runtime.h>

static NSString *const kIVGEnabledDefaultsKey = @"IsaacCustomTouchControlsEnabled";

#pragma mark - Virtual GameController Classes

@interface IVGAxisInput : NSObject
@property (atomic, assign) float fakeValue;
@end

@implementation IVGAxisInput
- (float)value {
    return self.fakeValue;
}
- (BOOL)isAnalog {
    return YES;
}
- (BOOL)isKindOfClass:(Class)aClass {
    NSString *name = NSStringFromClass(aClass);
    if ([name isEqualToString:@"GCControllerAxisInput"] ||
        [name isEqualToString:@"GCControllerElement"]) {
        return YES;
    }
    return [super isKindOfClass:aClass];
}
@end

@interface IVGButtonInput : NSObject
@property (atomic, assign) float fakeValue;
@end

@implementation IVGButtonInput
- (float)value {
    return self.fakeValue;
}
- (BOOL)isPressed {
    return self.fakeValue > 0.5f;
}
- (BOOL)isAnalog {
    return NO;
}
- (BOOL)isKindOfClass:(Class)aClass {
    NSString *name = NSStringFromClass(aClass);
    if ([name isEqualToString:@"GCControllerButtonInput"] ||
        [name isEqualToString:@"GCControllerElement"]) {
        return YES;
    }
    return [super isKindOfClass:aClass];
}
@end

@interface IVGDirectionPad : NSObject
@property (nonatomic, strong) IVGAxisInput *fakeXAxis;
@property (nonatomic, strong) IVGAxisInput *fakeYAxis;
@property (nonatomic, strong) IVGButtonInput *fakeUp;
@property (nonatomic, strong) IVGButtonInput *fakeDown;
@property (nonatomic, strong) IVGButtonInput *fakeLeft;
@property (nonatomic, strong) IVGButtonInput *fakeRight;
@end

@implementation IVGDirectionPad
- (instancetype)init {
    self = [super init];
    if (self) {
        _fakeXAxis = [IVGAxisInput new];
        _fakeYAxis = [IVGAxisInput new];
        _fakeUp = [IVGButtonInput new];
        _fakeDown = [IVGButtonInput new];
        _fakeLeft = [IVGButtonInput new];
        _fakeRight = [IVGButtonInput new];
    }
    return self;
}
- (id)xAxis { return self.fakeXAxis; }
- (id)yAxis { return self.fakeYAxis; }
- (id)up { return self.fakeUp; }
- (id)down { return self.fakeDown; }
- (id)left { return self.fakeLeft; }
- (id)right { return self.fakeRight; }
- (BOOL)isKindOfClass:(Class)aClass {
    NSString *name = NSStringFromClass(aClass);
    if ([name isEqualToString:@"GCControllerDirectionPad"] ||
        [name isEqualToString:@"GCControllerElement"]) {
        return YES;
    }
    return [super isKindOfClass:aClass];
}
@end

@class IVGController;

@interface IVGExtendedGamepad : NSObject
@property (nonatomic, weak) IVGController *controller;
@property (nonatomic, strong) IVGDirectionPad *leftThumbstick;
@property (nonatomic, strong) IVGDirectionPad *rightThumbstick;
@property (nonatomic, strong) IVGDirectionPad *dpad;
@property (nonatomic, strong) IVGButtonInput *buttonA;
@property (nonatomic, strong) IVGButtonInput *buttonB;
@property (nonatomic, strong) IVGButtonInput *buttonX;
@property (nonatomic, strong) IVGButtonInput *buttonY;
@property (nonatomic, strong) IVGButtonInput *leftShoulder;
@property (nonatomic, strong) IVGButtonInput *rightShoulder;
@property (nonatomic, strong) IVGButtonInput *leftTrigger;
@property (nonatomic, strong) IVGButtonInput *rightTrigger;
@property (nonatomic, strong) IVGButtonInput *buttonMenu;
@property (nonatomic, strong) IVGButtonInput *buttonOptions;
@end

@implementation IVGExtendedGamepad
- (instancetype)init {
    self = [super init];
    if (self) {
        _leftThumbstick = [IVGDirectionPad new];
        _rightThumbstick = [IVGDirectionPad new];
        _dpad = [IVGDirectionPad new];
        _buttonA = [IVGButtonInput new];
        _buttonB = [IVGButtonInput new];
        _buttonX = [IVGButtonInput new];
        _buttonY = [IVGButtonInput new];
        _leftShoulder = [IVGButtonInput new];
        _rightShoulder = [IVGButtonInput new];
        _leftTrigger = [IVGButtonInput new];
        _rightTrigger = [IVGButtonInput new];
        _buttonMenu = [IVGButtonInput new];
        _buttonOptions = [IVGButtonInput new];
    }
    return self;
}
- (BOOL)isKindOfClass:(Class)aClass {
    NSString *name = NSStringFromClass(aClass);
    if ([name isEqualToString:@"GCExtendedGamepad"] ||
        [name isEqualToString:@"GCGamepad"]) {
        return YES;
    }
    return [super isKindOfClass:aClass];
}
@end

@interface IVGController : NSObject
@property (nonatomic, strong) IVGExtendedGamepad *extendedGamepad;
@property (nonatomic, assign) NSInteger playerIndex;
@property (nonatomic, copy) NSString *vendorName;
@end

@implementation IVGController
- (instancetype)init {
    self = [super init];
    if (self) {
        _extendedGamepad = [IVGExtendedGamepad new];
        _extendedGamepad.controller = self;
        _playerIndex = 0; // GCControllerPlayerIndex1
        _vendorName = @"Isaac Virtual Touch Gamepad";
    }
    return self;
}
- (id)gamepad { return self.extendedGamepad; }
- (id)microGamepad { return nil; }
- (BOOL)isAttachedToDevice { return YES; }
- (BOOL)isKindOfClass:(Class)aClass {
    NSString *name = NSStringFromClass(aClass);
    if ([name isEqualToString:@"GCController"]) {
        return YES;
    }
    return [super isKindOfClass:aClass];
}
@end

#pragma mark - Shared State & Swizzling

static IVGController *gSharedVirtualController = nil;
static NSArray *(*gOrigGCControllerControllers)(id, SEL) = NULL;

static NSArray *Hook_GCController_controllers(id self, SEL _cmd) {
    NSArray *realControllers = nil;
    if (gOrigGCControllerControllers) {
        realControllers = gOrigGCControllerControllers(self, _cmd);
    }
    // If real physical controllers are connected, they take full priority!
    if (realControllers.count > 0) {
        return realControllers;
    }
    if (!IVGIsEnabled() || gSharedVirtualController == nil) {
        return realControllers ?: @[];
    }
    return @[ gSharedVirtualController ];
}

BOOL IVGHasPhysicalControllers(void) {
    if (!gOrigGCControllerControllers) return NO;
    Class gcClass = NSClassFromString(@"GCController");
    if (!gcClass) return NO;
    NSArray *real = gOrigGCControllerControllers(gcClass, @selector(controllers));
    return real.count > 0;
}

void IVGInstallVirtualGamepad(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gSharedVirtualController = [IVGController new];

        Class gcClass = NSClassFromString(@"GCController");
        if (!gcClass) {
            NSLog(@"[IsaacTouch] GameController.framework not loaded yet, loading...");
            [[NSBundle bundleWithPath:@"/System/Library/Frameworks/GameController.framework"] load];
            gcClass = NSClassFromString(@"GCController");
        }
        if (gcClass) {
            Method origMethod = class_getClassMethod(gcClass, @selector(controllers));
            if (origMethod) {
                gOrigGCControllerControllers = (NSArray *(*)(id, SEL))method_getImplementation(origMethod);
                method_setImplementation(origMethod, (IMP)Hook_GCController_controllers);
                NSLog(@"[IsaacTouch] Successfully hooked [GCController controllers]");
            } else {
                NSLog(@"[IsaacTouch] Warning: [GCController controllers] method not found");
            }
        } else {
            NSLog(@"[IsaacTouch] Error: GCController class could not be resolved");
        }
    });
}

BOOL IVGIsEnabled(void) {
    NSNumber *val = [NSUserDefaults.standardUserDefaults objectForKey:kIVGEnabledDefaultsKey];
    if (val == nil) {
        return YES; // Default enabled
    }
    return [val boolValue];
}

void IVGSetEnabled(BOOL enabled) {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:kIVGEnabledDefaultsKey];
    if (!enabled) {
        IVGResetAllInputs();
    }
}

void IVGSetLeftStick(float x, float y) {
    if (!gSharedVirtualController) return;
    IVGDirectionPad *stick = gSharedVirtualController.extendedGamepad.leftThumbstick;
    stick.fakeXAxis.fakeValue = x;
    stick.fakeYAxis.fakeValue = y;
    stick.fakeRight.fakeValue = (x > 0.2f) ? x : 0.0f;
    stick.fakeLeft.fakeValue = (x < -0.2f) ? -x : 0.0f;
    stick.fakeUp.fakeValue = (y > 0.2f) ? y : 0.0f;
    stick.fakeDown.fakeValue = (y < -0.2f) ? -y : 0.0f;
}

void IVGSetRightStick(float x, float y) {
    if (!gSharedVirtualController) return;
    IVGDirectionPad *stick = gSharedVirtualController.extendedGamepad.rightThumbstick;
    stick.fakeXAxis.fakeValue = x;
    stick.fakeYAxis.fakeValue = y;
    stick.fakeRight.fakeValue = (x > 0.2f) ? x : 0.0f;
    stick.fakeLeft.fakeValue = (x < -0.2f) ? -x : 0.0f;
    stick.fakeUp.fakeValue = (y > 0.2f) ? y : 0.0f;
    stick.fakeDown.fakeValue = (y < -0.2f) ? -y : 0.0f;
}

void IVGSetShootButtons(BOOL up, BOOL down, BOOL left, BOOL right) {
    if (!gSharedVirtualController) return;
    IVGExtendedGamepad *gp = gSharedVirtualController.extendedGamepad;
    
    // Set direct face buttons
    gp.buttonY.fakeValue = up ? 1.0f : 0.0f;
    gp.buttonA.fakeValue = down ? 1.0f : 0.0f;
    gp.buttonX.fakeValue = left ? 1.0f : 0.0f;
    gp.buttonB.fakeValue = right ? 1.0f : 0.0f;
    
    // Also drive right stick for maximum compatibility with all items
    float stickX = 0.0f;
    float stickY = 0.0f;
    if (left) stickX -= 1.0f;
    if (right) stickX += 1.0f;
    if (up) stickY += 1.0f;
    if (down) stickY -= 1.0f;
    
    gp.rightThumbstick.fakeXAxis.fakeValue = stickX;
    gp.rightThumbstick.fakeYAxis.fakeValue = stickY;
    gp.rightThumbstick.fakeUp.fakeValue = up ? 1.0f : 0.0f;
    gp.rightThumbstick.fakeDown.fakeValue = down ? 1.0f : 0.0f;
    gp.rightThumbstick.fakeLeft.fakeValue = left ? 1.0f : 0.0f;
    gp.rightThumbstick.fakeRight.fakeValue = right ? 1.0f : 0.0f;
}

void IVGSetButton(IVGButton button, BOOL pressed) {
    if (!gSharedVirtualController) return;
    IVGExtendedGamepad *gp = gSharedVirtualController.extendedGamepad;
    float val = pressed ? 1.0f : 0.0f;
    switch (button) {
        case IVGButtonA: gp.buttonA.fakeValue = val; break;
        case IVGButtonB: gp.buttonB.fakeValue = val; break;
        case IVGButtonX: gp.buttonX.fakeValue = val; break;
        case IVGButtonY: gp.buttonY.fakeValue = val; break;
        case IVGButtonLeftTrigger: gp.leftTrigger.fakeValue = val; break;
        case IVGButtonLeftShoulder: gp.leftShoulder.fakeValue = val; break;
        case IVGButtonRightShoulder: gp.rightShoulder.fakeValue = val; break;
        case IVGButtonRightTrigger: gp.rightTrigger.fakeValue = val; break;
        case IVGButtonMenu: gp.buttonMenu.fakeValue = val; break;
        case IVGButtonOptions: gp.buttonOptions.fakeValue = val; break;
    }
}

void IVGResetAllInputs(void) {
    if (!gSharedVirtualController) return;
    IVGExtendedGamepad *gp = gSharedVirtualController.extendedGamepad;
    gp.leftThumbstick.fakeXAxis.fakeValue = 0.0f;
    gp.leftThumbstick.fakeYAxis.fakeValue = 0.0f;
    gp.leftThumbstick.fakeUp.fakeValue = 0.0f;
    gp.leftThumbstick.fakeDown.fakeValue = 0.0f;
    gp.leftThumbstick.fakeLeft.fakeValue = 0.0f;
    gp.leftThumbstick.fakeRight.fakeValue = 0.0f;

    gp.rightThumbstick.fakeXAxis.fakeValue = 0.0f;
    gp.rightThumbstick.fakeYAxis.fakeValue = 0.0f;
    gp.rightThumbstick.fakeUp.fakeValue = 0.0f;
    gp.rightThumbstick.fakeDown.fakeValue = 0.0f;
    gp.rightThumbstick.fakeLeft.fakeValue = 0.0f;
    gp.rightThumbstick.fakeRight.fakeValue = 0.0f;

    gp.buttonA.fakeValue = 0.0f;
    gp.buttonB.fakeValue = 0.0f;
    gp.buttonX.fakeValue = 0.0f;
    gp.buttonY.fakeValue = 0.0f;
    gp.leftTrigger.fakeValue = 0.0f;
    gp.leftShoulder.fakeValue = 0.0f;
    gp.rightShoulder.fakeValue = 0.0f;
    gp.rightTrigger.fakeValue = 0.0f;
    gp.buttonMenu.fakeValue = 0.0f;
    gp.buttonOptions.fakeValue = 0.0f;
}
