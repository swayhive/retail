import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Stripe
  await Stripe.instance.applySettings();
  Stripe.publishableKey = 'your_stripe_publishable_key';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Commerce App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ProductListScreen(),
    );
  }
}

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  ProductListScreenState createState() => ProductListScreenState();
}

class ProductListScreenState extends State<ProductListScreen> {
  bool _isLoading = true;
  List<Product> _products = [];
  final List<Product> _cart = [];
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
    _loadProducts();
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authToken = prefs.getString('auth_token');
    });
  }

  Future<void> _login() async {
    // Implement login logic here
    // For example, show a login dialog and make an API call
    // On successful login, save the auth token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'example_auth_token');
    setState(() {
      _authToken = 'example_auth_token';
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    setState(() {
      _authToken = null;
    });
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(Uri.parse('https://api.example.com/products'));
      if (response.statusCode == 200) {
        final List<dynamic> productsJson = json.decode(response.body);
        setState(() {
          _products = productsJson.map((json) => Product.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  void _addToCart(Product product) {
    setState(() {
      _cart.add(product);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} added to cart')),
      );
    }
  }

  void _viewCart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CartScreen(cart: _cart),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Commerce App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: ProductSearch(_products));
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _viewCart,
          ),
          IconButton(
            icon: Icon(_authToken == null ? Icons.login : Icons.logout),
            onPressed: _authToken == null ? _login : _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ListTile(
                  leading: Image.asset(product.image, width: 50, height: 50, fit: BoxFit.cover),
                  title: Text(product.name),
                  subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_shopping_cart),
                    onPressed: () => _addToCart(product),
                  ),
                );
              },
            ),
    );
  }
}

class CartScreen extends StatelessWidget {
  final List<Product> cart;

  const CartScreen({super.key, required this.cart});

  double get total => cart.fold(0, (sum, product) => sum + product.price);

  Future<void> _processPayment(BuildContext context) async {
    try {
      // Create a payment intent on your server
      final response = await http.post(
        Uri.parse('https://api.example.com/create-payment-intent'),
        body: {'amount': (total * 100).round().toString(), 'currency': 'usd'},
      );

      final paymentIntentData = json.decode(response.body);

      // Confirm the payment with Stripe
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['client_secret'],
          style: ThemeMode.dark,
          merchantDisplayName: 'Your Store Name',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment completed!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final product = cart[index];
                return ListTile(
                  leading: Image.asset(product.image, width: 50, height: 50, fit: BoxFit.cover),
                  title: Text(product.name),
                  subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _processPayment(context),
            child: const Text('Checkout'),
          ),
        ],
      ),
    );
  }
}

class Product {
  final int id;
  final String name;
  final double price;
  final String image;

  Product({required this.id, required this.name, required this.price, required this.image});

  Product.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        price = json['price'].toDouble(),
        image = json['image'];
}

class ProductSearch extends SearchDelegate<Product> {
  final List<Product> products;

  ProductSearch(this.products);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, Product(id: -1, name: '', price: 0, image: ''));
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? products
        : products.where((product) =>
            product.name.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final product = suggestions[index];
        return ListTile(
          leading: Image.network(product.image, width: 50, height: 50, fit: BoxFit.cover),
          title: Text(product.name),
          subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
          onTap: () {
            close(context, product);
          },
        );
      },
    );
  }
}
