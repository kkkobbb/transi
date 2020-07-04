#!/bin/bash
# 英語->日本語 翻訳 (インタラクティブ)
# 改行を取り除いて翻訳にかける
# 改行のみの行が入力されると翻訳を実行する
# 終了はCtrl+c
# Translate-shell使用
#   sudo apt install translate-shell

PROMPT_INPUT="\n\e[36;1m# input text:\e[0m\n"
PROMPT_SRC="\e[32m# src text:\e[0m\n"
PROMPT_TRANS="\e[35m# translate:\e[0m\n"

MARK_START_TRANS=";;$"


printf "$PROMPT_INPUT"
text=""
while read LINE || [ -n "$LINE" ]; do
	# MARK_START_TRANSを含む場合、この行のみすぐに翻訳を実行する
	l=$(echo $LINE | sed -n "s/$MARK_START_TRANS//p")
	if [ -n "$l" ]; then
		trans -b en:ja "$l"
		printf "$PROMPT_INPUT"
		continue
	fi

	# 文字列がある場合、バッファに保存する
	if [ -n "$LINE" ]; then
		# 改行なしで結合
		text="$text $LINE"
		continue
	fi

	# 改行のみの行があると翻訳を開始する
	if [ -z "$text" ]; then
		continue
	fi

	printf "$PROMPT_SRC"
	echo $text | fmt

	printf "$PROMPT_TRANS"
	trans -b en:ja "$text"

	printf "$PROMPT_INPUT"
	text=""
done
