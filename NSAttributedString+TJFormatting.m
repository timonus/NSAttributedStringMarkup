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
    NSSet<NSString *> *tags = nil;
    if (supportNesting) {
        static NSRegularExpression *tagRegex;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            tagRegex = [NSRegularExpression regularExpressionWithPattern:@"</?(.*?)>" options:0 error:nil];
        });
        
        NSMutableSet<NSString *> *const mutableTags = [NSMutableSet new];
        for (NSTextCheckingResult *const result in [tagRegex matchesInString:markupString options:0 range:NSMakeRange(0, markupString.length)]) {
            [mutableTags addObject:[markupString substringWithRange:[result rangeAtIndex:1]]];
        }
        tags = mutableTags;
    } else {
        tags = [NSSet setWithObject:@".*?"];
    }
    
    NSMutableAttributedString *const mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:markupString attributes:attributes];
    for (NSString *const tag in tags) {
        NSString *const escapedTag = supportNesting ? [NSRegularExpression escapedPatternForString:tag] : tag;
        NSRegularExpression *const regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"<(%1$@)>(.*?)</(%1$@)>", escapedTag] options:0 error:nil];
        NSAssert(regex, @"Unable to form regex");
        NSString *const underlyingString = mutableAttributedString.string;
        for (NSTextCheckingResult *const result in [[regex matchesInString:underlyingString options:0 range:NSMakeRange(0, underlyingString.length)] reverseObjectEnumerator]) {
            NSString *const parsedTag = supportNesting ? tag : [underlyingString substringWithRange:[result rangeAtIndex:1]];
            NSAssert([[underlyingString substringWithRange:[result rangeAtIndex:3]] isEqualToString:parsedTag], @"Mismatching tags! %@ - %@", parsedTag, [underlyingString substringWithRange:[result rangeAtIndex:3]]);
            NSDictionary *const customizedAttributes = block(parsedTag);
            NSDictionary *rangeAttributes;
            if (customizedAttributes.count > 0) {
                NSMutableDictionary *const mutableAttributes = [NSMutableDictionary dictionaryWithDictionary:[mutableAttributedString attributesAtIndex:result.range.location effectiveRange:nil]];
                [mutableAttributes addEntriesFromDictionary:customizedAttributes];
                rangeAttributes = mutableAttributes;
            } else {
                rangeAttributes = attributes;
            }
            NSString *const text = [underlyingString substringWithRange:[result rangeAtIndex:2]];
            [mutableAttributedString replaceCharactersInRange:result.range
                                         withAttributedString:[[NSAttributedString alloc] initWithString:text attributes:rangeAttributes]];
        }
    }
    
    return mutableAttributedString;
}

@end
