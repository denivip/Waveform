Pod::Spec.new do |s|
    s.platform              = :ios
    s.ios.deployment_target = "8.0"
    s.name                  = "Waveform"
    s.summary               = "DENIVIP Media"
    s.requires_arc          = true

    s.version               = "0.0.1"

    s.license               = { :type => "MIT", :file => "LICENSE" }
    s.author                = { "Anton Belousov" => "belousov@denivip.ru" }

    s.homepage              = "https://github.com/AntonBelousov/Waveform"

    s.source                = { :git => "https://github.com/AntonBelousov/Waveform.git", :tag => "0.0.1" }
    s.source_files          = "Source/**/*.{swift}"
    s.frameworks            = "Foundation", "UIKit", "AVFoundation", "CoreMedia"
end