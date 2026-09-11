#import "IsaacTouchOverlay.h"
#import "IsaacVirtualGamepad.h"
#import <AudioToolbox/AudioToolbox.h>

extern bool ICSGameMenuIsActive(void);

static NSString *const kIVGShootModeDefaultsKey = @"IsaacTouchShootMode";
static NSString *const kIVGOpacityDefaultsKey = @"IsaacTouchOpacity";
static NSString *const kIVGHapticsDefaultsKey = @"IsaacTouchHapticsEnabled";

@interface IsaacTouchOverlayView () {
    // Touches tracking
    __weak UITouch *_leftStickTouch;
    __weak UITouch *_rightShootTouch;
    __weak UITouch *_bombTouch;
    __weak UITouch *_itemTouch;
    __weak UITouch *_cardTouch;
    __weak UITouch *_dropTouch;
    __weak UITouch *_mapTouch;
    __weak UITouch *_pauseTouch;

    // Left stick state
    CGPoint _leftStickAnchor;
    CGPoint _leftStickKnob;
    BOOL _leftStickActive;

    // Right shoot buttons state
    CGPoint _shootClusterCenter;
    BOOL _shootUp;
    BOOL _shootDown;
    BOOL _shootLeft;
    BOOL _shootRight;

    // Right shoot stick state (Mode 2)
    CGPoint _rightStickAnchor;
    CGPoint _rightStickKnob;
    BOOL _rightStickActive;

    // Button frames
    CGRect _bombFrame;
    CGRect _itemFrame;
    CGRect _cardFrame;
    CGRect _dropFrame;
    CGRect _mapFrame;
    CGRect _pauseFrame;
    CGRect _modeToggleFrame;

    // Button pressed states
    BOOL _bombPressed;
    BOOL _itemPressed;
    BOOL _cardPressed;
    BOOL _dropPressed;
    BOOL _mapPressed;
    BOOL _pausePressed;

    UIImpactFeedbackGenerator *_hapticGenerator;
}

@property (nonatomic, assign) IVGShootMode shootMode;
@property (nonatomic, assign) CGFloat controlsOpacity;
@property (nonatomic, assign) BOOL hapticsEnabled;

@end

@implementation IsaacTouchOverlayView

+ (instancetype)sharedOverlay {
    static IsaacTouchOverlayView *overlay;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        overlay = [[IsaacTouchOverlayView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    });
    return overlay;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // Load preferences
        NSNumber *savedMode = [NSUserDefaults.standardUserDefaults objectForKey:kIVGShootModeDefaultsKey];
        _shootMode = savedMode ? [savedMode integerValue] : IVGShootModeButtons;

        NSNumber *savedOpacity = [NSUserDefaults.standardUserDefaults objectForKey:kIVGOpacityDefaultsKey];
        _controlsOpacity = savedOpacity ? [savedOpacity doubleValue] : 0.45;

        NSNumber *savedHaptics = [NSUserDefaults.standardUserDefaults objectForKey:kIVGHapticsDefaultsKey];
        _hapticsEnabled = savedHaptics ? [savedHaptics boolValue] : YES;

        _hapticGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [_hapticGenerator prepare];

        [self updateLayout];
    }
    return self;
}

- (void)updateLayoutForWindow:(UIWindow *)window {
    if (window) {
        self.frame = window.bounds;
        [self updateLayout];
        [self setNeedsDisplay];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateLayout];
}

