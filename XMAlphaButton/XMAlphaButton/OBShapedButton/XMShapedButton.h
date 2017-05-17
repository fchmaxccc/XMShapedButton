/*
 借鉴了Begemann的程序 OBShapedButton
 实现了一个几个button重叠，点击混乱的问题，（重叠部分是透明的）
 现在将透明区域点击失效，这样做到button互相不干扰。
 */

/*
 XMShapedButton.m
 XM
 */


#import <UIKit/UIKit.h>

// -[UIView hitTest:withEvent: ignores views that an alpha level less than 0.1.
// So we will do the same and treat pixels with alpha < 0.1 as transparent.
#define kAlphaVisibleThreshold (0.1f)

@interface XMShapedButton : UIButton

// Class interface is empty. XMShapedButton does not add new public methods.

@end
