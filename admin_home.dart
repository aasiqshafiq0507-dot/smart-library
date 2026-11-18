import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/search_service.dart';

final _db = FirebaseFirestore.instance;
const _finePerDay = 2; // rupees per overdue day
const _loanDays = 14;

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Librarian'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'seed') _seed(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'seed', child: Text('Load sample books')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Books'), Tab(text: 'Issue'), Tab(text: 'Return')],
          ),
        ),
        body: const TabBarView(children: [_BooksTab(), _IssueTab(), _ReturnTab()]),
      ),
    );
  }
}

// ---------------- Sample data ----------------
Map<String, dynamic> _b(String t, String a, List<String> c, String ch, String p,
        String r, String s, String row) =>
    {
      'title': t,
      'author': a,
      'concepts': c,
      'chapter': ch,
      'pages': p,
      'rack': r,
      'shelf': s,
      'row': row,
      'available': true,
    };

Future<void> _seed(BuildContext context) async {
  final samples = [
    _b('Linear Algebra for AI', 'S. Kumar', ['linear algebra', 'matrices', 'vectors'],
        'Ch 4: Matrix Operations', 'pp. 88-110', '2', 'C', '3'),
    _b('Introduction to Machine Learning', 'P. Iyer',
        ['machine learning', 'regression', 'classification'], 'Ch 1: What is ML',
        'pp. 1-20', '3', 'A', '1'),
    _b('Neural Networks Essentials', 'M. Das',
        ['neural networks', 'backpropagation', 'gradient descent'],
        'Ch 3: Training Networks', 'pp. 60-95', '3', 'B', '1'),
    _b('Deep Learning Foundations', 'A. Sharma',
        ['deep learning', 'neural networks', 'optimization'],
        'Ch 6: Neural Networks', 'pp. 140-168', '3', 'B', '2'),
    _b('Convolutional Networks in Practice', 'R. Menon',
        ['cnn', 'convolutional networks', 'image recognition', 'deep learning'],
        'Ch 2: CNN Fundamentals', 'pp. 30-55', '3', 'B', '4'),
    _b('NLP Basics', 'T. Rao',
        ['nlp', 'natural language processing', 'embeddings', 'text classification'],
        'Ch 5: Word Embeddings', 'pp. 95-120', '4', 'A', '1'),
    _b('Python for Data Science', 'K. Nair', ['python', 'pandas', 'data analysis'],
        'Ch 2: Data Frames', 'pp. 25-60', '1', 'A', '2'),
    _b('Probability and Statistics for ML', 'V. Rajan',
        ['probability', 'statistics', 'machine learning'],
        'Ch 3: Distributions', 'pp. 50-80', '2', 'B', '1'),
  ];
  final batch = _db.batch();
  for (final s in samples) {
    batch.set(_db.collection('books').doc(), s);
  }
  await batch.commit();
  await SearchService.reindex();
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sample books added')));
  }
}

