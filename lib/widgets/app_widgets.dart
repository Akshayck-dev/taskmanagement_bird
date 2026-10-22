import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/app_models.dart';
import '../services/firebase_service.dart';

class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final List<Color>? gradientColors;
  final Color? textColor;
  final Widget? icon;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradientColors,
    this.textColor,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isWhiteBtn = widget.gradientColors != null && widget.gradientColors!.first == Colors.white;

    final bgColor = isWhiteBtn
        ? (isDark ? const Color(0xFF1E1E24) : Colors.white)
        : primaryColor;
    final strokeColor = isWhiteBtn
        ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08))
        : Colors.transparent;
    final textCol = widget.textColor ?? (isWhiteBtn ? (isDark ? Colors.white : Colors.black87) : Colors.white);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) => widget.isLoading ? null : _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: strokeColor, width: 1),
            boxShadow: [
              if (!isWhiteBtn)
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              else if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: textCol,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textCol,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Shown when a Firestore stream fails (offline, rules, etc.) instead of
/// leaving the screen stuck on a skeleton loader forever.
class StreamErrorView extends StatelessWidget {
  final String message;
  const StreamErrorView({super.key, this.message = 'Something went wrong while loading. Please check your connection and try again.'});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: isDark ? Colors.white30 : Colors.black26),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black54, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared UI kit (attractive + smooth pass)
// ---------------------------------------------------------------------------

/// Brand gradient used by hero surfaces and primary accents.
const List<Color> kBrandGradient = [Color(0xFF6D5DF6), Color(0xFF9B5CF6), Color(0xFF5B8DEF)];

/// Icon + colour identity per task category.
IconData categoryIcon(String category) {
  switch (category) {
    case 'Design':
      return Icons.palette_rounded;
    case 'Development':
      return Icons.code_rounded;
    case 'Marketing':
      return Icons.campaign_rounded;
    case 'Operations':
      return Icons.settings_rounded;
    case 'Personal':
      return Icons.person_rounded;
    default:
      return Icons.folder_rounded;
  }
}

Color categoryColor(String category) {
  switch (category) {
    case 'Design':
      return const Color(0xFFEC4899);
    case 'Development':
      return const Color(0xFF6366F1);
    case 'Marketing':
      return const Color(0xFFF59E0B);
    case 'Operations':
      return const Color(0xFF14B8A6);
    case 'Personal':
      return const Color(0xFF22C55E);
    default:
      return const Color(0xFF64748B);
  }
}

Color priorityColorOf(String priority) {
  switch (priority) {
    case 'High':
      return const Color(0xFFEF4444);
    case 'Low':
      return const Color(0xFF3B82F6);
    default:
      return const Color(0xFFF59E0B);
  }
}

/// Small tinted chip with an icon — replaces the old emoji-dot badges.
class IconChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const IconChip({super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades + slides a list item in once, staggered by [index].
/// Keep the item keyed (e.g. ValueKey(task.id)) in list builders so
/// stream updates don't replay the animation.
class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  const StaggeredFadeIn({super.key, required this.index, required this.child});

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    final delay = (widget.index.clamp(0, 12)) * 45;
    if (delay == 0) {
      _controller.forward();
    } else {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Animated integer counter (0 -> value) for stat numbers.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String suffix;
  const AnimatedCount({super.key, required this.value, this.style, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Circular progress ring with an animated sweep and a centre label.
class ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final double strokeWidth;
  final String label;
  final Color trackColor;
  final Color progressColor;
  final TextStyle? labelStyle;
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 76,
    this.strokeWidth = 8,
    required this.label,
    this.trackColor = const Color(0x33FFFFFF),
    this.progressColor = Colors.white,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(v, trackColor, progressColor, strokeWidth),
              ),
              Text(label, style: labelStyle ?? const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color fg;
  final double stroke;
  _RingPainter(this.progress, this.track, this.fg, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    final fgPaint = Paint()
      ..color = fg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.fg != fg || old.track != track;
}

/// Shimmering placeholder block for skeleton loaders.
class ShimmerBlock extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const ShimmerBlock({super.key, required this.height, this.width, this.radius = 10});

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E1E24) : const Color(0xFFEDEDF2);
    final highlight = isDark ? const Color(0xFF2C2C34) : const Color(0xFFF7F7FA);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
              transform: _SweepTransform(_controller.value),
            ),
          ),
        );
      },
    );
  }
}

