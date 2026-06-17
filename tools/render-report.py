#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 营造 yingzao · 报告渲染引擎（v1.13）
# 把报告数据 JSON 渲染成「自包含纯静态 HTML」：内联 CSS + 预算好的内联 SVG 雷达，
# 零外部依赖（无 CDN / 无 JS）、断网双击可开、深浅色自适应、可门禁测试。
# 用法: render-report.py <data.json> <out.html>
# 退出: 0 成功 / 2 用法或数据错
# 降级: 宿主无 python3 时，落成步骤跳过 HTML、只出 markdown 并在报告标注（见 SKILL 落成）。
# 数据契约见 references/html-report.md（schema + 字段说明）。
import sys, json, math, html as _html

def esc(s):
    return _html.escape(str(s)) if s is not None else ""

def _get(d, k, default=None):
    v = d.get(k, default)
    return v if v is not None else default

# ── 九维达成率雷达（纯 SVG·坐标在此算死·无 JS）────────────────────────────
def radar_svg(scores):
    n = len(scores)
    if n < 3:
        return ""
    cx, cy, R = 190, 165, 118
    def pt(i, frac):
        ang = math.radians(-90 + i * (360.0 / n))
        return (cx + R * frac * math.cos(ang), cy + R * frac * math.sin(ang))
    parts = ['<svg viewBox="0 0 380 330" width="100%" role="img" '
             'aria-label="九维达成率雷达图" class="radar">']
    # 网格环 25/50/75/100%
    for frac in (0.25, 0.5, 0.75, 1.0):
        poly = " ".join("%.1f,%.1f" % pt(i, frac) for i in range(n))
        parts.append('<polygon points="%s" class="rg"/>' % poly)
    # 轴线 + 标签
    for i, s in enumerate(scores):
        x, y = pt(i, 1.0)
        parts.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" class="ra"/>' % (cx, cy, x, y))
        lx, ly = pt(i, 1.18)
        anchor = "middle"
        if lx > cx + 6: anchor = "start"
        elif lx < cx - 6: anchor = "end"
        dy = "-2" if ly < cy - 6 else ("10" if ly > cy + 6 else "3")
        abbr = esc(_get(s, "abbr", _get(s, "dim", "")))
        sc, fl = _get(s, "score", 0), _get(s, "full", 1) or 1
        parts.append('<text x="%.1f" y="%.1f" dy="%s" text-anchor="%s" class="rl">%s '
                     '<tspan class="rlv">%s/%s</tspan></text>' % (lx, ly, dy, anchor, abbr, sc, fl))
    # 数据多边形
    dpts = []
    for i, s in enumerate(scores):
        fl = _get(s, "full", 1) or 1
        frac = max(0.0, min(1.0, float(_get(s, "score", 0)) / float(fl)))
        dpts.append(pt(i, frac))
    poly = " ".join("%.1f,%.1f" % p for p in dpts)
    parts.append('<polygon points="%s" class="rp"/>' % poly)
    for x, y in dpts:
        parts.append('<circle cx="%.1f" cy="%.1f" r="3" class="rpd"/>' % (x, y))
    parts.append('</svg>')
    return "".join(parts)

# ── 各区块 ────────────────────────────────────────────────────────────────
def meta_bar(m):
    keys = [("form", "形态"), ("role", "岗位"), ("target", "目标"),
            ("mode", "模式"), ("run", "运行档")]
    pills = "".join('<span class="pill">%s：%s</span>' % (lab, esc(m[k]))
                    for k, lab in keys if m.get(k))
    return '<div class="pills">%s</div>' % pills

def human_block(h):
    if not h: return ""
    items = ""
    for it in _get(h, "items", []):
        items += ('<li><b>%s</b> —— %s <span class="hafter">→ 改完：%s</span></li>'
                  % (esc(_get(it, "problem", "")), esc(_get(it, "why", "")),
                     esc(_get(it, "after", ""))))
    sn, sa = _get(h, "score_now"), _get(h, "score_after")
    head = ""
    if sn is not None:
        aft = (' 打磨后预计 <b>%s</b> 分（往低了估）' % esc(sa)) if sa is not None else ""
        head = '<p class="hlead">现在 <b>%s</b> 分。%s最该改的几件事：</p>' % (esc(sn), aft)
    return ('<section class="card human"><div class="sech"><span class="ico">&#9829;</span>'
            '核心结论（运营/PM 先看 · 零术语）</div>%s<ul class="hlist">%s</ul>'
            '<p class="hnote">下面是工程细节（研发 / 留档看），不影响理解上面的结论。</p></section>'
            % (head, items))

