import 'dart:math' as math;

import '../prayer/calculation_params.dart';

/// The smallest unit the picker offers — a zone or neighbourhood inside a
/// city, used where a city is large enough that the coordinate matters.
class CatalogArea {
  const CatalogArea(this.name, this.latitude, this.longitude);

  final String name;
  final double latitude;
  final double longitude;
}

/// A district or city.
class CatalogDistrict {
  const CatalogDistrict(
    this.name,
    this.latitude,
    this.longitude, {
    this.areas = const [],
  });

  final String name;
  final double latitude;
  final double longitude;
  final List<CatalogArea> areas;
}

/// A division, state or province.
class CatalogDivision {
  const CatalogDivision(this.name, this.districts);

  final String name;
  final List<CatalogDistrict> districts;
}

/// One country, together with the prayer-time conventions that apply there.
///
/// [defaultMethod] is what the country's own religious authority publishes, so
/// picking a location is enough to get locally correct times without the user
/// having to know what an Isha angle is. [standardUtcOffsetMinutes] is the
/// country's *standard* (non-DST) offset — see
/// `PrayerLocation.utcOffsetMinutes` for how that is reconciled with the
/// device's own clock.
class CatalogCountry {
  const CatalogCountry({
    required this.code,
    required this.name,
    required this.defaultMethod,
    required this.standardUtcOffsetMinutes,
    required this.divisions,
  });

  final String code;
  final String name;
  final CalculationMethod defaultMethod;
  final int standardUtcOffsetMinutes;
  final List<CatalogDivision> divisions;
}

/// A single resolved place, flattened out of the country/division/district
/// tree — what the nearest-match search returns and what the UI stores.
class CatalogPlace {
  const CatalogPlace({
    required this.country,
    required this.division,
    required this.district,
    this.area,
    required this.latitude,
    required this.longitude,
  });

  final CatalogCountry country;
  final CatalogDivision division;
  final CatalogDistrict district;
  final CatalogArea? area;
  final double latitude;
  final double longitude;
}

/// The app's offline place list.
///
/// Deliberately bundled rather than fetched: prayer times have to keep working
/// on a phone that has been offline for a month, and a reverse-geocoding call
/// would also send the user's coordinates to a third party for no benefit the
/// user asked for. GPS still gives an exact coordinate — the catalogue is only
/// used to put a *name* on it and to pick the local calculation method.
class LocationCatalog {
  LocationCatalog._();

