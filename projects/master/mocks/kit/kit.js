// MacRecordWidget mock kit: the current panel, drawn from the app's own numbers.
// Every mock loads this and builds only the part under review on top of it.
// Numbers mirror PanelScale (MacRecordWidget/PanelSizer.swift); glyphs are real
// SF Symbols exported by export-symbols.swift. Update both in the same commit
// as any change to the row. Ground truth: reference/*.png (2026-10-23).
(function () {
  const base = document.currentScript.src.replace(/kit\.js.*$/, '');
  const css = document.createElement('link');
  css.rel = 'stylesheet'; css.href = base + 'kit.css';
  document.head.appendChild(css);

  // PanelScale. extraLarge and full share large's row; only the preview grows.
  const S = {
    small:  { w: 400, h: 17, glyph: 14, font: 11, text: 10, gap: 8,  padH: 10, padT: 6, padB: 6, r: 4, timerPad: 5, well: 11, chevron: 7, picker: 110 },
    medium: { w: 480, h: 20, glyph: 16, font: 13, text: 12, gap: 14, padH: 12, padT: 8, padB: 8, r: 5, timerPad: 6, well: 13, chevron: 8, picker: 200 },
    large:  { w: 962, h: 22, glyph: 17, font: 14, text: 13, gap: 18, padH: 16, padT: 7, padB: 6, r: 6, timerPad: 8, well: 14, chevron: 9, picker: 260 },
  };
  S.extraLarge = { ...S.large, w: 1443 }; S.full = { ...S.large, w: 1924 };

  const RED = '#FF383C', BLUE = '#007AFF';
  const symbol = (name, px, color) =>
    `<i class="mrw-sym" style="width:${px}px;height:${px}px;background:${color};` +
    `-webkit-mask-image:url('${base}symbols/${name}.png');mask-image:url('${base}symbols/${name}.png')"></i>`;

  // One capsule control. on: fully round, filled with tint, white glyph, no outline.
  // off: scale corner radius, 1pt separator outline, control background, dark glyph.
  function control(s, o) {
    const on = !!o.on, tint = o.tint || BLUE;
    const style = `height:${s.h}px;padding:0 4px;border-radius:${on ? s.h / 2 : s.r}px;` +
      (on ? `background:${tint};border-color:transparent;` : '');
    const glyph = o.html || symbol(o.icon, s.glyph, on ? '#fff' : 'var(--mrw-glyph)');
    return `<span class="mrw-ctl${on ? ' on' : ''}${o.disabled ? ' disabled' : ''}" title="${o.title || ''}" style="${style}">` +
      `<span style="width:${s.glyph}px;height:${s.glyph}px;display:inline-flex;align-items:center;justify-content:center">${glyph}</span>${o.dot ? '<b class="mrw-dot"></b>' : ''}</span>`;
  }

  function row(opts = {}) {
    const s = S[opts.scale || 'medium'], st = Object.assign({
      pinned: true, mirrored: true, recording: null, playing: false, time: '00:00',
      last: 'audio', camera: 'FaceTime HD Camera', scale: opts.scale || 'medium',
    }, opts.state || {});
    const busy = !!st.recording;
    const lastIcon = st.last === 'video' ? 'play.rectangle.fill' : st.last === 'audio' ? 'waveform' : 'play.fill';
    const timer = `<span class="mrw-ctl mrw-timer${st.playing ? ' on' : ''}" style="height:${s.h}px;padding:0 ${s.timerPad}px;` +
      `border-radius:${st.playing ? s.h / 2 : s.r}px;gap:4px;font-size:${s.text}px;${st.playing ? `background:${BLUE};` : ''}">` +
      symbol(lastIcon, s.glyph - 2, st.playing ? '#fff' : (busy || !st.last ? 'var(--mrw-glyph-dim)' : 'var(--mrw-glyph)')) +
      `<span class="mrw-digits" style="${busy || st.playing ? 'opacity:1;' : ''}${st.playing ? 'color:#fff' : ''}">${st.time}</span></span>`;
    const order = ['small', 'medium', 'large', 'extraLarge', 'full'], i = order.indexOf(st.scale);
    const cam = `<span class="mrw-ctl mrw-cam" style="height:${s.h}px;border-radius:${s.r}px;max-width:${s.picker}px;font-size:${s.text}px">` +
      `<span class="mrw-cam-name">${st.camera}</span><span class="mrw-well" style="width:${s.well}px;border-radius:${s.r - 1}px">` +
      symbol('chevron.down', s.chevron + 2, '#fff') + `</span></span>`;
    const c = (o) => control(s, o);
    return `<div class="mrw-row" style="gap:${s.gap}px;padding:${s.padT}px ${s.padH}px ${s.padB}px">` +
      c({ icon: st.pinned ? 'pin.fill' : 'pin.slash', on: st.pinned, title: 'Keep panel open' }) +
      `<span class="mrw-grp" style="gap:${s.gap / 2}px">` +
        c({ icon: 'mic.fill', on: st.recording === 'audio', tint: RED, dot: st.recording === 'audio', disabled: st.recording === 'video' }) +
        timer +
        c({ icon: 'video.fill', on: st.recording === 'video', tint: RED, disabled: st.recording === 'audio' }) +
      `</span>` +
      c({ icon: 'arrow.left.and.right.righttriangle.left.righttriangle.right', on: st.mirrored }) +
      `<span class="mrw-spacer"></span>` + cam + (opts.afterCamera || '') +
      `<span class="mrw-grp" style="gap:2px">` +
        c({ icon: 'minus.magnifyingglass', disabled: i <= 0, title: 'Zoom Out' }) +
        c({ icon: 'plus.magnifyingglass', disabled: i >= order.length - 1, title: 'Zoom In' }) +
      `</span>` + c({ icon: 'power', on: true, title: 'Quit' }) + `</div>`;
  }

  // The whole panel: row over a 16:9 preview running flush to the panel edges.
  function panel(opts = {}) {
    const s = S[opts.scale || 'medium'], w = opts.width || s.w;
    const prev = opts.preview != null ? opts.preview : '<div class="mrw-scene"></div>';
    return `<div class="mrw-panel" style="width:${w}px">${row(opts)}` +
      `<div class="mrw-preview" style="height:${Math.round(w * 9 / 16)}px">${prev}${opts.overlay || ''}</div></div>`;
  }

  window.MRW = { scales: S, RED, BLUE, symbol, control: (scale, o) => control(S[scale], o), row, panel };
})();
