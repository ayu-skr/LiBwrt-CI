/* M2 speed helper */
var m2SpeedState = window.m2SpeedState || {
    lastRx: null,
    lastTx: null,
    lastTime: null
};
window.m2SpeedState = m2SpeedState;

function m2FormatSpeed(bytesPerSec) {
    bytesPerSec = Number(bytesPerSec || 0);

    if (bytesPerSec >= 1024 * 1024 * 1024) {
        return (bytesPerSec / 1024 / 1024 / 1024).toFixed(2) + " GB/s";
    }

    if (bytesPerSec >= 1024 * 1024) {
        return (bytesPerSec / 1024 / 1024).toFixed(2) + " MB/s";
    }

    if (bytesPerSec >= 1024) {
        return (bytesPerSec / 1024).toFixed(1) + " KB/s";
    }

    return bytesPerSec.toFixed(0) + " B/s";
}

function m2UpdateSpeed(d, textFn) {
    var now = Date.now();
    var rx = Number(d.speed_rx_bytes || 0);
    var tx = Number(d.speed_tx_bytes || 0);

    if (m2SpeedState.lastTime !== null) {
        var sec = (now - m2SpeedState.lastTime) / 1000;
        if (sec > 0) {
            var down = Math.max(0, (rx - m2SpeedState.lastRx) / sec);
            var up = Math.max(0, (tx - m2SpeedState.lastTx) / sec);

            textFn("speed_down", m2FormatSpeed(down));
            textFn("speed_up", m2FormatSpeed(up));
        }
    } else {
        textFn("speed_down", "计算中");
        textFn("speed_up", "计算中");
    }

    m2SpeedState.lastRx = rx;
    m2SpeedState.lastTx = tx;
    m2SpeedState.lastTime = now;
}
(function () {
    var latencyData = {
        google: "--",
        github: "--",
        youtube: "--",
        openai: "--",
        bilibili: "--",
        baidu: "--"
    };

    var latencyIndex = 0;

    var latencyItems = [
        { name: "Google", key: "google" },
        { name: "GitHub", key: "github" },
        { name: "YouTube", key: "youtube" },
        { name: "OpenAI", key: "openai" },
        { name: "B站", key: "bilibili" },
        { name: "百度", key: "baidu" }
    ];

    var nssModuleItems = ["--"];
    var nssAccelItems = ["--"];
    var nssModuleIndex = 0;
    var nssAccelIndex = 0;

    function $(id) {
        return document.getElementById(id);
    }

    function text(id, value) {
        var el = $(id);
        if (el) el.textContent = value || "--";
    }

    function service(name, value) {
        text(name, value);

        var dot = $("dot-" + name);
        if (!dot) return;

        if (value === "运行中") dot.classList.add("ok");
        else dot.classList.remove("ok");
    }

    function parsePercent(s) {
        var n = parseInt(String(s || "0").replace("%", ""), 10);
        if (isNaN(n)) n = 0;
        return Math.max(0, Math.min(100, n));
    }

    function parseTemp(s) {
        var n = parseFloat(String(s || "0").replace("°C", ""));
        if (isNaN(n)) n = 0;
        return n;
    }

    function updateHealth(d) {
        var score = 100;
        var t = parseTemp(d.temperature);
        var m = parsePercent(d.mem_pct);

        if (t >= 85) score -= 35;
        else if (t >= 75) score -= 22;
        else if (t >= 65) score -= 10;

        if (m >= 90) score -= 30;
        else if (m >= 80) score -= 18;
        else if (m >= 70) score -= 8;

        ["dnsmasq", "dropbear", "firewall", "network"].forEach(function (k) {
            if (d[k] !== "运行中") score -= 12;
        });

        score = Math.max(0, Math.min(100, score));
        text("health", score + "%");
    }

    function splitNssModules(value) {
        value = String(value || "--").trim();

        if (!value || value === "--") return ["--"];

        return value
            .split(/\s+/)
            .map(function (x) { return x.trim(); })
            .filter(function (x) { return x.length > 0; });
    }

    function splitNssAccel(value) {
        value = String(value || "--").trim();

        if (!value || value === "--") return ["--"];

        return value
            .split(/\s*\/\s*/)
            .map(function (x) { return x.trim(); })
            .filter(function (x) { return x.length > 0; });
    }

    function renderLatency() {
        var item = latencyItems[latencyIndex];
        var wrap = document.querySelector(".latency-single");

        if (wrap) {
            wrap.classList.remove("show");
            wrap.classList.add("hide");
        }

        setTimeout(function () {
            text("latency_name", item.name);
            text("latency_value", latencyData[item.key] || "--");

            if (wrap) {
                wrap.classList.remove("hide");
                wrap.classList.add("show");
            }

            latencyIndex = (latencyIndex + 1) % latencyItems.length;
        }, 300);
    }

    function renderNssScroll() {
        var moduleBox = $("nss_modules");
        var accelBox = $("nss_accel");

        if (moduleBox) {
            moduleBox.classList.remove("nss-roll-show");
            moduleBox.classList.add("nss-roll-hide");
        }

        if (accelBox) {
            accelBox.classList.remove("nss-roll-show");
            accelBox.classList.add("nss-roll-hide");
        }

        setTimeout(function () {
            var moduleValue = nssModuleItems[nssModuleIndex] || "--";
            var accelValue = nssAccelItems[nssAccelIndex] || "--";

            text("nss_modules", moduleValue);
            text("nss_accel", accelValue);

            if (moduleBox) {
                moduleBox.classList.remove("nss-roll-hide");
                moduleBox.classList.add("nss-roll-show");
            }

            if (accelBox) {
                accelBox.classList.remove("nss-roll-hide");
                accelBox.classList.add("nss-roll-show");
            }

            nssModuleIndex = (nssModuleIndex + 1) % nssModuleItems.length;
            nssAccelIndex = (nssAccelIndex + 1) % nssAccelItems.length;
        }, 260);
    }

    function load() {
        fetch("/cgi-bin/luci/admin/status/m2more/data?_=" + Date.now(), {
            credentials: "same-origin",
            cache: "no-store"
        })
            .then(function (r) { return r.json(); })
            .then(function (d) {
                latencyData.google = d.google_latency || "--";
                latencyData.github = d.github_latency || "--";
                latencyData.youtube = d.youtube_latency || "--";
                latencyData.openai = d.openai_latency || "--";
                latencyData.bilibili = d.bilibili_latency || "--";
                latencyData.baidu = d.baidu_latency || "--";

                text("model", d.model);
                text("hostname", d.hostname);
                text("kernel", d.kernel);
                text("time", d.time);
                text("uptime", d.uptime);

                text("temperature", d.temperature);
                text("cpu_freq", d.cpu_freq);
                text("load", d.load);
                text("mem_pct", d.mem_pct);
                text("mem_text", d.mem_text);
                text("overlay", d.overlay);
                text("rootfs", d.rootfs);

                text("lan_ip", d.lan_ip);
                text("lan_ipv6", d.lan_ipv6);
                text("wan_ip", d.wan_ip);
                text("wan_dev", d.wan_dev);
                text("gateway", d.gateway);
                text("dns", d.dns);
                text("rx", d.rx);
                text("tx", d.tx);
                text("conntrack", d.conntrack);
                m2UpdateSpeed(d, text);

                text("dhcp_count", d.dhcp_count + " 台");
                text("dhcp_list", d.dhcp_list);

                service("passwall", d.passwall);
                service("mosdns", d.mosdns);
                service("lucky", d.lucky);
                service("gecoosac", d.gecoosac);
                service("dnsmasq", d.dnsmasq);
                service("dropbear", d.dropbear);
                service("firewall", d.firewall);
                service("network", d.network);

                text("nss_status", d.nss_status);

                nssModuleItems = splitNssModules(d.nss_modules);
                nssAccelItems = splitNssAccel(d.nss_accel);

                if (nssModuleIndex >= nssModuleItems.length) nssModuleIndex = 0;
                if (nssAccelIndex >= nssAccelItems.length) nssAccelIndex = 0;

                updateHealth(d);
            })
            .catch(function () {
                latencyData.google = "--";
                latencyData.github = "--";
                latencyData.youtube = "--";
                latencyData.openai = "--";
                latencyData.bilibili = "--";
                latencyData.baidu = "--";

                nssModuleItems = ["--"];
                nssAccelItems = ["--"];
                nssModuleIndex = 0;
                nssAccelIndex = 0;
            });
    }

    load();

    setTimeout(renderLatency, 500);
    setTimeout(renderNssScroll, 700);

    setInterval(renderLatency, 2500);
    setInterval(renderNssScroll, 3000);
    setInterval(load, 8000);
})();
