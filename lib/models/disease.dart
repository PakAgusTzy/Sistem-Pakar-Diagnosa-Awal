// models/disease.dart
class Disease {
  final String id;
  final String name;
  final String? desc;
  final String? ref;
  Disease({required this.id, required this.name, this.desc, this.ref});

  factory Disease.fromJson(Map<String, dynamic> j, String id) =>
      Disease(id: id, name: j['name'], desc: j['desc'], ref: j['ref']);

  Map<String, dynamic> toJson() => {'name': name, 'desc': desc, 'ref': ref};
}