  static const List<CatalogCountry> countries = [
    CatalogCountry(
      code: 'BD',
      name: 'Bangladesh',
      defaultMethod: CalculationMethod.bangladesh,
      standardUtcOffsetMinutes: 360,
      divisions: [
        CatalogDivision('Barishal', [
          CatalogDistrict('Barguna', 22.1500, 90.1167),
          CatalogDistrict('Barishal', 22.7010, 90.3535),
          CatalogDistrict('Bhola', 22.6859, 90.6482),
          CatalogDistrict('Jhalokati', 22.6406, 90.1987),
          CatalogDistrict('Patuakhali', 22.3596, 90.3299),
          CatalogDistrict('Pirojpur', 22.5841, 89.9720),
        ]),
        CatalogDivision('Chattogram', [
          CatalogDistrict('Bandarban', 22.1953, 92.2184),
          CatalogDistrict('Brahmanbaria', 23.9571, 91.1115),
          CatalogDistrict('Chandpur', 23.2333, 90.6712),
          CatalogDistrict('Chattogram', 22.3569, 91.7832, areas: [
            CatalogArea('Agrabad', 22.3269, 91.8123),
            CatalogArea('Pahartali', 22.3711, 91.7896),
            CatalogArea('Patenga', 22.2380, 91.7960),
            CatalogArea('Chandgaon', 22.3639, 91.8380),
          ]),
          CatalogDistrict('Cumilla', 23.4607, 91.1809),
          CatalogDistrict("Cox's Bazar", 21.4272, 92.0058),
          CatalogDistrict('Feni', 23.0159, 91.3976),
          CatalogDistrict('Khagrachhari', 23.1193, 91.9847),
          CatalogDistrict('Lakshmipur', 22.9447, 90.8282),
          CatalogDistrict('Noakhali', 22.8696, 91.0995),
          CatalogDistrict('Rangamati', 22.6533, 92.1746),
        ]),
        CatalogDivision('Dhaka', [
          CatalogDistrict('Dhaka', 23.8103, 90.4125, areas: [
            CatalogArea('Mirpur', 23.8223, 90.3654),
            CatalogArea('Uttara', 23.8759, 90.3795),
            CatalogArea('Gulshan', 23.7925, 90.4078),
            CatalogArea('Dhanmondi', 23.7461, 90.3742),
            CatalogArea('Mohammadpur', 23.7590, 90.3596),
            CatalogArea('Motijheel', 23.7330, 90.4172),
            CatalogArea('Badda', 23.7806, 90.4258),
            CatalogArea('Jatrabari', 23.7104, 90.4340),
            CatalogArea('Savar', 23.8583, 90.2667),
            CatalogArea('Keraniganj', 23.7000, 90.3833),
          ]),
          CatalogDistrict('Faridpur', 23.6070, 89.8429),
          CatalogDistrict('Gazipur', 23.9999, 90.4203),
          CatalogDistrict('Gopalganj', 23.0050, 89.8266),
          CatalogDistrict('Kishoreganj', 24.4449, 90.7766),
          CatalogDistrict('Madaripur', 23.1641, 90.1897),
          CatalogDistrict('Manikganj', 23.8617, 90.0003),
          CatalogDistrict('Munshiganj', 23.5422, 90.5305),
          CatalogDistrict('Narayanganj', 23.6238, 90.5000),
          CatalogDistrict('Narsingdi', 23.9322, 90.7151),
          CatalogDistrict('Rajbari', 23.7574, 89.6444),
          CatalogDistrict('Shariatpur', 23.2423, 90.4348),
          CatalogDistrict('Tangail', 24.2513, 89.9167),
        ]),
        CatalogDivision('Khulna', [
          CatalogDistrict('Bagerhat', 22.6516, 89.7859),
          CatalogDistrict('Chuadanga', 23.6402, 88.8411),
          CatalogDistrict('Jashore', 23.1697, 89.2137),
          CatalogDistrict('Jhenaidah', 23.5450, 89.1726),
          CatalogDistrict('Khulna', 22.8456, 89.5403),
          CatalogDistrict('Kushtia', 23.9013, 89.1206),
          CatalogDistrict('Magura', 23.4855, 89.4198),
          CatalogDistrict('Meherpur', 23.7622, 88.6318),
          CatalogDistrict('Narail', 23.1725, 89.5127),
          CatalogDistrict('Satkhira', 22.7185, 89.0705),
        ]),
        CatalogDivision('Mymensingh', [
          CatalogDistrict('Jamalpur', 24.9375, 89.9372),
          CatalogDistrict('Mymensingh', 24.7471, 90.4203),
          CatalogDistrict('Netrokona', 24.8103, 90.8695),
          CatalogDistrict('Sherpur', 25.0205, 90.0153),
        ]),
        CatalogDivision('Rajshahi', [
          CatalogDistrict('Bogura', 24.8465, 89.3776),
          CatalogDistrict('Chapai Nawabganj', 24.5965, 88.2775),
          CatalogDistrict('Joypurhat', 25.0968, 89.0227),
          CatalogDistrict('Naogaon', 24.7936, 88.9318),
          CatalogDistrict('Natore', 24.4206, 89.0003),
          CatalogDistrict('Pabna', 24.0064, 89.2372),
          CatalogDistrict('Rajshahi', 24.3745, 88.6042),
          CatalogDistrict('Sirajganj', 24.4533, 89.7006),
        ]),
        CatalogDivision('Rangpur', [
          CatalogDistrict('Dinajpur', 25.6217, 88.6354),
          CatalogDistrict('Gaibandha', 25.3288, 89.5281),
          CatalogDistrict('Kurigram', 25.8054, 89.6362),
          CatalogDistrict('Lalmonirhat', 25.9923, 89.2847),
          CatalogDistrict('Nilphamari', 25.9317, 88.8560),
          CatalogDistrict('Panchagarh', 26.3411, 88.5542),
          CatalogDistrict('Rangpur', 25.7439, 89.2752),
          CatalogDistrict('Thakurgaon', 26.0418, 88.4616),
        ]),
        CatalogDivision('Sylhet', [
          CatalogDistrict('Habiganj', 24.3745, 91.4155),
          CatalogDistrict('Moulvibazar', 24.4829, 91.7774),
          CatalogDistrict('Sunamganj', 25.0658, 91.3950),
          CatalogDistrict('Sylhet', 24.8949, 91.8687),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'SA',
      name: 'Saudi Arabia',
      defaultMethod: CalculationMethod.ummAlQura,
      standardUtcOffsetMinutes: 180,
      divisions: [
        CatalogDivision('Makkah Region', [
          CatalogDistrict('Makkah', 21.4225, 39.8262),
          CatalogDistrict('Jeddah', 21.4858, 39.1925),
          CatalogDistrict('Taif', 21.2703, 40.4158),
        ]),
        CatalogDivision('Madinah Region', [
          CatalogDistrict('Madinah', 24.5247, 39.5692),
          CatalogDistrict('Yanbu', 24.0895, 38.0618),
        ]),
        CatalogDivision('Riyadh Region', [
          CatalogDistrict('Riyadh', 24.7136, 46.6753),
          CatalogDistrict('Al Kharj', 24.1483, 47.3050),
        ]),
        CatalogDivision('Eastern Province', [
          CatalogDistrict('Dammam', 26.4207, 50.0888),
          CatalogDistrict('Al Khobar', 26.2794, 50.2083),
          CatalogDistrict('Hofuf', 25.3646, 49.5876),
        ]),
        CatalogDivision('Asir', [
          CatalogDistrict('Abha', 18.2164, 42.5053),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'IN',
      name: 'India',
      defaultMethod: CalculationMethod.karachi,
      standardUtcOffsetMinutes: 330,
      divisions: [
        CatalogDivision('Delhi', [
          CatalogDistrict('New Delhi', 28.6139, 77.2090),
        ]),
        CatalogDivision('Maharashtra', [
          CatalogDistrict('Mumbai', 19.0760, 72.8777),
          CatalogDistrict('Pune', 18.5204, 73.8567),
          CatalogDistrict('Nagpur', 21.1458, 79.0882),
        ]),
        CatalogDivision('West Bengal', [
          CatalogDistrict('Kolkata', 22.5726, 88.3639),
          CatalogDistrict('Siliguri', 26.7271, 88.3953),
        ]),
        CatalogDivision('Uttar Pradesh', [
          CatalogDistrict('Lucknow', 26.8467, 80.9462),
          CatalogDistrict('Varanasi', 25.3176, 82.9739),
          CatalogDistrict('Aligarh', 27.8974, 78.0880),
        ]),
        CatalogDivision('Telangana', [
          CatalogDistrict('Hyderabad', 17.3850, 78.4867),
        ]),
        CatalogDivision('Tamil Nadu', [
          CatalogDistrict('Chennai', 13.0827, 80.2707),
        ]),
        CatalogDivision('Karnataka', [
          CatalogDistrict('Bengaluru', 12.9716, 77.5946),
        ]),
        CatalogDivision('Kerala', [
          CatalogDistrict('Kochi', 9.9312, 76.2673),
          CatalogDistrict('Kozhikode', 11.2588, 75.7804),
        ]),
        CatalogDivision('Gujarat', [
          CatalogDistrict('Ahmedabad', 23.0225, 72.5714),
          CatalogDistrict('Surat', 21.1702, 72.8311),
        ]),
        CatalogDivision('Assam', [
          CatalogDistrict('Guwahati', 26.1445, 91.7362),
        ]),
        CatalogDivision('Jammu and Kashmir', [
          CatalogDistrict('Srinagar', 34.0837, 74.7973),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'PK',
      name: 'Pakistan',
      defaultMethod: CalculationMethod.karachi,
      standardUtcOffsetMinutes: 300,
      divisions: [
        CatalogDivision('Punjab', [
          CatalogDistrict('Lahore', 31.5204, 74.3587),
          CatalogDistrict('Faisalabad', 31.4504, 73.1350),
          CatalogDistrict('Rawalpindi', 33.5651, 73.0169),
          CatalogDistrict('Multan', 30.1575, 71.5249),
        ]),
        CatalogDivision('Sindh', [
          CatalogDistrict('Karachi', 24.8607, 67.0011),
          CatalogDistrict('Hyderabad', 25.3960, 68.3578),
        ]),
        CatalogDivision('Khyber Pakhtunkhwa', [
          CatalogDistrict('Peshawar', 34.0151, 71.5249),
        ]),
        CatalogDivision('Balochistan', [
          CatalogDistrict('Quetta', 30.1798, 66.9750),
        ]),
        CatalogDivision('Islamabad Capital Territory', [
          CatalogDistrict('Islamabad', 33.6844, 73.0479),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'ID',
      name: 'Indonesia',
      defaultMethod: CalculationMethod.singapore,
      standardUtcOffsetMinutes: 420,
      divisions: [
        CatalogDivision('Jakarta', [
          CatalogDistrict('Jakarta', -6.2088, 106.8456),
        ]),
        CatalogDivision('West Java', [
          CatalogDistrict('Bandung', -6.9175, 107.6191),
          CatalogDistrict('Bogor', -6.5971, 106.8060),
        ]),
        CatalogDivision('East Java', [
          CatalogDistrict('Surabaya', -7.2575, 112.7521),
          CatalogDistrict('Malang', -7.9666, 112.6326),
        ]),
        CatalogDivision('Central Java', [
          CatalogDistrict('Semarang', -6.9667, 110.4167),
          CatalogDistrict('Yogyakarta', -7.7956, 110.3695),
        ]),
        CatalogDivision('North Sumatra', [
          CatalogDistrict('Medan', 3.5952, 98.6722),
        ]),
        CatalogDivision('Aceh', [
          CatalogDistrict('Banda Aceh', 5.5483, 95.3238),
        ]),
        CatalogDivision('South Sulawesi', [
          CatalogDistrict('Makassar', -5.1477, 119.4327),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'MY',
      name: 'Malaysia',
      defaultMethod: CalculationMethod.singapore,
      standardUtcOffsetMinutes: 480,
      divisions: [
        CatalogDivision('Kuala Lumpur', [
          CatalogDistrict('Kuala Lumpur', 3.1390, 101.6869),
        ]),
        CatalogDivision('Selangor', [
          CatalogDistrict('Shah Alam', 3.0733, 101.5185),
          CatalogDistrict('Petaling Jaya', 3.1073, 101.6067),
        ]),
        CatalogDivision('Penang', [
          CatalogDistrict('George Town', 5.4141, 100.3288),
        ]),
        CatalogDivision('Johor', [
          CatalogDistrict('Johor Bahru', 1.4927, 103.7414),
        ]),
        CatalogDivision('Sabah', [
          CatalogDistrict('Kota Kinabalu', 5.9804, 116.0735),
        ]),
        CatalogDivision('Sarawak', [
          CatalogDistrict('Kuching', 1.5533, 110.3592),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'AE',
      name: 'United Arab Emirates',
      defaultMethod: CalculationMethod.dubai,
      standardUtcOffsetMinutes: 240,
      divisions: [
        CatalogDivision('Abu Dhabi', [
          CatalogDistrict('Abu Dhabi', 24.4539, 54.3773),
          CatalogDistrict('Al Ain', 24.1302, 55.8023),
        ]),
        CatalogDivision('Dubai', [
          CatalogDistrict('Dubai', 25.2048, 55.2708),
        ]),
        CatalogDivision('Sharjah', [
          CatalogDistrict('Sharjah', 25.3463, 55.4209),
        ]),
        CatalogDivision('Ajman', [
          CatalogDistrict('Ajman', 25.4052, 55.5136),
        ]),
        CatalogDivision('Ras Al Khaimah', [
          CatalogDistrict('Ras Al Khaimah', 25.7895, 55.9432),
        ]),
        CatalogDivision('Fujairah', [
          CatalogDistrict('Fujairah', 25.1288, 56.3265),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'QA',
      name: 'Qatar',
      defaultMethod: CalculationMethod.qatar,
      standardUtcOffsetMinutes: 180,
      divisions: [
        CatalogDivision('Doha', [
          CatalogDistrict('Doha', 25.2854, 51.5310),
        ]),
        CatalogDivision('Al Rayyan', [
          CatalogDistrict('Al Rayyan', 25.2919, 51.4244),
        ]),
        CatalogDivision('Al Wakrah', [
          CatalogDistrict('Al Wakrah', 25.1659, 51.5985),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'KW',
      name: 'Kuwait',
      defaultMethod: CalculationMethod.kuwait,
      standardUtcOffsetMinutes: 180,
      divisions: [
        CatalogDivision('Al Asimah', [
          CatalogDistrict('Kuwait City', 29.3759, 47.9774),
        ]),
        CatalogDivision('Hawalli', [
          CatalogDistrict('Hawalli', 29.3328, 48.0289),
        ]),
        CatalogDivision('Al Ahmadi', [
          CatalogDistrict('Al Ahmadi', 29.0769, 48.0838),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'OM',
      name: 'Oman',
      defaultMethod: CalculationMethod.ummAlQura,
      standardUtcOffsetMinutes: 240,
      divisions: [
        CatalogDivision('Muscat', [
          CatalogDistrict('Muscat', 23.5880, 58.3829),
        ]),
        CatalogDivision('Dhofar', [
          CatalogDistrict('Salalah', 17.0151, 54.0924),
        ]),
        CatalogDivision('North Al Batinah', [
          CatalogDistrict('Sohar', 24.3477, 56.7091),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'BH',
      name: 'Bahrain',
      defaultMethod: CalculationMethod.ummAlQura,
      standardUtcOffsetMinutes: 180,
      divisions: [
        CatalogDivision('Capital', [
          CatalogDistrict('Manama', 26.2285, 50.5860),
        ]),
        CatalogDivision('Southern', [
          CatalogDistrict('Riffa', 26.1300, 50.5550),
        ]),
        CatalogDivision('Muharraq', [
          CatalogDistrict('Muharraq', 26.2572, 50.6119),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'JO',
      name: 'Jordan',
      defaultMethod: CalculationMethod.karachi,
      standardUtcOffsetMinutes: 180,
      divisions: [
        CatalogDivision('Amman', [
          CatalogDistrict('Amman', 31.9454, 35.9284),
        ]),
        CatalogDivision('Zarqa', [
          CatalogDistrict('Zarqa', 32.0728, 36.0876),
        ]),
        CatalogDivision('Irbid', [
          CatalogDistrict('Irbid', 32.5556, 35.8500),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'EG',
      name: 'Egypt',
      defaultMethod: CalculationMethod.egyptian,
      standardUtcOffsetMinutes: 120,
      divisions: [
        CatalogDivision('Cairo', [
          CatalogDistrict('Cairo', 30.0444, 31.2357),
        ]),
        CatalogDivision('Giza', [
          CatalogDistrict('Giza', 30.0131, 31.2089),
        ]),
        CatalogDivision('Alexandria', [
          CatalogDistrict('Alexandria', 31.2001, 29.9187),
        ]),
        CatalogDivision('Luxor', [
          CatalogDistrict('Luxor', 25.6872, 32.6396),
        ]),
        CatalogDivision('Aswan', [
          CatalogDistrict('Aswan', 24.0889, 32.8998),
        ]),
        CatalogDivision('Port Said', [
          CatalogDistrict('Port Said', 31.2653, 32.3019),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'TR',
      name: 'Türkiye',
      defaultMethod: CalculationMethod.turkey,
      standardUtcOffsetMinutes: 180,
      divisions: [
        CatalogDivision('Istanbul', [
          CatalogDistrict('Istanbul', 41.0082, 28.9784),
        ]),
        CatalogDivision('Ankara', [
          CatalogDistrict('Ankara', 39.9334, 32.8597),
        ]),
        CatalogDivision('Izmir', [
          CatalogDistrict('Izmir', 38.4237, 27.1428),
        ]),
        CatalogDivision('Bursa', [
          CatalogDistrict('Bursa', 40.1826, 29.0665),
        ]),
        CatalogDivision('Antalya', [
          CatalogDistrict('Antalya', 36.8969, 30.7133),
        ]),
        CatalogDivision('Konya', [
          CatalogDistrict('Konya', 37.8746, 32.4932),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'IR',
      name: 'Iran',
      defaultMethod: CalculationMethod.tehran,
      standardUtcOffsetMinutes: 210,
      divisions: [
        CatalogDivision('Tehran', [
          CatalogDistrict('Tehran', 35.6892, 51.3890),
        ]),
        CatalogDivision('Razavi Khorasan', [
          CatalogDistrict('Mashhad', 36.2605, 59.6168),
        ]),
        CatalogDivision('Isfahan', [
          CatalogDistrict('Isfahan', 32.6546, 51.6680),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'IQ',
      name: 'Iraq',
      defaultMethod: CalculationMethod.karachi,
      standardUtcOffsetMinutes: 180,
      divisions: [
        CatalogDivision('Baghdad', [
          CatalogDistrict('Baghdad', 33.3152, 44.3661),
        ]),
        CatalogDivision('Basra', [
          CatalogDistrict('Basra', 30.5085, 47.7804),
        ]),
        CatalogDivision('Nineveh', [
          CatalogDistrict('Mosul', 36.3350, 43.1189),
        ]),
        CatalogDivision('Najaf', [
          CatalogDistrict('Najaf', 32.0000, 44.3350),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'AF',
      name: 'Afghanistan',
      defaultMethod: CalculationMethod.karachi,
      standardUtcOffsetMinutes: 270,
      divisions: [
        CatalogDivision('Kabul', [
          CatalogDistrict('Kabul', 34.5553, 69.2075),
        ]),
        CatalogDivision('Kandahar', [
          CatalogDistrict('Kandahar', 31.6289, 65.7372),
        ]),
        CatalogDivision('Herat', [
          CatalogDistrict('Herat', 34.3529, 62.2040),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'SG',
      name: 'Singapore',
      defaultMethod: CalculationMethod.singapore,
      standardUtcOffsetMinutes: 480,
      divisions: [
        CatalogDivision('Singapore', [
          CatalogDistrict('Singapore', 1.3521, 103.8198),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'GB',
      name: 'United Kingdom',
      defaultMethod: CalculationMethod.moonsightingCommittee,
      standardUtcOffsetMinutes: 0,
      divisions: [
        CatalogDivision('England', [
          CatalogDistrict('London', 51.5074, -0.1278),
          CatalogDistrict('Birmingham', 52.4862, -1.8904),
          CatalogDistrict('Manchester', 53.4808, -2.2426),
          CatalogDistrict('Leeds', 53.8008, -1.5491),
          CatalogDistrict('Bradford', 53.7960, -1.7594),
        ]),
        CatalogDivision('Scotland', [
          CatalogDistrict('Glasgow', 55.8642, -4.2518),
          CatalogDistrict('Edinburgh', 55.9533, -3.1883),
        ]),
        CatalogDivision('Wales', [
          CatalogDistrict('Cardiff', 51.4816, -3.1791),
        ]),
        CatalogDivision('Northern Ireland', [
          CatalogDistrict('Belfast', 54.5973, -5.9301),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'US',
      name: 'United States',
      defaultMethod: CalculationMethod.northAmerica,
      standardUtcOffsetMinutes: -300,
      divisions: [
        CatalogDivision('New York', [
          CatalogDistrict('New York City', 40.7128, -74.0060),
          CatalogDistrict('Buffalo', 42.8864, -78.8784),
        ]),
        CatalogDivision('California', [
          CatalogDistrict('Los Angeles', 34.0522, -118.2437),
          CatalogDistrict('San Francisco', 37.7749, -122.4194),
          CatalogDistrict('San Diego', 32.7157, -117.1611),
        ]),
        CatalogDivision('Texas', [
          CatalogDistrict('Houston', 29.7604, -95.3698),
          CatalogDistrict('Dallas', 32.7767, -96.7970),
        ]),
        CatalogDivision('Illinois', [
          CatalogDistrict('Chicago', 41.8781, -87.6298),
        ]),
        CatalogDivision('Michigan', [
          CatalogDistrict('Detroit', 42.3314, -83.0458),
          CatalogDistrict('Dearborn', 42.3223, -83.1763),
        ]),
        CatalogDivision('New Jersey', [
          CatalogDistrict('Newark', 40.7357, -74.1724),
        ]),
        CatalogDivision('Virginia', [
          CatalogDistrict('Fairfax', 38.8462, -77.3064),
        ]),
        CatalogDivision('Georgia', [
          CatalogDistrict('Atlanta', 33.7490, -84.3880),
        ]),
        CatalogDivision('Florida', [
          CatalogDistrict('Miami', 25.7617, -80.1918),
        ]),
        CatalogDivision('Minnesota', [
          CatalogDistrict('Minneapolis', 44.9778, -93.2650),
        ]),
        CatalogDivision('Ohio', [
          CatalogDistrict('Columbus', 39.9612, -82.9988),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'CA',
      name: 'Canada',
      defaultMethod: CalculationMethod.northAmerica,
      standardUtcOffsetMinutes: -300,
      divisions: [
        CatalogDivision('Ontario', [
          CatalogDistrict('Toronto', 43.6532, -79.3832),
          CatalogDistrict('Ottawa', 45.4215, -75.6972),
          CatalogDistrict('Mississauga', 43.5890, -79.6441),
        ]),
        CatalogDivision('Quebec', [
          CatalogDistrict('Montreal', 45.5017, -73.5673),
        ]),
        CatalogDivision('Alberta', [
          CatalogDistrict('Calgary', 51.0447, -114.0719),
          CatalogDistrict('Edmonton', 53.5461, -113.4938),
        ]),
        CatalogDivision('British Columbia', [
          CatalogDistrict('Vancouver', 49.2827, -123.1207),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'AU',
      name: 'Australia',
      defaultMethod: CalculationMethod.muslimWorldLeague,
      standardUtcOffsetMinutes: 600,
      divisions: [
        CatalogDivision('New South Wales', [
          CatalogDistrict('Sydney', -33.8688, 151.2093),
        ]),
        CatalogDivision('Victoria', [
          CatalogDistrict('Melbourne', -37.8136, 144.9631),
        ]),
        CatalogDivision('Queensland', [
          CatalogDistrict('Brisbane', -27.4698, 153.0251),
        ]),
        CatalogDivision('Western Australia', [
          CatalogDistrict('Perth', -31.9505, 115.8605),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'FR',
      name: 'France',
      defaultMethod: CalculationMethod.muslimWorldLeague,
      standardUtcOffsetMinutes: 60,
      divisions: [
        CatalogDivision('Île-de-France', [
          CatalogDistrict('Paris', 48.8566, 2.3522),
        ]),
        CatalogDivision("Provence-Alpes-Côte d'Azur", [
          CatalogDistrict('Marseille', 43.2965, 5.3698),
        ]),
        CatalogDivision('Auvergne-Rhône-Alpes', [
          CatalogDistrict('Lyon', 45.7640, 4.8357),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'DE',
      name: 'Germany',
      defaultMethod: CalculationMethod.muslimWorldLeague,
      standardUtcOffsetMinutes: 60,
      divisions: [
        CatalogDivision('Berlin', [
          CatalogDistrict('Berlin', 52.5200, 13.4050),
        ]),
        CatalogDivision('Hamburg', [
          CatalogDistrict('Hamburg', 53.5511, 9.9937),
        ]),
        CatalogDivision('Bavaria', [
          CatalogDistrict('Munich', 48.1351, 11.5820),
        ]),
        CatalogDivision('North Rhine-Westphalia', [
          CatalogDistrict('Cologne', 50.9375, 6.9603),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'MA',
      name: 'Morocco',
      defaultMethod: CalculationMethod.muslimWorldLeague,
      standardUtcOffsetMinutes: 60,
      divisions: [
        CatalogDivision('Casablanca-Settat', [
          CatalogDistrict('Casablanca', 33.5731, -7.5898),
        ]),
        CatalogDivision('Rabat-Salé-Kénitra', [
          CatalogDistrict('Rabat', 34.0209, -6.8416),
        ]),
        CatalogDivision('Marrakesh-Safi', [
          CatalogDistrict('Marrakesh', 31.6295, -7.9811),
        ]),
        CatalogDivision('Fès-Meknès', [
          CatalogDistrict('Fez', 34.0181, -5.0078),
        ]),
        CatalogDivision('Tanger-Tétouan-Al Hoceïma', [
          CatalogDistrict('Tangier', 35.7595, -5.8340),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'NG',
      name: 'Nigeria',
      defaultMethod: CalculationMethod.muslimWorldLeague,
      standardUtcOffsetMinutes: 60,
      divisions: [
        CatalogDivision('Lagos', [
          CatalogDistrict('Lagos', 6.5244, 3.3792),
        ]),
        CatalogDivision('Kano', [
          CatalogDistrict('Kano', 12.0022, 8.5920),
        ]),
        CatalogDivision('Federal Capital Territory', [
          CatalogDistrict('Abuja', 9.0765, 7.3986),
        ]),
        CatalogDivision('Oyo', [
          CatalogDistrict('Ibadan', 7.3775, 3.9470),
        ]),
      ],
    ),
    CatalogCountry(
      code: 'ZA',
      name: 'South Africa',
      defaultMethod: CalculationMethod.muslimWorldLeague,
      standardUtcOffsetMinutes: 120,
      divisions: [
        CatalogDivision('Gauteng', [
          CatalogDistrict('Johannesburg', -26.2041, 28.0473),
        ]),
        CatalogDivision('Western Cape', [
          CatalogDistrict('Cape Town', -33.9249, 18.4241),
        ]),
        CatalogDivision('KwaZulu-Natal', [
          CatalogDistrict('Durban', -29.8587, 31.0218),
        ]),
      ],
    ),
  ];

  static CatalogCountry? countryByCode(String? code) {
    if (code == null) return null;
    for (final country in countries) {
      if (country.code == code) return country;
    }
    return null;
  }

  static CatalogDivision? divisionByName(CatalogCountry? country, String? name) {
    if (country == null || name == null) return null;
    for (final division in country.divisions) {
      if (division.name == name) return division;
    }
    return null;
  }

  static CatalogDistrict? districtByName(
      CatalogDivision? division, String? name) {
    if (division == null || name == null) return null;
    for (final district in division.districts) {
      if (district.name == name) return district;
    }
    return null;
  }

  static CatalogArea? areaByName(CatalogDistrict? district, String? name) {
    if (district == null || name == null) return null;
    for (final area in district.areas) {
      if (area.name == name) return area;
    }
    return null;
  }

  /// Every place in the catalogue, as a flat list.
  ///
  /// A district with named areas contributes each area *and* the district
  /// itself, so a GPS fix in a city fringe still resolves to the city rather
  /// than to whichever neighbourhood happens to be listed.
  static List<CatalogPlace> get allPlaces {
    final places = <CatalogPlace>[];
    for (final country in countries) {
      for (final division in country.divisions) {
        for (final district in division.districts) {
          places.add(CatalogPlace(
            country: country,
            division: division,
            district: district,
            latitude: district.latitude,
            longitude: district.longitude,
          ));
          for (final area in district.areas) {
            places.add(CatalogPlace(
              country: country,
              division: division,
              district: district,
              area: area,
              latitude: area.latitude,
              longitude: area.longitude,
            ));
          }
        }
      }
    }
    return places;
  }

  /// The catalogue entry closest to [latitude]/[longitude].
  ///
  /// Returns `null` when nothing is within [maxDistanceKm] — a GPS fix in a
  /// country the catalogue does not cover keeps its exact coordinate and is
  /// simply shown without a place name, which is more honest than labelling
  /// someone in Almaty as being in Karachi.
  static CatalogPlace? nearest(
    double latitude,
    double longitude, {
    double maxDistanceKm = 150,
  }) {
    CatalogPlace? best;
    var bestDistance = double.infinity;
    for (final place in allPlaces) {
      final distance = distanceKm(
        latitude,
        longitude,
        place.latitude,
        place.longitude,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = place;
      }
    }
    return bestDistance <= maxDistanceKm ? best : null;
  }

  /// Places whose country, division, district or area name contains [query].
  static List<CatalogPlace> search(String query, {int limit = 40}) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final matches = <CatalogPlace>[];
    for (final place in allPlaces) {
      final haystack = [
        place.area?.name,
        place.district.name,
        place.division.name,
        place.country.name,
      ].whereType<String>().join(' ').toLowerCase();
      if (haystack.contains(needle)) {
        matches.add(place);
        if (matches.length >= limit) break;
      }
    }
    return matches;
  }

  /// Great-circle distance in kilometres (haversine).
  static double distanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
