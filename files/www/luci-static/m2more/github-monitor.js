(function () {
    var STORAGE_KEY = "m2_github_monitor_repos_v3";

    function $(id) {
        return document.getElementById(id);
    }

    function normalizeRepo(input) {
        input = String(input || "").trim();

        input = input
            .replace(/^https?:\/\/github\.com\//i, "")
            .replace(/^github\.com\//i, "")
            .replace(/\/actions.*$/i, "")
            .replace(/\/releases.*$/i, "")
            .replace(/\/$/, "");

        var parts = input.split("/").filter(Boolean);
        if (parts.length < 2) return null;

        return {
            owner: parts[0],
            repo: parts[1],
            full: parts[0] + "/" + parts[1]
        };
    }

    function loadRepos() {
        try {
            var arr = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
            if (!Array.isArray(arr)) return [];

            return arr
                .map(normalizeRepo)
                .filter(Boolean)
                .filter(function (item, idx, self) {
                    return self.findIndex(function (x) {
                        return x.full.toLowerCase() === item.full.toLowerCase();
                    }) === idx;
                });
        } catch (e) {
            return [];
        }
    }

    function saveRepos(repos) {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(repos.map(function (x) {
            return x.full;
        })));
    }

    function setStatus(v) {
        var el = $("github_monitor_status");
        if (el) el.textContent = v || "今日";
    }

    function escapeHtml(s) {
        return String(s || "")
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    function renderRows(rows) {
        var body = $("github_monitor_body");
        if (!body) return;

        if (!rows.length) {
            body.innerHTML = '<tr><td colspan="7">暂无监控仓库</td></tr>';
            return;
        }

        body.innerHTML = rows.map(function (r) {
            return '<tr>' +
                '<td>' + escapeHtml(r.owner) + '</td>' +
                '<td>' + escapeHtml(r.repo) + '</td>' +
                '<td class="ok-num">' + escapeHtml(r.success) + '</td>' +
                '<td class="bad-num">' + escapeHtml(r.failed) + '</td>' +
                '<td class="fw-num">' + escapeHtml(r.firmware) + '</td>' +
                '<td>' + escapeHtml(r.latest_success) + '</td>' +
                '<td><button class="github-remove-btn" data-repo="' + escapeHtml(r.full) + '">×</button></td>' +
                '</tr>';
        }).join("");
    }

    function renderLoading(repos) {
        renderRows(repos.map(function (r) {
            return {
                owner: r.owner,
                repo: r.repo,
                full: r.full,
                success: "...",
                failed: "...",
                firmware: "...",
                latest_success: "..."
            };
        }));
    }

    function fetchRepo(repo, force) {
        return fetch("/cgi-bin/luci/admin/status/m2more/github_ci?repo=" + encodeURIComponent(repo.full) + "&force=" + (force ? "1" : "0") + "&_=" + Date.now(), {
            credentials: "same-origin",
            cache: "no-store"
        })
            .then(function (r) { return r.json(); })
            .then(function (d) {
                if (!d.ok) {
                    return {
                        owner: repo.owner,
                        repo: repo.repo,
                        full: repo.full,
                        success: "--",
                        failed: "--",
                        firmware: "--",
                        latest_success: d.error || "失败"
                    };
                }

                return {
                    owner: d.owner,
                    repo: d.repo,
                    full: d.owner + "/" + d.repo,
                    success: d.success,
                    failed: d.failed,
                    firmware: d.firmware,
                    latest_success: d.latest_success || "--"
                };
            })
            .catch(function () {
                return {
                    owner: repo.owner,
                    repo: repo.repo,
                    full: repo.full,
                    success: "--",
                    failed: "--",
                    firmware: "--",
                    latest_success: "请求失败"
                };
            });
    }

    function refreshMonitor(force) {
        var repos = loadRepos();

        if (!repos.length) {
            setStatus("今日");
            renderRows([]);
            return;
        }

        setStatus(force ? "刷新中" : "缓存");
        renderLoading(repos);

        Promise.all(repos.map(function (r) {
            return fetchRepo(r, force);
        })).then(function (rows) {
            renderRows(rows);
            setStatus("今日");
        }).catch(function () {
            setStatus("失败");
        });
    }

    function addRepo() {
        var input = $("github_repo_input");
        if (!input) return;

        var repo = normalizeRepo(input.value);
        if (!repo) {
            setStatus("格式错误");
            return;
        }

        var repos = loadRepos();
        var exists = repos.some(function (r) {
            return r.full.toLowerCase() === repo.full.toLowerCase();
        });

        if (!exists) {
            repos.push(repo);
            saveRepos(repos);
        }

        input.value = "";
        refreshMonitor(true);
    }

    function removeRepo(full) {
        var repos = loadRepos().filter(function (r) {
            return r.full.toLowerCase() !== String(full || "").toLowerCase();
        });

        saveRepos(repos);
        refreshMonitor(false);
    }

    function addRefreshButton() {
        var head = document.querySelector(".github-monitor-head");
        if (!head || $("github_refresh_btn")) return;

        var btn = document.createElement("button");
        btn.id = "github_refresh_btn";
        btn.type = "button";
        btn.textContent = "刷新";
        btn.addEventListener("click", function () {
            refreshMonitor(true);
        });

        head.appendChild(btn);
    }

    function bindEvents() {
        var btn = $("github_add_repo_btn");
        var input = $("github_repo_input");
        var body = $("github_monitor_body");

        if (btn) btn.addEventListener("click", addRepo);

        if (input) {
            input.removeAttribute("placeholder");
            input.addEventListener("keydown", function (e) {
                if (e.key === "Enter") addRepo();
            });
        }

        if (body) {
            body.addEventListener("click", function (e) {
                var t = e.target;
                if (t && t.classList.contains("github-remove-btn")) {
                    removeRepo(t.getAttribute("data-repo"));
                }
            });
        }
    }

    function init() {
        if (!$("github_monitor_body")) return;

        addRefreshButton();
        bindEvents();
        refreshMonitor(false);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
})();
