//
//  NSAttributedString+TJFormatting.h
//  OpenerCore
//
//  Created by Tim Johnsen on 2/10/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSDictionary<NSAttributedStringKey, id> *_Nullable (^TJFormattingCustomizerBlock)(NSString *const tag, NSDictionary<NSAttributedStringKey, id> *attributes);
@interface NSAttributedString (TJFormatting)

/**
 Used for creating @c NSAttributedStrings using lightweight HTML-like formatting.
 @param markupString An NSString containing HTML-like markup. For example "<b>Hello</b> world, how are <i>you</i> today!"
 @param attributes An dictionary of default NSAttributedString attributes that are applied to the whole string.
 @param customizerBlock A block that's called for each markup tag that's detected. Returns a dictionary of NSAttributedString attributes to apply to the span of text within the tag.
 @note This method supports nested tags by default, you can use the method below with @c supportNesting set to @c NO as an optional perf optimization if your input doesn't contain nested tags.
 */
+ (nullable instancetype)attributedStringWithMarkupString:(nullable NSString *const)markupString
                                               attributes:(nullable NSDictionary<NSAttributedStringKey, id> *const)attributes
                                          customizerBlock:(TJFormattingCustomizerBlock)customizerBlock;

+ (nullable instancetype)attributedStringWithMarkupString:(nullable NSString *const)markupString
                                           supportNesting:(const BOOL)supportNesting
                                               attributes:(nullable NSDictionary<NSAttributedStringKey, id> *const)attributes
                                          customizerBlock:(TJFormattingCustomizerBlock)block;

@end

NS_ASSUME_NONNULL_END
