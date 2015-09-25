//
//  MultiSelection.m
//  MultiSelection
//
//  Created by Mikail Freitas on 24/09/15.
//  Copyright © 2015 allmine. All rights reserved.
//

#import "MultiSelection.h"

@interface MultiSelection()

@property (nonatomic, strong, readwrite) NSBundle *bundle;
@property (nonatomic, strong) NSMutableSet *notificationSet;
@property (nonatomic, strong) NSMutableArray *selections;
@property (nonatomic, strong) NSMutableArray *selectionRanges;
@property (nonatomic, unsafe_unretained) NSTextView *sourceTextView;
@property (nonatomic, strong) NSColor *highlightColor;
@property (nonatomic,copy) NSString *selectedText;
@property (nonatomic) BOOL isInserting;
@property (nonatomic) BOOL shouldDelete;
@property (nonatomic) NSUInteger oldLength;

@end

@implementation MultiSelection

+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin {
    if(self = [super init]){
        self.bundle = plugin;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didApplicationFinishLaunchingNotification:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(selectionDidChange:)
                                                     name:NSTextViewDidChangeSelectionNotification
                                                   object:nil];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(textDidChange:)
                                                     name:NSTextDidChangeNotification
                                                   object:nil];
        
        self.notificationSet = [NSMutableSet new];
        self.highlightColor = [NSColor colorWithWhite:1.0 alpha:0.2];
        self.isInserting = NO;
        self.shouldDelete = NO;
        self.oldLength = 0;
    }
    return self;
}

- (void)didApplicationFinishLaunchingNotification:(NSNotification*)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidFinishLaunchingNotification object:nil];
    
    NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
    
    if (menuItem) {
        [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
        
        unichar arrowKey = NSF10FunctionKey;
        
        NSMenuItem *selectNextInstanceItem = [[NSMenuItem alloc] initWithTitle:@"Select Next Instance" action:@selector(selectNextInstance) keyEquivalent:[NSString stringWithCharacters:&arrowKey length:1]];
        
        [selectNextInstanceItem setKeyEquivalentModifierMask:NSCommandKeyMask];
        [selectNextInstanceItem setTarget:self];
        [[menuItem submenu] addItem:selectNextInstanceItem];
    }
    
    if (menuItem) {
        NSMenuItem *cancelItem = [[NSMenuItem alloc] initWithTitle:@"Cancel Multiple Selection" action:@selector(cancelMultipleSelection) keyEquivalent:@""];
        
        [cancelItem setTarget:self];
        [[menuItem submenu] addItem:cancelItem];
    }
}

-(void)textDidChange:(NSNotification*) noti {
    if ([[noti object] isKindOfClass:[NSTextView class]]) {
        NSTextView *textView = [noti object];
        NSString *className = NSStringFromClass([textView class]);
        
        if([className isEqualToString:@"DVTSourceTextView"] || [className isEqualToString:@"IDEConsoleTextView"]) {
            self.sourceTextView = textView;
            
            NSTextView *textView = self.sourceTextView;
            
            NSUInteger newLen = [self.sourceTextView.string length];
            
            if(newLen < self.oldLength){
                self.shouldDelete = YES;
            }
            else{
                self.shouldDelete = NO;
            }
            
            self.oldLength = newLen;
            
            if(!self.selections) return;
            else if([self.selections count] == 0) return;
            
            NSRange selectedRange = [textView selectedRange];
            selectedRange.location -= 1;
            selectedRange.length = 1;
            NSString *text = textView.textStorage.string;
            NSString *nSelectedStr = [[text substringWithRange:selectedRange] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@""]];
            
            NSString *textToInsert = nSelectedStr;
            NSUInteger insertLocation = 0;
            
            for(int i = 0; i < [self.selectionRanges count]; i++){
                NSRange range = [self.selectionRanges[i] rangeValue];
                
                if(range.location <= selectedRange.location && range.location + range.length >= selectedRange.location){
                    insertLocation = selectedRange.location - range.location;
                    break;
                }
            }
            
            if(!self.isInserting){
                [self insertString:textToInsert atIndex:insertLocation];
            }
        }
    }
}