def verdict_block(v):
    if not v: return ""
    cells = []
    sb, sa = _get(v, "score_before"), _get(v, "score_after")
    meas = (" · %s" % esc(_get(v, "measured"))) if v.get("measured") else ""
    if sb is not None:
        arrow = (' <span class="vsub">→ %s</span>' % esc(sa)) if sa is not None else ""
        cells.append(("勘验得分", '%s%s' % (esc(sb), arrow), "实测/估分%s" % meas))
    for k, lab in (("niche", "定式/生态位"), ("signature", "绝活"), ("next", "下一步")):
        if v.get(k):
            cells.append((lab, esc(v[k]), ""))
    inner = ""
    for lab, big, sub in cells:
        subhtml = ('<div class="vc-sub">%s</div>' % sub) if sub else ""
        inner += ('<div class="vc"><div class="vc-lab">%s</div><div class="vc-big">%s</div>%s</div>'
                  % (lab, big, subhtml))
    return ('<section class="card surface"><div class="sech"><span class="ico">&#9733;</span>'
            '落成匾 · 结果卡</div><div class="vgrid">%s</div></section>' % inner)

def scores_block(scores):
    if not scores: return ""
    return ('<section class="card"><div class="sech"><span class="ico">&#9678;</span>'
            '勘验 · 九维达成率（得分/满分）</div>%s</section>' % radar_svg(scores))

def headroom_block(hr):
    if not hr: return ""
    bars = ""
    for b in _get(hr, "bars", []):
        p, t = _get(b, "pass", 0), _get(b, "total", 1) or 1
        pct = max(0, min(100, round(100.0 * float(p) / float(t))))
        cls = "bar-pos" if pct >= 50 else "bar-neg"
        bars += ('<div class="barrow"><span class="barlab">%s</span>'
                 '<span class="bartrack"><span class="barfill %s" style="width:%d%%"></span></span>'
                 '<span class="barval">%s/%s</span></div>'
                 % (esc(_get(b, "label", "")), cls, pct, p, t))
    note = ('<p class="hrnote">%s</p>' % esc(hr["note"])) if hr.get("note") else ""
    typ = (' <span class="chip">%s</span>' % esc(hr["type"])) if hr.get("type") else ""
    return ('<section class="card"><div class="sech"><span class="ico">&#9678;</span>'
            'headroom 判定 · 真实任务对照（裸基线＝不装 skill 光用 AI）%s</div>'
            '<div class="bars">%s</div>%s</section>' % (typ, bars, note))

def gaps_block(gaps):
    if not gaps: return ""
    rows = ""
    for g in gaps:
        lv = esc(_get(g, "level", "P1"))
        lvcls = {"P0": "lv0", "P1": "lv1", "P2": "lv2"}.get(lv, "lv1")
        adopted = _get(g, "adopted")
        tags = ""
        for key, lab in (("V", "V 怎么验证"), ("A", "A 问题在哪"), ("K", "K 别弄坏")):
            if g.get(key):
                tags += '<span class="vak">%s：%s</span>' % (lab, esc(g[key]))
        gain = (' <span class="gain">预期 %s</span>' % esc(g["gain"])) if g.get("gain") else ""
        st = ""
        if adopted is True: st = '<span class="ok">采纳</span>'
        elif adopted is False: st = '<span class="no">不采纳</span>'
        rows += ('<div class="gap"><div class="gaphd"><span class="lvtag %s">%s</span>'
                 '<span class="gaptitle">%s</span>%s%s</div>'
                 '<div class="vakrow">%s</div></div>'
                 % (lvcls, lv, esc(_get(g, "title", "")), gain, st, tags))
    return ('<section class="card"><div class="sech"><span class="ico">&#9776;</span>'
            '差距清单（画样）</div>%s</section>' % rows)

