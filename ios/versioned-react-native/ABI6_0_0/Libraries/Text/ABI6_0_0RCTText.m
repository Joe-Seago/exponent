/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI6_0_0RCTText.h"

#import "ABI6_0_0RCTShadowText.h"
#import "ABI6_0_0RCTUtils.h"
#import "UIView+ReactABI6_0_0.h"

static void collectNonTextDescendants(ABI6_0_0RCTText *view, NSMutableArray *nonTextDescendants)
{
  for (UIView *child in view.ReactABI6_0_0Subviews) {
    if ([child isKindOfClass:[ABI6_0_0RCTText class]]) {
      collectNonTextDescendants((ABI6_0_0RCTText *)child, nonTextDescendants);
    } else {
      [nonTextDescendants addObject:child];
    }
  }
}

@implementation ABI6_0_0RCTText
{
  NSTextStorage *_textStorage;
  NSMutableArray<UIView *> *_ReactABI6_0_0Subviews;
  CAShapeLayer *_highlightLayer;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    _textStorage = [NSTextStorage new];
    _ReactABI6_0_0Subviews = [NSMutableArray array];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits |= UIAccessibilityTraitStaticText;

    self.opaque = NO;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (NSString *)description
{
  NSString *superDescription = super.description;
  NSRange semicolonRange = [superDescription rangeOfString:@";"];
  NSString *replacement = [NSString stringWithFormat:@"; ReactABI6_0_0Tag: %@; text: %@", self.ReactABI6_0_0Tag, self.textStorage.string];
  return [superDescription stringByReplacingCharactersInRange:semicolonRange withString:replacement];
}

- (void)ReactABI6_0_0SetFrame:(CGRect)frame
{
  // Text looks super weird if its frame is animated.
  // This disables the frame animation, without affecting opacity, etc.
  [UIView performWithoutAnimation:^{
    [super ReactABI6_0_0SetFrame:frame];
  }];
}

- (void)ReactABI6_0_0SetInheritedBackgroundColor:(UIColor *)inheritedBackgroundColor
{
  self.backgroundColor = inheritedBackgroundColor;
}

- (void)insertReactABI6_0_0Subview:(UIView *)subview atIndex:(NSInteger)atIndex
{
  [_ReactABI6_0_0Subviews insertObject:subview atIndex:atIndex];
}

- (void)removeReactABI6_0_0Subview:(UIView *)subview
{
  [_ReactABI6_0_0Subviews removeObject:subview];
}

- (NSArray<UIView *> *)ReactABI6_0_0Subviews
{
  return _ReactABI6_0_0Subviews;
}

- (void)setTextStorage:(NSTextStorage *)textStorage
{
  if (_textStorage != textStorage) {
    _textStorage = textStorage;
    [self setNeedsDisplay];
  }
}

- (void)drawRect:(CGRect)rect
{
  NSLayoutManager *layoutManager = _textStorage.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;
  CGRect textFrame = UIEdgeInsetsInsetRect(self.bounds, _contentInset);
  NSRange glyphRange = [layoutManager glyphRangeForTextContainer:textContainer];

  [layoutManager drawBackgroundForGlyphRange:glyphRange atPoint:textFrame.origin];
  [layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:textFrame.origin];

  __block UIBezierPath *highlightPath = nil;
  NSRange characterRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
  [layoutManager.textStorage enumerateAttribute:ABI6_0_0RCTIsHighlightedAttributeName inRange:characterRange options:0 usingBlock:^(NSNumber *value, NSRange range, BOOL *_) {
    if (!value.boolValue) {
      return;
    }

    [layoutManager enumerateEnclosingRectsForGlyphRange:range withinSelectedGlyphRange:range inTextContainer:textContainer usingBlock:^(CGRect enclosingRect, __unused BOOL *__) {
      UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(enclosingRect, -2, -2) cornerRadius:2];
      if (highlightPath) {
        [highlightPath appendPath:path];
      } else {
        highlightPath = path;
      }
    }];
  }];

  if (highlightPath) {
    if (!_highlightLayer) {
      _highlightLayer = [CAShapeLayer layer];
      _highlightLayer.fillColor = [UIColor colorWithWhite:0 alpha:0.25].CGColor;
      [self.layer addSublayer:_highlightLayer];
    }
    _highlightLayer.position = (CGPoint){_contentInset.left, _contentInset.top};
    _highlightLayer.path = highlightPath.CGPath;
  } else {
    [_highlightLayer removeFromSuperlayer];
    _highlightLayer = nil;
  }

  for (UIView *child in [self subviews]) {
    [child removeFromSuperview];
  }
  NSMutableArray *nonTextDescendants = [NSMutableArray new];
  collectNonTextDescendants(self, nonTextDescendants);
  for (UIView *child in nonTextDescendants) {
    [self addSubview:child];
  }
}

- (NSNumber *)ReactABI6_0_0TagAtPoint:(CGPoint)point
{
  NSNumber *ReactABI6_0_0Tag = self.ReactABI6_0_0Tag;

  CGFloat fraction;
  NSLayoutManager *layoutManager = _textStorage.layoutManagers.firstObject;
  NSTextContainer *textContainer = layoutManager.textContainers.firstObject;
  NSUInteger characterIndex = [layoutManager characterIndexForPoint:point
                                                    inTextContainer:textContainer
                           fractionOfDistanceBetweenInsertionPoints:&fraction];

  // If the point is not before (fraction == 0.0) the first character and not
  // after (fraction == 1.0) the last character, then the attribute is valid.
  if (_textStorage.length > 0 && (fraction > 0 || characterIndex > 0) && (fraction < 1 || characterIndex < _textStorage.length - 1)) {
    ReactABI6_0_0Tag = [_textStorage attribute:ABI6_0_0RCTReactABI6_0_0TagAttributeName atIndex:characterIndex effectiveRange:NULL];
  }
  return ReactABI6_0_0Tag;
}


- (void)didMoveToWindow
{
  [super didMoveToWindow];

  if (!self.window) {
    self.layer.contents = nil;
    if (_highlightLayer) {
      [_highlightLayer removeFromSuperlayer];
      _highlightLayer = nil;
    }
  } else if (_textStorage.length) {
    [self setNeedsDisplay];
  }
}

#pragma mark - Accessibility

- (NSString *)accessibilityLabel
{
  return _textStorage.string;
}

@end
