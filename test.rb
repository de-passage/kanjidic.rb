module Kanjidic
	@@extractor = nil
	def self.parse filename = "kanjidic"
		f = File.open(filename)
		f.map{ |l| extractor.call(l) }.tap{ f.close }
	end

	def self.extractor= ext
		@@extractor = ext
	end

	def self.extractor 
		@@extractor || lambda do |l| extract_kanji_info l end
	end

	def self.extract_kanji_info line
		k = { dictionary: {}, meanings: [] }
		elements = line.scan(/{[^}]+}|\S+/)
		# The two first elements are fixed 
		k[:character] = elements.shift
		k[:'JIS code'] = elements.shift
		# The rest is code based
		kana = :reading
		codes = { 
			'T' => lambda { |v| 
				case v.to_i
				when 1
					kana = :'name reading'
				when 2
					kana = :'radical name'
				end
			},
			'B' => :bushu, 
			'F' => :frequency,
			'G' => :grade,
			'Y' => :'chinese reading',
			'W' => :'korean reading', 
			'J' => :JLPT,
			'H' => :halpern
		}
		elements.each do |e|
			c = e[0]
			if ('A'..'Z').include? c # then it is a code
				r = codes[c]
				if r.respond_to? :call #if it's a lambda call it
					r.call c
				elsif r.is_a? Hash 
					key, value = r.first
					k[key] = {} unless k[key]
					k[key][value] = e[1..-1]
				elsif k[r]
					k[r] = [k[r], e[1..-1]].flatten
				else 
					k[r] = e[1..-1]
				end
			elsif c == "{" # then it is a meaning
				if e == "{(kokuji)}"
					k[:kokuji] = true
				else
					k[:meanings] << e[1...-1]
				end
			else 
				k[kana] = [] unless k[kana]
				k[kana] << e
			end
		end

		return k
	end

	private_class_method
	def self._insert hash, key, value

	end
end

