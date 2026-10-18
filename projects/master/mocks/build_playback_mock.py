import os
SRC=os.path.join(os.path.dirname(os.path.abspath(__file__)),'../../20261015-last-recording-playback/generated-docs/design/build_mocks.py')
code=open(SRC).read().split('# ---------- row-options.html ----------')[0]
ns={'__file__':SRC}; exec(code, ns)
svg,G,SC,ctl,panel,pair,stack=ns['svg'],ns['G'],ns['SC'],ns['ctl'],ns['panel'],ns['pair'],ns['stack']
G['trash']='<path d="M4 6.5h16M9.5 6.5V4.3c0-.7.5-1.3 1.2-1.3h2.6c.7 0 1.2.6 1.2 1.3v2.2" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><path d="M6 6.5l1 13.2c.1 1 .9 1.8 1.9 1.8h6.2c1 0 1.8-.8 1.9-1.8L18 6.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M10 10.5v7M14 10.5v7" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>'
orig=ns['tbtn']
TR={'on':False}
def tbtn2(s,t,st='idle',prog=None,med='audio',cue='swap'):
    out=orig(s,t,st,prog,med,cue)
    if TR['on']: out+=ctl(s,'trash','Move the last recording to the Trash','dis' if st in ('rec','none','on') else 'off')
    return out
ns['tbtn']=tbtn2
BASE=dict(t='00:06',med='audio')
def alert(theme, name, kind):
    bg,fg,sub,btn=('#ececec','#1d1d1f','#555','#fff') if theme=='light' else ('#2c2c2e','#f5f5f7','#aaa','#48484a')
    return (f'<div style="width:260px;margin:14px auto 0;background:{bg};color:{fg};border-radius:12px;padding:18px 16px 14px;text-align:center;box-shadow:0 12px 40px rgba(0,0,0,.35);font-size:12px">'
            f'<div style="font-weight:600;font-size:13px;margin-bottom:6px">Move the last recording to the Trash?</div>'
            f'<div style="color:{sub};margin-bottom:12px">{name} will be moved to the Trash. {kind}</div>'
            f'<div style="background:{btn};color:#FF383C;border-radius:6px;padding:4px;margin-bottom:6px">Move to Trash</div>'
            f'<div style="background:{btn};border-radius:6px;padding:4px">Cancel</div></div>')
AUD=('“Recording-20261018-0941.m4a” (00:06)','It will disappear from Voice Memos.')
VID=('“Photo Booth 10-18-26 at 9.41 AM.mov” (01:36)','It will disappear from Photo Booth.')
def audio_playing(s,theme,extra=''):
    p=panel(s,'B',dict(BASE,pb='on',t='00:03',tprog=50),'live',theme)
    tr=(f'<span class="ov transport"><span>00:03</span><span class="bar" role="slider" aria-label="Playback position"><i style="width:50%"></i><b style="left:50%"></b></span>'
        f'<span style="opacity:.75">00:06</span>{extra}</span>')
    return p[:p.rindex('</div></div></div>')]+tr+'</div></div></div>'
def write(name,title,lede,body):
    html=ns['HEAD'].replace('<title>Panel, Idle</title>',f'<title>{title}</title>')+ns['EXTRA']+f'</head><body><main><h1>{title}</h1><p class="lede">{lede}</p>{body}</main></body></html>'
    open(f'/tmp/delmock/{name}','w').write(html)


def mirrored(h):
    return (h.replace('<div class="scene"><span class="who"','<div class="scene mirrored"><span class="who"')
             .replace('&nbsp;·&nbsp;as others see it','&nbsp;·&nbsp;mirrored')
             .replace('shown as others see it','mirrored'))
tg=lambda: f'<span role="button" aria-label="Move this recording to the Trash" style="display:inline-flex;padding-left:9px;border-left:1px solid rgba(255,255,255,.3)">{svg(G["trash"],14)}</span>'
def vid_playing(t,s='L'):
    p=panel(s,'B',dict(BASE,pb='on',t='00:42',tprog=44,med='video'),'playing',t,el='00:42',du='01:36',pct=44)
    return mirrored(p.replace('01:36</span></span></div>','01:36</span>'+tg()+'</span></div>'))
