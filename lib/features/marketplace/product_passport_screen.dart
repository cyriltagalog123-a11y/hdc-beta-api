import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../widgets/passport/passport_header.dart';
import '../../widgets/passport/passport_section.dart';

class ProductPassportScreen
    extends StatelessWidget {

  final Product product;

  const ProductPassportScreen({

    super.key,

    required this.product,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Product Passport",
        ),
      ),

      body: SingleChildScrollView(

        padding:
            const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            PassportHeader(

              title: product.name,

              subtitle:
                  "Category ID: ${product.categoryId}",

              status: Chip(

                label: Text(
                  product.active
                      ? "ACTIVE"
                      : "INACTIVE",
                ),

                backgroundColor:
                    product.active
                        ? Colors.green
                        : Colors.red,
              ),
            ),

            PassportSection(

              title: "Overview",

              child: Card(

                child: ListTile(

                  title: Text(
                      product.description),

                  subtitle: Text(
                    "Price: \$${product.price.toStringAsFixed(2)}\n"
                    "Stock: ${product.stock}",
                  ),
                ),
              ),
            ),

            PassportSection(

              title: "Timeline",

              child: const Card(

                child: Padding(

                  padding:
                      EdgeInsets.all(20),

                  child: Text(
                    "Timeline integration coming soon.",
                  ),
                ),
              ),
            ),

            PassportSection(

              title: "Audit",

              child: const Card(

                child: Padding(

                  padding:
                      EdgeInsets.all(20),

                  child: Text(
                    "Audit integration coming soon.",
                  ),
                ),
              ),
            ),

            PassportSection(

              title: "Nexus Insight",

              child: const Card(

                child: Padding(

                  padding:
                      EdgeInsets.all(20),

                  child: Text(

                    "Nexus Insight\n\n"
                    "Analytics will be available in future versions. "
                    "Nexus will recommend restocking, analyze supplier "
                    "performance, and predict demand.",

                    style: TextStyle(
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}