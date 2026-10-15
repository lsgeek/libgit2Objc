#import "ViewController.h"
#import <libgit2Objc/libgit2Objc.h>

@interface ViewController ()

@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, copy) NSString *repoPath;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"libgit2Objc Demo";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    [LGRepository initializeLibgit2];

    // 顶部按钮
    UIStackView *buttons = [[UIStackView alloc] init];
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.spacing = 8;
    buttons.translatesAutoresizingMaskIntoConstraints = NO;

    [buttons addArrangedSubview:[self makeButton:@"1. 建仓库+提交" action:@selector(createRepo)]];
    [buttons addArrangedSubview:[self makeButton:@"2. 状态+历史" action:@selector(showStatusAndLog)]];
    [buttons addArrangedSubview:[self makeButton:@"3. 克隆" action:@selector(cloneRepo)]];

    // 日志输出
    self.logView = [[UITextView alloc] init];
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.logView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:buttons];
    [self.view addSubview:self.logView];

    [NSLayoutConstraint activateConstraints:@[
        [buttons.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [buttons.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [buttons.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.logView.topAnchor constraintEqualToAnchor:buttons.bottomAnchor constant:8],
        [self.logView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.logView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.logView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    self.repoPath = [docs stringByAppendingPathComponent:@"demo-repo"];
    [self log:@"就绪。仓库将创建在 Document/demo-repo\n"];
}

- (UIButton *)makeButton:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)log:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logView.text = [self.logView.text stringByAppendingString:text];
        [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
    });
}

#pragma mark - 步骤 1：建仓库 + 提交

- (void)createRepo {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.repoPath error:nil];

    LGRepository *repo = [LGRepository initializeAtPath:self.repoPath bare:NO error:&error];
    if (!repo) return [self log:[NSString stringWithFormat:@"❌ 初始化失败: %@\n", error.localizedDescription]];
    [self log:[NSString stringWithFormat:@"✅ 仓库已创建: %@\n", repo.workDirectoryPath]];

    [repo setConfigString:@"iOS Demo" forKey:@"user.name" error:nil];
    [repo setConfigString:@"ios@example.com" forKey:@"user.email" error:nil];

    LGSignature *sig = [LGSignature signatureWithName:@"iOS Demo" email:@"ios@example.com" error:&error];
    if (!sig) return [self log:[NSString stringWithFormat:@"❌ 签名失败: %@\n", error.localizedDescription]];

    NSString *readme = [self.repoPath stringByAppendingPathComponent:@"README.md"];
    [@"# iOS Demo\n" writeToFile:readme atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [repo.index addFileWithPath:@"README.md" error:&error];
    LGCommit *c1 = [repo commitWithMessage:@"Initial commit" author:sig committer:sig error:&error];
    if (!c1) return [self log:[NSString stringWithFormat:@"❌ 提交失败: %@\n", error.localizedDescription]];
    [self log:[NSString stringWithFormat:@"✅ 提交1: %@ %@\n", c1.shortOID, c1.summary]];

    NSString *code = [self.repoPath stringByAppendingPathComponent:@"main.m"];
    [@"int main() { return 0; }\n" writeToFile:code atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [repo.index addFileWithPath:@"main.m" error:&error];
    LGCommit *c2 = [repo commitWithMessage:@"Add main.m" author:sig committer:sig error:&error];
    if (c2) [self log:[NSString stringWithFormat:@"✅ 提交2: %@ %@\n", c2.shortOID, c2.summary]];
}

#pragma mark - 步骤 2：状态 + 历史

- (void)showStatusAndLog {
    NSError *error = nil;
    LGRepository *repo = [LGRepository repositoryAtPath:self.repoPath error:&error];
    if (!repo) return [self log:[NSString stringWithFormat:@"❌ 打开失败: %@\n", error.localizedDescription]];

    [self log:[NSString stringWithFormat:@"当前分支: %@\n", repo.currentBranchName]];

    NSArray *status = [repo statusWithError:&error];
    [self log:@"工作区状态:\n"];
    if (status.count == 0) [self log:@"  (干净)\n"];
    for (LGStatusEntry *entry in status) {
        [self log:[NSString stringWithFormat:@"  %@ [%@][%@]\n", entry.path, entry.indexStatus, entry.workdirStatus]];
    }

    NSArray *commits = [repo commitsWithMaxCount:0 error:&error];
    [self log:[NSString stringWithFormat:@"提交历史 (%lu 条):\n", (unsigned long)commits.count]];
    for (LGCommit *c in commits) {
        [self log:[NSString stringWithFormat:@"  %@  %@  <%@>\n", c.shortOID, c.summary, c.author.email]];
    }
}

#pragma mark - 步骤 3：克隆

- (void)cloneRepo {
    NSError *error = nil;
    NSString *clonePath = [self.repoPath stringByAppendingString:@"-clone"];
    [[NSFileManager defaultManager] removeItemAtPath:clonePath error:nil];

    LGRepository *clone = [LGRepository cloneFromURL:self.repoPath toPath:clonePath error:&error];
    if (!clone) return [self log:[NSString stringWithFormat:@"❌ 克隆失败: %@\n", error.localizedDescription]];

    [self log:[NSString stringWithFormat:@"✅ 克隆成功: %@\n", clone.workDirectoryPath]];
    [self log:[NSString stringWithFormat:@"  分支: %@, 远程: %@\n",
               clone.currentBranchName, [clone remoteNamesWithError:nil]]];
}

@end