- (void)updateLayout {
    CGRect bounds = self.bounds;
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    if (w <= 0 || h <= 0) return;

    // Safe area margins
    CGFloat rightMargin = 28.0;
    CGFloat bottomMargin = 28.0;
    CGFloat topMargin = 20.0;
    CGFloat leftMargin = 24.0;

    // Right shoot cluster center
    CGFloat clusterRadius = 60.0;
    _shootClusterCenter = CGPointMake(w - rightMargin - clusterRadius - 30.0,
                                      h - bottomMargin - clusterRadius - 10.0);

    // Mode toggle button (placed above shoot cluster)
    CGFloat toggleW = 84.0;
    CGFloat toggleH = 28.0;
    _modeToggleFrame = CGRectMake(_shootClusterCenter.x - toggleW * 0.5,
                                  _shootClusterCenter.y - clusterRadius - 46.0,
                                  toggleW, toggleH);

    // Action buttons
    CGFloat btnSize = 50.0;
    // Bomb (bottom-right, left of shoot cluster)
    _bombFrame = CGRectMake(_shootClusterCenter.x - clusterRadius - btnSize - 20.0,
                            h - bottomMargin - btnSize - 10.0,
                            btnSize, btnSize);

    // Active Item (above bomb)
    _itemFrame = CGRectMake(_bombFrame.origin.x,
                            _bombFrame.origin.y - btnSize - 16.0,
                            btnSize, btnSize);

    // Card / Pill (top of shoot area, right side)
    _cardFrame = CGRectMake(w - rightMargin - btnSize,
                            _modeToggleFrame.origin.y - btnSize - 10.0,
                            btnSize, btnSize);

    // Drop / Swap (next to card)
    _dropFrame = CGRectMake(_cardFrame.origin.x - btnSize - 12.0,
                            _cardFrame.origin.y,
                            btnSize, btnSize);

    // Map button (top-left)
    _mapFrame = CGRectMake(leftMargin + 10.0, topMargin + 40.0, 44.0, 44.0);

    // Pause button (top-right)
    _pauseFrame = CGRectMake(w - rightMargin - 44.0, topMargin + 40.0, 44.0, 44.0);

    _rightStickAnchor = _shootClusterCenter;
    _rightStickKnob = _shootClusterCenter;
}

- (void)toggleShootMode {
    if (self.shootMode == IVGShootModeButtons) {
        [self setShootMode:IVGShootModeStick];
    } else {
        [self setShootMode:IVGShootModeButtons];
    }
}

- (void)setShootMode:(IVGShootMode)mode {
    _shootMode = mode;
    [NSUserDefaults.standardUserDefaults setInteger:mode forKey:kIVGShootModeDefaultsKey];
    IVGSetShootButtons(NO, NO, NO, NO);
    IVGSetRightStick(0.0f, 0.0f);
    _shootUp = _shootDown = _shootLeft = _shootRight = NO;
    _rightStickActive = NO;
    _rightShootTouch = nil;
    if (self.hapticsEnabled) {
        [_hapticGenerator impactOccurred];
    }
    [self setNeedsDisplay];
}

#pragma mark - Hit Testing

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01 || !IVGIsEnabled()) {
        return nil;
    }

    // Always intercept mode toggle button
    if (CGRectContainsPoint(CGRectInset(_modeToggleFrame, -8, -8), point)) {
        return self;
    }

    // Intercept action buttons
    if (CGRectContainsPoint(CGRectInset(_bombFrame, -6, -6), point) ||
        CGRectContainsPoint(CGRectInset(_itemFrame, -6, -6), point) ||
        CGRectContainsPoint(CGRectInset(_cardFrame, -6, -6), point) ||
        CGRectContainsPoint(CGRectInset(_dropFrame, -6, -6), point) ||
        CGRectContainsPoint(CGRectInset(_mapFrame, -6, -6), point) ||
        CGRectContainsPoint(CGRectInset(_pauseFrame, -6, -6), point)) {
        return self;
    }

    // Left stick zone (bottom-left area of screen)
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    if (point.x < w * 0.44 && point.y > h * 0.22) {
        return self;
    }

    // Right shoot zone (around shoot cluster)
    CGFloat distToShoot = hypot(point.x - _shootClusterCenter.x, point.y - _shootClusterCenter.y);
    if (distToShoot < 110.0) {
        return self;
    }

    // Everywhere else falls through to the game
    return nil;
}

