import 'package:flutter/material.dart';

import '../models/asset_assignment.dart';
import '../repositories/asset_assignment_repository.dart';

class AssetAssignmentProvider
    extends ChangeNotifier {
  final AssetAssignmentRepository _repository =
      AssetAssignmentRepository.instance;

  List<AssetAssignment> getAssignments(
    String assetId,
  ) {
    return _repository.getAssignments(
      assetId,
    );
  }

  AssetAssignment? currentAssignment(
    String assetId,
  ) {
    return _repository.currentAssignment(
      assetId,
    );
  }

  void assign(
    AssetAssignment assignment,
  ) {
    _repository.assign(
      assignment,
    );

    notifyListeners();
  }

  void clear() {
    _repository.clear();

    notifyListeners();
  }
}