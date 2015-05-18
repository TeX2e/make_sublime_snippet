# make_sublime_snippet

- make\_ruby_snippet.sh

## Usage

enter the following command:

	./make_ruby_snippet.sh *.snip

## .snip file sample

ClassName.snip

	# 
	### comment using sharp(#)
	# 

	---constant---
	# 
	# NAN -> Float::NAN
	# !ARGV -> ARGV
	# 
	---class-method---
	# 
	# new(size) -> Array.new(size)
	# 
	---instance-method--
	# 
	# reject { |e| bool }
	# -> reject { |e| bool }
	# -> reject do |e|
	#      bool
	#    end
	# 
	---private-instance-method---
	# 
	# self.included(mod)
	# -> def self.included(mod)
	#      $0
	#    end
	# 
	# !alias_method(:new, :old)
	# -> alias_method :new, :old
	# 
	----seems-like--instance-method---
	# 
	### private-instance-method with { block }
	# 
	# define_method(sym) { block }
	# -> define_method(sym) { block }
	# -> define_method(sym) do
	#      block
	#    end
	# 
	---EOF---

	comment under --EOF--

