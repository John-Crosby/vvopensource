#import "VVThreadLoop.h"
#import "VVAssertionHandler.h"
#import <os/lock.h>

@implementation VVThreadLoop

- (id)initWithTimeInterval:(double)i target:(id)t selector:(SEL)s {
    self = [super init];
    if (self != nil) {
        [self generalInit];
        [self setInterval:i];
        targetObj = t;
        targetSel = s;
        if ((t == nil) || (s == nil) || (![t respondsToSelector:s])) {
            return nil;
        }
    }
    return self;
}

- (id)initWithTimeInterval:(double)i {
    self = [super init];
    if (self != nil) {
        [self generalInit];
        [self setInterval:i];
    }
    return self;
}

- (void)generalInit {
    interval = 0.1;
    maxInterval = 1.0;
    running = NO;
    bail = NO;
    paused = NO;
    executingCallback = NO;
    thread = nil;
    rlTimer = nil;
    runLoop = nil;
    
    valLock = OS_UNFAIR_LOCK_INIT;
    
    targetObj = nil;
    targetSel = nil;
}

// Under ARC, no need for manual dealloc
// Remove the dealloc entirely unless you clean up non-object memory

- (void)start {
    os_unfair_lock_lock(&valLock); // LOCK
    
    if (running) {
        os_unfair_lock_unlock(&valLock); // UNLOCK and return if already running
        return;
    }
    
    paused = NO;
    
    os_unfair_lock_unlock(&valLock); // UNLOCK when done with critical section
    
    [NSThread detachNewThreadSelector:@selector(threadCallback) toTarget:self withObject:nil];
}


- (void)threadCallback {
    @autoreleasepool {
        if (![NSThread setThreadPriority:1.0]) {
            NSLog(@"\terror setting thread priority to 1.0");
        }
        
        BOOL tmpRunning = YES;
        BOOL tmpBail = NO;
        
        os_unfair_lock_lock(&valLock); // LOCK critical section
        running = YES;
        bail = NO;
        thread = [NSThread currentThread];
        runLoop = [NSRunLoop currentRunLoop];
        rlTimer = [NSTimer scheduledTimerWithTimeInterval:60.0*60.0*24.0*7.0*52.0
                                                   target:self
                                                 selector:@selector(timerCallback:)
                                                 userInfo:nil
                                                  repeats:NO];
        os_unfair_lock_unlock(&valLock); // UNLOCK
    }
}
@end
