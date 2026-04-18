// Plant Detail, Calendar, Export dialog, Customizable Home shell
// All in one file to conserve context.

// ── Plant Detail ──
const PlantDetail = ({ theme, plantId, onBack, onToast, onExport }) => {
  const c = useTheme(theme);
  const plants = {
    bob: { name: 'Monstera "Bob"', latin: 'Monstera deliciosa', loc: 'Living room › South window', acquired: '2024-03-12 · from Mom', tags: ['variegated', 'climber'], thumb: <plantThumbs.monstera size={390} />, overdue: true },
    green: { name: 'Pothos "Green"', latin: 'Epipremnum aureum', loc: 'Kitchen shelf', acquired: '2024-06-01 · bought', tags: ['trailing'], thumb: <plantThumbs.pothos size={390} />, overdue: true },
    snake: { name: 'Snake plant', latin: 'Dracaena trifasciata', loc: 'Bedroom · east window', acquired: '2023-09-20', tags: ['low-light'], thumb: <plantThumbs.snake size={390} /> },
    cala: { name: 'Calathea', latin: 'Goeppertia orbifolia', loc: 'Bookcase', acquired: '2025-01-10', tags: ['humid-loving'], thumb: <plantThumbs.calathea size={390} /> },
    fid: { name: 'Fiddle fig', latin: 'Ficus lyrata', loc: 'Living room', acquired: '2024-05-15', tags: ['tree'], thumb: <plantThumbs.fiddle size={390} /> },
    fern: { name: 'Fern spray', latin: 'Nephrolepis exaltata', loc: 'Bathroom', acquired: '2023-11-02', tags: [], thumb: <plantThumbs.fern size={390} /> },
    suc: { name: 'Hens & chicks', latin: 'Sempervivum', loc: 'South window', acquired: '2023-04-01', tags: ['drought-ok'], thumb: <plantThumbs.succulent size={390} /> },
    pete: { name: 'Prickly Pete', latin: 'Opuntia microdasys', loc: 'Balcony', acquired: '2024-02-14', tags: ['outdoor'], thumb: <plantThumbs.cactus size={390} /> },
  };
  const p = plants[plantId] || plants.bob;
  return (
    <div style={{ height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column', background: c.bg }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '4px 14px 10px' }}>
        <button onClick={onBack} style={{ width: 40, height: 40, borderRadius: 12, background: c.surface, border: `1px solid ${c.border}`, color: c.text, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="m15 18-6-6 6-6" /></svg>
        </button>
        <button style={{ width: 40, height: 40, borderRadius: 12, background: c.surface, border: `1px solid ${c.border}`, color: c.text, fontSize: 22, fontWeight: 700 }}>⋯</button>
      </div>
      <div style={{ flex: 1, overflowY: 'auto' }}>
        <div style={{ height: 300, background: c.surfaceAlt, position: 'relative', overflow: 'hidden' }}>
          {p.thumb}
          <div style={{ position: 'absolute', bottom: 10, left: '50%', transform: 'translateX(-50%)', display: 'flex', gap: 5 }}>
            {[0, 1, 2].map((i) => <div key={i} style={{ width: i === 0 ? 18 : 6, height: 6, borderRadius: 3, background: i === 0 ? 'white' : 'rgba(255,255,255,0.5)' }} />)}
          </div>
        </div>
        <div style={{ padding: '18px 20px 10px' }}>
          <h1 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 24, fontWeight: 800, margin: 0, color: c.text, letterSpacing: '-0.02em' }}>{p.name}</h1>
          <div style={{ fontSize: 13, color: c.muted, fontStyle: 'italic', marginTop: 2 }}>{p.latin}</div>
          <div style={{ fontSize: 12, color: c.muted, marginTop: 10, display: 'flex', alignItems: 'center', gap: 5 }}>
            <Icon name="location" size={12} stroke={2} /> {p.loc}
          </div>
          <div style={{ fontSize: 12, color: c.muted, marginTop: 4 }}>Acquired {p.acquired}</div>
          {p.tags.length > 0 && (
            <div style={{ display: 'flex', gap: 6, marginTop: 10, flexWrap: 'wrap' }}>
              {p.tags.map((t) => <span key={t} style={{ fontSize: 11, fontWeight: 600, padding: '3px 9px', borderRadius: 999, background: c.greenSoft, color: c.green }}>#{t}</span>)}
            </div>
          )}
        </div>
        {/* Upcoming care */}
        <div style={{ padding: '16px 20px 8px' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: c.green, textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 10 }}>Upcoming care</div>
          <div style={{ background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14, overflow: 'hidden' }}>
            {[
              { icon: 'drop', label: 'Water', when: p.overdue ? '2 days overdue' : 'in 2 days', urgent: p.overdue },
              { icon: 'leaf', label: 'Fertilize', when: 'in 18 days' },
            ].map((r, i, arr) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderBottom: i < arr.length - 1 ? `1px solid ${c.border}` : 'none' }}>
                <div style={{ width: 36, height: 36, borderRadius: 10, background: r.urgent ? c.terraSoft : c.greenSoft, color: r.urgent ? c.terra : c.green, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={r.icon} size={16} stroke={2.2} /></div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 14, fontWeight: 600, color: c.text }}>{r.label}</div>
                  <div style={{ fontSize: 11.5, color: r.urgent ? c.terra : c.muted, fontWeight: r.urgent ? 600 : 500 }}>{r.when}</div>
                </div>
                <button onClick={() => onToast?.(`${r.label} logged`)} style={{ fontSize: 11, fontWeight: 700, padding: '6px 12px', borderRadius: 8, background: c.green, color: 'white', border: 'none', cursor: 'pointer', fontFamily: 'inherit' }}>Done</button>
                <button onClick={() => onToast?.('Snoozed 3 days')} style={{ fontSize: 11, fontWeight: 600, padding: '6px 10px', borderRadius: 8, background: c.surfaceAlt, border: `1px solid ${c.border}`, color: c.muted, cursor: 'pointer', fontFamily: 'inherit' }}>Snooze</button>
              </div>
            ))}
          </div>
        </div>
        {/* Timeline */}
        <div style={{ padding: '16px 20px 8px' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: c.green, textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 10 }}>Timeline</div>
          <div style={{ background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14, padding: '4px 14px' }}>
            {[
              { when: 'Apr 15', icon: 'drop', text: 'Watered' },
              { when: 'Apr 10', icon: 'sun', text: 'Photo added' },
              { when: 'Apr 08', icon: 'leaf', text: 'Fertilized (NPK 10-10-10, ¼ tsp)' },
              { when: 'Mar 20', icon: 'repot', text: 'Repotted → 20cm terracotta' },
            ].map((r, i, arr) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '10px 0', borderBottom: i < arr.length - 1 ? `1px solid ${c.border}` : 'none' }}>
                <div style={{ width: 30, height: 30, borderRadius: 999, background: c.greenSoft, color: c.green, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={r.icon} size={14} stroke={2.2} /></div>
                <div style={{ flex: 1, fontSize: 13, color: c.text }}>{r.text}</div>
                <div style={{ fontSize: 11, color: c.muted, fontWeight: 500 }}>{r.when}</div>
              </div>
            ))}
          </div>
          <div style={{ fontSize: 11.5, color: c.muted, textAlign: 'center', marginTop: 10 }}>View all 42 events</div>
        </div>
        {/* Export CTA */}
        <div style={{ padding: '20px 20px 32px' }}>
          <button onClick={onExport} style={{
            width: '100%', padding: 14, borderRadius: 14,
            background: c.surface, border: `2px dashed ${c.terra}`, color: c.terra,
            fontSize: 14, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, cursor: 'pointer', fontFamily: 'inherit',
          }}>
            <Icon name="door" size={16} stroke={2.2} /> Post on plantly.ro
          </button>
        </div>
      </div>
    </div>
  );
};

