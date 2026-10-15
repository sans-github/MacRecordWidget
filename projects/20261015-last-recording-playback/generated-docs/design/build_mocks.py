#!/usr/bin/env python3
"""Generates the last-recording-playback mocks. Reuses the master mocks' <head> CSS verbatim
(.head.html, copied from projects/master/mocks/popover-idle.html) and adds only playback styles."""
import os
D = os.path.dirname(os.path.abspath(__file__))
HEAD = open(os.path.join(D, '.head.html')).read()
EXTRA = """<style>
.ctl.on .g, .tbtn.on{color:#fff}
.timer{position:relative;overflow:hidden}
.timer .prog{position:absolute;left:0;bottom:0;height:2px;background:var(--blue)}
.tbtn{display:inline-flex;align-items:center;gap:3px;background:var(--ctl);border:1px solid var(--sep);font-variant-numeric:tabular-nums;white-space:nowrap;flex:none;position:relative;overflow:hidden;color:var(--label)}
.tbtn.idle .t{color:var(--label2)}
.tbtn.on{background:var(--blue);border-color:transparent}
.tbtn.on .prog{position:absolute;left:0;bottom:0;height:2px;background:rgba(255,255,255,.9)}
.tbtn.on .track{position:absolute;left:0;right:0;bottom:0;height:2px;background:rgba(255,255,255,.3)}
.tbtn .pg{display:inline-flex}.tbtn .pg.dim{opacity:.35}
.scene{position:absolute;inset:0;overflow:hidden}
.scene .who{position:absolute;bottom:0;width:30%;height:62%;border-radius:50% 50% 0 0;background:rgba(40,30,25,.55)}
.scene .sign{position:absolute;top:24%;padding:2px 8px;background:#f4efe6;color:#222;font:700 15px/1.2 -apple-system,sans-serif;border-radius:3px}
.mirrored{transform:scaleX(-1)}
.ov{position:absolute;color:#fff;font-size:11px;display:flex;align-items:center;gap:5px;background:rgba(30,30,32,.62);backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px);border:.5px solid rgba(255,255,255,.18)}
.badge{top:10px;left:10px;padding:3px 9px 3px 7px;border-radius:999px}
.badge small{opacity:.75;font-size:10px}
.live{top:10px;right:10px;padding:3px 9px;border-radius:999px;font-weight:500}
.transport{left:12px;right:12px;bottom:12px;padding:6px 10px;border-radius:10px;gap:9px;font-variant-numeric:tabular-nums}
.transport .bar{flex:1;height:4px;border-radius:2px;background:rgba(255,255,255,.3);position:relative}
.transport .bar i{position:absolute;left:0;top:0;bottom:0;border-radius:2px;background:#fff}
.transport .bar b{position:absolute;top:-4px;width:12px;height:12px;border-radius:50%;background:#fff;box-shadow:0 .5px 2px rgba(0,0,0,.5);margin-left:-6px}
.center{left:50%;top:50%;transform:translate(-50%,-50%);flex-direction:column;padding:12px 18px;border-radius:12px;font-size:12px;gap:6px}
.dimmed{filter:brightness(.55)}
.focus{outline:3px solid rgba(0,122,255,.55);outline-offset:1px}
.spec td:first-child{white-space:nowrap}
.stage.dark p.note{color:#a1a1a6 !important}
.tag{display:inline-block;font-size:11px;padding:0 6px;border-radius:4px;background:var(--code);margin-right:4px}
</style>"""

def svg(body, s):
    return f'<svg width="{s}" height="{s}" viewBox="0 0 24 24" aria-hidden="true">{body}</svg>'
