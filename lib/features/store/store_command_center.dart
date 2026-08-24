import 'package:flutter/material.dart';

import '../../core/dashboard/dashboard_registry.dart';

class StoreCommandCenter extends StatelessWidget {
  const StoreCommandCenter({
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    final widgets =
        DashboardRegistry.instance.widgets;

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Store Command Center",
        ),
      ),

      body: Padding(

        padding: const EdgeInsets.all(16),

        child: GridView.builder(

          itemCount: widgets.length,

          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(

            crossAxisCount: 2,

            crossAxisSpacing: 16,

            mainAxisSpacing: 16,

          ),

          itemBuilder: (context, index) {

            final widgetData =
                widgets[index];

            return Card(

              elevation: 3,

              child: InkWell(

                onTap: () {

                  Navigator.push(

                    context,

                    MaterialPageRoute(

                      builder: (_) =>
                          Scaffold(

                        appBar: AppBar(
                          title: Text(
                            widgetData.title,
                          ),
                        ),

                        body:
                            widgetData.builder(
                                context),
                      ),
                    ),
                  );
                },

                child: Column(

                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: [

                    Icon(
                      widgetData.icon,
                      size: 50,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      widgetData.title,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}