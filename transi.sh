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
#     実行すると"$"とでるので英文(空行なしの複数行)を入力し、
#     空行(改行のみの行)を入力すると日本語に翻訳した結果を表示する
#     翻訳前の英文の改行は空白に置換し、先頭末尾の空白を削除し、複数の空白は1つにする
#   簡易実行
#     行の最後に";;"があるとそれまでの入力を翻訳して結果を表示する
#   キャッシュ
#     実行した場所にtransi_cacheディレクトリを作成すればキャッシュが動作する
#     transi_cache/statディレクトリを作成すればキャッシュの追加情報を保存する
#       追加情報の項目は以下
#       * count: 参照した回数
#       * last modified: 最後に参照した日時
#   終了
#     Ctrl+c or Ctrl+d

CACHE_DIR="./transi_cache"
CACHE_STAT_DIR="$CACHE_DIR/stat"

# 追加情報の項目
# 翻訳回数
STAT_COUNT="count,"
# 最終更新日時
STAT_LAST_MODIFIED="last modified,"
# 終了記号
STAT_END=","

#PROMPT_INPUT="\e[36;1m# input text\e[0m\n"
#PROMPT_SRC="\e[32m# src text\e[0m\n"
#CACHE_MARK_TMPL="(cache %s) "
PROMPT_TRANS="\e[35m# %stranslate\e[0m\n"
PROMPT_INPUT="\e[36;1m$\e[0m "
PROMPT_SRC=""
CACHE_MARK_TMPL="(%s) "
#PROMPT_TRANS="\e[35m# %strns:\e[0m "

RE_START_TRANS=";;$"


# 引数の文章を翻訳して標準出力に出力する
# 文章の翻訳1パターンのみ
translate_sentences() {
	lang="$1"
	text="$2"
	trans -no-warn -b "$lang" "$text"
}

# 引数の単語を翻訳して標準出力に出力する
# 単語の意味を羅列
translate_word() {
	lang="$1"
	text="$2"
	trans -no-warn -no-ansi -show-languages=n -show-original=n -show-prompt-message=n -show-translation=n "$lang" "$text"
}

# 英語を日本語に翻訳して標準出力に出力する
# １単語のみか、文章かで内容を変える
translate_en_ja() {
	lang="en:ja"
	text="$1"

	if echo "$text" | grep -q " "; then
		translate_sentences "$lang" "$text"
	else
		translate_word "$lang" "$text"
	fi
}

get_hash() {
	key="$1"
	echo "$key" | sha256sum | awk '{print $1}'
}

# キャッシュを保存する
# 失敗した場合、非0を返す
#
# キャッシュファイルは以下の2行の組の繰り返し (ハッシュが衝突した場合、複数の組が記述される)
#   原文(英語)
#   翻訳結果
#
# 原文は改行なしの想定
# 翻訳結果は改行あり(単語の翻訳結果のみ)の想定
save_cache() {
	key="$1"
	value="$2"

	# キャッシュ用ディレクトリがない場合、何もしない
	if [ ! -d $CACHE_DIR ]; then
		return 1
	fi

	keyhash=$(get_hash "$key")
	cachefile="$CACHE_DIR/$keyhash.txt"
	echo "$key" >> $cachefile
	# 改行は"\\n"の3文字に置き換えて保存する
	value=$(echo "$value" | sed -z 's/\n/\\\\n/g')
	echo "$value" >> $cachefile

	return 0
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

	keyhash=$(get_hash "$key")

	update_cache_stat "$key" "$keyhash"

	cachefile="$CACHE_DIR/${keyhash}.txt"
	if [ -f "$cachefile" ]; then
		same_key=false
		skip_f=false
		while read LINE || [ -n "$LINE" ]; do
			if $skip_f; then
				skip_f=false
				continue
			fi
			if $same_key; then
				printf "$LINE"
				return 0
			fi
			if [ "$LINE" = "$key" ]; then
				# 指定されたキーの場合、次の行を返す
				same_key=true
				skip_f=false
			else
				# 指定されたキーでない場合、次のキーの行まで飛ぶ
				skip_f=true
			fi
		done < $cachefile
	fi

	echo ""
	return 1
}

