# VikACG 签到脚本 - PowerShell 版本, 仅支持 Powershell 7
param(
    [string]$ProxyServer  # 支持代理设置, 格式如: socks5://host:port 或 http://user:password@host:port
)

# 获取脚本基础路径
$BasePath = Split-Path -Parent $MyInvocation.MyCommand.Path

# 日志记录函数
function Write-XLogger {
    param(
        [string]$Tag,
        [string]$Level,
        [string]$Message
    )
    
    if ([string]::IsNullOrEmpty($Tag) -or [string]::IsNullOrEmpty($Level) -or [string]::IsNullOrEmpty($Message)) {
        Write-Host "Usage: Write-XLogger -Tag <TAG> -Level <LEVEL> -Message <MSG>"
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Tag] [$Level] $Message"
    Add-Content -Path "checkin.log" -Value $logMessage
    switch ($Level.ToUpper()) {
        "I" { 
            Write-Information $logMessage -InformationAction Continue
        }
        "E" { 
            Write-Error $Message -ErrorAction Continue
        }
        default { 
            Write-Information $logMessage -InformationAction Continue
        }
    }
}

# 获取脚本名称
$TAG = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

# 设置代理（如果指定）
if ($ProxyServer) {
    $env:ALL_PROXY = $ProxyServer
    Write-XLogger -Tag $TAG -Level "I" -Message "使用代理: $ProxyServer"
}

# 读取配置文件
$CONF = Join-Path $BasePath "$TAG.conf"
if (Test-Path $CONF) {
    try {
        $b2_tokens = Get-Content $CONF | Where-Object { $_.Trim() -ne "" }
        if ($b2_tokens.Count -eq 0) {
            Write-XLogger -Tag $TAG -Level "E" -Message "b2_tokens 为空! 退出!"
            exit 1
        }
    }
    catch {
        Write-XLogger -Tag $TAG -Level "E" -Message "读取配置文件失败: $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-XLogger -Tag $TAG -Level "E" -Message "$CONF 不存在! 退出!"
    exit 1
}

# 签到函数
function Invoke-Checkin {
    param(
        [string]$Token
    )

    try {
        # 第一步: 获取用户任务信息
        $headers = @{
            'authority'       = 'www.vikacg.com'
            'accept'          = 'application/json, text/plain, */*'
            'accept-encoding' = 'identity'
            'accept-language' = 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7'
            'authorization'   = "Bearer $Token"
            'content-type'    = 'application/json;charset=UTF-8'
            'cookie'          = "b2_token=$Token"
            'dnt'             = '1'
            'origin'          = 'https://www.vikacg.com'
            'priority'        = 'u=1, i'
            'referer'         = 'https://www.vikacg.com/wallet/mission'
            'user-agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36'
        }
        
        $body = @{
            count = 0
            paged = 1
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri 'https://www.vikacg.com/api/b2/v1/getUserMission' `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -ContentType 'application/json;charset=UTF-8' `
            -ErrorAction Stop

        $mission = $response.mission
        $my_credit = $mission.my_credit
        $checkinDate = $mission.date
        $checkGetMission = $mission.credit
        $current_user = $mission.current_user
        
        if ($checkGetMission -eq 0) {
            Write-XLogger -Tag $TAG -Level "I" -Message "ID $current_user 目前积分: $my_credit"
            
            # 第二步: 执行签到
            $checkinResponse = Invoke-RestMethod -Uri 'https://www.vikacg.com/api/b2/v1/userMission' `
                -Method Post `
                -Headers $headers `
                -ErrorAction Stop
            
            if ($checkinResponse -ne "414") {
                $date = $checkinResponse.date
                $credit = $checkinResponse.credit
                $new_my_credit = $checkinResponse.mission.my_credit
                Write-XLogger -Tag $TAG -Level "I" -Message "ID $current_user 在 $date 签到成功, 获得积分: $credit 目前积分: $new_my_credit 请查看积分是否有变动"
            }
            else {
                Write-XLogger -Tag $TAG -Level "E" -Message "ID $current_user 签到失败: 是否重复签到？"
            }
        }
        else {
            Write-XLogger -Tag $TAG -Level "I" -Message "ID $current_user 今天已经签到, 签到时间: $checkinDate , 签到获得积分: $checkGetMission , 目前积分: $my_credit"
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode) {
            if ($statusCode -ne 200) {
                $result = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($result)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();
                Write-XLogger -Tag $TAG -Level "E" -Message "请求失败: ${statusCode}: $responseBody, 是否未登录?"
            }
        }
        else {
            Write-XLogger -Tag $TAG -Level "E" -Message "ID $current_user 签到失败: 请求失败。可能的原因有: 1、网络连接失败; 2、cookie过期。错误详情: $($_.Exception.Message)"
        }
    }
}

# 对每个 token 执行签到
foreach ($token in $b2_tokens) {
    if (![string]::IsNullOrWhiteSpace($token)) {
        Invoke-Checkin -Token $token.Trim()
        Start-Sleep -Milliseconds 1000  # 添加延迟避免请求过快
    }
}

Write-XLogger -Tag $TAG -Level "I" -Message "签到脚本执行完成"
