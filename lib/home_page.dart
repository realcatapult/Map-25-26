import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
  'MapApp', // 
  style: TextStyle(
    fontSize: 32, // 
    fontWeight: FontWeight.bold, 
  ),
),
SizedBox(height: 40), //spacing 

              ],
            ), 
          ),
        ),
      ),
    );
  }
}
