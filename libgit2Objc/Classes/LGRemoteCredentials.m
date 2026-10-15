#import "LGRemoteCredentials.h"

@implementation LGRemoteCredentials

- (id)copyWithZone:(NSZone *)zone {
    LGRemoteCredentials *copy = [[LGRemoteCredentials alloc] init];
    copy.username = self.username;
    copy.password = self.password;
    copy.SSHUsername = self.SSHUsername;
    copy.SSHPrivateKeyPath = self.SSHPrivateKeyPath;
    copy.SSHPublicKeyPath = self.SSHPublicKeyPath;
    copy.SSHPassphrase = self.SSHPassphrase;
    copy.useSSHAgent = self.useSSHAgent;
    return copy;
}

- (NSString *)description {
    NSMutableString *parts = [NSMutableString string];
    if (self.username) [parts appendFormat:@"https:%@ ", self.username];
    if (self.SSHPrivateKeyPath) [parts appendFormat:@"ssh-key:%@ ", self.SSHPrivateKeyPath];
    if (self.useSSHAgent) [parts appendString:@"ssh-agent "];
    return [NSString stringWithFormat:@"<%@: %@>", NSStringFromClass(self.class), parts];
}

@end
