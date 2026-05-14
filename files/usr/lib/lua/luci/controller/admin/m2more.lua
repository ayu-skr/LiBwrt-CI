module("luci.controller.admin.m2more", package.seeall)

function index()
    entry({"admin", "status", "m2aurora"}, template("m2more/aurora"), _("M2 Aurora 首页"), 1).dependent = true
    entry({"admin", "status", "m2more", "data"}, call("action_data")).leaf = true
    entry({"admin", "status", "m2more", "github_ci"}, call("action_github_ci_v2")).leaf = true
end

local function readfile(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local s = f:read("*a") or ""
    f:close()
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function shell(cmd)
    local f = io.popen(cmd .. " 2>/dev/null")
    if not f then return "" end
    local s = f:read("*a") or ""
    f:close()
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function esc(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "")
    return s
end

local function pair(k, v)
    return '"' .. k .. '":"' .. esc(v) .. '"'
end

local function ping_ms(host, fallback_ip)
    local t = shell("ping -c 1 -W 1 " .. host .. " | sed -n 's/.*time=\\([0-9.]*\\).*/\\1/p' | head -n1")
    local n = tonumber(t)
    if n then return string.format("%.0f ms", n) end

    if fallback_ip and fallback_ip ~= "" then
        t = shell("ping -c 1 -W 1 " .. fallback_ip .. " | sed -n 's/.*time=\\([0-9.]*\\).*/\\1/p' | head -n1")
        n = tonumber(t)
        if n then return string.format("%.0f ms", n) end
    end

    local ok = shell("nc -z -w 1 " .. host .. " 443 >/dev/null 2>&1 && echo ok")
    if ok == "ok" then return "可连接" end

    return "--"
end

local function get_model()
    local model = readfile("/tmp/sysinfo/model")
    if model == "" then model = readfile("/proc/device-tree/model"):gsub("%z", "") end
    if model == "" then model = "ZN-M2" end
    return model
end

local function get_hostname()
    local h = shell("uci -q get system.@system[0].hostname")
    if h == "" then h = shell("hostname") end
    if h == "" then h = "--" end
    return h
end

local function get_version()
    local v = shell(". /etc/openwrt_release 2>/dev/null; echo \"$DISTRIB_DESCRIPTION\"")
    if v == "" then v = "--" end
    return v
end

local function get_kernel()
    local k = shell("uname -r")
    if k == "" then k = "--" end
    return k
end

local function get_time()
    local t = shell("date '+%Y-%m-%d %H:%M:%S'")
    if t == "" then t = "--" end
    return t
end

local function get_uptime()
    local raw = readfile("/proc/uptime")
    local sec = tonumber(raw:match("^(%d+)")) or 0
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    local m = math.floor((sec % 3600) / 60)

    if d > 0 then return string.format("%d天 %d小时 %d分", d, h, m) end
    if h > 0 then return string.format("%d小时 %d分", h, m) end
    return string.format("%d分钟", m)
end

local function get_temp()
    local paths = {
        "/sys/class/thermal/thermal_zone0/temp",
        "/sys/class/thermal/thermal_zone1/temp",
        "/sys/class/thermal/thermal_zone2/temp",
        "/sys/class/hwmon/hwmon0/temp1_input",
        "/sys/class/hwmon/hwmon1/temp1_input",
        "/sys/class/hwmon/hwmon2/temp1_input"
    }

    for _, p in ipairs(paths) do
        local v = readfile(p)
        if v and v:match("^%-?%d+$") then
            local n = tonumber(v)
            if n then
                if n > 1000 then return string.format("%.1f°C", n / 1000) end
                return string.format("%.1f°C", n)
            end
        end
    end

    return "--"
end

local function get_load()
    local s = readfile("/proc/loadavg")
    local a, b, c = s:match("^(%S+)%s+(%S+)%s+(%S+)")
    if a then return a .. " / " .. b .. " / " .. c end
    return "--"
end

local function get_cpu_freq()
    local f = readfile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq")
    local n = tonumber(f or "")
    if n and n > 0 then return string.format("%.0f MHz", n / 1000) end
    return "--"
end

local function get_mem()
    local m = readfile("/proc/meminfo")
    local total = tonumber(m:match("MemTotal:%s+(%d+)")) or 0
    local avail = tonumber(m:match("MemAvailable:%s+(%d+)")) or 0
    local used = total - avail
    local pct = 0
    if total > 0 then pct = math.floor(used * 100 / total) end
    return string.format("%d%%", pct), string.format("%.0f MB / %.0f MB", used / 1024, total / 1024)
end

local function get_df(path)
    local s = shell("df -h " .. path .. " | awk 'NR==2{print $3\" / \"$2\" / \"$5}'")
    if s == "" then s = "--" end
    return s
end

local function get_lan_ip()
    local ip = shell("ip -4 addr show br-lan | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1")
    if ip == "" then ip = shell("uci -q get network.lan.ipaddr") end
    if ip == "" then ip = "--" end
    return ip
end

local function get_lan_ipv6()
    local ip = shell("ip -6 addr show br-lan scope global | awk '/inet6/{print $2}' | head -n2")
    if ip == "" then ip = "--" end
    return ip
end

local function get_wan_dev()
    local dev = shell("ip -4 route get 223.5.5.5 | awk '{for(i=1;i<=NF;i++) if($i==\"dev\") print $(i+1)}' | head -n1")
    if dev == "" then dev = shell("ip route | awk '/default/{print $5; exit}'") end
    if dev == "" then dev = "--" end
    return dev
end

local function get_wan_ip()
    local ip = shell("ip -4 route get 223.5.5.5 | awk '{for(i=1;i<=NF;i++) if($i==\"src\") print $(i+1)}' | head -n1")
    if ip == "" then ip = "--" end
    return ip
end

local function get_gateway()
    local gw = shell("ip route | awk '/default/{print $3; exit}'")
    if gw == "" then gw = "--" end
    return gw
end

local function get_dns()
    local dns = shell("awk '/nameserver/{print $2}' /tmp/resolv.conf.d/resolv.conf.auto /etc/resolv.conf 2>/dev/null | awk '!a[$0]++' | head -n6")
    if dns == "" then dns = "--" end
    return dns
end

local function get_rx_tx(dev)
    if dev == "--" then return "--", "--" end

    local line = shell("cat /proc/net/dev | grep '^[ ]*" .. dev .. ":'")
    local rx, tx = line:match(":%s*(%d+)%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+(%d+)")
    rx = tonumber(rx or 0)
    tx = tonumber(tx or 0)

    local function fmt(n)
        if n > 1024 * 1024 * 1024 then return string.format("%.2f GB", n / 1024 / 1024 / 1024) end
        if n > 1024 * 1024 then return string.format("%.2f MB", n / 1024 / 1024) end
        if n > 1024 then return string.format("%.2f KB", n / 1024) end
        return tostring(n) .. " B"
    end

    return fmt(rx), fmt(tx)
end

local function get_dhcp_count()
    local n = shell("[ -f /tmp/dhcp.leases ] && wc -l < /tmp/dhcp.leases")
    if n == "" then n = "0" end
    return n
end

local function get_dhcp_list()
    local s = shell("awk '{print $3\"  \"$4\"  \"$2}' /tmp/dhcp.leases 2>/dev/null | head -n10")
    if s == "" then s = "暂无 DHCP 租约" end
    return s
end

local function get_conntrack()
    local count = readfile("/proc/sys/net/netfilter/nf_conntrack_count")
    local max = readfile("/proc/sys/net/netfilter/nf_conntrack_max")
    if count == "" then count = "0" end
    if max == "" then max = "--" end
    return count .. " / " .. max
end

local function service_status(name)
    local s = shell("/etc/init.d/" .. name .. " running >/dev/null 2>&1 && echo running || echo stopped")
    if s == "running" then return "运行中" end
    return "未运行"
end


local function get_public_ip()
    local ip = shell("wget -qO- -T 3 http://4.ipw.cn 2>/dev/null | tr -d '\\n\\r '")
    if ip == "" or not ip:match("^%d+%.%d+%.%d+%.%d+$") then
        ip = shell("wget -qO- -T 3 http://api.ipify.org 2>/dev/null | tr -d '\\n\\r '")
    end
    if ip == "" or not ip:match("^%d+%.%d+%.%d+%.%d+$") then
        ip = shell("wget -qO- -T 3 http://ifconfig.me/ip 2>/dev/null | tr -d '\\n\\r '")
    end
    if ip == "" or not ip:match("^%d+%.%d+%.%d+%.%d+$") then
        ip = get_wan_ip()
    end
    if ip == "" then ip = "--" end
    return ip
end

local function get_local_listen_ports()
    local s = shell("netstat -lnt 2>/dev/null | awk 'NR>2{split($4,a,\":\"); p=a[length(a)]; if(p ~ /^[0-9]+$/) print p}' | sort -n | uniq | tr '\\n' ' '")
    if s == "" then
        s = shell("ss -lnt 2>/dev/null | awk 'NR>1{split($4,a,\":\"); p=a[length(a)]; if(p ~ /^[0-9]+$/) print p}' | sort -n | uniq | tr '\\n' ' '")
    end
    if s == "" then s = "--" end
    return s
end

local function get_firewall_redirect_ports()
    local s = shell("uci show firewall 2>/dev/null | grep '\\.src_dport=' | cut -d= -f2 | tr -d \"'\" | sort -n | uniq | tr '\\n' ' '")
    if s == "" then s = "--" end
    return s
end

local function scan_public_open_ports(ip)
    if ip == "" or ip == "--" then return "--" end

    local ports = {
        21, 22, 23, 25, 53, 80, 81, 88, 110, 123, 143, 443,
        445, 465, 587, 993, 995, 1433, 3306, 3389, 5000, 5432,
        6379, 7000, 7681, 7890, 8080, 8443, 9000, 9090, 9999
    }

    local result = {}

    for _, port in ipairs(ports) do
        local ok = shell("nc -z -w 1 " .. ip .. " " .. port .. " >/dev/null 2>&1 && echo open")
        if ok == "open" then
            table.insert(result, tostring(port))
        end
    end

    if #result == 0 then
        return "未检测到常见开放端口"
    end

    return table.concat(result, " ")
end

local function get_public_port_summary()
    local public_ip = get_public_ip()
    local scan_ports = scan_public_open_ports(public_ip)
    local listen_ports = get_local_listen_ports()
    local redirect_ports = get_firewall_redirect_ports()

    return public_ip, scan_ports, listen_ports, redirect_ports
end


local function get_public_ip()
    local ip = shell("wget -qO- -T 4 http://4.ipw.cn 2>/dev/null | tr -d '\\n\\r '")
    if ip == "" or not ip:match("^%d+%.%d+%.%d+%.%d+$") then
        ip = shell("wget -qO- -T 4 http://api.ipify.org 2>/dev/null | tr -d '\\n\\r '")
    end
    if ip == "" or not ip:match("^%d+%.%d+%.%d+%.%d+$") then
        ip = shell("wget -qO- -T 4 http://ifconfig.me/ip 2>/dev/null | tr -d '\\n\\r '")
    end
    if ip == "" then ip = "--" end
    return ip
end

local function get_online_port_scan(ip)
    if ip == "" or ip == "--" then
        return "--"
    end

    local scan = shell("wget -qO- -T 12 'https://api.hackertarget.com/nmap/?q=" .. ip .. "'")
    if scan == "" then
        return "--"
    end

    local low = scan:lower()
    if low:match("api count exceeded") or low:match("error") or low:match("usage") then
        return "扫描受限"
    end

    local result = {}

    for line in scan:gmatch("[^\n]+") do
        local p1 = line:match("^(%d+)/tcp%s+open")
        if p1 then
            table.insert(result, p1)
        end

        local p2 = line:match("^(%d+)/udp%s+open")
        if p2 then
            table.insert(result, p2 .. "/udp")
        end
    end

    if #result == 0 then
        return "未发现开放端口"
    end

    return table.concat(result, " ")
end

local function get_online_port_scan_summary()
    local cache_file = "/tmp/m2_online_port_scan.cache"
    local now = os.time()

    local cache = readfile(cache_file)
    if cache ~= "" then
        local ts, ip, ports = cache:match("^(%d+)|([^|]*)|(.*)$")
        ts = tonumber(ts)

        if ts and (now - ts) < 600 then
            if ip == "" then ip = "--" end
            if ports == "" then ports = "--" end
            return ip, ports
        end
    end

    local ip = get_public_ip()
    local ports = get_online_port_scan(ip)

    local f = io.open(cache_file, "w")
    if f then
        f:write(tostring(now) .. "|" .. tostring(ip or "--") .. "|" .. tostring(ports or "--"))
        f:close()
    end

    return ip, ports
end

local function has_module_keyword(keyword)
    local s = shell("lsmod | grep -i '" .. keyword .. "' | awk '{print $1}' | head -n20")
    if s ~= "" then return true, s end
    return false, ""
end

local function has_file_or_dir(path)
    local s = shell("[ -e '" .. path .. "' ] && echo yes")
    return s == "yes"
end

local function get_nss_loaded_modules()
    local s = shell("lsmod | grep -Ei '(^qca_nss|nss|qca.*nss)' | awk '{print $1}' | sort | uniq | tr '\\n' ' '")
    if s == "" then
        s = "--"
    end
    return s
end

local function get_nss_accel_summary()
    local loaded = get_nss_loaded_modules()
    local status = "未检测到 NSS 模块"
    local enabled = {}

    if loaded ~= "--" then
        status = "已加载"
    end

    local ok_drv = has_module_keyword("qca_nss_drv")
    local ok_dp = has_module_keyword("qca_nss_dp")
    local ok_crypto = has_module_keyword("qca_nss_crypto")
    local ok_ifb = has_module_keyword("nss_ifb")
    local ok_bridge = has_module_keyword("bridge_mgr")
    local ok_vlan = has_module_keyword("vlan")
    local ok_pppoe = has_module_keyword("pppoe")
    local ok_gre = has_module_keyword("gre")
    local ok_l2tp = has_module_keyword("l2tp")
    local ok_ipsec = has_module_keyword("ipsec")
    local ok_ipv4 = has_module_keyword("ipv4")
    local ok_ipv6 = has_module_keyword("ipv6")

    if ok_drv then table.insert(enabled, "NSS Driver") end
    if ok_dp then table.insert(enabled, "NSS DP") end
    if ok_crypto then table.insert(enabled, "NSS Crypto") end
    if ok_ifb then table.insert(enabled, "NSS IFB") end
    if ok_bridge then table.insert(enabled, "Bridge 加速") end
    if ok_vlan then table.insert(enabled, "VLAN 加速") end
    if ok_pppoe then table.insert(enabled, "PPPoE 加速") end
    if ok_gre then table.insert(enabled, "GRE 加速") end
    if ok_l2tp then table.insert(enabled, "L2TP 加速") end
    if ok_ipsec then table.insert(enabled, "IPSec 加速") end
    if ok_ipv4 then table.insert(enabled, "IPv4 加速") end
    if ok_ipv6 then table.insert(enabled, "IPv6 加速") end

    if has_file_or_dir("/sys/kernel/debug/qca-nss-drv") then
        table.insert(enabled, "debugfs qca-nss-drv")
    end

    if has_file_or_dir("/sys/kernel/debug/ecm") then
        table.insert(enabled, "ECM")
    end

    local sqm = shell("opkg list-installed 2>/dev/null | grep -E '^sqm-scripts-nss|^luci-app-sqm' | awk '{print $1}' | tr '\\n' ' '")
    if sqm ~= "" then
        table.insert(enabled, "SQM/NSS")
    end

    local accel = table.concat(enabled, " / ")
    if accel == "" then
        accel = "--"
    end

    return status, loaded, accel
end

local function get_rx_tx_bytes(dev)
    if not dev or dev == "" or dev == "--" then
        return "0", "0"
    end

    local rx = readfile("/sys/class/net/" .. dev .. "/statistics/rx_bytes")
    local tx = readfile("/sys/class/net/" .. dev .. "/statistics/tx_bytes")

    if rx == "" then rx = "0" end
    if tx == "" then tx = "0" end

    return rx, tx
end
function action_data()
    local http = require "luci.http"

    local mem_pct, mem_text = get_mem()
    local wan_dev = get_wan_dev()
    local rx, tx = get_rx_tx(wan_dev)
    local speed_rx_bytes, speed_tx_bytes = get_rx_tx_bytes(wan_dev)
    local nss_status, nss_modules, nss_accel = get_nss_accel_summary()
    local public_ip, public_open_ports = get_online_port_scan_summary()
    local public_ip, public_open_ports, local_listen_ports, firewall_redirect_ports = get_public_port_summary()

    local data = {
        pair("model", get_model()),
        pair("hostname", get_hostname()),
        pair("version", get_version()),
        pair("kernel", get_kernel()),
        pair("time", get_time()),
        pair("uptime", get_uptime()),

        pair("temperature", get_temp()),
        pair("cpu_freq", get_cpu_freq()),
        pair("load", get_load()),
        pair("mem_pct", mem_pct),
        pair("mem_text", mem_text),
        pair("overlay", get_df("/overlay")),
        pair("rootfs", get_df("/")),

        pair("lan_ip", get_lan_ip()),
        pair("lan_ipv6", get_lan_ipv6()),
        pair("wan_ip", get_wan_ip()),
        pair("wan_dev", wan_dev),
        pair("gateway", get_gateway()),
        pair("dns", get_dns()),
        pair("rx", rx),
        pair("tx", tx),
        pair("speed_rx_bytes", speed_rx_bytes),
        pair("speed_tx_bytes", speed_tx_bytes),
        pair("conntrack", get_conntrack()),
        pair("nss_status", nss_status),
        pair("nss_modules", nss_modules),
        pair("nss_accel", nss_accel),
        pair("public_ip", public_ip),
        pair("public_open_ports", public_open_ports),

        pair("google_latency", ping_ms("www.google.com", "8.8.8.8")),
        pair("github_latency", ping_ms("github.com", "140.82.112.4")),
        pair("youtube_latency", ping_ms("www.youtube.com", "8.8.8.8")),
        pair("openai_latency", ping_ms("openai.com", "104.18.33.45")),
        pair("bilibili_latency", ping_ms("www.bilibili.com", "8.8.8.8")),
        pair("baidu_latency", ping_ms("www.baidu.com", "180.101.50.242")),

        pair("dhcp_count", get_dhcp_count()),
        pair("dhcp_list", get_dhcp_list()),

        pair("passwall", service_status("passwall")),
        pair("mosdns", service_status("mosdns")),
        pair("lucky", service_status("lucky")),
        pair("gecoosac", service_status("gecoosac")),
        pair("dnsmasq", service_status("dnsmasq")),
        pair("dropbear", service_status("dropbear")),
        pair("firewall", service_status("firewall")),
        pair("network", service_status("network"))
    }

    http.prepare_content("application/json")
    http.write("{" .. table.concat(data, ",") .. "}")
end

local function gh_json_escape(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
         :gsub('"', '\\"')
         :gsub("\n", "\\n")
         :gsub("\r", "")
    return s
end

local function gh_pair(k, v)
    return '"' .. k .. '":"' .. gh_json_escape(v) .. '"'
end

local function gh_num_pair(k, v)
    v = tonumber(v) or 0
    return '"' .. k .. '":' .. tostring(v)
end

local function gh_repo_normalize(repo)
    repo = tostring(repo or "")
    repo = repo:gsub("^https://github.com/", "")
    repo = repo:gsub("^http://github.com/", "")
    repo = repo:gsub("^github.com/", "")
    repo = repo:gsub("/actions.*$", "")
    repo = repo:gsub("/releases.*$", "")
    repo = repo:gsub("/+$", "")

    local owner, name = repo:match("^([^/]+)/([^/]+)$")
    if not owner or not name then return nil, nil end

    owner = owner:gsub("[^A-Za-z0-9_.-]", "")
    name = name:gsub("[^A-Za-z0-9_.-]", "")

    if owner == "" or name == "" then return nil, nil end
    return owner, name
end

local function gh_today_utc_prefix()
    return os.date("!%Y-%m-%d")
end

local function gh_wget(url)
    local token = readfile("/etc/github_token")
    local cmd

    if token ~= "" then
        cmd = "wget -qO- -T 12 --header='Accept: application/vnd.github+json' --header='Authorization: Bearer " .. token .. "' '" .. url .. "'"
    else
        cmd = "wget -qO- -T 12 --header='Accept: application/vnd.github+json' '" .. url .. "'"
    end

    return shell(cmd)
end

local function gh_extract_runs(json)
    local runs = {}

    if not json or json == "" then return runs end

    for obj in json:gmatch('{"id":.-"run_attempt":.-}') do
        local id = obj:match('"id":(%d+)')
        local status = obj:match('"status":"([^"]*)"') or ""
        local conclusion = obj:match('"conclusion":([^,}]+)')
        local created_at = obj:match('"created_at":"([^"]*)"') or ""
        local updated_at = obj:match('"updated_at":"([^"]*)"') or ""

        if conclusion then
            conclusion = conclusion:gsub('"', ''):gsub("null", "")
        else
            conclusion = ""
        end

        if id and created_at ~= "" then
            table.insert(runs, {
                id = id,
                status = status,
                conclusion = conclusion,
                created_at = created_at,
                updated_at = updated_at
            })
        end
    end

    return runs
end

local function gh_artifact_count(owner, repo, run_id)
    local url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/actions/runs/" .. run_id .. "/artifacts?per_page=100"
    local json = gh_wget(url)

    if json == "" then return 0 end

    local count = 0

    for obj in json:gmatch('{"id":.-"archive_download_url":.-}') do
        local expired = obj:match('"expired":([^,}]+)') or "false"
        local name = obj:match('"name":"([^"]*)"') or ""
        local low = name:lower()

        if expired ~= "true" then
            if low:find("firmware", 1, true)
                or low:find("openwrt", 1, true)
                or low:find("libwrt", 1, true)
                or low:find("immortalwrt", 1, true)
                or low:find("sysupgrade", 1, true)
                or low:find("factory", 1, true)
                or low:find("rootfs", 1, true)
                or low:find("bin", 1, true)
                or low:find("img", 1, true)
                or name:find("固件", 1, true)
            then
                count = count + 1
            end
        end
    end

    return count
end

function action_github_ci()
    local http = require "luci.http"

    local repo_arg = http.formvalue("repo") or ""
    local owner, repo = gh_repo_normalize(repo_arg)

    http.prepare_content("application/json")

    if not owner or not repo then
        http.write('{"ok":false,"error":"仓库格式错误"}')
        return
    end

    local today = gh_today_utc_prefix()
    local cache_dir = "/tmp/m2_github_ci"
    local cache_file = cache_dir .. "/" .. owner .. "_" .. repo .. ".json"

    shell("mkdir -p " .. cache_dir)

    local now = os.time()
    local cached = readfile(cache_file)

    if cached ~= "" then
        local ts = tonumber(cached:match('"_cache_ts":(%d+)') or "0") or 0
        if now - ts < 180 then
            http.write(cached)
            return
        end
    end

    local url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/actions/runs?per_page=50"
    local json = gh_wget(url)

    if json == "" then
        http.write('{"ok":false,"error":"GitHub 请求失败"}')
        return
    end

    if json:find("API rate limit exceeded", 1, true) then
        http.write('{"ok":false,"error":"请求受限，可在 /etc/github_token 填写 GitHub Token"}')
        return
    end

    if json:find('"message":"Not Found"', 1, true) then
        http.write('{"ok":false,"error":"仓库不存在或私有仓库无权限"}')
        return
    end

    local runs = gh_extract_runs(json)

    local success = 0
    local failed = 0
    local firmware_runs = 0
    local latest_success = "--"

    for _, run in ipairs(runs) do
        if run.created_at:sub(1, 10) == today then
            if run.conclusion == "success" then
                success = success + 1
                latest_success = run.updated_at:sub(12, 16)

                local ac = gh_artifact_count(owner, repo, run.id)
                if ac > 0 then
                    firmware_runs = firmware_runs + 1
                end
            elseif run.conclusion == "failure"
                or run.conclusion == "cancelled"
                or run.conclusion == "timed_out"
                or run.conclusion == "startup_failure"
                or run.conclusion == "action_required"
            then
                failed = failed + 1
            end
        end
    end

    local out = "{"
        .. '"ok":true,'
        .. '"_cache_ts":' .. tostring(now) .. ','
        .. gh_pair("owner", owner) .. ","
        .. gh_pair("repo", repo) .. ","
        .. gh_num_pair("success", success) .. ","
        .. gh_num_pair("failed", failed) .. ","
        .. gh_num_pair("firmware", firmware_runs) .. ","
        .. gh_pair("latest_success", latest_success)
        .. "}"

    local f = io.open(cache_file, "w")
    if f then
        f:write(out)
        f:close()
    end

    http.write(out)
end

local function gh2_json_escape(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
         :gsub('"', '\\"')
         :gsub("\n", "\\n")
         :gsub("\r", "")
    return s
end

local function gh2_pair(k, v)
    return '"' .. k .. '":"' .. gh2_json_escape(v) .. '"'
end

local function gh2_num_pair(k, v)
    v = tonumber(v) or 0
    return '"' .. k .. '":' .. tostring(v)
end

local function gh2_normalize_repo(repo)
    repo = tostring(repo or "")
    repo = repo:gsub("^https://github.com/", "")
    repo = repo:gsub("^http://github.com/", "")
    repo = repo:gsub("^github.com/", "")
    repo = repo:gsub("/actions.*$", "")
    repo = repo:gsub("/releases.*$", "")
    repo = repo:gsub("/+$", "")

    local owner, name = repo:match("^([^/]+)/([^/]+)$")
    if not owner or not name then return nil, nil end

    owner = owner:gsub("[^A-Za-z0-9_.-]", "")
    name = name:gsub("[^A-Za-z0-9_.-]", "")

    if owner == "" or name == "" then return nil, nil end
    return owner, name
end

local function gh2_today_utc()
    return os.date("!%Y-%m-%d")
end

local function gh2_wget(url)
    local token = readfile("/etc/github_token")
    local cmd = ""

    if token ~= "" then
        cmd = "wget -qO- -T 15 --no-check-certificate --header='User-Agent: M2-Aurora-LuCI' --header='Accept: application/vnd.github+json' --header='Authorization: Bearer " .. token .. "' '" .. url .. "'"
    else
        cmd = "wget -qO- -T 15 --no-check-certificate --header='User-Agent: M2-Aurora-LuCI' --header='Accept: application/vnd.github+json' '" .. url .. "'"
    end

    return shell(cmd)
end

local function gh2_split_runs(json)
    local runs = {}

    if not json or json == "" then return runs end

    local normalized = json:gsub('},{"id":', '}\n{"id":')

    for line in normalized:gmatch("[^\n]+") do
        if line:find('"run_attempt"', 1, true) then
            local id = line:match('"workflow_runs":%[{"id":(%d+)') or line:match('^{"id":(%d+)')
            local created_at = line:match('"created_at":"([^"]+)"') or ""
            local updated_at = line:match('"updated_at":"([^"]+)"') or ""
            local conclusion = line:match('"conclusion":"([^"]+)"') or ""
            local status = line:match('"status":"([^"]+)"') or ""

            if id and created_at ~= "" then
                table.insert(runs, {
                    id = id,
                    created_at = created_at,
                    updated_at = updated_at,
                    conclusion = conclusion,
                    status = status
                })
            end
        end
    end

    return runs
end

local function gh2_run_has_artifact(owner, repo, run_id)
    local url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/actions/runs/" .. run_id .. "/artifacts?per_page=100"
    local json = gh2_wget(url)

    if json == "" then return false end

    local total = tonumber(json:match('"total_count":(%d+)') or "0") or 0
    if total <= 0 then return false end

    -- 只要成功的这一次 workflow 有 artifact，就认为这次成功出了固件/产物。
    -- 这样不会因为 artifact 名字不含 firmware/openwrt 而漏计。
    return true
end

function action_github_ci_v2()
    local http = require "luci.http"

    local repo_arg = http.formvalue("repo") or ""
    local force = http.formvalue("force") or ""
    local owner, repo = gh2_normalize_repo(repo_arg)

    http.prepare_content("application/json")

    if not owner or not repo then
        http.write('{"ok":false,"error":"仓库格式错误"}')
        return
    end

    local cache_dir = "/tmp/m2_github_ci_v2"
    local cache_file = cache_dir .. "/" .. owner .. "_" .. repo .. ".json"
    shell("mkdir -p " .. cache_dir)

    local now = os.time()
    local cached = readfile(cache_file)

    -- 非强制刷新时缓存 30 分钟
    if force ~= "1" and cached ~= "" then
        local ts = tonumber(cached:match('"_cache_ts":(%d+)') or "0") or 0
        if now - ts < 1800 then
            http.write(cached)
            return
        end
    end

    local url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/actions/runs?per_page=100"
    local json = gh2_wget(url)

    if json == "" then
        http.write('{"ok":false,"error":"GitHub 请求失败"}')
        return
    end

    if json:find("API rate limit exceeded", 1, true) then
        http.write('{"ok":false,"error":"请求受限，可填 /etc/github_token"}')
        return
    end

    if json:find('"message":"Not Found"', 1, true) then
        http.write('{"ok":false,"error":"仓库不存在或私有无权限"}')
        return
    end

    local today = gh2_today_utc()
    local runs = gh2_split_runs(json)

    local success = 0
    local failed = 0
    local firmware = 0
    local latest_success = "--"

    for _, run in ipairs(runs) do
        if run.created_at:sub(1, 10) == today then
            if run.conclusion == "success" then
                success = success + 1

                if latest_success == "--" or run.updated_at > latest_success then
                    latest_success = run.updated_at
                end

                if gh2_run_has_artifact(owner, repo, run.id) then
                    firmware = firmware + 1
                end
            elseif run.conclusion == "failure"
                or run.conclusion == "cancelled"
                or run.conclusion == "timed_out"
                or run.conclusion == "startup_failure"
                or run.conclusion == "action_required"
            then
                failed = failed + 1
            end
        end
    end

    local success_time = "--"
    if latest_success ~= "--" then
        success_time = latest_success:sub(12, 16)
    end

    local out = "{"
        .. '"ok":true,'
        .. '"_cache_ts":' .. tostring(now) .. ','
        .. gh2_pair("owner", owner) .. ","
        .. gh2_pair("repo", repo) .. ","
        .. gh2_num_pair("success", success) .. ","
        .. gh2_num_pair("failed", failed) .. ","
        .. gh2_num_pair("firmware", firmware) .. ","
        .. gh2_pair("latest_success", success_time)
        .. "}"

    local f = io.open(cache_file, "w")
    if f then
        f:write(out)
        f:close()
    end

    http.write(out)
end
