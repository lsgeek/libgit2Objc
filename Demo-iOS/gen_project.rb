#!/usr/bin/env ruby
# 生成 DemoApp.xcodeproj（依赖 CocoaPods 自带的 xcodeproj gem）
# 用法: ruby gen_project.rb
require 'xcodeproj'
require 'fileutils'

ROOT = __dir__
PROJ_PATH = File.join(ROOT, 'DemoApp.xcodeproj')

FileUtils.rm_rf(PROJ_PATH)
project = Xcodeproj::Project.new(PROJ_PATH)

target = project.new_target(:application, 'DemoApp', :ios, '15.0')

# 源码与资源
group = project.main_group.new_group('DemoApp')
Dir.glob(File.join(ROOT, 'DemoApp', '*.{h,m}')).each do |file|
  ref = group.new_reference(file)
  target.add_file_references([ref])
end
assets = group.new_reference(File.join(ROOT, 'DemoApp', 'Assets.xcassets'))
target.add_resources([assets])

# Info.plist 与编译设置
target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'DemoApp/Info.plist'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.libgit2objc.demoapp'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end

project.save
puts "已生成 #{PROJ_PATH}"
