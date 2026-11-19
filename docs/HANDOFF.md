# Handoff (2026-11-19) - branch `wip/other-machine`

Nothing from this session is committed. Start with `git status`, then commit in logical chunks.
Goal from the user: build every feature of the "advanced plan" list (Mizito-style workspace) in server + Flutter app,
Persian UI, tests last. Read AGENTS.md and docs/platform-design.md first.

## State
- Server tests: 641 passed right after the guest fix; many files changed since (accounts security/guests, gantt, monitor,
  chat/crm guest checks). The FULL server suite and the FULL `flutter test` have NOT been re-run since. Do that first:
  `cd server && DJANGO_DEBUG=1 uv run pytest -q -p no:cacheprovider`; `cd app && flutter analyze && flutter test`
  (copy `brands/demo/*` into `app/assets/brand/` before flutter).
- The app-side security + Gantt agent was still running when this was written. Its files (`app/lib/gantt/`, `sec*` l10n
  keys, edits to `screens/admin_screen.dart`, `profile_tab.dart`, `sessions_tab.dart`, login 2FA screen) may be
  incomplete. Last known breakage: `lib/gantt/gantt_screen.dart` (`_BarDragRecognizer.isPointerAllowed` type mismatch) and
  missing `sec*` getters; `test/screens/{screens_ui,signing_pin,biometric_enrol}_test.dart` and
  `test/workspace/{home_shell,workspace}_test.dart` did not compile because of that. Run `flutter gen-l10n` first.

## Done (server)
- Guests: `registry.set_current_user` (contextvar) + `enabled_modules()` limits guests to `GUEST_MODULES`; path blocking in
  `BearerAuth`; directory/roster leaks closed in letters, comments/mentions, tasks, projects, chat (`chat/service.py`),
  crm (`checked_members` refuses guests).
- Accounts: 2FA (`/me/2fa*`), login history (`/me/login-history`, manager variant), revoke-others, guest CRUD + guest
  invites (migration 0015), manager access editor (`/manage/users/{id}/access`).
- Monitor (`/api/monitor/*`, perm `monitor.view`), project-group access (`PUT /project-groups/{id}/access`).
- Gantt (`server/gantt/`, `/api/projects/{id}/gantt`): phases, items/WBS, links (cycle check), print data, readiness
  notification.
- Docs: monitor section added to platform-design.md; gantt/security/guests sections NOT yet documented, AGENTS.md not
  updated (it still says create/admin/notifications dialogs are English - now false).

## Done (app, each with its own passing test folder)
monitor, finance, sales, chat, calendar, search, bookmarks/pins, prefs/settings, crm (customer file), polls, Persian
pass over old screens (~260 keys, `lib/l10n/tr.dart`).

## Known gaps / TODO
- Chat: voice recording, inline audio, clipboard image paste are null hooks (no packages in pubspec); "turn message into
  task" does not call `POST /chat/messages/{id}/to-task`; no message edit UI, no in-conversation search.
- Polls not embedded in the customer file; `CustomerChatTab`, finance/leads panels: check they are wired in
  `crm/customer_detail_screen.dart` (CRM agent said they are, via builders).
- Pins/mentions open tasks/letters/meetings by subject id -> may show load error; background image only previewed in
  settings; per-project calendar not linked from project screen (`CalendarScreen(projectId:)` exists).
- Monitor: sales/finance chart keys guessed (`won_by_month`, bucket `net`); raw status keys in meetings/customers chips;
  presets are rolling windows not Jalali-aligned.
- Task inbox has no customer filter UI; CRM letters tab has no link/unlink.
- Gantt: no critical path, only finish-to-start; `gantt.task_ready` not in `IMPORTANT_KINDS`; delete-guard not tested.
- Not started: online video meeting (marked experimental), iOS push/PWA.
- `accounts` dev `db.sqlite3` has an inconsistent migration history (don't run makemigrations against it).
- Nothing was run on a device/simulator or against the real server from the app.