G = {
 'pin': '<path d="M8 1.5h8l-1.2 1.6v5.2l3.4 3.6v1.6H13v6.5L12 22l-1-2V13.5H5.8v-1.6l3.4-3.6V3.1z" fill="currentColor"/>',
 'mic': '<rect x="8.5" y="2" width="7" height="12" rx="3.5" fill="currentColor"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M8.5 21h7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
 'video': '<rect x="2" y="6" width="13.5" height="12" rx="2.5" fill="currentColor"/><path d="M16.5 10.2l5.5-3.2v10l-5.5-3.2z" fill="currentColor"/>',
 'mirror': '<path d="M12 2.5v19" stroke="currentColor" stroke-width="1.4" stroke-dasharray="2 2"/><path d="M10 9L3 20h7z M14 9l7 11h-7z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="M4.5 5h15M4.5 5l2-2M4.5 5l2 2M19.5 5l-2-2M19.5 5l-2 2" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
 'power': '<path d="M12 3v8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M7.2 6.2a7.5 7.5 0 1 0 9.6 0" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
 'chev': '<path d="M5 9l7 7 7-7" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>',
 'play': '<path d="M7 4.2v15.6c0 .8.9 1.3 1.6.8l12-7.8c.6-.4.6-1.2 0-1.6l-12-7.8C7.9 2.9 7 3.4 7 4.2z" fill="currentColor"/>',
 'pause': '<rect x="6" y="4" width="4" height="16" rx="1" fill="currentColor"/><rect x="14" y="4" width="4" height="16" rx="1" fill="currentColor"/>',
 'replay': '<path d="M4 12a8 8 0 1 0 2.4-5.7M4 3.5v4.5h4.5" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',
 'warn': '<path d="M12 3L2 20.5h20z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M12 9.5v5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="17.5" r="1.2" fill="currentColor"/>',
 'wave': '<path d="M3 10v4M7 7v10M11 4v16M15 8v8M19 6v12" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
 'playrectf': '<path fill-rule="evenodd" d="M5 4h14a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3V7a3 3 0 0 1 3-3zm5 4.5v7l6-3.5z" fill="currentColor"/>',
 'playrect':'<rect x="2" y="4" width="20" height="16" rx="3" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M10 8.5v7l6-3.5z" fill="currentColor"/>',
}
# PanelScale values, straight from PanelSizer.swift / master panel-scale.html
SC = {
 'S': dict(w=380, gap=8, pad='6px 10px 6px', cw=24, h=17, r=4, gs=14, sv=13, tp=5, tf=10, gg=4.0, mw=110, wl=11, cv=7, lf=9, dot=5),
 'M': dict(w=480, gap=14, pad='8px 12px 8px', cw=26, h=20, r=5, gs=16, sv=15, tp=6, tf=12, gg=7.0, mw=200, wl=13, cv=8, lf=12, dot=6),
 'L': dict(w=640, gap=18, pad='7px 16px 6px', cw=27, h=22, r=6, gs=17, sv=16, tp=8, tf=13, gg=9.0, mw=260, wl=14, cv=9, lf=13, dot=7),
}

def ctl(s, glyph, label, st='off', red=False, inner=None):
    """st: off | on | dis | load. on = fully round blue (red if red=True) filled capsule."""
    c = SC[s]
    cls = 'ctl' + (' red' if red else '')
    rad = c['r']
    extra = ''
    if st in ('on', 'rec'):
        cls += ' on' + (' red ember' if st == 'rec' else '')
        rad = c['h'] / 2
        if st == 'rec':
            o = -0.45 * c['dot']
            extra = f'<span class="dot" style="width:{c["dot"]}px;height:{c["dot"]}px;right:{o:.2f}px;bottom:{o:.2f}px"></span>'
    if st == 'dis': cls += ' disabled'
    if st == 'arm': cls += ' on red'; rad = c['h'] / 2
    gcls = 'g arming' if st in ('load', 'arm') else 'g'
    body = inner or svg(G[glyph], c['sv'])
    return (f'<span class="{cls}" role="button" aria-label="{label}" style="width:{c["cw"]}px;height:{c["h"]}px;border-radius:{rad}px">'
            f'<span class="{gcls}" style="width:{c["gs"]}px;height:{c["gs"]}px;display:inline-flex;align-items:center;justify-content:center">{body}</span>{extra}</span>')

def timer(s, t, idle=True, prog=None):
    c = SC[s]
    p = f'<span class="prog" style="width:{prog}%"></span>' if prog is not None else ''
    return (f'<span class="timer{" idle" if idle else ""}" role="timer" aria-label="Recording time" '
            f'style="height:{c["h"]}px;padding:0 {c["tp"]}px;border-radius:{c["r"]}px;font-size:{c["tf"]}px">{t}{p}</span>')

