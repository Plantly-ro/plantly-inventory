// Desktop home (secondary surface) — web app layout
const DesktopHome = ({ theme = 'light' }) => {
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

  const NavLink = ({ icon, label, active, count }) => (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '9px 12px', borderRadius: 10,
      background: active ? greenSoft : 'transparent',
      color: active ? green : text,
      fontSize: 13.5, fontWeight: active ? 600 : 500,
      cursor: 'pointer',
    }}>
      <Icon name={icon} size={17} stroke={active ? 2.2 : 1.8} />
      <span style={{ flex: 1 }}>{label}</span>
      {count && (
        <span style={{
          background: active ? green : surfaceAlt, color: active ? 'white' : muted,
          fontSize: 11, fontWeight: 600, padding: '1px 8px', borderRadius: 999,
        }}>{count}</span>
      )}
    </div>
  );

  const PlantCard = ({ name, latin, location, thumb, status, due }) => {
    const isOverdue = status === 'overdue';
    return (
      <div style={{ background: surface, border: `1px solid ${border}`, borderRadius: 16, overflow: 'hidden' }}>
        <div style={{ position: 'relative', aspectRatio: '1.2', background: surfaceAlt }}>
          {thumb}
          {status && (
            <div style={{
              position: 'absolute', top: 10, left: 10,
              display: 'inline-flex', alignItems: 'center', gap: 5,
              background: isOverdue ? terraSoft : greenSoft,
              color: isOverdue ? terra : green,
              padding: '3px 9px', borderRadius: 999,
              fontSize: 10.5, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em',
              backdropFilter: 'blur(8px)',
            }}>
              <Icon name="drop" size={11} stroke={2.4} /> {due}
            </div>
          )}
          <button style={{
            position: 'absolute', top: 10, right: 10,
            width: 30, height: 30, borderRadius: 999,
            background: 'rgba(255,255,255,0.85)', backdropFilter: 'blur(8px)',
            border: 'none', color: muted,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Icon name="heart" size={14} />
          </button>
        </div>
        <div style={{ padding: '12px 14px 14px' }}>
          <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 15, fontWeight: 700, color: text, letterSpacing: '-0.01em', lineHeight: 1.2 }}>{name}</div>
          <div style={{ fontSize: 12, color: muted, fontStyle: 'italic', marginTop: 2 }}>{latin}</div>
          <div style={{ fontSize: 11.5, color: muted, marginTop: 8, display: 'flex', alignItems: 'center', gap: 4 }}>
            <Icon name="location" size={11} stroke={2} /> {location}
          </div>
        </div>
      </div>
    );
  };

  return (
    <div style={{ height: '100%', overflow: 'hidden', display: 'flex', background: bg, fontFamily: "'Inter', system-ui, sans-serif", color: text }}>
      {/* Sidebar */}
      <div style={{ width: 240, background: surface, borderRight: `1px solid ${border}`, display: 'flex', flexDirection: 'column', padding: '20px 14px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '0 8px 20px' }}>
          <div style={{ fontSize: 22 }}>🌿</div>
          <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontWeight: 800, fontSize: 16, color: green, letterSpacing: '-0.01em' }}>Plantly<span style={{ color: muted, fontWeight: 600 }}>Inventory</span></div>
        </div>

        <div style={{ fontSize: 10.5, fontWeight: 700, color: muted, textTransform: 'uppercase', letterSpacing: '0.1em', padding: '6px 12px 8px' }}>Care</div>
        <NavLink icon="home" label="Plants" active count="24" />
        <NavLink icon="calendar" label="Calendar" />
        <NavLink icon="drop" label="Care log" />
        <NavLink icon="bell" label="Reminders" count="5" />

        <div style={{ fontSize: 10.5, fontWeight: 700, color: muted, textTransform: 'uppercase', letterSpacing: '0.1em', padding: '20px 12px 8px' }}>Inventory</div>
        <NavLink icon="location" label="Spaces" count="6" />
        <NavLink icon="leaf" label="Species" />
        <NavLink icon="repot" label="Propagations" />

        <div style={{ fontSize: 10.5, fontWeight: 700, color: muted, textTransform: 'uppercase', letterSpacing: '0.1em', padding: '20px 12px 8px' }}>Export</div>
        <NavLink icon="door" label="plantly.ro" count="2" />

        <div style={{ flex: 1 }} />
        {/* Sync status */}
        <div style={{ background: surfaceAlt, border: `1px solid ${border}`, borderRadius: 12, padding: '10px 12px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
            <div style={{ width: 7, height: 7, borderRadius: 999, background: green }} />
            <span style={{ fontSize: 11.5, fontWeight: 600, color: text }}>Synced</span>
          </div>
          <div style={{ fontSize: 10.5, color: muted }}>2 devices · MinIO self-host</div>
        </div>
      </div>

      {/* Main */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* Header bar */}
        <div style={{ padding: '18px 28px', borderBottom: `1px solid ${border}`, background: surface, display: 'flex', alignItems: 'center', gap: 16 }}>
          <div style={{ flex: 1, maxWidth: 420, position: 'relative' }}>
            <div style={{ position: 'absolute', left: 12, top: 9, color: muted }}>
              <Icon name="search" size={16} />
            </div>
            <input placeholder="Search plants, species, tags…" style={{
              width: '100%', padding: '9px 12px 9px 38px', borderRadius: 10,
              border: `1px solid ${border}`, background: surfaceAlt, color: text,
              fontSize: 13, fontFamily: 'inherit', outline: 'none',
            }} />
          </div>
          <button style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '8px 12px', borderRadius: 10,
            border: `1px solid ${border}`, background: surface, color: text,
            fontSize: 12.5, fontWeight: 600, fontFamily: 'inherit',
          }}>
            <Icon name="filter" size={14} stroke={2.2} /> Filter
          </button>
          <div style={{ width: 1, height: 24, background: border }} />
          <button style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '8px 14px', borderRadius: 10,
            background: green, color: 'white', border: 'none',
            fontSize: 12.5, fontWeight: 600, fontFamily: 'inherit',
          }}>
            <Icon name="plus" size={14} stroke={2.4} /> New plant
          </button>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: '24px 28px 32px' }}>
          {/* Header with weather */}
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 20 }}>
            <div>
              <div style={{ fontSize: 12, color: muted, fontWeight: 500, letterSpacing: '0.02em' }}>Friday · April 18</div>
              <h1 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 30, fontWeight: 800, margin: '2px 0 0', color: text, letterSpacing: '-0.02em' }}>Your plants</h1>
            </div>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 10,
              background: `linear-gradient(135deg, ${greenDeep}, ${green})`,
              color: 'white', padding: '10px 14px', borderRadius: 12,
            }}>
              <Icon name="sun" size={18} stroke={2.2} />
              <div>
                <div style={{ fontSize: 10.5, opacity: 0.85, fontWeight: 500, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Timișoara</div>
                <div style={{ fontSize: 13, fontWeight: 600 }}>19°C · rain Saturday</div>
              </div>
            </div>
          </div>

          {/* Summary strip */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
            {[
              { value: '2', label: 'Overdue', tone: 'terra', icon: 'drop' },
              { value: '3', label: 'Due today', tone: 'green', icon: 'check' },
              { value: '24', label: 'Total plants', tone: 'muted', icon: 'leaf' },
              { value: '6', label: 'Spaces', tone: 'muted', icon: 'location' },
            ].map((s, i) => {
              const col = s.tone === 'terra' ? terra : s.tone === 'green' ? green : muted;
              const soft = s.tone === 'terra' ? terraSoft : s.tone === 'green' ? greenSoft : surfaceAlt;
              return (
                <div key={i} style={{ background: surface, border: `1px solid ${border}`, borderRadius: 14, padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 40, height: 40, borderRadius: 11, background: soft, color: col, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Icon name={s.icon} size={18} stroke={2.2} />
                  </div>
                  <div>
                    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 26, fontWeight: 800, color: text, letterSpacing: '-0.02em', lineHeight: 1 }}>{s.value}</div>
                    <div style={{ fontSize: 11.5, color: muted, marginTop: 4, fontWeight: 500 }}>{s.label}</div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Overdue + Due today strip */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <h2 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 18, fontWeight: 700, margin: 0, color: text, letterSpacing: '-0.01em' }}>Needs attention</h2>
            <span style={{ fontSize: 12, color: terra, fontWeight: 600 }}>2 overdue · 3 due today</span>
          </div>
          <div style={{ background: surface, border: `1px solid ${border}`, borderRadius: 14, overflow: 'hidden', marginBottom: 28 }}>
            {[
              { plant: 'Monstera "Bob"', latin: 'M. deliciosa', loc: 'Living room › South window', action: 'Water', days: '2 days late', urgent: true, thumb: <plantThumbs.monstera size={44} /> },
              { plant: 'Pothos "Green"', latin: 'E. aureum', loc: 'Kitchen shelf', action: 'Fertilize', days: 'Overdue', urgent: true, thumb: <plantThumbs.pothos size={44} /> },
              { plant: 'Snake plant', latin: 'D. trifasciata', loc: 'Bedroom', action: 'Water', days: 'Today', thumb: <plantThumbs.snake size={44} /> },
              { plant: 'Calathea', latin: 'G. orbifolia', loc: 'Bookcase', action: 'Mist', days: 'Today', thumb: <plantThumbs.calathea size={44} /> },
            ].map((r, i, arr) => (
              <div key={i} style={{ display: 'grid', gridTemplateColumns: '56px 1.6fr 1.4fr 1fr auto', alignItems: 'center', gap: 14, padding: '11px 16px', borderBottom: i < arr.length - 1 ? `1px solid ${border}` : 'none' }}>
                <div style={{ width: 44, height: 44, borderRadius: 10, overflow: 'hidden' }}>{r.thumb}</div>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 600, color: text, lineHeight: 1.2 }}>{r.plant}</div>
                  <div style={{ fontSize: 11.5, color: muted, fontStyle: 'italic' }}>{r.latin}</div>
                </div>
                <div style={{ fontSize: 12, color: muted, display: 'flex', alignItems: 'center', gap: 5 }}>
                  <Icon name="location" size={11} stroke={2} /> {r.loc}
                </div>
                <div style={{
                  fontSize: 11.5, fontWeight: 600,
                  color: r.urgent ? terra : green,
                }}>{r.action} · {r.days}</div>
                <div style={{ display: 'flex', gap: 6 }}>
                  <button style={{ fontSize: 11.5, fontWeight: 600, padding: '6px 11px', borderRadius: 8, background: surfaceAlt, color: muted, border: `1px solid ${border}`, fontFamily: 'inherit' }}>Snooze</button>
                  <button style={{ fontSize: 11.5, fontWeight: 600, padding: '6px 13px', borderRadius: 8, background: green, color: 'white', border: 'none', fontFamily: 'inherit' }}>Log done</button>
                </div>
              </div>
            ))}
          </div>

          {/* Grid */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <h2 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 18, fontWeight: 700, margin: 0, color: text, letterSpacing: '-0.01em' }}>All plants</h2>
            <div style={{ fontSize: 12, color: muted }}>Sorted by last cared</div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 14 }}>
            <PlantCard name='Monstera "Bob"' latin="Monstera deliciosa" location="Living room" thumb={<plantThumbs.monstera size={240} />} status="overdue" due="2d late" />
            <PlantCard name='Pothos "Green"' latin="Epipremnum aureum" location="Kitchen shelf" thumb={<plantThumbs.pothos size={240} />} />
            <PlantCard name="Snake plant" latin="Dracaena trifasciata" location="Bedroom" thumb={<plantThumbs.snake size={240} />} />
            <PlantCard name="Fiddle fig" latin="Ficus lyrata" location="Living room" thumb={<plantThumbs.fiddle size={240} />} />
            <PlantCard name="Fern spray" latin="Nephrolepis exaltata" location="Bathroom" thumb={<plantThumbs.fern size={240} />} />
            <PlantCard name="Hens & chicks" latin="Sempervivum" location="South window" thumb={<plantThumbs.succulent size={240} />} />
            <PlantCard name="Calathea" latin="Goeppertia orbifolia" location="Bookcase" thumb={<plantThumbs.calathea size={240} />} />
            <PlantCard name="Prickly Pete" latin="Opuntia microdasys" location="Balcony" thumb={<plantThumbs.cactus size={240} />} />
          </div>
        </div>
      </div>
    </div>
  );
};

window.DesktopHome = DesktopHome;
