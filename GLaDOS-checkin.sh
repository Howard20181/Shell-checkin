#!/bin/bash

# echo_off=1
BasePath=$(
    cd "$(dirname "$0")" || exit 1
    pwd
)
xlogger() {
    if [ -n "$3" ]; then
        case "$2" in
        "I")
            logger -t "$1" -p "info" "$3"
            ;;
        "N")
            logger -t "$1" -p "notice" "$3"
            ;;
        "W")
            logger -t "$1" -p "warn" "$3"
            ;;
        "E")
            logger -t "$1" -p "err" "$3"
            ;;
        "C")
            logger -t "$1" -p "crit" "$3"
            ;;
        "A")
            logger -t "$1" -p "alert" "$3"
            ;;
        "D")
            if [ "$DEBUG" = "1" ]; then
                logger -t "$1" -p "debug" "$3"
            fi
            ;;
        *)
            logger -t "$1" -p "info" "$3"
            ;;
        esac
        if [ -z "$echo_off" ]; then
            echo "$3"
        fi
    else
        echo "Usage: xlogger <TAG> <LEVEL> <MSG>"
    fi
}
TAG=$(basename "$0")
command -v jq >/dev/null 2>&1 || {
    xlogger "$TAG" E "jq 未安装! 退出!"
    exit 1
}
CONF="$BasePath"/$TAG.conf
if [ -f "$CONF" ]; then
    # shellcheck source=./$TAG.conf
    # shellcheck disable=SC1091
    mapfile -t cookies <"$CONF" || exit 1
    if [ "${#cookies[@]}" -le 0 ]; then
        xlogger "$TAG" E "cookies NULL! EXIT!"
        exit
    fi
else
    xlogger "$TAG" E "$CONF not found! EXIT!"
    exit
fi

function checkin() {
    local HTTP_RESPONSE checkin_info HTTP_STATUS checkin_code message user_id
    HTTP_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" 'https://glados.rocks/api/user/checkin' \
        -H 'authority: glados.rocks' \
        -H 'accept: application/json, text/plain, */*' \
        -H 'accept-language: zh-CN,zh;q=0.9' \
        -H 'content-type: application/json;charset=UTF-8' \
        -H 'cookie: '"$1"'' \
        -H 'dnt: 1' \
        -H 'origin: https://glados.rocks' \
        -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0' \
        --data-raw '{"token":"glados.one"}' \
        --compressed)
    checkin_info=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g' | jq -j .)
    HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    if [ "$HTTP_STATUS" != 200 ]; then
        xlogger "$TAG" E "签到失败：请求失败"
    else
        checkin_code=$(echo "$checkin_info" | jq -r .code)
        message=$(echo "$checkin_info" | jq -r .message)
        user_id=$(echo "$checkin_info" | jq -r .list[0].user_id)
        if [ "$checkin_code" = 0 ]; then
            xlogger "$TAG" I "ID $user_id 签到成功：$message"
        elif [ "$checkin_code" = 1 ]; then
            xlogger "$TAG" E "ID $user_id 签到失败：$message"
        fi
    fi
}

for i in "${cookies[@]}"; do
    checkin "$i"
done
