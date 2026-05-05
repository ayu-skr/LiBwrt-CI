#!/bin/bash
set -e

echo "==== Create luci-app-znm2-dashboard ===="

# WRT-CORE.yml 会在 ./wrt/package/ 目录下执行 Scripts/Packages.sh
# 所以这里的 ./custom 实际就是 ./wrt/package/custom
rm -rf ./custom/luci-app-znm2-dashboard
mkdir -p ./custom/luci-app-znm2-dashboard/luasrc/controller
mkdir -p ./custom/luci-app-znm2-dashboard/luasrc/view
mkdir -p ./custom/luci-app-znm2-dashboard/root/etc/uci-defaults

cat > ./custom/luci-app-znm2-dashboard/Makefile <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-znm2-dashboard
PKG_VERSION:=1.1
PKG_RELEASE:=1

LUCI_TITLE:=ZN M2 iStoreOS Style Dashboard
LUCI_DEPENDS:=+luci-base +luci-compat
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
EOF

cat > ./custom/luci-app-znm2-dashboard/luasrc/controller/znm2_dashboard.lua <<'EOF'
module("luci.controller.znm2_dashboard", package.seeall)

local http = require "luci.http"
local sys  = require "luci.sys"

function index()
    -- 把状态页默认入口指向仪表盘
    entry({"admin", "status"}, alias("admin", "status", "znm2_dashboard"), _("状态"), 1).index = true

    -- 仪表盘页面
    entry({"admin", "status", "znm2_dashboard"}, template("znm2_dashboard"), _("首页"), 0).dependent = false

    -- 数据接口：/cgi-bin/luci/admin/status/znm2_dashboard/data
    entry({"admin", "status", "znm2_dashboard", "data"}, call("action_data")).leaf = true
end

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function readfile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return trim(data)
end

