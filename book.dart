import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String id, title, author, chapter, pages, rack, shelf, row;
  final List<String> concepts;
  final bool available;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.concepts,
    required this.chapter,
    required this.pages,
    required this.rack,
    required this.shelf,
    required this.row,
    required this.available,
  });

  factory Book.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Book(
      id: d.id,
      title: (m['title'] ?? '').toString(),
      author: (m['author'] ?? '').toString(),
      concepts: List<String>.from(m['concepts'] ?? const []),
      chapter: (m['chapter'] ?? '').toString(),
      pages: (m['pages'] ?? '').toString(),
      rack: (m['rack'] ?? '').toString(),
      shelf: (m['shelf'] ?? '').toString(),
      row: (m['row'] ?? '').toString(),
      available: m['available'] ?? true,
    );
  }

  String get location => 'Rack $rack · Shelf $shelf · Row $row';
}
