import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/proposals/customer_offer_catalog.dart';
import '../../core/ui/hdc_app_shell.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/proposal.dart';
import '../../models/service_request.dart';
import '../../models/service_request_draft.dart';
import '../../models/service_transaction.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/hdc_marketplace_provider.dart';
import '../../providers/hdc_notification_center_provider.dart';
import '../../providers/hdc_sales_center_provider.dart';
import '../../providers/proposal_provider.dart';
import '../../providers/service_request_provider.dart';
import '../../providers/service_transaction_provider.dart';
import '../authentication/login_screen.dart';
import '../authentication/registered_user_gate.dart';
import '../customer_proposals/customer_offers_screen.dart';
import '../internal/internal_dashboard_screen.dart';
import '../marketplace/marketplace_catalog_screen.dart';
import '../marketplace/sales_center_screen.dart';
import '../notifications/notification_center_screen.dart';
import '../profiles/profile_center_screen.dart';
import '../roles/role_center_screen.dart';
import '../search/search_screen.dart';
import '../service_requests/create_service_request_screen.dart';
import '../service_requests/my_service_requests_screen.dart';
import '../technician_marketplace/technician_marketplace_screen.dart';
import '../transactions/my_transactions_screen.dart';
import 'widgets/dashboard_activity_timeline.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_marketplace_overview.dart';
import 'widgets/dashboard_primary_actions.dart';
import 'widgets/dashboard_quick_access.dart';
import 'widgets/dashboard_service_overview.dart';
import 'widgets/dashboard_statistics.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _openRoleCenter(BuildContext context) async {
    if (!await requireRegisteredUser(context, action: 'manage account roles')) {
      return;
    }
    if (!context.mounted) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RoleCenterScreen()));
  }

  Future<void> _openProfiles(BuildContext context) async {
    if (!await requireRegisteredUser(
      context,
      action: 'manage account profiles',
    )) {
      return;
    }
    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileCenterScreen()),
    );
  }

  void _openPrivateDashboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const InternalDashboardScreen()),
    );
  }

  Future<void> _openPostRequest(BuildContext context) async {
    if (!await requireRegisteredUser(
      context,
      action: 'post a service request',
    )) {
      return;
    }
    if (!context.mounted) return;

    Navigator.of(context)
        .push(HDCPageRoute<void>(page: const CreateServiceRequestScreen()));
  }

  Future<void> _openMyRequests(BuildContext context) async {
    if (!await requireRegisteredUser(
      context,
      action: 'view your service requests',
    )) {
      return;
    }
    if (!context.mounted) return;

    Navigator.of(context)
        .push(HDCPageRoute<void>(page: const MyServiceRequestsScreen()));
  }

  Future<void> _openTransactions(BuildContext context, String actorId) async {
    if (!await requireRegisteredUser(
      context,
      action: 'open service transactions',
    )) {
      return;
    }
    if (!context.mounted) return;

    Navigator.of(context)
        .push(HDCPageRoute<void>(page: MyTransactionsScreen(actorId: actorId)));
  }

  Future<void> _openOffers(BuildContext context) async {
    if (!await requireRegisteredUser(
      context,
      action: 'review technician offers',
    )) {
      return;
    }
    if (!context.mounted) return;

    Navigator.of(context)
        .push(HDCPageRoute<void>(page: const CustomerOffersScreen()));
  }

  void _openTechnicianSearch(BuildContext context) {
    Navigator.of(context).push(
      HDCPageRoute<void>(page: SearchScreen(draft: ServiceRequestDraft())),
    );
  }

  Future<void> _openTechnicianMarketplace(
    BuildContext context,
    HDCAuthProvider auth,
  ) async {
    if (!await requireRegisteredUser(
      context,
      action: 'access the Technician Marketplace',
    )) {
      return;
    }
    if (!context.mounted) return;

    final identity = auth.identity;
    final allowed =
        auth.authenticated &&
        identity != null &&
        identity.hasPlatformRole(HDCPlatformRole.technician);

    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Technician Marketplace is available only to registered '
            'technician accounts.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context)
        .push(HDCPageRoute<void>(page: const TechnicianMarketplaceScreen()));
  }

  Future<void> _openSalesCenter(BuildContext context) async {
    if (!await requireRegisteredUser(
      context,
      action: 'manage marketplace items and sales',
    )) {
      return;
    }
    if (!context.mounted) return;

    Navigator.of(context)
        .push(HDCPageRoute<void>(page: const SalesCenterScreen()));
  }

  void _openProductMarketplace(BuildContext context) {
    Navigator.of(context)
        .push(HDCPageRoute<void>(page: const MarketplaceCatalogScreen()));
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming in a future HDC sprint.')),
    );
  }

  Future<void> _openNotifications(BuildContext context) async {
    if (!await requireRegisteredUser(context, action: 'view notifications')) {
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context)
        .push(HDCPageRoute<void>(page: const NotificationCenterScreen()));
  }

  Future<void> _openPassport(BuildContext context) async {
    if (!await requireRegisteredUser(
      context,
      action: 'open your HDC Passport',
    )) {
      return;
    }
    if (!context.mounted) return;
    _showComingSoon(context, 'HDC Passport');
  }

  List<DashboardActivityItem> _accountActivity({
    required String actorId,
    required List<ServiceRequest> ownedRequests,
    required List<Proposal> relevantProposals,
    required List<ServiceTransaction> transactions,
  }) {
    final entries = <DashboardActivityItem>[];
    final requestsById = {
      for (final request in ownedRequests) request.id: request,
    };

    for (final request in ownedRequests) {
      entries.add(
        DashboardActivityItem(
          icon: Icons.campaign_outlined,
          color: HDCColors.info,
          title: 'Request ${request.status.label}',
          subtitle: '${request.title} • ${request.id}',
          occurredAt: request.updatedAt,
        ),
      );
    }

    for (final proposal in relevantProposals) {
      final request = requestsById[proposal.requestId];
      final received = request?.customerId == actorId;
      entries.add(
        DashboardActivityItem(
          icon: Icons.local_offer_outlined,
          color: HDCColors.warning,
          title: received
              ? 'Proposal received'
              : 'Proposal ${proposal.status.label}',
          subtitle: received
              ? '${proposal.reputation.technicianName} • ${request!.title}'
              : '${request?.title ?? proposal.requestId} • ${proposal.id}',
          occurredAt: proposal.latestLifecycleAt,
        ),
      );
    }

    for (final transaction in transactions) {
      entries.add(
        DashboardActivityItem(
          icon: transaction.status == ServiceTransactionStatus.completed
              ? Icons.check_circle_outline
              : Icons.handshake_outlined,
          color: transaction.status == ServiceTransactionStatus.completed
              ? HDCColors.success
              : HDCColors.primary,
          title: 'Service ${transaction.status.label}',
          subtitle: '${transaction.requestTitle} • ${transaction.id}',
          occurredAt: transaction.updatedAt,
        ),
      );
    }

    entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return entries.take(5).toList(growable: false);
  }

  Future<void> _signOut(BuildContext context, HDCAuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(auth.guestMode ? 'Exit Guest mode?' : 'Sign out of HDC?'),
          content: Text(
            auth.guestMode
                ? 'You will return to the HDC sign-in screen.'
                : 'You will need to sign in again to access your account, '
                      'service requests, transactions, and private conversations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.logout),
              label: Text(auth.guestMode ? 'Exit Guest' : 'Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await auth.signOut();

      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on Object catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not sign out: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<HDCAuthProvider>();
    final actorId = auth.currentUserId ?? 'guest-local';
    final isRegisteredUser =
        auth.authenticated && !auth.guestMode && auth.identity != null;
    final hasPrivateWorkspace =
        isRegisteredUser && auth.identity!.internalRoles.isNotEmpty;
    final requestProvider = context.watch<ServiceRequestProvider>();
    final proposalProvider = context.watch<ProposalProvider>();
    final transactionProvider = context.watch<ServiceTransactionProvider>();
    final marketplaceProvider = context.watch<HdcMarketplaceProvider>();
    final salesProvider = context.watch<HdcSalesCenterProvider>();
    final notificationCenter = context.watch<HdcNotificationCenterProvider>();
    final platformRoleLabels = [
      ...?auth.identity?.platformRoles.map((role) => role.label),
    ]..sort();

    final ownedRequests = isRegisteredUser
        ? requestProvider.requests
              .where((request) => request.customerId == actorId)
              .toList(growable: false)
        : const <ServiceRequest>[];
    final ownedRequestIds = ownedRequests.map((request) => request.id).toSet();
    final receivedProposals = isRegisteredUser
        ? const CustomerOfferCatalog()
              .entriesFor(
                customerId: actorId,
                requests: requestProvider.requests,
                proposals: proposalProvider.proposals,
              )
              .map((entry) => entry.proposal)
              .toList(growable: false)
        : const <Proposal>[];
    final relevantProposals = isRegisteredUser
        ? proposalProvider.proposals
              .where(
                (proposal) =>
                    ownedRequestIds.contains(proposal.requestId) ||
                    proposal.technicianId == actorId,
              )
              .where((proposal) => proposal.status != ProposalStatus.draft)
              .where((proposal) => proposal.status != ProposalStatus.withdrawn)
              .toList(growable: false)
        : const <Proposal>[];
    final accountTransactions = isRegisteredUser
        ? transactionProvider.transactions
              .where((transaction) => transaction.isParticipant(actorId))
              .toList(growable: false)
        : const <ServiceTransaction>[];
    final activeRequests = ownedRequests
        .where((request) => request.status.isActive)
        .length;
    final totalOffers = receivedProposals.length;
    final activeTransactions = accountTransactions
        .where((transaction) => transaction.status.isActive)
        .length;
    final completedServiceCount = accountTransactions
        .where(
          (transaction) =>
              transaction.status == ServiceTransactionStatus.completed,
        )
        .length;
    final accountActivity = isRegisteredUser
        ? _accountActivity(
            actorId: actorId,
            ownedRequests: ownedRequests,
            relevantProposals: relevantProposals,
            transactions: accountTransactions,
          )
        : const <DashboardActivityItem>[];

    final isTechnician =
        auth.authenticated &&
        auth.identity?.hasPlatformRole(HDCPlatformRole.technician) == true;
    final primaryNavigation = <HDCNavigationItem>[
      HDCNavigationItem(
        label: 'Overview',
        icon: Icons.space_dashboard_outlined,
        selected: true,
        onTap: () {},
      ),
      HDCNavigationItem(
        label: 'Post a Service Request',
        icon: Icons.add_task_rounded,
        onTap: () => _openPostRequest(context),
      ),
      HDCNavigationItem(
        label: 'Active Services',
        icon: Icons.handshake_outlined,
        badgeCount: activeTransactions,
        onTap: () => _openTransactions(context, actorId),
      ),
      HDCNavigationItem(
        label: 'My Service Requests',
        icon: Icons.campaign_outlined,
        badgeCount: activeRequests,
        onTap: () => _openMyRequests(context),
      ),
      HDCNavigationItem(
        label: 'Offers',
        icon: Icons.local_offer_outlined,
        badgeCount: totalOffers,
        onTap: () => _openOffers(context),
      ),
      HDCNavigationItem(
        label: 'Find a Technician',
        icon: Icons.manage_search_rounded,
        onTap: () => _openTechnicianSearch(context),
      ),
      if (isTechnician)
        HDCNavigationItem(
          label: 'Technician Jobs',
          icon: Icons.engineering_outlined,
          onTap: () => _openTechnicianMarketplace(context, auth),
        ),
      HDCNavigationItem(
        label: 'Shop Technology',
        icon: Icons.storefront_outlined,
        onTap: () => _openProductMarketplace(context),
      ),
    ];
    final secondaryNavigation = <HDCNavigationItem>[
      HDCNavigationItem(
        label: 'Notifications',
        icon: Icons.notifications_none_rounded,
        badgeCount: notificationCenter.unreadCount,
        onTap: () => _openNotifications(context),
      ),
      HDCNavigationItem(
        label: 'Profiles & Workspaces',
        icon: Icons.account_circle_outlined,
        onTap: () => _openProfiles(context),
      ),
      HDCNavigationItem(
        label: 'Role Center',
        icon: Icons.badge_outlined,
        onTap: () => _openRoleCenter(context),
      ),
      HDCNavigationItem(
        label: 'HDC Passport',
        icon: Icons.fingerprint_rounded,
        onTap: () => _openPassport(context),
      ),
      if (hasPrivateWorkspace)
        HDCNavigationItem(
          label: 'Private Operations',
          icon: Icons.admin_panel_settings_outlined,
          onTap: () => _openPrivateDashboard(context),
        ),
    ];

    return HDCAppShell(
      workspaceLabel: auth.guestMode ? 'Guest Preview' : 'Public Workspace',
      userLabel: auth.guestMode
          ? 'Guest session'
          : platformRoleLabels.isEmpty
          ? auth.displayName
          : '${auth.displayName}\n${platformRoleLabels.join(' • ')}',
      primaryItems: primaryNavigation,
      secondaryItems: secondaryNavigation,
      notificationCount: notificationCenter.unreadCount,
      onNotifications: () => _openNotifications(context),
      onSignOut: () {
        if (!auth.isBusy) {
          _signOut(context, auth);
        }
      },
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 18,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DashboardHeader(
                        displayName: auth.displayName,
                        activeTransactions: activeTransactions,
                        newOffers: totalOffers,
                        guestMode: auth.guestMode,
                        platformRoleLabels: platformRoleLabels,
                        email: auth.identity?.email,
                        accountId:
                            auth.identity?.publicMemberId ?? auth.identity?.id,
                      ),
                      const SizedBox(height: 24),
                      DashboardPrimaryActions(
                        onPostRequest: () => _openPostRequest(context),
                        onFindTechnician: () => _openTechnicianSearch(context),
                        onShopTechnology: () =>
                            _openProductMarketplace(context),
                      ),
                      const SizedBox(height: 24),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  DashboardServiceOverview(
                                    activeTransactionCount: activeTransactions,
                                    activeRequestCount: activeRequests,
                                    offerCount: totalOffers,
                                    onViewTransactions: () =>
                                        _openTransactions(context, actorId),
                                    onPostRequest: () =>
                                        _openPostRequest(context),
                                    onFindTechnician: () =>
                                        _openTechnicianSearch(context),
                                    onViewOffers: () => _openOffers(context),
                                    onViewRequests: () =>
                                        _openMyRequests(context),
                                  ),
                                  const SizedBox(height: 24),
                                  DashboardMarketplaceOverview(
                                    guestMode: auth.guestMode,
                                    canSell: salesProvider.canSell,
                                    hasListingHistory:
                                        salesProvider.hasListingHistory,
                                    isLoading: salesProvider.isLoading,
                                    isCatalogLoading:
                                        marketplaceProvider.isLoadingCatalog,
                                    availableProductCount: marketplaceProvider
                                        .availableProductCount,
                                    pendingBuyerPurchaseCount:
                                        marketplaceProvider
                                            .pendingPurchaseCount,
                                    activeListingCount:
                                        salesProvider.activeListingCount,
                                    soldListingCount:
                                        salesProvider.soldListingCount,
                                    lowStockListingCount:
                                        salesProvider.lowStockListingCount,
                                    pendingPurchaseRequestCount: salesProvider
                                        .pendingPurchaseRequestCount,
                                    onBrowseProducts: () =>
                                        _openProductMarketplace(context),
                                    onOpenSalesCenter: () =>
                                        _openSalesCenter(context),
                                    onOpenRoleCenter: () =>
                                        _openRoleCenter(context),
                                  ),
                                  const SizedBox(height: 24),
                                  DashboardStatistics(
                                    openRequestCount: activeRequests,
                                    offerCount: totalOffers,
                                    activeServiceCount: activeTransactions,
                                    completedServiceCount:
                                        completedServiceCount,
                                    guestMode: auth.guestMode,
                                  ),
                                  const SizedBox(height: 24),
                                  DashboardActivityTimeline(
                                    guestMode: auth.guestMode,
                                    entries: accountActivity,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: DashboardQuickAccess(
                                onTransactions: () =>
                                    _openTransactions(context, actorId),
                                onRequests: () => _openMyRequests(context),
                                onMarketplace: () =>
                                    _openTechnicianMarketplace(context, auth),
                                onPassport: () => _openPassport(context),
                                onRoleCenter: () => _openRoleCenter(context),
                                canAccessMarketplace:
                                    auth.authenticated &&
                                    auth.identity?.hasPlatformRole(
                                          HDCPlatformRole.technician,
                                        ) ==
                                        true,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        DashboardServiceOverview(
                          activeTransactionCount: activeTransactions,
                          activeRequestCount: activeRequests,
                          offerCount: totalOffers,
                          onViewTransactions: () =>
                              _openTransactions(context, actorId),
                          onPostRequest: () => _openPostRequest(context),
                          onFindTechnician: () =>
                              _openTechnicianSearch(context),
                          onViewOffers: () => _openOffers(context),
                          onViewRequests: () => _openMyRequests(context),
                        ),
                        const SizedBox(height: 24),
                        DashboardMarketplaceOverview(
                          guestMode: auth.guestMode,
                          canSell: salesProvider.canSell,
                          hasListingHistory: salesProvider.hasListingHistory,
                          isLoading: salesProvider.isLoading,
                          isCatalogLoading:
                              marketplaceProvider.isLoadingCatalog,
                          availableProductCount:
                              marketplaceProvider.availableProductCount,
                          pendingBuyerPurchaseCount:
                              marketplaceProvider.pendingPurchaseCount,
                          activeListingCount: salesProvider.activeListingCount,
                          soldListingCount: salesProvider.soldListingCount,
                          lowStockListingCount:
                              salesProvider.lowStockListingCount,
                          pendingPurchaseRequestCount:
                              salesProvider.pendingPurchaseRequestCount,
                          onBrowseProducts: () =>
                              _openProductMarketplace(context),
                          onOpenSalesCenter: () => _openSalesCenter(context),
                          onOpenRoleCenter: () => _openRoleCenter(context),
                        ),
                        const SizedBox(height: 24),
                        DashboardStatistics(
                          openRequestCount: activeRequests,
                          offerCount: totalOffers,
                          activeServiceCount: activeTransactions,
                          completedServiceCount: completedServiceCount,
                          guestMode: auth.guestMode,
                        ),
                        const SizedBox(height: 24),
                        DashboardQuickAccess(
                          onTransactions: () =>
                              _openTransactions(context, actorId),
                          onRequests: () => _openMyRequests(context),
                          onMarketplace: () =>
                              _openTechnicianMarketplace(context, auth),
                          onPassport: () => _openPassport(context),
                          onRoleCenter: () => _openRoleCenter(context),
                          canAccessMarketplace:
                              auth.authenticated &&
                              auth.identity?.hasPlatformRole(
                                    HDCPlatformRole.technician,
                                  ) ==
                                  true,
                        ),
                        const SizedBox(height: 24),
                        DashboardActivityTimeline(
                          guestMode: auth.guestMode,
                          entries: accountActivity,
                        ),
                      ],
                      const SizedBox(height: 32),
                      const Center(
                        child: Text(
                          'HelpDesk Connect Beta v0.6.4 Build 24',
                          style: TextStyle(color: HDCColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