local function json_escape(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    return s
end

local function json_bool(v)
    return v and "true" or "false"
end

local function get_cpu_temp()
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
        local n = tonumber(v)
        if n then
            if n > 1000 then
                return string.format("%.1f", n / 1000)
            else
                return string.format("%.1f", n)
            end
        end
    end

    local v = trim(sys.exec("for f in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp*_input; do [ -f \"$f\" ] && cat \"$f\" && break; done 2>/dev/null"))
    local n = tonumber(v)

    if n then
        if n > 1000 then
            return string.format("%.1f", n / 1000)
        else
            return string.format("%.1f", n)
        end
    end

    return "--"
end

local function get_uptime()
    local up = tonumber((readfile("/proc/uptime") or "0"):match("^(%S+)")) or 0
    local d = math.floor(up / 86400)
    local h = math.floor((up % 86400) / 3600)
    local m = math.floor((up % 3600) / 60)

    if d > 0 then
        return string.format("%d天 %d小时 %d分", d, h, m)
    elseif h > 0 then
        return string.format("%d小时 %d分", h, m)
    else
        return string.format("%d分钟", m)
    end
end

local function get_load()
    local l = readfile("/proc/loadavg") or "0.00 0.00 0.00"
    local a, b, c = l:match("^(%S+)%s+(%S+)%s+(%S+)")
    return a or "0.00", b or "0.00", c or "0.00"
end

local function get_mem()
    local meminfo = readfile("/proc/meminfo") or ""
    local total = tonumber(meminfo:match("MemTotal:%s+(%d+)")) or 0
    local available = tonumber(meminfo:match("MemAvailable:%s+(%d+)")) or 0
    local used = total - available
    local percent = 0

    if total > 0 then
        percent = math.floor((used / total) * 100)
    end

    return {
        total = string.format("%.2f GB", total / 1024 / 1024),
        used = string.format("%.2f GB", used / 1024 / 1024),
        percent = percent
    }
end

local function get_rootfs()
    local line = trim(sys.exec("df -h /overlay 2>/dev/null | awk 'NR==2 {print $2\" \"$3\" \"$5}'"))
    if line == "" then
        line = trim(sys.exec("df -h / 2>/dev/null | awk 'NR==2 {print $2\" \"$3\" \"$5}'"))
    end

    local total, used, percent = line:match("^(%S+)%s+(%S+)%s+(%S+)")
    return {
        total = total or "--",
        used = used or "--",
        percent = percent or "--"
    }
end

local function get_model()
    local model = readfile("/tmp/sysinfo/model")
    if model and model ~= "" then return model end

    model = readfile("/proc/device-tree/model")
    if model and model ~= "" then return model end

    return "ZN M2"
end

local function get_hostname()
    local h = trim(sys.exec("uci -q get system.@system[0].hostname"))
    if h ~= "" then return h end

    h = readfile("/proc/sys/kernel/hostname")
    if h and h ~= "" then return h end

    return "LiBwrt"
end

local function get_firmware()
    local release = readfile("/etc/openwrt_release") or ""
    local desc = release:match("DISTRIB_DESCRIPTION='([^']+)'")
    if desc and desc ~= "" then return desc end

    local ver = trim(sys.exec("cat /etc/banner 2>/dev/null | head -n 1"))
    if ver ~= "" then return ver end

    return "LiBwrt / OpenWrt"
end

local function get_kernel()
    local k = trim(sys.exec("uname -r 2>/dev/null"))
    return k ~= "" and k or "--"
end

local function get_lan_ip()
    local ip = trim(sys.exec("ip -4 addr show br-lan 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1"))
    if ip == "" then
        ip = trim(sys.exec("uci -q get network.lan.ipaddr"))
    end
    return ip ~= "" and ip or "--"
end

local function get_wan_ip()
    local ip = trim(sys.exec("ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\") print $(i+1)}' | head -n1"))
    if ip == "" then
        ip = trim(sys.exec("ip -4 addr show pppoe-wan 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1"))
    end
    if ip == "" then
        ip = trim(sys.exec("ip -4 addr show wan 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1"))
    end
    return ip ~= "" and ip or "--"
end

local function get_gateway()
    local gw = trim(sys.exec("ip route 2>/dev/null | awk '/default/ {print $3; exit}'"))
    return gw ~= "" and gw or "--"
end

local function get_dns()
    local dns = trim(sys.exec("awk '/^nameserver/ {print $2}' /tmp/resolv.conf.d/resolv.conf.auto /tmp/resolv.conf.auto /etc/resolv.conf 2>/dev/null | sort -u | head -n 3 | paste -sd ',' -"))
    return dns ~= "" and dns or "--"
end

local function service_status(name)
    local running = sys.call("/etc/init.d/" .. name .. " running >/dev/null 2>&1")
    return running == 0
end

local function get_net_bytes()
    local dev = trim(sys.exec("ip route 2>/dev/null | awk '/default/ {print $5; exit}'"))
    if dev == "" then dev = "br-lan" end

    local rx = tonumber(readfile("/sys/class/net/" .. dev .. "/statistics/rx_bytes")) or 0
    local tx = tonumber(readfile("/sys/class/net/" .. dev .. "/statistics/tx_bytes")) or 0

    return dev, rx, tx
end

local function get_cpu_usage()
    local l1 = readfile("/proc/stat") or ""
    local u1, n1, s1, i1, w1, irq1, sirq1 = l1:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")

    u1 = tonumber(u1) or 0
    n1 = tonumber(n1) or 0
    s1 = tonumber(s1) or 0
    i1 = tonumber(i1) or 0
    w1 = tonumber(w1) or 0
    irq1 = tonumber(irq1) or 0
    sirq1 = tonumber(sirq1) or 0

    sys.call("sleep 1 >/dev/null 2>&1")

    local l2 = readfile("/proc/stat") or ""
    local u2, n2, s2, i2, w2, irq2, sirq2 = l2:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")

    u2 = tonumber(u2) or 0
    n2 = tonumber(n2) or 0
    s2 = tonumber(s2) or 0
    i2 = tonumber(i2) or 0
    w2 = tonumber(w2) or 0
    irq2 = tonumber(irq2) or 0
    sirq2 = tonumber(sirq2) or 0

    local idle1 = i1 + w1
    local idle2 = i2 + w2

    local total1 = u1 + n1 + s1 + i1 + w1 + irq1 + sirq1
    local total2 = u2 + n2 + s2 + i2 + w2 + irq2 + sirq2

    local totald = total2 - total1
    local idled = idle2 - idle1

    if totald <= 0 then return 0 end

    local usage = math.floor(((totald - idled) / totald) * 100)
    if usage < 0 then usage = 0 end
    if usage > 100 then usage = 100 end

    return usage
end

function action_data()
    local load1, load5, load15 = get_load()
    local mem = get_mem()
    local rootfs = get_rootfs()
    local dev, rx, tx = get_net_bytes()

    local json = string.format([[
{
  "hostname": "%s",
  "model": "%s",
  "firmware": "%s",
  "kernel": "%s",
  "uptime": "%s",
  "temp": "%s",
  "cpu": %d,
  "load": {
    "one": "%s",
    "five": "%s",
    "fifteen": "%s"
  },
  "mem": {
    "used": "%s",
    "total": "%s",
    "percent": %d
  },
  "rootfs": {
    "used": "%s",
    "total": "%s",
    "percent": "%s"
  },
  "lan_ip": "%s",
  "wan_ip": "%s",
  "gateway": "%s",
  "dns": "%s",
  "net": {
    "dev": "%s",
    "rx": %d,
    "tx": %d
  },
  "services": [
    {"name": "passwall", "running": %s},
    {"name": "mosdns", "running": %s},
    {"name": "lucky", "running": %s},
    {"name": "gecoosac", "running": %s}
  ]
}
]],
        json_escape(get_hostname()),
        json_escape(get_model()),
        json_escape(get_firmware()),
        json_escape(get_kernel()),
        json_escape(get_uptime()),
        json_escape(get_cpu_temp()),
        get_cpu_usage(),
        json_escape(load1),
        json_escape(load5),
        json_escape(load15),
        json_escape(mem.used),
        json_escape(mem.total),
        mem.percent,
        json_escape(rootfs.used),
        json_escape(rootfs.total),
        json_escape(rootfs.percent),
        json_escape(get_lan_ip()),
        json_escape(get_wan_ip()),
        json_escape(get_gateway()),
        json_escape(get_dns()),
        json_escape(dev),
        rx,
        tx,
        json_bool(service_status("passwall")),
        json_bool(service_status("mosdns")),
        json_bool(service_status("lucky")),
        json_bool(service_status("gecoosac"))
    )

    http.prepare_content("application/json")
    http.write(json)
end
EOF

cat > ./custom/luci-app-znm2-dashboard/luasrc/view/znm2_dashboard.htm <<'EOF'
<%+header%>

<style>
body {
    background: #f3f6fb !important;
}

.zn-wrap {
    padding: 8px 4px 32px;
    color: #172033;
}

.zn-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 18px;
}

