// Widgets library — each is a self-contained block users can add to their home
// All accept `theme` + `onPlantClick` callback

const widgetRegistry = {};

// ─── Shared helpers ───
const useTheme = (theme) => {
  const dark = theme === 'dark';
  return {
    dark,
    bg: dark ? '#0a0a0a' : '#f7f6f2',
    surface: dark ? '#18181b' : '#ffffff',
    surfaceAlt: dark ? '#09090b' : '#fafaf7',
    text: dark ? '#fafafa' : '#18181b',
    muted: dark ? '#a1a1aa' : '#52525b',
    border: dark ? '#27272a' : '#e4e4e7',
    green: dark ? '#5aac83' : '#3D7A5F',
    greenDeep: dark ? '#86bb9d' : '#264e3b',
    greenSoft: dark ? 'rgba(90,172,131,0.15)' : '#f0f7f3',
    terra: dark ? '#e58255' : '#C26A3A',
    terraSoft: dark ? 'rgba(229,130,85,0.15)' : '#fbe8d7',
  };
};

// Widget shell with header
const WidgetShell = ({ title, accent, action, editing, onRemove, onMoveUp, onMoveDown, children, c, inset = true }) => (
  <div style={{ padding: inset ? '0 20px' : 0, marginBottom: 16, position: 'relative' }}>
    {title && (
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10, padding: inset ? 0 : '0 20px' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
          <h2 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 16, fontWeight: 700, margin: 0, color: c.text, letterSpacing: '-0.01em' }}>{title}</h2>
          {accent != null && <span style={{ fontSize: 13, fontWeight: 600, color: accent.color }}>{accent.label}</span>}
        </div>
        {action && !editing && <div style={{ fontSize: 11, color: c.green, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em' }}>{action}</div>}
      </div>
    )}
    {editing && (
      <div style={{
        position: 'absolute', top: -6, right: 20, display: 'flex', gap: 4,
        background: c.surface, border: `1px solid ${c.border}`, borderRadius: 8, padding: 3,
        boxShadow: '0 4px 12px rgba(0,0,0,0.12)', zIndex: 3,
      }}>
        <button onClick={onMoveUp} style={{ border: 'none', background: 'transparent', color: c.muted, padding: 4, cursor: 'pointer', display: 'flex' }} title="Move up">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="m18 15-6-6-6 6" /></svg>
        </button>
        <button onClick={onMoveDown} style={{ border: 'none', background: 'transparent', color: c.muted, padding: 4, cursor: 'pointer', display: 'flex' }} title="Move down">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="m6 9 6 6 6-6" /></svg>
        </button>
        <div style={{ width: 1, background: c.border, margin: '2px 2px' }} />
        <button onClick={onRemove} style={{ border: 'none', background: 'transparent', color: c.terra, padding: 4, cursor: 'pointer', display: 'flex', fontSize: 11, fontWeight: 600, fontFamily: 'inherit' }}>Remove</button>
      </div>
    )}
    {children}
  </div>
);

// ─── Widget: Greeting ───
widgetRegistry.greeting = {
  label: 'Greeting', icon: 'user',
  render: ({ theme, editing, widgetProps }) => {
    const c = useTheme(theme);
    return (
      <WidgetShell c={c} editing={editing} {...widgetProps}>
        <div style={{ padding: '0 20px 12px', display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 999, background: c.greenSoft, color: c.green, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: "'Plus Jakarta Sans', sans-serif", fontWeight: 700, fontSize: 17 }}>AM</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12, color: c.muted, fontWeight: 500 }}>Friday · April 18</div>
            <h1 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 24, fontWeight: 800, margin: 0, color: c.text, letterSpacing: '-0.02em' }}>Good morning, Ana</h1>
          </div>
          <button style={{ width: 40, height: 40, borderRadius: 12, background: c.surface, border: `1px solid ${c.border}`, color: c.text, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
            <Icon name="bell" size={18} />
            <span style={{ position: 'absolute', top: 6, right: 7, width: 8, height: 8, borderRadius: 999, background: c.terra, border: `2px solid ${c.surface}` }} />
          </button>
        </div>
      </WidgetShell>
    );
  },
};

