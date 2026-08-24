import 'package:flutter/material.dart';

class ServiceCategory {
  final String id;
  final String name;
  final IconData icon;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class HDCCategories {
  static const List<ServiceCategory> all = [
    ServiceCategory(
      id: 'computer_repair',
      name: 'Computer Repair',
      icon: Icons.desktop_windows,
    ),
    ServiceCategory(
      id: 'laptop_repair',
      name: 'Laptop Repair',
      icon: Icons.laptop,
    ),
    ServiceCategory(
      id: 'mobile_device_repair',
      name: 'Mobile Device Repair',
      icon: Icons.phone_android,
    ),
    ServiceCategory(
      id: 'printer_repair',
      name: 'Printer Repair',
      icon: Icons.print,
    ),
    ServiceCategory(
      id: 'network_installation',
      name: 'Network Installation',
      icon: Icons.router,
    ),
    ServiceCategory(
      id: 'cctv_installation',
      name: 'CCTV Installation',
      icon: Icons.videocam,
    ),
    ServiceCategory(
      id: 'pos_support',
      name: 'POS Support',
      icon: Icons.point_of_sale,
    ),
    ServiceCategory(
      id: 'server_support',
      name: 'Server & Storage Support',
      icon: Icons.dns,
    ),
    ServiceCategory(
      id: 'software_installation',
      name: 'Software Installation',
      icon: Icons.install_desktop,
    ),
    ServiceCategory(
      id: 'virus_removal',
      name: 'Virus Removal',
      icon: Icons.security,
    ),
    ServiceCategory(
      id: 'data_recovery',
      name: 'Data Recovery',
      icon: Icons.storage,
    ),
    ServiceCategory(
      id: 'tech_electrical_support',
      name: 'Technology Power & Electrical Support',
      icon: Icons.electrical_services,
    ),
    ServiceCategory(
      id: 'other_technology',
      name: 'Other Technology Service',
      icon: Icons.memory,
    ),
  ];
}
