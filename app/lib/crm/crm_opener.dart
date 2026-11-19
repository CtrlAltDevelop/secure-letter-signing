import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/crm/crm_env.dart';
import 'package:letter_signing/crm/customer_detail_screen.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/workspace/open_target.dart';

/// Opens search hits, bookmarks and pins of the `crm` module. Hits carry the customer id; a
/// pin only knows the subject id, which is matched against my customer list. False when
/// nothing matches.
TargetOpener crmOpener(CrmEnv env) => (context, target) async {
  var id = target.kind == 'subject' ? null : target.id;
  if (id == null && target.subjectId.isNotEmpty) {
    for (final c in await env.api.list(const CustomerFilter(), limit: 200)) {
      if (c.subjectId == target.subjectId) id = c.id;
    }
  }
  if (id == null || id.isEmpty || !context.mounted) return false;
  final customerId = id;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CustomerDetailScreen(env: env, customerId: customerId),
    ),
  );
  return true;
};
