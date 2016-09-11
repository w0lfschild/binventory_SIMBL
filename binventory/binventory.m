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
- (void)setupWatchDogs:(NSNotification*)aNotification;
@end

@interface NSObject (Tile)
- (void)setStatusLabel:(id)arg1 forType:(int)arg2;
- (void)removeStatusLabelForType:(int)arg1;
@end

ZKSwizzleInterface(WBTrashTile, DOCKTrashTile, NSObject)
@implementation WBTrashTile

- (void)wb_updateCount {
    NSUInteger x = 0;
    
    for (NSURL *url in Trashes)
    {
        x += [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[url path] error:nil] count];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/.DS_Store", url.path]])
            x -= 1;
    }

    if (x <= 0)
        [self removeStatusLabelForType:1];
    else
        [self setStatusLabel:[[ZKClass(ECStatusLabelDescription) alloc] initWithDefaultPositioningAndString:[NSString stringWithFormat:@"%lu", (unsigned long)x]] forType:1];
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

+ (binventory*) sharedInstance
{
    static binventory* plugin = nil;
    if (plugin == nil) {
        plugin = [[binventory alloc] init];
    }
    return plugin;
}

+ (void)load
{
    binventory *plugin = [binventory sharedInstance];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:plugin
                                                           selector:@selector(setupWatchDogs:)
                                                               name:NSWorkspaceDidMountNotification
                                                             object:[NSWorkspace sharedWorkspace]];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:plugin
                                                           selector:@selector(setupWatchDogs:)
                                                               name:NSWorkspaceDidUnmountNotification
                                                             object:[NSWorkspace sharedWorkspace]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        /* Wait for the tile to be found */
        while (myTile == nil)
            usleep(100000);
        
        /* Set up watchdogs */
        dispatch_async(dispatch_get_main_queue(), ^{
            [plugin setupWatchDogs:nil];
        });
    });
    NSLog(@"binventory: loaded...");
}

- (void)setupWatchDogs:(NSNotification*)aNotification
{
    NSLog(@"binventory: setting up watchdogs...");
    Trashes = nil;
    watchdogs = [[NSMutableArray alloc] init];
    NSMutableArray *trashCans = [[NSMutableArray alloc] init];
    NSArray *volumes = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:nil options:0];
    for (NSURL *url in volumes)
    {
        NSError *error;
        NSURL *trash = [[NSFileManager defaultManager] URLForDirectory:NSTrashDirectory inDomain:NSAllDomainsMask appropriateForURL:url create:NO error:&error];
        if (trash != nil)
        {
            [trashCans addObject:trash];
            SGDirWatchdog *watchDog = [[SGDirWatchdog alloc] initWithPath:trash.path
                                                                   update:^{
                                                                       [myTile wb_updateCount];
                                                                   }];
            [watchDog start];
            [watchdogs addObject:watchDog];
        }
    }
    Trashes = [trashCans copy];
//    NSLog(@"%@", Trashes);
    [myTile wb_updateCount];
}

@end
