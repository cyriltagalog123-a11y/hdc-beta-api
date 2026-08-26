import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/hdc_workflow_api_client.dart';
import 'core/auth/auth_gateway.dart';
import 'core/auth/hdc_api_auth_gateway.dart';
import 'core/auth/auth_session_store.dart';
import 'core/auth/unavailable_auth_gateway.dart';
import 'core/backend/backend_config.dart';
import 'core/ui/hdc_theme.dart';
import 'features/splash/splash_screen.dart';
import 'providers/hdc_auth_provider.dart';
import 'providers/hdc_internal_dashboard_provider.dart';
import 'providers/hdc_marketplace_provider.dart';
import 'providers/hdc_profile_provider.dart';
import 'providers/hdc_role_center_provider.dart';
import 'providers/hdc_sales_center_provider.dart';
import 'providers/hdc_workflow_sync_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/private_messaging_provider.dart';
import 'providers/proposal_acceptance_provider.dart';
import 'providers/proposal_provider.dart';
import 'providers/service_request_provider.dart';
import 'providers/service_transaction_provider.dart';
import 'providers/technician_discovery_provider.dart';
import 'providers/technician_marketplace_provider.dart';
import 'providers/ticket_provider.dart';
import 'repositories/hdc_api_workflow_repositories.dart';
import 'repositories/proposal_acceptance_gateway.dart';
import 'repositories/proposal_repository.dart';
import 'repositories/service_request_repository.dart';
import 'repositories/service_transaction_repository.dart';
import 'repositories/service_transaction_transition_gateway.dart';
import 'repositories/shared_preferences_onboarding_repository.dart';
import 'repositories/shared_preferences_private_conversation_repository.dart';
import 'repositories/shared_preferences_proposal_repository.dart';
import 'repositories/shared_preferences_service_request_repository.dart';
import 'repositories/shared_preferences_service_transaction_repository.dart';
import 'repositories/shared_preferences_transaction_seed_repository.dart';
import 'repositories/transaction_seed_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AuthGateway authGateway;
  final sessionStore = MemoryAuthSessionStore();
  final baseUri = HDCBackendConfig.apiBaseUri;

  try {
    if (baseUri == null) {
      throw StateError('HDC authentication API configuration is invalid.');
    }

    authGateway = HdcApiAuthGateway(
      baseUri: baseUri,
      sessionStore: sessionStore,
    );
  } on Object catch (error) {
    authGateway = UnavailableAuthGateway(error);
  }

  late final ProposalRepository proposalRepository;
  late final ServiceRequestRepository serviceRequestRepository;
  late final ServiceTransactionRepository serviceTransactionRepository;
  late final TransactionSeedRepository transactionSeedRepository;
  ProposalAcceptanceGateway? proposalAcceptanceGateway;
  ServiceTransactionTransitionGateway? transactionTransitionGateway;
  HdcWorkflowSyncProvider? workflowSyncProvider;
  HdcWorkflowApiClient? roleApiClient;

  if (HDCBackendConfig.provider == HDCBackendProvider.hdcApi &&
      baseUri != null) {
    final workflowClient = HdcWorkflowApiClient(
      baseUri: baseUri,
      sessionStore: sessionStore,
    );
    roleApiClient = workflowClient;
    final workflowStore = HdcApiWorkflowStore(client: workflowClient);
    proposalRepository = HdcApiProposalRepository(workflowStore);
    serviceRequestRepository = HdcApiServiceRequestRepository(workflowStore);
    serviceTransactionRepository = HdcApiServiceTransactionRepository(
      workflowStore,
    );
    transactionSeedRepository = HdcApiTransactionSeedRepository(workflowStore);
    proposalAcceptanceGateway = workflowStore;
    transactionTransitionGateway = workflowStore;
    workflowSyncProvider = HdcWorkflowSyncProvider(store: workflowStore);
  } else {
    proposalRepository = SharedPreferencesProposalRepository();
    serviceRequestRepository = SharedPreferencesServiceRequestRepository();
    serviceTransactionRepository =
        SharedPreferencesServiceTransactionRepository();
    transactionSeedRepository = SharedPreferencesTransactionSeedRepository();
  }

  runApp(
    HDCApp(
      authGateway: authGateway,
      proposalRepository: proposalRepository,
      serviceRequestRepository: serviceRequestRepository,
      serviceTransactionRepository: serviceTransactionRepository,
      transactionSeedRepository: transactionSeedRepository,
      proposalAcceptanceGateway: proposalAcceptanceGateway,
      transactionTransitionGateway: transactionTransitionGateway,
      workflowSyncProvider: workflowSyncProvider,
      roleApiClient: roleApiClient,
    ),
  );
}

