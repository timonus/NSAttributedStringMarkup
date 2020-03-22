//
//  NSAttributedString+TJFormatting.m
//  OpenerCore
//
//  Created by Tim Johnsen on 2/10/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import "NSAttributedString+TJFormatting.h"

static void _processMarkupInMutableAttributedString(NSString *const markupString,
                                                    NSMutableAttributedString *const mutableAttributedString,
                                                    NSDictionary *(^block)(NSString *tag),
                                                    const BOOL supportNesting)
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
                NSCAssert(regex, @"Unable to form regex for tag %@", tag);
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
    
    [regexesForTags enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull tag, NSRegularExpression * _Nonnull regex, BOOL * _Nonnull stop) {
        NSString *const underlyingString = mutableAttributedString.string;
        for (NSTextCheckingResult *const result in [[regex matchesInString:underlyingString options:0 range:NSMakeRange(0, underlyingString.length)] reverseObjectEnumerator]) {
            NSString *const parsedTag = supportNesting ? tag : [underlyingString substringWithRange:[result rangeAtIndex:1]];
            NSCAssert([[underlyingString substringWithRange:[result rangeAtIndex:3]] isEqualToString:parsedTag], @"Mismatching tags! %@ - %@", parsedTag, [underlyingString substringWithRange:[result rangeAtIndex:3]]);
            NSDictionary *const customizedAttributes = block(parsedTag);
            
            // Apply attributes if needed
            if (customizedAttributes.count > 0) {
                [mutableAttributedString enumerateAttributesInRange:result.range
                                                            options:0
                                                         usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attributes, NSRange range, BOOL * _Nonnull stop) {
                    NSMutableDictionary *const mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
                    [mutableAttributes addEntriesFromDictionary:customizedAttributes];
                    [mutableAttributedString replaceCharactersInRange:range
                                                 withAttributedString:[[NSAttributedString alloc] initWithString:[underlyingString substringWithRange:range]
                                                                                                      attributes:mutableAttributes]];
                }];
            }
            
            // Remove enclosing tags
            [mutableAttributedString replaceCharactersInRange:result.range
                                         withAttributedString:[mutableAttributedString attributedSubstringFromRange:[result rangeAtIndex:2]]];
        }
    }];
}

@implementation NSAttributedString (TJFormatting)

+ (instancetype)attributedStringWithMarkupString:(NSString *const)markupString
                                      attributes:(NSDictionary *const)attributes
                                 customizerBlock:(NSDictionary *(^)(NSString *tag))block
{
    return [self attributedStringWithMarkupString:markupString
                                   supportNesting:YES
                                       attributes:attributes
                                  customizerBlock:block];
}

+ (instancetype)attributedStringWithMarkupString:(NSString *const)markupString
                                  supportNesting:(const BOOL)supportNesting
                                      attributes:(NSDictionary *const)attributes
                                 customizerBlock:(NSDictionary *(^)(NSString *tag))block
{
    NSMutableAttributedString *const mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:markupString attributes:attributes];
    _processMarkupInMutableAttributedString(markupString,
                                            mutableAttributedString,
                                            block,
                                            supportNesting);
    return mutableAttributedString;
}

@end

@implementation NSMutableAttributedString (TJFormatting)

- (void)processMarkupWithCustomizerBlock:(NSDictionary *_Nullable(^)(NSString *tag))block
                          supportNesting:(const BOOL)supportNesting
{
    _processMarkupInMutableAttributedString(self.string,
                                            self,
                                            block,
                                            supportNesting);
}

@end
