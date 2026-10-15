#import "LGRemoteAuthContext.h"
#import "LGTransferProgress.h"
#import "LGTransferProgress+Internal.h"

@interface LGRemoteAuthContext ()
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, copy, nullable) NSString *password;
@property (nonatomic, copy, nullable) NSString *SSHUsername;
@property (nonatomic, copy, nullable) NSString *SSHPrivateKeyPath;
@property (nonatomic, copy, nullable) NSString *SSHPublicKeyPath;
@property (nonatomic, copy, nullable) NSString *SSHPassphrase;
@property (nonatomic) BOOL useSSHAgent;
@end

@implementation LGRemoteAuthContext

- (instancetype)initWithCredentials:(LGRemoteCredentials *)credentials {
    self = [super init];
    if (self && credentials) {
        _username = credentials.username;
        _password = credentials.password;
        _SSHUsername = credentials.SSHUsername;
        _SSHPrivateKeyPath = credentials.SSHPrivateKeyPath;
        _SSHPublicKeyPath = credentials.SSHPublicKeyPath;
        _SSHPassphrase = credentials.SSHPassphrase;
        _useSSHAgent = credentials.useSSHAgent;
    }
    return self;
}

- (instancetype)initWithCredentialSource:(id)source {
    self = [super init];
    if (self && source) {
        _username = [source valueForKey:@"username"];
        _password = [source valueForKey:@"password"];
        _SSHUsername = [source valueForKey:@"SSHUsername"];
        _SSHPrivateKeyPath = [source valueForKey:@"SSHPrivateKeyPath"];
        _SSHPublicKeyPath = [source valueForKey:@"SSHPublicKeyPath"];
        _SSHPassphrase = [source valueForKey:@"SSHPassphrase"];
        _useSSHAgent = [[source valueForKey:@"useSSHAgent"] boolValue];
    }
    return self;
}

@end

int LGRemoteAuthCallback(git_credential **out,
                         const char *url,
                         const char *usernameFromURL,
                         unsigned int allowedTypes,
                         void *payload) {
    LGRemoteAuthContext *context = (__bridge LGRemoteAuthContext *)payload;
    NSString *sshUsername = context.SSHUsername;
    NSString *privateKey = context.SSHPrivateKeyPath;
    NSString *publicKey = context.SSHPublicKeyPath;
    NSString *passphrase = context.SSHPassphrase;

    // 1. SSH 密钥文件
    if (privateKey.length > 0 && (allowedTypes & GIT_CREDENTIAL_SSH_KEY)) {
        const char *user = sshUsername.length > 0 ? sshUsername.UTF8String
                         : (usernameFromURL ?: "git");
        NSString *pub = publicKey.length > 0 ? publicKey : [privateKey stringByAppendingString:@".pub"];
        return git_credential_ssh_key_new(out, user, pub.UTF8String, privateKey.UTF8String,
                                          passphrase.UTF8String);
    }

    // 2. ssh-agent
    if (context.useSSHAgent && (allowedTypes & GIT_CREDENTIAL_SSH_KEY)) {
        const char *user = sshUsername.length > 0 ? sshUsername.UTF8String
                         : (usernameFromURL ?: "git");
        return git_credential_ssh_key_from_agent(out, user);
    }

    // 3. HTTPS 用户名密码
    if (context.username.length > 0 && (allowedTypes & GIT_CREDENTIAL_USERPASS_PLAINTEXT)) {
        const char *user = usernameFromURL ? usernameFromURL : context.username.UTF8String;
        return git_credential_userpass_plaintext_new(out, user, context.password.UTF8String ?: "");
    }
    return GIT_PASSTHROUGH;
}

int LGRemoteFetchProgressCallback(const git_indexer_progress *stats, void *payload) {
    LGRemoteAuthContext *context = (__bridge LGRemoteAuthContext *)payload;
    if (context.progressBlock) {
        LGTransferProgress *progress = [[LGTransferProgress alloc]
            initWithTotalObjects:stats->total_objects
            transferredObjects:stats->received_objects
            indexedObjects:stats->indexed_objects
            transferredBytes:stats->received_bytes
            isPush:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            context.progressBlock(progress);
        });
    }
    return 0;
}

int LGRemotePushProgressCallback(unsigned int current,
                                 unsigned int total,
                                 size_t bytes,
                                 void *payload) {
    LGRemoteAuthContext *context = (__bridge LGRemoteAuthContext *)payload;
    if (context.progressBlock) {
        LGTransferProgress *progress = [[LGTransferProgress alloc]
            initWithTotalObjects:total
            transferredObjects:current
            indexedObjects:0
            transferredBytes:bytes
            isPush:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            context.progressBlock(progress);
        });
    }
    return 0;
}
