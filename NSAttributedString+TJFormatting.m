//
//  NSAttributedString+TJFormatting.m
//  OpenerCore
//
//  Created by Tim Johnsen on 2/10/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import "NSAttributedString+TJFormatting.h"

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
            
            // Apply attributes if needed
            [mutableAttributedString enumerateAttributesInRange:result.range
                                                        options:0
                                                     usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attributes, NSRange range, BOOL * _Nonnull stop) {
                NSDictionary *const customizedAttributes = block(parsedTag, attributes);
                if (customizedAttributes.count) {
                    NSMutableDictionary *const mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
                    [mutableAttributes addEntriesFromDictionary:customizedAttributes];
                    [mutableAttributedString replaceCharactersInRange:range
                                                 withAttributedString:[[NSAttributedString alloc] initWithString:[underlyingString substringWithRange:range]
                                                                                                      attributes:mutableAttributes]];
                }
            }];
            
            // Remove enclosing tags
            [mutableAttributedString replaceCharactersInRange:result.range
                                         withAttributedString:[mutableAttributedString attributedSubstringFromRange:[result rangeAtIndex:2]]];
        }
    }];
    
    return mutableAttributedString;
}

@end
