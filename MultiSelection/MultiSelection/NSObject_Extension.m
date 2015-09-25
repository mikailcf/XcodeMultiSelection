//
//  NSObject_Extension.m
//  MultiSelection
//
//  Created by Mikail Freitas on 24/09/15.
//  Copyright © 2015 allmine. All rights reserved.
//


#import "NSObject_Extension.h"
#import "MultiSelection.h"

@implementation NSObject (Xcode_Plugin_Template_Extension)

+ (void)pluginDidLoad:(NSBundle *)plugin
{
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[MultiSelection alloc] initWithBundle:plugin];
        });
    }
}
@end
