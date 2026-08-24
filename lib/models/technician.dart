import 'package:flutter/material.dart';

class Technician {
  final String id;

  final String name;

  final String specialty;

  final double rating;

  final int completedJobs;

  final double distanceKm;

  final int responseMinutes;

  final bool verified;

  final bool available;

  final String about;

  final List<String> skills;

  final String? companyName;

  final String? photoUrl;

  const Technician({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.completedJobs,
    required this.distanceKm,
    required this.responseMinutes,
    required this.verified,
    required this.available,
    required this.about,
    required this.skills,
    this.companyName,
    this.photoUrl,
  });

  IconData get availabilityIcon =>
      available ? Icons.check_circle : Icons.schedule;

  Color get availabilityColor =>
      available ? Colors.green : Colors.orange;

  String get availabilityText =>
      available ? "Available Now" : "Busy";

  String get responseText =>
      "Responds in $responseMinutes mins";

  String get distanceText =>
      "${distanceKm.toStringAsFixed(1)} km";

  String get completedJobsText =>
      "$completedJobs Jobs";
}
