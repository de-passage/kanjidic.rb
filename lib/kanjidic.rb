require "forwardable.rb"

module Kanjidic

	@@extractor ||= nil
	@@kana ||= :meaning # Oh look at that ugly global ! 
	@@dic ||= nil

	@@dictionaries = {
			H: :halpern,
			N: :nelson,
			V: :new_nelson,
			DA: :spahn_hadaminsky,
			DB: :AJLT,
			DC: :crowley,
			DF: :hodges_okazaki,
			DG: :kodansha,
			DH: :hensall,
			DJ: :nishiguchi_kono,
			DK: :halpern_2,
			DL: :halpern_3,
			DM: :maniette,
			DN: :heisig_6th,
			DO: :oneil_2,
			DP: :halpern_4,
			DR: :deroo,
			DS: :sakade,
			DT: :kask,
			E: :henshall,
			K: :gakken,
			L: :heisig,
			O: :oneil,
	}

	@@descriptions = { 
			halpern: '"New Japanese-English Character Dictionary" (1990), edited by Jack Halpern',
			nelson: '"Modern Reader\'s Japanese-English Character Dictionary", edited by Andrew Nelson',
			new_nelson: '"The New Nelson Japanese-English Character Dictionary", edited by John Haig',
			spahn_hadaminsky: '"Kanji & Kana book" (2011), by Spahn & Hadamitzky',
			AJLT: '"Japanese For Busy People" vols I-III, published by the AJLT',
			crowley: '"The Kanji Way to Japanese Language Power" by Dale Crowley',
			hodges_okazaki: '"Japanese Kanji Flashcards", by Max Hodges and Tomoko Okazaki (White Rabbit Press)',
			kodansha: '"Kodansha Compact Kanji Guide"',
			hensall: '"A Guide To Reading and Writing Japanese" 3rd edition, edited by Ken Hensall et al',
			nishiguchi_kono: '"Kanji in Context" by Nishiguchi and Kono',
			halpern_2: '"Kanji Learners Dictionary" 1999, edited by Jack Halpern (Kodansha)',
			halpern_3: '"Kanji Learners Dictionary" 2013, edited by Jack Halpern (Kodansha)',
			maniette: '"Les Kanji dans la tête", by Yves Maniette',
			heisig_6th: '"Remembering The Kanji, 6th Edition" by James Heisig',
			oneil_2: '"Essential Kanji", by P.G. O\'Neill',
			halpern_4: '"Kodansha Kanji Dictionary" (2013), by Jack Halpern',
			deroo: '"2001 Kanji" (Bonjinsha), by Father Joseph De Roo',
			sakade: '"A Guide To Reading and Writing Japanese" edited by Florence Sakade',
			kask: '"Tuttle Kanji Cards", compiled by Alexander Kask. ',
			henshall: '"A Guide To Remembering Japanese Characters" by Kenneth G. Henshall',
			gakken: '"A New Dictionary of Kanji Usage", by Nao\'omi Kuratani, Akemi Kobayashi',
			heisig: '"Remembering The Kanji" by James Heisig',
			oneil: '"Japanese Names" (1972), by P.G. O\'Neill. (Weatherhill)',
			morohasidaikanwajiten: '"Morohashi Daikanwajiten"'
	}

	# Very slow and quite nasty but works. Rework into one unified regex for efficiency
	@@patterns ||= { 
			/T([12])/ => lambda { |v| 
				case v.to_i
				when 1
					Kanjidic::kana = :'name reading'
				when 2
					Kanjidic::kana = :'radical name'
				end
			},
			/B(\d+)/ => :bushu, 
			/C(\d+)/ => :classical_radical,
			/F(\d+)/ => :frequency,
			/G(\d+)/ => :grade,
			/J(\d)/ => :JLPT,
			/Y(\S+)/ => :pinyin,
			/W(\w+)/ => :hangul,
			/P(\d+-\d+-\d+)/ => :SKIP,
			/S(\d+)/ => :strokes,
			/U(\h+)/ => -> (v) { { unicode: v.hex } },
			/Q([0-9.]*)/ => :four_corner,
			/M([NP])([0-9.XP]+)/ => lambda { |t, v| 
				key = case t 
					  when 'N' then :number
					  when 'P' then :page
					  else return nil
					  end
				{ dictionary: { morohasidaikanwajiten: { key => v } } }
			},
			/X([A-Z]{1,2})(\S+)/ => lambda { |t, v| 
				if t == "J" 
					{ crossreference: { 'JIS code': v[1..-1] } }
				else 
					{ crossreference: { dictionaries[t.to_sym] => v } }
				end 
			},
			/Z([BPRS])P(\S+)/ => lambda { |c, v|  
				key = case c
					  when 'S' then :stroke
					  when 'P' then :position
					  when 'B' then :both
					  when 'R' then :disagreement
					  else return nil
					  end
				{ misrepresentation: { key  => v } } 
			},
			/{([^}]+)}/ => lambda { |v| 
				v == "(kokuji)" ? { kokuji: true } : { :meanings => v } 
			},
			/(\W+)/ => lambda { |v| { Kanjidic::kana => v } }
	}.
	merge(
		@@dictionaries.map { |k,v| 
			[/#{k}(\d+A?)/, { dictionary: v }]
		}.to_h
	)

	def self.dictionaries
		@@dictionaries
	end

	def self.parse filename = "kanjidic"
		File.open(filename) do |f|
			f.map{ |l| extractor.call(l) }
		end
	end

	def self.extractor= ext
		@@extractor = ext
	end

	def self.extractor 
		@@extractor || lambda do |l| extract_kanji_info l end
	end

	def self.kana
		@@kana
	end

	def self.kana= k
		@@kana = k
	end

	def self.codes
		@@patterns
	end

	def self.open filename
		raise "Kanjidic already open (use Kanjidic::close if you want to reload it)" if @@dic
		@@dic = parse(filename)
		@@dic.freeze
	end

	def self.close 
		@@dic = nil
	end

	def self.open?
		!!@@dic
	end

	def self.method_missing sym, *args, &blck
		raise NoMethodError, "No method named #{sym} for Kanjidic" unless @@dic
		@@dic.send sym, *args, &blck
	end

	def self.extract_kanji_info line
		k = { dictionary: {} }
		elements = line.scan(/{[^}]+}|\S+/)
		# The two first elements are fixed 
		k[:character] = elements.shift
		k[:'JIS code'] = elements.shift
		# The rest is code based
		self.kana = :reading
		available_codes = codes.keys
		elements.each do |e|
			available_codes.each do |c|
				if m = e.match(/^#{c}$/)
					key = codes[c]
					value = m[1]
					if key.is_a? Symbol	
						insert k, key, value
					elsif key.is_a? Hash
						insert k, key.first[0], { key.first[1] => value }
					elsif key.respond_to? :call
						ret = key.call(*m[1..-1])
						insert k, ret.first[0], ret.first[1] if ret.is_a? Hash
					end
					break
				end
			end
		end
		return k
	end

	def self.format e, opt = {}
		if e.is_a? Array
			e.map { |el| format el, opt }.join("\n")
		elsif e.is_a? Hash
			opt = { character: 0, reading: 1, 'name reading': 2, 'radical name': 3, meanings: 4, dictionary: false }.merge(opt)
			ret = ""
			opt.sort_by { |_, value| value ? value : 0 }.to_h.each { |key, visible| ret += _to_s(key, e[key]) if visible and e[key] }
			e.each { |k,v| ret += _to_s k, v unless opt.has_key?(k) }
			ret
		else 
			raise ArgumentError, "Invalid parameter #{e}"
		end
	end

	def self.descriptions
		@@descriptions
	end

	private_class_method def self.insert hash, key, value 
		t = hash[key]
		if t.nil? 
			hash[key] = value 
		elsif t.is_a?(Array)
			hash[key] << value
		elsif t.is_a?(Hash)
			 value.each { |k,v| insert hash[key], k, v }
		else 
			hash[key] = [hash[key], value]
		end
	end

	private_class_method def self._to_s key, value, nesting = 1, resolve = false
		resolve = (resolve || key.to_s[/misrepresentation|crossreference/])
		ret = "#{key}:"
		if value.is_a? Hash 
			ret += "\n"
			value.each { |k, v| ret += " " * 2 * nesting + _to_s(k, v, nesting + 1, resolve) }
		elsif value.is_a? Array
			ret += " " + value.map{ |e| e.to_s + _resolve(key, e, resolve) }.join(", ") +  "\n"
		else 
			ret += " #{value}#{_resolve(key, value, resolve)}\n"
		end
		ret
	end

	private_class_method def self._resolve key, value, resolve
		return "" unless open? and resolve
		key = :SKIP if resolve == "misrepresentation"
		r = Kanjidic.find { |e| 
			(e[key] == value) || (e[:dictionary][key] == value)
		}		  
		r ? " (#{r[:character]})" : ""
	end

end

