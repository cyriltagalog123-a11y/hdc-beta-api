import 'nexus_context.dart';
import 'nexus_knowledge.dart';
import 'nexus_memory.dart';
import 'nexus_personality.dart';
import 'nexus_recommendation_engine.dart';

class NexusService {

  final NexusMemory memory;

  final NexusContext context;

  final NexusKnowledge knowledge;

  final NexusPersonality personality;

  final NexusRecommendationEngine recommendations;

  const NexusService({

    required this.memory,

    required this.context,

    required this.knowledge,

    required this.personality,

    required this.recommendations,
  });
}