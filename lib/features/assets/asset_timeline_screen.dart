import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/asset_history_provider.dart';

class AssetTimelineScreen extends StatelessWidget {
  final String assetId;

  const AssetTimelineScreen({
    super.key,
    required this.assetId,
  });

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<AssetHistoryProvider>();

    final events =
        provider.getHistory(assetId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Asset Timeline"),
      ),
      body: events.isEmpty
          ? const Center(
              child: Text(
                "No history available.",
              ),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.all(20),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];

                final isLast =
                    index == events.length - 1;

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Column(
                      children: [

                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              event.color,
                          child: Icon(
                            event.icon,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),

                        if (!isLast)
                          Container(
                            width: 2,
                            height: 70,
                            color:
                                Colors.grey.shade300,
                          ),
                      ],
                    ),

                    const SizedBox(width: 18),

                    Expanded(
                      child: Card(
                        margin:
                            const EdgeInsets.only(
                          bottom: 20,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [

                              Text(
                                event.title,
                                style:
                                    const TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const SizedBox(
                                height: 6,
                              ),

                              Text(
                                event.description,
                              ),

                              const SizedBox(
                                height: 10,
                              ),

                              Text(
                                event.createdAt
                                    .toLocal()
                                    .toString(),
                                style:
                                    TextStyle(
                                  color: Colors
                                      .grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}