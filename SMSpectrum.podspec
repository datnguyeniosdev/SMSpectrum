Pod::Spec.new do |s|
  s.name             = 'SMSpectrum'
  s.version          = '1.0.0'
  s.summary          = 'High-performance audio spectrum visualization for iOS, powered by Metal.'
  s.description      = <<-DESC
    SMSpectrum is an audio spectrum visualization SDK inspired by Adobe After Effects'
    Audio Spectrum effect. It provides realtime FFT analysis via Accelerate and renders
    digital bars, analog lines, or analog dots through a Metal pipeline at 60/120 Hz.
  DESC

  s.homepage         = 'https://github.com/darrennguyen/SMSpectrum'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Darren Nguyen' => 'darren@example.com' }
  s.source           = { :git => 'https://github.com/darrennguyen/SMSpectrum.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_versions        = ['5.5', '5.6', '5.7', '5.8', '5.9']

  s.default_subspec = 'Core'

  s.subspec 'Renderer' do |r|
    r.source_files = 'Sources/SMSpectrumRenderer/**/*.{swift,h}'
    r.resource_bundles = {
      'SMSpectrumRenderer' => ['Sources/SMSpectrumRenderer/Resources/Shaders/*.metal']
    }
    r.frameworks = 'Metal', 'MetalKit', 'QuartzCore'
  end

  s.subspec 'Core' do |c|
    c.source_files = 'Sources/SMSpectrum/**/*.swift'
    c.dependency 'SMSpectrum/Renderer'
    c.frameworks = 'AVFoundation', 'Accelerate', 'Metal', 'MetalKit'
  end
end
