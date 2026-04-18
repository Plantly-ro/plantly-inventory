// Home Variation A — Grouped (Overdue → Due today → All plants)
// Matches the wireframe in PLAN.md most closely: care-first triage
const HomeGrouped = ({ theme = 'light' }) => {
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
  const terraSoft = dark ? 'rgba(229,130,85,0.15)' : '#fbe8d7';

  const SectionTitle = ({ children, count, accent }) => (
    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '20px 20px 10px' }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <h2 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 17, fontWeight: 700, margin: 0, color: text, letterSpacing: '-0.01em' }}>{children}</h2>
        <span style={{ fontSize: 13, fontWeight: 600, color: accent || muted }}>{count}</span>
      </div>
      <Icon name="chevronDown" size={16} style={{ color: muted }} />
    </div>
  );

  const CareRow = ({ plant, thumb, latin, days, action, urgent }) => {
    const accent = urgent ? terra : green;
    const accentSoft = urgent ? terraSoft : greenSoft;
    return (
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '10px 20px',
      }}>
        <div style={{ width: 48, height: 48, borderRadius: 12, overflow: 'hidden', flexShrink: 0, background: surfaceAlt }}>
          {thumb}
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 15, fontWeight: 600, color: text, lineHeight: 1.25 }}>{plant}</div>
          <div style={{ fontSize: 12, color: muted, marginTop: 1, fontStyle: 'italic' }}>{latin}</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 5,
            background: accentSoft, color: accent,
            padding: '4px 9px', borderRadius: 999,
            fontSize: 11, fontWeight: 600,
          }}>
            <Icon name={action} size={12} stroke={2.2} />
            <span>{days}</span>
          </div>
          <button style={{
            border: `1px solid ${border}`, background: surface,
            color: text, fontSize: 11, fontWeight: 600,
            padding: '4px 10px', borderRadius: 8, cursor: 'pointer',
            fontFamily: 'inherit',
          }}>Log</button>
        </div>
      </div>
    );
  };

  const PlantTile = ({ thumb, name, location, ok }) => (
    <div style={{ background: surface, borderRadius: 16, overflow: 'hidden', border: `1px solid ${border}` }}>
      <div style={{ position: 'relative', aspectRatio: '1', background: surfaceAlt }}>
        {thumb}
        <div style={{
          position: 'absolute', top: 8, right: 8,
          width: 24, height: 24, borderRadius: 999,
          background: ok ? greenSoft : terraSoft,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          border: `1.5px solid ${ok ? green : terra}`,
        }}>
          <div style={{ width: 6, height: 6, borderRadius: 999, background: ok ? green : terra }} />
        </div>
      </div>
      <div style={{ padding: '8px 10px 10px' }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: text, lineHeight: 1.25 }}>{name}</div>
        <div style={{ fontSize: 10.5, color: muted, marginTop: 2, display: 'flex', alignItems: 'center', gap: 3 }}>
          <Icon name="location" size={10} stroke={2} /> {location}
        </div>
      </div>
    </div>
  );

  return (
    <div style={{ height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column', background: bg }}>
      {/* App bar */}
      <div style={{ padding: '6px 20px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 12, color: muted, fontWeight: 500, letterSpacing: '0.02em' }}>Friday · Apr 18</div>
          <h1 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 26, fontWeight: 800, margin: 0, color: text, letterSpacing: '-0.02em' }}>My plants</h1>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button style={{ width: 40, height: 40, borderRadius: 12, background: surface, border: `1px solid ${border}`, color: text, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="search" size={18} /></button>
          <button style={{ width: 40, height: 40, borderRadius: 12, background: surface, border: `1px solid ${border}`, color: text, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
            <Icon name="bell" size={18} />
            <span style={{ position: 'absolute', top: 6, right: 7, width: 8, height: 8, borderRadius: 999, background: terra, border: `2px solid ${surface}` }} />
          </button>
        </div>
      </div>

      {/* Scroll area */}
      <div style={{ flex: 1, overflowY: 'auto' }}>
        {/* Overdue */}
        <SectionTitle count="2" accent={terra}>Overdue</SectionTitle>
        <div style={{ background: surface, borderTop: `1px solid ${border}`, borderBottom: `1px solid ${border}` }}>
          <CareRow plant={'Monstera "Bob"'} latin="M. deliciosa" thumb={<plantThumbs.monstera size={48} />} days="2d late" action="drop" urgent />
          <div style={{ height: 1, background: border, marginLeft: 80 }} />
          <CareRow plant={'Pothos "Green"'} latin="Epipremnum aureum" thumb={<plantThumbs.pothos size={48} />} days="Fertilize" action="leaf" urgent />
        </div>

        {/* Due today */}
        <SectionTitle count="3" accent={green}>Due today</SectionTitle>
        <div style={{ background: surface, borderTop: `1px solid ${border}`, borderBottom: `1px solid ${border}` }}>
          <CareRow plant="Snake plant" latin="Dracaena trifasciata" thumb={<plantThumbs.snake size={48} />} days="Water" action="drop" />
          <div style={{ height: 1, background: border, marginLeft: 80 }} />
          <CareRow plant="Calathea" latin="Goeppertia orbifolia" thumb={<plantThumbs.calathea size={48} />} days="Mist" action="drop" />
          <div style={{ height: 1, background: border, marginLeft: 80 }} />
          <CareRow plant="Fiddle fig" latin="Ficus lyrata" thumb={<plantThumbs.fiddle size={48} />} days="Rotate" action="sun" />
        </div>

        {/* All plants */}
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '22px 20px 12px' }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
            <h2 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 17, fontWeight: 700, margin: 0, color: text, letterSpacing: '-0.01em' }}>All plants</h2>
            <span style={{ fontSize: 13, fontWeight: 600, color: muted }}>24</span>
          </div>
          <div style={{ display: 'flex', gap: 2, background: surfaceAlt, padding: 3, borderRadius: 8, border: `1px solid ${border}` }}>
            <button style={{ padding: '4px 9px', borderRadius: 6, background: surface, color: text, border: 'none', fontSize: 11, fontWeight: 600, fontFamily: 'inherit' }}>Grid</button>
            <button style={{ padding: '4px 9px', borderRadius: 6, background: 'transparent', color: muted, border: 'none', fontSize: 11, fontWeight: 600, fontFamily: 'inherit' }}>List</button>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, padding: '0 20px 24px' }}>
          <PlantTile name="Fern spray" location="Bathroom" thumb={<plantThumbs.fern size={160} />} ok />
          <PlantTile name='Monstera "Bob"' location="Living room" thumb={<plantThumbs.monstera size={160} />} />
          <PlantTile name="Hens & chicks" location="South window" thumb={<plantThumbs.succulent size={160} />} ok />
          <PlantTile name="Pothos" location="Kitchen shelf" thumb={<plantThumbs.pothos size={160} />} />
          <PlantTile name="Prickly Pete" location="South window" thumb={<plantThumbs.cactus size={160} />} ok />
          <PlantTile name="Calathea" location="Bedroom" thumb={<plantThumbs.calathea size={160} />} ok />
        </div>
      </div>

      {/* Bottom tab bar */}
      <div style={{
        borderTop: `1px solid ${border}`, background: surface,
        display: 'flex', padding: '8px 0 28px', position: 'relative',
      }}>
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
        {/* FAB */}
        <button style={{
          position: 'absolute', right: 20, bottom: 72,
          width: 56, height: 56, borderRadius: 18,
          background: green, color: 'white', border: 'none',
          boxShadow: '0 8px 20px -4px rgba(61, 122, 95, 0.5)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }}>
          <Icon name="plus" size={24} stroke={2.5} />
        </button>
      </div>
    </div>
  );
};

window.HomeGrouped = HomeGrouped;
