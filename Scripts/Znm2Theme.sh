#!/bin/bash
set -e

echo "==== Create luci-theme-znm2-neon ===="

# WRT-CORE.yml 会在 ./wrt/package/ 下执行 Packages.sh
# 所以这里的 ./custom 就是 ./wrt/package/custom
rm -rf ./custom/luci-theme-znm2-neon

mkdir -p ./custom/luci-theme-znm2-neon/htdocs/luci-static/znm2-neon
mkdir -p ./custom/luci-theme-znm2-neon/luasrc/view/themes/znm2-neon
mkdir -p ./custom/luci-theme-znm2-neon/root/etc/uci-defaults

cat > ./custom/luci-theme-znm2-neon/Makefile <<'EOF'
include $(TOPDIR)/rules.mk

LUCI_TITLE:=ZN M2 Neon Dark Theme
LUCI_DEPENDS:=+luci-base
LUCI_PKGARCH:=all

PKG_NAME:=luci-theme-znm2-neon
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
EOF

cat > ./custom/luci-theme-znm2-neon/htdocs/luci-static/znm2-neon/cascade.css <<'EOF'
/*
 * ZN M2 Neon Dark Theme
 * iStoreOS-like dark dashboard style for LuCI
 */

:root {
    --zn-bg: #061426;
    --zn-bg2: #081b33;
    --zn-card: rgba(10, 31, 58, .82);
    --zn-card2: rgba(12, 38, 70, .92);
    --zn-border: rgba(82, 155, 255, .22);
    --zn-border2: rgba(82, 155, 255, .38);
    --zn-text: #eaf3ff;
    --zn-muted: #8fa9c9;
    --zn-blue: #2f8cff;
    --zn-cyan: #20d8ff;
    --zn-green: #22c55e;
    --zn-orange: #ff8a18;
    --zn-red: #ff4d6d;
    --zn-purple: #8b5cf6;
    --zn-radius: 18px;
    --zn-shadow: 0 18px 48px rgba(0, 0, 0, .35);
}

html,
body {
    min-height: 100%;
    background:
        radial-gradient(circle at 15% 10%, rgba(47, 140, 255, .22), transparent 25%),
        radial-gradient(circle at 80% 20%, rgba(139, 92, 246, .20), transparent 28%),
        radial-gradient(circle at 20% 90%, rgba(20, 184, 166, .16), transparent 30%),
        linear-gradient(135deg, #04101f 0%, #07192f 45%, #030b18 100%) !important;
    color: var(--zn-text) !important;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Microsoft YaHei", Arial, sans-serif !important;
}

/* 顶部导航 */
header,
.navbar,
#mainmenu,
.mainmenu {
    background: rgba(5, 17, 34, .72) !important;
    backdrop-filter: blur(18px);
    border-bottom: 1px solid rgba(82, 155, 255, .18) !important;
    box-shadow: 0 8px 26px rgba(0, 0, 0, .28);
}

header a,
.navbar a,
#mainmenu a,
.mainmenu a {
    color: var(--zn-text) !important;
    font-weight: 700;
}

header a:hover,
.navbar a:hover,
#mainmenu a:hover,
.mainmenu a:hover {
    color: #7dd3fc !important;
}

/* 左侧菜单，适配 bootstrap/argon/aurora 常见结构 */
aside,
#sidenav,
.sidenav,
.sidebar,
.main-left,
#maincontent + .sidebar {
    background:
        linear-gradient(180deg, rgba(7, 25, 50, .96), rgba(4, 13, 28, .98)) !important;
    border-right: 1px solid rgba(82, 155, 255, .18) !important;
    box-shadow: 14px 0 40px rgba(0, 0, 0, .28);
}

aside a,
#sidenav a,
.sidenav a,
.sidebar a,
.main-left a {
    color: #dbeafe !important;
    border-radius: 12px !important;
    font-weight: 700;
}

aside a:hover,
#sidenav a:hover,
.sidenav a:hover,
.sidebar a:hover,
.main-left a:hover {
    background: rgba(47, 140, 255, .16) !important;
    color: #ffffff !important;
}

