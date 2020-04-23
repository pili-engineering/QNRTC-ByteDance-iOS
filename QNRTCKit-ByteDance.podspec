#
#  Be sure to run `pod spec lint QNRTCKit-ByteDance.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

    s.name      = 'QNRTCKit-ByteDance'
    s.version   = '1.0.2'
    s.summary   = 'Qiniu RTC SDK for iOS.'
    s.homepage  = 'https://github.com/pili-engineering/QNRTC-ByteDance-iOS'
    s.license   = 'Apache License, Version 2.0'
    s.author    = { "pili" => "pili-coresdk@qiniu.com" }
    s.source    = { :http => "https://sdk-release.qnsdk.com/QNRTCKit-ByteDance-v1.0.2.zip"}

   
    s.platform                = :ios
    s.ios.deployment_target   = '8.0'
    s.requires_arc            = true

    s.vendored_frameworks = ['Pod/Library/QNRTCKit.framework']

    s.frameworks = ['UIKit', 'AVFoundation', 'CoreGraphics', 'CFNetwork', 'AudioToolbox', 'CoreMedia', 'VideoToolbox']

end
