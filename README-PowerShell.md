# PowerShell 签到脚本

本项目包含两个 PowerShell 签到脚本的实现，从原始的 Bash 脚本转换而来。

仅支持 Powershell 7

## 文件说明

### GLaDOS 签到脚本

- `GLaDOS-checkin.ps1` - GLaDOS 网站签到的 PowerShell 脚本
- `GLaDOS-checkin.conf` - GLaDOS 签到脚本的配置文件（存放 cookies）

### VikACG 签到脚本

- `VikACG-checkin.ps1` - VikACG 网站签到的 PowerShell 脚本
- `VikACG-checkin.ps1.conf` - VikACG 签到脚本的配置文件（存放 b2_tokens）

## 使用方法

### 1. 配置文件设置

#### GLaDOS 配置

编辑 `GLaDOS-checkin.conf` 文件，每行添加一个完整的 cookie 字符串：

```text
_ga=GA1.2.123456789.1234567890; _gid=GA1.2.987654321.0987654321; koa:sess=eyJ1c2VySWQiOjEyMzQ1...
```

#### VikACG 配置

编辑 `VikACG-checkin.ps1.conf` 文件，每行添加一个 b2_token：

```text
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczpcL1wvd3d3LnZpa2FjZy5jb20i...
```

### 2. 运行脚本

#### 基本运行

```powershell
# GLaDOS 签到
.\GLaDOS-checkin.ps1

# VikACG 签到
.\VikACG-checkin.ps1
```

#### 带参数运行

```powershell
# VikACG 使用代理
.\VikACG-checkin.ps1 -ProxyServer "socks5://127.0.0.1:1080"
```

### 3. 参数说明

#### 通用参数

- `-Debug` - 启用调试模式，显示详细的调试信息
- `-EchoOff` - 关闭控制台输出，只记录到日志

#### VikACG 特有参数

- `-ProxyServer` - 设置代理服务器，支持 socks5 和 http 代理

### 4. 自动化运行

#### 使用 Windows 任务计划程序

1. 打开"任务计划程序"
2. 创建基本任务
3. 设置触发器（如每天特定时间）
4. 设置操作：
   - 程序/脚本：`pwsh.exe`
   - 添加参数：`-ExecutionPolicy Bypass -File "C:\path\to\GLaDOS-checkin.ps1"`
   - 起始于：脚本所在目录

#### 使用 PowerShell 配置文件

在 PowerShell 配置文件中添加函数：

```powershell
function Start-DailyCheckin {
    & "C:\path\to\GLaDOS-checkin.ps1"
    & "C:\path\to\VikACG-checkin.ps1"
}
```

## 功能特点

### 相比原始 Bash 脚本的改进

1. **更好的错误处理** - 使用 PowerShell 的异常处理机制
2. **彩色输出** - 不同级别的日志使用不同颜色显示
3. **参数支持** - 支持命令行参数控制脚本行为
4. **Windows 集成** - 更好地与 Windows 系统集成
5. **代理支持** - VikACG 脚本支持代理设置
6. **延迟控制** - 添加请求间隔避免触发反爬虫机制

### 日志级别

- `I` (Info) - 信息，绿色显示
- `N` (Notice) - 通知，白色显示
- `W` (Warning) - 警告，黄色显示
- `E` (Error) - 错误，红色显示
- `C` (Critical) - 严重错误，深红色显示
- `A` (Alert) - 警报，洋红色显示
- `D` (Debug) - 调试信息，青色显示（仅在 Debug 模式下显示）

## 注意事项

1. **执行策略** - 首次运行可能需要设置 PowerShell 执行策略：

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **Cookie 获取** - 需要从浏览器开发者工具中获取有效的 cookie 或 token

3. **网络环境** - 确保网络连接正常，VikACG 可能需要代理

4. **定期更新** - Cookie 和 Token 可能会过期，需要定期更新配置文件

## 故障排除

### 常见错误

1. **"cookies NULL! EXIT!"** - 配置文件为空或格式错误
2. **"签到失败：请求失败"** - 网络连接问题或 cookie 过期
3. **"jq 未安装"** - 此错误仅出现在 Bash 版本中，PowerShell 版本不需要 jq

### 调试方法

1. 使用 `-Debug` 参数查看详细信息
2. 检查配置文件格式和内容
3. 验证网络连接和代理设置
4. 更新 cookie 或 token

## 更新日志

### v1.0 (2025-06-27)

- 初始版本
- 从 Bash 脚本转换为 PowerShell
- 添加彩色输出和参数支持
- 改进错误处理和日志记录