aside .active > a,
#sidenav .active > a,
.sidenav .active > a,
.sidebar .active > a,
.main-left .active > a,
.main-left .selected > a {
    background: linear-gradient(135deg, #1d6df2, #22b8ff) !important;
    color: #fff !important;
    box-shadow: 0 10px 28px rgba(47, 140, 255, .36);
}

/* 主体区域 */
#maincontent,
.main,
.main-right,
.content,
.container,
.container-fluid {
    color: var(--zn-text) !important;
}

#maincontent {
    background: transparent !important;
}

/* 页面标题 */
h1, h2, h3, legend {
    color: #f8fbff !important;
    font-weight: 900 !important;
    letter-spacing: -.3px;
}

p,
td,
th,
label,
.cbi-value-title,
.cbi-section-node,
.cbi-section-descr,
.cbi-value-description,
.description {
    color: #cbdaf0 !important;
}

/* 卡片化所有 section */
.cbi-section,
.cbi-map,
.panel,
.card,
fieldset,
.table,
.tabs,
.tabs-container,
.node-main-login {
    background: var(--zn-card) !important;
    border: 1px solid var(--zn-border) !important;
    border-radius: var(--zn-radius) !important;
    box-shadow: var(--zn-shadow);
    color: var(--zn-text) !important;
}

/* 状态页表格 */
table,
.table {
    background: rgba(9, 30, 58, .72) !important;
    color: var(--zn-text) !important;
    border-collapse: separate !important;
    border-spacing: 0;
    overflow: hidden;
}

tr,
td,
th {
    border-color: rgba(82, 155, 255, .16) !important;
}

tr:nth-child(even) {
    background: rgba(255, 255, 255, .025) !important;
}

tr:hover {
    background: rgba(47, 140, 255, .10) !important;
}

th {
    color: #eaf3ff !important;
    background: rgba(47, 140, 255, .10) !important;
    font-weight: 900 !important;
}

/* 表单 */
input,
select,
textarea,
.cbi-input-text,
.cbi-input-select,
.cbi-input-password {
    background: rgba(3, 15, 31, .86) !important;
    border: 1px solid rgba(82, 155, 255, .28) !important;
    color: #f8fbff !important;
    border-radius: 12px !important;
    box-shadow: none !important;
}

input:focus,
select:focus,
textarea:focus {
    border-color: #38bdf8 !important;
    box-shadow: 0 0 0 3px rgba(56, 189, 248, .16) !important;
}

