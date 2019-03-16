# NSAttributedStringMarkup

This is a simple utility for turning strings containing markup into `NSAttributedString`s.

## Why?

Building `NSAttributedString`s can be cumbersome, often involving constructing and concatenating a bunch of small strings together in a way that's hard to parse. For example

```objc
NSMutableAttributedString *const string = [NSMutableAttributedString new];
NSDictionary *const textAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:18.0]};
NSDictionary *const boldTextAttributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0]};
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"Here's to the " attributes:textAttributes]];
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"crazy ones.\n" attributes:boldTextAttributes]];
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"The " attributes:textAttributes]];
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"misfits.\n" attributes:boldTextAttributes]];
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"The " attributes:textAttributes]];
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"troublemakers.\n" attributes:boldTextAttributes]];
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"The " attributes:textAttributes]];
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"round pegs" attributes:boldTextAttributes]];
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"in the " attributes:textAttributes]];
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"square holes.\n\n" attributes:boldTextAttributes]];
NSDictionary *const byLineTextAttributes = @{NSFontAttributeName: [UIFont italicSystemFontOfSize:16.0], NSForegroundColorAttributeName: [UIColor grayColor]};
[string appendAttributedString:[[NSAttributedString alloc] initWithString:@"‒ Steve Jobs" attributes:byLineTextAttributes]];
```

Concatenation isn't great for localization since other languages often order things differently.

## How?

This library lets you convert plain strings into attributed strings using arbitrary markup and styling of your choosing. To recreate the above text you'd do something like the following.

```objc
NSString *const markupString = @"Here's to the <b>crazy ones</b>.\nThe <b>misfits</b>.\nThe <b>troublemakers</b>.\nThe <b>round pegs</b> in the <b>square holes</b>.\n\n<i>‒ Steve Jobs</i>";
NSDictionary *const textAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:18.0]};
NSAttributedString *const string = [NSAttributedString attributedStringWithMarkupString:markupString
                                                                             attributes:textAttributes
                                                                        customizerBlock:^NSDictionary *(NSString *tag) {
                                                                            if ([tag isEqualToString:@"b"]) {
                                                                                return @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0]};
                                                                            } else if ([tag isEqualToString:@"i"]) {
                                                                                @{NSFontAttributeName: [UIFont italicSystemFontOfSize:16.0],
                                                                                  NSForegroundColorAttributeName: [UIColor grayColor]};
                                                                            }
                                                                            return nil;
                                                                        }];
```

The `attributes` text attributes are applied to the string passed in. The customization block is called for each `<...>`/`</...>` markup tag identified in the string and the attributes you return from that block are applied on top of the span enclosed in that tag. Simple as that!

## Little Things

By default this method handles nested pairs of tags, but this has some small performance drawbacks. If you know your markup won't contain any nested tags and you're concerned about performance you can use the variant of the method that includes the `supportNesting:` param and pass `NO`.

### About

I built this when localizing [Opener](https://itunes.apple.com/app/id989565871) last year, and I've since used it in [Burst](https://itunes.apple.com/app/id1355171732) as well. I find this to be a pretty sensible, uncomplicated way of building attributed strings. Hope you find it useful!