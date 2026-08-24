import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/product_provider.dart';
import '../../widgets/entity_card.dart';
import '../../widgets/status_badge.dart';
import 'product_passport_screen.dart';

class ProductCatalogScreen extends StatelessWidget {

  const ProductCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final provider =
        context.watch<ProductProvider>();

    final products =
        provider.products;

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Product Catalog",
        ),
      ),

      body: ListView.builder(

        itemCount: products.length,

        itemBuilder: (context, index) {

          final product =
              products[index];

          return EntityCard(

            title: product.name,

            subtitle:
                "\$${product.price.toStringAsFixed(2)} • Stock: ${product.stock}",

            trailing: StatusBadge(

              text: product.active
                  ? "ACTIVE"
                  : "INACTIVE",

              color: product.active
                  ? Colors.green
                  : Colors.red,
            ),

            onTap: () {

              Navigator.push(

                context,

                MaterialPageRoute(

                  builder: (_) =>
                      ProductPassportScreen(
                    product: product,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}