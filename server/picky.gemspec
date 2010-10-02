Gem::Specification.new do |s|
  s.name = 'picky'
  s.version = '0.0.4'
  s.author = 'Florian Hanke'
  s.email = 'florian.hanke+picky@gmail.com'
  s.homepage = 'http://floere.github.com/picky'
  s.rubyforge_project = 'http://rubyforge.org/projects/picky'
  s.description = 'Fast Combinatorial Ruby Search Engine'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Picky the Search Engine'
  s.executables = ['picky']
  s.default_executable = "picky"
  s.files = Dir["lib/**/*.rb", "lib/tasks/*.rake", "lib/picky/ext/ruby19/performant.c", "prototype_project/**/*"]
  s.test_files = Dir["spec/**/*_spec.rb"]
  
  s.extensions << 'lib/picky/ext/ruby19/extconf.rb'
  
  s.add_dependency 'bundler',          '>=0.9.26'
  s.add_dependency 'activesupport',    '2.3.8'
  s.add_dependency 'activerecord',     '2.3.8'
  s.add_dependency 'rack',             '1.2.1'
  s.add_dependency 'rack-mount',       '0.6.9'
  s.add_dependency 'rsolr',            '>=0.12.1'
  s.add_dependency 'sunspot',          '1.1.0'
  s.add_dependency 'text',             '0.2.0'
  s.add_dependency 'rack_fast_escape', '2009.06.24'
  
  s.add_development_dependency 'rspec'
end