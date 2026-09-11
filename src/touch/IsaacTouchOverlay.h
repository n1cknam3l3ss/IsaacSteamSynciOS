#pragma once

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, IVGShootMode) {
    IVGShootModeButtons = 0, // 4-directional buttons (Rollable for Brimstone/Tech X)
    IVGShootModeStick = 1    // 360-degree analog stick (for Analog Stick, Marked, Eye of Occult)
};

@interface IsaacTouchOverlayView : UIView

+ (instancetype)sharedOverlay;
- (void)updateLayoutForWindow:(UIWindow *)window;
- (void)toggleShootMode;
- (void)setShootMode:(IVGShootMode)mode;
- (IVGShootMode)shootMode;

@property (nonatomic, assign) CGFloat controlsOpacity;
@property (nonatomic, assign) BOOL hapticsEnabled;

@end

#ifdef __cplusplus
extern "C" {
#endif

void ICSInstallTouchOverlay(void);
void ICSUpdateTouchOverlayVisibility(void);

#ifdef __cplusplus
}
#endif