#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];

        // 1. Mode toggle button
        if (CGRectContainsPoint(CGRectInset(_modeToggleFrame, -6, -6), p)) {
            [self toggleShootMode];
            continue;
        }

        // 2. Action buttons
        if (CGRectContainsPoint(CGRectInset(_bombFrame, -6, -6), p) && !_bombTouch) {
            _bombTouch = touch;
            _bombPressed = YES;
            IVGSetButton(IVGButtonLeftTrigger, YES);
            if (self.hapticsEnabled) [_hapticGenerator impactOccurred];
            [self setNeedsDisplay];
            continue;
        }
        if (CGRectContainsPoint(CGRectInset(_itemFrame, -6, -6), p) && !_itemTouch) {
            _itemTouch = touch;
            _itemPressed = YES;
            IVGSetButton(IVGButtonLeftShoulder, YES);
            if (self.hapticsEnabled) [_hapticGenerator impactOccurred];
            [self setNeedsDisplay];
            continue;
        }
        if (CGRectContainsPoint(CGRectInset(_cardFrame, -6, -6), p) && !_cardTouch) {
            _cardTouch = touch;
            _cardPressed = YES;
            IVGSetButton(IVGButtonRightShoulder, YES);
            if (self.hapticsEnabled) [_hapticGenerator impactOccurred];
            [self setNeedsDisplay];
            continue;
        }
        if (CGRectContainsPoint(CGRectInset(_dropFrame, -6, -6), p) && !_dropTouch) {
            _dropTouch = touch;
            _dropPressed = YES;
            IVGSetButton(IVGButtonRightTrigger, YES);
            if (self.hapticsEnabled) [_hapticGenerator impactOccurred];
            [self setNeedsDisplay];
            continue;
        }
        if (CGRectContainsPoint(CGRectInset(_mapFrame, -6, -6), p) && !_mapTouch) {
            _mapTouch = touch;
            _mapPressed = YES;
            IVGSetButton(IVGButtonOptions, YES);
            if (self.hapticsEnabled) [_hapticGenerator impactOccurred];
            [self setNeedsDisplay];
            continue;
        }
        if (CGRectContainsPoint(CGRectInset(_pauseFrame, -6, -6), p) && !_pauseTouch) {
            _pauseTouch = touch;
            _pausePressed = YES;
            IVGSetButton(IVGButtonMenu, YES);
            if (self.hapticsEnabled) [_hapticGenerator impactOccurred];
            [self setNeedsDisplay];
            continue;
        }

        // 3. Left movement stick
        CGFloat w = self.bounds.size.width;
        CGFloat h = self.bounds.size.height;
        if (p.x < w * 0.44 && p.y > h * 0.22 && !_leftStickTouch) {
            _leftStickTouch = touch;
            _leftStickActive = YES;
            _leftStickAnchor = p;
            _leftStickKnob = p;
            IVGSetLeftStick(0.0f, 0.0f);
            [self setNeedsDisplay];
            continue;
        }

        // 4. Right shoot cluster
        CGFloat distToShoot = hypot(p.x - _shootClusterCenter.x, p.y - _shootClusterCenter.y);
        if (distToShoot < 110.0 && !_rightShootTouch) {
            _rightShootTouch = touch;
            if (self.shootMode == IVGShootModeButtons) {
                [self updateShootButtonsForPoint:p isBegan:YES];
            } else {
                _rightStickActive = YES;
                _rightStickAnchor = _shootClusterCenter;
                [self updateShootStickForPoint:p];
            }
            [self setNeedsDisplay];
            continue;
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];

        if (touch == _leftStickTouch) {
            [self updateLeftStickForPoint:p];
            [self setNeedsDisplay];
        } else if (touch == _rightShootTouch) {
            if (self.shootMode == IVGShootModeButtons) {
                [self updateShootButtonsForPoint:p isBegan:NO];
            } else {
                [self updateShootStickForPoint:p];
            }
            [self setNeedsDisplay];
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        if (touch == _leftStickTouch) {
            _leftStickTouch = nil;
            _leftStickActive = NO;
            // Instant release: 0 ms delay!
            IVGSetLeftStick(0.0f, 0.0f);
            [self setNeedsDisplay];
        } else if (touch == _rightShootTouch) {
            _rightShootTouch = nil;
            _rightStickActive = NO;
            // Release firing: trigger attack release for Brimstone/Tech X!
            _shootUp = _shootDown = _shootLeft = _shootRight = NO;
            IVGSetShootButtons(NO, NO, NO, NO);
            IVGSetRightStick(0.0f, 0.0f);
            [self setNeedsDisplay];
        } else if (touch == _bombTouch) {
            _bombTouch = nil;
            _bombPressed = NO;
            IVGSetButton(IVGButtonLeftTrigger, NO);
            [self setNeedsDisplay];
        } else if (touch == _itemTouch) {
            _itemTouch = nil;
            _itemPressed = NO;
            IVGSetButton(IVGButtonLeftShoulder, NO);
            [self setNeedsDisplay];
        } else if (touch == _cardTouch) {
            _cardTouch = nil;
            _cardPressed = NO;
            IVGSetButton(IVGButtonRightShoulder, NO);
            [self setNeedsDisplay];
        } else if (touch == _dropTouch) {
            _dropTouch = nil;
            _dropPressed = NO;
            IVGSetButton(IVGButtonRightTrigger, NO);
            [self setNeedsDisplay];
        } else if (touch == _mapTouch) {
            _mapTouch = nil;
            _mapPressed = NO;
            IVGSetButton(IVGButtonOptions, NO);
            [self setNeedsDisplay];
        } else if (touch == _pauseTouch) {
            _pauseTouch = nil;
            _pausePressed = NO;
            IVGSetButton(IVGButtonMenu, NO);
            [self setNeedsDisplay];
        }
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

#pragma mark - Input Calculation

- (void)updateLeftStickForPoint:(CGPoint)p {
    CGFloat dx = p.x - _leftStickAnchor.x;
    CGFloat dy = p.y - _leftStickAnchor.y;
    CGFloat dist = hypot(dx, dy);

    CGFloat maxRadius = 60.0;
    CGFloat deadzone = 8.0;

    if (dist > maxRadius) {
        dx = (dx / dist) * maxRadius;
        dy = (dy / dist) * maxRadius;
        dist = maxRadius;
    }

    _leftStickKnob = CGPointMake(_leftStickAnchor.x + dx, _leftStickAnchor.y + dy);

    if (dist < deadzone) {
        IVGSetLeftStick(0.0f, 0.0f);
        return;
    }

    CGFloat norm = (dist - deadzone) / (maxRadius - deadzone);
    CGFloat axisX = (dx / dist) * norm;
    CGFloat axisY = -(dy / dist) * norm; // Inverted so up is positive
    IVGSetLeftStick(axisX, axisY);
}

- (void)updateShootButtonsForPoint:(CGPoint)p isBegan:(BOOL)isBegan {
    CGFloat dx = p.x - _shootClusterCenter.x;
    CGFloat dy = p.y - _shootClusterCenter.y;
    CGFloat dist = hypot(dx, dy);

    CGFloat deadzone = 10.0;
    if (dist < deadzone) {
        // Very center: maintain current or do not activate
        return;
    }

    // Calculate angle: in iOS screen coordinates, +X is Right, +Y is Down
    // atan2(dy, dx):
    // Right: ~0
    // Down: ~+PI/2
    // Left: ~+-PI
    // Up: ~-PI/2
    CGFloat angle = atan2(dy, dx); // [-PI, +PI]

    BOOL up = NO;
    BOOL down = NO;
    BOOL left = NO;
    BOOL right = NO;

    if (angle > -M_PI_4 && angle <= M_PI_4) {
        right = YES;
    } else if (angle > M_PI_4 && angle <= 3.0 * M_PI_4) {
        down = YES;
    } else if (angle < -M_PI_4 && angle >= -3.0 * M_PI_4) {
        up = YES;
    } else {
        left = YES;
    }

    BOOL directionChanged = (up != _shootUp || down != _shootDown || left != _shootLeft || right != _shootRight);
    if (directionChanged) {
        _shootUp = up;
        _shootDown = down;
        _shootLeft = left;
        _shootRight = right;

        // Crucial: seamless transition without dropping attack state!
        IVGSetShootButtons(up, down, left, right);

        if (self.hapticsEnabled) {
            [_hapticGenerator impactOccurred];
        }
    }
}

- (void)updateShootStickForPoint:(CGPoint)p {
    CGFloat dx = p.x - _rightStickAnchor.x;
    CGFloat dy = p.y - _rightStickAnchor.y;
    CGFloat dist = hypot(dx, dy);

    CGFloat maxRadius = 60.0;
    CGFloat deadzone = 8.0;

    if (dist > maxRadius) {
        dx = (dx / dist) * maxRadius;
        dy = (dy / dist) * maxRadius;
        dist = maxRadius;
    }

    _rightStickKnob = CGPointMake(_rightStickAnchor.x + dx, _rightStickAnchor.y + dy);

    if (dist < deadzone) {
        IVGSetRightStick(0.0f, 0.0f);
        return;
    }

    CGFloat norm = (dist - deadzone) / (maxRadius - deadzone);
    CGFloat axisX = (dx / dist) * norm;
    CGFloat axisY = -(dy / dist) * norm; // Inverted so up is positive
    IVGSetRightStick(axisX, axisY);
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    if (!IVGIsEnabled()) return;

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGFloat alpha = self.controlsOpacity;

    // 1. Draw Left Stick
    if (_leftStickActive) {
        // Base ring
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.0 alpha:alpha * 0.6].CGColor);
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:alpha * 0.8].CGColor);
        CGContextSetLineWidth(ctx, 2.0);
        CGRect baseRect = CGRectMake(_leftStickAnchor.x - 60.0, _leftStickAnchor.y - 60.0, 120.0, 120.0);
        CGContextFillEllipseInRect(ctx, baseRect);
        CGContextStrokeEllipseInRect(ctx, baseRect);

        // Knob
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.25 green:0.65 blue:1.0 alpha:alpha * 0.9].CGColor);
        CGRect knobRect = CGRectMake(_leftStickKnob.x - 24.0, _leftStickKnob.y - 24.0, 48.0, 48.0);
        CGContextFillEllipseInRect(ctx, knobRect);
        CGContextSetStrokeColorWithColor(ctx, UIColor.whiteColor.CGColor);
        CGContextStrokeEllipseInRect(ctx, knobRect);
    } else {
        // Idle guide circle in bottom-left
        CGFloat guideX = 100.0;
        CGFloat guideY = self.bounds.size.height - 110.0;
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.0 alpha:alpha * 0.25].CGColor);
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:alpha * 0.4].CGColor);
        CGContextSetLineWidth(ctx, 1.5);
        CGRect guideRect = CGRectMake(guideX - 45.0, guideY - 45.0, 90.0, 90.0);
        CGContextFillEllipseInRect(ctx, guideRect);
        CGContextStrokeEllipseInRect(ctx, guideRect);
    }

    // 2. Draw Right Shoot Area
    if (self.shootMode == IVGShootModeButtons) {
        // 4-Button Cross
        CGFloat btnRadius = 26.0;
        CGFloat offset = 44.0;

        CGPoint upCenter = CGPointMake(_shootClusterCenter.x, _shootClusterCenter.y - offset);
        CGPoint downCenter = CGPointMake(_shootClusterCenter.x, _shootClusterCenter.y + offset);
        CGPoint leftCenter = CGPointMake(_shootClusterCenter.x - offset, _shootClusterCenter.y);
        CGPoint rightCenter = CGPointMake(_shootClusterCenter.x + offset, _shootClusterCenter.y);

        [self drawDirectionButton:upCenter radius:btnRadius symbol:@"▲" active:_shootUp alpha:alpha inContext:ctx];
        [self drawDirectionButton:downCenter radius:btnRadius symbol:@"▼" active:_shootDown alpha:alpha inContext:ctx];
        [self drawDirectionButton:leftCenter radius:btnRadius symbol:@"◀" active:_shootLeft alpha:alpha inContext:ctx];
        [self drawDirectionButton:rightCenter radius:btnRadius symbol:@"▶" active:_shootRight alpha:alpha inContext:ctx];
    } else {
        // 360° Analog Shooting Stick
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.0 alpha:alpha * 0.6].CGColor);
        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:alpha * 0.8].CGColor);
        CGContextSetLineWidth(ctx, 2.0);
        CGRect baseRect = CGRectMake(_rightStickAnchor.x - 60.0, _rightStickAnchor.y - 60.0, 120.0, 120.0);
        CGContextFillEllipseInRect(ctx, baseRect);
        CGContextStrokeEllipseInRect(ctx, baseRect);

        // Knob
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:alpha * 0.9].CGColor);
        CGRect knobRect = CGRectMake(_rightStickKnob.x - 24.0, _rightStickKnob.y - 24.0, 48.0, 48.0);
        CGContextFillEllipseInRect(ctx, knobRect);
        CGContextSetStrokeColorWithColor(ctx, UIColor.whiteColor.CGColor);
        CGContextStrokeEllipseInRect(ctx, knobRect);
    }

    // 3. Draw Mode Toggle Button
    [self drawModeToggleButtonInContext:ctx alpha:alpha];

    // 4. Draw Action Buttons
    [self drawRoundButton:_bombFrame symbol:@"💣" active:_bombPressed alpha:alpha inContext:ctx];
    [self drawRoundButton:_itemFrame symbol:@"⚡" active:_itemPressed alpha:alpha inContext:ctx];
    [self drawRoundButton:_cardFrame symbol:@"💊" active:_cardPressed alpha:alpha inContext:ctx];
    [self drawRoundButton:_dropFrame symbol:@"⏬" active:_dropPressed alpha:alpha inContext:ctx];
    [self drawRoundButton:_mapFrame symbol:@"🗺" active:_mapPressed alpha:alpha inContext:ctx];
    [self drawRoundButton:_pauseFrame symbol:@"⏸" active:_pausePressed alpha:alpha inContext:ctx];
}

