// Home Variation C — Feed (chronological timeline of plants needing attention + recent events)
const HomeFeed = ({ theme = 'light' }) => {
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

  const Chip = ({ active, children }) => (
    <div style={{
      padding: '6px 12px', borderRadius: 999,
      background: active ? green : surface,
      color: active ? 'white' : text,
      border: `1px solid ${active ? green : border}`,
      fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap',
    }}>{children}</div>
  );

  const DueCard = ({ plant, latin, location, action, label, tone, thumb }) => {
    const accent = tone === 'terra' ? terra : green;
    const accentSoft = tone === 'terra' ? terraSoft : greenSoft;
    return (
      <div style={{ background: surface, borderRadius: 20, border: `1px solid ${border}`, padding: 14, display: 'flex', gap: 14 }}>
        <div style={{ width: 84, height: 84, borderRadius: 14, overflow: 'hidden', flexShrink: 0 }}>{thumb}</div>
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
          <div>
            <div style={{
              display: 'inline-flex', alignItems: 'center', gap: 5,
              background: accentSoft, color: accent,
              padding: '3px 8px', borderRadius: 999,
              fontSize: 10.5, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em',
              marginBottom: 6,
            }}>
              <Icon name={action} size={11} stroke={2.4} />
              <span>{label}</span>
            </div>
            <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 16, fontWeight: 700, color: text, letterSpacing: '-0.01em', lineHeight: 1.2 }}>{plant}</div>
            <div style={{ fontSize: 11.5, color: muted, fontStyle: 'italic', marginTop: 2 }}>{latin}</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 8 }}>
            <div style={{ fontSize: 11, color: muted, display: 'flex', alignItems: 'center', gap: 3 }}>
              <Icon name="location" size={10} stroke={2} /> {location}
            </div>
            <div style={{ display: 'flex', gap: 6 }}>
              <button style={{ fontSize: 11, fontWeight: 600, padding: '5px 10px', borderRadius: 8, background: surfaceAlt, color: muted, border: `1px solid ${border}`, fontFamily: 'inherit' }}>Snooze</button>
              <button style={{ fontSize: 11, fontWeight: 600, padding: '5px 12px', borderRadius: 8, background: green, color: 'white', border: 'none', fontFamily: 'inherit' }}>Done</button>
            </div>
          </div>
        </div>
      </div>
    );
  };

  const TimelineRow = ({ when, plant, event, icon, thumb, last }) => (
    <div style={{ display: 'flex', gap: 12 }}>
      <div style={{ width: 28, display: 'flex', flexDirection: 'column', alignItems: 'center', flexShrink: 0 }}>
        <div style={{ width: 28, height: 28, borderRadius: 999, background: greenSoft, color: green, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name={icon} size={14} stroke={2.2} />
        </div>
        {!last && <div style={{ width: 1.5, flex: 1, background: border, minHeight: 16 }} />}
      </div>
      <div style={{ flex: 1, paddingBottom: last ? 0 : 14 }}>
        <div style={{ fontSize: 11, color: muted, fontWeight: 500, marginBottom: 4 }}>{when}</div>
        <div style={{ background: surface, borderRadius: 14, border: `1px solid ${border}`, padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 36, height: 36, borderRadius: 8, overflow: 'hidden', flexShrink: 0 }}>{thumb}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13.5, fontWeight: 600, color: text, lineHeight: 1.25 }}>{plant}</div>
            <div style={{ fontSize: 11.5, color: muted }}>{event}</div>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div style={{ height: '100%', overflow: 'hidden', display: 'flex', flexDirection: 'column', background: bg }}>
      <div style={{ padding: '6px 20px 14px' }}>
        <h1 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 28, fontWeight: 800, margin: 0, color: text, letterSpacing: '-0.02em' }}>Today</h1>
        <div style={{ fontSize: 13, color: muted, marginTop: 2 }}>Friday, April 18 · 2 overdue</div>
      </div>

      <div style={{ padding: '0 20px 12px', display: 'flex', gap: 6, overflowX: 'auto', margin: '0 -20px', paddingLeft: 20, paddingRight: 20 }}>
        <Chip active>Needs care</Chip>
        <Chip>This week</Chip>
        <Chip>Activity</Chip>
        <Chip>Outdoor</Chip>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 20px 24px' }}>
        {/* Needs care - cards */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <DueCard
            plant={'Monstera "Bob"'} latin="Monstera deliciosa"
            location="Living room · South window"
            action="drop" label="2 days late" tone="terra"
            thumb={<plantThumbs.monstera size={84} />}
          />
          <DueCard
            plant={'Pothos "Green"'} latin="Epipremnum aureum"
            location="Kitchen shelf"
            action="leaf" label="Fertilize overdue" tone="terra"
            thumb={<plantThumbs.pothos size={84} />}
          />
          <DueCard
            plant="Snake plant" latin="Dracaena trifasciata"
            location="Bedroom · east window"
            action="drop" label="Water today" tone="green"
            thumb={<plantThumbs.snake size={84} />}
          />
        </div>

        {/* Recent activity */}
        <h2 style={{ fontFamily: "'Plus Jakarta Sans', sans-serif", fontSize: 16, fontWeight: 700, color: text, margin: '28px 0 14px', letterSpacing: '-0.01em' }}>Recent activity</h2>
        <div>
          <TimelineRow when="Today · 7:12" plant="Fern spray" event="Misted" icon="drop" thumb={<plantThumbs.fern size={36} />} />
          <TimelineRow when="Yesterday · 18:30" plant="Fiddle fig" event="Rotated 90°" icon="sun" thumb={<plantThumbs.fiddle size={36} />} />
          <TimelineRow when="Apr 16 · 09:04" plant="Hens & chicks" event="Watered (50ml)" icon="drop" thumb={<plantThumbs.succulent size={36} />} />
          <TimelineRow when="Apr 15 · 17:22" plant={'Monstera "Bob"'} event="Fertilized — NPK 10-10-10, ¼ tsp" icon="leaf" thumb={<plantThumbs.monstera size={36} />} last />
        </div>
      </div>

      <div style={{ borderTop: `1px solid ${border}`, background: surface, display: 'flex', padding: '8px 0 28px', position: 'relative' }}>
        {[
          { name: 'home', label: 'Feed', active: true },
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

window.HomeFeed = HomeFeed;