- (void)insertString:(NSString*)stringToInsert atIndex:(NSUInteger)insertLocation {
    self.isInserting = YES;
    NSRange firstRange = self.sourceTextView.selectedRange;
    
    for(int i = 0; i < [self.selectionRanges count]; i++){
        NSRange range = [self.selectionRanges[i] rangeValue];
        
        if(!self.shouldDelete){
            range.location += i;
            range.length++;
            
            self.sourceTextView.selectedRange = NSMakeRange(range.location + insertLocation, 0);
            
            if(i > 0) [self.sourceTextView insertText:stringToInsert];
        }
        else{
            range.location -= i;
            range.length--;
            
            self.sourceTextView.selectedRange = NSMakeRange(range.location + insertLocation + 2, 0);
            
            if(i > 0) [self.sourceTextView deleteBackward:nil];
        }
        
        self.selectionRanges[i] = [NSValue valueWithRange:range];
    }
    
    [self removeAllHighlighting];
    [self highlightRangesArray];
    
    self.sourceTextView.selectedRange = firstRange;
    
    self.isInserting = NO;
}

- (void)selectionDidChange:(NSNotification*) notification {
    if ([[notification object] isKindOfClass:[NSTextView class]]) {
        NSTextView *textView = [notification object];
        NSString *className = NSStringFromClass([textView class]);
        
        if([className isEqualToString:@"DVTSourceTextView"] || [className isEqualToString:@"IDEConsoleTextView"]) {
            self.sourceTextView = textView;
            
            NSTextView *textView = self.sourceTextView;
            
            NSRange selectedRange = [textView selectedRange];
            NSString *text = textView.textStorage.string;
            NSString *nSelectedStr = [[text substringWithRange:selectedRange] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@""]];
            
            if (!nSelectedStr.length) {
                return;
            }
            
            self.selectedText = nSelectedStr;
        }
    }
}

- (void)cancelMultipleSelection {
    [self removeAllHighlighting];
    [self.selections removeAllObjects];
    [self.selectionRanges removeAllObjects];
}

- (void)selectNextInstance {
    if(!self.selections){
        self.selections = [NSMutableArray new];
    }
    
    if([self.selectionRanges count] == 0){
        [self.selections addObject:[NSNumber numberWithBool:YES]];
    }
    
    [self.selections addObject:[NSNumber numberWithBool:YES]];
    
    [self removeAllHighlighting];
    
    [self searchRangesOfString:self.selectedText];
    [self highlightRangesArray];
}

- (void)searchRangesOfString:(NSString *)string {
    NSRange selectedRange = [self.sourceTextView selectedRange];
    NSUInteger totalLength = [self.sourceTextView.textStorage.string length];
    NSUInteger length = totalLength - selectedRange.location;
    
    NSRange searchRange = NSMakeRange(selectedRange.location, length);
    NSRange foundRange = NSMakeRange(0, 0);
    
    NSMutableArray *rangArray = [NSMutableArray array];
    
    int count = 0;
    
    while(count < [self.selections count]) {
        foundRange = [self.sourceTextView.textStorage.string rangeOfString:string options:0 range:searchRange];
        
        NSUInteger searchRangeStart = foundRange.location + foundRange.length;
        
        searchRange = NSMakeRange(searchRangeStart, totalLength - searchRangeStart);
        
        if (foundRange.location != NSNotFound) {
            [rangArray addObject:[NSValue valueWithRange:foundRange]];
            count++;
        }
        else{
            break;
        }
    }
    
    self.selectionRanges = rangArray;
}

- (void)highlightRangesArray {
    NSArray *rangeArray = [self.selectionRanges copy];
    
    NSTextView *textView = self.sourceTextView;
    
    [rangeArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSValue *value = obj;
        NSRange range = [value rangeValue];
        [textView.layoutManager addTemporaryAttribute:NSBackgroundColorAttributeName value:self.highlightColor forCharacterRange:range];
    }];
    
    [textView setNeedsDisplay:YES];
}

- (void)removeAllHighlighting {
    NSUInteger length = [[[self.sourceTextView textStorage] string] length];
    NSTextView *textView = self.sourceTextView;
    
    NSRange range = NSMakeRange(0, 0);
    for(int i = 0; i < length;){
        NSDictionary *dic = [textView.layoutManager temporaryAttributesAtCharacterIndex:i effectiveRange:&range];
        
        id obj = dic[NSBackgroundColorAttributeName];
        
        if (obj && [_highlightColor isEqual:obj]) {
            [textView.layoutManager removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:range];
        }
        
        i += range.length;
    }
    
    [textView setNeedsDisplay:YES];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