// ─── Widget: Stats row ───
widgetRegistry.stats = {
  label: 'Stats row', icon: 'leaf',
  render: ({ theme, editing, widgetProps }) => {
    const c = useTheme(theme);
    const stats = [
      { value: '2', label: 'Overdue', color: c.terra, soft: c.terraSoft, icon: 'drop' },
      { value: '3', label: 'Due today', color: c.green, soft: c.greenSoft, icon: 'check' },
      { value: '24', label: 'Plants', color: c.muted, soft: c.surfaceAlt, icon: 'leaf' },
      { value: '6', label: 'Spaces', color: c.muted, soft: c.surfaceAlt, icon: 'location' },
    ];
    return (
      <WidgetShell c={c} editing={editing} {...widgetProps}>
        <div style={{ padding: '0 20px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {stats.map((s, i) => (
            <div key={i} style={{ background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14, padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ width: 30, height: 30, borderRadius: 9, background: s.soft, color: s.color, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name={s.icon} size={15} stroke={2.2} />
              </div>
              <div>
                <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 24, fontWeight: 800, color: c.text, letterSpacing: '-0.02em', lineHeight: 1 }}>{s.value}</div>
                <div style={{ fontSize: 11, color: c.muted, marginTop: 3, fontWeight: 500 }}>{s.label}</div>
              </div>
            </div>
          ))}
        </div>
      </WidgetShell>
    );
  },
};

// ─── Widget: Weather ───
widgetRegistry.weather = {
  label: 'Weather', icon: 'sun',
  render: ({ theme, editing, widgetProps }) => {
    const c = useTheme(theme);
    return (
      <WidgetShell c={c} editing={editing} {...widgetProps}>
        <div style={{ padding: '0 20px' }}>
          <div style={{ background: `linear-gradient(135deg, ${c.greenDeep}, ${c.green})`, borderRadius: 16, padding: 14, color: 'white', display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 42, height: 42, borderRadius: 12, background: 'rgba(255,255,255,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="sun" size={22} stroke={2.2} />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 11, opacity: 0.85, fontWeight: 500, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Timișoara · 19°C</div>
              <div style={{ fontSize: 13, fontWeight: 500, marginTop: 2, lineHeight: 1.35 }}>Rain Saturday — skip outdoor watering.</div>
            </div>
          </div>
        </div>
      </WidgetShell>
    );
  },
};

// ─── Widget: Overdue list ───
widgetRegistry.overdue = {
  label: 'Overdue', icon: 'drop',
  render: ({ theme, editing, widgetProps, onPlantClick, onToast }) => {
    const c = useTheme(theme);
    const items = [
      { id: 'bob', plant: 'Monstera "Bob"', latin: 'M. deliciosa', days: '2d late', action: 'drop', thumb: <plantThumbs.monstera size={44} /> },
      { id: 'green', plant: 'Pothos "Green"', latin: 'E. aureum', days: 'Fertilize', action: 'leaf', thumb: <plantThumbs.pothos size={44} /> },
    ];
    return (
      <WidgetShell title="Overdue" accent={{ color: c.terra, label: items.length }} c={c} editing={editing} {...widgetProps}>
        <div style={{ padding: '0 20px' }}>
          <div style={{ background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14, overflow: 'hidden' }}>
            {items.map((r, i) => (
              <div key={r.id} onClick={() => onPlantClick?.(r.id)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px', borderBottom: i < items.length - 1 ? `1px solid ${c.border}` : 'none', cursor: 'pointer' }}>
                <div style={{ width: 44, height: 44, borderRadius: 10, overflow: 'hidden', flexShrink: 0 }}>{r.thumb}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 600, color: c.text, lineHeight: 1.25 }}>{r.plant}</div>
                  <div style={{ fontSize: 11, color: c.terra, fontWeight: 600, marginTop: 2, display: 'flex', alignItems: 'center', gap: 4 }}>
                    <Icon name={r.action} size={11} stroke={2.4} /> {r.days}
                  </div>
                </div>
                <button onClick={(e) => { e.stopPropagation(); onToast?.(`Logged care for ${r.plant}`); }} style={{
                  fontSize: 11, fontWeight: 700, padding: '6px 12px', borderRadius: 8,
                  background: c.green, color: 'white', border: 'none', fontFamily: 'inherit', cursor: 'pointer',
                }}>Done</button>
              </div>
            ))}
          </div>
        </div>
      </WidgetShell>
    );
  },
};

// ─── Widget: Due today ───
widgetRegistry.today = {
  label: 'Due today', icon: 'check',
  render: ({ theme, editing, widgetProps, onPlantClick, onToast }) => {
    const c = useTheme(theme);
    const items = [
      { id: 'snake', plant: 'Snake plant', latin: 'D. trifasciata', action: 'Water', icon: 'drop', thumb: <plantThumbs.snake size={44} /> },
      { id: 'cala', plant: 'Calathea', latin: 'G. orbifolia', action: 'Mist', icon: 'drop', thumb: <plantThumbs.calathea size={44} /> },
      { id: 'fid', plant: 'Fiddle fig', latin: 'F. lyrata', action: 'Rotate', icon: 'sun', thumb: <plantThumbs.fiddle size={44} /> },
    ];
    return (
      <WidgetShell title="Due today" accent={{ color: c.green, label: items.length }} c={c} editing={editing} {...widgetProps}>
        <div style={{ padding: '0 20px' }}>
          <div style={{ background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14, overflow: 'hidden' }}>
            {items.map((r, i) => (
              <div key={r.id} onClick={() => onPlantClick?.(r.id)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px', borderBottom: i < items.length - 1 ? `1px solid ${c.border}` : 'none', cursor: 'pointer' }}>
                <div style={{ width: 44, height: 44, borderRadius: 10, overflow: 'hidden', flexShrink: 0 }}>{r.thumb}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 600, color: c.text, lineHeight: 1.25 }}>{r.plant}</div>
                  <div style={{ fontSize: 11, color: c.muted, fontWeight: 500, marginTop: 2, display: 'flex', alignItems: 'center', gap: 4 }}>
                    <Icon name={r.icon} size={11} stroke={2.2} /> {r.action}
                  </div>
                </div>
                <button onClick={(e) => { e.stopPropagation(); onToast?.(`${r.action}ed ${r.plant}`); }} style={{
                  width: 32, height: 32, borderRadius: 10,
                  background: c.greenSoft, color: c.green, border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
                }}><Icon name="check" size={16} stroke={2.5} /></button>
              </div>
            ))}
          </div>
        </div>
      </WidgetShell>
    );
  },
};

