import 'package:flutter/material.dart';

/// Mock plant fixtures — mirror the `plants` object in
/// `web/prototype/components/screens.jsx` (PlantDetail.plants).
/// Replaced by Drift-backed repositories in Phase 1 proper.
class MockPlant {
  const MockPlant({
    required this.id,
    required this.name,
    required this.latin,
    required this.location,
    required this.acquired,
    required this.tags,
    required this.swatch,
    this.overdue = false,
  });

  final String id;
  final String name;
  final String latin;
  final String location;
  final String acquired;
  final List<String> tags;
  final Color swatch;
  final bool overdue;
}

class MockPlants {
  MockPlants._();

  static const monsteraBob = MockPlant(
    id: 'bob',
    name: 'Monstera "Bob"',
    latin: 'Monstera deliciosa',
    location: 'Living room › South window',
    acquired: '2024-03-12 · from Mom',
    tags: ['variegated', 'climber'],
    swatch: Color(0xFF264E3B),
    overdue: true,
  );

  static const pothosGreen = MockPlant(
    id: 'green',
    name: 'Pothos "Green"',
    latin: 'Epipremnum aureum',
    location: 'Kitchen shelf',
    acquired: '2024-06-01 · bought',
    tags: ['trailing'],
    swatch: Color(0xFFF0F7F3),
    overdue: true,
  );

  static const snake = MockPlant(
    id: 'snake',
    name: 'Snake plant',
    latin: 'Dracaena trifasciata',
    location: 'Bedroom · east window',
    acquired: '2023-09-20',
    tags: ['low-light'],
    swatch: Color(0xFFFDF5EF),
  );

  static const calathea = MockPlant(
    id: 'cala',
    name: 'Calathea',
    latin: 'Goeppertia orbifolia',
    location: 'Bookcase',
    acquired: '2025-01-10',
    tags: ['humid-loving'],
    swatch: Color(0xFF264E3B),
  );

  static const fiddle = MockPlant(
    id: 'fid',
    name: 'Fiddle fig',
    latin: 'Ficus lyrata',
    location: 'Living room',
    acquired: '2024-05-15',
    tags: ['tree'],
    swatch: Color(0xFFFBE8D7),
  );

  static const fern = MockPlant(
    id: 'fern',
    name: 'Fern spray',
    latin: 'Nephrolepis exaltata',
    location: 'Bathroom',
    acquired: '2023-11-02',
    tags: [],
    swatch: Color(0xFFD9EBE0),
  );

  static const succulent = MockPlant(
    id: 'suc',
    name: 'Hens & chicks',
    latin: 'Sempervivum',
    location: 'South window',
    acquired: '2023-04-01',
    tags: ['drought-ok'],
    swatch: Color(0xFFF0F7F3),
  );

  static const cactus = MockPlant(
    id: 'pete',
    name: 'Prickly Pete',
    latin: 'Opuntia microdasys',
    location: 'Balcony',
    acquired: '2024-02-14',
    tags: ['outdoor'],
    swatch: Color(0xFFFDF5EF),
  );

  static const all = <MockPlant>[
    monsteraBob,
    pothosGreen,
    snake,
    calathea,
    fiddle,
    fern,
    succulent,
    cactus,
  ];

  static MockPlant byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => monsteraBob);
}
