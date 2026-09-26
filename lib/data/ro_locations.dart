/// Romanian administrative + listing vocab for the plantly.ro export dialog.
///
/// The 42 județe (counties, incl. București) are a stable, official set, so
/// they're hard-coded here rather than fetched. Cities are left as free text —
/// the ~3200 localities are too many to bundle usefully, and plantly.ro's own
/// locality list is the eventual source of truth (see issue #7).
///
/// [exportCategories] is the category vocabulary of the *local* export form,
/// i.e. whenever `PlantlyFeatures.sellEnabled` is off (the default build). With
/// selling on, the dialog searches plantly.ro's real categories instead
/// (`GET /categories/search`) and this list is not used.
library;

/// The 42 Romanian counties (județe), including București, alphabetical by the
/// Romanian collation as commonly listed.
const List<String> roCounties = [
  'Alba',
  'Arad',
  'Argeș',
  'Bacău',
  'Bihor',
  'Bistrița-Năsăud',
  'Botoșani',
  'Brașov',
  'Brăila',
  'București',
  'Buzău',
  'Caraș-Severin',
  'Călărași',
  'Cluj',
  'Constanța',
  'Covasna',
  'Dâmbovița',
  'Dolj',
  'Galați',
  'Giurgiu',
  'Gorj',
  'Harghita',
  'Hunedoara',
  'Ialomița',
  'Iași',
  'Ilfov',
  'Maramureș',
  'Mehedinți',
  'Mureș',
  'Neamț',
  'Olt',
  'Prahova',
  'Satu Mare',
  'Sălaj',
  'Sibiu',
  'Suceava',
  'Teleorman',
  'Timiș',
  'Tulcea',
  'Vaslui',
  'Vâlcea',
  'Vrancea',
];

/// Listing categories for the local (selling-off) export form — see the
/// library note. Not used when selling is enabled.
const List<String> exportCategories = [
  'Indoor plant',
  'Outdoor plant',
  'Succulent / Cactus',
  'Herb',
  'Seedling / Cutting',
  'Tree / Shrub',
  'Other',
];
