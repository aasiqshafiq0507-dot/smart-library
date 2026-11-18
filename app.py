"""Smart Library AI service: semantic search over the books in Firestore.

Run:  python app.py      (listens on http://localhost:8000)
Needs serviceAccountKey.json in this folder (Firebase console >
Project settings > Service accounts > Generate new private key).
"""
import firebase_admin
import numpy as np
from firebase_admin import credentials, firestore
from flask import Flask, jsonify, request
from flask_cors import CORS
from sentence_transformers import SentenceTransformer

firebase_admin.initialize_app(credentials.Certificate("serviceAccountKey.json"))
db = firestore.client()
model = SentenceTransformer("all-MiniLM-L6-v2")  # small, fast, runs on CPU

app = Flask(__name__)
CORS(app)  # lets the Flutter web app (Chrome) call this service

books = []
vectors = None
MIN_SCORE = 0.25  # ignore weak matches


def reindex():
    """Load all books from Firestore and embed them."""
    global books, vectors
    books = []
    for d in db.collection("books").stream():
        b = d.to_dict()
        b["id"] = d.id
        books.append(b)
    texts = [
        f'{b.get("title", "")}. {b.get("chapter", "")}. '
        f'Topics: {", ".join(b.get("concepts", []))}'
        for b in books
    ]
    vectors = model.encode(texts, normalize_embeddings=True) if texts else None
    return len(books)


@app.post("/reindex")
def reindex_route():
    return jsonify(indexed=reindex())


@app.post("/search")
def search():
    query = (request.get_json(silent=True) or {}).get("query", "").strip()
    if not query or vectors is None:
        return jsonify(results=[], related=[])

    qv = model.encode([query], normalize_embeddings=True)[0]
    scores = vectors @ qv
    order = np.argsort(-scores)[:8]
    results = [
        {"id": books[i]["id"], "score": float(scores[i])}
        for i in order
        if scores[i] >= MIN_SCORE
    ]

    # Related concepts: topics of the best matches that the query didn't mention.
    related = []
    q_low = query.lower()
    by_id = {b["id"]: b for b in books}
    for r in results[:3]:
        for c in by_id[r["id"]].get("concepts", []):
            if c not in related and c.lower() not in q_low:
                related.append(c)
    return jsonify(results=results, related=related[:6])


if __name__ == "__main__":
    print(f"Indexed {reindex()} books")
    app.run(port=8000)
