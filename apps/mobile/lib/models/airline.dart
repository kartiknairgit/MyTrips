/// Airline model matching the airlines table schema.
class Airline {
  final String iataCode;
  final String name;
  final String brandColorHex;
  final String? alliance;

  Airline({
    required this.iataCode,
    required this.name,
    required this.brandColorHex,
    this.alliance,
  });

  factory Airline.fromJson(Map<String, dynamic> json) {
    return Airline(
      iataCode: json['iata_code'] as String,
      name: json['name'] as String,
      brandColorHex: json['brand_color_hex'] as String? ?? '#6b7280',
      alliance: json['alliance'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iata_code': iataCode,
      'name': name,
      'brand_color_hex': brandColorHex,
      'alliance': alliance,
    };
  }
}
