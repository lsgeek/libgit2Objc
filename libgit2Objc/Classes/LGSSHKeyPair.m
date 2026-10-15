#import "LGSSHKeyPair.h"
#import "LGError.h"
#include <openssl/evp.h>
#include <openssl/rsa.h>
#include <openssl/core_names.h>
#include <openssl/bn.h>
#include <openssl/rand.h>
#include <openssl/sha.h>
#include <openssl/err.h>

#pragma mark - SSH 二进制编码辅助

static NSError *LGOpenSSLError(NSString *operation) {
    unsigned long code = ERR_get_error();
    const char *msg = code ? ERR_error_string(code, NULL) : "unknown error";
    return [NSError errorWithDomain:LGGitErrorDomain
                               code:(NSInteger)code
                           userInfo:@{NSLocalizedDescriptionKey:
                                          [NSString stringWithFormat:@"%@: %s", operation, msg]}];
}

/// SSH wire 格式 string: uint32 长度 + 字节
static void LGAppendSSHString(NSMutableData *data, const void *bytes, NSUInteger length) {
    uint32_t len = (uint32_t)NSSwapHostIntToBig((uint32_t)length);
    [data appendBytes:&len length:4];
    if (length > 0) [data appendBytes:bytes length:length];
}

static void LGAppendSSHStringData(NSMutableData *data, NSData *payload) {
    LGAppendSSHString(data, payload.bytes, payload.length);
}

static void LGAppendSSHStringC(NSMutableData *data, const char *cstr) {
    LGAppendSSHString(data, cstr, strlen(cstr));
}

/// SSH wire 格式 mpint（大端，去掉前导零；首字节高位为 1 时补零）
static void LGAppendSSHMPInt(NSMutableData *data, const BIGNUM *bn) {
    if (BN_is_zero(bn) || BN_is_negative(bn)) {
        uint32_t zero = 0;
        [data appendBytes:&zero length:4];
        return;
    }
    int bytes = BN_num_bytes(bn);
    NSMutableData *raw = [NSMutableData dataWithLength:bytes];
    BN_bn2bin(bn, raw.mutableBytes);
    if ([raw length] > 0 && (((const uint8_t *)raw.bytes)[0] & 0x80)) {
        uint32_t len = (uint32_t)NSSwapHostIntToBig((uint32_t)(bytes + 1));
        [data appendBytes:&len length:4];
        const uint8_t pad = 0;
        [data appendBytes:&pad length:1];
    } else {
        uint32_t len = (uint32_t)NSSwapHostIntToBig((uint32_t)bytes);
        [data appendBytes:&len length:4];
    }
    [data appendData:raw];
}

static NSString *LGBase64Encode(NSData *data) {
    if (data.length == 0) return @"";
    size_t outLen = 4 * ((data.length + 2) / 3);
    NSMutableData *out = [NSMutableData dataWithLength:outLen + 1];
    int written = EVP_EncodeBlock(out.mutableBytes, data.bytes, (int)data.length);
    if (written < 0) return @"";
    return [[NSString alloc] initWithBytes:out.bytes length:written encoding:NSASCIIStringEncoding];
}

/// base64 按 70 字符折行 + PEM 头尾
static NSString *LGOpenSSHPrivateKeyPEM(NSData *blob) {
    NSString *b64 = LGBase64Encode(blob);
    NSMutableString *body = [NSMutableString string];
    for (NSUInteger i = 0; i < b64.length; i += 70) {
        [body appendString:[b64 substringWithRange:NSMakeRange(i, MIN(70, b64.length - i))]];
        [body appendString:@"\n"];
    }
    return [NSString stringWithFormat:@"-----BEGIN OPENSSH PRIVATE KEY-----\n%@-----END OPENSSH PRIVATE KEY-----\n", body];
}

/// OpenSSH 私钥文件外层容器（openssh-key-v1，未加密）
static NSData *LGWrapOpenSSHPrivateKey(NSData *publicBlob, NSData *privateSection) {
    NSMutableData *out = [NSMutableData data];
    // 魔数 "openssh-key-v1" + 一个 \0，共 15 字节
    // （注意 "...\0" 字面量会有显式+隐式两个 \0，sizeof 为 16，不能直接用）
    const char magic[] = "openssh-key-v1";
    [out appendBytes:magic length:sizeof(magic)];
    LGAppendSSHStringC(out, "none");                // ciphername
    LGAppendSSHStringC(out, "none");                // kdfname
    LGAppendSSHString(out, NULL, 0);                // kdfoptions
    uint32_t nkeys = NSSwapHostIntToBig(1);
    [out appendBytes:&nkeys length:4];
    LGAppendSSHStringData(out, publicBlob);
    LGAppendSSHStringData(out, privateSection);
    return out;
}

