// Shared primitives for PlantlyInventory mocks
// All screens consume tokens via CSS vars from colors_and_type.css

// ─── Mini icons (inline SVG — matches Plantly's Heroicons-outline convention) ───
const Icon = ({ name, size = 20, stroke = 2, className = '', style = {} }) => {
  const paths = {
    search: <path d="m21 21-4.35-4.35M17 10a7 7 0 1 1-14 0 7 7 0 0 1 14 0Z" />,
    bell: <path d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0" />,
    settings: <><path d="M10.343 3.94c.09-.542.56-.94 1.11-.94h1.093c.55 0 1.02.398 1.11.94l.149.894c.07.424.384.764.78.93.398.164.855.142 1.205-.108l.737-.527a1.125 1.125 0 0 1 1.45.12l.773.774c.39.389.44 1.002.12 1.45l-.527.737c-.25.35-.272.806-.107 1.204.165.397.505.71.93.78l.893.15c.543.09.94.56.94 1.109v1.094c0 .55-.397 1.02-.94 1.11l-.894.149c-.424.07-.764.383-.929.78-.165.398-.143.854.107 1.204l.527.738c.32.447.269 1.06-.12 1.45l-.774.773a1.125 1.125 0 0 1-1.449.12l-.738-.527c-.35-.25-.806-.272-1.203-.107-.398.165-.71.505-.781.929l-.149.894c-.09.542-.56.94-1.11.94h-1.094c-.55 0-1.019-.398-1.11-.94l-.148-.894c-.071-.424-.384-.764-.781-.93-.398-.164-.854-.142-1.204.108l-.738.527a1.125 1.125 0 0 1-1.45-.12l-.773-.774a1.125 1.125 0 0 1-.12-1.45l.527-.737c.25-.35.272-.806.108-1.204-.165-.397-.506-.71-.93-.78l-.894-.15c-.542-.09-.94-.56-.94-1.109v-1.094c0-.55.398-1.02.94-1.11l.894-.149c.424-.07.765-.383.93-.78.165-.398.143-.854-.108-1.204l-.526-.738a1.125 1.125 0 0 1 .12-1.45l.773-.773a1.125 1.125 0 0 1 1.45-.12l.737.527c.35.25.807.272 1.204.107.397-.165.71-.505.78-.929l.15-.894Z" /><path d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" /></>,
    drop: <path d="M12 2.25c-1.99 3.5-7.5 8.5-7.5 13.25a7.5 7.5 0 0 0 15 0c0-4.75-5.51-9.75-7.5-13.25Z" />,
    leaf: <path d="M8.5 14.5 3 20m5.5-5.5c1.5-1.5 3-3 4-5 1.5-3 1.5-6 1.5-6s-3 0-6 1.5c-2 1-3.5 2.5-5 4s-2 3.5-2 5 1 2.5 2.5 2.5 3.5-.5 5-2Z M14 10c2 0 4-1 5-2 2-2 2-5 2-5s-3 0-5 2c-1 1-2 3-2 5Z" />,
    repot: <path d="M4 9h16l-2 11H6L4 9Zm4-3V5a4 4 0 0 1 8 0v1M8 6h8m-4 5v5m-3-3 3 3 3-3" />,
    prune: <path d="M6 4v6m0 0a3 3 0 1 0 0 6m0-6a3 3 0 1 1 0 6M6 16v4m14-12v6m0 0a3 3 0 1 0 0 6m0-6a3 3 0 1 1 0 6M20 20v-4M6 10h14" />,
    sun: <path d="M12 3v2.25m6.364 1.386-1.591 1.591M21 12h-2.25m-1.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z" />,
    plus: <path d="M12 4.5v15m7.5-7.5h-15" />,
    home: <path d="m2.25 12 8.954-8.955a1.5 1.5 0 0 1 2.122 0L22.28 12M4.5 9.75v10.125a1.125 1.125 0 0 0 1.125 1.125H9.75v-4.875a1.125 1.125 0 0 1 1.125-1.125h2.25a1.125 1.125 0 0 1 1.125 1.125V21h4.125a1.125 1.125 0 0 0 1.125-1.125V9.75" />,
    calendar: <path d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5" />,
    user: <path d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.5 20.25a7.5 7.5 0 0 1 15 0" />,
    chevron: <path d="m8.25 4.5 7.5 7.5-7.5 7.5" />,
    chevronDown: <path d="m19.5 8.25-7.5 7.5-7.5-7.5" />,
    location: <><path d="M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" /><path d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1 1 15 0Z" /></>,
    filter: <path d="M12 3c2.755 0 5.455.232 8.083.678.533.09.917.556.917 1.096v1.044a2.25 2.25 0 0 1-.659 1.591l-5.432 5.432a2.25 2.25 0 0 0-.659 1.591v2.927a2.25 2.25 0 0 1-1.244 2.013L9.75 21v-6.568a2.25 2.25 0 0 0-.659-1.591L3.659 7.409A2.25 2.25 0 0 1 3 5.818V4.774c0-.54.384-1.005.917-1.096A48.32 48.32 0 0 1 12 3Z" />,
    heart: <path d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />,
    check: <path d="m4.5 12.75 6 6 9-13.5" />,
    snooze: <path d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />,
    door: <path d="M2.25 12 12 2.25 21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H18.375a1.125 1.125 0 0 0 1.125-1.125V9.75M8.25 21v-6h7.5v6" />,
    shelf: <path d="M3.75 6.75h16.5M3.75 12h16.5M3.75 17.25h16.5" />,
    outdoor: <><path d="M12 3v2m0 0a7 7 0 0 0-7 7m7-7a7 7 0 0 1 7 7m-14 0H3m16 0h2M7.05 7.05 5.636 5.636m12.728 0L16.95 7.05" /><path d="M4 20h16M8 20v-3a4 4 0 0 1 8 0v3" /></>,
  };
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="none" stroke="currentColor" strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" className={className} style={style} aria-hidden="true">
      {paths[name]}
    </svg>
  );
};

