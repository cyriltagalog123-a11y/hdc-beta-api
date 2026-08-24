import 'package:flutter/material.dart';

import 'nexus_context.dart';
import 'nexus_knowledge.dart';
import 'nexus_memory.dart';
import 'nexus_personality.dart';
import 'nexus_recommendation_engine.dart';
import 'nexus_service.dart';

class NexusProvider extends ChangeNotifier {
  late final NexusService _service;

  NexusProvider() {
    _service = NexusService(
      memory: NexusMemory(),
      context: NexusContext(),
      knowledge: NexusKnowledge(),
      personality: const NexusPersonality(),
      recommendations:
          const NexusRecommendationEngine(),
    );
  }

  NexusService get service =>
      _service;

  NexusContext get context =>
      _service.context;

  NexusMemory get memory =>
      _service.memory;

  NexusKnowledge get knowledge =>
      _service.knowledge;

  NexusPersonality get personality =>
      _service.personality;

  NexusRecommendationEngine
      get recommendations =>
          _service.recommendations;

  String get greeting =>
      _service.personality.greeting;

  void update(
    NexusContext newContext,
  ) {
    _service.context.organizationId =
        newContext.organizationId;

    _service.context.brandId =
        newContext.brandId;

    _service.context.regionId =
        newContext.regionId;

    _service.context.storeId =
        newContext.storeId;

    _service.context.departmentId =
        newContext.departmentId;

    _service.context.employeeId =
        newContext.employeeId;

    _service.context.userAccountId =
        newContext.userAccountId;

    notifyListeners();
  }

  void clearContext() {
    _service.context.clear();

    notifyListeners();
  }
}