class HDCApp extends StatelessWidget {
  final AuthGateway authGateway;
  final ProposalRepository proposalRepository;
  final ServiceRequestRepository serviceRequestRepository;
  final ServiceTransactionRepository serviceTransactionRepository;
  final TransactionSeedRepository transactionSeedRepository;
  final ProposalAcceptanceGateway? proposalAcceptanceGateway;
  final ServiceTransactionTransitionGateway? transactionTransitionGateway;
  final HdcWorkflowSyncProvider? workflowSyncProvider;
  final HdcWorkflowApiClient? roleApiClient;

  const HDCApp({
    required this.authGateway,
    required this.proposalRepository,
    required this.serviceRequestRepository,
    required this.serviceTransactionRepository,
    required this.transactionSeedRepository,
    this.proposalAcceptanceGateway,
    this.transactionTransitionGateway,
    this.workflowSyncProvider,
    this.roleApiClient,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => HDCAuthProvider(gateway: authGateway),
        ),
        ChangeNotifierProxyProvider<HDCAuthProvider, HdcRoleCenterProvider>(
          create: (_) => HdcRoleCenterProvider(client: roleApiClient),
          update: (_, auth, roleCenter) {
            final provider =
                roleCenter ?? HdcRoleCenterProvider(client: roleApiClient);
            provider.bindIdentity(
              auth.authenticated && !auth.guestMode ? auth.identity : null,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<
          HDCAuthProvider,
          HdcInternalDashboardProvider
        >(
          create: (_) => HdcInternalDashboardProvider(client: roleApiClient),
          update: (_, auth, internalDashboard) {
            final provider =
                internalDashboard ??
                HdcInternalDashboardProvider(client: roleApiClient);
            provider.bindIdentity(
              auth.authenticated && !auth.guestMode ? auth.identity : null,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<HDCAuthProvider, HdcProfileProvider>(
          create: (_) => HdcProfileProvider(client: roleApiClient),
          update: (_, auth, profileProvider) {
            final provider =
                profileProvider ?? HdcProfileProvider(client: roleApiClient);
            provider.bindIdentity(
              auth.authenticated && !auth.guestMode ? auth.identity : null,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<HDCAuthProvider, HdcSalesCenterProvider>(
          create: (_) => HdcSalesCenterProvider(client: roleApiClient),
          update: (_, auth, salesCenter) {
            final provider =
                salesCenter ?? HdcSalesCenterProvider(client: roleApiClient);
            provider.bindIdentity(
              auth.authenticated && !auth.guestMode ? auth.identity : null,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<HDCAuthProvider, HdcMarketplaceProvider>(
          create: (_) => HdcMarketplaceProvider(client: roleApiClient),
          update: (_, auth, marketplace) {
            final provider =
                marketplace ?? HdcMarketplaceProvider(client: roleApiClient);
            provider.bindIdentity(
              auth.authenticated && !auth.guestMode ? auth.identity : null,
            );
            return provider;
          },
        ),
        if (workflowSyncProvider != null)
          ChangeNotifierProxyProvider<HDCAuthProvider, HdcWorkflowSyncProvider>(
            create: (_) => workflowSyncProvider!,
            update: (_, auth, syncProvider) {
              final provider = syncProvider ?? workflowSyncProvider!;
              provider.bindUser(auth.authenticated ? auth.identity?.id : null);
              return provider;
            },
          ),
        ChangeNotifierProxyProvider<HDCAuthProvider, TicketProvider>(
          create: (_) => TicketProvider(),
          update: (_, auth, ticketProvider) {
            final provider = ticketProvider ?? TicketProvider();
            provider.bindUser(
              auth.authenticated && !auth.guestMode ? auth.identity?.id : null,
            );
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => OnboardingProvider(
            repository: SharedPreferencesOnboardingRepository(),
          ),
        ),
        ChangeNotifierProxyProvider<
          HDCAuthProvider,
          TechnicianMarketplaceProvider
        >(
          create: (_) => TechnicianMarketplaceProvider(),
          update: (_, auth, marketplaceProvider) {
            final provider =
                marketplaceProvider ?? TechnicianMarketplaceProvider();
            provider.bindUser(
              auth.authenticated && !auth.guestMode ? auth.identity?.id : null,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<
          HDCAuthProvider,
          TechnicianDiscoveryProvider
        >(
          create: (_) => TechnicianDiscoveryProvider(client: roleApiClient),
          update: (_, auth, discoveryProvider) {
            final provider =
                discoveryProvider ??
                TechnicianDiscoveryProvider(client: roleApiClient);
            provider.bindIdentity(
              auth.authenticated && !auth.guestMode ? auth.identity : null,
            );
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = ProposalProvider(repository: proposalRepository);
            workflowSyncProvider?.addListener(provider.refreshFromRepository);
            provider.initialize();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = ServiceRequestProvider(
              repository: serviceRequestRepository,
            );
            workflowSyncProvider?.addListener(provider.refreshFromRepository);
            provider.initialize();
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<
          ProposalProvider,
          ServiceRequestProvider,
          ProposalAcceptanceProvider
        >(
          create: (_) => ProposalAcceptanceProvider(
            transactionSeedRepository: transactionSeedRepository,
            acceptanceGateway: proposalAcceptanceGateway,
          )..initialize(),
          update:
              (
                _,
                proposalProvider,
                serviceRequestProvider,
                acceptanceProvider,
              ) {
                final provider =
                    acceptanceProvider ??
                    ProposalAcceptanceProvider(
                      transactionSeedRepository: transactionSeedRepository,
                      acceptanceGateway: proposalAcceptanceGateway,
                    );
                provider.bind(
                  proposalProvider: proposalProvider,
                  serviceRequestProvider: serviceRequestProvider,
                );
                return provider;
              },
        ),
        ChangeNotifierProxyProvider2<
          ProposalProvider,
          ServiceRequestProvider,
          ServiceTransactionProvider
        >(
          create: (_) {
            final provider = ServiceTransactionProvider(
              repository: serviceTransactionRepository,
              seedRepository: transactionSeedRepository,
              transitionGateway: transactionTransitionGateway,
            );
            workflowSyncProvider?.addListener(provider.refreshFromRepository);
            return provider;
          },
          update:
              (
                _,
                proposalProvider,
                serviceRequestProvider,
                transactionProvider,
              ) {
                final provider =
                    transactionProvider ??
                    ServiceTransactionProvider(
                      repository: serviceTransactionRepository,
                      seedRepository: transactionSeedRepository,
                      transitionGateway: transactionTransitionGateway,
                    );
                provider.bindAndInitialize(
                  proposalProvider: proposalProvider,
                  serviceRequestProvider: serviceRequestProvider,
                );
                return provider;
              },
        ),
        ChangeNotifierProvider(
          create: (_) => PrivateMessagingProvider(
            repository: SharedPreferencesPrivateConversationRepository(),
            transactionRepository: serviceTransactionRepository,
          )..initialize(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'HelpDesk Connect',
        theme: HDCTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
