platform :ios, "18.0"
source 'https://github.com/CocoaPods/Specs.git'
inhibit_all_warnings!
use_frameworks!

install! 'cocoapods',
            :warn_for_unused_master_specs_repo => false

# 全てのPodのワーニングを無効にする
inhibit_all_warnings!

target 'RadioSnap' do
	pod 'RxSwift'
	pod 'RxCocoa'
	pod 'RxGesture'
	pod 'RxOptional'
	pod 'RxWebKit'
	pod 'RxMapKit'
	pod 'RxCoreLocation'
	pod 'RxDataSources'
	pod 'Alamofire'
	pod 'AlamofireImage'
	pod 'FFPopup'
	pod 'pop', '~> 1.0'
	pod 'ffmpeg-kit-ios-full-gpl', :git => 'https://github.com/SilenceLove/ffmpeg-kit-ios-full-gpl'
end

post_install do |installer|
  xcode_base_version = `xcodebuild -version | grep 'Xcode' | awk '{print $2}' | cut -d . -f 1`
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      # Xcode 15以上で動作します(if内を追記)
      if config.base_configuration_reference && Integer(xcode_base_version) >= 15
        xcconfig_path = config.base_configuration_reference.real_path
        xcconfig = File.read(xcconfig_path)
        xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
        File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
      end
    end
  end
end
