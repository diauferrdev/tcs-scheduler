import 'package:flutter/material.dart';

class Untitled extends StatefulWidget {
  final double? width;
  final double? height;

  const Untitled({
    super.key,
    this.width,
    this.height,
  });

  @override
  UntitledState createState() => UntitledState();
}

class UntitledState extends State<Untitled> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
