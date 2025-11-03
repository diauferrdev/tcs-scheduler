import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sched_fe/utils/responsive_helper.dart';

class LandingHeader extends StatelessWidget {
  final bool isLoggedIn;

  const LandingHeader({
    super.key,
    this.isLoggedIn = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      height: isMobile ? 64 : 80,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 80),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo - TCS Pace com brand correto
          SvgPicture.asset(
            'assets/logos/tcs-pace-logo-w.svg',
            height: isMobile ? 24 : 32,
          ),

          const Spacer(),

          // Navigation button
          isMobile
              ? IconButton(
                  onPressed: () {
                    if (isLoggedIn) {
                      context.go('/app');
                    } else {
                      context.go('/login');
                    }
                  },
                  icon: Icon(
                    isLoggedIn ? Icons.dashboard : Icons.login,
                    size: 20,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isLoggedIn
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.15),
                    padding: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: () {
                    if (isLoggedIn) {
                      context.go('/app');
                    } else {
                      context.go('/login');
                    }
                  },
                  icon: Icon(
                    isLoggedIn ? Icons.dashboard : Icons.login,
                    size: 18,
                  ),
                  label: Text(
                    isLoggedIn ? 'Open App' : 'Sign In',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'NeueHaasGrotesk',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLoggedIn
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white,
                    foregroundColor: isLoggedIn ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: isLoggedIn
                          ? BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1)
                          : BorderSide.none,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