static uint32_t LGCheckInt(void) {
    uint32_t value = 0;
    RAND_bytes((uint8_t *)&value, sizeof(value));
    return value;
}

#pragma mark - LGSSHKeyPair

@interface LGSSHKeyPair ()
@property (nonatomic, copy) NSString *keyType;
@property (nonatomic, copy) NSString *comment;
@property (nonatomic, copy) NSString *publicKey;
@property (nonatomic, copy) NSString *privateKey;
@property (nonatomic, copy) NSString *SHA256Fingerprint;
@end

@implementation LGSSHKeyPair

- (BOOL)writePrivateKeyToFile:(NSString *)path error:(NSError **)error {
    NSError *err = nil;
    if (![self.privateKey writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
        if (error) *error = err;
        return NO;
    }
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0600}
                                     ofItemAtPath:path error:nil];
    return YES;
}

- (BOOL)writePublicKeyToFile:(NSString *)path error:(NSError **)error {
    NSError *err = nil;
    NSString *content = [self.publicKey stringByAppendingString:@"\n"];
    if (![content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
        if (error) *error = err;
        return NO;
    }
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0644}
                                     ofItemAtPath:path error:nil];
    return YES;
}

@end

#pragma mark - LGSSHKeyGenerator

@implementation LGSSHKeyGenerator

+ (nullable LGSSHKeyPair *)generateEd25519KeyPairWithComment:(nullable NSString *)comment
                                                       error:(NSError **)error {
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_ED25519, NULL);
    if (!ctx) { if (error) *error = LGOpenSSLError(@"创建密钥上下文失败"); return nil; }

    LGSSHKeyPair *result = nil;
    EVP_PKEY *pkey = NULL;
    do {
        if (EVP_PKEY_keygen_init(ctx) <= 0) break;
        if (EVP_PKEY_keygen(ctx, &pkey) <= 0) break;

        uint8_t pub[32], seed[32];
        size_t pubLen = sizeof(pub), seedLen = sizeof(seed);
        if (EVP_PKEY_get_raw_public_key(pkey, pub, &pubLen) <= 0) break;
        if (EVP_PKEY_get_raw_private_key(pkey, seed, &seedLen) <= 0) break;
        if (pubLen != 32 || seedLen != 32) break;

        NSData *pubData = [NSData dataWithBytes:pub length:32];
        // OpenSSH 私钥载荷: seed(32) || pub(32)
        NSMutableData *privRaw = [NSMutableData dataWithBytes:seed length:32];
        [privRaw appendData:pubData];

        // 公钥 blob: string "ssh-ed25519" || string pub
        NSMutableData *pubBlob = [NSMutableData data];
        LGAppendSSHStringC(pubBlob, "ssh-ed25519");
        LGAppendSSHStringData(pubBlob, pubData);

        // 私钥 section: checkint x2, string type, string pub, string priv64, string comment, 1..n 填充
        NSMutableData *section = [NSMutableData data];
        uint32_t c1 = LGCheckInt(), c2 = c1;
        [section appendBytes:&c1 length:4];
        [section appendBytes:&c2 length:4];
        LGAppendSSHStringC(section, "ssh-ed25519");
        LGAppendSSHStringData(section, pubData);
        LGAppendSSHStringData(section, privRaw);
        LGAppendSSHStringData(section, [comment ?: @"libgit2objc" dataUsingEncoding:NSUTF8StringEncoding]);
        // 未加密块大小 8：补齐到 8 的倍数
        uint8_t pad = 1;
        while (section.length % 8 != 0) { [section appendBytes:&pad length:1]; pad++; }

        result = [self keyPairWithType:@"ssh-ed25519"
                               comment:comment
                              pubBlob:pubBlob
                           privateKey:LGOpenSSHPrivateKeyPEM(LGWrapOpenSSHPrivateKey(pubBlob, section))];
    } while (0);

    EVP_PKEY_free(pkey);
    EVP_PKEY_CTX_free(ctx);
    if (!result && error && !*error) *error = LGOpenSSLError(@"ed25519 密钥生成失败");
    return result;
}

