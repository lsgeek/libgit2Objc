#import "LGTransferProgress.h"

NS_ASSUME_NONNULL_BEGIN

@interface LGTransferProgress ()

- (instancetype)initWithTotalObjects:(NSUInteger)total
                  transferredObjects:(NSUInteger)transferred
                      indexedObjects:(NSUInteger)indexed
                    transferredBytes:(NSUInteger)bytes
                               isPush:(BOOL)isPush NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