/* 按钮 */
.btn,
.cbi-button,
button,
input[type="submit"],
input[type="button"] {
    border: 0 !important;
    border-radius: 12px !important;
    background: linear-gradient(135deg, #2563eb, #06b6d4) !important;
    color: #ffffff !important;
    font-weight: 900 !important;
    box-shadow: 0 12px 26px rgba(37, 99, 235, .26);
}

.btn:hover,
.cbi-button:hover,
button:hover,
input[type="submit"]:hover,
input[type="button"]:hover {
    filter: brightness(1.08);
    transform: translateY(-1px);
}

.cbi-button-negative,
.btn-danger,
.cbi-button-remove {
    background: linear-gradient(135deg, #ef4444, #f97316) !important;
}

.cbi-button-positive,
.btn-success,
.cbi-button-apply,
.cbi-button-save {
    background: linear-gradient(135deg, #16a34a, #22c55e) !important;
}

.cbi-button-neutral,
.btn-secondary {
    background: linear-gradient(135deg, #334155, #475569) !important;
}

/* Tab */
.tabs,
.cbi-tabmenu,
.nav-tabs {
    background: rgba(8, 27, 51, .76) !important;
    border-radius: 999px !important;
    padding: 6px !important;
    border: 1px solid rgba(82, 155, 255, .18) !important;
}

.tabs li,
.cbi-tab,
.cbi-tab-disabled,
.nav-tabs li {
    border-radius: 999px !important;
}

.tabs li.active,
.cbi-tab,
.nav-tabs li.active {
    background: linear-gradient(135deg, #1d6df2, #22b8ff) !important;
    color: #fff !important;
}

/* 状态标签 */
.label,
.badge,
.ifacebadge {
    border-radius: 999px !important;
    font-weight: 900 !important;
    border: 1px solid rgba(82, 155, 255, .20) !important;
}

.label-success,
.badge-success,
.ifacebadge-active {
    background: rgba(34, 197, 94, .18) !important;
    color: #86efac !important;
}

.label-danger,
.badge-danger {
    background: rgba(239, 68, 68, .18) !important;
    color: #fca5a5 !important;
}

.label-warning,
.badge-warning {
    background: rgba(249, 115, 22, .18) !important;
    color: #fdba74 !important;
}

/* 进度条 */
.progress,
.cbi-progressbar {
    background: rgba(148, 163, 184, .18) !important;
    border-radius: 999px !important;
    overflow: hidden;
    border: 0 !important;
}

.progress-bar,
.cbi-progressbar div {
    background: linear-gradient(90deg, #2f8cff, #20d8ff) !important;
    border-radius: 999px !important;
}

/* 登录页 */
.node-main-login,
.login-page,
.login {
    background:
        radial-gradient(circle at 80% 10%, rgba(47, 140, 255, .24), transparent 26%),
        rgba(8, 27, 51, .88) !important;
    border: 1px solid rgba(82, 155, 255, .26) !important;
    border-radius: 24px !important;
    box-shadow: 0 24px 80px rgba(0, 0, 0, .42) !important;
}

/* 滚动条 */
::-webkit-scrollbar {
    width: 10px;
    height: 10px;
}

::-webkit-scrollbar-track {
    background: rgba(8, 27, 51, .9);
}

::-webkit-scrollbar-thumb {
    background: rgba(82, 155, 255, .38);
    border-radius: 999px;
}

::-webkit-scrollbar-thumb:hover {
    background: rgba(82, 155, 255, .58);
}

/* 首页概览状态页特殊优化 */
[data-page="status-overview"] .cbi-section,
[data-page="admin-status-index"] .cbi-section {
    background:
        radial-gradient(circle at 90% 0%, rgba(47, 140, 255, .16), transparent 26%),
        rgba(10, 31, 58, .86) !important;
}

/* 移动端 */
@media (max-width: 768px) {
    .cbi-section,
    .cbi-map,
    .panel,
    .card,
    fieldset {
        border-radius: 14px !important;
    }

    body {
        background: linear-gradient(180deg, #061426, #030b18) !important;
    }
}
EOF

cat > ./custom/luci-theme-znm2-neon/htdocs/luci-static/znm2-neon/theme.js <<'EOF'
(function () {
    function addClass() {
        document.documentElement.classList.add('znm2-neon-theme');
        document.body && document.body.classList.add('znm2-neon-theme');

        var path = location.pathname || '';
        if (path.indexOf('/admin/status') >= 0) {
            document.body.setAttribute('data-page', 'status-overview');
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', addClass);
    } else {
        addClass();
    }
})();
EOF

cat > ./custom/luci-theme-znm2-neon/luasrc/view/themes/znm2-neon/header.htm <<'EOF'
<%#
 ZN M2 Neon theme header
 This theme reuses the default LuCI header and injects dark theme CSS.
-%>
<%+themes/bootstrap/header%>
<link rel="stylesheet" href="<%=media%>/cascade.css?v=1.0">
<script src="<%=media%>/theme.js?v=1.0"></script>
EOF

cat > ./custom/luci-theme-znm2-neon/luasrc/view/themes/znm2-neon/footer.htm <<'EOF'
<%+themes/bootstrap/footer%>
EOF

cat > ./custom/luci-theme-znm2-neon/root/etc/uci-defaults/99-znm2-neon-theme <<'EOF'
#!/bin/sh

# 设置 ZN M2 Neon 为默认主题
uci -q set luci.main.mediaurlbase='/luci-static/znm2-neon'

# 默认中文
uci -q set luci.main.lang='zh_cn'
uci -q set luci.languages.zh_cn='简体中文'
uci -q set luci.languages.en='English'

uci -q commit luci

# 清理 LuCI 缓存
rm -rf /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache

# 重启 Web 服务
/etc/init.d/uhttpd restart >/dev/null 2>&1 || true

exit 0
EOF

chmod +x ./custom/luci-theme-znm2-neon/root/etc/uci-defaults/99-znm2-neon-theme

echo "==== luci-theme-znm2-neon created successfully ===="
find ./custom/luci-theme-znm2-neon -maxdepth 5 -type f | sort