.zn-head h1 {
    margin: 0;
    font-size: 28px;
    font-weight: 900;
}

.zn-head p {
    margin: 6px 0 0;
    color: #64748b;
}

.zn-btn {
    border: none;
    border-radius: 12px;
    padding: 10px 16px;
    background: #2563eb;
    color: #fff;
    font-weight: 800;
    cursor: pointer;
    box-shadow: 0 8px 20px rgba(37, 99, 235, .25);
}

.zn-grid {
    display: grid;
    grid-template-columns: repeat(12, 1fr);
    gap: 16px;
}

.zn-card {
    background: #fff;
    border-radius: 20px;
    padding: 18px;
    box-shadow: 0 12px 32px rgba(15, 23, 42, .08);
    border: 1px solid rgba(226, 232, 240, .9);
    overflow: hidden;
}

.zn-card h2 {
    margin: 0 0 14px;
    font-size: 17px;
    font-weight: 900;
}

.span-3 { grid-column: span 3; }
.span-4 { grid-column: span 4; }
.span-5 { grid-column: span 5; }
.span-7 { grid-column: span 7; }
.span-8 { grid-column: span 8; }
.span-12 { grid-column: span 12; }

.temp-card {
    background:
        radial-gradient(circle at 85% 15%, rgba(249, 115, 22, .28), transparent 32%),
        radial-gradient(circle at 5% 100%, rgba(37, 99, 235, .15), transparent 40%),
        #fff;
}

.temp-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.temp-value {
    font-size: 50px;
    font-weight: 950;
    color: #f97316;
    letter-spacing: -1px;
}

.temp-unit {
    font-size: 24px;
}

.temp-icon {
    width: 78px;
    height: 78px;
    border-radius: 24px;
    background: rgba(249, 115, 22, .14);
    display: grid;
    place-items: center;
    font-size: 42px;
}

.badge {
    display: inline-flex;
    padding: 6px 10px;
    border-radius: 999px;
    background: rgba(34, 197, 94, .12);
    color: #16a34a;
    font-size: 12px;
    font-weight: 900;
}

.badge.warn {
    background: rgba(249, 115, 22, .14);
    color: #f97316;
}

.badge.danger {
    background: rgba(239, 68, 68, .14);
    color: #ef4444;
}