def rounds_block(rounds):
    if not rounds: return ""
    items = ""
    for r in rounds:
        verdict = _get(r, "verdict", "")
        ic, icc = "&#9679;", "dot-mid"
        if r.get("pass") is True: ic, icc = "&#10003;", "dot-ok"
        elif r.get("pass") is False: ic, icc = "&#10007;", "dot-no"
        sub = esc(_get(r, "result", ""))
        gates = (" · 门 %s" % esc(r["gates"])) if r.get("gates") else ""
        vv = (" → <b>%s</b>" % esc(verdict)) if verdict else ""
        items += ('<div class="trow"><span class="tdot %s">%s</span><div>'
                  '<div class="ttitle">%s</div><div class="tsub">%s%s%s</div></div></div>'
                  % (icc, ic, esc(_get(r, "variable", "")), sub, gates, vv))
    return ('<section class="card"><div class="sech"><span class="ico">&#9656;</span>'
            '验证门记录（细作）</div><div class="timeline">%s</div></section>' % items)

def sections_block(secs, order):
    if not secs: return ""
    out = ""
    for key, lab in order:
        val = secs.get(key)
        if not val: continue
        body = "".join('<p>%s</p>' % esc(p) for p in (val if isinstance(val, list) else [val]))
        out += ('<section class="card txt"><div class="sech">%s</div>%s</section>' % (lab, body))
    return out

CSS = """
:root{--bg:#fbfbf9;--surface:#fff;--surface2:#f3f1ea;--bd:rgba(0,0,0,.12);
--tx:#26252b;--tx2:#5f5e5a;--tx3:#8a8980;--info-bg:#e6f1fb;--info-tx:#0c447c;
--ok:#1d9e75;--no:#a32d2d;--p0bg:#fceaea;--p0tx:#a32d2d;--p1bg:#faeeda;--p1tx:#854f0b;--p2bg:#eaf3de;--p2tx:#3b6d11;
--rg:rgba(0,0,0,.10);--ra:rgba(0,0,0,.14);--rp:#1d9e75;--rpf:rgba(29,158,117,.18)}
@media (prefers-color-scheme:dark){:root{--bg:#1c1c1e;--surface:#262629;--surface2:#2f2f31;
--bd:rgba(255,255,255,.14);--tx:#eceae4;--tx2:#b4b2a9;--tx3:#888780;--info-bg:#11314f;--info-tx:#b5d4f4;
--ok:#5dcaa5;--no:#f09595;--p0bg:#3a1414;--p0tx:#f09595;--p1bg:#3a2a0a;--p1tx:#fac775;--p2bg:#1f3a14;--p2tx:#c0dd97;
--rg:rgba(255,255,255,.12);--ra:rgba(255,255,255,.16);--rp:#5dcaa5;--rpf:rgba(93,202,165,.22)}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tx);font-size:16px;line-height:1.7;
font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif}
.wrap{max-width:820px;margin:0 auto;padding:2rem 1.25rem 3rem}
h1{font-size:22px;font-weight:500;margin:0}
.sub{font-size:12px;color:var(--tx3)}
.hd{display:flex;align-items:baseline;justify-content:space-between;flex-wrap:wrap;gap:8px;margin-bottom:6px}
.pills{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:1.5rem}
.pill{font-size:12px;padding:3px 10px;border-radius:8px;background:var(--surface2);color:var(--tx2)}
.card{background:var(--surface);border:.5px solid var(--bd);border-radius:12px;padding:1rem 1.25rem;margin-bottom:1rem}
.surface{background:var(--surface2);border:none}
.sech{font-size:13px;color:var(--tx3);margin:0 0 12px;display:flex;align-items:center;gap:6px;flex-wrap:wrap}
.ico{color:var(--tx2)}
.human{background:var(--info-bg)}
.human .sech{color:var(--info-tx)}.human .ico{color:var(--info-tx)}
.hlead,.human p,.human li{color:var(--info-tx)}
.hlist{margin:0;padding-left:1.1rem}.hlist li{margin:6px 0}
.hafter{color:var(--info-tx);opacity:.85}
.hnote{font-size:12px;opacity:.8;margin:10px 0 0;font-style:italic}
.vgrid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:14px}
.vc-lab{font-size:12px;color:var(--tx2)}.vc-big{font-size:22px;font-weight:500;margin-top:2px}
.vsub{font-size:14px;color:var(--tx3)}.vc-sub{font-size:11px;color:var(--tx3)}
.radar{display:block;margin:0 auto;max-width:420px}
.rg{fill:none;stroke:var(--rg);stroke-width:1}
.ra{stroke:var(--ra);stroke-width:1}
.rp{fill:var(--rpf);stroke:var(--rp);stroke-width:2}
.rpd{fill:var(--rp)}
.rl{font-size:11px;fill:var(--tx2)}.rlv{fill:var(--tx3)}
.bars{display:flex;flex-direction:column;gap:10px}
.barrow{display:flex;align-items:center;gap:10px}
.barlab{width:84px;font-size:13px;color:var(--tx2)}
.bartrack{flex:1;background:var(--surface2);border-radius:6px;height:20px;overflow:hidden}
.barfill{display:block;height:100%}.bar-pos{background:var(--ok)}.bar-neg{background:var(--tx3)}
.barval{font-size:13px;font-weight:500;min-width:46px;text-align:right}
.hrnote{font-size:12px;color:var(--tx2);margin:10px 0 0}
.chip{font-size:11px;padding:2px 8px;border-radius:8px;background:var(--surface2);color:var(--tx2)}
.gap{border:.5px solid var(--bd);border-radius:8px;padding:10px 12px;margin-bottom:8px}
.gaphd{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:8px}
.gaptitle{font-size:14px;font-weight:500}
.lvtag{font-size:11px;padding:2px 8px;border-radius:8px}
.lv0{background:var(--p0bg);color:var(--p0tx)}.lv1{background:var(--p1bg);color:var(--p1tx)}.lv2{background:var(--p2bg);color:var(--p2tx)}
.gain{font-size:11px;color:var(--tx3)}
.ok{font-size:11px;color:var(--ok)}.no{font-size:11px;color:var(--no)}
.vakrow{display:flex;flex-wrap:wrap;gap:6px}
.vak{font-size:11px;padding:2px 8px;border-radius:8px;background:var(--surface2);color:var(--tx2)}
.timeline{display:flex;flex-direction:column}
.trow{display:flex;gap:10px;padding:8px 0;border-bottom:.5px solid var(--bd)}
.trow:last-child{border-bottom:none}
.tdot{font-size:16px;line-height:1.4}.dot-ok{color:var(--ok)}.dot-no{color:var(--tx3)}.dot-mid{color:var(--tx2)}
.ttitle{font-size:14px}.tsub{font-size:12px;color:var(--tx2)}
.txt p{margin:.3rem 0}
.foot{font-size:12px;color:var(--tx3);margin-top:1rem}
"""

