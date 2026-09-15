import 'technician_directory_entry.dart';

class TechnicianPublicReview {
  final String publicRatingId;
  final int score;
  final String review;
  final DateTime? createdAt;

  const TechnicianPublicReview({
    required this.publicRatingId,
    required this.score,
    required this.review,
    required this.createdAt,
  });

  factory TechnicianPublicReview.fromJson(Map<String, dynamic> json) {
    final score = json['score'];
    final id = json['publicRatingId'];
    if (score is! int || score < 1 || score > 5 || id is! String || id.isEmpty) {
      throw const FormatException('Invalid public service review.');
    }
    return TechnicianPublicReview(
      publicRatingId: id,
      score: score,
      review: json['review'] is String ? json['review'] as String : '',
      createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal(),
    );
  }
}

class TechnicianPublicProfile {
  final TechnicianDirectoryEntry technician;
  final List<TechnicianPublicReview> reviews;
  final int reviewPage;
  final bool hasMoreReviews;

  const TechnicianPublicProfile({
    required this.technician,
    required this.reviews,
    required this.reviewPage,
    required this.hasMoreReviews,
  });

  factory TechnicianPublicProfile.fromJson(Map<String, dynamic> json) {
    final technician = json['technician'];
    final reviews = json['reviews'];
    final page = json['reviewPage'];
    if (technician is! Map || reviews is! List || page is! int || page < 0) {
      throw const FormatException('Invalid public technician profile.');
    }
    return TechnicianPublicProfile(
      technician: TechnicianDirectoryEntry.fromJson(
        technician.map((key, value) => MapEntry('$key', value)),
      ),
      reviews: List<TechnicianPublicReview>.unmodifiable(reviews.map((value) {
        if (value is! Map) {
          throw const FormatException('Invalid public service review.');
        }
        return TechnicianPublicReview.fromJson(
          value.map((key, value) => MapEntry('$key', value)),
        );
      })),
      reviewPage: page,
      hasMoreReviews: json['hasMoreReviews'] == true,
    );
  }
}
