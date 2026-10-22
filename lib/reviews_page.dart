import 'package:flutter/material.dart';
import 'main.dart';
import 'tabs.dart';
import 'ui.dart';

/// Page « Avis clients » : note moyenne et liste des avis du commerce (table shop_reviews).
class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});
  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    store.loadReviews().then((_) { if (mounted) setState(() => loading = false); });
  }

  /// Texte de l'avis : on accepte plusieurs noms de colonne possibles.
  String _comment(Map<String, dynamic> r) {
    for (final k in const ['comment', 'text', 'body', 'content', 'review', 'message']) {
      final v = r[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  String _author(Map<String, dynamic> r) {
    final id = r['client_id'] ?? r['user_id'];
    if (id == null) return '';
    final n = store.clientName('$id');
    return n == '—' ? '' : n;
  }

  Widget _stars(num rating, {double size = 18}) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++) Icon(i <= rating.round() ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: kWarn),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListenableBuilder(
          listenable: store,
          builder: (_, __) {
            final rows = store.reviews;
            final rated = rows.where((r) => r['rating'] is num).toList();
            // Moyenne : celle de la vue si elle marche, sinon calculée depuis la liste.
            final viewAvg = (store.rating?['avg_rating'] as num?)?.toDouble();
            final avg = viewAvg ?? (rated.isEmpty ? null : rated.fold<double>(0, (a, r) => a + (r['rating'] as num)) / rated.length);
            final count = store.rating?['reviews_count'] ?? rows.length;
            return NqScreen(
              title: tr('Avis clients', 'آراء الزبائن'),
              action: HeaderPill(icon: Icons.arrow_back_rounded, label: tr('Retour', 'رجوع'), onTap: () => Navigator.pop(context)),
              header: [
                YellowCard(
                  child: Row(children: [
                    Text(avg == null ? '—' : avg.toStringAsFixed(1), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (avg != null) _stars(avg, size: 22),
                        const SizedBox(height: 4),
                        Text('$count ${tr('avis', 'تقييم')}', style: const TextStyle(fontSize: 15)),
                      ]),
                    ),
                  ]),
                ),
              ],
              body: RefreshIndicator(
                onRefresh: () async { await store.refresh(); await store.loadReviews(); },
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
                  if (store.errors['reviews'] != null) ErrorBanner(tr('liste des avis', 'قائمة الآراء'), store.errors['reviews']!),
                  if (store.errors['rating'] != null) ErrorBanner(tr('note moyenne', 'المعدل'), store.errors['rating']!),
                  if (loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                  if (!loading && rows.isEmpty && store.errors['reviews'] == null) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(tr('Aucun avis pour l\'instant', 'لا آراء بعد'), style: const TextStyle(color: kMuted)))),
                  for (var i = 0; i < rows.length; i++)
                    FadeSlideIn(
                      index: i,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardColor(context), borderRadius: BorderRadius.circular(22)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            if (rows[i]['rating'] is num) _stars(rows[i]['rating'] as num),
                            const Spacer(),
                            if (rows[i]['created_at'] != null) Text(dmy(localDt(rows[i]['created_at'])), style: const TextStyle(fontSize: 12.5, color: kMuted)),
                          ]),
                          if (_comment(rows[i]).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_comment(rows[i]))),
                          if (_author(rows[i]).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_author(rows[i]), style: const TextStyle(fontSize: 12.5, color: kMuted, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ),
                ]),
              ),
            );
          },
        ),
      );
}
