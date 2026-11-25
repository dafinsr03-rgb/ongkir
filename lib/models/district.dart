class District {
  const District({required this.id, required this.name});

  factory District.fromJson(Map<String, dynamic> json) =>
      District(id: json['id'].toString(), name: json['name'] as String);

  final String id;
  final String name;

  @override
  String toString() => name;
}
