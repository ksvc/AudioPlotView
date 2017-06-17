#
#  Be sure to run `pod spec lint KSYAduioPlotView.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name         = "KSYAduioPlotView"
  s.version      = "1.0.0"
  s.summary      = "Audio Waveform view"
  # s.description  = <<-DESC
                   # DESC
  s.homepage     = "https://github.com/sunyazhou13/AudioPlotView"
  s.license      = {:type => 'Proprietary', :text => <<-LICENSE
      Copyright 2017 kingsoft Ltd. All rights reserved.
      LICENSE
    }

  s.author             = { "sunyazhou" => "sunyazhou@kingsoft.com" }
  s.ios.deployment_target = '8.0'
  # s.osx.deployment_target = '10.8'
  s.source       = { :git => "https://github.com/sunyazhou13/AudioPlotView.git", 
                     :tag => s.version }
  s.exclude_files = ['KSYAduioPlotView/KSYPlotCircularBuffer.{h,c}', 'KSYAduioPlotView/KSYAudioFile.h']
  s.ios.frameworks = 'AudioToolbox','AVFoundation','GLKit', 'Accelerate'
  # s.osx.frameworks = 'AudioToolbox','AudioUnit','CoreAudio','QuartzCore','OpenGL','GLKit', 'Accelerate'
  s.requires_arc = true;
  s.source_files  = 'KSYAduioPlotView/*.{h,m,c}'
end