- (void)drawDirectionButton:(CGPoint)center radius:(CGFloat)radius symbol:(NSString *)symbol active:(BOOL)active alpha:(CGFloat)alpha inContext:(CGContextRef)ctx {
    CGRect rect = CGRectMake(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0);
    UIColor *fill = active
        ? [UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:0.85]
        : [UIColor colorWithWhite:0.0 alpha:alpha * 0.7];
    UIColor *stroke = active
        ? UIColor.whiteColor
        : [UIColor colorWithWhite:1.0 alpha:alpha * 0.75];

    CGContextSetFillColorWithColor(ctx, fill.CGColor);
    CGContextSetStrokeColorWithColor(ctx, stroke.CGColor);
    CGContextSetLineWidth(ctx, active ? 2.5 : 1.5);
    CGContextFillEllipseInRect(ctx, rect);
    CGContextStrokeEllipseInRect(ctx, rect);

    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold],
        NSForegroundColorAttributeName: UIColor.whiteColor
    };
    CGSize strSize = [symbol sizeWithAttributes:attrs];
    CGPoint textPoint = CGPointMake(center.x - strSize.width * 0.5, center.y - strSize.height * 0.5);
    [symbol drawAtPoint:textPoint withAttributes:attrs];
}

- (void)drawRoundButton:(CGRect)rect symbol:(NSString *)symbol active:(BOOL)active alpha:(CGFloat)alpha inContext:(CGContextRef)ctx {
    UIColor *fill = active
        ? [UIColor colorWithRed:0.2 green:0.7 blue:1.0 alpha:0.85]
        : [UIColor colorWithWhite:0.0 alpha:alpha * 0.65];
    UIColor *stroke = active
        ? UIColor.whiteColor
        : [UIColor colorWithWhite:1.0 alpha:alpha * 0.65];

    CGContextSetFillColorWithColor(ctx, fill.CGColor);
    CGContextSetStrokeColorWithColor(ctx, stroke.CGColor);
    CGContextSetLineWidth(ctx, active ? 2.5 : 1.5);
    CGContextFillEllipseInRect(ctx, rect);
    CGContextStrokeEllipseInRect(ctx, rect);

    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:20.0],
        NSForegroundColorAttributeName: UIColor.whiteColor
    };
    CGSize strSize = [symbol sizeWithAttributes:attrs];
    CGPoint textPoint = CGPointMake(CGRectGetMidX(rect) - strSize.width * 0.5,
                                    CGRectGetMidY(rect) - strSize.height * 0.5);
    [symbol drawAtPoint:textPoint withAttributes:attrs];
}

