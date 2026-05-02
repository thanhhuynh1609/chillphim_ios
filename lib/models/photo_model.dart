class Photo {
  final int id;
  final String imageUrl;
  final String createdAt;

  Photo({required this.id, required this.imageUrl, required this.createdAt});

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      imageUrl: json['image_url'],
      createdAt: json['created_at'],
    );
  }
}