# keyの行以降、STAT_ENDまでの間にあるitemの行を出力する
# ない場合、何も出力しない
read_cache_stat_item() {
	statfile=$1
	key=$2
	item=$3
	gawk 'BEGIN {flag=0} $0 == "'"$key"'" {flag=1} /^'"$item"'/ {if (flag==1) {print $0; exit}}' $statfile
}

# keyの行以降、STAT_ENDまでの間にあるitemの行を更新する
# itemがない場合、keyの直下に追加する
update_cache_stat_item() {
	statfile=$1
	key=$2
	item=$3
	value=$4

	# keyの行以降、STAT_ENDの行までの間にitemがあれば変更する
	# 変更した場合0、しなかった場合1を返す
	new_stat=$(gawk 'BEGIN {flag=0;exists=1} /^'"$item"'/ {if (flag==1) {exists=0; print "'"$item$value"'"; next}} $0 == "'"$key"'" {flag=1} /^,$/ {flag=0} {print $0} END {exit exists}' $statfile)

	# itemが見つけられなかった場合、keyの後にitemとvalueの行を追加する
	if [ "$?" == "1" ]; then
		new_stat=$(gawk '$0 == "'"$key"'" {print $0; print "'"$item$value"'"; next} {print $0}' $statfile)
	fi

	echo "$new_stat" > $statfile
}

# キャッシュ追加情報更新
# 無い場合、新規作成
update_cache_stat() {
	key="$1"
	keyhash="$2"

	# 追加情報用ディレクトリがない場合、何もしない
	if [ ! -d $CACHE_STAT_DIR ]; then
		return 1
	fi

	statfile="$CACHE_STAT_DIR/${keyhash}.txt"

	# ファイルがない(またはkeyの行がない)場合、keyの行を末尾にもつファイルを生成(更新)する
	grep -qF "$key" $statfile > /dev/null 2> /dev/null || printf "$key\n,\n" >> $statfile

	# count
	value_count=$(read_cache_stat_item "$statfile" "$key" "$STAT_COUNT" | sed "s/$STAT_COUNT//")
	test -z "$value_count" && value_count="0"
	value_count=$(expr $value_count + 1)
	update_cache_stat_item "$statfile" "$key" "$STAT_COUNT" "$value_count"

	# last modified
	value_last_modified=$(date "+%Y/%m/%d %H:%M:%S")
	update_cache_stat_item "$statfile" "$key" "$STAT_LAST_MODIFIED" "$value_last_modified"
}

# 先頭、末尾の空白文字を削除し、連続する空白文字を1つにする
normalize_space() {
	RE_SP="[ \f\n\r\t]"
	sed -e "s/^${RE_SP}*//" -e "s/${RE_SP}*$//" -e "s/${RE_SP}\+/ /g"
}

printf "\n$PROMPT_INPUT"
text=""
while read LINE || [ -n "$LINE" ]; do
	# 次のループの文字列も使用する場合、真
	continue_text=true
	# 結果表示時に翻訳元も表示する場合、真
	detail_flag=true

	# $RE_START_TRANSにマッチする場合、翻訳を実行する
	l=$(echo $LINE | sed -n "s/$RE_START_TRANS//p")
	if [ -n "$l" ]; then
		LINE=$l
		continue_text=false
		detail_flag=false
	fi

	# 文字列がある場合、バッファに保存する
	# 空行の場合、翻訳を開始する
	if [ -n "$LINE" ]; then
		# 改行なしで結合
		text=$(echo "$text $LINE" | normalize_space)
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
	$detail_flag && printf "$PROMPT_SRC%s" "$text" | fmt -s -w $(tput cols)

	# 翻訳結果表示
	cache_data=$(load_cache "$text")
	if [ $? -ne 0 ]; then
		# 翻訳実行
		result=$(translate_en_ja "$text")
		cache_mark=""
	else
		# キャッシュ使用
		result="$cache_data"
		hash_head=$(get_hash "$text" | cut -c 1-8)
		cache_mark=$(printf "$CACHE_MARK_TMPL" $hash_head)
	fi
	$detail_flag && printf "$PROMPT_TRANS" "$cache_mark"
	printf "$result"

	# 翻訳結果がテキストと同じ場合、翻訳失敗とみなしてキャッシュしない
	if [ -z "$cache_data" -a "$text" != "$result" ]; then
		save_cache "$text" "$result"
	fi

	printf "\n$PROMPT_INPUT"
	text=""
done
