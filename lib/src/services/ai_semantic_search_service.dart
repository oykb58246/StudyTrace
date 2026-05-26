import 'api_client.dart';

class SemanticSearchCandidate<T> {
  const SemanticSearchCandidate({
    required this.item,
    required this.text,
    this.id = '',
  });

  final T item;
  final String text;
  final String id;
}

class SemanticSearchHit<T> {
  const SemanticSearchHit({
    required this.item,
    required this.score,
    required this.rewrittenQuery,
  });

  final T item;
  final double score;
  final String rewrittenQuery;
}

class AiSemanticSearchService {
  AiSemanticSearchService({
    ApiClient? backendClient,
  }) : _backendClient = backendClient;

  final ApiClient? _backendClient;

  Future<List<SemanticSearchHit<T>>> search<T>({
    required String query,
    required List<SemanticSearchCandidate<T>> candidates,
  }) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      return candidates
          .map((candidate) => SemanticSearchHit(
                item: candidate.item,
                score: 0,
                rewrittenQuery: cleaned,
              ))
          .toList();
    }

    final pool = _candidatePool(cleaned, candidates);
    if (pool.isEmpty) return const [];

    try {
      final rewritten = await _rewrite(cleaned);
      final scores = await _rerank(
        query: rewritten.isEmpty ? cleaned : rewritten,
        sentences: pool.map((c) => c.text).toList(),
      );
      if (scores.length == pool.length) {
        final hits = <SemanticSearchHit<T>>[];
        for (var i = 0; i < pool.length; i++) {
          hits.add(SemanticSearchHit(
            item: pool[i].item,
            score: scores[i],
            rewrittenQuery: rewritten,
          ));
        }
        hits.sort((a, b) => b.score.compareTo(a.score));
        return hits;
      }
    } catch (_) {
      // Semantic search is enhancement-only. Fall back to local filtering.
    }

    return _localMatches(cleaned, candidates)
        .map((candidate) => SemanticSearchHit(
              item: candidate.item,
              score: 0,
              rewrittenQuery: cleaned,
            ))
        .toList();
  }

  Future<String> _rewrite(String query) async {
    final backend = _backendClient;
    if (backend != null) {
      try {
        final data = await backend.postJson(
          '/ai/query-rewrite',
          body: {'query': query},
        );
        final rewritten = data['query']?.toString().trim() ?? '';
        if (rewritten.isNotEmpty) return rewritten;
      } on ApiException {}
    }

    return query;
  }

  Future<List<double>> _rerank({
    required String query,
    required List<String> sentences,
  }) async {
    final backend = _backendClient;
    if (backend != null) {
      try {
        final data = await backend.postJson(
          '/ai/rerank',
          body: {
            'query': query,
            'sentences': sentences,
          },
        );
        final scores = data['scores'];
        if (scores is List) {
          return scores
              .map((item) => item is num
                  ? item.toDouble()
                  : double.negativeInfinity)
              .toList();
        }
      } on ApiException {}
    }

    return const [];
  }

  List<SemanticSearchCandidate<T>> _candidatePool<T>(
    String query,
    List<SemanticSearchCandidate<T>> candidates,
  ) {
    if (candidates.length <= 20) return candidates;
    final local = _localMatches(query, candidates);
    if (local.length >= 20) return local.take(20).toList();
    final result = <SemanticSearchCandidate<T>>[...local];
    for (final candidate in candidates) {
      if (result.length >= 20) break;
      if (!result.any((item) => item.id == candidate.id)) {
        result.add(candidate);
      }
    }
    return result;
  }

  List<SemanticSearchCandidate<T>> _localMatches<T>(
    String query,
    List<SemanticSearchCandidate<T>> candidates,
  ) {
    final q = query.toLowerCase();
    final matches = candidates
        .where((candidate) => candidate.text.toLowerCase().contains(q))
        .toList();
    return matches.isEmpty ? candidates : matches;
  }
}
