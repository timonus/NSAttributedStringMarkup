//
//  NSAttributedString+TJFormatting.m
//  OpenerCore
//
//  Created by Tim Johnsen on 2/10/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import "NSAttributedString+TJFormatting.h"

#if defined(__has_attribute) && __has_attribute(objc_direct_members)
__attribute__((objc_direct_members))
#endif
@implementation NSAttributedString (TJFormatting)

+ (instancetype)attributedStringWithMarkupString:(NSString *const)markupString
                                      attributes:(nullable NSDictionary<NSAttributedStringKey,id> *const)attributes
                                 customizerBlock:(TJFormattingCustomizerBlock)block
{
    return [self attributedStringWithMarkupString:markupString
                                   supportNesting:YES
                                       attributes:attributes
                                  customizerBlock:block];
}

+ (instancetype)attributedStringWithMarkupString:(NSString *const)markupString
                                  supportNesting:(const BOOL)supportNesting
                                      attributes:(NSDictionary<NSAttributedStringKey,id> *const)attributes
                                 customizerBlock:(TJFormattingCustomizerBlock)block
{
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"<(.*?)>(.*?)</\\1>" options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    });
    
    NSMutableAttributedString *const mutableAttributedString = (markupString != nil) ? [[NSMutableAttributedString alloc] initWithString:markupString attributes:attributes] : nil;
    BOOL continueLooping;
    do {
        NSString *const underlyingString = mutableAttributedString.string;
        const NSUInteger underlyingStringLength = underlyingString.length;
        if (!underlyingStringLength) {
            break;
        }
        continueLooping = NO;
        for (NSTextCheckingResult *const result in [[regex matchesInString:underlyingString options:0 range:NSMakeRange(0, underlyingStringLength)] reverseObjectEnumerator]) {
            NSString *const parsedTag = [underlyingString substringWithRange:[result rangeAtIndex:1]];
            const NSRange textRange = [result rangeAtIndex:2];
            const NSRange fullRange = result.range;
            if (supportNesting) {
                // Apply attributes if needed
                [mutableAttributedString enumerateAttributesInRange:textRange
                                                            options:0
                                                         usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull subrangeAttributes, NSRange subrange, BOOL * _Nonnull stop) {
                    NSDictionary *const customizedAttributes = block(parsedTag, subrangeAttributes);
                    if (customizedAttributes.count) {
                        [mutableAttributedString addAttributes:customizedAttributes range:subrange];
                    }
                }];
                
                // Remove enclosing tags
                [mutableAttributedString replaceCharactersInRange:fullRange
                                             withAttributedString:[mutableAttributedString attributedSubstringFromRange:textRange]];
                
                // If tags were found we might've not exhaused all inner nested ones, so loop once again.
                continueLooping = YES;
            } else {
                NSString *const text = [underlyingString substringWithRange:textRange];
                NSDictionary<NSAttributedStringKey, id> *const customizedAttributes = block(parsedTag, attributes);
                if (customizedAttributes.count) {
                    // Apply attributes if needed
                    NSMutableDictionary<NSAttributedStringKey, id> *const mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
                    [mutableAttributes addEntriesFromDictionary:customizedAttributes];
                    [mutableAttributedString replaceCharactersInRange:fullRange
                                                 withAttributedString:[[NSAttributedString alloc] initWithString:text attributes:mutableAttributes]];
                } else {
                    // Otherwise just remove enclosing tags
                    [mutableAttributedString replaceCharactersInRange:fullRange
                                                           withString:text];
                }
            }
        }
    } while(continueLooping);
    
    return [[self alloc] initWithAttributedString:mutableAttributedString];
}

@end