+ (nullable LGSSHKeyPair *)generateRSAKeyPairWithKeySize:(NSUInteger)keySize
                                                 comment:(nullable NSString *)comment
                                                   error:(NSError **)error {
    if (keySize < 2048) {
        if (error) *error = [NSError errorWithDomain:LGGitErrorDomain
                                                code:0
                                            userInfo:@{NSLocalizedDescriptionKey: @"RSA 密钥长度至少 2048 位"}];
        return nil;
    }

    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, NULL);
    if (!ctx) { if (error) *error = LGOpenSSLError(@"创建密钥上下文失败"); return nil; }

    LGSSHKeyPair *result = nil;
    EVP_PKEY *pkey = NULL;
    BIGNUM *n = NULL, *e = NULL, *d = NULL, *p = NULL, *q = NULL, *iqmp = NULL;
    do {
        if (EVP_PKEY_keygen_init(ctx) <= 0) break;
        if (EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, (int)keySize) <= 0) break;
        if (EVP_PKEY_keygen(ctx, &pkey) <= 0) break;

        if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_N, &n) <= 0) break;
        if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_E, &e) <= 0) break;
        if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_D, &d) <= 0) break;
        if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_FACTOR1, &p) <= 0) break;
        if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_FACTOR2, &q) <= 0) break;
        if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_COEFFICIENT1, &iqmp) <= 0) break;

        NSData *commentData = [comment ?: @"libgit2objc" dataUsingEncoding:NSUTF8StringEncoding];

        // 公钥 blob: string "ssh-rsa" || mpint e || mpint n
        NSMutableData *pubBlob = [NSMutableData data];
        LGAppendSSHStringC(pubBlob, "ssh-rsa");
        LGAppendSSHMPInt(pubBlob, e);
        LGAppendSSHMPInt(pubBlob, n);

        // 私钥 section: checkint x2, string type, mpint n,e,d,iqmp,p,q, string comment, 填充
        NSMutableData *section = [NSMutableData data];
        uint32_t c1 = LGCheckInt(), c2 = c1;
        [section appendBytes:&c1 length:4];
        [section appendBytes:&c2 length:4];
        LGAppendSSHStringC(section, "ssh-rsa");
        LGAppendSSHMPInt(section, n);
        LGAppendSSHMPInt(section, e);
        LGAppendSSHMPInt(section, d);
        LGAppendSSHMPInt(section, iqmp);
        LGAppendSSHMPInt(section, p);
        LGAppendSSHMPInt(section, q);
        LGAppendSSHStringData(section, commentData);
        uint8_t pad = 1;
        while (section.length % 8 != 0) { [section appendBytes:&pad length:1]; pad++; }

        result = [self keyPairWithType:@"ssh-rsa"
                               comment:comment
                              pubBlob:pubBlob
                           privateKey:LGOpenSSHPrivateKeyPEM(LGWrapOpenSSHPrivateKey(pubBlob, section))];
    } while (0);

    BN_free(n); BN_free(e); BN_free(d); BN_free(p); BN_free(q); BN_free(iqmp);
    EVP_PKEY_free(pkey);
    EVP_PKEY_CTX_free(ctx);
    if (!result && error && !*error) *error = LGOpenSSLError(@"RSA 密钥生成失败");
    return result;
}

/// 组装密钥对：公钥整行、SHA256 指纹
+ (LGSSHKeyPair *)keyPairWithType:(NSString *)type
                          comment:(nullable NSString *)comment
                         pubBlob:(NSData *)pubBlob
                      privateKey:(NSString *)privateKey {
    NSString *commentString = comment.length > 0 ? comment : @"libgit2objc";

    LGSSHKeyPair *pair = [[LGSSHKeyPair alloc] init];
    pair.keyType = type;
    pair.comment = commentString;
    pair.privateKey = privateKey;
    pair.publicKey = [NSString stringWithFormat:@"%@ %@ %@", type, LGBase64Encode(pubBlob), commentString];

    // SHA256 指纹（与 ssh-keygen 一致）
    uint8_t digest[SHA256_DIGEST_LENGTH];
    SHA256(pubBlob.bytes, pubBlob.length, digest);
    NSData *digestData = [NSData dataWithBytes:digest length:SHA256_DIGEST_LENGTH];
    NSString *b64 = LGBase64Encode(digestData);
    pair.SHA256Fingerprint = [NSString stringWithFormat:@"SHA256:%@", [b64 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]]];
    return pair;
}

@end
