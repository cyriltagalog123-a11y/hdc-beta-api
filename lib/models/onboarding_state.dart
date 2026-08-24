class OnboardingState {
  final Set<String> completedFlows;

  const OnboardingState({
    this.completedFlows = const <String>{},
  });

  bool hasCompleted(String flowId) {
    return completedFlows.contains(flowId);
  }

  OnboardingState complete(String flowId) {
    return OnboardingState(
      completedFlows: <String>{...completedFlows, flowId},
    );
  }

  OnboardingState reset(String flowId) {
    return OnboardingState(
      completedFlows: completedFlows
          .where((completedFlow) => completedFlow != flowId)
          .toSet(),
    );
  }
}
