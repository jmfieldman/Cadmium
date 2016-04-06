Pod::Spec.new do |s|

  s.name         = "Cadmium"
  s.version      = "0.10.1"
  s.summary      = "Core Data framework for Swift that uses concise syntax to ensure best practices and protect you from common Core Data pitfalls"

  s.description  = <<-DESC
                   Core Data framework for Swift that uses concise syntax to ensure best practices and protect you from common Core Data pitfalls.
                   DESC

  s.homepage     = "https://github.com/jmfieldman/Cadmium"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Jason Fieldman" => "jason@fieldman.org" }
  s.social_media_url = 'http://fieldman.org'

  s.ios.deployment_target = "8.0"
  s.watchos.deployment_target = "2.0"
  #s.osx.deployment_target = "10.10"
  #s.tvos.deployment_target = "9.0"

  s.source = { :git => "https://github.com/jmfieldman/Cadmium.git", :tag => "#{s.version}" }
  s.source_files = "Cadmium/*.swift"

  s.requires_arc = true
  s.frameworks = ['CoreData']

end
