import '../models/location.dart';

const majorCities = [
  LocationValue(
    code: 'tokyo',
    latitude: 35.6812,
    longitude: 139.7671,
    regionName: '東京',
  ),
  LocationValue(
    code: 'osaka',
    latitude: 34.6937,
    longitude: 135.5023,
    regionName: '大阪',
  ),
  LocationValue(
    code: 'nagoya',
    latitude: 35.1815,
    longitude: 136.9066,
    regionName: '名古屋',
  ),
  LocationValue(
    code: 'fukuoka',
    latitude: 33.5904,
    longitude: 130.4017,
    regionName: '福岡',
  ),
  LocationValue(
    code: 'sapporo',
    latitude: 43.0618,
    longitude: 141.3545,
    regionName: '札幌',
  ),
  LocationValue(
    code: 'sendai',
    latitude: 38.2682,
    longitude: 140.8694,
    regionName: '仙台',
  ),
  LocationValue(
    code: 'yokohama',
    latitude: 35.4437,
    longitude: 139.6380,
    regionName: '横浜',
  ),
  LocationValue(
    code: 'kyoto',
    latitude: 35.0116,
    longitude: 135.7681,
    regionName: '京都',
  ),
  LocationValue(
    code: 'hiroshima',
    latitude: 34.3853,
    longitude: 132.4553,
    regionName: '広島',
  ),
  LocationValue(
    code: 'naha',
    latitude: 26.2124,
    longitude: 127.6809,
    regionName: '那覇',
  ),
  LocationValue(
    code: 'niigata',
    latitude: 37.9161,
    longitude: 139.0364,
    regionName: '新潟',
  ),
  LocationValue(
    code: 'kanazawa',
    latitude: 36.5613,
    longitude: 136.6562,
    regionName: '金沢',
  ),
  LocationValue(
    code: 'nara',
    latitude: 34.6851,
    longitude: 135.8050,
    regionName: '奈良',
  ),
  LocationValue(
    code: 'kobe',
    latitude: 34.6901,
    longitude: 135.1955,
    regionName: '神戸',
  ),
  LocationValue(
    code: 'matsuyama',
    latitude: 33.8416,
    longitude: 132.7657,
    regionName: '松山',
  ),
];

LocationValue? majorCityByCode(String code) {
  for (final city in majorCities) {
    if (city.code == code) {
      return city;
    }
  }
  return null;
}
