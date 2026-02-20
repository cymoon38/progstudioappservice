

class ContentBlock {
  final String type; // 'text' or 'image'
  final String? text;
  final String? imageUrl;
  final int order;

  ContentBlock({
    required this.type,
    this.text,
    this.imageUrl,
    required this.order,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'text': text,
      'imageUrl': imageUrl,
      'order': order,
    };
  }

  factory ContentBlock.fromMap(Map<String, dynamic> map) {
    return ContentBlock(
      type: map['type'] ?? 'text',
      text: map['text'],
      imageUrl: map['imageUrl'],
      order: map['order'] ?? 0,
    );
  }
}




