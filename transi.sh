#!/bin/bash
# 英語->日本語 翻訳 (インタラクティブ)
#
# Translate-shell使用
#   sudo apt install translate-shell
#
# Usage:
#   基本
#     実行すると"# input text:"とでるので英文(空行なしの複数行)を入力し、
#     改行のみの行を入力すると日本語に翻訳した結果を表示する
#     翻訳前に入力した英文の改行は削除し、複数の空白は1つにする
#   簡易実行
#     行の最後に";;"があるとそれまでの入力を翻訳して結果を表示する
#   終了
#     Ctrl+c or Ctrl+d

PROMPT_INPUT="\n\e[36;1m# input text:\e[0m\n"
PROMPT_SRC="\n\e[32m# src text:\e[0m\n"
PROMPT_TRANS="\e[35m# translate:\e[0m\n"

REGEX_START_TRANS=";;$"


# 引数の日本語を英語に翻訳して標準出力に出力する
translate_en_ja() {
	text="$1"
	trans -no-warn -b en:ja "$text"
}

printf "$PROMPT_INPUT"
text=""
while read LINE || [ -n "$LINE" ]; do
	continue_text=true
	detail_flag=true

	# REGEX_START_TRANSにマッチする場合、翻訳を実行する
	l=$(echo $LINE | sed -n "s/$REGEX_START_TRANS//p")
	if [ -n "$l" ]; then
		LINE=$l
		continue_text=false
		detail_flag=false
	fi

	if [ -n "$LINE" ]; then
		# 文字列がある場合、バッファに保存する
		# 改行なしで結合
		text="$text $LINE"
	else
		# 改行のみの行があると翻訳を開始する
		continue_text=false
	fi

	# 文章に続きがあると判断した場合、まだ翻訳しない
	if $continue_text; then
		continue
	fi
	# 翻訳する文字列がない場合、翻訳しない
	if [ -z "$text" ]; then
		continue
	fi

	$detail_flag && printf "$PROMPT_SRC"
	$detail_flag && echo $text | fmt

	$detail_flag && printf "$PROMPT_TRANS"
	translate_en_ja "$text"

	printf "$PROMPT_INPUT"
	text=""
done