// ─── Phone frame — minimalist, not iOS/Android specific ───
const PhoneFrame = ({ children, label, theme = 'light' }) => {
  const bg = theme === 'dark' ? '#09090b' : '#f7f6f2';
  const shell = theme === 'dark' ? '#0a0a0a' : '#1a1a1a';
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{
        width: 390, height: 844, borderRadius: 54,
        background: shell, padding: 14,
        boxShadow: '0 30px 60px -20px rgba(0,0,0,0.25), 0 10px 20px -10px rgba(0,0,0,0.15), inset 0 0 0 2px rgba(255,255,255,0.04)',
      }}>
        <div style={{
          width: '100%', height: '100%', borderRadius: 42,
          overflow: 'hidden', background: bg, position: 'relative',
          fontFamily: "'Inter', system-ui, sans-serif",
        }}>
          {/* Status bar */}
          <div style={{
            height: 44, padding: '16px 28px 0', display: 'flex',
            justifyContent: 'space-between', alignItems: 'flex-start',
            fontFamily: "'Inter', system-ui", fontSize: 15, fontWeight: 600,
            color: theme === 'dark' ? '#fafafa' : '#18181b', position: 'relative', zIndex: 20,
          }}>
            <span>9:41</span>
            {/* Dynamic-island-ish notch */}
            <div style={{
              position: 'absolute', top: 11, left: '50%', transform: 'translateX(-50%)',
              width: 118, height: 34, borderRadius: 20, background: '#000',
            }} />
            <div style={{ display: 'flex', gap: 5, alignItems: 'center', marginTop: 2 }}>
              {/* Signal bars */}
              <svg width="17" height="11" viewBox="0 0 17 11"><g fill="currentColor"><rect x="0" y="7" width="3" height="4" rx="0.5" /><rect x="4.5" y="5" width="3" height="6" rx="0.5" /><rect x="9" y="2.5" width="3" height="8.5" rx="0.5" /><rect x="13.5" y="0" width="3" height="11" rx="0.5" /></g></svg>
              {/* Battery */}
              <svg width="26" height="12" viewBox="0 0 26 12"><rect x="0.5" y="0.5" width="22" height="11" rx="2.5" stroke="currentColor" fill="none" opacity="0.4" /><rect x="2" y="2" width="19" height="8" rx="1.5" fill="currentColor" /><rect x="23" y="4" width="2" height="4" rx="1" fill="currentColor" opacity="0.6" /></svg>
            </div>
          </div>
          {children}
        </div>
      </div>
      {label && <div style={{ marginTop: 16, fontSize: 13, fontWeight: 500, color: 'rgba(60,50,40,0.65)' }}>{label}</div>}
    </div>
  );
};

