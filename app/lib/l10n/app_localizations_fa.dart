// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get moduleTasks => 'وظایف';

  @override
  String get moduleProjects => 'پروژه‌ها';

  @override
  String get moduleLetters => 'نامه‌ها';

  @override
  String get navMore => 'بیشتر';

  @override
  String get navProfile => 'پروفایل';

  @override
  String get navDevices => 'دستگاه‌ها';

  @override
  String get navAllLetters => 'همه نامه‌ها';

  @override
  String get navAdmin => 'مدیریت';

  @override
  String get signOut => 'خروج';

  @override
  String get comingSoonTitle => 'به‌زودی';

  @override
  String get comingSoonMessage => 'این بخش به‌زودی در دسترس خواهد بود.';

  @override
  String get jalaliPickerConfirm => 'تأیید';

  @override
  String get jalaliPickerCancel => 'انصراف';

  @override
  String get jalaliFieldHint => 'انتخاب تاریخ';

  @override
  String get jalaliFieldClear => 'پاک کردن تاریخ';

  @override
  String get commonCancel => 'انصراف';

  @override
  String get commonConfirm => 'تأیید';

  @override
  String get commonRetry => 'تلاش دوباره';

  @override
  String get commonSave => 'ذخیره';

  @override
  String get tasksTabInbox => 'صندوق';

  @override
  String get tasksTabFollowup => 'پیگیری';

  @override
  String get tasksTabAll => 'همه';

  @override
  String get tasksSearchHint => 'جستجوی عنوان وظیفه';

  @override
  String get tasksSearchClear => 'پاک کردن جستجو';

  @override
  String get tasksFilterAll => 'همه وضعیت‌ها';

  @override
  String get tasksLoadFailed => 'بارگذاری وظایف ممکن نشد';

  @override
  String get tasksLoadMore => 'نمایش بیشتر';

  @override
  String get tasksEmptyInboxTitle => 'وظیفه‌ای در صندوق نیست';

  @override
  String get tasksEmptyInboxMessage =>
      'وظایفی که باید انجام یا تأیید کنید اینجا نمایش داده می‌شوند.';

  @override
  String get tasksEmptyFollowupTitle => 'وظیفه‌ای برای پیگیری نیست';

  @override
  String get tasksEmptyFollowupMessage =>
      'وظایفی که ایجاد کرده‌اید یا دنبال می‌کنید اینجا نمایش داده می‌شوند.';

  @override
  String get tasksEmptyAllTitle => 'هنوز وظیفه‌ای ثبت نشده';

  @override
  String get tasksEmptyAllMessage =>
      'همه وظایفی که به شما مربوط است اینجا نمایش داده می‌شود.';

  @override
  String get tasksEmptyFilteredTitle => 'وظیفه‌ای پیدا نشد';

  @override
  String get tasksEmptyFilteredMessage => 'جستجو یا فیلترها را تغییر دهید.';

  @override
  String get taskNew => 'وظیفه جدید';

  @override
  String get taskEdit => 'ویرایش وظیفه';

  @override
  String get taskDetailTitle => 'وظیفه';

  @override
  String get taskLoadFailed => 'بارگذاری وظیفه ممکن نشد';

  @override
  String get taskStatusOpen => 'باز';

  @override
  String get taskStatusAwaiting => 'در انتظار تأیید';

  @override
  String get taskStatusDone => 'انجام‌شده';

  @override
  String get taskStatusCancelled => 'لغوشده';

  @override
  String get taskPriorityLow => 'کم';

  @override
  String get taskPriorityNormal => 'معمولی';

  @override
  String get taskPriorityHigh => 'زیاد';

  @override
  String get taskPriorityUrgent => 'فوری';

  @override
  String taskChecklistCount(String done, String total) {
    return '$done از $total';
  }

  @override
  String taskCreatedBy(String name) {
    return 'ایجاد‌کننده: $name';
  }

  @override
  String get taskProgressFromChecklist =>
      'پیشرفت از روی فهرست کارها محاسبه می‌شود.';

  @override
  String get taskComplete => 'انجام شد';

  @override
  String get taskApprove => 'تأیید';

  @override
  String get taskReject => 'رد';

  @override
  String get taskReopen => 'بازگشایی';

  @override
  String get taskCancel => 'لغو وظیفه';

  @override
  String get taskCancelConfirm => 'این وظیفه لغو شود؟';

  @override
  String get taskCancelYes => 'بله، لغو شود';

  @override
  String get taskNoteOptional => 'یادداشت (اختیاری)';

  @override
  String get taskRejectNoteRequired => 'دلیل رد را بنویسید';

  @override
  String get taskConflict =>
      'این وظیفه همزمان توسط فرد دیگری تغییر کرده است. نسخه جدید بارگذاری شد؛ دوباره تلاش کنید.';

  @override
  String get taskForbidden => 'اجازه انجام این کار را ندارید.';

  @override
  String get taskNotFound => 'این وظیفه دیگر در دسترس نیست.';

  @override
  String get taskActionFailed => 'انجام کار ممکن نشد.';

  @override
  String get fieldTitle => 'عنوان';

  @override
  String get fieldDescription => 'توضیحات';

  @override
  String get fieldPriority => 'اولویت';

  @override
  String get fieldStatus => 'وضعیت';

  @override
  String get fieldStart => 'شروع';

  @override
  String get fieldDue => 'سررسید';

  @override
  String get fieldAllDay => 'تمام روز';

  @override
  String get fieldProgress => 'پیشرفت';

  @override
  String get fieldOwners => 'مسئولان';

  @override
  String get fieldApprovers => 'تأییدکنندگان';

  @override
  String get fieldFollowers => 'دنبال‌کنندگان';

  @override
  String get fieldChecklist => 'فهرست کارها';

  @override
  String get approverApproved => 'تأیید کرد';

  @override
  String get approverRejected => 'رد کرد';

  @override
  String get approverPending => 'در انتظار';

  @override
  String get approverTurn => 'نوبت تأیید';

  @override
  String get checklistAdd => 'افزودن';

  @override
  String get checklistAddHint => 'مورد جدید';

  @override
  String get checklistRemove => 'حذف مورد';

  @override
  String get formTitleRequired => 'عنوان را وارد کنید';

  @override
  String get formOwnerRequired => 'دست‌کم یک مسئول لازم است';

  @override
  String get formDueBeforeStart => 'سررسید باید بعد از شروع باشد';

  @override
  String get labelsTitle => 'برچسب‌ها';

  @override
  String get peopleAdd => 'افزودن';

  @override
  String get peopleSearch => 'جستجوی همکار';

  @override
  String get peopleEmpty => 'همکاری پیدا نشد';

  @override
  String peopleRemove(String name) {
    return 'حذف $name';
  }

  @override
  String get tabComments => 'نظرها';

  @override
  String get tabFiles => 'پرونده‌ها';

  @override
  String get tabHistory => 'تاریخچه';

  @override
  String get commentsEmpty => 'هنوز نظری ثبت نشده';

  @override
  String get commentHint => 'نظر خود را بنویسید';

  @override
  String get commentSend => 'ارسال';

  @override
  String get commentReply => 'پاسخ';

  @override
  String get commentEdit => 'ویرایش';

  @override
  String get commentDelete => 'حذف';

  @override
  String get commentEdited => 'ویرایش‌شده';

  @override
  String get commentEditing => 'ویرایش نظر';

  @override
  String commentReplyingTo(String name) {
    return 'پاسخ به $name';
  }

  @override
  String get commentKindComment => 'نظر';

  @override
  String get commentKindReport => 'گزارش';

  @override
  String get commentAttachProgress => 'ثبت درصد پیشرفت';

  @override
  String commentProgress(String percent) {
    return 'پیشرفت: $percent٪';
  }

  @override
  String get filesEmpty => 'پرونده‌ای پیوست نشده';

  @override
  String get fileUpload => 'بارگذاری پرونده';

  @override
  String get fileDownload => 'دریافت';

  @override
  String get fileDelete => 'حذف پرونده';

  @override
  String get historyEmpty => 'تغییری ثبت نشده';

  @override
  String get historyNone => '—';

  @override
  String get historyYes => 'بله';

  @override
  String get historyNo => 'خیر';

  @override
  String get historySystem => 'سیستم';

  @override
  String historyChanged(String actor, String field) {
    return '$actor، «$field» را تغییر داد';
  }

  @override
  String get seenByTitle => 'دیده‌شده توسط';

  @override
  String get seenByEmpty => 'هنوز کسی ندیده است';

  @override
  String get seenByFailed => 'بارگذاری ممکن نشد';

  @override
  String get fieldProject => 'پروژه';

  @override
  String get fieldColumn => 'ستون';

  @override
  String get projectNone => 'بدون پروژه';

  @override
  String get projectStatusActive => 'فعال';

  @override
  String get projectStatusDone => 'انجام‌شده';

  @override
  String get projectStatusArchived => 'بایگانی‌شده';

  @override
  String get roleManager => 'مدیر';

  @override
  String get roleMember => 'عضو';

  @override
  String get roleViewer => 'بیننده';

  @override
  String get sortManual => 'ترتیب دستی';

  @override
  String get sortCreatedAsc => 'قدیمی‌ترین ایجاد';

  @override
  String get sortCreatedDesc => 'جدیدترین ایجاد';

  @override
  String get sortDueAsc => 'سررسید نزدیک‌تر';

  @override
  String get sortDueDesc => 'سررسید دورتر';

  @override
  String get sortUpdatedAsc => 'قدیمی‌ترین تغییر';

  @override
  String get sortUpdatedDesc => 'جدیدترین تغییر';

  @override
  String get projectConflict =>
      'پروژه همزمان تغییر کرده است. دوباره تلاش کنید.';

  @override
  String get projectNotFound => 'این پروژه یا مورد دیگر در دسترس نیست.';

  @override
  String get boardCompact => 'کارت فشرده';

  @override
  String get columnAdd => 'ستون جدید';

  @override
  String get columnTitleHint => 'عنوان ستون';

  @override
  String get boardEmpty => 'ستونی وجود ندارد';

  @override
  String get columnRename => 'تغییر نام ستون';

  @override
  String get columnHide => 'پنهان کردن ستون';

  @override
  String get columnMoveEarlier => 'جابه‌جایی به قبل';

  @override
  String get columnMoveLater => 'جابه‌جایی به بعد';

  @override
  String get columnSort => 'مرتب‌سازی';

  @override
  String get columnMenu => 'گزینه‌های ستون';

  @override
  String get boardAddTask => 'افزودن وظیفه';

  @override
  String get boardAddTaskHint => 'عنوان وظیفه';

  @override
  String get projectListEmpty => 'وظیفه‌ای پیدا نشد';

  @override
  String get calendarPickDay => 'یک روز را انتخاب کنید.';

  @override
  String get calendarDayEmpty => 'وظیفه‌ای در این روز نیست.';

  @override
  String get fileTypeImage => 'تصویر';

  @override
  String get fileTypeVideo => 'ویدئو';

  @override
  String get fileTypeDocument => 'سند';

  @override
  String get projectFilesUnavailable => 'پرونده‌های پروژه هنوز در دسترس نیست.';

  @override
  String get filesSearchHint => 'جستجوی نام پرونده';

  @override
  String get projectArchive => 'بایگانی پروژه';

  @override
  String get projectArchiveConfirm =>
      'پروژه بایگانی شود؟ دیگر وظیفه جدیدی نمی‌پذیرد.';

  @override
  String get projectCopy => 'کپی پروژه';

  @override
  String get projectCopyUnavailable => 'کپی پروژه روی این سرور در دسترس نیست.';

  @override
  String get projectEnd => 'پایان';

  @override
  String get projectMembers => 'اعضا';

  @override
  String get projectEdit => 'ویرایش پروژه';

  @override
  String get projectMarkDone => 'پایان پروژه';

  @override
  String get projectReactivate => 'فعال‌سازی دوباره';

  @override
  String get projectTabBoard => 'برد';

  @override
  String get projectTabList => 'فهرست';

  @override
  String get projectTabCalendar => 'تقویم';

  @override
  String get projectTabFiles => 'پرونده‌ها';

  @override
  String get projectTabMembers => 'اعضا و تنظیمات';

  @override
  String get projectTabChat => 'گفتگو';

  @override
  String get projectLoadFailed => 'بارگذاری پروژه ممکن نشد';

  @override
  String get projectNew => 'پروژه جدید';

  @override
  String get projectName => 'نام پروژه';

  @override
  String get projectNameRequired => 'نام پروژه را وارد کنید';

  @override
  String get projectEndBeforeStart => 'پایان باید بعد از شروع باشد';

  @override
  String get projectGroup => 'گروه';

  @override
  String get projectColor => 'رنگ';

  @override
  String get groupNew => 'گروه جدید';

  @override
  String get groupNameHint => 'نام گروه';

  @override
  String get groupScopeTitle => 'نوع گروه';

  @override
  String get groupScopeOrg => 'گروه سازمان';

  @override
  String get groupScopePersonal => 'گروه شخصی';

  @override
  String get groupRename => 'تغییر نام گروه';

  @override
  String get groupsTitle => 'گروه‌های پروژه';

  @override
  String get groupsEmpty => 'گروهی وجود ندارد';

  @override
  String get groupDeactivate => 'غیرفعال‌سازی گروه';

  @override
  String get groupActivate => 'فعال‌سازی گروه';

  @override
  String get projectsSearchHint => 'جستجوی پروژه';

  @override
  String get projectsLoadFailed => 'بارگذاری پروژه‌ها ممکن نشد';

  @override
  String get projectsEmptyFilteredTitle => 'پروژه‌ای پیدا نشد';

  @override
  String get projectsEmptyTitle => 'هنوز پروژه‌ای ندارید';

  @override
  String get projectsEmptyMessage =>
      'پروژه‌هایی که عضو آن هستید اینجا نمایش داده می‌شوند.';

  @override
  String get projectsUngrouped => 'بدون گروه';

  @override
  String get labelNew => 'برچسب جدید';

  @override
  String get labelEdit => 'ویرایش برچسب';

  @override
  String get labelName => 'نام برچسب';

  @override
  String get labelDuplicate => 'برچسبی با این نام وجود دارد.';

  @override
  String get labelScopeOrg => 'برچسب سازمان (برای همه)';

  @override
  String get labelsLoadFailed => 'بارگذاری برچسب‌ها ممکن نشد';

  @override
  String get labelsOrgTitle => 'برچسب‌های سازمان';

  @override
  String get labelsPersonalTitle => 'برچسب‌های من';

  @override
  String get labelsEmpty => 'برچسبی وجود ندارد';

  @override
  String get labelDeactivate => 'غیرفعال‌سازی برچسب';

  @override
  String get labelActivate => 'فعال‌سازی برچسب';

  @override
  String get navLabels => 'برچسب‌ها';

  @override
  String get remindersTitle => 'یادآوری‌های من';

  @override
  String get reminderAdd => 'افزودن یادآوری';

  @override
  String get remindersEmpty => 'یادآوری‌ای ثبت نشده';

  @override
  String get reminderRemove => 'حذف یادآوری';

  @override
  String get reminderWhen => 'زمان یادآوری';

  @override
  String get reminderDateRequired => 'یک تاریخ و ساعت در آینده انتخاب کنید';

  @override
  String get reminderRepeat => 'تکرار';

  @override
  String get reminderOnce => 'یک‌بار';

  @override
  String get reminderDaily => 'روزانه';

  @override
  String get reminderWeekly => 'هفتگی';

  @override
  String get reminderMonthly => 'ماهانه';

  @override
  String get taskMove => 'انتقال';

  @override
  String get taskCopy => 'کپی';

  @override
  String get taskCopied => 'نسخه‌ای از وظیفه ساخته شد.';

  @override
  String get taskNoProject => 'این وظیفه در هیچ پروژه‌ای نیست.';

  @override
  String percentValue(String p) {
    return '$p٪';
  }

  @override
  String projectCopyName(String name) {
    return '$name (کپی)';
  }

  @override
  String projectCopied(String name) {
    return 'پروژه «$name» ساخته شد.';
  }

  @override
  String sizeBytes(String n) {
    return '$n بایت';
  }

  @override
  String sizeKilobytes(String n) {
    return '$n کیلوبایت';
  }

  @override
  String sizeMegabytes(String n) {
    return '$n مگابایت';
  }

  @override
  String reminderMonthDay(String day) {
    return 'روز $day';
  }

  @override
  String get lettersBoxInbox => 'دریافتی';

  @override
  String get lettersBoxOutbox => 'ارسالی';

  @override
  String get lettersBoxArchive => 'بایگانی';

  @override
  String get lettersBoxAll => 'همه';

  @override
  String get lettersSearchHint => 'جستجوی عنوان نامه';

  @override
  String get lettersSearchClear => 'پاک کردن جستجو';

  @override
  String get lettersAdvancedSearch => 'جستجوی پیشرفته';

  @override
  String get lettersLoadFailed => 'بارگذاری نامه‌ها ممکن نشد';

  @override
  String get lettersEmptyTitle => 'نامه‌ای وجود ندارد';

  @override
  String get lettersEmptyMessage =>
      'نامه‌هایی که می‌نویسید یا برای شما ارسال می‌شود اینجا نمایش داده می‌شود.';

  @override
  String get lettersNoMatchTitle => 'نامه‌ای پیدا نشد';

  @override
  String get lettersNoMatchMessage => 'جستجو یا فیلترها را تغییر دهید.';

  @override
  String get lettersNew => 'نامه جدید';

  @override
  String get lettersCreatedByYou => 'ایجاد شده توسط شما';

  @override
  String get lettersSharedWithYou => 'ارسال شده برای شما';

  @override
  String get lettersPublic => 'عمومی';

  @override
  String get lettersPrivate => 'خصوصی';

  @override
  String get lettersArchive => 'بایگانی کردن';

  @override
  String get lettersUnarchive => 'خروج از بایگانی';

  @override
  String get lettersEditLabels => 'ویرایش برچسب‌ها';

  @override
  String get lettersNoLabels => 'هنوز برچسبی تعریف نشده است.';

  @override
  String get lettersMenu => 'گزینه‌ها';

  @override
  String get lettersSecretariat => 'دبیرخانه';

  @override
  String lettersReferralCount(String n) {
    return '$n ارجاع';
  }

  @override
  String get lettersSearchText => 'متن جستجو';

  @override
  String get lettersSearchStatus => 'وضعیت';

  @override
  String get lettersSearchAnyStatus => 'همه وضعیت‌ها';

  @override
  String get lettersSearchLabel => 'برچسب';

  @override
  String get lettersSearchNumber => 'شماره نامه';

  @override
  String get lettersSearchCreator => 'نویسنده';

  @override
  String get lettersSearchSigner => 'امضاکننده';

  @override
  String get lettersSearchFrom => 'از تاریخ';

  @override
  String get lettersSearchTo => 'تا تاریخ';

  @override
  String get lettersSearchReset => 'پاک کردن';

  @override
  String get lettersSearchApply => 'اعمال';

  @override
  String get letterStatusDraft => 'پیش‌نویس';

  @override
  String get letterStatusInSigning => 'در حال امضا';

  @override
  String get letterStatusPublished => 'منتشرشده';

  @override
  String get letterStatusRejected => 'ردشده';

  @override
  String get letterStatusCancelled => 'لغوشده';

  @override
  String letterTitle(String no) {
    return 'نامه $no';
  }

  @override
  String get letterLoadFailed => 'بارگذاری نامه ممکن نشد';

  @override
  String get paperTooltip => 'کاغذ / چاپ';

  @override
  String get certTooltip => 'گواهی امضا';

  @override
  String get letterAttachments => 'پیوست‌ها';

  @override
  String letterFileCount(String n) {
    return '$n پرونده';
  }

  @override
  String get letterSigning => 'امضا';

  @override
  String get letterSerial => 'امضاکنندگان یکی پس از دیگری امضا می‌کنند';

  @override
  String get letterParallel => 'امضاکنندگان به هر ترتیب می‌توانند امضا کنند';

  @override
  String get letterViewers => 'بینندگان';

  @override
  String get letterChained => 'نامه‌های زنجیره‌ای';

  @override
  String get letterCustomers => 'پرونده‌های مشتری';

  @override
  String get letterUnlisted => 'فهرست‌نشده';

  @override
  String get letterArchived => 'بایگانی‌شده';

  @override
  String letterCreatedSent(String created, String sent) {
    return 'ایجاد: $created$sent';
  }

  @override
  String letterSent(String date) {
    return 'ارسال: $date';
  }

  @override
  String get letterRepliesTo => 'پاسخ به نامه‌ای قبلی';

  @override
  String get letterYourTurn => 'امضای شما روی این نامه لازم است.';

  @override
  String get letterNoText => '(بدون متن)';

  @override
  String get letterNoSigners => 'امضاکننده‌ای نیست';

  @override
  String get letterRelist => 'فهرست کردن';

  @override
  String get letterUnlist => 'حذف از فهرست';

  @override
  String get letterCancel => 'لغو نامه';

  @override
  String get letterReply => 'پاسخ با نامه';

  @override
  String get letterSend => 'ارسال';

  @override
  String get letterSign => 'امضا';

  @override
  String get letterAttachmentFallback => 'پیوست';

  @override
  String get decisionApproved => 'تأیید شد';

  @override
  String get decisionRejected => 'رد شد';

  @override
  String get decisionPending => 'در انتظار';

  @override
  String get decisionOpened => 'باز کرده';

  @override
  String get decisionApprove => 'تأیید';

  @override
  String get decisionReject => 'رد';

  @override
  String get signMethodPin => 'رمز';

  @override
  String get signMethodBiometric => 'زیست‌سنجی';

  @override
  String get paraphTitle => 'پاراف';

  @override
  String get paraphNone => 'هنوز پارافی ثبت نشده است.';

  @override
  String get paraphAction => 'پاراف';

  @override
  String get paraphExplain =>
      'پاراف مهر می‌شود و برای هر نفر یک بار ثبت می‌شود.';

  @override
  String paraphReason(String title) {
    return 'پاراف نامه: $title';
  }

  @override
  String get referralTitle => 'ارجاعات';

  @override
  String get referralRefer => 'ارجاع';

  @override
  String get referralEmpty => 'این نامه ارجاعی ندارد.';

  @override
  String get referralSheetTitle => 'ارجاع به';

  @override
  String get referralNoteOptional => 'یادداشت (اختیاری)';

  @override
  String get referralSend => 'ارسال ارجاع';

  @override
  String get referralMarkDone => 'انجام شد';

  @override
  String get referralMarkDeclined => 'رد ارجاع';

  @override
  String get referralDone => 'انجام شد';

  @override
  String get referralDeclined => 'ردشده';

  @override
  String get referralPending => 'در انتظار';

  @override
  String referralFromTo(String from, String to) {
    return '$from به $to';
  }

  @override
  String get referralAnswer => 'پاسخ';

  @override
  String get letterTasksTitle => 'وظایف مرتبط';

  @override
  String get letterTaskLink => 'پیوند وظیفه';

  @override
  String get letterTaskCreate => 'ایجاد وظیفه';

  @override
  String get letterTaskUnlink => 'جدا کردن وظیفه';

  @override
  String get letterTasksEmpty => 'وظیفه‌ای به این نامه وصل نشده است.';

  @override
  String get letterTaskPickerEmpty => 'وظیفه‌ای پیدا نشد.';

  @override
  String letterTaskTitle(String title) {
    return 'پیگیری نامه: $title';
  }

  @override
  String letterTaskDescription(String number, String title) {
    return 'مربوط به نامه $number: $title';
  }

  @override
  String get certVerified => 'امضاها تأیید شد';

  @override
  String get certFailed => 'تأیید امضاها ناموفق بود';

  @override
  String get certNoSignatures => 'هنوز امضایی نیست';

  @override
  String get certParaphsVerified => 'پاراف‌ها تأیید شد';

  @override
  String get certParaphsFailed => 'تأیید پاراف‌ها ناموفق بود';

  @override
  String certDevice(String device) {
    return 'دستگاه $device';
  }

  @override
  String get certValid => 'معتبر';

  @override
  String get certInvalid => 'نامعتبر';

  @override
  String get commonClose => 'بستن';

  @override
  String get signTitle => 'امضای نامه';

  @override
  String get signHow => 'چگونه امضا می‌کنید؟';

  @override
  String get signDecision => 'تصمیم شما';

  @override
  String get signApproveHint => 'با این نامه موافقم';

  @override
  String get signRejectHint => 'موافق نیستم';

  @override
  String get signRejectFinal =>
      'رد کردن قطعی است. نویسنده می‌تواند نامه زنجیره‌ای جدید بنویسد.';

  @override
  String get signNoteOptional => 'یادداشت (اختیاری)';

  @override
  String signProgress(String signed, String total) {
    return '$signed از $total امضا شده';
  }

  @override
  String signReasonApprove(String title) {
    return 'تأیید: $title';
  }

  @override
  String signReasonReject(String title) {
    return 'رد: $title';
  }

  @override
  String get signPinInvalid => '۶ رقم وارد کنید';

  @override
  String get signPinLabel => 'رمز امضا';

  @override
  String get signBiometricFailed => 'تأیید اثر انگشت یا چهره ناموفق بود';

  @override
  String signDeclined(String device) {
    return '$device رد کرد. به‌جای آن رمز خود را وارد کنید.';
  }

  @override
  String get signExpired => 'درخواست منقضی شد. به‌جای آن رمز خود را وارد کنید.';

  @override
  String get signCancelled => 'درخواست لغو شد.';

  @override
  String signNoAnswer(String device) {
    return '$device پاسخ نداد. به‌جای آن رمز خود را وارد کنید.';
  }

  @override
  String get signBusy => 'در حال امضا...';

  @override
  String get signWithPin => 'امضا با رمز';

  @override
  String get signOrBiometric => 'یا با زیست‌سنجی تأیید کنید';

  @override
  String get signFingerprint => 'اثر انگشت / چهره';

  @override
  String get signEnableBiometric => 'فعال‌سازی اثر انگشت / چهره';

  @override
  String signAskDevice(String device) {
    return 'تأیید با $device من';
  }

  @override
  String signWaiting(String device) {
    return 'در انتظار تأیید روی $device';
  }

  @override
  String get signWaitingHint =>
      'برنامه را آنجا باز کنید و با اثر انگشت یا چهره تأیید کنید. درخواست پس از ۵ دقیقه منقضی می‌شود.';

  @override
  String paperNumber(String number) {
    return 'شماره: $number';
  }

  @override
  String paperDate(String date) {
    return 'تاریخ: $date';
  }

  @override
  String paperSubject(String title) {
    return 'موضوع: $title';
  }

  @override
  String get paperDecisionApproved => 'تصمیم: تأیید';

  @override
  String get paperDecisionRejected => 'تصمیم: رد';

  @override
  String paperDocumentId(String id) {
    return 'شناسه سند: $id';
  }

  @override
  String paperSeal(String seal) {
    return 'مهر سرور: $seal';
  }

  @override
  String get paperParaphs => 'پاراف‌ها';

  @override
  String paperPrintFailed(String error) {
    return 'چاپ ممکن نشد: $error';
  }

  @override
  String get paperPreviewTitle => 'پیش‌نمایش کاغذ';

  @override
  String get paperPrint => 'چاپ / ذخیره PDF';

  @override
  String get secretariatAll => 'همه';

  @override
  String get secretariatIn => 'وارده';

  @override
  String get secretariatOut => 'صادره';

  @override
  String get secretariatAnyYear => 'همه سال‌ها';

  @override
  String get secretariatSearchHint => 'جستجو در دبیرخانه';

  @override
  String get secretariatLoadFailed => 'بارگذاری دفتر دبیرخانه ممکن نشد';

  @override
  String get secretariatEmpty => 'موردی ثبت نشده است';

  @override
  String get secretariatRegister => 'ثبت نامه';

  @override
  String get secretariatFrom => 'فرستنده';

  @override
  String get secretariatTo => 'گیرنده';

  @override
  String get secretariatEdit => 'ویرایش';

  @override
  String get secretariatTitle => 'عنوان';

  @override
  String get secretariatTitleRequired => 'عنوان را وارد کنید';

  @override
  String get secretariatPartyFrom => 'نام فرستنده';

  @override
  String get secretariatPartyTo => 'نام گیرنده';

  @override
  String get secretariatPartyRef => 'شماره یا ارجاع طرف مقابل';

  @override
  String get secretariatSummary => 'خلاصه';

  @override
  String get secretariatPickLetter => 'انتخاب نامه موجود (اختیاری)';

  @override
  String secretariatRegisteredBy(String name) {
    return 'ثبت‌کننده: $name';
  }

  @override
  String get secretariatDetailTitle => 'مورد دبیرخانه';

  @override
  String get secretariatOpenLetter => 'باز کردن نامه';

  @override
  String get moduleMeetings => 'جلسات';

  @override
  String get meetingStatusDraft => 'پیش‌نویس';

  @override
  String get meetingStatusScheduled => 'برنامه‌ریزی‌شده';

  @override
  String get meetingStatusHeld => 'برگزارشده';

  @override
  String get meetingStatusClosed => 'بسته‌شده';

  @override
  String get meetingStatusCancelled => 'لغوشده';

  @override
  String get meetingKindOrganizational => 'سازمانی';

  @override
  String get meetingKindSimple => 'ساده';

  @override
  String get meetingKindAny => 'همه انواع';

  @override
  String get meetingRoleChair => 'رئیس جلسه';

  @override
  String get meetingRoleSecretary => 'دبیر';

  @override
  String get meetingRoleMember => 'عضو';

  @override
  String get meetingRoleGuest => 'مهمان';

  @override
  String get meetingAttendancePresent => 'حاضر';

  @override
  String get meetingAttendanceAbsent => 'غایب';

  @override
  String get meetingAttendanceExcused => 'موجه';

  @override
  String get meetingAttendanceUnknown => 'نامشخص';

  @override
  String get meetingsSearchHint => 'جستجوی عنوان جلسه';

  @override
  String get meetingsFilters => 'فیلترها';

  @override
  String get meetingTemplatesTitle => 'الگوهای جلسه';

  @override
  String get meetingsLoadFailed => 'بارگذاری جلسات ممکن نشد';

  @override
  String get meetingsEmptyTitle => 'جلسه‌ای وجود ندارد';

  @override
  String get meetingsEmptyMessage =>
      'جلسه‌هایی که برگزار می‌کنید یا در آن‌ها دعوت هستید اینجا نمایش داده می‌شود.';

  @override
  String get meetingNew => 'جلسه جدید';

  @override
  String get meetingNoDate => 'بدون زمان';

  @override
  String meetingAttendeeCount(String n) {
    return '$n نفر';
  }

  @override
  String meetingResolutionCount(String done, String total) {
    return 'مصوبات $done از $total';
  }

  @override
  String get meetingFieldStatus => 'وضعیت';

  @override
  String get meetingFieldKind => 'نوع';

  @override
  String get meetingsMineOnly => 'فقط جلسات من';

  @override
  String get meetingsFrom => 'از تاریخ';

  @override
  String get meetingsTo => 'تا تاریخ';

  @override
  String get meetingAttendees => 'حاضرین';

  @override
  String get meetingExternalGuest => 'مهمان بیرونی';

  @override
  String get meetingFieldRole => 'نقش';

  @override
  String get meetingAddPeople => 'افزودن همکار';

  @override
  String get meetingAddGuest => 'افزودن مهمان';

  @override
  String get meetingGuestName => 'نام مهمان';

  @override
  String get meetingEdit => 'ویرایش جلسه';

  @override
  String get meetingTemplate => 'الگو';

  @override
  String get meetingProject => 'پروژه';

  @override
  String get meetingNoProject => 'بدون پروژه';

  @override
  String get meetingStart => 'شروع';

  @override
  String get meetingEnd => 'پایان';

  @override
  String get meetingFieldTitle => 'عنوان';

  @override
  String get meetingLocation => 'مکان';

  @override
  String get meetingDescription => 'توضیحات';

  @override
  String get meetingSaveTemplate => 'ذخیره به‌عنوان الگو';

  @override
  String get meetingTemplateName => 'نام الگو';

  @override
  String get meetingTemplateOrg => 'الگوی سازمانی (برای همه)';

  @override
  String get meetingTemplateSaved => 'الگو ذخیره شد';

  @override
  String get meetingSaveDraft => 'ذخیره پیش‌نویس';

  @override
  String get meetingSaveSchedule => 'ذخیره و برنامه‌ریزی';

  @override
  String get meetingTitleRequired => 'عنوان را وارد کنید';

  @override
  String get meetingStartRequired => 'زمان شروع را مشخص کنید';

  @override
  String get meetingEndBeforeStart => 'پایان نباید قبل از شروع باشد';

  @override
  String get meetingNeedChair => 'جلسه سازمانی دقیقاً یک رئیس لازم دارد';

  @override
  String get meetingNeedSecretary => 'جلسه سازمانی دقیقاً یک دبیر لازم دارد';

  @override
  String get meetingTemplateScopeOrg => 'سازمانی';

  @override
  String get meetingTemplateScopePersonal => 'شخصی';

  @override
  String get meetingTemplateInactive => 'غیرفعال';

  @override
  String get meetingTemplateRename => 'تغییر نام';

  @override
  String get meetingTemplateDeactivate => 'غیرفعال کردن';

  @override
  String get meetingTemplateActivate => 'فعال کردن';

  @override
  String get meetingTemplatesEmpty => 'الگویی وجود ندارد';

  @override
  String get meetingTemplatesEmptyHint =>
      'هنگام ساخت جلسه می‌توانید آن را به‌عنوان الگو ذخیره کنید.';

  @override
  String get meetingDetailTitle => 'جلسه';

  @override
  String get meetingLoadFailed => 'بارگذاری جلسه ممکن نشد';

  @override
  String get meetingNotFound => 'این جلسه دیگر در دسترس نیست.';

  @override
  String get meetingConfirmCancel => 'این جلسه لغو شود؟';

  @override
  String get meetingConfirmClose => 'صورتجلسه بسته شود؟';

  @override
  String get meetingConfirmReopen =>
      'جلسه دوباره باز شود؟ امضاهای قبلی منسوخ می‌شوند.';

  @override
  String meetingRevision(String n) {
    return 'ویرایش $n';
  }

  @override
  String meetingCreatedBy(String name) {
    return 'ایجاد‌کننده: $name';
  }

  @override
  String get meetingAttendanceHint => 'برای ثبت حضور روی وضعیت هر نفر بزنید';

  @override
  String get meetingNoAttendees => 'حاضری ثبت نشده است';

  @override
  String get meetingMarkAttendance => 'ثبت حضور';

  @override
  String get meetingMinutes => 'صورتجلسه';

  @override
  String get meetingEditMinutes => 'ویرایش متن';

  @override
  String get meetingNoMinutes => 'هنوز متنی نوشته نشده است.';

  @override
  String get meetingSignatures => 'امضاها';

  @override
  String get meetingAllSigned => 'همه امضا کرده‌اند';

  @override
  String get meetingNoSignatures => 'هنوز امضایی نیست.';

  @override
  String get meetingSign => 'امضای صورتجلسه';

  @override
  String get meetingSignatureStale => 'منسوخ';

  @override
  String get meetingResolutions => 'مصوبات';

  @override
  String get resolutionAdd => 'افزودن مصوبه';

  @override
  String get resolutionEdit => 'ویرایش';

  @override
  String get resolutionDeactivate => 'غیرفعال کردن';

  @override
  String get resolutionDeactivateConfirm =>
      'این مصوبه و وظیفه پیگیری آن لغو شود؟';

  @override
  String get resolutionOwners => 'مسئولان';

  @override
  String get resolutionDue => 'سررسید';

  @override
  String get resolutionTask => 'وظیفه';

  @override
  String get resolutionText => 'متن مصوبه';

  @override
  String get resolutionOpen => 'باز';

  @override
  String get resolutionDone => 'انجام شد';

  @override
  String get resolutionCancelled => 'لغوشده';

  @override
  String get meetingNoResolutions => 'مصوبه‌ای ثبت نشده است.';

  @override
  String get meetingSignTitle => 'امضای صورتجلسه';

  @override
  String get meetingSignApproveHint => 'با صورتجلسه موافقم';

  @override
  String get meetingSignRejectHint => 'با صورتجلسه موافق نیستم';

  @override
  String get meetingSignNoteRequired => 'یادداشت (برای رد الزامی است)';

  @override
  String get meetingRejectNeedsNote => 'برای رد کردن باید یادداشت بنویسید.';

  @override
  String meetingSignReason(String title) {
    return 'امضای صورتجلسه: $title';
  }

  @override
  String get meetingActionSchedule => 'برنامه‌ریزی';

  @override
  String get meetingActionHold => 'شروع جلسه';

  @override
  String get meetingActionClose => 'بستن صورتجلسه';

  @override
  String get meetingActionReopen => 'بازگشایی';

  @override
  String get meetingActionCancel => 'لغو جلسه';

  @override
  String get meetingRemind => 'یادآوری به حاضرین';

  @override
  String get meetingSms => 'پیامک به حاضرین';

  @override
  String get meetingRemindTitle => 'یادآوری به حاضرین';

  @override
  String get meetingRemindBefore => 'چه مدت قبل از شروع';

  @override
  String meetingOffsetDays(String n) {
    return '$n روز';
  }

  @override
  String meetingOffsetHours(String n) {
    return '$n ساعت';
  }

  @override
  String meetingOffsetMinutes(String n) {
    return '$n دقیقه';
  }

  @override
  String meetingRemindDone(String n) {
    return '$n یادآوری ثبت شد';
  }

  @override
  String get meetingSmsTitle => 'پیامک به حاضرین';

  @override
  String get meetingSmsText => 'متن پیامک';

  @override
  String get meetingSmsSend => 'ارسال';

  @override
  String meetingSmsDone(String sent, String without) {
    return 'ارسال‌شده: $sent، بدون شماره: $without';
  }

  @override
  String get meetingPrint => 'چاپ صورتجلسه';

  @override
  String get meetingPrintTitle => 'صورتجلسه';

  @override
  String get meetingPrintDate => 'تاریخ';

  @override
  String get moduleNotes => 'یادداشت‌ها';

  @override
  String get notesSearchHint => 'جستجو در یادداشت‌ها';

  @override
  String get notesViewGrid => 'نمایش شبکه‌ای';

  @override
  String get notesViewList => 'نمایش فهرستی';

  @override
  String get notesArchiveToggle => 'آرشیو';

  @override
  String get notesNew => 'یادداشت جدید';

  @override
  String get notesPinned => 'سنجاق‌شده';

  @override
  String get notesOthers => 'سایر';

  @override
  String get notesEmptyTitle => 'یادداشتی ندارید';

  @override
  String get notesEmptyMessage =>
      'با دکمه «یادداشت جدید» اولین یادداشت خود را بنویسید. یادداشت‌ها فقط برای شما دیده می‌شوند.';

  @override
  String get notesEmptyArchived => 'یادداشت آرشیوشده‌ای وجود ندارد';

  @override
  String get notesLoadFailed => 'بارگذاری یادداشت‌ها ممکن نشد';

  @override
  String get noteEdit => 'ویرایش یادداشت';

  @override
  String get noteTitleHint => 'عنوان';

  @override
  String get noteBodyHint => 'یادداشت';

  @override
  String noteColorName(String n) {
    return 'رنگ $n';
  }

  @override
  String get notePin => 'سنجاق کردن';

  @override
  String get noteUnpin => 'برداشتن سنجاق';

  @override
  String get noteArchive => 'بایگانی';

  @override
  String get noteUnarchive => 'خارج کردن از آرشیو';

  @override
  String get noteChecklistAddHint => 'افزودن مورد';

  @override
  String get noteChecklistAdd => 'افزودن';

  @override
  String get noteItemUp => 'انتقال به بالا';

  @override
  String get noteItemDown => 'انتقال به پایین';

  @override
  String get noteItemRemove => 'حذف مورد';

  @override
  String get noteImageAdd => 'افزودن تصویر';

  @override
  String get noteImageRemove => 'حذف تصویر';

  @override
  String get noteImageOnly => 'فقط پرونده تصویر مجاز است.';
}