MEDLBL = {'audio': 'audio', 'video': 'video'}
def tbtn(s, t, st='idle', prog=None, med='audio', cue='swap'):
    """Option B: the timer box becomes a button. st: idle | on | rec | dis | load | none.
    cue: how the last medium is shown before pressing. trail = medium glyph after the time (recommended),
    badge = mini medium glyph on the play triangle's corner, swap = medium-specific play glyph, none = play only."""
    c = SC[s]
    if st == 'none': med = None
    ms = c['sv'] - 4
    label = (f'Play your last recording, {med}, {t}' if med else 'No recording yet')
    if st == 'on': label = f'Stop playing the last {med}'
    if st == 'rec': label = 'Recording time'
    mg = ''
    if med and cue == 'trail':
        mg = f'<span class="pg{" dim" if st == "rec" else ""}" style="opacity:{1 if st in ("on",) else .7}">{svg(G["mic" if med == "audio" else "video"], ms)}</span>'
    pglyph = svg(G['play'], ms)
    if med and cue == 'badge':
        b = svg(G['mic' if med == 'audio' else 'video'], 8)
        pglyph = f'<span style="position:relative;display:inline-flex">{pglyph}<span style="position:absolute;right:-5px;bottom:-4px;display:inline-flex">{b}</span></span>'
    if med and cue == 'swap':
        pglyph = svg(G['playrectf'] if med == 'video' else G['wave'], ms + 2)
    tip = {'audio': f'Play last voice recording ({t})', 'video': f'Play last video recording ({t})', None: 'No recording yet'}[med]
    if st == 'on': tip = f'Stop playing ({t})'
    if st == 'rec': tip = 'Recording time'
    return _tbtn(s, t, st, prog, label, pglyph, mg).replace(' role=', f' title="{tip}" role=', 1)

def _tbtn(s, t, st, prog, label, pglyph, mg):
    c = SC[s]
    cls = 'tbtn'
    rad = c['r']
    if st == 'on': cls += ' on'; rad = c['h'] / 2
    if st in ('idle', 'none', 'load'): cls += ' idle'
    if st == 'none': cls += ' disabled'
    gd = ' dim' if st in ('rec', 'none', 'load') else ''
    p = ''
    if st == 'on': p = f'<span class="track"></span><span class="prog" style="width:{prog}%"></span>'
    op = ';opacity:.45' if st == 'none' else ''
    role = 'timer' if st == 'rec' else 'button'
    return (f'<span class="{cls}" role="{role}" aria-label="{label}" style="height:{c["h"]}px;padding:0 {c["tp"]}px 0 {c["tp"]-1}px;border-radius:{rad}px;font-size:{c["tf"]}px{op}">'
            f'<span class="pg{gd}">{pglyph}</span><span class="t">{t}</span>{mg}{p}</span>')

def row(s, opt, st):
    """opt: 'A' | 'B' | None (shipped). st: dict of overrides."""
    c = SC[s]
    d = dict(pin='on', mic='off', vid='off', pa='off', pv='off', pb='idle', t='04:17', tidle=True, tprog=None,
             mirror='on', menu=True, scale=s, cam='Logitech BRIO')
    d.update(st)
    mic = ctl(s, 'mic', 'Stop and save to Voice Memos' if d['mic'] == 'rec' else 'Record audio to Voice Memos', d['mic'], red=True)
    vid = ctl(s, 'video', 'Stop video recording' if d['vid'] == 'rec' else 'Record video to Photo Booth', d['vid'], red=True)
    g = c['gg']
    if opt == 'A':
        pa = ctl(s, 'play', 'Stop playing the last audio' if d['pa'] == 'on' else 'Play the last audio recording', d['pa'])
        pv = ctl(s, 'play', 'Stop playing the last video' if d['pv'] == 'on' else 'Play the last video recording', d['pv'])
        grp = f'{mic}{pa}{timer(s, d["t"], d["tidle"], d["tprog"])}{pv}{vid}'
    elif opt == 'B':
        grp = f'{mic}{tbtn(s, d["t"], d["pb"], d["tprog"], d.get("med", "audio"), d.get("cue", "swap"))}{vid}'
    else:
        grp = f'{mic}{timer(s, d["t"], d["tidle"])}{vid}'
    menu_op = '' if d['menu'] else ' disabled'
    menu = (f'<span class="menu{menu_op}" role="button" aria-label="Preview camera" style="height:{c["h"]}px;border-radius:{c["r"]}px;padding:0 4px 0 7px;max-width:{c["mw"]}px;font-size:{c["tf"]}px">'
            f'<span class="name">{d["cam"]}</span><span class="well" style="width:{c["wl"]}px;height:{c["gs"]}px">{svg(G["chev"], c["cv"])}</span></span>')
    sizes = ''.join(ctl(s, None, f'{n} preview size', 'on' if k == d['scale'] else 'off',
                        inner=f'<span style="font-size:{c["lf"]}px">{k}</span>')
                    for k, n in (('S', 'Small'), ('M', 'Medium'), ('L', 'Large')))
    return (f'<div class="row" style="gap:{c["gap"]}px;padding:{c["pad"]}">'
            f'{ctl(s, "pin", "Keep panel open", d["pin"])}<span class="grp" style="gap:{g}px">{grp}</span>'
            f'{ctl(s, "mirror", "Show the preview as others see it", d["mirror"])}<span class="spacer" style="min-width:12px"></span>'
            f'{menu}<span class="grp" style="gap:2px">{sizes}</span>{ctl(s, "power", "Quit MacRecordWidget", "on")}</div>')