// ─── Widget: Plant grid ───
widgetRegistry.grid = {
  label: 'All plants (grid)', icon: 'home',
  render: ({ theme, editing, widgetProps, onPlantClick }) => {
    const c = useTheme(theme);
    const items = [
      { id: 'fern', name: 'Fern spray', loc: 'Bathroom', thumb: <plantThumbs.fern size={160} />, ok: true },
      { id: 'bob', name: 'Monstera "Bob"', loc: 'Living room', thumb: <plantThumbs.monstera size={160} /> },
      { id: 'suc', name: 'Hens & chicks', loc: 'South window', thumb: <plantThumbs.succulent size={160} />, ok: true },
      { id: 'green', name: 'Pothos', loc: 'Kitchen shelf', thumb: <plantThumbs.pothos size={160} /> },
      { id: 'pete', name: 'Prickly Pete', loc: 'Balcony', thumb: <plantThumbs.cactus size={160} />, ok: true },
      { id: 'cala', name: 'Calathea', loc: 'Bedroom', thumb: <plantThumbs.calathea size={160} />, ok: true },
    ];
    return (
      <WidgetShell title="All plants" accent={{ color: c.muted, label: '24' }} action="See all" c={c} editing={editing} {...widgetProps}>
        <div style={{ padding: '0 20px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {items.map((p) => (
            <div key={p.id} onClick={() => onPlantClick?.(p.id)} style={{ background: c.surface, borderRadius: 14, overflow: 'hidden', border: `1px solid ${c.border}`, cursor: 'pointer' }}>
              <div style={{ position: 'relative', aspectRatio: '1', background: c.surfaceAlt }}>
                {p.thumb}
                <div style={{
                  position: 'absolute', top: 8, right: 8,
                  width: 22, height: 22, borderRadius: 999,
                  background: p.ok ? c.greenSoft : c.terraSoft,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  border: `1.5px solid ${p.ok ? c.green : c.terra}`,
                }}>
                  <div style={{ width: 6, height: 6, borderRadius: 999, background: p.ok ? c.green : c.terra }} />
                </div>
              </div>
              <div style={{ padding: '8px 10px 10px' }}>
                <div style={{ fontSize: 12.5, fontWeight: 600, color: c.text, lineHeight: 1.2 }}>{p.name}</div>
                <div style={{ fontSize: 10, color: c.muted, marginTop: 2, display: 'flex', alignItems: 'center', gap: 3 }}>
                  <Icon name="location" size={9} stroke={2} /> {p.loc}
                </div>
              </div>
            </div>
          ))}
        </div>
      </WidgetShell>
    );
  },
};