// ── Calendar week view ──
const CalendarScreen = ({ theme, onPlantClick, onBack }) => {
  const c = useTheme(theme);
  const days = [
    { d: 'Mon', n: '14', events: [{ p: 'Bob', icon: 'drop', tone: c.green }, { p: 'Ivy', icon: 'leaf', tone: c.green }] },
    { d: 'Tue', n: '15', events: [{ p: 'Fern', icon: 'drop', tone: c.green }, { p: 'Oak', icon: 'drop', tone: c.green }] },
    { d: 'Wed', n: '16', events: [] },
    { d: 'Thu', n: '17', events: [{ p: 'Bob', icon: 'drop', tone: c.green }, { p: 'Rose', icon: 'repot', tone: c.green }] },
    { d: 'Fri', n: '18', today: true, events: [{ p: 'Monty', icon: 'drop', tone: c.green }] },
    { d: 'Sat', n: '19', events: [{ p: 'Ivy', icon: 'drop', tone: c.terra, skip: true }, { p: 'Oak', icon: 'leaf', tone: c.green }] },
    { d: 'Sun', n: '20', events: [{ p: 'Fern', icon: 'drop', tone: c.green }] },
  ];
  return (
    <div style={{ height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column', background: c.bg }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 14px 14px' }}>
        <button onClick={onBack} style={{ width: 40, height: 40, borderRadius: 12, background: c.surface, border: `1px solid ${c.border}`, color: c.text, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="m15 18-6-6 6-6" /></svg>
        </button>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 11, color: c.muted, fontWeight: 500, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Apr 14 – 20</div>
          <h1 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 22, fontWeight: 800, margin: 0, color: c.text, letterSpacing: '-0.02em' }}>This week</h1>
        </div>
        <button style={{ padding: '8px 12px', borderRadius: 10, background: c.surface, border: `1px solid ${c.border}`, color: c.text, fontSize: 12, fontWeight: 600, fontFamily: 'inherit' }}>Week ▾</button>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 20px 24px' }}>
        {/* Weather suggestion */}
        <div style={{
          background: `linear-gradient(135deg, ${c.greenDeep}, ${c.green})`, color: 'white',
          borderRadius: 14, padding: 14, display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16,
        }}>
          <div style={{ width: 38, height: 38, borderRadius: 10, background: 'rgba(255,255,255,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="drop" size={18} stroke={2.2} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 11, opacity: 0.85, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Sat · Rain expected</div>
            <div style={{ fontSize: 13, fontWeight: 500, marginTop: 2 }}>Skip outdoor watering — we'll reschedule.</div>
          </div>
          <button style={{ fontSize: 11, fontWeight: 700, padding: '6px 10px', borderRadius: 8, background: 'rgba(255,255,255,0.22)', border: 'none', color: 'white', fontFamily: 'inherit', cursor: 'pointer' }}>Apply</button>
        </div>
        {/* Days */}
        <div style={{ background: c.surface, border: `1px solid ${c.border}`, borderRadius: 16, overflow: 'hidden' }}>
          {days.map((day, i) => (
            <div key={day.d} style={{ display: 'grid', gridTemplateColumns: '56px 1fr', gap: 12, padding: '14px 14px', borderBottom: i < days.length - 1 ? `1px solid ${c.border}` : 'none', background: day.today ? c.greenSoft : 'transparent' }}>
              <div>
                <div style={{ fontSize: 11, fontWeight: 700, color: day.today ? c.green : c.muted, textTransform: 'uppercase', letterSpacing: '0.1em' }}>{day.d}</div>
                <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 22, fontWeight: 800, color: day.today ? c.green : c.text, letterSpacing: '-0.02em', lineHeight: 1 }}>{day.n}</div>
                {day.today && <div style={{ fontSize: 10, fontWeight: 700, color: c.green, marginTop: 2 }}>TODAY</div>}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 5, justifyContent: 'center' }}>
                {day.events.length === 0 && <div style={{ fontSize: 12, color: c.muted, fontStyle: 'italic' }}>Clear</div>}
                {day.events.map((e, j) => (
                  <div key={j} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', borderRadius: 10, background: e.skip ? c.terraSoft : c.surfaceAlt, border: `1px solid ${c.border}` }}>
                    <div style={{ color: e.tone, display: 'flex' }}><Icon name={e.icon} size={13} stroke={2.2} /></div>
                    <div style={{ fontSize: 12.5, fontWeight: 600, color: c.text, flex: 1, textDecoration: e.skip ? 'line-through' : 'none', opacity: e.skip ? 0.6 : 1 }}>{e.p}</div>
                    {e.skip && <div style={{ fontSize: 10, fontWeight: 700, color: c.terra, textTransform: 'uppercase', letterSpacing: '0.06em' }}>Skip</div>}
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// ── Export dialog (plantly.ro post) ──
const ExportDialog = ({ theme, onClose, onToast }) => {
  const c = useTheme(theme);
  const [title, setTitle] = React.useState('Monstera deliciosa variegata');
  const [desc, setDesc] = React.useState('Mature Monstera, 5 leaves, propagated from my mother plant in 2024. Healthy and ready to re-home.');
  const [price, setPrice] = React.useState('250');
  const [photos, setPhotos] = React.useState([true, true, true, false, false]);
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.55)', zIndex: 10, display: 'flex', alignItems: 'flex-end' }}>
      <div style={{ width: '100%', background: c.bg, borderRadius: '24px 24px 0 0', maxHeight: '92%', display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '10px 0', display: 'flex', justifyContent: 'center' }}>
          <div style={{ width: 40, height: 4, borderRadius: 2, background: c.border }} />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 20px 12px' }}>
          <div>
            <div style={{ fontSize: 11, fontWeight: 700, color: c.terra, textTransform: 'uppercase', letterSpacing: '0.1em' }}>🌿 plantly.ro</div>
            <h2 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 19, fontWeight: 800, margin: 0, color: c.text, letterSpacing: '-0.02em' }}>Post "Monstera Bob"</h2>
          </div>
          <button onClick={onClose} style={{ width: 32, height: 32, borderRadius: 999, background: c.surface, border: `1px solid ${c.border}`, color: c.text, fontSize: 16, cursor: 'pointer' }}>✕</button>
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: '0 20px 20px' }}>
          {/* Title */}
          <label style={{ fontSize: 11, fontWeight: 700, color: c.muted, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Title</label>
          <input value={title} onChange={(e) => setTitle(e.target.value)} style={{ width: '100%', marginTop: 6, padding: '10px 12px', borderRadius: 10, border: `1px solid ${c.border}`, background: c.surface, color: c.text, fontSize: 14, fontFamily: 'inherit', outline: 'none', boxSizing: 'border-box' }} />
          <div style={{ fontSize: 10.5, color: c.muted, textAlign: 'right', marginTop: 4 }}>{title.length}/64</div>
          {/* Description */}
          <label style={{ fontSize: 11, fontWeight: 700, color: c.muted, textTransform: 'uppercase', letterSpacing: '0.08em', display: 'block', marginTop: 10 }}>Description</label>
          <textarea value={desc} onChange={(e) => setDesc(e.target.value)} rows={3} style={{ width: '100%', marginTop: 6, padding: '10px 12px', borderRadius: 10, border: `1px solid ${c.border}`, background: c.surface, color: c.text, fontSize: 13, fontFamily: 'inherit', outline: 'none', resize: 'none', lineHeight: 1.5, boxSizing: 'border-box' }} />
          <div style={{ fontSize: 10.5, color: c.muted, textAlign: 'right', marginTop: 4 }}>{desc.length}/2000</div>
          {/* Price */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 10 }}>
            <div>
              <label style={{ fontSize: 11, fontWeight: 700, color: c.muted, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Price</label>
              <div style={{ position: 'relative', marginTop: 6 }}>
                <input value={price} onChange={(e) => setPrice(e.target.value)} style={{ width: '100%', padding: '10px 40px 10px 12px', borderRadius: 10, border: `1px solid ${c.border}`, background: c.surface, color: c.text, fontSize: 14, fontFamily: 'inherit', outline: 'none', boxSizing: 'border-box' }} />
                <span style={{ position: 'absolute', right: 12, top: 10, color: c.muted, fontSize: 13, fontWeight: 600 }}>lei</span>
              </div>
            </div>
            <div>
              <label style={{ fontSize: 11, fontWeight: 700, color: c.muted, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Category</label>
              <div style={{ marginTop: 6, padding: '10px 12px', borderRadius: 10, border: `1px solid ${c.border}`, background: c.surface, color: c.text, fontSize: 13, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span>Indoor › Monsteras</span>
                <Icon name="chevronDown" size={14} style={{ color: c.muted }} />
              </div>
            </div>
          </div>
          {/* Location */}
          <label style={{ fontSize: 11, fontWeight: 700, color: c.muted, textTransform: 'uppercase', letterSpacing: '0.08em', display: 'block', marginTop: 10 }}>Location</label>
          <div style={{ marginTop: 6, padding: '10px 12px', borderRadius: 10, border: `1px solid ${c.border}`, background: c.surface, color: c.text, fontSize: 13, display: 'flex', alignItems: 'center', gap: 6 }}>
            <Icon name="location" size={13} stroke={2} style={{ color: c.muted }} />
            <span>Timiș County · Timișoara</span>
          </div>
          {/* Photos */}
          <label style={{ fontSize: 11, fontWeight: 700, color: c.muted, textTransform: 'uppercase', letterSpacing: '0.08em', display: 'block', marginTop: 14 }}>Photos ({photos.filter(Boolean).length}/6)</label>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 6, marginTop: 8 }}>
            {photos.map((on, i) => (
              <div key={i} onClick={() => setPhotos(photos.map((p, j) => j === i ? !p : p))} style={{
                aspectRatio: '1', borderRadius: 10, overflow: 'hidden', position: 'relative', cursor: 'pointer',
                border: on ? `2px solid ${c.green}` : `2px solid ${c.border}`, opacity: on ? 1 : 0.45,
              }}>
                <plantThumbs.monstera size={80} />
                {on && <div style={{ position: 'absolute', top: 3, right: 3, width: 18, height: 18, borderRadius: 999, background: c.green, color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="check" size={11} stroke={3} /></div>}
              </div>
            ))}
          </div>
        </div>
        <div style={{ padding: '12px 20px 14px', borderTop: `1px solid ${c.border}`, background: c.surface, display: 'flex', gap: 10, flexShrink: 0 }}>
          <button onClick={() => { onToast?.('Draft saved'); onClose(); }} style={{ flex: 1, padding: 12, borderRadius: 12, background: c.surfaceAlt, border: `1px solid ${c.border}`, color: c.text, fontSize: 13, fontWeight: 600, fontFamily: 'inherit', cursor: 'pointer' }}>Save draft</button>
          <button onClick={() => { onToast?.('Posted to plantly.ro ✓'); onClose(); }} style={{ flex: 1.4, padding: 12, borderRadius: 12, background: c.terra, border: 'none', color: 'white', fontSize: 13, fontWeight: 700, fontFamily: 'inherit', cursor: 'pointer' }}>Post now</button>
        </div>
      </div>
    </div>
  );
};

// ── Customizable Home ──
const CustomHome = ({ theme, layout, setLayout, editing, setEditing, onPlantClick, onToast, onNav }) => {
  const c = useTheme(theme);
  const move = (idx, dir) => {
    const next = [...layout];
    const j = idx + dir;
    if (j < 0 || j >= next.length) return;
    [next[idx], next[j]] = [next[j], next[idx]];
    setLayout(next);
  };
  const remove = (idx) => setLayout(layout.filter((_, i) => i !== idx));

  return (
    <div style={{ height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column', background: c.bg }}>
      {/* Edit mode toggle */}
      <div style={{ display: 'flex', justifyContent: 'flex-end', padding: '4px 16px 6px' }}>
        <button onClick={() => setEditing(!editing)} style={{
          padding: '6px 12px', borderRadius: 999, fontSize: 11, fontWeight: 700,
          background: editing ? c.green : c.surface, color: editing ? 'white' : c.muted,
          border: `1px solid ${editing ? c.green : c.border}`, cursor: 'pointer', fontFamily: 'inherit',
          display: 'inline-flex', alignItems: 'center', gap: 5,
        }}>
          {editing ? <>✓ Done</> : <>✎ Customize home</>}
        </button>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', paddingTop: 6 }}>
        {layout.map((wid, i) => {
          const W = widgetRegistry[wid];
          if (!W) return null;
          return (
            <W.render key={i + wid} theme={theme} editing={editing} widgetProps={{ onRemove: () => remove(i), onMoveUp: () => move(i, -1), onMoveDown: () => move(i, 1) }} onPlantClick={onPlantClick} onToast={onToast} />
          );
        })}
        {editing && (
          <div style={{ padding: '0 20px 20px' }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: c.green, textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 8 }}>Add widget</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              {Object.entries(widgetRegistry).filter(([k]) => !layout.includes(k)).map(([k, w]) => (
                <button key={k} onClick={() => setLayout([...layout, k])} style={{
                  padding: '10px 12px', borderRadius: 12, background: c.surface, border: `1px dashed ${c.border}`, color: c.text,
                  fontSize: 12, fontWeight: 600, fontFamily: 'inherit', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8, textAlign: 'left',
                }}>
                  <div style={{ color: c.green, display: 'flex' }}><Icon name={w.icon} size={14} stroke={2.2} /></div>
                  <span style={{ flex: 1 }}>{w.label}</span>
                  <span style={{ color: c.green, fontSize: 16, fontWeight: 800 }}>+</span>
                </button>
              ))}
            </div>
            <div style={{ fontSize: 11, fontWeight: 700, color: c.muted, textTransform: 'uppercase', letterSpacing: '0.1em', marginTop: 16, marginBottom: 8 }}>Or start from a preset</div>
            <div style={{ display: 'flex', gap: 6, overflowX: 'auto' }}>
              {[
                { name: 'Grouped', keys: ['greeting', 'overdue', 'today', 'grid'] },
                { name: 'Dashboard', keys: ['greeting', 'stats', 'weather', 'today', 'activity'] },
                { name: 'Feed', keys: ['greeting', 'overdue', 'today', 'activity'] },
                { name: 'Minimal', keys: ['greeting', 'quicklog', 'today'] },
              ].map((p) => (
                <button key={p.name} onClick={() => setLayout(p.keys)} style={{
                  padding: '7px 12px', borderRadius: 999, background: c.surface, border: `1px solid ${c.border}`, color: c.text,
                  fontSize: 11.5, fontWeight: 600, fontFamily: 'inherit', cursor: 'pointer', whiteSpace: 'nowrap',
                }}>{p.name}</button>
              ))}
            </div>
          </div>
        )}
      </div>
      {/* Tab bar */}
      <div style={{ borderTop: `1px solid ${c.border}`, background: c.surface, display: 'flex', padding: '8px 0 10px', position: 'relative', flexShrink: 0 }}>
        {[
          { name: 'home', label: 'Home', active: true },
          { name: 'calendar', label: 'Calendar', go: 'calendar' },
          { name: 'location', label: 'Spaces' },
          { name: 'user', label: 'Me' },
        ].map((t, i) => (
          <div key={i} onClick={() => t.go && onNav?.(t.go)} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, color: t.active ? c.green : c.muted, cursor: t.go ? 'pointer' : 'default' }}>
            <Icon name={t.name} size={22} stroke={t.active ? 2.2 : 1.8} />
            <div style={{ fontSize: 10, fontWeight: t.active ? 600 : 500 }}>{t.label}</div>
          </div>
        ))}
        <button style={{
          position: 'absolute', right: 20, bottom: 68,
          width: 56, height: 56, borderRadius: 18, background: c.green, color: 'white', border: 'none',
          boxShadow: '0 8px 20px -4px rgba(61, 122, 95, 0.5)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }}><Icon name="plus" size={24} stroke={2.5} /></button>
      </div>
    </div>
  );
};

Object.assign(window, { PlantDetail, CalendarScreen, ExportDialog, CustomHome });