def scene(mirrored):
    m = ' mirrored' if mirrored else ''
    return (f'<div class="scene{m}"><span class="who" style="left:22%"></span>'
            f'<span class="sign" style="left:60%">HELLO</span></div>')

def preview(s, mode='live', **k):
    """mode: live | playing | paused | finished | missing | opening | row (no preview)"""
    if mode == 'row': return ''
    c = SC[s]
    w, h = c['w'], round(c['w'] * 9 / 16)
    st = f'width:{w}px;height:{h}px;border-radius:0 0 10px 10px'
    if mode == 'live':
        return f'<div class="preview" style="{st}">{scene(True)}</div>'
    if mode in ('missing', 'opening'):
        body = ('<span class="spin"></span><span>Opening the last video…</span>' if mode == 'opening' else
                f'{svg(G["warn"], 22)}<span>The last video is no longer in Photo Booth’s library. It may have been deleted there.</span><span class="btn">Back to Live Camera</span>')
        return f'<div class="preview dark-bg" style="{st}"><div class="msg">{body}</div></div>'
    el, du, pct = k.get('el', '00:42'), k.get('du', '01:36'), k.get('pct', 44)
    dim = ' dimmed' if mode == 'finished' else ''
    out = f'<div class="preview" style="{st}"><div class="scene{dim}" style="position:absolute;inset:0">{scene(False)}</div>'
    out += (f'<span class="ov badge" role="note" aria-label="Playing your last video, shown as others see it">{svg(G["playrect"], 12)}Last video'
            f'<small>&nbsp;·&nbsp;as others see it</small></span>')
    out += '<span class="ov live" role="button" aria-label="Back to live camera">Live Camera</span>'
    if mode == 'finished':
        out += f'<span class="ov center" role="button" aria-label="Replay the last video">{svg(G["replay"], 22)}Replay</span>'
        pct, el = 100, du
    pp = 'pause' if mode == 'playing' else 'play'
    out += (f'<span class="ov transport"><span role="button" aria-label="{"Pause" if pp == "pause" else "Play"}" style="display:inline-flex">{svg(G[pp], 14)}</span>'
            f'<span>{el}</span><span class="bar" role="slider" aria-label="Playback position"><i style="width:{pct}%"></i><b style="left:{pct}%"></b></span>'
            f'<span style="opacity:.75">{du}</span></span></div>')
    return out

def panel(s, opt, st=None, mode='live', theme='light', **k):
    c = SC[s]
    return (f'<div class="mac {theme}"><div class="panel" style="width:{c["w"]}px">{row(s, opt, st or {})}'
            f'{preview(s, mode, **k)}</div></div>')

def pair(title, fn, note=''):
    """fn(theme) -> html. Renders light and dark side by side."""
    n = f'<p class="note">{note}</p>' if note else ''
    return (f'<h2>{title}</h2><div class="pair">'
            + ''.join(f'<div><h3>{t.title()}</h3><div class="stage {t}">{fn(t)}</div></div>' for t in ('light', 'dark'))
            + f'</div>{n}')

def stack(items):
    """items: list of (caption, html) rendered vertically inside one stage."""
    return '<div style="height:14px"></div>'.join(
        f'<p class="note" style="color:inherit;margin:0 0 6px">{cap}</p>{h}' for cap, h in items)

def page(name, title, lede, body):
    html = (HEAD.replace('<title>Panel, Idle</title>', f'<title>{title}</title>') + EXTRA +
            f'</head><body><main><nav class="crumbs"><a href="index.html">All playback mocks</a></nav>'
            f'<h1>{title}</h1><p class="lede">{lede}</p>{body}</main></body></html>')
    open(os.path.join(D, name), 'w').write(html)

# ---------- row-options.html ----------
def B(s, th, w=None, **st):
    h = panel(s, 'B', dict(scale=s, **st), 'row', th)
    return h.replace(f'width:{SC[s]["w"]}px', f'width:{w}px') if w else h

