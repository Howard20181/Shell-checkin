# GLaDOS 签到脚本 - PowerShell 版本, 仅支持 Powershell 7

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
    Add-Content -Path "${TAG}.log" -Value $logMessage

    switch ($Level.ToUpper()) {
        "I" { 
            Write-Information $logMessage -InformationAction Continue
        }
        "W" { 
            Write-Warning $Message
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

# 读取配置文件
$CONF = Join-Path $BasePath "$TAG.conf"
if (Test-Path $CONF) {
    try {
        $cookies = Get-Content $CONF | Where-Object { $_.Trim() -ne "" }
        if ($cookies.Count -eq 0) {
            Write-XLogger -Tag $TAG -Level "E" -Message "cookies NULL! EXIT!"
            exit 1
        }
    }
    catch {
        Write-XLogger -Tag $TAG -Level "E" -Message "读取配置文件失败: $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-XLogger -Tag $TAG -Level "E" -Message "$CONF not found! EXIT!"
    exit 1
}

# 签到函数
function Invoke-Checkin {
    param(
        [string]$Cookie
    )
    
    try {
        $headers = @{
            'authority'       = 'glados.rocks'
            'accept'          = 'application/json, text/plain, */*'
            'accept-encoding' = 'gzip, deflate, br, zstd'
            'accept-language' = 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7'
            'content-type'    = 'application/json;charset=UTF-8'
            'cookie'          = $Cookie
            'dnt'             = '1'
            'origin'          = 'https://glados.rocks'
            'user-agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36'
            'priority'        = 'u=1, i'
        }
        
        $body = @{
            token = "glados.one"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri 'https://glados.rocks/api/user/checkin' `
            -Method Post `
            -Headers $headers `
            -Body $body `
            -ContentType 'application/json;charset=UTF-8' `
            -ErrorAction Stop
        
        $checkin_code = $response.code
        $message = $response.message
        $user_id = $null
        if ($response.list -and $response.list.Count -gt 0) {
            $user_id = $response.list[0].user_id
            $asset = $response.list[0].asset
            [int]$change = $response.list[0].change
            $latest_success = $response.list[0].detail
            $latest_success_time = (Get-Date -UnixTimeSeconds ($response.list[0].time / 1000))
            Write-XLogger -Tag $TAG -Level "I" -Message "ID $user_id 最近一次签到成功: $latest_success $change $asset, 时间: $latest_success_time"
        }
        else {
        }
        if ($checkin_code -eq 0) {
            Write-XLogger -Tag $TAG -Level "I" -Message "ID $user_id 签到成功: $message"
        }
        elseif ($checkin_code -eq 1) {
            Write-XLogger -Tag $TAG -Level "E" -Message "ID $user_id 签到失败: $message"
        }
        else {
            Write-XLogger -Tag $TAG -Level "W" -Message "ID $user_id 未知响应代码 ${checkin_code}: $message"
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode) {
            Write-XLogger -Tag $TAG -Level "E" -Message "签到失败: HTTP状态码 $statusCode"
        }
        else {
            Write-XLogger -Tag $TAG -Level "E" -Message "签到失败: $($_.Exception.Message)"
        }
    }
}

# 对每个 cookie 执行签到
foreach ($cookie in $cookies) {
    if (![string]::IsNullOrWhiteSpace($cookie)) {
        Invoke-Checkin -Cookie $cookie.Trim()
        Start-Sleep -Milliseconds 500  # 添加小延迟避免请求过快
    }
}

Write-XLogger -Tag $TAG -Level "I" -Message "签到脚本执行完成"
