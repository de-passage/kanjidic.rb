require "forwardable.rb"

module Kanjidic

	@@dic ||= nil
	@@parser ||= nil

	# sym => [code, name, additional information]
	@@dictionaries ||= {
			:halpern => ['H', 'New Japanese-English Character Dictionary', '(1990), edited by Jack Halpern'],
			:nelson => ['N', 'Modern Reader\'s Japanese-English Character Dictionary', 'edited by Andrew Nelson'],
			:new_nelson => ['V', 'The New Nelson Japanese-English Character Dictionary', 'edited by John Haig'],
			:spahn_hadaminsky => ['DA', 'Kanji & Kana', '(2011), by Spahn & Hadamitzky'],
			:spahn_hadaminsky_2 => ['I', 'The Kanji Dictionary', "(1996), by Spahn and Hadaminsky"],
			:AJLT => ['DB', 'Japanese For Busy People', 'vols I-III, published by the AJLT'],
			:crowley => ['DC', 'The Kanji Way to Japanese Language Power', 'by Dale Crowley'],
			:hodges_okazaki => ['DF', 'Japanese Kanji Flashcards', 'by Max Hodges and Tomoko Okazaki (White Rabbit Press)'],
			:kodansha => ['DG', 'Kodansha Compact Kanji Guide'],
			:hensall => ['DH', 'A Guide To Reading and Writing Japanese', '3rd edition, edited by Ken Hensall et al'],
			:nishiguchi_kono => ['DJ', 'Kanji in Context', 'by Nishiguchi and Kono'],
			:halpern_2 => ['DK', 'Kanji Learners Dictionary (1999)', 'edited by Jack Halpern (Kodansha)'],
			:halpern_3 => ['DL', 'Kanji Learners Dictionary (2013)', 'edited by Jack Halpern (Kodansha)'],
			:maniette => ['DM', 'Les Kanji dans la tête', 'by Yves Maniette'],
			:heisig_6th => ['DN', 'Remembering The Kanji, 6th Edition', 'by James Heisig'],
			:oneil_2 => ['DO', 'Essential Kanji', 'by P.G. O\'Neill'],
			:halpern_4 => ['DP', 'Kodansha Kanji Dictionary', '(2013), by Jack Halpern'],
			:deroo => ['DR', '2001 Kanji', '(Bonjinsha), by Father Joseph De Roo'],
			:sakade => ['DS', 'A Guide To Reading and Writing Japanese', 'edited by Florence Sakade'],
			:kask => ['DT', 'Tuttle Kanji Cards', 'compiled by Alexander Kask. '],
			:henshall => ['E', 'A Guide To Remembering Japanese Characters', 'by Kenneth G. Henshall'],
			:gakken => ['K', 'A New Dictionary of Kanji Usage', 'by Nao\'omi Kuratani, Akemi Kobayashi'],
			:heisig => ['L', 'Remembering The Kanji', 'by James Heisig'],
			:oneil => ['O', 'Japanese Names', '(1972), by P.G. O\'Neill. (Weatherhill)'],
			:morohasidaikanwajiten => ['M', '大漢和辞典', "13 volumes, by Morohashi Tetsuji" ]
	}

	@@additional_codes ||= {
			classification_radical: ['B', "Nelson classification radical (部首)"],
			classical_radical: ['C', "Classical radical (部首)"],
			frequency: ['F', "Frequency in newspapers"],
			grade: ['G', "Grade taught"],
			jlpt: ['J', "JLPT level"],
			pinyin: ['Y', "Pinyin"],
			hangul: ['W', "Hangul"],
			skip_code: ['P', "SKIP"],
			strokes: ['S', "Stroke count"],
			unicode: ['U', "Unicode value"],
			four_corner_index: ['Q', '"Four Corner" index'],
			crossreference: ['X', "Cross-reference code"],
			misclassification: ['Z', "Mis-classification code"]
	}

	@@uncoded ||= {
		reading: "Reading",
		name_reading: "Name reading (名乗り)",
		radical_name: "Radical name",
		character: "Character",
		jis_code: "JIS code",
		meanings: "Meaning",
		kokuji: "Original Japanese character (国字)",
		dictionaries: "Dictionaries",
		number: 'Number',
		page: 'Page',
		position: "Position",
		both: "Stroke count and position",
		disagreement: "Disagreement over the number of strokes",
		undefined: "undefined"
	}

	@@codes ||= nil
	@@all_symbols ||= nil

	@@special_codes ||= {
		'T' => ->(_, value, sup) {
			case value.to_i
			when 1
				sup.call(:name_reading)
			when 2
				sup.call(:radical_name)
			end
			{}
		},
		'M' => ->(subcode, value, _) {
			{
				dictionaries: {
					morohasidaikanwajiten: {
						case subcode
						when 'N'
							:number
						when 'P'
							:page
						end => value
					}
				}
			}
		},
		'X' => ->(subcode, value, _) {
			{ crossreference:
				if subcode == "J"
					{ jis_code: value }
				elsif t = codes[subcode]
					t.call("", value, proc {})
				else
					{ undefined: value }
				end
			}
		},
		'Z' => ->(subcode, value, _) {
			key = case subcode[0]
				  when 'S' then :strokes
				  when 'P' then :position
				  when 'B' then :both
				  when 'R' then :disagreement
				  else :undefined
				  end
			{ misclassification: { key => value } }
		},
		'IN' => ->(_, value, _) {
			{ dictionaries: { spahn_hadaminsky: value } }
		}
	}

	# Load the Kanji dictionary
	#
	# Load a file at the location given in argument in the KANJIDIC format and parse it into a data structure in memory.
	#
	# Raise an exception if a file has already been loaded. See also Kanjidic::close, Kanjidic::expand
	def self.open filename, jis
		raise "Kanjidic already open (use Kanjidic::close first if you want to reload it, or Kanjidic::expand if you want to extend it)" if @@dic
		@@dic = build(filename, jis)
	end

	# Expand the Kanji dictionary
	#
	# Load a file, parse it and add its informations to an existing in-memory dictionary
	def self.expand filename, jis
		@@dic.concat build(filename, jis)
	end

	# Close the Kanji dictionary
	#
	# The Kanjidic is a big file, resulting in a big structure in memory.
	#
	# Use this function if you need to close it
	def self.close
		@@dic = nil
		GC.start
	end

	# Checks whether the Kanjidic is loaded
	#
	# Returns true if a Kanjidic is available to use through the Kanjidic module interface, false otherwise.
	def self.open?
		!!@@dic
	end

	# Parse a Kanjidic file
	#
	# Parse the file at the location given in argument and return a data structure representing it
	def self.build filename, jis
		File.open(filename) do |f|
			result = []
			f.each do |l|
				if r = parse(l, jis)
					result << r
				end
			end
			result
		end
	end

	# Parse a string in Kanjidic format
	#
	# Returns nil if the string doesn't start with a kanji, otherwise
	#
	# Returns a Hash containing the Kanji informations found in the String given in argument.

	# Refer to the Kanjidic homepage for details about the accepted structure of the string.
	def self.parse line, jis
		return nil if line =~ /^[[:ascii:]]/ #Anything that doesn't start with a (supposedly) kanji is treated as a comment
		elements = line.scan(/{[^}]+}|\S+/)
		kanji = { character: elements.shift, jis_code: jis.to_s + elements.shift, dictionaries: {} }
		kanji.extend self
		kana = :reading
		elements.each do |e|
			# We'll only consider the first match, because reasons
			# (namely a well formed file should never yield more than 1 match array)
			matches = e.scan(parser)[0]
			unless matches
				_insert kanji, { undefined: e }
			else
				matches.compact!
				case matches.length
				when 1 # It's a reading, see Kanjidic::parser
					_insert kanji, { kana => matches[0] }
				when 2 # It's a meaning, see Kanjidic::parser
					_insert kanji, { meanings: matches[1] }
				when 3 # It's a code, see Kanjidic::parser
					code, subcode, value = *matches
					_insert kanji, codes[code].call(subcode, value, ->(n) { kana = n })
				else raise "Unhandled case"
				end
			end
		end
		kanji
	end

	# Builds a Regexp for line parsing
	#
	#
	# Builds a Regexp based on the informations available in the @@dictionaries variables.
	#
	# Takes a boolean parameter to indicate whether the regexp should be constructed from
	# scratches as opposed to retrieved from a cached value, false by default (returns the cache).
	#
	#The resulting regexp will return matches as follow:
	#
	# 3 groups (code, sub code, value) if the element is code based,
	#
	# 2 groups ("{", content) if it is a bracket delimited string,
	#
	# 1 group (content) if it is a string of japanese characters
	def self.parser reload = false
		return @@parser if @@parser and !reload
		# It's gonna get ugly so here's the reasoning: take all the codes and check for them,
		# then take the remaining informations and refer it for later

		# First fetch the dictionary codes and assemble them in a A|B|DR|... fashion
		dic_codes = codes.keys.join("|")
		# Build the actual regexp.
		# The format is dic_code + optionaly 1 or 2 uppercase letters + kanji_code
		# OR {text with spaces} OR <japanese characters>
		@@parser = /(#{dic_codes})([A-Z]{0,2})(.+)|({)(.*)}|(\W+)/
	end

	# Return a hash of all the informations that will be used when building the dictionary
	#
	# The Hash is build from the values returned by Kanjidic::dictionaries and Kanjidic::additional_codes
	# and cached for further use.
	#
	# The parameter in a boolean indicating whether the value should be
	# fetched from the cache or rebuild (default to false: from cache)
	def self.codes reload = false
		return @@codes if @@codes and !reload
		@@codes = dictionaries.to_a.map { |e|
			sym, arr = *e
			[ arr[0], ->(s, v, _) { { dictionaries: { sym => s + v } } } ]
		}.to_h.
		merge(additional_codes.to_a.map { |e|
			sym, arr = *e
			[ arr[0], ->(s, v, _) { { sym => s + v } } ]
		}.to_h).merge(special_codes)
	end

	# Return a hash containing all the informations about dictionary codes
	#
	# Modifying the return value will change the behaviour of the module. See
	# implementation for details
	def self.dictionaries
		@@dictionaries
	end

	# Return a hash containing the informations about non dictionary codes
	#
	# Modifying the return value will change the behaviour of the module. See
	# implementation for details
	def self.additional_codes
		@@additional_codes
	end

	# Return a hash of all symbols used in the datastructure, associated with a description string
	#
	# The hash is build from the values returned by Kanjidic::dictionaries,
	# Kanjidic::additional_codes and Kanjidic::uncoded_symbols. Modifying it
	# will not affect the behaviour of the module.
	#
	# The hash is cached, reload
	# can be forced by passing true to the function.
	def self.all_symbols reload = false
		return @@all_symbols if @@all_symbols and !reload
		coded_symboles.merge(uncoded_symbols)
	end

	# Returns a hash of all symbols and their String representations
	def self.coded_symboles
		dictionaries.to_a.map { |e|
			sym, arr = *e
			[ sym, arr[1] ]
		}.to_h.
		merge(additional_codes.to_a.map { |e|
			sym, arr = *e
			[ sym, arr[1] ]
		}.to_h)
	end

	# Return a hash of all symboles not associated with a letter code
	#
	# The values are the description strings
	def self.uncoded_symbols
		@@uncoded
	end

	# Return a hash of all the special codes and associated Procs
	def self.special_codes
		@@special_codes
	end


	# Forward anything not specificaly defined to the dictionary array if it is
	# loaded
	def self.method_missing sym, *args, &blck
		raise NoMethodError,
			"No method named #{sym} for Kanjidic#{
		" (try loading the dictionary with Kanjidic::open first)" if [].respond_to?(sym)}" unless @@dic
		@@dic.send sym, *args, &blck
	end

	def to_s
		Kanjidic::format self,
			character: 0,
			reading: 1,
			name_reading: 2,
			radical_name: 3,
			meanings: 4,
			dictionaries: false
	end

	# Turns a Kanjidic entry into an easy to read string
	def self.format e, opt = {}
		if e.is_a? Array
			e.map { |el| format el, opt }.join("\n")
		elsif e.is_a? Hash
			opt = { character: 0 }.merge(opt)
			ret = ""
			opt.sort_by { |_, value| value ? value : 0 }.to_h.each { |key, visible| ret += _to_s(key, e[key]) if visible and e[key] }
			e.each { |k,v| ret += _to_s k, v unless opt.has_key?(k) }
			ret
		else
			raise ArgumentError, "Invalid parameter #{e}"
		end
	end

	# Insert values in a hash depending on the previous content of the hash
	#
	# Essentially a deep_merge implementation..
	private_class_method def self._insert hash, dic
		dic.each do |key, value|
			t = hash[key]
			# If the key doesn't exist, insert
			if t.nil?
				hash[key] = value
				# If the key exist and its value is an array, add to it
			elsif t.is_a?(Array)
				hash[key] << value
				# If the key exist  and its value is a hash, merge them following the rules of this function
			elsif t.is_a?(Hash)
				_insert hash[key], value
				# If the key exists and its value is anything else, build an array to contain the previous value and
				# the new one
			else
			hash[key] = [hash[key], value]
			end
		end
	end

	private_class_method def self._to_s key, value, nesting = 1, resolve = false
		resolve = (resolve || key == :crossreference)
		ret = "#{all_symbols[key] || key}:"
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
		r = Kanjidic.find { |e|
			(e[key] == value) || (e[:dictionaries][key] == value)
		}
		r ? " (#{r[:character]})" : ""
	end
end

