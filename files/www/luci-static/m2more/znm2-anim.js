(function () {
    function shuffle(arr) {
        var a = arr.slice();
        for (var i = a.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var t = a[i];
            a[i] = a[j];
            a[j] = t;
        }
        return a;
    }

    function initZnm2Animated() {
        var letters = Array.prototype.slice.call(document.querySelectorAll(".znm2-letter"));
        if (!letters.length) return;

        var palette = [
            "#2563eb", // 蓝
            "#10b981", // 绿
            "#f59e0b", // 橙
            "#fb7185", // 粉
            "#8b5cf6", // 紫
            "#06b6d4", // 青
            "#ef4444", // 红
            "#14b8a6", // 蓝绿
            "#a855f7", // 亮紫
            "#84cc16", // 草绿
            "#f97316", // 深橙
            "#0ea5e9"  // 天蓝
        ];

        var lastColors = [];

        function recolorUnique() {
            var picked = shuffle(palette).slice(0, letters.length);

            // 尽量避免某个字母连续两次拿到同一个颜色
            for (var i = 0; i < picked.length; i++) {
                if (picked[i] === lastColors[i]) {
                    for (var j = 0; j < picked.length; j++) {
                        if (picked[j] !== lastColors[i] && picked[i] !== lastColors[j]) {
                            var t = picked[i];
                            picked[i] = picked[j];
                            picked[j] = t;
                            break;
                        }
                    }
                }
            }

            letters.forEach(function (el, idx) {
                el.style.color = picked[idx];
                lastColors[idx] = picked[idx];
            });
        }

        recolorUnique();
        setInterval(recolorUnique, 850);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", initZnm2Animated);
    } else {
        initZnm2Animated();
    }
})();