// ---------------- Books tab ----------------
class _BooksTab extends StatelessWidget {
  const _BooksTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBookDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('books').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final books = snap.data!.docs.map(Book.fromDoc).toList()
            ..sort((a, b) => a.title.compareTo(b.title));
          if (books.isEmpty) {
            return const Center(
                child: Text('No books yet. Use the menu > Load sample books, or tap +'));
          }
          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, i) {
              final b = books[i];
              return ListTile(
                title: Text(b.title),
                subtitle: Text(
                    '${b.author} · ${b.location} · ${b.available ? "Available" : "Issued"}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showBookDialog(context, book: b),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      await _db.collection('books').doc(b.id).delete();
                      await SearchService.reindex();
                    },
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

Widget _field(TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );

Future<void> _showBookDialog(BuildContext context, {Book? book}) async {
  final title = TextEditingController(text: book?.title);
  final author = TextEditingController(text: book?.author);
  final concepts = TextEditingController(text: book?.concepts.join(', '));
  final chapter = TextEditingController(text: book?.chapter);
  final pages = TextEditingController(text: book?.pages);
  final rack = TextEditingController(text: book?.rack);
  final shelf = TextEditingController(text: book?.shelf);
  final row = TextEditingController(text: book?.row);

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(book == null ? 'Add book' : 'Edit book'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(title, 'Title'),
            _field(author, 'Author'),
            _field(concepts, 'Concepts (comma separated)'),
            _field(chapter, 'Chapter (e.g. Ch 6: Neural Networks)'),
            _field(pages, 'Pages (e.g. pp. 140-168)'),
            Row(children: [
              Expanded(child: _field(rack, 'Rack')),
              Expanded(child: _field(shelf, 'Shelf')),
              Expanded(child: _field(row, 'Row')),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (saved != true) return;

  final data = <String, dynamic>{
    'title': title.text.trim(),
    'author': author.text.trim(),
    'concepts': concepts.text
        .split(',')
        .map((c) => c.trim().toLowerCase())
        .where((c) => c.isNotEmpty)
        .toList(),
    'chapter': chapter.text.trim(),
    'pages': pages.text.trim(),
    'rack': rack.text.trim(),
    'shelf': shelf.text.trim(),
    'row': row.text.trim(),
  };
  if (book == null) {
    await _db.collection('books').add({...data, 'available': true});
  } else {
    await _db.collection('books').doc(book.id).update(data);
  }
  await SearchService.reindex();
}

// ---------------- Issue tab ----------------
class _IssueTab extends StatefulWidget {
  const _IssueTab();

  @override
  State<_IssueTab> createState() => _IssueTabState();
}

class _IssueTabState extends State<_IssueTab> {
  final _email = TextEditingController();
  String? _bookId;

  void _msg(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _issue() async {
    final id = _bookId;
    final email = _email.text.trim();
    if (id == null || email.isEmpty) {
      _msg('Pick a book and enter the student email');
      return;
    }
    final u = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (u.docs.isEmpty) {
      _msg('No student found with that email');
      return;
    }
    final bookDoc = await _db.collection('books').doc(id).get();
    final now = DateTime.now();
    final batch = _db.batch();
    batch.set(_db.collection('transactions').doc(), {
      'bookId': id,
      'bookTitle': bookDoc.data()?['title'] ?? '',
      'studentId': u.docs.first.id,
      'studentEmail': email,
      'issueDate': Timestamp.fromDate(now),
      'dueDate': Timestamp.fromDate(now.add(const Duration(days: _loanDays))),
      'returned': false,
      'fine': 0,
    });
    batch.update(_db.collection('books').doc(id), {'available': false});
    await batch.commit();
    if (!mounted) return;
    setState(() {
      _bookId = null;
      _email.clear();
    });
    _msg('Issued. Due in $_loanDays days.');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db.collection('books').where('available', isEqualTo: true).snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final value = docs.any((d) => d.id == _bookId) ? _bookId : null;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              value: value,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Available book', border: OutlineInputBorder()),
              items: [
                for (final d in docs)
                  DropdownMenuItem(
                      value: d.id, child: Text((d.data()['title'] ?? '').toString())),
              ],
              onChanged: (v) => setState(() => _bookId = v),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              decoration: const InputDecoration(
                  labelText: 'Student email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _issue, child: const Text('Issue book')),
          ]);
        },
      ),
    );
  }
}

// ---------------- Return tab ----------------
class _ReturnTab extends StatelessWidget {
  const _ReturnTab();

  Future<void> _return(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final t = doc.data();
    final due = (t['dueDate'] as Timestamp).toDate();
    final late = DateTime.now().difference(due).inDays;
    final fine = late > 0 ? late * _finePerDay : 0;

    final batch = _db.batch();
    batch.update(doc.reference,
        {'returned': true, 'returnDate': Timestamp.now(), 'fine': fine});
    batch.update(_db.collection('books').doc(t['bookId']), {'available': true});
    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Returned. Fine: ₹$fine')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('transactions').where('returned', isEqualTo: false).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No books currently issued'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final t = docs[i].data();
            final due = (t['dueDate'] as Timestamp).toDate();
            final overdue = DateTime.now().isAfter(due);
            return ListTile(
              title: Text((t['bookTitle'] ?? '').toString()),
              subtitle: Text(
                  '${t['studentEmail']} · due ${due.day}/${due.month}/${due.year}'
                  '${overdue ? " (OVERDUE)" : ""}'),
              trailing: TextButton(
                onPressed: () => _return(context, docs[i]),
                child: const Text('Return'),
              ),
            );
          },
        );
      },
    );
  }
}
