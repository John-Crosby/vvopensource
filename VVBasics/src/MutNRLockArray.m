#import "MutNRLockArray.h"

@implementation MutNRLockArray

- (NSString *)description {
    return [NSString stringWithFormat:@"<MutNRLockArray: %@>", array];
}

+ (id)arrayWithCapacity:(NSInteger)c {
    MutNRLockArray *returnMe = [[MutNRLockArray alloc] initWithCapacity:c];
    if (returnMe == nil)
        return nil;
    return returnMe;
}

- (id)initWithCapacity:(NSInteger)c {
    if (self = [super initWithCapacity:c]) {
        pthread_rwlock_init(&arrayLock, NULL);
        zwrFlag = NO; // you can remove zwrFlag if unused
    }
    return self;
}

- (id)copyWithZone:(NSZone *)z {
    MutNRLockArray *returnMe = [[MutNRLockArray alloc] initWithCapacity:0];
    if (returnMe != nil) {
        if (zwrFlag)
            [returnMe setZwrFlag:YES];
        [returnMe lockAddObjectsFromArray:self];
    }
    return returnMe;
}

- (NSMutableArray *)createArrayCopy {
    NSMutableArray *returnMe = [NSMutableArray arrayWithCapacity:[array count]];
    for (id objPtr in array) {
        if (objPtr != nil)
            [returnMe addObject:objPtr];
    }
    return returnMe;
}

- (NSMutableArray *)lockCreateArrayCopy {
    NSMutableArray *returnMe = nil;
    pthread_rwlock_rdlock(&arrayLock);
    returnMe = [self createArrayCopy];
    pthread_rwlock_unlock(&arrayLock);
    return returnMe;
}

- (void)addObject:(id)o {
    if (o == nil)
        return;

    [super addObject:o];
}

- (void)addObjectsFromArray:(id)a {
    if (array != nil && a != nil && [a count] > 0) {
        if ([a isKindOfClass:[MutNRLockArray class]] || [a isKindOfClass:[MutLockArray class]]) {
            NSMutableArray *copy = [a lockCreateArrayCopy];
            if (copy != nil)
                [array addObjectsFromArray:copy];
        } else {
            for (id anObj in a) {
                if (anObj != nil)
                    [array addObject:anObj];
            }
        }
    }
}

- (void)replaceWithObjectsFromArray:(id)a {
    if (array != nil && a != nil) {
        [array removeAllObjects];
        [self addObjectsFromArray:a];
    }
}

- (BOOL)insertObject:(id)o atIndex:(NSInteger)i {
    if (o == nil)
        return NO;

    if (i < 0 || i > [array count])
        return NO;

    [array insertObject:o atIndex:i];
    return YES;
}

- (id)lastObject {
    return [super lastObject];
}

- (void)removeObject:(id)o {
    if (o == nil)
        return;

    NSUInteger indexOfObject = [self indexOfObject:o];
    if (indexOfObject != NSNotFound)
        [self removeObjectAtIndex:indexOfObject];
}

- (BOOL)containsObject:(id)o {
    return ([self indexOfObject:o] != NSNotFound);
}

- (id)objectAtIndex:(NSInteger)i {
    if (i < 0 || i >= [array count])
        return nil;

    return [super objectAtIndex:i];
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexes {
    if (array == nil || indexes == nil)
        return @[];

    NSArray *tmpArray = [array objectsAtIndexes:indexes];
    return tmpArray ?: @[];
}

- (NSInteger)indexOfObject:(id)o {
    if (array == nil || o == nil || [array count] < 1)
        return NSNotFound;

    NSUInteger index = [array indexOfObject:o];
    return (index != NSNotFound) ? index : NSNotFound;
}

- (BOOL)containsIdenticalPtr:(id)o {
    return ([self indexOfIdenticalPtr:o] != NSNotFound);
}

- (long)indexOfIdenticalPtr:(id)o {
    if (array == nil || o == nil || [array count] < 1)
        return NSNotFound;

    NSUInteger index = [array indexOfObjectIdenticalTo:o];
    return (index != NSNotFound) ? index : NSNotFound;
}

- (void)removeIdenticalPtr:(id)o {
    long foundIndex = [self indexOfIdenticalPtr:o];
    if (foundIndex != NSNotFound)
        [self removeObjectAtIndex:foundIndex];
}

@synthesize zwrFlag;

- (void)bruteForceMakeObjectsPerformSelector:(SEL)s {
    if (array == nil)
        return;

    for (id actualObj in array) {
        if (actualObj != nil && [actualObj respondsToSelector:s])
            [actualObj performSelector:s];
    }
}

- (void)lockBruteForceMakeObjectsPerformSelector:(SEL)s {
    if (array == nil)
        return;

    pthread_rwlock_rdlock(&arrayLock);
    [self bruteForceMakeObjectsPerformSelector:s];
    pthread_rwlock_unlock(&arrayLock);
}

- (void)bruteForceMakeObjectsPerformSelector:(SEL)s withObject:(id)o {
    if (array == nil)
        return;

    for (id actualObj in array) {
        if (actualObj != nil && [actualObj respondsToSelector:s])
            [actualObj performSelector:s withObject:o];
    }
}

- (void)lockBruteForceMakeObjectsPerformSelector:(SEL)s withObject:(id)o {
    if (array == nil)
        return;

    pthread_rwlock_rdlock(&arrayLock);
    [self bruteForceMakeObjectsPerformSelector:s withObject:o];
    pthread_rwlock_unlock(&arrayLock);
}

- (void)lockPurgeEmptyHolders {
    pthread_rwlock_wrlock(&arrayLock);
    if (array != nil)
        [self purgeEmptyHolders];
    pthread_rwlock_unlock(&arrayLock);
}

- (void)purgeEmptyHolders {
    if (array != nil) {
        NSIndexSet *indicesToRemove = [array indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return obj == nil;
        }];

        if ([indicesToRemove count] > 0)
            [array removeObjectsAtIndexes:indicesToRemove];
    }
}

@end

