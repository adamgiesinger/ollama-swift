# Ollama.podspec

Pod::Spec.new do |s|
  s.name             = 'Ollama'
  s.version          = '0.1.0'
  s.summary          = 'A Swift client for the Ollama API.'

  s.description      = <<-DESC
  An unofficial Swift client for interacting with the Ollama API, allowing you to integrate large language models into your macOS and iOS applications.
                       DESC

  s.homepage         = 'https://github.com/loopwork-ai/Ollama-Swift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'loopwork-ai' => 'your-email@example.com' }
  s.source           = { :git => 'https://github.com/loopwork-ai/Ollama-Swift.git', :tag => s.version.to_s }

  s.social_media_url = 'https://twitter.com/loopwork_ai'

  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'

  s.swift_version = '6.0'
  s.source_files = 'Sources/Ollama/**/*'

end
