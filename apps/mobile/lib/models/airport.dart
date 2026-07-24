/// Airport model matching the airports table schema.
class Airport {
  final String iataCode;
  final String name;
  final String? country;
  final String? continent;
  final String? city;
  final double lat;
  final double lng;

  Airport({
    required this.iataCode,
    required this.name,
    this.country,
    this.continent,
    this.city,
    required this.lat,
    required this.lng,
  });

  factory Airport.fromJson(Map<String, dynamic> json) {
    return Airport(
      iataCode: json['iata_code'] as String,
      name: json['name'] as String,
      country: json['country'] as String?,
      continent: json['continent'] as String?,
      city: json['city'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iata_code': iataCode,
      'name': name,
      'country': country,
      'continent': continent,
      'city': city,
      'lat': lat,
      'lng': lng,
    };
  }
}
