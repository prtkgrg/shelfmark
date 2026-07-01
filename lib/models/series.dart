class Series {
  final String id;
  String name;
  final String folderPath;

  Series({required this.id, required this.name, required this.folderPath});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'folderPath': folderPath,
      };

  factory Series.fromJson(Map<String, dynamic> json) => Series(
        id: json['id'] as String,
        name: json['name'] as String,
        folderPath: json['folderPath'] as String,
      );
}
