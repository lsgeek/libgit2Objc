#import "LGSignature.h"
#import "LGSignature+Internal.h"
#import "LGError.h"

@interface LGSignature () {
    git_signature *_signature;
}
@end

@implementation LGSignature

/// 显式实现 getter：属性自动合成会使用未赋值的 _gitSignature 变量，
/// 必须返回 git_signature_new 填充的 _signature
- (const git_signature *)gitSignature {
    return _signature;
}

- (nullable instancetype)initWithName:(NSString *)name
                                email:(NSString *)email
                                error:(NSError **)error {
    return [self initWithName:name email:email date:[NSDate date] error:error];
}

- (nullable instancetype)initWithName:(NSString *)name
                                email:(NSString *)email
                                 date:(NSDate *)date
                                error:(NSError **)error {
    self = [super init];
    if (!self) return nil;

    git_time_t time = (git_time_t)[date timeIntervalSince1970];
    int status = git_signature_new(&_signature,
                                   name.UTF8String,
                                   email.UTF8String,
                                   time,
                                   0); // UTC，简化处理
    if (status != GIT_OK) {
        if (error) *error = [NSError lg_errorWithGitCode:status];
        return nil;
    }
    return self;
}

+ (nullable LGSignature *)signatureWithName:(NSString *)name
                                      email:(NSString *)email
                                      error:(NSError **)error {
    return [[self alloc] initWithName:name email:email error:error];
}

- (void)dealloc {
    git_signature_free(_signature);
}

- (NSString *)name {
    return [NSString stringWithUTF8String:_signature->name];
}

- (NSString *)email {
    return [NSString stringWithUTF8String:_signature->email];
}

- (NSDate *)date {
    return [NSDate dateWithTimeIntervalSince1970:_signature->when.time];
}

- (id)copyWithZone:(NSZone *)zone {
    return [[LGSignature alloc] initWithName:self.name
                                       email:self.email
                                        date:self.date
                                       error:NULL];
}

@end
