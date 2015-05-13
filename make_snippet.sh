#! /bin/bash
# 
# Usage: mksnip <snippet-file>
# 

# use this 'eval echo -e $SNIPPET'
# vars :
#   $SNIPPET_STR   :description
#   $NORMAL_STR    :
#   $SNIPPET_DIR   :
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
		sed -e 's/ {/ do/' |                    # { -> do
		sed -e 's/\([a-z_][a-z_]*\) }/.. }/' |  # block -> ..
		sed -e 's/ }/ end/'                     # } -> end
	)
	echo "$STR"
}

# convert 'val' to ${:val}
function snippet_var() {
	local STR=$*
	STR=$(
		echo $STR | 
		sed -e 's/\([a-z_][a-z_]*\)\([,)\|]\)/${:\1}\2/g' |  # var -> ${:var}
		sed -e 's/block/${:block}/g'                         # block -> ${:block}
	)

	VAR_NUM=5  # only five variables changed
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
		sed -e 's/ {/ do/' |      # { -> do
		sed -e 's/| /|\\n\\t/' |  # | -> |\n\t
		sed -e 's/ }/\\nend/' |   # } -> \n end
		sed -e 's/\t\${[0-9]:\([a-z_][a-z_]*\)}/\t${0:\1}/'  # do ${2:block} -> do ${0:block}
	)
	echo "$STR"
}

# remove extention form filename
SNIPPET_FILE=$1
SNIPPET_DIR=${1%\.*}

echo $SNIPPET_DIR

mkdir $SNIPPET_DIR 2> /dev/null

cat ${SNIPPET_FILE} | while read line; do
	# MODE flag
	if [[ $line =~ 'class-method' ]]; then
		MODE='class-method'
		continue
	elif [[ $line =~ 'instance-method' ]]; then
		MODE='instance-method'
		continue
	elif [[ $line =~ ^$ ]]; then
		continue
	elif [[ $line =~ 'EOF' ]]; then
		exit 0
	fi
	
	# class methods
	if [[ $MODE = 'class-method' ]]; then
		NORMAL_STR=$SNIPPET_DIR.$line
		SNIPPET_STR=$(snippet_var $SNIPPET_DIR.$line)
		eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet"

		# if snippet is '{ block }' , make snippet 'do .. end'
		if [[ $NORMAL_STR =~ }$ ]]; then
			NORMAL_STR=$(normal_block $NORMAL_STR)
			SNIPPET_STR=$(snippet_block $SNIPPET_STR)
			eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet"
		fi
	fi

	# instance methods
	if [[ $MODE = 'instance-method' ]]; then
		NORMAL_STR=$line
		SNIPPET_STR=$(snippet_var $line)
		eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet"
		
		# if snippet is '{ block }' , make snippet 'do .. end'
		if [[ $NORMAL_STR =~ }$ ]]; then
			NORMAL_STR=$(normal_block $NORMAL_STR)
			SNIPPET_STR=$(snippet_block $SNIPPET_STR)
			eval echo -e $SNIPPET > "$SNIPPET_DIR/$NORMAL_STR.sublime-snippet"
		fi
	fi
done













