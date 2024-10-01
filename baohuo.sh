#!/bin/bash

# 从命令行参数获取配置
SERVERS_INFO="$1"
TELEGRAM_BOT_TOKEN="$2"
TELEGRAM_CHAT_ID="$3"

# 初始化日志内容
log=""
success_count=0
failure_count=0
failed_execs=""

# 发送电报消息函数
send_telegram_message() {
    local message=$1
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=Markdown" >/dev/null 2>&1
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
    commands_array=$(echo "$server_info" | jq -r '.commands[]')

    # 获取当前时间（北京时间）
    now=$(TZ='Asia/Shanghai' date +"%Y-%m-%d %H:%M:%S.%3N")

    # 执行每个命令并检查结果
    for cmd in $commands_array; do
        sshpass -p "$pwd" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -tt "$user@$ip" "$cmd" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            message="${user} (${ip}) 于北京时间 ${now} 执行\"${cmd}\"成功！"
            log+="${message}\n"
            success_count=$((success_count + 1))
        else
            message="${user} (${ip}) 于北京时间 ${now} 执行\"${cmd}\"失败！"
            log+="${message}\n"
            failed_execs+="${message}\n"
            failure_count=$((failure_count + 1))
        fi

        # 发送单个执行结果
        send_telegram_message "$message"
    done
done

# 总结统计信息
summary="执行结果统计：
成功执行的账号：${success_count}
执行失败的账号：${failure_count}"

# 如果有失败的执行，列出失败的账号
if [ $failure_count -gt 0 ]; then
    summary+="

执行失败的账号列表：
${failed_execs}"
fi

# 发送汇总信息
send_telegram_message "$summary"
