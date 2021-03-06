Gem::Specification.new do |s|
	s.name        = 'kanjidic'
	s.version     = '0.4.1'
	s.date        = '2016-10-26'
	s.summary     = "Extract and explore the KANJIDIC"
	s.description = "A gem to extract and explore the KANJIDIC (http://ftp.monash.edu.au/pub/nihongo/kanjidic.html)"
	s.authors     = ["Sylvain Leclercq"]
	s.email       = 'maisbiensurqueoui@gmail.com'
	s.files       = ["lib/kanjidic.rb"]
	s.homepage    =
		'http://www.github.com/de-passage/kanjidic'
	s.executables.concat ["kanjidic"]
	s.license       = 'MIT'
end
