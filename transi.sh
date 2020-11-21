#!/bin/bash
# 英語->日本語 翻訳 (インタラクティブ)
#
# Translate-shell使用
#   sudo apt install translate-shell
#
# Usage:
#   ./transi.sh
#
#   基本
#     実行すると"# input text:"とでるので英文(空行なしの複数行)を入力し、
#     空行(改行のみの行)を入力すると日本語に翻訳した結果を表示する
#     翻訳前の英文の改行は空白に置換し、複数の空白は1つにする
#   簡易実行
#     行の最後に";;"があるとそれまでの入力を翻訳して結果を表示する
#   キャッシュ
#     実行した場所にtransi_cacheディレクトリがあればキャッシュが動作する
#   終了
#     Ctrl+c or Ctrl+d

CACHE_DIR=./transi_cache

PROMPT_INPUT="\n\e[36;1m# input text:\e[0m\n"
PROMPT_SRC="\n\e[32m# src text:\e[0m"
PROMPT_TRANS="\e[35m# translate:\e[0m"

REGEX_START_TRANS=";;$"


# 引数の日本語を英語に翻訳して標準出力に出力する
translate_en_ja() {
	text="$1"
	trans -no-warn -b en:ja "$text"
}

get_hash() {
	key="$1"
	printf "$key" | sha256sum | awk '{print $1}'
}

# キャッシュを保存する
# 失敗した場合、非0を返す
save_cache() {
	key="$1"
	value="$2"

	# キャッシュ用ディレクトリがない場合、何もしない
	if [ ! -d $CACHE_DIR ]; then
		return 1
	fi

	texthash=$(get_hash "$key")
	cachefile="$CACHE_DIR/$texthash.txt"
	echo "$key" >> $cachefile
	echo "$value" >> $cachefile
}

# キャッシュがあればその内容を出力し、0を返す
# ない場合、空文字列を出力し非0を返す
load_cache() {
	key="$1"

	# キャッシュ用ディレクトリがない場合、何もしない
	if [ ! -d $CACHE_DIR ]; then
		echo ""
		return 1
	fi

	texthash=$(get_hash "$key")
	cachefile="$CACHE_DIR/${texthash}.txt"
	if [ -f "$cachefile" ]; then
		same_text=false
		skip_f=false
		while read LINE || [ -n "$LINE" ]; do
			if $skip_f; then
				skip_f=false
				continue
			fi
			if $same_text; then
				printf "$LINE"
				return 0
			fi
			if [ "$LINE" = "$key" ]; then
				same_text=true
				skip_f=false
			else
				skip_f=true
			fi
		done < $cachefile
	fi

	echo ""
	return 1
}

printf "$PROMPT_INPUT"
text=""
while read LINE || [ -n "$LINE" ]; do
	# 次のループの文字列も使用する場合、真
	continue_text=true
	# 結果表示時に翻訳元も表示する場合、真
	detail_flag=true

	# REGEX_START_TRANSにマッチする場合、翻訳を実行する
	l=$(echo $LINE | sed -n "s/$REGEX_START_TRANS//p")
	if [ -n "$l" ]; then
		LINE=$l
		continue_text=false
		detail_flag=false
	fi

	# 文字列がある場合、バッファに保存する
	# 空行の場合、翻訳を開始する
	if [ -n "$LINE" ]; then
		# 改行なしで結合
		text=$(echo "$text $LINE" | sed -e "s/^ *//" -e "s/ *$//")
	else
		continue_text=false
	fi

	if $continue_text; then
		continue
	fi
	# 翻訳する文字列がない場合、翻訳しない
	if [ -z "$text" ]; then
		continue
	fi

	# 翻訳元表示
	$detail_flag && printf "$PROMPT_SRC\n"
	$detail_flag && echo $text | fmt
	$detail_flag && printf "$PROMPT_TRANS"

	# 翻訳結果表示
	cache_data=$(load_cache "$text")
	if [ $? -ne 0 ]; then
		result=$(translate_en_ja "$text")
		cache_mark="\n"
	else
		result="$cache_data"
		hash_head=$(get_hash "$text" | cut -c 1-2)
		cache_mark=" (cache $hash_head)\n"
	fi
	printf "${cache_mark}$result\n"

	# 翻訳結果がテキストと同じ場合、翻訳失敗とみなしてキャッシュしない
	if [ -z "$cache_data" -a "$text" != "$result" ]; then
		save_cache "$text" "$result"
	fi

	printf "$PROMPT_INPUT"
	text=""
done
