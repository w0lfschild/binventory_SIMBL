//
//  binventory.m
//  binventory
//
//  Created by Alexander Zielenski on 4/4/16.
//  Edited by Wolfgang Baird on 5/14/16.
//  Copyright © 2016 Alexander Zielenski. All rights reserved.
//

@import AppKit;
#import "ZKSwizzle.h"
#import "ECStatusLabelDescription.h"
#import "SGDirWatchdog.h"

static NSMutableArray *watchdogs = nil;
static NSArray *Trashes = nil;

@interface binventory : NSObject
@end

@interface NSObject (Tile)
- (void)setStatusLabel:(id)arg1 forType:(int)arg2;
- (void)removeStatusLabelForType:(int)arg1;
@end

ZKSwizzleInterface(WBTrashTile, DOCKTrashTile, NSObject)
@implementation WBTrashTile

- (void)dk_updateCount {
    NSUInteger x = -1;
    
    for (NSURL *url in Trashes)
            x += [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[url path] error:nil] count];

    if (x <= 0)
        [self removeStatusLabelForType:1];
    else
        [self setStatusLabel:[[ZKClass(ECStatusLabelDescription) alloc] initWithDefaultPositioningAndString:[NSString stringWithFormat:@"%lu", (unsigned long)x]] forType:1];
}

- (void)resetTrashIcon {
    ZKOrig(void);
    [self dk_updateCount];
}

- (void)changeState:(BOOL)arg1 {
    if (watchdogs == nil)
    {
        watchdogs = [[NSMutableArray alloc] init];
        Trashes = [[NSFileManager defaultManager] URLsForDirectory:NSTrashDirectory inDomains:NSUserDomainMask];
        
        __weak WBTrashTile *weakSelf = self;
        for (NSURL *url in Trashes) {
            SGDirWatchdog *watchDog = [[SGDirWatchdog alloc] initWithPath:url.path
                                                                   update:^{
                                                                       [weakSelf dk_updateCount];
                                                                   }];
            [watchDog start];
            [watchdogs addObject:watchDog];
        }
    }
    [self dk_updateCount];
    ZKOrig(void, arg1);
}

- (void)dealloc {
    for (SGDirWatchdog *dog in watchdogs) {
        [dog stop];
    }
    
    Trashes = nil;
    watchdogs = nil;
    ZKOrig(void);
}

@end

static WBTrashTile *myTile = nil;

ZKSwizzleInterface(WBTile, Tile, NSObject)
@implementation WBTile

- (void)updateRect
{
    ZKOrig(void);
    if (myTile == nil)
        if ([self.className isEqualToString:@"DOCKTrashTile"])
            myTile = (WBTrashTile*)self;
}

@end

@implementation binventory

+ (void)load
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        /* Wait for the tile to be found */
        while (myTile == nil)
            usleep(100000);
        
        /* Set up watchdogs */
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"binventory: settting up watchdogs...");
            
            watchdogs = [[NSMutableArray alloc] init];
            Trashes = [[NSFileManager defaultManager] URLsForDirectory:NSTrashDirectory inDomains:NSUserDomainMask];
            
            for (NSURL *url in Trashes) {
                SGDirWatchdog *watchDog = [[SGDirWatchdog alloc] initWithPath:url.path
                                                                       update:^{
                                                                           [myTile dk_updateCount];
                                                                       }];
                [watchDog start];
                [watchdogs addObject:watchDog];
            }
            [myTile dk_updateCount];
        });
    });
    NSLog(@"binventory: loaded...");
}

@end