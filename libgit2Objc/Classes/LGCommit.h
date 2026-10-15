#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LGSignature, LGTree;

/// git 提交对象
@interface LGCommit : NSObject

/// 完整 SHA-1
@property (nonatomic, readonly) NSString *OID;
/// 短 SHA
@property (nonatomic, readonly) NSString *shortOID;
@property (nonatomic, readonly) NSString *message;
@property (nonatomic, readonly) NSString *summary;
@property (nonatomic, readonly) LGSignature *author;
@property (nonatomic, readonly) LGSignature *committer;
@property (nonatomic, readonly) NSDate *date;
/// 父提交的 SHA 数组（NSArray<NSString *>）
@property (nonatomic, readonly) NSArray<NSString *> *parentOIDs;
@property (nonatomic, readonly) NSUInteger parentCount;

- (nullable LGTree *)treeWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
