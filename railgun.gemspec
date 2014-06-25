Gem::Specification.new do |s|
  s.authors = ['timuralp']
  s.date    = Time.now.strftime('%F')
  s.description = 'Provides a Ruby client for the nailgun server.'
  s.email = 'timur.alperovich@gmail.com'
  s.homepage = 'http://github.com/timuralp/railgun'
  s.license = 'MIT'
  s.name    = 'railgun'
  s.summary = 'A gem to provide a nailgun client'
  s.version = '0.0.1'

  s.files         = `git ls-files`.split("\n")
  s.require_paths = [ 'lib' ]
  s.required_ruby_version = '>= 1.9.1'
end
