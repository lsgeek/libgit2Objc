#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class LGSignature;

/// git 提交者/作者签名（name + email + 时间）
@interface LGSignature : NSObject <NSCopying>

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *email;
@property (nonatomic, readonly) NSDate *date;

/// 使用当前时间创建签名
- (nullable instancetype)initWithName:(NSString *)name
                                email:(NSString *)email
                                error:(NSError **)error;

/// 指定时间创建签名
- (nullable instancetype)initWithName:(NSString *)name
                                email:(NSString *)email
                                 date:(NSDate *)date
                                error:(NSError **)error;

/// 便捷构造
+ (nullable LGSignature *)signatureWithName:(NSString *)name
                                      email:(NSString *)email
                                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
