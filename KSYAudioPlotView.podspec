#
#  Be sure to run `pod spec lint KSYAudioPlotView.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name         = "KSYAudioPlotView"
  s.version      = "1.0.2"
  s.summary      = "Audio Waveform view"
  # s.description  = <<-DESC
                   # DESC
  s.homepage     = "https://github.com/sunyazhou13/AudioPlotView"
  s.license      = {:type => 'Proprietary', :text => <<-LICENSE
      Copyright 2017 kingsoft Ltd. All rights reserved.
      LICENSE
    }

  s.author             = { "sunyazhou" => "sunyazhou@kingsoft.com" }
  s.ios.deployment_target = '7.0'
  # s.osx.deployment_target = '10.8'
  s.source       = { :git => "https://github.com/sunyazhou13/AudioPlotView.git", 
                     :tag => s.version }
  s.ios.frameworks = 'AudioToolbox','AVFoundation','GLKit', 'Accelerate'
  # s.osx.frameworks = 'AudioToolbox','AudioUnit','CoreAudio','QuartzCore','OpenGL','GLKit', 'Accelerate'
  s.requires_arc = true;
  s.source_files  = 'KSYAudioPlotView/*.{h,m,c}'
end