def menu2(t, prev=True, nxt=False):
    bg,fg=('#f6f6f6','#1d1d1f') if t=='light' else ('#323234','#f5f5f7')
    items=[('Play Last Recording',1),None,('Previous Recording',prev),('Next Recording',nxt),None,('Move to Trash…',1)]
    h=''.join('<div style="border-top:1px solid rgba(128,128,128,.3);margin:4px 0"></div>' if i is None else
              f'<div style="padding:3px 12px;border-radius:4px;{"opacity:.35;" if not i[1] else ""}{"background:#007AFF;color:#fff" if i[0].startswith("Previous") else ""}">{i[0]}</div>' for i in items)
    return f'<div style="position:absolute;left:96px;top:30px;width:200px;background:{bg};color:{fg};border-radius:8px;padding:5px;box-shadow:0 8px 24px rgba(0,0,0,.3);font-size:13px;z-index:5">{h}</div>'
def withmenu2(t, st, **k):
    p=panel('L','B',st,'live',t)
    i=p.index('<div class="panel"')
    return p[:i]+'<div style="position:relative">'+menu2(t,**k)+p[i:-6]+'</div></div>'
b=pair('Idle: the timer box is the play button',lambda t: panel('L','B',dict(BASE),'live',t),
  'Glyph names the medium (waveform for audio, play.rectangle.fill for video); the digits are the recording length. Click to play, click again to stop.')
b+=pair('Audio playing: scrubber over the live camera',lambda t: audio_playing('L',t,tg()),
  'No pause button: audio is play/stop only. Drag to seek. The trash at the end moves this recording to the Trash after a confirmation.')
b+=pair('Video playing: mirrored by default',lambda t: vid_playing(t),
  'Playback follows the mirror toggle, which stays enabled. The badge reads “mirrored” or “as others see it”. The file itself is never mirrored.')
def overlay_alert(t):
    p=panel('L','B',dict(BASE,med='video',t='01:36'),'live',t)
    i=p.index('<div class="panel"')
    card=('<div style="position:absolute;left:0;right:0;top:34px;bottom:0;background:rgba(0,0,0,.35);border-radius:0 0 10px 10px;display:flex;align-items:center;justify-content:center;z-index:5">'
          '<div style="width:300px;background:rgba(40,40,40,.85);backdrop-filter:blur(12px);color:#fff;border-radius:12px;padding:14px;text-align:center;font-size:11px">'
          '<div style="font-weight:600;font-size:13px;margin-bottom:6px">Move the Last Recording to the Trash?</div>'
          f'<div style="opacity:.8;margin-bottom:10px">{VID[0]} will be moved to the Trash. It came from Photo Booth.</div>'
          '<span style="display:inline-block;padding:3px 12px;border-radius:6px;background:rgba(255,255,255,.18);margin-right:8px">Cancel</span>'
          '<span style="display:inline-block;padding:3px 12px;border-radius:6px;background:rgba(255,255,255,.18);color:#FF6B6E">Move to Trash</span></div></div>')
    return p[:i]+'<div style="position:relative">'+card+p[i:-6]+'</div></div>'
b+=pair('Trash clicked: confirmation inside the panel (playback stops first)',overlay_alert,
  'Drawn over the preview, not as a separate alert window, so a pinned panel stays open. Clicking outside the card cancels.')
b+=pair('Right-click the timer box (newest recording)',lambda t: withmenu2(t,dict(BASE)),
  'Previous / Next walk every Photo Booth movie and Voice Memos memo by creation date. Next is disabled on the newest. All items are disabled while playing.')
b+=pair('After Previous: an older video',lambda t: panel('L','B',dict(BASE,t='01:36',med='video'),'live',t),
  'Glyph and length follow the selected recording.')
b+=pair('Previous again: both directions available',lambda t: withmenu2(t,dict(BASE,t='00:42'),nxt=True))
html=ns['HEAD'].replace('<title>Panel, Idle</title>','<title>Playback</title>')+ns['EXTRA']+('</head><body><main><nav class="crumbs"><a href="index.html">All mocks</a></nav><h1>Playback</h1>'
 '<p class="lede">Play, seek, browse and delete the last recording. When the shown recording is deleted elsewhere, the box falls back to the newest one left, or disables if none remain.</p>'
 +b+'<p class="note" style="margin-top:40px">Master baseline, added 2026-10-18 from the shipped build. Generated by build_playback_mock.py. Glyphs are SVG stand-ins for the named SF Symbols.</p></main></body></html>')
open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'playback.html'),'w').write(html)
