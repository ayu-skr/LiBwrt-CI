(function () {
    var lastRx = null;
    var lastTx = null;
    var lastTime = null;

    function $(id) {
        return document.getElementById(id);
    }

    function setText(id, value) {
        var el = $(id);
        if (el) el.textContent = value || "--";
    }

    function formatSpeed(bytesPerSecond) {
        bytesPerSecond = Number(bytesPerSecond || 0);

        if (bytesPerSecond >= 1024 * 1024 * 1024) {
            return (bytesPerSecond / 1024 / 1024 / 1024).toFixed(2) + " GB/s";
        }

        if (bytesPerSecond >= 1024 * 1024) {
            return (bytesPerSecond / 1024 / 1024).toFixed(2) + " MB/s";
        }

        if (bytesPerSecond >= 1024) {
            return (bytesPerSecond / 1024).toFixed(1) + " KB/s";
        }

        return bytesPerSecond.toFixed(0) + " B/s";
    }

    function updateSpeed() {
        if (!$("speed_down") || !$("speed_up")) return;

        fetch("/cgi-bin/luci/admin/status/m2more/data?_speed=" + Date.now(), {
            credentials: "same-origin",
            cache: "no-store"
        })
            .then(function (r) { return r.json(); })
            .then(function (d) {
                var now = Date.now();
                var rx = Number(d.speed_rx_bytes || 0);
                var tx = Number(d.speed_tx_bytes || 0);

                if (!rx && !tx) {
                    setText("speed_down", "--");
                    setText("speed_up", "--");
                    return;
                }

                if (lastTime !== null && lastRx !== null && lastTx !== null) {
                    var sec = (now - lastTime) / 1000;

                    if (sec > 0) {
                        var down = Math.max(0, (rx - lastRx) / sec);
                        var up = Math.max(0, (tx - lastTx) / sec);

                        setText("speed_down", formatSpeed(down));
                        setText("speed_up", formatSpeed(up));
                    }
                } else {
                    setText("speed_down", "计算中");
                    setText("speed_up", "计算中");
                }

                lastRx = rx;
                lastTx = tx;
                lastTime = now;
            })
            .catch(function () {
                setText("speed_down", "--");
                setText("speed_up", "--");
            });
    }

    updateSpeed();
    setInterval(updateSpeed, 2000);
})();
