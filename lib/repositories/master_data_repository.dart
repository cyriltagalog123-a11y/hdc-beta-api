import 'package:flutter/material.dart';

class ServiceCategory {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class MasterDataRepository {
  MasterDataRepository._();

  static final MasterDataRepository instance = MasterDataRepository._();

  Future<List<ServiceCategory>> getServiceCategories() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return const [
      ServiceCategory(
        id: 'computer_repair',
        name: 'Computer Repair',
        description: 'Desktop diagnostics, upgrades and repairs.',
        icon: Icons.desktop_windows,
      ),
      ServiceCategory(
        id: 'laptop_repair',
        name: 'Laptop Repair',
        description: 'Laptop troubleshooting and hardware replacement.',
        icon: Icons.laptop,
      ),
      ServiceCategory(
        id: 'mobile_device_repair',
        name: 'Mobile Device Repair',
        description: 'Phone and tablet diagnostics, repair and setup.',
        icon: Icons.phone_android,
      ),
      ServiceCategory(
        id: 'printer_repair',
        name: 'Printer Repair',
        description: 'Printer setup, maintenance and repair.',
        icon: Icons.print,
      ),
      ServiceCategory(
        id: 'network_installation',
        name: 'Network Installation',
        description: 'LAN, Wi-Fi, routers, switches and structured cabling.',
        icon: Icons.router,
      ),
      ServiceCategory(
        id: 'cctv_installation',
        name: 'CCTV Installation',
        description: 'Technology security cameras, NVRs and related networking.',
        icon: Icons.videocam,
      ),
      ServiceCategory(
        id: 'pos_support',
        name: 'POS Support',
        description: 'Restaurant and retail POS, KDS and peripheral support.',
        icon: Icons.point_of_sale,
      ),
      ServiceCategory(
        id: 'server_support',
        name: 'Server & Storage Support',
        description: 'Servers, NAS, storage, backup and infrastructure support.',
        icon: Icons.dns,
      ),
      ServiceCategory(
        id: 'software_installation',
        name: 'Software Installation',
        description: 'Operating systems and software setup.',
        icon: Icons.install_desktop,
      ),
      ServiceCategory(
        id: 'virus_removal',
        name: 'Virus Removal',
        description: 'Malware cleanup and endpoint protection.',
        icon: Icons.security,
      ),
      ServiceCategory(
        id: 'data_recovery',
        name: 'Data Recovery',
        description: 'Recover deleted or damaged files from technology devices.',
        icon: Icons.storage,
      ),
      ServiceCategory(
        id: 'tech_electrical_support',
        name: 'Technology Power & Electrical Support',
        description:
            'UPS, PoE, device power and technology-related electrical diagnostics. '
            'High-risk work may require a licensed electrician.',
        icon: Icons.electrical_services,
      ),
      ServiceCategory(
        id: 'other_technology',
        name: 'Other Technology Service',
        description: 'Technology-device or IT services not listed above.',
        icon: Icons.memory,
      ),
    ];
  }
}
