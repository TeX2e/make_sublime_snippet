#! /bin/bash
# 
# Usage: command <snippet-file>
# 

function usage() {
	echo "Usage: command <snippet-file>"
}

[[ $# = 0 ]] && usage && exit 0

# use this 'eval echo -e $SNIPPET'
# vars :
#   $SNIPPET_STR  :content
#   $NORMAL_STR   :tabTrigger
#   $SNIPPET_DIR  :description
# 
export SNIPPET=\
'\<snippet\>\\n'\
'\\t\<content\>\<\!\[CDATA\[\\n'\
'$SNIPPET_STR\\n'\
'\]\]\>\</content\>\\n'\
'\\t\<tabTrigger\>$NORMAL_STR\</tabTrigger\>\\n'\
'\\t\<scope\>source.ruby\</scope\>\\n'\
'\\t\<description\>$SNIPPET_DIR\</description\>\\n'\
'\</snippet\>'

# convert { block } to 'do .. end'
function normal_block() {
	local STR=$*
	STR=$(
		echo $STR | 
		sed -e 's/ {/ do/' |        # { -> do
		sed -e 's/block }/.. }/' |  # block -> ..
		sed -e 's/bool }/.. }/' |   # bool -> ..
		sed -e 's/ }/ end/'         # } -> end
	)
	echo "$STR"
}

# convert 'val' to ${:val}
function snippet_var() {
	local STR=$*
	STR=$(
		echo $STR | 
		sed -e 's/\([a-zA-Z_][a-z_=0-9]*\)\([,)\|]\)/${:\1}\2/g' |  # var -> ${:var}
		sed -e 's/block }/${:block} }/g' |  # block -> ${:block}
		sed -e 's/bool }/${:bool} }/g'      # bool -> ${:bool}
	)

	VAR_NUM=5  # change only five variables
	for (( i = 1; i < VAR_NUM; i++ )); do
		STR=$(echo $STR | sed -e "s/\${:/$\{$i:/")  # ${:var} -> ${1:var}
	done

	echo "$STR"
}

# convert { block } to 'do block end'
function snippet_block() {
	local STR=$*
	STR=$(
		echo $STR | 
		sed -e 's/ { \$/ do\\n\\t$/' |  # { ${2:block} -> do\\n\\t${2:block}
		sed -e 's/ {/ do/' |      # { -> do
		sed -e 's/| /|\\n\\t/' |  # | -> |\n\t
		sed -e 's/ }/\\nend/' |   # } -> \n end
		sed -e 's/\t\${[1-9]:block}/\t${0:block}/' | # do ${2:block} -> do ${0:block}
		sed -e 's/\t\${[1-9]:bool}/\t${0:bool}/'     # do ${2:bool} -> do ${0:bool}
	)
	echo "$STR"
}

# convert 'def func' to 'def func\n\t$0\n'
function snippet_def() {
	local STR=$*
	STR=$(
		echo $STR | 
		sed -e 's/$/\\n\\t$0\\nend/'
	)
	echo "$STR"
}

for ruby_snip_file in $@; do
	if [[ ! -f $ruby_snip_file ]]; then
		echo "$ruby_snip_file: No such file or directory"
		continue
	fi

	SNIPPET_FILE=$ruby_snip_file
	SNIPPET_DIR=${ruby_snip_file%\.snip} # remove extention from filename

	# if snippet-file is not newer then snippet-dir, skip reading snippet-file.
	if [[ ! $SNIPPET_FILE -nt $SNIPPET_DIR ]]; then
		echo $SNIPPET_DIR
		continue
	else
		echo "$SNIPPET_DIR <"
	fi

	# make dir and modification timestamp
	mkdir $SNIPPET_DIR 2> /dev/null
	touch -m $SNIPPET_DIR/.update

	cat ${SNIPPET_FILE} | while read line; do
		# MODE flag
		if [[ $line =~ '--constant--' ]]; then
			MODE='constant'
			continue
		elif [[ $line =~ '--class-method--' ]]; then
			MODE='class-method'
			continue
		elif [[ $line =~ '--instance-method--' ]]; then
			MODE='instance-method'
			continue
		elif [[ $line =~ '--private-instance-method--' ]]; then
			MODE='private-instance-method'
			continue
		elif [[ $line =~ ^$ || $line =~ ^# ]]; then
			continue
		elif [[ $line =~ '--EOF--' ]]; then
			exit 0
		fi
		
		# constant
		# 
		# NAN -> Float::NAN
		# !ARGV -> ARGV
		# 
		if [[ $MODE = 'constant' ]]; then
			if [[ $line =~ '!' ]]; then
				NORMAL_STR=${line:1}
			else
				NORMAL_STR="$SNIPPET_DIR::$line"
			fi
			SNIPPET_STR=$NORMAL_STR

			eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet" &
			continue
		fi

		# public class methods
		# 
		# new(size) -> Array.new(size)
		# 
		if [[ $MODE = 'class-method' ]]; then
			NORMAL_STR=$SNIPPET_DIR.$line
			SNIPPET_STR=$(snippet_var $SNIPPET_DIR.$line)
			eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet" &

			# if snippet is '{ block }' , make snippet 'do .. end'
			if [[ $NORMAL_STR =~ }$ ]]; then
				NORMAL_STR=$(normal_block $NORMAL_STR)
				SNIPPET_STR=$(snippet_block $SNIPPET_STR)
				eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet" &
			fi
			continue
		fi

		# public instance methods
		# 
		# reject { |e| bool }
		# -> reject { |e| bool }
		# -> reject do |e|
		#      bool
		#    end
		# 
		if [[ $MODE = 'instance-method' ]]; then
			NORMAL_STR=$line
			SNIPPET_STR=$(snippet_var $line)
			eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet" &
			
			# if snippet is '{ block }' , make snippet 'do .. end'
			if [[ $NORMAL_STR =~ }$ ]]; then
				NORMAL_STR=$(normal_block $NORMAL_STR)
				SNIPPET_STR=$(snippet_block $SNIPPET_STR)
				eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet" &
			fi
			continue
		fi

		# private instance method
		# 
		# self.included(mod)
		# -> def self.included(mod)
		#      $0
		#    end
		# 
		# !alias_method(:new, :old)
		# -> alias_method :new, :old
		# 
		if [[ $MODE = 'private-instance-method' ]]; then
			if [[ $line =~ '!' ]]; then
				NORMAL_STR=${line:1}
				SNIPPET_STR=$(snippet_var $NORMAL_STR | tr '(' ' ' | tr -d ')' )
				eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet" &
				continue
			else
				NORMAL_STR="Def $line"
				SNIPPET_STR=$(snippet_var "def $line")
				SNIPPET_STR=$(snippet_def $SNIPPET_STR)
				eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet" &
				continue
			fi
		fi
	done

	wait
	
	# About all snippet-file under this $SNIPPET_DIR directory
	for file in $SNIPPET_DIR/*.sublime-snippet; do
		[[ -z $file ]] && break
		# if the timestamp of this snippet-file is older then $SNIPPET_DIR/.update file,
		# remove this snippet-file.
		if [[ $file -ot $SNIPPET_DIR/.update ]]; then
			echo "remove $file"
			rm "$file"
		fi
	done

	# remove tmp file
	rm $SNIPPET_DIR/.update
done










