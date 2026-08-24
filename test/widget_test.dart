import 'package:flutter_test/flutter_test.dart';

import 'package:hdc_app/core/auth/unavailable_auth_gateway.dart';
import 'package:hdc_app/main.dart';
import 'package:hdc_app/repositories/shared_preferences_proposal_repository.dart';
import 'package:hdc_app/repositories/shared_preferences_service_request_repository.dart';
import 'package:hdc_app/repositories/shared_preferences_service_transaction_repository.dart';
import 'package:hdc_app/repositories/shared_preferences_transaction_seed_repository.dart';

void main() {
  testWidgets(
    'HDC app launches successfully',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        HDCApp(
          authGateway: const UnavailableAuthGateway(
            'Widget test authentication gateway',
          ),
          proposalRepository: SharedPreferencesProposalRepository(),
          serviceRequestRepository:
              SharedPreferencesServiceRequestRepository(),
          serviceTransactionRepository:
              SharedPreferencesServiceTransactionRepository(),
          transactionSeedRepository:
              SharedPreferencesTransactionSeedRepository(),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byType(HDCApp),
        findsOneWidget,
      );
    },
  );
}