- (void)drawModeToggleButtonInContext:(CGContextRef)ctx alpha:(CGFloat)alpha {
    CGRect rect = _modeToggleFrame;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:14.0];

    BOOL isButtons = (self.shootMode == IVGShootModeButtons);
    UIColor *fill = [UIColor colorWithWhite:0.0 alpha:alpha * 0.8];
    UIColor *stroke = isButtons
        ? [UIColor colorWithRed:0.3 green:0.8 blue:0.4 alpha:0.9]
        : [UIColor colorWithRed:1.0 green:0.6 blue:0.2 alpha:0.9];

    CGContextSetFillColorWithColor(ctx, fill.CGColor);
    CGContextSetStrokeColorWithColor(ctx, stroke.CGColor);
    CGContextSetLineWidth(ctx, 1.5);
    [path fill];
    [path stroke];

    NSString *title = isButtons ? @"✛ 4-WAY" : @"🕹 360°";
    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold],
        NSForegroundColorAttributeName: stroke
    };
    CGSize strSize = [title sizeWithAttributes:attrs];
    CGPoint textPoint = CGPointMake(CGRectGetMidX(rect) - strSize.width * 0.5,
                                    CGRectGetMidY(rect) - strSize.height * 0.5);
    [title drawAtPoint:textPoint withAttributes:attrs];
}

