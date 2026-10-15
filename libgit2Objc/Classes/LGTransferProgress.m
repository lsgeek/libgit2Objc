#import "LGTransferProgress.h"
#import "LGTransferProgress+Internal.h"

@implementation LGTransferProgress

- (instancetype)initWithTotalObjects:(NSUInteger)total
                  transferredObjects:(NSUInteger)transferred
                      indexedObjects:(NSUInteger)indexed
                     transferredBytes:(NSUInteger)bytes
                                isPush:(BOOL)isPush {
    self = [super init];
    if (self) {
        _totalObjects = total;
        _transferredObjects = transferred;
        _indexedObjects = indexed;
        _transferredBytes = bytes;
        _push = isPush;
    }
    return self;
}

- (NSString *)localizedDescription {
    NSString *unit = self.isPush ? @"已推送" : @"已接收";
    return [NSString stringWithFormat:@"%lu/%lu 对象，%@ %lu KB",
            (unsigned long)self.transferredObjects,
            (unsigned long)self.totalObjects,
            unit,
            (unsigned long)self.transferredBytes / 1024];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass(self.class), self.localizedDescription];
}

@end
