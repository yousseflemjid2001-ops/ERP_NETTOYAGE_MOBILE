import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The official Nettoyage Plus logo SVG definition
const String kAppLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="proGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0047AB"/>
      <stop offset="100%" stop-color="#00C4CC"/>
    </linearGradient>
  </defs>
  <circle cx="32" cy="32" r="30" fill="url(#proGrad)"/>
  <path d="M18 18 v28 h6 v-16 l16 16 h6 v-28 h-6 v16 l-16 -16 h-6 Z
           M42 22 C42 26 38 30 34 30 C38 30 42 34 42 38 C42 34 46 30 50 30 C46 30 42 26 42 22 Z" 
        fill="#FFFFFF"/>
</svg>
''';

class AppLogo extends StatelessWidget {
  final double size;
  final bool hasShadow;

  const AppLogo({
    super.key,
    this.size = 64,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget svgWidget = SvgPicture.string(
      kAppLogoSvg,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (!hasShadow) {
      return svgWidget;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0047AB).withOpacity(0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: svgWidget,
    );
  }
}
