import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/search_service.dart';

class StudentHome extends StatefulWidget {
  final String name;
  const StudentHome({super.key, required this.name});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final _q = TextEditingController();
  final _service = SearchService();
  SearchResponse? _resp;
  bool _loading = false;

  Future<void> _run([String? text]) async {
    if (text != null) _q.text = text;
    final query = _q.text.trim();
    if (query.isEmpty) return;
    setState(() => _loading = true);
    final r = await _service.search(query);
    if (!mounted) return;
    setState(() {
      _resp = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${widget.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _q,
              onSubmitted: (_) => _run(),
              decoration: InputDecoration(
                hintText: 'Ask or enter a concept, e.g. neural networks',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _run,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final resp = _resp;
    if (resp == null) {
      return ListView(children: [
        const Text('Try:', style: TextStyle(color: Colors.grey)),
        Wrap(spacing: 8, children: [
          for (final s in [
            'neural networks',
            'where can I learn machine learning',
            'nlp',
            'linear algebra'
          ])
            ActionChip(label: Text(s), onPressed: () => _run(s)),
        ]),
      ]);
    }
    if (resp.hits.isEmpty) {
      return const Center(child: Text('No matches. Try a broader term.'));
    }
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          resp.usedAi
              ? 'AI semantic search'
              : 'Keyword search (AI service offline)',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
      for (final h in resp.hits)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(h.book.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                Chip(
                  label: Text(h.book.available ? 'Available' : 'Checked out'),
                  backgroundColor:
                      h.book.available ? Colors.green.shade50 : Colors.orange.shade50,
                ),
              ]),
              Text(h.book.author, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text('${h.book.chapter} · ${h.book.pages}'),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.place, size: 16),
                const SizedBox(width: 4),
                Text(h.book.location),
              ]),
            ]),
          ),
        ),
      if (resp.related.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('Explore next', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final c in resp.related)
            ActionChip(label: Text(c), onPressed: () => _run(c)),
        ]),
      ],
    ]);
  }
}
