#!/bin/bash
# echo_off=1
# export ALL_PROXY="socks5h://host:port"
# export ALL_PROXY="socks5h://User:Password@host:port"
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
    mapfile -t b2_tokens <"$CONF" || exit 1
    if [ "${#b2_tokens[@]}" -le 0 ]; then
        xlogger "$TAG" E "b2_tokens 为空! 退出!"
        exit
    fi
else
    xlogger "$TAG" E "$CONF 不存在! 退出!"
    exit
fi

function checkin() {
    local HTTP_RESPONSE HTTP_STATUS JSON credit_info my_credit checkinDate checkGetMission current_user checkin_info date credit
    HTTP_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" 'https://www.vikacg.com/wp-json/b2/v1/getUserMission' \
        -H 'authority: www.vikacg.com' \
        -H 'accept: application/json, text/plain, */*' \
        -H 'accept-language: zh-CN,zh;q=0.9' \
        -H 'authorization: Bearer '"$1"'' \
        -H 'content-type: application/x-www-form-urlencoded' \
        -H 'cookie: b2_token='"$1"'' \
        -H 'dnt: 1' \
        -H 'origin: https://www.vikacg.com' \
        -H 'referer: https://www.vikacg.com/mission/today' \
        -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)' \
        --data-raw 'count=0&paged=1' \
        --compressed)
    # shellcheck disable=SC2001
    JSON=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
    HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    if [ "$HTTP_STATUS" != 200 ]; then
        xlogger "$TAG" E "请求失败: $HTTP_STATUS，是否未登录?"
    else
        credit_info=$(echo "$JSON" | jq -j .)

        my_credit=$(echo "$credit_info" | jq -j '.mission.my_credit')
        checkinDate=$(echo "$credit_info" | jq -j '.mission.date')
        checkGetMission=$(echo "$credit_info" | jq -j '.mission.credit')
        current_user=$(echo "$credit_info" | jq -j '.mission.current_user')
        if [ "$checkGetMission" = "0" ]; then
            xlogger "$TAG" I "ID $current_user 目前积分: $my_credit"
            HTTP_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" 'https://www.vikacg.com/wp-json/b2/v1/userMission' \
                -X 'POST' \
                -H 'authority: www.vikacg.com' \
                -H 'accept: application/json, text/plain, */*' \
                -H 'accept-language: zh-CN,zh;q=0.9' \
                -H 'authorization: Bearer '"$1"'' \
                -H 'content-length: 0' \
                -H 'cookie: b2_token='"$1"'' \
                -H 'dnt: 1' \
                -H 'origin: https://www.vikacg.com' \
                -H 'referer: https://www.vikacg.com/mission/today' \
                -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)' \
                --compressed)
            # shellcheck disable=SC2001
            checkin_info=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g' | jq -j .)
            if [ "$checkin_info" != "414" ]; then
                HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
                if [ "$HTTP_STATUS" != 200 ]; then
                    xlogger "$TAG" E "ID $current_user 签到失败：请求失败。可能的原因有：1、网络连接失败；2、cookie过期"
                else
                    date=$(echo "$checkin_info" | jq -j '.date')
                    credit=$(echo "$checkin_info" | jq -j '.credit')
                    my_credit=$(echo "$checkin_info" | jq -j '.mission.my_credit')
                    xlogger "$TAG" I "ID $current_user 在 $date 签到成功，获得积分：$credit 目前积分：$my_credit 请查看积分是否有变动"
                fi
            else
                xlogger "$TAG" E "ID $current_user 签到失败：是否重复签到？"
            fi
        else
            xlogger "$TAG" I "ID $current_user 今天已经签到，签到时间：$checkinDate ，签到获得积分：$checkGetMission ，目前积分：$my_credit"
        fi
    fi
}

for i in "${b2_tokens[@]}"; do
    checkin "$i"
done
