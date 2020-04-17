//
//  NSAttributedString+TJFormatting.m
//  OpenerCore
//
//  Created by Tim Johnsen on 2/10/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import "NSAttributedString+TJFormatting.h"

#import <UIKit/UIKit.h>

TJFormattingCustomizerBlock TJFormattingCommonCustomizerBlock() {
    return ^NSDictionary *(NSString *const tag, NSDictionary<NSAttributedStringKey, id> *attributes) {
        UIFont *const font = attributes[NSFontAttributeName];
        if ([tag isEqualToString:@"b"] || [tag isEqualToString:@"strong"]) {
            for (NSNumber *const fontWeightValue in @[@(UIFontWeightBold),
                                                      @(UIFontWeightHeavy),
                                                      @(UIFontWeightSemibold),
                                                      @(UIFontWeightBlack),
                                                      @(UIFontWeightMedium),]) {
                UIFont *const boldFont = [UIFont fontWithDescriptor:[[font fontDescriptor] fontDescriptorWithSymbolicTraits:fontWeightValue.doubleValue]
                                                               size:font.pointSize];
                if (boldFont) {
                    return @{NSFontAttributeName: boldFont};
                }
            }
        } else if ([tag isEqualToString:@"i"] || [tag isEqualToString:@"em"]) {
            UIFont *const italicFont = [UIFont fontWithDescriptor:[[font fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic]
                                                             size:font.pointSize];
            if (italicFont) {
                return @{NSFontAttributeName: italicFont};
            }
        } else if ([tag isEqualToString:@"u"]) {
            return @{NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)};
        } else if ([tag isEqualToString:@"s"] || [tag isEqualToString:@"del"]) {
            return @{NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle)};
        } else if ([tag isEqualToString:@"code"]) {
            UIFont *const monospaceFont = [UIFont fontWithDescriptor:[[font fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitMonoSpace]
                                                                size:font.pointSize];
            if (monospaceFont) {
                return @{NSFontAttributeName: monospaceFont};
            }
        } else {
            NSURL *const url = [NSURL URLWithString:tag];
            if (url) {
                return @{NSLinkAttributeName: url};
            }
        }
        return nil;
    };
}

@implementation NSAttributedString (TJFormatting)

+ (instancetype)attributedStringWithMarkupString:(NSString *const)markupString
                                      attributes:(NSDictionary *const)attributes
                                 customizerBlock:(TJFormattingCustomizerBlock)block
{
    return [self attributedStringWithMarkupString:markupString
                                   supportNesting:YES
                                       attributes:attributes
                                  customizerBlock:block];
}

+ (instancetype)attributedStringWithMarkupString:(NSString *const)markupString
                                  supportNesting:(const BOOL)supportNesting
                                      attributes:(NSDictionary *const)attributes
                                 customizerBlock:(TJFormattingCustomizerBlock)block
{
#define regexesForTagsTypes NSString *, NSRegularExpression *
    NSDictionary<regexesForTagsTypes> *regexesForTags;
    if (supportNesting) {
        static NSRegularExpression *tagRegex;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            tagRegex = [NSRegularExpression regularExpressionWithPattern:@"</(.*?)>" options:0 error:nil];
        });
        
        regexesForTags = [NSMutableDictionary new];
        for (NSTextCheckingResult *const result in [tagRegex matchesInString:markupString options:0 range:NSMakeRange(0, markupString.length)]) {
            NSString *const tag = [markupString substringWithRange:[result rangeAtIndex:1]];
            if (![regexesForTags objectForKey:tag]) {
                NSString *const escapedTag = [NSRegularExpression escapedPatternForString:tag];
                NSRegularExpression *const regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"<(%1$@)>(.*?)</(%1$@)>", escapedTag] options:0 error:nil];
                NSAssert(regex, @"Unable to form regex for tag %@", tag);
                [(NSMutableDictionary<regexesForTagsTypes> *)regexesForTags setObject:regex forKey:tag];
            }
        }
    } else {
        static NSDictionary<NSString *, NSRegularExpression *> *genericRegexesForTags;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            genericRegexesForTags = @{@"": [NSRegularExpression regularExpressionWithPattern:@"<(.*?)>(.*?)</(.*?)>" options:0 error:nil]}; // The key is ignored in this case, "parsedTag" is populated in the loop below.
        });
        regexesForTags = genericRegexesForTags;
    }
    
    NSMutableAttributedString *const mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:markupString attributes:attributes];
    [regexesForTags enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull tag, NSRegularExpression * _Nonnull regex, BOOL * _Nonnull stop) {
        NSString *const underlyingString = mutableAttributedString.string;
        for (NSTextCheckingResult *const result in [[regex matchesInString:underlyingString options:0 range:NSMakeRange(0, underlyingString.length)] reverseObjectEnumerator]) {
            NSString *const parsedTag = supportNesting ? tag : [underlyingString substringWithRange:[result rangeAtIndex:1]];
            NSAssert([[underlyingString substringWithRange:[result rangeAtIndex:3]] isEqualToString:parsedTag], @"Mismatching tags! %@ - %@", parsedTag, [underlyingString substringWithRange:[result rangeAtIndex:3]]);
            const NSRange textRange = [result rangeAtIndex:2];
            const NSRange fullRange = result.range;
            if (supportNesting) {
                // Apply attributes if needed
                [mutableAttributedString enumerateAttributesInRange:textRange
                                                            options:0
                                                         usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull subrangeAttributes, NSRange subrange, BOOL * _Nonnull stop) {
                    NSDictionary *const customizedAttributes = block(parsedTag, subrangeAttributes);
                    if (customizedAttributes.count) {
                        NSMutableDictionary *const mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:subrangeAttributes];
                        [mutableAttributes addEntriesFromDictionary:customizedAttributes];
                        [mutableAttributedString replaceCharactersInRange:subrange
                                                     withAttributedString:[[NSAttributedString alloc] initWithString:[underlyingString substringWithRange:subrange]
                                                                                                          attributes:mutableAttributes]];
                    }
                }];
                
                // Remove enclosing tags
                [mutableAttributedString replaceCharactersInRange:fullRange
                                             withAttributedString:[mutableAttributedString attributedSubstringFromRange:textRange]];
            } else {
                NSString *const text = [underlyingString substringWithRange:textRange];
                NSDictionary *const customizedAttributes = block(parsedTag, attributes);
                if (customizedAttributes.count) {
                    // Apply attributes if needed
                    NSMutableDictionary *const mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
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
    }];
    
    return mutableAttributedString;
}

@end
