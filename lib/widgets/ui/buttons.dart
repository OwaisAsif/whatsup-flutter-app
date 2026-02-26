import 'package:flutter/material.dart';
import 'package:whatsup/widgets/ui/colors.dart';

class Buttons {
  static Widget primary(String text, VoidCallback onPressed, bool isLoading) {
    return _buildButton(text, onPressed, isLoading, "primary");
  }

  static Widget secondary(String text, VoidCallback onPressed, bool isLoading) {
    return _buildButton(text, onPressed, isLoading, "secondary");
  }

  static Widget success(String text, VoidCallback onPressed, bool isLoading) {
    return _buildButton(text, onPressed, isLoading, "success");
  }

  static Widget error(String text, VoidCallback onPressed, bool isLoading) {
    return _buildButton(text, onPressed, isLoading, "error");
  }

  static Widget warning(String text, VoidCallback onPressed, bool isLoading) {
    return _buildButton(text, onPressed, isLoading, "warning");
  }

  static Widget _buildButton(
    String text,
    VoidCallback onPressed,
    bool isLoading,
    String type,
  ) {
    var bg;
    var fg;

    switch (type) {
      case "primary":
        bg = kprimaryColor;
        fg = kwhiteColor;
        break;
      case "secondary":
        bg = kinfoColor;
        fg = kwhiteColor;
        break;
      case "success":
        bg = ksuccessColor;
        fg = kwhiteColor;
        break;
      case "error":
        bg = kerrorColor;
        fg = kwhiteColor;
        break;
      case "warning":
        bg = kwarningColor;
        fg = kwhiteColor;
        break;
      default:
        bg = kprimaryColor;
        fg = kwhiteColor;
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 40),
        backgroundColor: bg,
        foregroundColor: fg,
      ),
      child: isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(text, style: const TextStyle(fontSize: 16)),
    );
  }
}
