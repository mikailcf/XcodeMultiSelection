//
//  MultiSelection.h
//  MultiSelection
//
//  Created by Mikail Freitas on 24/09/15.
//  Copyright © 2015 allmine. All rights reserved.
//

#import <AppKit/AppKit.h>

@class MultiSelection;

static MultiSelection *sharedPlugin;

@interface MultiSelection : NSObject <NSTextViewDelegate>

+ (instancetype)sharedPlugin;
- (id)initWithBundle:(NSBundle *)plugin;

@property (nonatomic, strong, readonly) NSBundle* bundle;
@end