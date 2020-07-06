#!/bin/bash
# 英語->日本語 翻訳 (インタラクティブ)
# 改行を取り除いて翻訳にかける
# 改行のみの行が入力されると翻訳を実行する
# 終了はCtrl+c
# Translate-shell使用
#   sudo apt install translate-shell

PROMPT_INPUT="\n\e[36;1m# input text:\e[0m\n"
PROMPT_SRC="\n\e[32m# src text:\e[0m\n"
PROMPT_TRANS="\e[35m# translate:\e[0m\n"

MARK_START_TRANS=";;$"


printf "$PROMPT_INPUT"
text=""
while read LINE || [ -n "$LINE" ]; do
	continue_text=true
	add_detail=true

	# MARK_START_TRANSを含む場合、翻訳を実行する
	l=$(echo $LINE | sed -n "s/$MARK_START_TRANS//p")
	if [ -n "$l" ]; then
		LINE=$l
		continue_text=false
		add_detail=false
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

	$add_detail && printf "$PROMPT_SRC"
	$add_detail && echo $text | fmt

	$add_detail && printf "$PROMPT_TRANS"
	trans -no-warn -b en:ja "$text"

	printf "$PROMPT_INPUT"
	text=""
done
