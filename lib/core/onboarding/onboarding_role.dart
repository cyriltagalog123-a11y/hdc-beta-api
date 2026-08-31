enum OnboardingRole {
  buyer,
  technician,
  seller,
  store,
}

extension OnboardingRoleDetails on OnboardingRole {
  String get flowId {
    switch (this) {
      case OnboardingRole.buyer:
        return 'buyer_v1';
      case OnboardingRole.technician:
        return 'technician_v1';
      case OnboardingRole.seller:
        return 'seller_v1';
      case OnboardingRole.store:
        return 'store_v1';
    }
  }

  String get title {
    switch (this) {
      case OnboardingRole.buyer:
        return 'HDC Marketplace';
      case OnboardingRole.technician:
        return 'HDC Technician';
      case OnboardingRole.seller:
        return 'HDC Seller';
      case OnboardingRole.store:
        return 'HDC Store Management';
    }
  }

  String get welcomeTitle {
    switch (this) {
      case OnboardingRole.buyer:
        return 'Welcome to the HDC Marketplace';
      case OnboardingRole.technician:
        return 'Welcome to HDC Technician';
      case OnboardingRole.seller:
        return 'Welcome to HDC Seller';
      case OnboardingRole.store:
        return 'Welcome to HDC Store Management';
    }
  }

  String get description {
    switch (this) {
      case OnboardingRole.buyer:
        return 'Discover verified sellers, compare products and services, '
            'and keep orders, warranties, and support in one place.';
      case OnboardingRole.technician:
        return 'Build your professional profile, discover open service '
            'requests, send offers, and manage active jobs.';
      case OnboardingRole.seller:
        return 'Create product listings, manage inventory and orders, and '
            'support buyers through transaction-based conversations.';
      case OnboardingRole.store:
        return 'Manage branches, departments, employees, assets, service requests, '
            'and technician visits from one workspace.';
    }
  }

  String get primaryActionLabel {
    switch (this) {
      case OnboardingRole.buyer:
        return 'Explore Marketplace';
      case OnboardingRole.technician:
        return 'Set Up Technician Profile';
      case OnboardingRole.seller:
        return 'Set Up Seller Account';
      case OnboardingRole.store:
        return 'Set Up Store';
    }
  }

  List<String> get checklist {
    switch (this) {
      case OnboardingRole.buyer:
        return const [
          'Browse verified sellers and stores',
          'Compare products, prices, and services',
          'Track orders, receipts, and warranties',
          'Open support from a completed transaction',
        ];
      case OnboardingRole.technician:
        return const [
          'Complete your professional profile',
          'Select specialties and service coverage',
          'Set availability and response preferences',
          'Browse open requests and send offers',
          'Manage jobs, ratings, and service history',
        ];
      case OnboardingRole.seller:
        return const [
          'Complete seller verification',
          'Add products, services, and pricing',
          'Manage stock and incoming orders',
          'Use transaction messaging for buyer support',
          'Monitor sales and after-sales cases',
        ];
      case OnboardingRole.store:
        return const [
          'Complete the store profile',
          'Add branches, departments, and employees',
          'Register store products and assets',
          'Manage service requests and technician visits',
          'Review store activity and performance',
        ];
    }
  }
}
