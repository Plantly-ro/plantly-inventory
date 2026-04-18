// Locations hierarchy screen
const LocationsScreen = ({ theme = 'light' }) => {
  const dark = theme === 'dark';
  const bg = dark ? '#0a0a0a' : '#f7f6f2';
  const surface = dark ? '#18181b' : '#ffffff';
  const surfaceAlt = dark ? '#09090b' : '#fafaf7';
  const text = dark ? '#fafafa' : '#18181b';
  const muted = dark ? '#a1a1aa' : '#52525b';
  const border = dark ? '#27272a' : '#e4e4e7';
  const green = dark ? '#5aac83' : '#3D7A5F';
  const greenSoft = dark ? 'rgba(90,172,131,0.15)' : '#f0f7f3';
  const terra = dark ? '#e58255' : '#C26A3A';

  const LocNode = ({ icon, name, meta, count, indent = 0, expanded, children, last, outdoor }) => (
    <div>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '12px 14px', paddingLeft: 14 + indent * 20,
        borderBottom: last ? 'none' : `1px solid ${border}`,
      }}>
        {children !== undefined && (
          <div style={{ color: muted, display: 'flex', transform: expanded ? 'rotate(90deg)' : 'none', transition: 'transform 0.2s' }}>
            <Icon name="chevron" size={12} stroke={2.4} />
          </div>
        )}
        {children === undefined && <div style={{ width: 12 }} />}
        <div style={{
          width: 32, height: 32, borderRadius: 9,
          background: outdoor ? 'rgba(194,106,58,0.12)' : greenSoft,
          color: outdoor ? terra : green,
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}>
          <Icon name={icon} size={16} stroke={2} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: text, lineHeight: 1.2 }}>{name}</div>
          {meta && <div style={{ fontSize: 11, color: muted, marginTop: 2 }}>{meta}</div>}
        </div>
        <div style={{
          fontSize: 11, fontWeight: 600, color: muted,
          background: surfaceAlt, padding: '3px 8px', borderRadius: 999,
          border: `1px solid ${border}`,
        }}>{count}</div>
      </div>
      {expanded && children}
    </div>
  );

  return (
    <div style={{ height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column', background: bg }}>
      <div style={{ padding: '6px 20px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 11, color: muted, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Inventory</div>
          <h1 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 26, fontWeight: 800, margin: 0, color: text, letterSpacing: '-0.02em' }}>Spaces</h1>
        </div>
        <button style={{
          display: 'inline-flex', alignItems: 'center', gap: 5,
          background: green, color: 'white', border: 'none',
          padding: '8px 12px', borderRadius: 12, fontSize: 12, fontWeight: 600,
          fontFamily: 'inherit',
        }}>
          <Icon name="plus" size={14} stroke={2.4} /> New
        </button>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '0 20px 24px' }}>
        {/* Quick summary */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginBottom: 16 }}>
          {[
            { value: '6', label: 'Spaces' },
            { value: '24', label: 'Plants' },
            { value: '2', label: 'Outdoor' },
          ].map((s, i) => (
            <div key={i} style={{
              background: surface, border: `1px solid ${border}`,
              borderRadius: 12, padding: '10px 12px',
            }}>
              <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 20, fontWeight: 800, color: text, letterSpacing: '-0.02em' }}>{s.value}</div>
              <div style={{ fontSize: 10.5, color: muted, fontWeight: 500 }}>{s.label}</div>
            </div>
          ))}
        </div>

        {/* Tree */}
        <div style={{ background: surface, border: `1px solid ${border}`, borderRadius: 16, overflow: 'hidden' }}>
          <LocNode icon="door" name="Home" meta="Timișoara" count="20" expanded>
            <LocNode icon="home" name="Living room" meta="Bright, indirect · 40–60% RH" count="7" indent={1} expanded>
              <LocNode icon="shelf" name="South window" meta="Direct sun 4h" count="3" indent={2} />
              <LocNode icon="shelf" name="Coffee table" meta="Medium light" count="2" indent={2} />
              <LocNode icon="shelf" name="Bookcase" meta="Low light" count="2" indent={2} last />
            </LocNode>
            <LocNode icon="home" name="Kitchen" meta="Bright · medium humidity" count="4" indent={1} expanded>
              <LocNode icon="shelf" name="Window ledge" meta="East, 2h sun" count="2" indent={2} />
              <LocNode icon="shelf" name="Top of fridge" meta="Warm, low light" count="2" indent={2} last />
            </LocNode>
            <LocNode icon="home" name="Bedroom" meta="East light · cool" count="5" indent={1} />
            <LocNode icon="home" name="Bathroom" meta="Bright · 70% RH" count="2" indent={1} last />
          </LocNode>
          <LocNode icon="outdoor" name="Balcony" meta="South-facing · 18°C today" count="4" outdoor last />
        </div>

        {/* Care hint */}
        <div style={{
          marginTop: 16,
          background: greenSoft, borderRadius: 14,
          padding: '12px 14px', display: 'flex', gap: 10, alignItems: 'flex-start',
        }}>
          <div style={{ color: green, flexShrink: 0, marginTop: 1 }}>
            <Icon name="sun" size={18} stroke={2.2} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 12.5, fontWeight: 600, color: dark ? '#fafafa' : '#264e3b', lineHeight: 1.35 }}>South window is getting 4h+ of direct sun</div>
            <div style={{ fontSize: 11.5, color: dark ? '#a1a1aa' : '#3f3f46', marginTop: 2, lineHeight: 1.4 }}>Your Calathea may prefer it in the bookcase — tap to move.</div>
          </div>
        </div>
      </div>

      <div style={{ borderTop: `1px solid ${border}`, background: surface, display: 'flex', padding: '8px 0 28px' }}>
        {[
          { name: 'home', label: 'Plants' },
          { name: 'calendar', label: 'Calendar' },
          { name: 'location', label: 'Spaces', active: true },
          { name: 'user', label: 'Me' },
        ].map((t, i) => (
          <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, color: t.active ? green : muted }}>
            <Icon name={t.name} size={22} stroke={t.active ? 2.2 : 1.8} />
            <div style={{ fontSize: 10, fontWeight: t.active ? 600 : 500 }}>{t.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
};

window.LocationsScreen = LocationsScreen;
