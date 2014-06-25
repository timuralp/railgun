Gem::Specification.new do |s|
  s.name    = 'railgun'
  s.version = '0.0.1'
  s.date    = Time.now.strftime('%F')
  s.summary = 'A gem to provide a nailgun client'
  s.authors = ['timuralp']
  s.homepage = 'http://github.com/timuralp/railgun'
  s.email = 'timur.alperovich@gmail.com'
  s.description = 'Provides a Ruby client for the nailgun server.'

  s.files         = `git ls-files`.split("\n")
  s.require_paths = [ 'lib' ]
end
