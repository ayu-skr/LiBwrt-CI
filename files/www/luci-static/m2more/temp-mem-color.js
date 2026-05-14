(function () {
    function $(id) {
        return document.getElementById(id);
    }

    function parseNumber(text) {
        var m = String(text || "").match(/-?\d+(\.\d+)?/);
        if (!m) return null;
        return parseFloat(m[0]);
    }

    function setLevel(el, level) {
        if (!el) return;

        el.classList.remove("m2-value-green", "m2-value-orange", "m2-value-red");

        if (level === "green") el.classList.add("m2-value-green");
        if (level === "orange") el.classList.add("m2-value-orange");
        if (level === "red") el.classList.add("m2-value-red");
    }

    function updateColors() {
        var tempEl = $("temperature");
        var memEl = $("mem_pct");

        var temp = parseNumber(tempEl ? tempEl.textContent : "");
        var mem = parseNumber(memEl ? memEl.textContent : "");

        if (temp !== null) {
            if (temp < 50) {
                setLevel(tempEl, "green");
            } else if (temp < 65) {
                setLevel(tempEl, "orange");
            } else {
                setLevel(tempEl, "red");
            }
        }

        if (mem !== null) {
            if (mem < 65) {
                setLevel(memEl, "green");
            } else if (mem < 75) {
                setLevel(memEl, "orange");
            } else {
                setLevel(memEl, "red");
            }
        }
    }

    updateColors();
    setInterval(updateColors, 2000);
})();