CUES = [
 ('1. Medium-specific play glyph (recommended)', 'swap',
  'Audio: <code>waveform</code>, the same mark as Voice Memos’ icon, which is where the file lives. Video: <code>play.rectangle.fill</code>, the standard “play a video” symbol. Both exist on macOS 14 (SF Symbols 1.0, macOS 11+). The glyph replaces the play triangle, so it costs no more width than a plain ▶. Tooltip names the medium and length: “Play last voice recording (04:17)” / “Play last video recording (01:36)”. With nothing recorded it shows <code>play.fill</code>, disabled, tooltip “No recording yet”. Known weakness: <code>waveform</code> on its own does not say “play”; the button capsule, the tooltip and the result of the press carry that.'),
 ('2. Alternative: play glyph + medium glyph after the time', 'trail',
  'Reads “▶ 04:17 🎙” using the record buttons’ own glyphs. Clearer play affordance, but costs an extra glyph (~14pt) of camera menu width at every scale. Not chosen.'),
 ('3. Alternative: mini medium badge on the play triangle', 'badge',
  'Zero width cost, but the badge is 7 to 8pt at Small, too small to tell mic from video, and a corner badge already means “live” in this row. Not chosen.'),
]
body = '<p class="note">Requirement: before pressing, the user can tell at a glance whether “play last” will play audio or video. Three ways explored, Medium scale, last recording audio (top) and video (bottom).</p>'
for title, cue, note in CUES:
    body += pair(title, lambda t, cue=cue: stack([('Last was audio', B('M', t, med='audio', cue=cue)),
                                                ('Last was video', B('M', t, med='video', cue=cue, t='01:36'))]), note)
body += '<p class="note">Tooltips are on the play-last control in every row on this page: hover to see them.</p>'
body += pair('Recommended glyphs at S, M, L (shipped widths), last audio then last video', lambda t: stack([(f'{s} {m}: {SC[s]["w"]}pt', B(s, t, med=m, t='04:17' if m == 'audio' else '01:36')) for s in 'SML' for m in ('audio', 'video')]),
             'Small is left with an ellipsis only; Medium truncates one letter more than today; Large is unaffected.')
body += pair('Recommended: widen Small by 20pt, leave Medium and Large', lambda t: stack([('S at 400pt (+20)', B('S', t, 400)), ('M at 480pt (unchanged)', B('M', t)), ('L at 640pt (unchanged)', B('L', t))]),
             'Widening Small restores the name to today’s “Logi…”. Medium loses only ~15pt (“Logitech…” to about “Logi…”), which I judge acceptable for the default size rather than changing it. The preview grows with the panel (400x225).')
body += """<h2>Row width budget (estimated)</h2>
<p class="note">Estimates from PanelScale values and the mock's text metrics, not measured on hardware. "Name" is what is left after the menu's own padding and chevron well (~27 to 30pt). "Logitech BRIO" needs about 62pt at 10pt, 74pt at 12pt, 80pt at 13pt. The rendered rows above are the better evidence.</p>
<table><tr><th>Scale</th><th>Shipped: menu / name</th><th>Play last, medium glyph (+~13/15/16pt): menu / name</th><th>Recommendation</th></tr>
<tr><td>S 380</td><td>~56 / ~29 (“Logi…”)</td><td>~43 / ~15 (ellipsis only)</td><td><b>Widen to 400 (+20)</b>: ~63 / ~35</td></tr>
<tr><td>M 480</td><td>~87 / ~58 (“Logitech…”)</td><td>~72 / ~43 (“Logi…”)</td><td>Accept the truncation</td></tr>
<tr><td>L 640</td><td>~196 / full</td><td>~180 / full</td><td>No change</td></table>
<h2>Appendix: Option A (two buttons), not chosen</h2>"""
body += pair('Option A at S, M, L', lambda t: stack([(f'{s}: {SC[s]["w"]}pt', panel(s, 'A', dict(scale=s), 'row', t)) for s in 'SML']),
             'Two identical play buttons flanking the timer. Costs 56 to 72pt; collapses the camera menu at Small and hides the name at Medium. Kept for the record only.')
page('row-options.html', 'Playback: The “Play Last” Control',
     'One “play last” control, merged into the timer box, which already shows the last recording’s length while idle. Its glyph says which medium it will play. This page also covers what it costs the camera menu at each scale.', body)