// ─── Widget: Recent activity timeline ───
widgetRegistry.activity = {
  label: 'Recent activity', icon: 'calendar',
  render: ({ theme, editing, widgetProps }) => {
    const c = useTheme(theme);
    const items = [
      { when: '7:12', plant: 'Fern spray', event: 'Misted', icon: 'drop' },
      { when: 'Yesterday', plant: 'Fiddle fig', event: 'Rotated 90°', icon: 'sun' },
      { when: 'Apr 16', plant: 'Hens & chicks', event: 'Watered (50ml)', icon: 'drop' },
    ];
    return (
      <WidgetShell title="Recent activity" c={c} editing={editing} action="View all" {...widgetProps}>
        <div style={{ padding: '0 20px' }}>
          <div style={{ background: c.surface, border: `1px solid ${c.border}`, borderRadius: 14, padding: '4px 14px' }}>
            {items.map((r, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '10px 0', borderBottom: i < items.length - 1 ? `1px solid ${c.border}` : 'none' }}>
                <div style={{ width: 30, height: 30, borderRadius: 999, background: c.greenSoft, color: c.green, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <Icon name={r.icon} size={14} stroke={2.2} />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: c.text, lineHeight: 1.25 }}>{r.plant}</div>
                  <div style={{ fontSize: 11.5, color: c.muted }}>{r.event}</div>
                </div>
                <div style={{ fontSize: 11, color: c.muted, fontWeight: 500 }}>{r.when}</div>
              </div>
            ))}
          </div>
        </div>
      </WidgetShell>
    );
  },
};

// ─── Widget: Quick log (buttons for water/fertilize across multiple plants) ───
widgetRegistry.quicklog = {
  label: 'Quick log', icon: 'plus',
  render: ({ theme, editing, widgetProps, onToast }) => {
    const c = useTheme(theme);
    const actions = [
      { label: 'Water', icon: 'drop', color: c.green, soft: c.greenSoft },
      { label: 'Fertilize', icon: 'leaf', color: c.green, soft: c.greenSoft },
      { label: 'Mist', icon: 'drop', color: c.terra, soft: c.terraSoft },
      { label: 'Photo', icon: 'sun', color: c.terra, soft: c.terraSoft },
    ];
    return (
      <WidgetShell title="Quick log" c={c} editing={editing} {...widgetProps}>
        <div style={{ padding: '0 20px', display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
          {actions.map((a) => (
            <button key={a.label} onClick={() => onToast?.(`${a.label} logged`)} style={{
              background: c.surface, border: `1px solid ${c.border}`,
              borderRadius: 14, padding: '12px 6px',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
              cursor: 'pointer', fontFamily: 'inherit',
            }}>
              <div style={{ width: 32, height: 32, borderRadius: 10, background: a.soft, color: a.color, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name={a.icon} size={16} stroke={2.2} />
              </div>
              <div style={{ fontSize: 11, fontWeight: 600, color: c.text }}>{a.label}</div>
            </button>
          ))}
        </div>
      </WidgetShell>
    );
  },
};

window.widgetRegistry = widgetRegistry;
window.useTheme = useTheme;
