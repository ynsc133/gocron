#!/bin/bash

# 从命令行参数获取配置
SERVERS_INFO="$1"
TELEGRAM_BOT_TOKEN="$2"
TELEGRAM_CHAT_ID="$3"

# 验证 JSON 格式
if ! echo "$SERVERS_INFO" | jq . >/dev/null 2>&1; then
    echo "Error: Invalid JSON format in SERVERS_INFO"
    exit 1
fi

# 初始化日志内容
log=""
success_count=0
failure_count=0
failed_execs=""

# 发送电报消息函数
send_telegram_message() {
    local message="$1"

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${message}" >/dev/null 2>&1
}

# 从 JSON 字符串解析服务器信息为数组
servers=$(echo "$SERVERS_INFO" | jq -c '.[]')

# 检查 JSON 是否正确解析
if [ -z "$servers" ]; then
    echo "Error: Failed to parse JSON. Please check the JSON format."
    exit 1
fi

# 循环遍历每个服务器信息
while IFS= read -r server_info; do
    ip=$(echo "$server_info" | jq -r '.ip')
    user=$(echo "$server_info" | jq -r '.user')
    pwd=$(echo "$server_info" | jq -r '.pwd')
    commands_array=$(echo "$server_info" | jq -r '.commands[]')

    now=$(TZ='Asia/Shanghai' date +"%Y-%m-%d %H:%M:%S.%3N")

    while IFS= read -r cmd; do
        sshpass -p "$pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -tt "$user@$ip" "$cmd" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            message="${user} (${ip}) 于北京时间 ${now} 执行命令成功：\"$cmd\""
            log+="${message}\n"
            ((success_count++))
        else
            message="${user} (${ip}) 于北京时间 ${now} 执行命令失败：\"$cmd\""
            log+="${message}\n"
            failed_execs+="${message}\n"
            ((failure_count++))
        fi
        send_telegram_message "$message"
    done < <(echo "$commands_array")
done < <(echo "$servers")

summary="执行结果统计：
成功执行的账号：${success_count}
执行失败的账号：${failure_count}"

if [ $failure_count -gt 0 ]; then
    summary+="

执行失败的账号列表：
${failed_execs}"
fi

send_telegram_message "$summary"