// ─── Decorative plant thumbnail — a set of distinct SVG "photos" ───
const plantThumbs = {
  monstera: ({ size = 100 }) => (
    <svg viewBox="0 0 100 100" width={size} height={size}>
      <defs><linearGradient id="mg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#5aac83" /><stop offset="1" stopColor="#264e3b" /></linearGradient></defs>
      <rect width="100" height="100" fill="url(#mg)" />
      <g fill="#86bb9d" opacity="0.9">
        <path d="M50 85 Q30 70 25 50 Q22 32 38 22 Q50 16 62 22 Q78 32 75 50 Q70 70 50 85 Z" fill="#3D7A5F" />
        <path d="M44 36 L44 28 M54 34 L60 26 M38 50 L30 50 M62 50 L70 48 M44 66 L38 72 M56 66 L62 72" stroke="#1e3e30" strokeWidth="1.5" />
        <circle cx="44" cy="32" r="1.8" fill="#1e3e30" opacity="0.6" />
        <circle cx="56" cy="34" r="1.8" fill="#1e3e30" opacity="0.6" />
      </g>
      <rect x="38" y="74" width="24" height="18" rx="2" fill="#C26A3A" />
    </svg>
  ),
  pothos: ({ size = 100 }) => (
    <svg viewBox="0 0 100 100" width={size} height={size}>
      <rect width="100" height="100" fill="#f0f7f3" />
      <g>
        <path d="M20 15 Q35 40 20 65 Q25 80 45 75" stroke="#5aac83" strokeWidth="2" fill="none" />
        <path d="M80 20 Q65 45 85 70 Q80 82 55 72" stroke="#86bb9d" strokeWidth="2" fill="none" />
        <ellipse cx="25" cy="25" rx="7" ry="5" fill="#3D7A5F" transform="rotate(-30 25 25)" />
        <ellipse cx="23" cy="55" rx="8" ry="5.5" fill="#264e3b" transform="rotate(40 23 55)" />
        <ellipse cx="75" cy="30" rx="7" ry="5" fill="#5aac83" transform="rotate(30 75 30)" />
        <ellipse cx="78" cy="60" rx="8" ry="5.5" fill="#3D7A5F" transform="rotate(-40 78 60)" />
        <ellipse cx="48" cy="78" rx="10" ry="6" fill="#264e3b" />
      </g>
      <rect x="40" y="82" width="20" height="14" rx="1" fill="#834324" />
    </svg>
  ),
  snake: ({ size = 100 }) => (
    <svg viewBox="0 0 100 100" width={size} height={size}>
      <rect width="100" height="100" fill="#fdf5ef" />
      <g>
        <path d="M50 82 Q48 55 45 25 Q44 18 48 18 Q52 18 51 30 Q50 55 52 82 Z" fill="#3D7A5F" />
        <path d="M50 82 Q58 60 62 30 Q63 20 59 20 Q55 22 55 35 Q53 60 52 82 Z" fill="#264e3b" />
        <path d="M50 82 Q40 62 36 32 Q35 22 40 22 Q44 24 44 36 Q46 60 48 82 Z" fill="#5aac83" />
        <path d="M47 28 L48 22 M51 34 L53 28 M38 36 L36 30 M60 38 L62 32" stroke="#fef4a8" strokeWidth="0.8" opacity="0.8" />
      </g>
      <rect x="36" y="80" width="28" height="16" rx="2" fill="#C26A3A" />
    </svg>
  ),
  fiddle: ({ size = 100 }) => (
    <svg viewBox="0 0 100 100" width={size} height={size}>
      <rect width="100" height="100" fill="#fbe8d7" />
      <g fill="#264e3b">
        <ellipse cx="35" cy="28" rx="10" ry="14" />
        <ellipse cx="62" cy="22" rx="11" ry="15" />
        <ellipse cx="30" cy="50" rx="12" ry="15" />
        <ellipse cx="66" cy="48" rx="10" ry="13" />
        <ellipse cx="45" cy="68" rx="11" ry="13" />
      </g>
      <path d="M50 80 L50 20" stroke="#1e3e30" strokeWidth="2" />
      <rect x="38" y="80" width="24" height="16" rx="1" fill="#834324" />
    </svg>
  ),
  fern: ({ size = 100 }) => (
    <svg viewBox="0 0 100 100" width={size} height={size}>
      <rect width="100" height="100" fill="#d9ebe0" />
      <g stroke="#264e3b" strokeWidth="1.2" fill="#3D7A5F">
        <path d="M50 80 Q48 60 30 40 M50 80 Q52 60 70 40 M50 80 Q45 55 25 50 M50 80 Q55 55 75 50 M50 80 Q50 45 35 25 M50 80 Q50 45 65 25 M50 80 Q50 55 50 20" fill="none" strokeWidth="1.5" />
        {Array.from({ length: 12 }, (_, i) => (
          <ellipse key={i} cx={50 + (i % 2 ? 1 : -1) * (6 + i * 0.3)} cy={70 - i * 4} rx="4" ry="2" transform={`rotate(${(i % 2 ? -1 : 1) * 45} ${50} ${70 - i * 4})`} />
        ))}
      </g>
      <rect x="40" y="82" width="20" height="14" rx="1" fill="#C26A3A" />
    </svg>
  ),
  succulent: ({ size = 100 }) => (
    <svg viewBox="0 0 100 100" width={size} height={size}>
      <rect width="100" height="100" fill="#f0f7f3" />
      <g>
        <circle cx="50" cy="55" r="24" fill="#86bb9d" />
        {Array.from({ length: 8 }, (_, i) => {
          const a = (i / 8) * Math.PI * 2;
          return <ellipse key={i} cx={50 + Math.cos(a) * 14} cy={55 + Math.sin(a) * 14} rx="9" ry="5" transform={`rotate(${(a * 180 / Math.PI) + 90} ${50 + Math.cos(a) * 14} ${55 + Math.sin(a) * 14})`} fill="#3D7A5F" stroke="#264e3b" strokeWidth="0.5" />;
        })}
        <circle cx="50" cy="55" r="8" fill="#5aac83" />
      </g>
      <rect x="32" y="78" width="36" height="16" rx="2" fill="#a25529" />
    </svg>
  ),
  calathea: ({ size = 100 }) => (
    <svg viewBox="0 0 100 100" width={size} height={size}>
      <rect width="100" height="100" fill="#264e3b" />
      <g>
        <ellipse cx="30" cy="40" rx="10" ry="22" fill="#3D7A5F" transform="rotate(-30 30 40)" />
        <ellipse cx="70" cy="40" rx="10" ry="22" fill="#3D7A5F" transform="rotate(30 70 40)" />
        <ellipse cx="50" cy="35" rx="10" ry="24" fill="#5aac83" />
        <ellipse cx="50" cy="35" rx="5" ry="20" fill="#86bb9d" opacity="0.6" />
        <path d="M50 55 Q45 45 42 30 M50 55 Q55 45 58 30" stroke="#1e3e30" strokeWidth="0.8" fill="none" />
      </g>
      <rect x="38" y="74" width="24" height="20" rx="2" fill="#C26A3A" />
    </svg>
  ),
  cactus: ({ size = 100 }) => (
    <svg viewBox="0 0 100 100" width={size} height={size}>
      <rect width="100" height="100" fill="#fdf5ef" />
      <g fill="#3D7A5F">
        <rect x="42" y="30" width="16" height="50" rx="6" />
        <rect x="30" y="45" width="10" height="28" rx="4" />
        <rect x="60" y="40" width="10" height="32" rx="4" />
      </g>
      <g stroke="#264e3b" strokeWidth="0.6">
        {Array.from({ length: 10 }, (_, i) => <line key={i} x1={44 + (i % 3) * 5} y1={35 + i * 4} x2={44 + (i % 3) * 5} y2={37 + i * 4} />)}
      </g>
      <circle cx="50" cy="32" r="4" fill="#e58255" />
      <rect x="36" y="78" width="28" height="18" rx="2" fill="#834324" />
    </svg>
  ),
};

Object.assign(window, { Icon, PhoneFrame, plantThumbs });
