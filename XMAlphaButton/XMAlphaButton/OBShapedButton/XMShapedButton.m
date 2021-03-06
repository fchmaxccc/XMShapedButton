/*
 借鉴了Begemann的程序 OBShapedButton
 实现了一个几个button重叠，点击混乱的问题，（重叠部分是透明的）
 现在将透明区域点击失效，这样做到button互相不干扰。
 */

/*
 XMShapedButton.m
 XM
 */


#import "XMShapedButton.h"
#import "UIImage+ColorAtPixel.h"


@interface UIImageView (PointConversionCategory)

@property (nonatomic, readonly) CGAffineTransform viewToImageTransform;
@property (nonatomic, readonly) CGAffineTransform imageToViewTransform;

@end

@implementation UIImageView (PointConversionCategory)

-(CGAffineTransform) viewToImageTransform {
    
    UIViewContentMode contentMode = self.contentMode;
    
    // failure conditions. If any of these are met – return the identity transform
    if (!self.image || self.frame.size.width == 0 || self.frame.size.height == 0 ||
        (contentMode != UIViewContentModeScaleToFill && contentMode != UIViewContentModeScaleAspectFill && contentMode != UIViewContentModeScaleAspectFit)) {
        return CGAffineTransformIdentity;
    }
    
    // the width and height ratios
    CGFloat rWidth = self.image.size.width/self.frame.size.width;
    CGFloat rHeight = self.image.size.height/self.frame.size.height;
    
    // whether the image will be scaled according to width
    BOOL imageWiderThanView = rWidth > rHeight;
    
    if (contentMode == UIViewContentModeScaleAspectFit || contentMode == UIViewContentModeScaleAspectFill) {
        
        // The ratio to scale both the x and y axis by
        CGFloat ratio = ((imageWiderThanView && contentMode == UIViewContentModeScaleAspectFit) || (!imageWiderThanView && contentMode == UIViewContentModeScaleAspectFill)) ? rWidth:rHeight;
        
        // The x-offset of the inner rect as it gets centered
        CGFloat xOffset = (self.image.size.width-(self.frame.size.width*ratio))*0.5;
        
        // The y-offset of the inner rect as it gets centered
        CGFloat yOffset = (self.image.size.height-(self.frame.size.height*ratio))*0.5;
        
        return CGAffineTransformConcat(CGAffineTransformMakeScale(ratio, ratio), CGAffineTransformMakeTranslation(xOffset, yOffset));
    } else {
        return CGAffineTransformMakeScale(rWidth, rHeight);
    }
}

-(CGAffineTransform) imageToViewTransform {
    return CGAffineTransformInvert(self.viewToImageTransform);
}

@end




@interface XMShapedButton ()

@property (nonatomic, assign) CGPoint previousTouchPoint;
@property (nonatomic, assign) BOOL previousTouchHitTestResponse;
@property (nonatomic, strong) UIImage *buttonImage;
@property (nonatomic, strong) UIImage *buttonBackground;

- (void)updateImageCacheForCurrentState;
- (void)resetHitTestCache;

@end


@implementation XMShapedButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setup];
}

- (void)setup
{
    [self updateImageCacheForCurrentState];
    [self resetHitTestCache];
}

#pragma mark - Hit testing

- (BOOL)isAlphaVisibleAtPoint:(CGPoint)point forImage:(UIImage *)image
{
    // Correction for image scaling including contentmode
    CGPoint pt = CGPointApplyAffineTransform(point, self.imageView.viewToImageTransform);
    point = pt;
    

    UIColor *pixelColor = [image colorAtPixel:point];
    CGFloat alpha = 0.0;
    
    if ([pixelColor respondsToSelector:@selector(getRed:green:blue:alpha:)])
    {
        // available from iOS 5.0
        [pixelColor getRed:NULL green:NULL blue:NULL alpha:&alpha];
    }
    else
    {
        // for iOS < 5.0
        // In iOS 6.1 this code is not working in release mode, it works only in debug
        // CGColorGetAlpha always return 0.
        CGColorRef cgPixelColor = [pixelColor CGColor];
        alpha = CGColorGetAlpha(cgPixelColor);
    }
    return alpha >= kAlphaVisibleThreshold;
}


// UIView uses this method in hitTest:withEvent: to determine which subview should receive a touch event.
// If pointInside:withEvent: returns YES, then the subview’s hierarchy is traversed; otherwise, its branch
// of the view hierarchy is ignored.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event 
{
    // Return NO if even super returns NO (i.e., if point lies outside our bounds)
    BOOL superResult = [super pointInside:point withEvent:event];
    if (!superResult) {
        return superResult;
    }

    // Don't check again if we just queried the same point
    // (because pointInside:withEvent: gets often called multiple times)
    if (CGPointEqualToPoint(point, self.previousTouchPoint)) {
        return self.previousTouchHitTestResponse;
    } else {
        self.previousTouchPoint = point;
    }

    BOOL response = NO;
    
    if (self.buttonImage == nil && self.buttonBackground == nil) {
        response = YES;
    }
    else if (self.buttonImage != nil && self.buttonBackground == nil) {
        response = [self isAlphaVisibleAtPoint:point forImage:self.buttonImage];
    }
    else if (self.buttonImage == nil && self.buttonBackground != nil) {
        response = [self isAlphaVisibleAtPoint:point forImage:self.buttonBackground];
    }
    else {
        if ([self isAlphaVisibleAtPoint:point forImage:self.buttonImage]) {
            response = YES;
        } else {
            response = [self isAlphaVisibleAtPoint:point forImage:self.buttonBackground];
        }
    }
    
    self.previousTouchHitTestResponse = response;
    return response;
}


#pragma mark - Accessors

// Reset the Hit Test Cache when a new image is assigned to the button
- (void)setImage:(UIImage *)image forState:(UIControlState)state
{
    [super setImage:image forState:state];
    [self updateImageCacheForCurrentState];
    [self resetHitTestCache];
}

- (void)setBackgroundImage:(UIImage *)image forState:(UIControlState)state
{
    [super setBackgroundImage:image forState:state];
    [self updateImageCacheForCurrentState];
    [self resetHitTestCache];
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    [self updateImageCacheForCurrentState];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self updateImageCacheForCurrentState];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self updateImageCacheForCurrentState];
}


#pragma mark - Helper methods

- (void)updateImageCacheForCurrentState
{
    _buttonBackground = [self currentBackgroundImage];
    _buttonImage = [self currentImage];
}

- (void)resetHitTestCache
{
    self.previousTouchPoint = CGPointMake(CGFLOAT_MIN, CGFLOAT_MIN);
    self.previousTouchHitTestResponse = NO;
}

@end