FULL_SECTIONS = [("xiangdi", "相地 · 立项审查"), ("fangli", "访例 · 同类调研"),
                 ("dingshi", "定式 · 生态位"), ("readme", "README 与展示升级建议"),
                 ("plan", "执行计划"), ("suixiu", "岁修清单")]

def build(data):
    kind = _get(data, "kind", "full")
    m = _get(data, "meta", {})
    title = "%s · %s报告" % (esc(_get(m, "skill", "skill")),
                            "大修" if kind == "full" else "查勘")
    head = ('<div class="hd"><h1>%s</h1><span class="sub">营造 yingzao · %s</span></div>%s'
            % (title, esc(_get(m, "date", "")), meta_bar(m)))
    blocks = [head, human_block(_get(data, "human"))]
    if kind == "full":
        blocks += [verdict_block(_get(data, "verdict")),
                   scores_block(_get(data, "scores")),
                   headroom_block(_get(data, "headroom")),
                   gaps_block(_get(data, "gaps")),
                   rounds_block(_get(data, "rounds")),
                   sections_block(_get(data, "sections"), FULL_SECTIONS)]
    else:
        blocks += [scores_block(_get(data, "scores")),
                   gaps_block(_get(data, "gaps")),
                   sections_block(_get(data, "sections"),
                                  [("sanwen", "相地三问"), ("advice", "下一步建议")])]
    foot = ('<p class="foot">营造 yingzao 报告引擎 · 自包含 HTML（内联 SVG · 零外部依赖）。'
            '同源 markdown 报告含完整明细。</p>')
    body = "".join(b for b in blocks if b) + foot
    return ('<!DOCTYPE html><html lang="zh"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>%s</title><style>%s</style></head><body><div class="wrap">%s</div></body></html>'
            % (title, CSS, body))

def main():
    if len(sys.argv) < 3:
        sys.stderr.write("用法: render-report.py <data.json> <out.html>\n")
        return 2
    try:
        with open(sys.argv[1], encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        sys.stderr.write("数据读取/解析失败: %s\n" % e)
        return 2
    out = build(data)
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(out)
    sys.stderr.write("✓ 已渲染自包含 HTML 报告 → %s（%d 字节·零外部依赖）\n"
                     % (sys.argv[2], len(out.encode("utf-8"))))
    return 0

if __name__ == "__main__":
    sys.exit(main())