# ---------- audio-playback.html ----------
AUD = [
 ('Has a last recording, idle', dict(), dict(), 'Play is a bordered capsule. The timer shows the last recording’s length, faded, as it does today.'),
 ('Nothing recorded yet (disabled)', dict(pa='dis', pv='dis', t='00:00'), dict(pb='none', t='00:00'),
  'Disabled with a tooltip and VoiceOver hint: “No recording yet.” Not hidden: hiding it would move the camera menu on first record.'),
 ('Opening (file not written yet)', dict(pa='load'), dict(pb='load'),
  'Voice Memos writes the .m4a only after Stop. If Play is pressed in that window, the glyph dims (same treatment as arming) and the app retries for up to 5s before showing the error below.'),
 ('Playing', dict(pa='on', t='01:52', tidle=False, tprog=44), dict(pb='on', t='01:52', tprog=44),
  'Lit blue, fully round. The timer counts up the playback position (same MM:SS width, so nothing shifts) and gains a 2pt progress line. Press again to stop (no pause for audio: the simpler option, flagged as open). The live preview keeps running: audio playback never takes the preview surface.'),
 ('Finished', dict(), dict(), 'Returns to the idle look by itself: off capsule, timer back to the full length, faded. No “finished” badge: the row already says it.'),
]
body = ''
for title, a, b, note in AUD:
    body += pair(title, lambda t, a=a, b=b: panel('M', 'B', b, 'row', t), note)
alert = (f'<div class="alert"><div class="ico" style="background:linear-gradient(#5ea2ff,#0a66d8)">{svg(G["warn"], 30)}</div>'
         '<b>Can’t Play the Last Recording</b><p>MacRecordWidget couldn’t open the recording in Voice Memos. It may still be saving, '
         'it may have been deleted, or macOS may be blocking access to Voice Memos’ files.</p><span class="ok">OK</span>'
         '<span style="display:block;margin-top:6px;font-size:13px;padding:4px 0;border-radius:6px;background:var(--ctl);border:1px solid var(--sep)">Open Voice Memos</span></div>')
body += pair('Couldn’t find the recording', lambda t: f'<div class="mac {t}">{alert}</div>',
             'Same <code>.alert</code> pattern as the shipped “Could Not Start Recording”. An alert, not inline text: the row has no room for a message and audio has no surface of its own. '
             'The icon is the app badge in blue, not red, because nothing failed to capture. After OK the row returns to idle; the play control stays enabled so the user can retry.')
page('audio-playback.html', 'Playback: Audio States',
     'Audio plays in-app from the Voice Memos file. Shown at Medium (rows only, the preview is unaffected). Last recording is audio throughout.', body)

# ---------- video-playback.html ----------
VID = [
 ('Live preview (unchanged, mirrored by default)', 'live', dict(pv='off'), dict(),
  'For comparison. The sign reads backwards because the preview is mirrored.'),
 ('Opening', 'opening', dict(pv='load'), dict(pb='load', mirror='dis'), 'Spinner while the asset loads. Usually too brief to see.'),
 ('Playing', 'playing', dict(pv='on', t='00:42', tidle=False, tprog=44, mirror='dis'), dict(pb='on', t='00:42', tprog=44, mirror='dis'),
  'Badge top left says this is the recording, not the camera. “Live Camera” top right returns to the preview. Transport at the bottom: pause, elapsed, scrubber, duration. '
  'Note the image: the sign now reads correctly and the person is on the other side, because the file is unmirrored and the preview is not. Mirror is disabled while a video plays (it acts on the preview only, and must not suggest it can flip the file).'),
 ('Paused', 'paused', dict(pv='on', t='00:42', tidle=False, tprog=44, mirror='dis'), dict(pb='on', t='00:42', tprog=44, mirror='dis'),
  'Same as playing with a play glyph in the transport. The row control stays lit: the playback session is still open. When the video reaches its end it returns to the live camera by itself (no finished state, no Replay); the row control goes back to off and Mirror re-enables.'),
 ('Video missing', 'missing', dict(pv='off', mirror='dis'), dict(pb='idle', mirror='dis'),
  'The .mov was deleted or moved in Photo Booth. Message on the preview surface, same style as the camera message states.'),
]
body = ''
for title, mode, a, b, note in VID:
    kw = dict(el='00:42', du='01:36', pct=44)
    body += pair(title, lambda t, mode=mode, a=a, b=b, kw=kw: panel('M', 'B', dict(dict(t='01:36'), **b, med='video'), mode, t, **kw), note)
body += pair('Small scale, playing (400pt)', lambda t: panel('S', 'B', dict(pb='on', t='00:42', tprog=44, mirror='dis', scale='S', med='video'), 'playing', t)
             .replace('width:380px', 'width:400px').replace('height:214px', 'height:225px'),
             'At Small the badge drops its secondary text if it would collide with Live Camera.')
body += """<h2>Mirroring callout</h2><p class="note">The live preview defaults to mirrored; the file is pinned unmirrored. So in playback the user’s image flips relative to what they just saw, while text in the scene reads correctly. The badge’s secondary text “as others see it” reuses the mirror toggle’s own wording to explain the flip without a tooltip. The mirror toggle is <b>disabled</b> (dimmed, tooltip “Mirroring applies to the live camera”) from Opening until the user returns to Live Camera, and playback ignores the stored setting: flipping a recording would show text backwards, which is the defect turning file mirroring off fixed.</p>"""
page('video-playback.html', 'Playback: Video on the Preview Surface',
     'Video plays where the camera preview shows, at the same 16:9 size. Overlay controls are drawn on a dark material so they read the same in light and dark appearance; only the row changes.', body)

