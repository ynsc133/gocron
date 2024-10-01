#!/bin/bash

# 从命令行参数获取配置
SERVERS_INFO="$1"
DINGTALK_WEBHOOK="$2"
TELEGRAM_BOT_TOKEN="$3"
TELEGRAM_CHAT_ID="$4"
KEYWORD="$5"

# 初始化日志内容
log=""
success_count=0
failure_count=0
failed_logins=""

# 发送电报消息函数
send_telegram_message() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=Markdown" >/dev/null 2>&1
}

# 发送钉钉消息函数
send_dingtalk_message() {
    local message=$1
    curl -s "${DINGTALK_WEBHOOK}" \
        -H 'Content-Type: application/json' \
        -d "{\"msgtype\": \"text\", \"text\": {\"content\": \"${message}\"}}"
}

# 从 JSON 字符串解析服务器信息为数组
servers=$(echo "$SERVERS_INFO" | jq -c '.[]')

# 检查 JSON 是否正确解析
if [ -z "$servers" ]; then
    echo "Error: Failed to parse JSON. Please check the JSON format."
    exit 1
fi

# 循环遍历每个服务器信息
for server_info in $servers; do
    # 使用 jq 解析 JSON
    ip=$(echo "$server_info" | jq -r '.ip')
    user=$(echo "$server_info" | jq -r '.user')
    pwd=$(echo "$server_info" | jq -r '.pwd')

    # 获取当前时间（北京时间）
    now=$(TZ='Asia/Shanghai' date +"%Y-%m-%d %H:%M:%S.%3N")

    # 使用 sshpass 执行 SSH 登录并运行命令
    sshpass -p "$pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -tt "$user@$ip" "ps -A" >/dev/null 2>&1

    # 检查上一个命令是否成功
    if [ $? -eq 0 ]; then
        message="${user} (${ip}) 于北京时间 ${now} 登录成功！"
        log+="${message}\n"
        success_count=$((success_count + 1))
    else
        message="${user} (${ip}) 于北京时间 ${now} 登录失败！"
        log+="${message}\n"
        failed_logins+="${message}\n"
        failure_count=$((failure_count + 1))
    fi

    # 发送单个登录结果
    send_dingtalk_message "$message"
    send_telegram_message "$message"
done

# 总结统计信息
summary="登录结果统计：
成功登录的账号：${success_count}
登录失败的账号：${failure_count}"

# 如果有失败的登录，列出失败的账号
if [ $failure_count -gt 0 ]; then
    summary+="

登录失败的账号列表：
${failed_logins}"
fi

# 发送汇总信息
send_dingtalk_message "$summary"
send_telegram_message "$summary"
