#import "MutNRLockDict.h"

@implementation MutNRLockDict

- (NSString *)description {
    return [NSString stringWithFormat:@"<MutNRLockDict: %@>", dict];
}

+ (id)dictionaryWithCapacity:(NSInteger)c {
    MutNRLockDict *returnMe = [[MutNRLockDict alloc] initWithCapacity:0];
    if (returnMe == nil)
        return nil;
    return returnMe;
}

- (NSMutableDictionary *)createDictCopy {
    NSMutableDictionary *returnMe = [NSMutableDictionary dictionaryWithCapacity:0];
    for (NSString *keyPtr in [dict allKeys]) {
        id objPtr = [dict objectForKey:keyPtr]; // direct object reference
        if (objPtr != nil) {
            [returnMe setObject:objPtr forKey:keyPtr];
        }
    }
    return returnMe;
}

- (void)setObject:(id)o forKey:(NSString *)s {
    if (s == nil || o == nil)
        return;

    [super setObject:o forKey:s]; // no need to wrap
}

- (void)setValue:(id)v forKey:(NSString *)s {
    if (s == nil || v == nil)
        return;

    [super setObject:v forKey:s]; // no need to wrap
}

- (id)objectForKey:(NSString *)k {
    return [super objectForKey:k]; // no need to unwrap
}

- (void)addEntriesFromDictionary:(id)otherDictionary {
    if ((dict != nil) && (otherDictionary != nil) && ([otherDictionary count] > 0)) {
        // If the array's another MutNRLockDict, I can simply use its items
        if ([otherDictionary isKindOfClass:[MutNRLockDict class]]) {
            [dict addEntriesFromDictionary:[otherDictionary lockCreateDictCopy]];
        }
        // Else if it's a MutLockDict
        else if ([otherDictionary isKindOfClass:[MutLockDict class]]) {
            NSMutableDictionary *copy = [otherDictionary lockCreateDictCopy];
            if (copy != nil) {
                for (NSString *keyPtr in [copy allKeys]) {
                    id anObj = [copy objectForKey:keyPtr];
                    if (anObj != nil) {
                        [dict setObject:anObj forKey:keyPtr];
                    }
                }
            }
        }
        // Else it's some other kind of generic dictionary
        else {
            for (NSString *keyPtr in [otherDictionary allKeys]) {
                id anObj = [otherDictionary objectForKey:keyPtr];
                if (anObj != nil) {
                    [dict setObject:anObj forKey:keyPtr];
                }
            }
        }
    }
}

- (NSArray *)allValues {
    if (dict == nil)
        return nil;

    NSArray *returnMe = [dict allValues]; // no need for valueForKey:@"object"

    return returnMe;
}

@end
