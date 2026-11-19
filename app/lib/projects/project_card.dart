import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/jalali/jalali_format.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/projects/models.dart';
import 'package:letter_signing/projects/project_ui.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/widgets/progress_ring.dart';

/// A project in the list: a bar in the project colour, name, dates, status, progress ring and
/// the member count shown as overlapping avatars.
class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, required this.onTap});

  final ProjectBrief project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = projectColor(project.color);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const ValueKey('project-color-bar'),
                width: 6,
                color: color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (project.status != ProjectStatus.active)
                                  StatusPill(
                                    projectStatusLabel(l, project.status),
                                    tone: projectStatusTone(project.status),
                                  ),
                                if (project.endDate != null)
                                  Text(
                                    '${l.projectEnd}: ${formatJalaliDate(project.endDate!)}',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                _Avatars(
                                  count: project.memberCount,
                                  color: color,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ProgressRing(value: project.progress),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Up to three overlapping avatar circles and the member count.
class _Avatars extends StatelessWidget {
  const _Avatars({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = count.clamp(0, 3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: shown == 0 ? 0 : 14.0 * shown + 8,
          height: 22,
          child: Stack(
            children: [
              for (var i = 0; i < shown; i++)
                PositionedDirectional(
                  start: 14.0 * i,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: color.withValues(alpha: 0.35 + 0.2 * i),
                    child: Icon(Icons.person, size: 13, color: scheme.surface),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          toPersianDigits(count),
          key: const ValueKey('member-count'),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
        ),
      ],
    );
  }
}
