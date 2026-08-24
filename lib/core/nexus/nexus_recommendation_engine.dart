class NexusRecommendationEngine {

  const NexusRecommendationEngine();

  List<String> recommend({

    required String topic,

    required List<String> candidates,

  }) {

    if (candidates.isEmpty) {
      return [];
    }

    return candidates;
  }
}