.metric {
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.metric .num {
    font-size: 34px;
    font-weight: 950;
}

.metric .sub {
    font-size: 13px;
    color: #64748b;
}

.iconbox {
    width: 48px;
    height: 48px;
    border-radius: 16px;
    display: grid;
    place-items: center;
    color: white;
    font-size: 22px;
}

.blue { background: linear-gradient(135deg, #2563eb, #38bdf8); }
.green { background: linear-gradient(135deg, #16a34a, #86efac); }
.purple { background: linear-gradient(135deg, #7c3aed, #c084fc); }
.orange { background: linear-gradient(135deg, #f97316, #facc15); }

.progress {
    height: 9px;
    background: #e2e8f0;
    border-radius: 999px;
    overflow: hidden;
    margin-top: 14px;
}

.progress span {
    display: block;
    height: 100%;
    width: 0%;
    border-radius: 999px;
    background: linear-gradient(90deg, #2563eb, #06b6d4);
    transition: width .25s ease;
}

.progress.green span {
    background: linear-gradient(90deg, #22c55e, #86efac);
}

.progress.purple span {
    background: linear-gradient(90deg, #8b5cf6, #c084fc);
}

.info-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 11px 0;
    border-bottom: 1px solid #e5e7eb;
    gap: 18px;
}

.info-row:last-child {
    border-bottom: none;
}

.info-row span:first-child {
    color: #64748b;
    font-weight: 800;
}

.info-row span:last-child {
    font-weight: 900;
    text-align: right;
    word-break: break-all;
}

.service {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 0;
    border-bottom: 1px solid #e5e7eb;
}

.service:last-child {
    border-bottom: none;
}

.service-name {
    display: flex;
    align-items: center;
    gap: 10px;
    font-weight: 900;
}

.dot {
    width: 10px;
    height: 10px;
    border-radius: 999px;
    background: #ef4444;
    box-shadow: 0 0 0 5px rgba(239, 68, 68, .12);
}

.dot.ok {
    background: #22c55e;
    box-shadow: 0 0 0 5px rgba(34, 197, 94, .12);
}

.speed-box {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 14px;
}

.speed-card {
    border-radius: 16px;
    background: #f8fafc;
    padding: 15px;
}

.speed-card .label {
    color: #64748b;
    font-weight: 800;
}

.speed-card .value {
    margin-top: 8px;
    font-size: 28px;
    font-weight: 950;
}

.quick-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 14px;
}

.quick {
    display: block;
    padding: 16px;
    border-radius: 16px;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    text-decoration: none;
    color: #172033;
    font-weight: 900;
}

.quick small {
    display: block;
    margin-top: 6px;
    color: #64748b;
    font-weight: 700;
}

.chart {
    height: 130px;
    margin-top: 14px;
    border-radius: 16px;
    overflow: hidden;
    background:
        linear-gradient(180deg, rgba(37, 99, 235, .08), transparent),
        repeating-linear-gradient(to right, transparent, transparent 49px, rgba(148,163,184,.12) 50px),
        repeating-linear-gradient(to bottom, transparent, transparent 31px, rgba(148,163,184,.12) 32px);
    position: relative;
}

.chart-line {
    position: absolute;
    left: 0;
    right: 0;
    bottom: 18px;
    height: 78px;
    background: linear-gradient(90deg, rgba(37,99,235,.35), rgba(6,182,212,.45), rgba(34,197,94,.35));
    clip-path: polygon(0 70%, 8% 44%, 16% 62%, 25% 38%, 34% 57%, 43% 28%, 52% 55%, 60% 35%, 70% 64%, 82% 34%, 92% 48%, 100% 25%, 100% 100%, 0 100%);
}

@media (max-width: 1000px) {
    .span-3, .span-4, .span-5, .span-7, .span-8 {
        grid-column: span 12;
    }

    .quick-grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

@media (max-width: 600px) {
    .zn-head {
        display: block;
    }

    .zn-btn {
        margin-top: 10px;
    }

    .quick-grid,
    .speed-box {
        grid-template-columns: 1fr;
    }
}
</style>

<div class="zn-wrap">
    <div class="zn-head">
        <div>
            <h1>首页</h1>
            <p>类似 iStoreOS 的系统状态概览与实时监控</p>
        </div>
        <button class="zn-btn" onclick="refreshData()">刷新</button>
    </div>

    <div class="zn-grid">
        <div class="zn-card temp-card span-3">
            <h2>CPU 当前温度</h2>
            <div class="temp-row">
                <div>
                    <div class="temp-value"><span id="temp">--</span><span class="temp-unit">°C</span></div>
                    <div id="tempBadge" class="badge">正常</div>
                </div>
                <div class="temp-icon">♨</div>
            </div>
        </div>

        <div class="zn-card span-3">
            <h2>CPU 使用率</h2>
            <div class="metric">
                <div>
                    <div class="num"><span id="cpu">--</span>%</div>
                    <div class="sub">实时 CPU 占用</div>
                </div>
                <div class="iconbox blue">⚙</div>
            </div>
            <div class="progress"><span id="cpuBar"></span></div>
        </div>

        <div class="zn-card span-3">
            <h2>内存占用</h2>
            <div class="metric">
                <div>
                    <div class="num"><span id="memPercent">--</span>%</div>
                    <div class="sub"><span id="memUsed">--</span> / <span id="memTotal">--</span></div>
                </div>
                <div class="iconbox green">▣</div>
            </div>
            <div class="progress green"><span id="memBar"></span></div>
        </div>

        <div class="zn-card span-3">
            <h2>运行时间</h2>
            <div class="metric">
                <div>
                    <div class="num" style="font-size:24px" id="uptime">--</div>
                    <div class="sub">系统稳定运行</div>
                </div>
                <div class="iconbox purple">◷</div>
            </div>
        </div>

        <div class="zn-card span-4">
            <h2>系统概览</h2>
            <div class="info-row"><span>主机名</span><span id="hostname">--</span></div>
            <div class="info-row"><span>设备型号</span><span id="model">--</span></div>
            <div class="info-row"><span>固件版本</span><span id="firmware">--</span></div>
            <div class="info-row"><span>内核版本</span><span id="kernel">--</span></div>
            <div class="info-row"><span>系统负载</span><span id="load">--</span></div>
        </div>

        <div class="zn-card span-4">
            <h2>网络状态</h2>
            <div class="info-row"><span>WAN IP</span><span id="wanIp">--</span></div>
            <div class="info-row"><span>LAN IP</span><span id="lanIp">--</span></div>
            <div class="info-row"><span>网关</span><span id="gateway">--</span></div>
            <div class="info-row"><span>DNS</span><span id="dns">--</span></div>
            <div class="info-row"><span>出口接口</span><span id="netDev">--</span></div>
        </div>

        <div class="zn-card span-4">
            <h2>服务状态</h2>
            <div id="services"></div>
        </div>

        <div class="zn-card span-8">
            <h2>实时上下行速率</h2>
            <div class="speed-box">
                <div class="speed-card">
                    <div class="label">上传</div>
                    <div class="value"><span id="upSpeed">0.00</span> Mbps</div>
                </div>
                <div class="speed-card">
                    <div class="label">下载</div>
                    <div class="value"><span id="downSpeed">0.00</span> Mbps</div>
                </div>
            </div>
            <div class="chart"><div class="chart-line"></div></div>
        </div>

        <div class="zn-card span-4">
            <h2>存储状态</h2>
            <div class="metric">
                <div>
                    <div class="num" style="font-size:30px"><span id="rootPercent">--</span></div>
                    <div class="sub">已用 <span id="rootUsed">--</span> / <span id="rootTotal">--</span></div>
                </div>
                <div class="iconbox orange">▤</div>
            </div>
            <div class="progress purple"><span id="rootBar"></span></div>
        </div>

        <div class="zn-card span-12">
            <h2>快捷入口</h2>
            <div class="quick-grid">
                <a class="quick" href="<%=url('admin/network/network')%>">网络设置<small>接口 / LAN / WAN</small></a>
                <a class="quick" href="<%=url('admin/services/passwall')%>">PassWall<small>代理服务</small></a>
                <a class="quick" href="<%=url('admin/services/mosdns')%>">MosDNS<small>DNS 分流</small></a>
                <a class="quick" href="<%=url('admin/system/admin')%>">管理权限<small>密码 / SSH</small></a>
            </div>
        </div>
    </div>
</div>

<script>
var lastNet = null;
var lastTime = null;

function setText(id, value) {
    var e = document.getElementById(id);
    if (e) e.textContent = value;
}

function setBar(id, value) {
    var e = document.getElementById(id);
    if (!e) return;

    var n = parseInt(value || 0);
    if (isNaN(n)) n = 0;
    if (n < 0) n = 0;
    if (n > 100) n = 100;

    e.style.width = n + "%";
}

function updateTempBadge(temp) {
    var e = document.getElementById("tempBadge");
    if (!e) return;

    var n = parseFloat(temp);
    e.className = "badge";

    if (isNaN(n)) {
        e.textContent = "未知";
    } else if (n >= 75) {
        e.textContent = "温度过高";
        e.className = "badge danger";
    } else if (n >= 60) {
        e.textContent = "偏高";
        e.className = "badge warn";
    } else {
        e.textContent = "正常";
    }
}

function renderServices(list) {
    var box = document.getElementById("services");
    if (!box) return;

    box.innerHTML = "";

    if (!list || !list.length) {
        box.innerHTML = '<div class="info-row"><span>暂无服务数据</span><span>--</span></div>';
        return;
    }

    list.forEach(function(s) {
        var running = !!s.running;
        var row = document.createElement("div");
        row.className = "service";
        row.innerHTML =
            '<div class="service-name"><span class="dot ' + (running ? 'ok' : '') + '"></span>' +
            (s.name || "--") + '</div>' +
            '<span class="' + (running ? 'badge' : 'badge danger') + '">' +
            (running ? '运行中' : '未运行') + '</span>';
        box.appendChild(row);
    });
}

function updateSpeed(net) {
    if (!net) return;

    setText("netDev", net.dev || "--");

    var now = Date.now();

    if (lastNet && lastTime) {
        var dt = (now - lastTime) / 1000;
        if (dt > 0) {
            var down = ((net.rx - lastNet.rx) * 8 / 1024 / 1024 / dt);
            var up = ((net.tx - lastNet.tx) * 8 / 1024 / 1024 / dt);

            if (down < 0) down = 0;
            if (up < 0) up = 0;

            setText("downSpeed", down.toFixed(2));
            setText("upSpeed", up.toFixed(2));
        }
    }

    lastNet = {
        rx: net.rx || 0,
        tx: net.tx || 0
    };
    lastTime = now;
}

function refreshData() {
    fetch("<%=url('admin/status/znm2_dashboard/data')%>", {
        cache: "no-store",
        credentials: "same-origin"
    })
    .then(function(r) {
        if (!r.ok) {
            throw new Error("HTTP " + r.status);
        }
        return r.json();
    })
    .then(function(d) {
        setText("hostname", d.hostname || "--");
        setText("model", d.model || "--");
        setText("firmware", d.firmware || "--");
        setText("kernel", d.kernel || "--");
        setText("uptime", d.uptime || "--");

        setText("temp", d.temp || "--");
        updateTempBadge(d.temp);

        setText("cpu", d.cpu || 0);
        setBar("cpuBar", d.cpu || 0);

        if (d.load) {
            setText("load", [d.load.one, d.load.five, d.load.fifteen].join(" / "));
        }

        if (d.mem) {
            setText("memPercent", d.mem.percent || 0);
            setText("memUsed", d.mem.used || "--");
            setText("memTotal", d.mem.total || "--");
            setBar("memBar", d.mem.percent || 0);
        }

        if (d.rootfs) {
            setText("rootPercent", d.rootfs.percent || "--");
            setText("rootUsed", d.rootfs.used || "--");
            setText("rootTotal", d.rootfs.total || "--");

            var p = parseInt((d.rootfs.percent || "0").replace("%", ""));
            setBar("rootBar", p || 0);
        }

        setText("wanIp", d.wan_ip || "--");
        setText("lanIp", d.lan_ip || "--");
        setText("gateway", d.gateway || "--");
        setText("dns", d.dns || "--");

        updateSpeed(d.net);
        renderServices(d.services || []);
    })
    .catch(function(e) {
        console.log("dashboard error", e);
    });
}

refreshData();
setInterval(refreshData, 5000);
</script>

<%+footer%>
EOF

cat > ./custom/luci-app-znm2-dashboard/root/etc/uci-defaults/99-znm2-dashboard <<'EOF'
#!/bin/sh

uci -q set luci.main.lang='zh_cn'
uci -q set luci.languages.zh_cn='简体中文'
uci -q set luci.languages.en='English'
uci -q set luci.main.mediaurlbase='/luci-static/aurora'
uci -q commit luci

rm -rf /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache

/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

exit 0
EOF

chmod +x ./custom/luci-app-znm2-dashboard/root/etc/uci-defaults/99-znm2-dashboard

echo "==== luci-app-znm2-dashboard created successfully ===="
find ./custom/luci-app-znm2-dashboard -maxdepth 4 -type f | sort
