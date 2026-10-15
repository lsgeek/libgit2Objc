Pod::Spec.new do |s|
  s.name             = 'libgit2Objc'
  s.version          = '0.3.0'
  s.summary          = 'libgit2 的 Objective-C 封装 SDK，支持 iOS 与 macOS'
  s.description      = <<-DESC
    libgit2Objc 对 libgit2 (v1.8.4) 静态库做了面向对象的 Objective-C 封装，
    提供仓库管理、提交、分支、检出、状态、克隆等常用 Git 操作，
    底层以 XCFramework 形式预编译（iOS 真机/模拟器、macOS），开箱即用。
  DESC

  s.homepage         = 'https://github.com/lsgeek/libgit2Objc'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'lsgeek' => 'lsgeek@126.com' }
  s.source           = { :git => 'https://github.com/lsgeek/libgit2Objc.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'

  s.source_files        = 'libgit2Objc/Classes/**/*.{h,m}'
  s.public_header_files = 'libgit2Objc/Classes/*.h'

  # libgit2 预编译 XCFramework（iOS 真机 arm64 / iOS 模拟器 arm64+x86_64 / macOS arm64+x86_64）
  s.vendored_frameworks = 'External/libgit2/build/lib/libgit2.xcframework'

  # 若产物不存在（例如直接以源码方式 pod install），则现场编译 libgit2
  s.prepare_command = <<-CMD
    bash Scripts/build_libgit2.sh
  CMD

  s.frameworks = 'Security', 'CoreFoundation'
  s.libraries  = 'z', 'iconv'
  s.requires_arc = true
end
