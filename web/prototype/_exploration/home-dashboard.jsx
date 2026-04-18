// Home Variation B — Dashboard
// Summary cards at top, weather banner, compact plant strip
const HomeDashboard = ({ theme = 'light' }) => {
  const dark = theme === 'dark';
  const bg = dark ? '#0a0a0a' : '#f7f6f2';
  const surface = dark ? '#18181b' : '#ffffff';
  const surfaceAlt = dark ? '#09090b' : '#fafaf7';
  const text = dark ? '#fafafa' : '#18181b';
  const muted = dark ? '#a1a1aa' : '#52525b';
  const border = dark ? '#27272a' : '#e4e4e7';
  const green = dark ? '#5aac83' : '#3D7A5F';
  const greenDeep = dark ? '#86bb9d' : '#264e3b';
  const greenSoft = dark ? 'rgba(90,172,131,0.15)' : '#f0f7f3';
  const terra = dark ? '#e58255' : '#C26A3A';
  const terraSoft = dark ? 'rgba(229,130,85,0.15)' : '#fbe8d7';

  const StatCard = ({ value, label, icon, tone }) => {
    const toneColor = tone === 'terra' ? terra : tone === 'muted' ? muted : green;
    const toneSoft = tone === 'terra' ? terraSoft : tone === 'muted' ? surfaceAlt : greenSoft;
    return (
      <div style={{
        background: surface, borderRadius: 16,
        border: `1px solid ${border}`, padding: '14px 14px 12px',
        display: 'flex', flexDirection: 'column', gap: 8,
      }}>
        <div style={{
          width: 32, height: 32, borderRadius: 10,
          background: toneSoft, color: toneColor,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon name={icon} size={16} stroke={2.2} />
        </div>
        <div>
          <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 28, fontWeight: 800, color: text, letterSpacing: '-0.02em', lineHeight: 1 }}>{value}</div>
          <div style={{ fontSize: 11.5, color: muted, marginTop: 4, fontWeight: 500 }}>{label}</div>
        </div>
      </div>
    );
  };

  return (
    <div style={{ height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column', background: bg }}>
      {/* App bar */}
      <div style={{ padding: '6px 20px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 40, height: 40, borderRadius: 999, background: greenSoft, color: green, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: "'Plus Jakarta Sans', sans-serif", fontWeight: 700 }}>AM</div>
          <div>
            <div style={{ fontSize: 12, color: muted, fontWeight: 500 }}>Good morning,</div>
            <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 17, fontWeight: 700, color: text, letterSpacing: '-0.01em' }}>Ana</div>
          </div>
        </div>
        <button style={{ width: 40, height: 40, borderRadius: 12, background: surface, border: `1px solid ${border}`, color: text, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
          <Icon name="bell" size={18} />
          <span style={{ position: 'absolute', top: 6, right: 7, width: 8, height: 8, borderRadius: 999, background: terra, border: `2px solid ${surface}` }} />
        </button>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '0 20px 24px' }}>
        {/* Stat grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 12 }}>
          <StatCard value="2" label="Overdue" icon="drop" tone="terra" />
          <StatCard value="3" label="Due today" icon="check" tone="green" />
          <StatCard value="24" label="Plants" icon="leaf" tone="muted" />
          <StatCard value="6" label="Spaces" icon="location" tone="muted" />
        </div>

        {/* Weather banner */}
        <div style={{
          background: `linear-gradient(135deg, ${greenDeep}, ${green})`,
          borderRadius: 16, padding: 16, color: 'white',
          display: 'flex', alignItems: 'center', gap: 14, marginBottom: 20,
        }}>
          <div style={{ width: 44, height: 44, borderRadius: 12, background: 'rgba(255,255,255,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <Icon name="sun" size={24} stroke={2.2} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 11, opacity: 0.8, fontWeight: 500, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Timișoara · 19°C</div>
            <div style={{ fontSize: 13, fontWeight: 500, marginTop: 2, lineHeight: 1.35 }}>Rain on Saturday — skip outdoor watering.</div>
          </div>
          <Icon name="chevron" size={18} style={{ opacity: 0.7 }} />
        </div>

        {/* Today list */}
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
          <h2 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 17, fontWeight: 700, margin: 0, color: text, letterSpacing: '-0.01em' }}>Today's care</h2>
          <div style={{ fontSize: 11, color: green, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em' }}>See all</div>
        </div>

        <div style={{ background: surface, borderRadius: 16, border: `1px solid ${border}`, overflow: 'hidden', marginBottom: 20 }}>
          {[
            { plant: 'Monstera "Bob"', action: 'Water — 2d overdue', icon: 'drop', urgent: true, thumb: <plantThumbs.monstera size={44} /> },
            { plant: 'Pothos "Green"', action: 'Fertilize — overdue', icon: 'leaf', urgent: true, thumb: <plantThumbs.pothos size={44} /> },
            { plant: 'Snake plant', action: 'Water — today', icon: 'drop', thumb: <plantThumbs.snake size={44} /> },
            { plant: 'Calathea', action: 'Mist — today', icon: 'drop', thumb: <plantThumbs.calathea size={44} /> },
          ].map((r, i, arr) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderBottom: i < arr.length - 1 ? `1px solid ${border}` : 'none' }}>
              <div style={{ width: 44, height: 44, borderRadius: 10, overflow: 'hidden', flexShrink: 0 }}>{r.thumb}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 600, color: text, lineHeight: 1.25 }}>{r.plant}</div>
                <div style={{
                  fontSize: 11.5, color: r.urgent ? terra : muted, marginTop: 2, fontWeight: 500,
                  display: 'flex', alignItems: 'center', gap: 5,
                }}>
                  <Icon name={r.icon} size={12} stroke={2.2} /> {r.action}
                </div>
              </div>
              <button style={{
                width: 32, height: 32, borderRadius: 10,
                background: greenSoft, color: green, border: 'none',
                display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
              }}>
                <Icon name="check" size={16} stroke={2.5} />
              </button>
            </div>
          ))}
        </div>

        {/* Recent plants strip */}
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
          <h2 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 17, fontWeight: 700, margin: 0, color: text, letterSpacing: '-0.01em' }}>Recently tended</h2>
        </div>
        <div style={{ display: 'flex', gap: 10, overflowX: 'auto', margin: '0 -20px', padding: '2px 20px 8px' }}>
          {[
            { name: 'Fern', when: '1h ago', thumb: <plantThumbs.fern size={120} /> },
            { name: 'Monstera', when: '3h ago', thumb: <plantThumbs.monstera size={120} /> },
            { name: 'Succulent', when: 'Yesterday', thumb: <plantThumbs.succulent size={120} /> },
            { name: 'Fiddle', when: 'Tue', thumb: <plantThumbs.fiddle size={120} /> },
          ].map((p, i) => (
            <div key={i} style={{ flexShrink: 0, width: 110 }}>
              <div style={{ aspectRatio: '1', borderRadius: 14, overflow: 'hidden', background: surface, border: `1px solid ${border}` }}>{p.thumb}</div>
              <div style={{ fontSize: 12.5, fontWeight: 600, color: text, marginTop: 8 }}>{p.name}</div>
              <div style={{ fontSize: 10.5, color: muted }}>{p.when}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Bottom tab bar */}
      <div style={{ borderTop: `1px solid ${border}`, background: surface, display: 'flex', padding: '8px 0 28px', position: 'relative' }}>
        {[
          { name: 'home', label: 'Plants', active: true },
          { name: 'calendar', label: 'Calendar' },
          { name: 'location', label: 'Spaces' },
          { name: 'user', label: 'Me' },
        ].map((t, i) => (
          <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, color: t.active ? green : muted }}>
            <Icon name={t.name} size={22} stroke={t.active ? 2.2 : 1.8} />
            <div style={{ fontSize: 10, fontWeight: t.active ? 600 : 500 }}>{t.label}</div>
          </div>
        ))}
        <button style={{
          position: 'absolute', right: 20, bottom: 72,
          width: 56, height: 56, borderRadius: 18, background: green, color: 'white', border: 'none',
          boxShadow: '0 8px 20px -4px rgba(61, 122, 95, 0.5)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }}>
          <Icon name="plus" size={24} stroke={2.5} />
        </button>
      </div>
    </div>
  );
};

window.HomeDashboard = HomeDashboard;
