(function () {
    function $(id) {
        return document.getElementById(id);
    }

    function fitOneLine(el, maxSize, minSize) {
        if (!el) return;

        var parent = el.parentElement;
        if (!parent) return;

        el.style.whiteSpace = "nowrap";
        el.style.wordBreak = "normal";
        el.style.overflow = "hidden";
        el.style.textOverflow = "clip";
        el.style.display = "block";

        var parentWidth = parent.clientWidth - 12;
        if (parentWidth <= 0) return;

        var size = maxSize;
        el.style.fontSize = size + "px";

        while (el.scrollWidth > parentWidth && size > minSize) {
            size -= 1;
            el.style.fontSize = size + "px";
        }
    }

    function updateFit() {
        fitOneLine($("load"), 30, 18);
        fitOneLine($("conntrack"), 30, 17);
    }

    updateFit();

    setInterval(updateFit, 1000);

    window.addEventListener("resize", updateFit);
})();
