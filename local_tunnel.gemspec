# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        =  'local_tunnel'
  s.version     =  '0.2.0'
  s.licenses    =  ['3BSD']
  s.summary     =  'Expose yourself to the world from Ruby'
  s.authors     =  ['Loic Nageleisen']
  s.email       =  'loic.nageleisen@gmail.com'
  s.bindir      =  'bin'
  s.executables << 'local_tunnel'
  s.files       =  Dir['lib/**/*.rb'] + Dir['bin/*']
  s.files      +=  Dir['[A-Z]*'] + Dir['test/**/*']
  s.description =  <<-EOT
    Localtunnel allows you to easily share a web service on your local
    development machine without messing with DNS and firewall settings.
  EOT

  s.required_ruby_version = '>= 2.3'

  s.add_development_dependency 'minitest', '~> 5.10'
  s.add_development_dependency 'sinatra', '~> 2.0'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rake', '~> 12.0'
end
