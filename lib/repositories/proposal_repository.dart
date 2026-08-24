import '../models/proposal.dart';

abstract class ProposalRepository {
  Future<void> initialize();

  List<Proposal> getAll();

  Proposal? byId(String id);

  List<Proposal> byRequestId(String requestId);

  List<Proposal> byTechnicianId(String technicianId);

  Future<void> create(Proposal proposal);

  Future<void> update(Proposal proposal);

  Future<void> delete(String id);
}