# ---------- exclusivity.html ----------
EX = [
 ('Recording audio: playback disabled', dict(mic='rec', vid='dis', pa='dis', pv='dis', t='00:31', tidle=False), dict(mic='rec', vid='dis', pb='rec', t='00:31'), 'live',
  'All playback is disabled while either medium records. The timer box stops being a button: its play glyph dims and it reads as the recording clock again.'),
 ('Recording video: playback disabled', dict(vid='rec', mic='dis', pa='dis', pv='dis', t='00:31', tidle=False, menu=False), dict(vid='rec', mic='dis', pb='rec', t='00:31', menu=False, med='video'), 'live', ''),
 ('Playing audio, user presses record: playback stops, recording arms', dict(), dict(mic='arm', pb='rec', t='00:00'), 'live',
  'Record buttons stay <b>enabled</b> during playback. Pressing one stops playback at once, then the normal arming state shows (red capsule, glyph dimmed) for as long as setup takes, then recording starts. Play last is disabled from the press onward.'),
 ('Playing video, user presses video record: back to live, then arming', dict(), dict(vid='arm', mic='dis', pb='rec', t='00:00', med='video', menu=False), 'live',
  'Playback stops and the surface returns to the live camera first, so the arming state is never drawn over the old video. Mirror re-enables with the live camera.'),
]
body = ''
for title, a, b, mode, note in EX:
    body += pair(title, lambda t, a=a, b=b, mode=mode: panel('M', 'B', b, mode, t), note)
body += """<h2>State matrix</h2><table>
<tr><th>While…</th><th>Record audio</th><th>Record video</th><th>Play last</th><th>Mirror</th><th>Camera menu</th><th>S/M/L</th></tr>
<tr><td>Idle, has recording</td><td>enabled</td><td>enabled</td><td>enabled</td><td>enabled</td><td>enabled</td><td>enabled</td></tr>
<tr><td>Idle, nothing recorded</td><td>enabled</td><td>enabled</td><td>disabled</td><td>enabled</td><td>enabled</td><td>enabled</td></tr>
<tr><td>Arming / recording audio</td><td>lit red (stop)</td><td>disabled</td><td>disabled</td><td>enabled</td><td>enabled</td><td>enabled</td></tr>
<tr><td>Arming / recording video</td><td>disabled</td><td>lit red (stop)</td><td>disabled</td><td>enabled</td><td>disabled</td><td>enabled</td></tr>
<tr><td>Playing audio</td><td>enabled: stops playback, arms, records</td><td>enabled: stops playback, arms, records</td><td>lit blue (stop)</td><td>enabled</td><td>enabled</td><td>enabled</td></tr>
<tr><td>Playing / paused video</td><td>enabled: back to live, arms, records</td><td>enabled: back to live, arms, records</td><td>lit blue (stop)</td><td>disabled</td><td>enabled (applies when back to live)</td><td>enabled (video rescales)</td></tr>
</table><p class="note">Panel closing during playback stops playback (unlike a video recording, nothing is lost) and the next open shows the live camera.</p>"""
page('exclusivity.html', 'Playback: Recording and Playback Exclusivity',
     'Recording and playback never run together. Recording blocks playback; record during playback wins and ends it.', body)

