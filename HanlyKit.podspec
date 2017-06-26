Pod::Spec.new do |s|
  s.name             = "HanlyKit"
  s.version          = "0.0.1"
  s.summary          = "A common Kit used on iOS."
  s.description      = <<-DESC
                       It is a common Kit used on iOS, which implement by Objective-C.
                       DESC
  s.homepage         = "https://github.com/LingyeHan/HanlyKit"
  # s.screenshots      = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "HanLingye" => "lingye.han@gmail.com" }
  s.source           = { :git => "https://github.com/LingyeHan/HanlyKit.git", :tag => s.version }
  # s.social_media_url = 'https://twitter.com/NAME'

  s.platform     = :ios, '8.0'
  # s.ios.deployment_target = '8.0'
  # s.osx.deployment_target = '10.9'
  s.requires_arc = true

  s.source_files = 'HanlyKit/*'
  # s.resources = 'Assets'

  # s.ios.exclude_files = 'Classes/osx'
  # s.osx.exclude_files = 'Classes/ios'
  # s.public_header_files = 'Classes/**/*.h'
  s.frameworks = 'Foundation', 'UIKit'

end
