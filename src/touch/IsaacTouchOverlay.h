#pragma once

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, IVGShootMode) {
    IVGShootModeButtons = 0, // 4-directional buttons (Rollable for Brimstone/Tech X)
    IVGShootModeStick = 1    // 360-degree analog stick (for Analog Stick, Marked, Eye of Occult)
};

typedef NS_ENUM(NSInteger, IVGJacobPetalsMode) {
    IVGJacobPetalsAuto = 0,    // Show petals when playing Jacob & Esau (auto-detected)
    IVGJacobPetalsAlways = 1,  // Always show petals when holding RT
    IVGJacobPetalsDisabled = 2 // Disabled
};

@interface IsaacTouchOverlayView : UIView

+ (instancetype)sharedOverlay;
- (void)updateLayoutForWindow:(UIWindow *)window;
- (void)toggleShootMode;

@property (nonatomic, assign) IVGShootMode shootMode;
@property (nonatomic, assign) CGFloat controlsOpacity;
@property (nonatomic, assign) BOOL hapticsEnabled;
@property (nonatomic, assign) IVGJacobPetalsMode jacobPetalsMode;

@end

#ifdef __cplusplus
extern "C" {
#endif

void ICSInstallTouchOverlay(void);
void ICSUpdateTouchOverlayVisibility(void);

#ifdef __cplusplus
}
#endif