# ---------- index.html ----------
body = """<ul class="links">
<li><a href="row-options.html">The “play last” control</a>: how it shows audio vs video before pressing (recommended glyphs + 2 alternatives), S/M/L widths, width recommendation, Option A appendix</li>
<li><a href="audio-playback.html">Audio states</a>: idle, nothing recorded, opening, playing, finished, can’t find</li>
<li><a href="video-playback.html">Video states</a>: opening, playing, paused, missing, auto-return to live, mirroring callout</li>
<li><a href="exclusivity.html">Exclusivity</a>: what recording disables, record during playback, state matrix</li></ul>
<h2>Glyph decision: no play/stop swap</h2>
<p class="note">The play last control keeps its medium glyph (<code>waveform</code> or <code>play.rectangle.fill</code>) and flips its fill, like the record toggles; it never swaps to stop. The row’s rule is “lit means active, press again to end it”; the pin is the only glyph swapper and adding a second one would make the rule two rules. Transport glyphs that do swap (play/pause) live in the video overlay, where QuickTime’s convention applies and users expect it. The VoiceOver label carries the action: “Play your last recording, audio, 04:17” / “Stop playing the last audio”.</p>
<h2>Component spec</h2><table class="spec">
<tr><th>Element</th><th>SwiftUI / AppKit</th><th>States</th><th>Accessibility</th></tr>
<tr><td>Play last</td><td><code>Button</code> whose label is <code>HStack { Image(systemName: medium == .audio ? "waveform" : "play.rectangle.fill"); RecordingTimer }</code> (<code>play.fill</code> when nothing is recorded) with <code>.help("Play last voice recording (04:17)")</code>, same capsule style as the row (off = bordered, on = round blue), pinned to <code>controlHeight</code>; while recording it is <code>.disabled</code> and keeps <code>accessibilityAddTraits(.updatesFrequently)</code></td><td>idle, hover, pressed, on (blue, white text + 2pt progress), opening, disabled (nothing recorded), recording (readout)</td><td>“Play your last recording, audio, 4 minutes 17 seconds” (names the medium so VoiceOver users are not left guessing)</td></tr>
<tr><td>Timer progress line</td><td><code>GeometryReader</code>-free overlay: <code>Rectangle().frame(height: 2)</code> scaled by fraction, <code>.blue</code> / white on blue</td><td>shown only while playing</td><td>timer value reads “1 minute 52 of 4 minutes 17”</td></tr>
<tr><td>Video surface</td><td><code>AVPlayerView</code> (AVKit, <code>NSViewRepresentable</code>), <code>controlsStyle = .floating</code>, <code>videoGravity = .resizeAspect</code>, drawn <b>over</b> the always-mounted preview layer (the preview layer must stay mounted: see the deadlock rules in CLAUDE.md)</td><td>opening, playing, paused, missing; returns to live at end</td><td>native transport is already accessible</td></tr>
<tr><td>“Last video” badge</td><td><code>Label</code> on <code>.regularMaterial</code> (dark scheme forced) in a <code>Capsule</code></td><td>static</td><td><code>.accessibilityElement(children: .combine)</code>, “Playing your last video, shown as others see it”</td></tr>
<tr><td>Live Camera</td><td><code>Button</code>, <code>.buttonStyle(.plain)</code> on the same material capsule</td><td>hover (material lightens), pressed, focus ring if keyboard focus is on</td><td>“Back to live camera”</td></tr>
<tr><td>Missing message</td><td>existing camera message view, <code>exclamationmark.triangle</code> + text + <code>Button</code></td><td>static</td><td>combined element</td></tr>
<tr><td>Can’t play alert</td><td><code>.alert</code> with OK + “Open Voice Memos” (opens via <code>NSWorkspace</code>)</td><td>static</td><td>native</td></tr></table>
<h2>Keyboard, menu bar, motion, contrast</h2>
<p class="note"><b>Keyboard.</b> No shortcuts, matching the shipped app; the floating transport's own play/pause is click-only. <b>Menu bar.</b> The app is <code>LSUIElement</code> with a <code>MenuBarExtra</code> and has no app menus; the status icon does not change during playback (it reports capturing, and playback is not capturing). <b>Reduce Motion.</b> The progress line and scrubber move linearly with time and carry information, so they stay; nothing new animates decoratively. <b>Increase Contrast.</b> The overlay material gains a 1pt white 50% stroke; white on #007AFF is 4.02:1.</p>
<h2>Open: audio pause</h2><p class="note">Audio playback is play/stop only (the simpler choice); pause is not designed. Flagged for the user.</p><h2>Feasibility flags for EM (not designed around)</h2>
<p class="note">1. Reading the newest .m4a from Voice Memos’ group container may trigger the macOS “would like to access data from other apps” prompt or be refused; the alert above covers refusal but not the prompt’s timing. 2. Identifying “the last” audio file: the Start shortcut passes <code>Recording-&lt;timestamp&gt;</code>, but whether Voice Memos’ filename relates to it is unverified. 3. Whether the camera session keeps running under video playback (privacy light stays on) or pauses; pausing reintroduces the start latency on Live Camera.</p>"""
page('index.html', 'Last Recording Playback: Mocks',
     'Draft mocks for playing the last recording inside the panel. Decided: one “play last” control (option B), merged into the timer box, whose glyph says the medium (<code>waveform</code> / <code>play.rectangle.fill</code>); mirror disabled during video playback; video returns to live when it ends; no keyboard shortcuts. '
     'Visual baseline and CSS: projects/master/mocks. Not yet approved.', body)
print('ok')
