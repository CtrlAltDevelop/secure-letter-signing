import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:letter_signing/bookmarks/pin_button.dart';
import 'package:letter_signing/crm/crm_env.dart';
import 'package:letter_signing/crm/crm_ui.dart';
import 'package:letter_signing/crm/customer_calls_tab.dart';
import 'package:letter_signing/crm/customer_form_screen.dart';
import 'package:letter_signing/crm/customer_links_tabs.dart';
import 'package:letter_signing/crm/customer_members_tab.dart';
import 'package:letter_signing/crm/customer_overview_tab.dart';
import 'package:letter_signing/crm/customer_timeline_tab.dart';
import 'package:letter_signing/crm/models.dart';
import 'package:letter_signing/l10n/app_localizations.dart';
import 'package:letter_signing/theme/widgets.dart';
import 'package:letter_signing/workspace/subject_controller.dart';
import 'package:letter_signing/workspace/widgets/bookmark_button.dart';
import 'package:letter_signing/workspace/widgets/comment_thread.dart';
import 'package:letter_signing/workspace/widgets/history_list.dart';
import 'package:letter_signing/workspace/widgets/subject_files.dart';

/// A customer file: overview, timeline, linked tasks/meetings/letters, files (cheques,
/// contracts), call reports, finance and leads panels (only when the host provides them),
/// chat, members, comments and change history.
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.env,
    required this.customerId,
  });
  final CrmEnv env;
  final String customerId;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Customer? _customer;
  Object? _error;
  SubjectController? _subject;

  CrmEnv get env => widget.env;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _subject?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await env.api.get(widget.customerId);
      if (!mounted) return;
      setState(() {
        _customer = c;
        _error = null;
        _subject ??= SubjectController(
          api: env.api.workspace,
          live: env.live,
          subjectId: c.subjectId,
        )..addListener(_rebuild);
      });
      unawaited(_subject!.loadComments());
      unawaited(_subject!.loadHistory());
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _edit(Customer c) async {
    final saved = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(env: env, customer: c),
      ),
    );
    if (saved != null && mounted) unawaited(_load());
  }

  Future<bool> _via(Future<ActionOutcome> Function() action) async {
    final failed = AppLocalizations.of(context).crmSaveFailed;
    final messenger = ScaffoldMessenger.of(context);
    final out = await action();
    if (out != ActionOutcome.ok) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
    return out == ActionOutcome.ok;
  }

  /// Tab label and body in display order; panels of other modules appear only when the
  /// host builds them.
  List<(String, Widget)> _tabs(AppLocalizations l, Customer c) {
    final s = _subject!;
    final write = canWrite(c.myRole);
    final finance = env.financePanel?.call(c.id);
    final leads = env.leadsPanel?.call(c.id);
    final chat = env.chatTab?.call(c.id);
    return [
      (
        l.crmTabOverview,
        CustomerOverviewTab(
          key: ValueKey('ov-${c.labelIds}-${c.name}'),
          env: env,
          customer: c,
        ),
      ),
      (
        l.crmTabTimeline,
        CustomerTimelineTab(
          api: env.api,
          customerId: c.id,
          canAdd: c.can.event,
        ),
      ),
      (
        l.crmTabTasks,
        CustomerTasksTab(env: env, customerId: c.id, canCreate: write),
      ),
      (
        l.crmTabMeetings,
        CustomerMeetingsTab(env: env, customerId: c.id, canCreate: write),
      ),
      (l.crmTabLetters, CustomerLettersTab(env: env, customerId: c.id)),
      (
        l.crmTabFiles,
        ListView(
          children: [
            PageBody(
              child: SubjectFiles(
                api: env.api.workspace,
                live: env.live,
                subjectId: c.subjectId,
                userId: env.userId,
                pickFile: env.pickFile,
                saveFile: env.saveFile,
              ),
            ),
          ],
        ),
      ),
      (
        l.crmTabCalls,
        CustomerCallsTab(
          api: env.api,
          customerId: c.id,
          userId: env.userId,
          canAdd: c.can.call,
          canTask: write && env.tasks.canCreate,
        ),
      ),
      if (finance != null)
        (l.crmTabFinance, ListView(children: [PageBody(child: finance)])),
      if (leads != null)
        (l.crmTabLeads, ListView(children: [PageBody(child: leads)])),
      if (chat != null) (l.crmTabChat, chat),
      (
        l.crmTabMembers,
        CustomerMembersTab(
          key: ValueKey('members-${c.members.length}'),
          api: env.api,
          customer: c,
          directory: env.directory,
          onChanged: (n) => setState(() => _customer = n),
        ),
      ),
      (
        l.tabComments,
        ListView(
          children: [
            PageBody(
              child: CommentThread(
                comments: s.comments,
                currentUserId: env.userId,
                canComment: c.can.comment,
                onPost: (text, {parentId, required kind, progress}) => _via(
                  () => s.postComment(text, parentId: parentId, kind: kind),
                ),
                onEdit: (id, text) => _via(() => s.editComment(id, text)),
                onDelete: (id) => _via(() => s.deactivateComment(id)),
              ),
            ),
          ],
        ),
      ),
      (
        l.tabHistory,
        ListView(
          children: [PageBody(child: HistoryList(entries: s.history))],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = _customer;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.crmTitle)),
        body: _error != null
            ? EmptyState(
                icon: Icons.cloud_off_outlined,
                title: l.crmLoadFailed,
                message: '$_error',
                action: OutlinedButton.icon(
                  onPressed: () => unawaited(_load()),
                  icon: const Icon(Icons.refresh),
                  label: Text(l.commonRetry),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final tabs = _tabs(l, c);
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(c.name),
          actions: [
            PinButton(api: env.api.workspace, subjectId: c.subjectId),
            BookmarkButton(api: env.api.workspace, module: 'crm', id: c.id),
            if (c.can.edit)
              IconButton(
                key: const ValueKey('crm-edit'),
                tooltip: l.crmEditTitle,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => unawaited(_edit(c)),
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(text: t.$1)],
          ),
        ),
        body: TabBarView(children: [for (final t in tabs) t.$2]),
      ),
    );
  }
}