@end

#pragma mark - Global Overlay Lifecycle

static void ICSAttachOverlayToKeyWindow(void) {
    if (!IVGIsEnabled()) {
        [IsaacTouchOverlayView sharedOverlay].hidden = YES;
        return;
    }

    UIWindow *targetWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) { targetWindow = w; break; }
            }
            if (targetWindow) break;
        }
    }
    if (!targetWindow) {
        targetWindow = UIApplication.sharedApplication.keyWindow;
    }
    if (!targetWindow) return;

    IsaacTouchOverlayView *overlay = [IsaacTouchOverlayView sharedOverlay];
    if (overlay.superview != targetWindow) {
        [overlay removeFromSuperview];
        [targetWindow addSubview:overlay];
        [targetWindow bringSubviewToFront:overlay];
    }
    [overlay updateLayoutForWindow:targetWindow];
    ICSUpdateTouchOverlayVisibility();
}

void ICSUpdateTouchOverlayVisibility(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        IsaacTouchOverlayView *overlay = [IsaacTouchOverlayView sharedOverlay];
        if (!IVGIsEnabled()) {
            overlay.hidden = YES;
            return;
        }
        // If game is in menus (title, save select, etc.), hide controls to not clutter
        BOOL inMenu = ICSGameMenuIsActive();
        overlay.hidden = inMenu;
    });
}

void ICSInstallTouchOverlay(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        IVGInstallVirtualGamepad();

        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification
                                                        object:nil
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(__unused NSNotification *note) {
            ICSAttachOverlayToKeyWindow();
        }];

        [NSNotificationCenter.defaultCenter addObserverForName:@"IsaacCloudSyncGameStateChanged"
                                                        object:nil
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(__unused NSNotification *note) {
            ICSAttachOverlayToKeyWindow();
            ICSUpdateTouchOverlayVisibility();
        }];

        [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(__unused NSTimer *timer) {
            ICSAttachOverlayToKeyWindow();
        }];

        dispatch_async(dispatch_get_main_queue(), ^{
            ICSAttachOverlayToKeyWindow();
        });

        NSLog(@"[IsaacTouch] Custom touch overlay system installed");
    });
}