class _SweepTransform extends GradientTransform {
  final double value;
  const _SweepTransform(this.value);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final dx = (value * 2 - 1) * bounds.width;
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// Gradient initials avatar — used when a user has no photo.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const InitialsAvatar({super.key, required this.name, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    final hue = (name.hashCode % kBrandGradient.length).abs();
    final colors = [
      [const Color(0xFF6366F1), const Color(0xFFA855F7)],
      [const Color(0xFFEC4899), const Color(0xFFF59E0B)],
      [const Color(0xFF14B8A6), const Color(0xFF22C55E)],
    ][hue];
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(fontSize: radius * 0.72, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// Smooth fade+rise page route (used for task detail navigation).
Route<T> smoothPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Bottom sheet with a blurred, dimmed backdrop (premium sheet feel).
Future<T?> showBlurBottomSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withValues(alpha: 0.28)),
          ),
        ),
        Align(alignment: Alignment.bottomCenter, child: child),
      ],
    ),
  );
}


/// Wraps a task card with swipe actions:
/// swipe right = complete / reopen (assignee only), swipe left =
/// delete with a confirmation dialog. Actions run inside
/// confirmDismiss and return false, so the Firestore stream stays the
/// single source of truth; a confirmed delete first hides the card via
/// [onLocalDelete] to avoid any dismiss race with the stream.
Widget swipeableTaskCard({
  required BuildContext context,
  required TaskModel task,
  required DatabaseService dbService,
  required String currentUid,
  required VoidCallback onLocalDelete,
  required VoidCallback onDeleteFailed,
  required Widget child,
}) {
  final canToggle = task.assignedTo == currentUid;
  return Dismissible(
    key: ValueKey('swipe-${task.id}'),
    direction: canToggle ? DismissDirection.horizontal : DismissDirection.endToStart,
    background: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: Colors.green.shade500, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(task.isDone ? Icons.replay_rounded : Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(task.isDone ? 'Reopen' : 'Complete', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    ),
    secondaryBackground: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(color: Colors.red.shade500, borderRadius: BorderRadius.circular(14)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          SizedBox(width: 8),
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
        ],
      ),
    ),
    confirmDismiss: (direction) async {
      if (direction == DismissDirection.startToEnd) {
        await dbService.updateTaskStatus(task.id, !task.isDone, taskTitle: task.title, assignedBy: task.assignedBy);
        HapticFeedback.lightImpact();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(task.isDone ? 'Moved back to To Do' : 'Marked as complete 🎉'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
        }
        return false;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete this task?'),
          content: Text('"${task.title}" will be permanently deleted.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
          ],
        ),
      );
      if (confirmed == true) {
        onLocalDelete();
        dbService.deleteTask(task.id).catchError((Object _) {
          onDeleteFailed();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not delete the task. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ));
          }
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Task deleted'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ));
        }
      }
      return false;
    },
    child: child,
  );
}

/// Amber strip shown while the device has no connectivity. Firestore
/// queues writes offline and syncs on reconnect — this just makes the
/// state visible instead of silent.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final results = snapshot.data;
        final offline = results != null && (results.isEmpty || results.every((r) => r == ConnectivityResult.none));
        if (!offline) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: const Color(0xFFF59E0B),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  "You're offline — changes will sync when you reconnect",
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small selectable chip used by the priority/category pickers in the
/// create- and edit-task sheets.

/// Small selectable chip used by the priority/category pickers in the
/// create- and edit-task sheets.
Widget taskOptionChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
  required bool isDark,
  required Color primaryColor,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? primaryColor : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? primaryColor : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08))),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    ),
  );
}

