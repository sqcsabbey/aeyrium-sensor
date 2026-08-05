#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'aeyrium_sensor'
  s.version          = '1.0.0'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://www.aeyriu.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Aeyrium Inc' => 'diego@aeyrium.com' }
  s.source           = { :path => '.' }
  s.source_files = 'aeyrium_sensor/Sources/aeyrium_sensor/**/*.{h,m}'
  s.public_header_files = 'aeyrium_sensor/Sources/aeyrium_sensor/include/**/*.h'
  s.dependency 'Flutter'
  
  s.ios.deployment_target = '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end

