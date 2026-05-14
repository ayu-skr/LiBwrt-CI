(function () {
    var ids = [
        "passwall",
        "mosdns",
        "lucky",
        "gecoosac",
        "dnsmasq",
        "dropbear",
        "firewall",
        "network",
        "nss_status"
    ];

    function $(id) {
        return document.getElementById(id);
    }

    function updateOne(el) {
        if (!el) return;

        var text = String(el.textContent || "").trim();

        el.classList.remove("m2-status-ok", "m2-status-bad");

        if (
            text === "运行中" ||
            text === "已加载" ||
            text === "正常" ||
            text === "启用"
        ) {
            el.classList.add("m2-status-ok");
            return;
        }

        if (
            text === "未运行" ||
            text === "未加载" ||
            text.indexOf("未检测") >= 0 ||
            text.indexOf("失败") >= 0 ||
            text.indexOf("错误") >= 0
        ) {
            el.classList.add("m2-status-bad");
        }
    }

    function updateStatusColors() {
        ids.forEach(function (id) {
            updateOne($(id));
        });

        /* 兜底：所有 service 右侧状态文字也检查一次 */
        document.querySelectorAll(".aurora .service b").forEach(updateOne);

        /* NSS 顶部状态 */
        document.querySelectorAll(".aurora .nss-inline-head em").forEach(updateOne);
    }

    updateStatusColors();
    setInterval(updateStatusColors, 1000);
})();
