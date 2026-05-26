import 'package:flutter_test/flutter_test.dart';
import 'package:studytrace/src/models/ai_flash_card.dart';

void main() {
  AiFlashCard makeCard() => AiFlashCard(
        id: 'fc1',
        question: 'What is TCP?',
        answer: 'Transmission Control Protocol',
        createdAt: DateTime(2026, 5, 1),
      );

  group('AiFlashCard.recordReview - SM-2', () {
    test('初次评分 5 分：第 1 次复习，间隔 1 天', () {
      final card = makeCard();
      final reviewed = card.recordReview(5);
      expect(reviewed.reviewCount, 1);
      expect(reviewed.nextReviewDate, isNotNull);
      final daysUntil =
          reviewed.nextReviewDate!.difference(DateTime.now()).inDays;
      expect(daysUntil, inInclusiveRange(0, 2));
    });

    test('质量 < 3 会重新开始（间隔 1 天）', () {
      final card = makeCard().copyWith(reviewCount: 5);
      final reviewed = card.recordReview(2);
      final daysUntil =
          reviewed.nextReviewDate!.difference(DateTime.now()).inDays;
      expect(daysUntil, inInclusiveRange(0, 2));
      // ease factor 会降低
      expect(reviewed.easeFactor, lessThan(card.easeFactor));
    });

    test('连续高分 ease factor 上升', () {
      var card = makeCard();
      for (int i = 0; i < 3; i++) {
        card = card.recordReview(5);
      }
      expect(card.easeFactor, greaterThan(250));
    });

    test('ease factor 最低 130', () {
      var card = makeCard();
      for (int i = 0; i < 20; i++) {
        card = card.recordReview(1);
      }
      expect(card.easeFactor, greaterThanOrEqualTo(130));
    });

    test('quality 会被 clamp 到 1-5', () {
      final card = makeCard();
      final high = card.recordReview(10);
      final low = card.recordReview(0);
      expect(high.easeFactor, greaterThanOrEqualTo(130));
      expect(low.easeFactor, greaterThanOrEqualTo(130));
    });
  });

  group('AiFlashCard.isDueForReview', () {
    test('从未复习过的卡片 → 应复习', () {
      final card = makeCard();
      expect(card.isDueForReview, isTrue);
    });

    test('nextReviewDate 在未来 → 不应复习', () {
      final card = makeCard()
          .copyWith(nextReviewDate: DateTime.now().add(const Duration(days: 3)));
      expect(card.isDueForReview, isFalse);
    });

    test('nextReviewDate 在过去 → 应复习', () {
      final card = makeCard().copyWith(
          nextReviewDate:
              DateTime.now().subtract(const Duration(days: 1)));
      expect(card.isDueForReview, isTrue);
    });
  });

  group('AiFlashCard JSON 序列化', () {
    test('toJson 保留所有字段', () {
      final card = makeCard().recordReview(4);
      final json = card.toJson();
      expect(json['reviewCount'], 1);
      expect(json['nextReviewDate'], isNotNull);
    });

    test('fromJson 对缺失字段兜底默认值（向后兼容）', () {
      final json = {
        'id': 'fc1',
        'question': 'Q',
        'answer': 'A',
        'createdAt': '2026-05-01T00:00:00.000',
      };
      final card = AiFlashCard.fromJson(json);
      expect(card.reviewCount, 0);
      expect(card.easeFactor, 250);
      expect(card.nextReviewDate, isNull);
    });
  });
}
