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

  @override
  String get moduleChat => 'گفتگو';

  @override
  String get chatTabMine => 'گفتگوهای من';

  @override
  String get chatTabPublic => 'عمومی';

  @override
  String get chatSearchHint => 'متن پیام';

  @override
  String get chatKindGroup => 'گروه';

  @override
  String get chatKindChannel => 'کانال';

  @override
  String get chatKindDm => 'پیام مستقیم';

  @override
  String get chatLoadFailed => 'بارگذاری گفتگوها ممکن نشد';

  @override
  String get chatEmptyTitle => 'هنوز گفتگویی ندارید';

  @override
  String get chatEmptyMessage =>
      'یک گروه بسازید یا از فهرست همکاران پیام مستقیم بفرستید.';

  @override
  String get chatEmptyPublic => 'گروه یا کانال عمومی‌ای برای پیوستن نیست.';

  @override
  String get chatNew => 'گفتگوی جدید';

  @override
  String get chatNewGroup => 'گروه جدید';

  @override
  String get chatNewChannel => 'کانال جدید';

  @override
  String get chatNewDm => 'پیام مستقیم';

  @override
  String get chatPinConv => 'سنجاق کردن گفتگو';

  @override
  String get chatUnpinConv => 'برداشتن سنجاق گفتگو';

  @override
  String get chatMute => 'بی‌صدا کردن';

  @override
  String get chatUnmute => 'فعال کردن صدا';

  @override
  String get chatJoin => 'پیوستن';

  @override
  String get chatLeave => 'ترک گفتگو';

  @override
  String get chatLeaveConfirm => 'این گفتگو را ترک می‌کنید؟';

  @override
  String chatMembersCount(String count) {
    return '$count عضو';
  }

  @override
  String get chatName => 'نام';

  @override
  String get chatDescription => 'توضیحات (اختیاری)';

  @override
  String get chatPublicSwitch => 'عمومی (همه می‌توانند پیدا کنند و بپیوندند)';

  @override
  String get chatPostPolicy => 'چه کسی می‌تواند پیام بدهد';

  @override
  String get chatPostAll => 'همه اعضا';

  @override
  String get chatPostAdmins => 'فقط مدیران';

  @override
  String get chatMembers => 'اعضا';

  @override
  String get chatAddMembers => 'افزودن اعضا';

  @override
  String get chatNameRequired => 'نام را وارد کنید';

  @override
  String get chatCreate => 'ایجاد';

  @override
  String get chatCreateForbidden => 'اجازه ساختن گروه یا کانال را ندارید.';

  @override
  String get chatDmPickTitle => 'شروع گفتگوی مستقیم';

  @override
  String get chatDirectorySearch => 'جستجوی همکار';

  @override
  String get chatMessageHint => 'پیام بنویسید';

  @override
  String get chatSend => 'ارسال';

  @override
  String get chatAttach => 'پیوست پرونده';

  @override
  String get chatPaste => 'چسباندن از کلیپ‌بورد';

  @override
  String get chatPasteEmpty => 'چیزی برای چسباندن نیست.';

  @override
  String get chatMention => 'اشاره به همکار';

  @override
  String get chatVoice => 'پیام صوتی';

  @override
  String get chatReply => 'پاسخ';

  @override
  String chatReplyingTo(String name) {
    return 'پاسخ به $name';
  }

  @override
  String get chatCancelReply => 'لغو پاسخ';

  @override
  String get chatDelete => 'حذف پیام';

  @override
  String get chatDeleteConfirm => 'این پیام حذف شود؟';

  @override
  String get chatDeleted => 'این پیام حذف شد';

  @override
  String get chatPinMessage => 'سنجاق پیام';

  @override
  String get chatUnpinMessage => 'برداشتن سنجاق پیام';

  @override
  String get chatBookmark => 'نشان کردن';

  @override
  String get chatBookmarked => 'پیام نشان شد.';

  @override
  String get chatToTask => 'تبدیل به وظیفه';

  @override
  String get chatSeenBy => 'چه کسی دیده است';

  @override
  String get chatCopy => 'رونوشت متن';

  @override
  String chatPinsBar(String count) {
    return '$count پیام سنجاق‌شده';
  }

  @override
  String get chatJumpToDate => 'رفتن به تاریخ';

  @override
  String get chatJumpLatest => 'رفتن به آخرین پیام';

  @override
  String get chatNoMessagesOnDate => 'از این تاریخ به بعد پیامی نیست.';

  @override
  String get chatSeenTitle => 'دیده‌شده توسط';

  @override
  String get chatSeenEmpty => 'هنوز کسی ندیده است.';

  @override
  String get chatSeenUntracked => 'در گفتگوهای بزرگ رسید خواندن ثبت نمی‌شود.';

  @override
  String get chatSeenFailed => 'بارگذاری رسیدها ممکن نشد.';

  @override
  String get chatNotMember => 'برای دیدن پیام‌ها ابتدا بپیوندید.';

  @override
  String get chatArchivedNote => 'این گفتگو بایگانی شده است.';

  @override
  String get chatReadOnly => 'فقط مدیران می‌توانند پیام بدهند.';

  @override
  String get chatSendFailed => 'ارسال پیام ممکن نشد.';

  @override
  String get chatActionFailed => 'انجام این کار ممکن نشد.';

  @override
  String get chatForbidden => 'اجازه انجام این کار را ندارید.';

  @override
  String get chatDownload => 'دریافت پرونده';

  @override
  String get chatEdited => 'ویرایش‌شده';

  @override
  String get chatTaskCreated => 'وظیفه‌ای از یک پیام ساخته شد.';

  @override
  String get chatInfo => 'اطلاعات گفتگو';

  @override
  String get chatAdminRole => 'مدیر';

  @override
  String get chatMentionSearch => 'جستجوی عضو';

  @override
  String get chatMessageToTaskPrefix => 'پیام گفتگو';

  @override
  String get chatSeen => 'دیده شد';

  @override
  String get chatToday => 'امروز';

  @override
  String get chatUnreadMentions => 'اشاره‌ها';

  @override
  String get monTitle => 'پایش';

  @override
  String get monMyNumbers => 'اعداد من';

  @override
  String get monOpenTasks => 'کار باز';

  @override
  String get monOverdue => 'عقب‌افتاده';

  @override
  String get monDone => 'انجام‌شده';

  @override
  String get monLettersWaiting => 'نامه منتظر شما';

  @override
  String get monMeetingsToday => 'جلسه امروز';

  @override
  String get monUnreadChat => 'پیام خوانده‌نشده';

  @override
  String get monRemindersToday => 'یادآور امروز';

  @override
  String get monTabOverview => 'نمای کلی';

  @override
  String get monTabProjects => 'پروژه‌ها';

  @override
  String get monTabTasks => 'کارها';

  @override
  String get monTabMeetings => 'جلسات';

  @override
  String get monTabMembers => 'اعضا';

  @override
  String get monTabOnline => 'آنلاین';

  @override
  String get monTabCustomers => 'مشتریان';

  @override
  String get monTabFinance => 'مالی';

  @override
  String get monTabSales => 'فروش';

  @override
  String get monPeriodWeek => 'هفته';

  @override
  String get monPeriodMonth => 'ماه';

  @override
  String get monPeriodQuarter => 'فصل';

  @override
  String get monPeriodYear => 'سال';

  @override
  String get monPeriodCustom => 'بازه دلخواه';

  @override
  String get monBucketDay => 'روزانه';

  @override
  String get monBucketWeek => 'هفتگی';

  @override
  String get monBucketMonth => 'ماهانه';

  @override
  String get monFrom => 'از';

  @override
  String get monTo => 'تا';

  @override
  String get monChat => 'پیام‌های گفتگو';

  @override
  String get monLetters => 'نامه‌ها';

  @override
  String get monTasks => 'کارها';

  @override
  String get monCustomers => 'مشتریان';

  @override
  String get monMeetings => 'جلسات';

  @override
  String get monProjectsTitle => 'پروژه‌ها';

  @override
  String get monCreated => 'ایجادشده';

  @override
  String get monCompleted => 'تکمیل‌شده';

  @override
  String get monSigned => 'امضاشده';

  @override
  String get monEvents => 'رویدادها';

  @override
  String get monMessages => 'پیام';

  @override
  String get monSortLastDone => 'آخرین کار انجام‌شده';

  @override
  String get monSortMostOverdue => 'بیشترین عقب‌افتادگی';

  @override
  String get monSortLeastOverdue => 'کمترین عقب‌افتادگی';

  @override
  String get monSortCompleted => 'بیشترین انجام‌شده';

  @override
  String get monSortActivity => 'فعالیت';

  @override
  String get monGroups => 'گروه‌های پروژه';

  @override
  String get monNoGroup => 'بدون گروه';

  @override
  String get monProjectsCount => 'پروژه';

  @override
  String get monOverdueReport => 'گزارش عقب‌افتاده‌ها';

  @override
  String get monLate => 'تأخیر';

  @override
  String get monDays => 'روز';

  @override
  String get monHours => 'ساعت';

  @override
  String get monFilterProject => 'پروژه';

  @override
  String get monFilterLabel => 'برچسب';

  @override
  String get monFilterPerson => 'فرد';

  @override
  String get monFilterCustomer => 'مشتری';

  @override
  String get monFilterAll => 'همه';

  @override
  String get monFilterNoProject => 'بدون پروژه';

  @override
  String get monPrint => 'چاپ فهرست';

  @override
  String get monPrintTitle => 'گزارش کارهای عقب‌افتاده';

  @override
  String get monMeetingProjectFilter => 'عنوان پروژه';

  @override
  String get monInvited => 'دعوت‌شده';

  @override
  String get monPresent => 'حاضر';

  @override
  String get monOpenResolutions => 'مصوبهٔ باز';

  @override
  String get monOnTime => 'به‌موقع';

  @override
  String get monLateDone => 'با تأخیر';

  @override
  String get monAvgDelay => 'میانگین تأخیر (روز)';

  @override
  String get monLettersSigned => 'نامه امضاشده';

  @override
  String get monMeetingsAttended => 'جلسه حاضر';

  @override
  String get monOnlineNow => 'آنلاین';

  @override
  String get monLastActive => 'آخرین فعالیت';

  @override
  String get monNever => 'هرگز';

  @override
  String get monHistory => 'سابقهٔ ورود و دستگاه‌ها';

  @override
  String get monRevoked => 'خروج‌شده';

  @override
  String get monTheirTasks => 'کارهای این فرد';

  @override
  String get monQuiet => 'مشتریان بی‌حرکت';

  @override
  String get monQuietHint => 'بدون رویداد در ۳۰ روز اخیر';

  @override
  String get monCustomerTotal => 'کل پرونده‌ها';

  @override
  String get monCreatedInPeriod => 'ایجادشده در بازه';

  @override
  String get monLastEvent => 'آخرین رویداد';

  @override
  String get monReceipts => 'دریافت قطعی';

  @override
  String get monPayments => 'پرداخت قطعی';

  @override
  String get monNet => 'خالص';

  @override
  String get monProbableReceipts => 'دریافت محتمل';

  @override
  String get monProbablePayments => 'پرداخت محتمل';

  @override
  String get monOverdueReceipts => 'دریافت معوق';

  @override
  String get monOverduePayments => 'پرداخت معوق';

  @override
  String get monSalesWon => 'برده‌شده';

  @override
  String get monSalesOpen => 'باز';

  @override
  String get monSalesLost => 'ازدست‌رفته';

  @override
  String get monAccess => 'دسترسی';

  @override
  String get monAccessTitle => 'دسترسی گروه';

  @override
  String get monAccessAdd => 'افزودن عضو';

  @override
  String get monAccessRemove => 'حذف دسترسی';

  @override
  String get monAccessSaved => 'دسترسی ذخیره شد';

  @override
  String get monRoleManager => 'مدیر';

  @override
  String get monRoleMember => 'عضو';

  @override
  String get monRoleViewer => 'بیننده';

  @override
  String get monAccessPick => 'انتخاب فرد';

  @override
  String get monEmpty => 'داده‌ای برای نمایش نیست';

  @override
  String get monStatusOpen => 'باز';

  @override
  String get monStatusAwaiting => 'در انتظار';

  @override
  String get monStatusDone => 'انجام‌شده';

  @override
  String get monStatusCancelled => 'لغوشده';

  @override
  String get monTotal => 'کل';

  @override
  String get commonRial => 'ریال';

  @override
  String get moneyFiles => 'پیوست‌ها';

  @override
  String get moneyLabels => 'برچسب‌ها';

  @override
  String get moneyVoidReasonRequired => 'دلیل را بنویسید.';

  @override
  String get moneyChartLabel => 'نمودار میله‌ای';

  @override
  String get moduleFinance => 'مالی';

  @override
  String get moduleSales => 'فروش';

  @override
  String get moduleCrm => 'مشتریان';

  @override
  String get crmTitle => 'پرونده مشتری';

  @override
  String get crmNew => 'مشتری جدید';

  @override
  String get crmEditTitle => 'ویرایش مشتری';

  @override
  String get crmSearchHint => 'جستجوی نام، تلفن، ایمیل یا کد ملی';

  @override
  String get crmFilterAll => 'همه';

  @override
  String get crmLoadMore => 'نمایش بیشتر';

  @override
  String get crmLoadFailed => 'بارگیری مشتریان ممکن نشد';

  @override
  String get crmEmptyTitle => 'مشتری‌ای پیدا نشد';

  @override
  String get crmEmptyMessage => 'با دکمه «مشتری جدید» اولین پرونده را بسازید.';

  @override
  String get crmKindPerson => 'شخص';

  @override
  String get crmKindCompany => 'شرکت';

  @override
  String get crmStatusActive => 'فعال';

  @override
  String get crmStatusInactive => 'غیرفعال';

  @override
  String get crmStatusArchived => 'بایگانی';

  @override
  String get crmRoleManager => 'مدیر';

  @override
  String get crmRoleMember => 'عضو';

  @override
  String get crmRoleViewer => 'ناظر';

  @override
  String get crmFieldKind => 'نوع';

  @override
  String get crmFieldStatus => 'وضعیت';

  @override
  String get crmFieldName => 'نام';

  @override
  String get crmFieldLegalName => 'نام حقوقی';

  @override
  String get crmFieldRegistrationNo => 'شماره ثبت';

  @override
  String get crmFieldNationalId => 'کد ملی / شناسه ملی';

  @override
  String get crmFieldPhone => 'تلفن';

  @override
  String get crmFieldMobile => 'موبایل';

  @override
  String get crmFieldEmail => 'ایمیل';

  @override
  String get crmFieldAddress => 'نشانی';

  @override
  String get crmFieldNotes => 'یادداشت‌ها';

  @override
  String get crmFieldOwner => 'مسئول پرونده';

  @override
  String get crmNameRequired => 'نام را وارد کنید.';

  @override
  String get crmLimitReached => 'سقف تعداد پرونده‌های مشتری پر شده است.';

  @override
  String get crmSaveFailed => 'ذخیره انجام نشد';

  @override
  String get crmTabOverview => 'نمای کلی';

  @override
  String get crmTabTimeline => 'خط زمانی';

  @override
  String get crmTabTasks => 'وظایف';

  @override
  String get crmTabMeetings => 'جلسات';

  @override
  String get crmTabLetters => 'نامه‌ها';

  @override
  String get crmTabFiles => 'پرونده‌ها و اسناد';

  @override
  String get crmTabCalls => 'گزارش تماس';

  @override
  String get crmTabFinance => 'مالی';

  @override
  String get crmTabLeads => 'فروش';

  @override
  String get crmTabChat => 'گفتگو';

  @override
  String get crmTabMembers => 'اعضا';

  @override
  String get crmNoteHint => 'یادداشت جدید برای خط زمانی';

  @override
  String get crmNoteAdd => 'افزودن یادداشت';

  @override
  String get crmTimelineEmpty => 'هنوز رویدادی ثبت نشده.';

  @override
  String get crmEventNote => 'یادداشت';

  @override
  String get crmEventCall => 'تماس';

  @override
  String get crmEventMeeting => 'جلسه';

  @override
  String get crmEventFinance => 'مالی';

  @override
  String get crmEventLead => 'فروش';

  @override
  String get crmEventSystem => 'سیستم';

  @override
  String get crmEventTask => 'وظیفه';

  @override
  String get crmEventLetter => 'نامه';

  @override
  String get crmTasksEmpty => 'وظیفه‌ای به این پرونده وصل نیست.';

  @override
  String get crmTaskNew => 'وظیفه جدید';

  @override
  String get crmMeetingsEmpty => 'جلسه‌ای به این پرونده وصل نیست.';

  @override
  String get crmMeetingNew => 'جلسه جدید';

  @override
  String get crmLettersEmpty => 'نامه‌ای به این پرونده وصل نیست.';

  @override
  String get crmCallsEmpty => 'تماسی ثبت نشده.';

  @override
  String get crmCallNew => 'ثبت تماس';

  @override
  String get crmCallIn => 'ورودی';

  @override
  String get crmCallOut => 'خروجی';

  @override
  String get crmCallContact => 'نام مخاطب';

  @override
  String get crmCallSummary => 'خلاصه گفتگو';

  @override
  String get crmCallDuration => 'مدت (دقیقه)';

  @override
  String get crmCallNoContact => 'بدون نام';

  @override
  String get crmCallToTask => 'تبدیل به وظیفه';

  @override
  String get crmCallTaskCreated => 'وظیفه پیگیری ساخته شد.';

  @override
  String get crmMembersAdd => 'افزودن عضو';

  @override
  String get crmMemberRemove => 'حذف عضو';

  @override
  String get crmImport => 'درون‌ریزی از اکسل';

  @override
  String get crmImportHelp =>
      'فایل CSV یا xlsx با ستون‌های kind, name, legal_name, national_id, phone, mobile, email, address, status انتخاب کنید؛ فقط name الزامی است.';

  @override
  String get crmImportPick => 'انتخاب فایل';

  @override
  String get crmImportFailed => 'درون‌ریزی انجام نشد.';

  @override
  String crmCallMinutes(String minutes) {
    return '$minutes دقیقه';
  }

  @override
  String crmImportRow(String row) {
    return 'ردیف $row';
  }

  @override
  String crmImportSummary(String created, String skipped, String errors) {
    return '$created ایجاد، $skipped ردشده، $errors خطا';
  }

  @override
  String get financeTabDocs => 'اسناد';

  @override
  String get financeTabReport => 'گزارش';

  @override
  String get financeTabMonitor => 'پایش';

  @override
  String get financeNew => 'سند مالی جدید';

  @override
  String get financeEdit => 'ویرایش سند مالی';

  @override
  String get financeSearchHint => 'جستجو در مشتری، مبلغ و توضیحات';

  @override
  String get financeLoadFailed => 'بارگذاری اسناد مالی ممکن نشد';

  @override
  String get financeEmptyTitle => 'سندی پیدا نشد';

  @override
  String get financeEmptyMessage =>
      'با دکمه «سند مالی جدید» اولین سند را ثبت کنید.';

  @override
  String get financeFilterAll => 'همه';

  @override
  String get financeKindCash => 'نقد';

  @override
  String get financeKindCheque => 'چک';

  @override
  String get financeKindProbable => 'احتمالی';

  @override
  String get financeKindVoid => 'باطل';

  @override
  String get financeDirReceipt => 'دریافت';

  @override
  String get financeDirPayment => 'پرداخت';

  @override
  String get financeStatusConfirmed => 'قطعی';

  @override
  String get financeStatusPending => 'در انتظار';

  @override
  String get financeStatusVoid => 'باطل‌شده';

  @override
  String get financeOverdue => 'سررسید گذشته';

  @override
  String get financeKind => 'نوع سند';

  @override
  String get financeDirection => 'جهت';

  @override
  String get financeAmount => 'مبلغ (ریال)';

  @override
  String get financeDate => 'تاریخ';

  @override
  String get financeDueDate => 'تاریخ سررسید';

  @override
  String get financeDescription => 'توضیحات';

  @override
  String financeCustomer(String name) {
    return 'مشتری: $name';
  }

  @override
  String get financeAmountInvalid => 'مبلغ باید عددی مثبت باشد.';

  @override
  String get financeDueRequired =>
      'برای چک و سند احتمالی تاریخ سررسید لازم است.';

  @override
  String get financeSaved => 'سند ذخیره شد.';

  @override
  String get financeSaveFirstFiles =>
      'برای پیوست فایل، ابتدا سند را ذخیره کنید.';

  @override
  String get financeConfirm => 'قطعی‌سازی';

  @override
  String get financeConfirmed => 'سند قطعی شد.';

  @override
  String get financeVoid => 'ابطال سند';

  @override
  String get financeVoidReason => 'دلیل ابطال';

  @override
  String get financeVoidSubmit => 'ابطال';

  @override
  String financeVoidedBanner(String reason) {
    return 'این سند باطل شده است: $reason';
  }

  @override
  String get financeReportMonthly => 'ماهانه';

  @override
  String get financeReportYearly => 'سالانه';

  @override
  String get financeReportEmpty => 'داده‌ای برای گزارش نیست.';

  @override
  String get financeColPeriod => 'دوره';

  @override
  String get financeColReceipts => 'دریافتی';

  @override
  String get financeColPayments => 'پرداختی';

  @override
  String get financeColNet => 'خالص';

  @override
  String get financeTotals => 'جمع کل';

  @override
  String get financeProbableReceipts => 'دریافتی احتمالی';

  @override
  String get financeProbablePayments => 'پرداختی احتمالی';

  @override
  String get financeOverdueReceipts => 'دریافتی معوق';

  @override
  String get financeProjectedNet => 'خالص پیش‌بینی‌شده';

  @override
  String get financeChartTitle => 'دریافتی و پرداختی قطعی';

  @override
  String financeDrillTitle(String period) {
    return 'اسناد $period';
  }

  @override
  String get financeMonitorTitle => 'دریافتی‌های احتمالی و معوق';

  @override
  String get financeMonitorOverdue => 'معوق';

  @override
  String get financeMonitorUpcoming => 'در راه';

  @override
  String get financeMonitorEmpty => 'دریافتی احتمالی یا معوقی وجود ندارد.';

  @override
  String get financeCustomerTitle => 'گزارش مالی مشتری';

  @override
  String get financeCustomerEmpty => 'سند مالی برای این مشتری ثبت نشده.';

  @override
  String get salesTabLeads => 'فرصت‌ها';

  @override
  String get salesTabMonitor => 'پایش فروش';

  @override
  String get salesNew => 'فرصت فروش جدید';

  @override
  String get salesEdit => 'ویرایش فرصت فروش';

  @override
  String get salesSearchHint => 'جستجو در عنوان و مشتری';

  @override
  String get salesLoadFailed => 'بارگذاری فرصت‌های فروش ممکن نشد';

  @override
  String get salesEmptyTitle => 'فرصت فروشی پیدا نشد';

  @override
  String get salesEmptyMessage =>
      'با دکمه «فرصت فروش جدید» اولین فرصت را ثبت کنید.';

  @override
  String get salesStatusOpen => 'باز';

  @override
  String get salesStatusWon => 'موفق';

  @override
  String get salesStatusLost => 'ناموفق';

  @override
  String get salesTitle => 'عنوان';

  @override
  String get salesValue => 'ارزش (ریال)';

  @override
  String salesProbability(String percent) {
    return 'احتمال موفقیت: $percent٪';
  }

  @override
  String get salesOwner => 'مسئول';

  @override
  String get salesDescription => 'توضیحات';

  @override
  String get salesTitleRequired => 'عنوان را بنویسید.';

  @override
  String get salesSaved => 'فرصت ذخیره شد.';

  @override
  String get salesSaveFirstFiles =>
      'برای پیوست فایل، ابتدا فرصت را ذخیره کنید.';

  @override
  String get salesWin => 'موفق شد';

  @override
  String get salesLose => 'ناموفق بود';

  @override
  String get salesLoseReason => 'دلیل ناموفق بودن';

  @override
  String get salesLoseSubmit => 'ثبت';

  @override
  String get salesReopen => 'بازگشایی';

  @override
  String salesWeighted(String amount) {
    return 'ارزش وزنی: $amount';
  }

  @override
  String salesLostBanner(String reason) {
    return 'این فرصت ناموفق بسته شد: $reason';
  }

  @override
  String get salesMonitorWon => 'فروش موفق';

  @override
  String get salesMonitorProbable => 'فروش احتمالی (وزنی)';

  @override
  String get salesMonitorOpen => 'مجموع فرصت‌های باز';

  @override
  String get salesMonitorChart => 'موفق در برابر احتمالی';

  @override
  String get salesByBucket => 'فرصت‌های باز بر اساس احتمال';

  @override
  String salesBucketLeads(String bucket) {
    return 'فرصت‌های با احتمال $bucket';
  }

  @override
  String get salesWonByMonth => 'فروش موفق به تفکیک ماه';

  @override
  String salesCountValue(String count) {
    return '$count فرصت';
  }

  @override
  String get salesCustomerTitle => 'فرصت‌های فروش مشتری';

  @override
  String get salesCustomerEmpty => 'فرصت فروشی برای این مشتری ثبت نشده.';

  @override
  String get openFailed => 'باز کردن مورد ممکن نشد';

  @override
  String get bookmarkAdd => 'نشان‌دار کردن';

  @override
  String get bookmarkRemove => 'حذف نشان';

  @override
  String get bookmarkFailed => 'ذخیره نشان ممکن نشد';

  @override
  String get bookmarksTitle => 'نشان‌شده‌ها';

  @override
  String get bookmarksEmpty => 'هنوز چیزی نشان نکرده‌اید';

  @override
  String get bookmarksEmptyHint =>
      'با ستاره بالای وظیفه، نامه یا جلسه آن را نشان کنید.';

  @override
  String get bookmarksLoadFailed => 'بارگذاری نشان‌شده‌ها ممکن نشد';

  @override
  String get pinnedTitle => 'سنجاق‌شده‌ها';

  @override
  String get pinnedEmpty => 'چیزی سنجاق نشده';

  @override
  String get pinnedEmptyHint =>
      'پروژه‌ها، مشتریان و گفتگوها را سنجاق کنید تا اینجا در دسترس باشند.';

  @override
  String get pinnedLoadFailed => 'بارگذاری سنجاق‌ها ممکن نشد';

  @override
  String get pinAdd => 'سنجاق کردن';

  @override
  String get pinRemove => 'برداشتن سنجاق';

  @override
  String get pinFailed => 'تغییر سنجاق ممکن نشد';

  @override
  String get searchTitle => 'جستجو';

  @override
  String get searchHint => 'جستجو در همه بخش‌ها و نام فایل‌ها';

  @override
  String get searchPrompt => 'جستجو کنید';

  @override
  String get searchMinChars => 'دست‌کم دو نویسه وارد کنید.';

  @override
  String get searchNoResults => 'نتیجه‌ای پیدا نشد';

  @override
  String get searchFailed => 'جستجو ممکن نشد';

  @override
  String get searchRateLimited =>
      'درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.';

  @override
  String get searchModuleCrm => 'مشتریان';

  @override
  String get searchModuleChat => 'گفتگو';

  @override
  String get searchModuleFinance => 'مالی';

  @override
  String get searchModuleSales => 'فروش';

  @override
  String get searchModuleFiles => 'فایل‌ها';

  @override
  String searchFileIn(String owner) {
    return 'این فایل در «$owner» است.';
  }

  @override
  String get calendarTitle => 'تقویم';

  @override
  String get calendarMonth => 'ماه';

  @override
  String get calendarWeek => 'هفته';

  @override
  String get calendarTeam => 'تیم';

  @override
  String get calendarColleagues => 'وظایف همکار';

  @override
  String get calendarFilters => 'فیلتر';

  @override
  String get calendarLoadFailed => 'بارگذاری تقویم ممکن نشد';

  @override
  String get calendarDayNothing => 'موردی در این روز نیست.';

  @override
  String get calendarAllDay => 'تمام روز';

  @override
  String get calendarKindTask => 'وظیفه';

  @override
  String get calendarKindMeeting => 'جلسه';

  @override
  String get calendarKindReminder => 'یادآوری';

  @override
  String get calendarKindProject => 'پروژه';

  @override
  String get calendarFilterProject => 'پروژه';

  @override
  String get calendarFilterLabel => 'برچسب';

  @override
  String get calendarFilterPerson => 'فرد';

  @override
  String get calendarFilterCustomer => 'مشتری';

  @override
  String get calendarFilterAll => 'همه';

  @override
  String get calendarFilterApply => 'اعمال';

  @override
  String get calendarFilterReset => 'پاک کردن فیلترها';

  @override
  String get calendarStatusAll => 'همه';

  @override
  String get calendarStatusOpen => 'باز';

  @override
  String get calendarStatusDone => 'انجام‌شده';

  @override
  String get calendarPickPerson => 'یک همکار را انتخاب کنید';

  @override
  String get calendarMonitorForbidden =>
      'اجازه مشاهده وظایف همکاران را ندارید.';

  @override
  String get calendarColleagueEmpty => 'وظیفه فعالی نیست.';

  @override
  String get settingsTitle => 'تنظیمات';

  @override
  String get settingsTheme => 'تم';

  @override
  String get settingsThemeLight => 'روشن';

  @override
  String get settingsThemeDark => 'تیره';

  @override
  String get settingsThemeAuto => 'خودکار';

  @override
  String get settingsBackground => 'تصویر پس‌زمینه';

  @override
  String get settingsBackgroundChoose => 'انتخاب تصویر';

  @override
  String get settingsBackgroundRemove => 'حذف تصویر';

  @override
  String get settingsTitleLabel => 'عنوان';

  @override
  String get settingsStatus => 'وضعیت';

  @override
  String get settingsBirthday => 'تاریخ تولد';

  @override
  String get settingsBirthdayVisible => 'نمایش تولد به همکاران';

  @override
  String get settingsDnd => 'مزاحم نشوید';

  @override
  String get settingsDndOff => 'خاموش است';

  @override
  String get settingsDndTurnOff => 'خاموش کردن';

  @override
  String settingsDndUntil(String when) {
    return 'تا $when';
  }

  @override
  String settingsDndHours(String hours) {
    return '$hours ساعت';
  }

  @override
  String get prefsFailed => 'ذخیره تنظیمات ممکن نشد';

  @override
  String get personalEmailTitle => 'ایمیل شخصی';

  @override
  String get personalEmailField => 'نشانی ایمیل';

  @override
  String get personalEmailSend => 'ارسال کد تأیید';

  @override
  String get personalEmailToken => 'کد تأیید';

  @override
  String get personalEmailVerify => 'تأیید ایمیل';

  @override
  String get personalEmailSent => 'کد تأیید به ایمیل ارسال شد.';

  @override
  String get personalEmailFailed => 'ارسال ممکن نشد؛ نشانی را بررسی کنید.';

  @override
  String get personalEmailVerified => 'ایمیل تأیید شد.';

  @override
  String get personalEmailBadToken => 'کد نامعتبر یا منقضی است.';

  @override
  String get personalEmailVerifiedBadge => 'تأییدشده';

  @override
  String get personalEmailUnverified => 'تأییدنشده';

  @override
  String get notificationsTitle => 'اعلان‌ها';

  @override
  String get notificationsMarkAll => 'خوانده شد';

  @override
  String get notificationsUnread => 'خوانده‌نشده';

  @override
  String get notificationsMentions => 'اشاره‌ها';

  @override
  String get notificationsEmpty => 'اعلانی نیست';

  @override
  String get notificationsNoMentions => 'کسی شما را نام نبرده';

  @override
  String get notificationsLoadFailed => 'بارگذاری اعلان‌ها ممکن نشد';

  @override
  String get authWelcomeTitle => 'خوش آمدید';

  @override
  String get authWelcomeSubtitle => 'برای ادامه وارد شوید';

  @override
  String get authNewHere => 'تازه آمده‌اید؟';

  @override
  String get authCreateAccount => 'ایجاد حساب';

  @override
  String get authEnterPassword => 'رمز عبور را وارد کنید';

  @override
  String get authSignIn => 'ورود';

  @override
  String get authForgotPassword => 'فراموشی رمز عبور';

  @override
  String get authServerUnreachable => 'اتصال به سرور برقرار نشد';

  @override
  String get authRegistered => 'ثبت‌نام انجام شد. اکنون وارد شوید.';

  @override
  String get authEmailVerified => 'ایمیل تأیید شد. اکنون وارد شوید.';

  @override
  String get authCheckEmailTitle => 'ایمیل خود را بررسی کنید';

  @override
  String get authCheckEmailSubtitle =>
      'کد ارسال‌شده به ایمیل را برای تأیید نشانی خود وارد کنید.';

  @override
  String get authVerifyTokenLabel => 'کد تأیید';

  @override
  String get authVerify => 'تأیید';

  @override
  String get authSignupSubtitle => 'به فضای کاری شرکت بپیوندید';

  @override
  String get authFullName => 'نام و نام خانوادگی';

  @override
  String get authEnterFullName => 'نام و نام خانوادگی را وارد کنید';

  @override
  String get authInviteCodeOptional => 'کد دعوت (اختیاری)';

  @override
  String get authInviteHelper => 'برای ثبت‌نام با ایمیل سازمانی، خالی بگذارید';

  @override
  String get authSignUp => 'ثبت‌نام';

  @override
  String get authHaveAccount => 'حساب کاربری دارید؟';

  @override
  String get authBackToSignIn => 'بازگشت به ورود';

  @override
  String get authResetTitle => 'بازیابی رمز عبور';

  @override
  String get authResetSubtitle =>
      'کدی به ایمیل شما می‌فرستیم، سپس رمز عبور جدید انتخاب می‌کنید.';

  @override
  String get authEmailMeToken => 'ارسال کد به ایمیل';

  @override
  String get authResetRequested =>
      'اگر حساب وجود داشته باشد، کد به ایمیل ارسال شد.';

  @override
  String get authHaveToken => 'کد دارید (ایمیل‌شده یا دریافتی از مدیر)؟';

  @override
  String get authToken => 'کد';

  @override
  String get authEnterToken => 'کد را وارد کنید';

  @override
  String get authNewPassword => 'رمز عبور جدید';

  @override
  String get authSetNewPassword => 'ثبت رمز عبور جدید';

  @override
  String get authPasswordChangedSignIn =>
      'رمز عبور تغییر کرد. اکنون وارد شوید.';

  @override
  String get authEmail => 'ایمیل';

  @override
  String get authPassword => 'رمز عبور';

  @override
  String get authEnterEmail => 'ایمیل را وارد کنید';

  @override
  String get authEnterValidEmail => 'نشانی ایمیل معتبر وارد کنید';

  @override
  String authPasswordHint(String min) {
    return 'حداقل $min نویسه؛ از رمزهای رایج استفاده نکنید';
  }

  @override
  String authPasswordTooShort(String min) {
    return 'حداقل $min نویسه وارد کنید';
  }

  @override
  String authPinDigits(String count) {
    return '$count رقم وارد کنید';
  }

  @override
  String get authShowPassword => 'نمایش رمز عبور';

  @override
  String get authHidePassword => 'پنهان کردن رمز عبور';

  @override
  String get authSigningPin => 'رمز امضا';

  @override
  String get permMember => 'عضو';

  @override
  String get permLetterCreate => 'ایجاد نامه';

  @override
  String get permLetterSee => 'مشاهده نامه‌ها';

  @override
  String get permLetterSign => 'امضای نامه';

  @override
  String get relTimeNow => 'هم‌اکنون';

  @override
  String relTimeMinutes(String n) {
    return '$n دقیقه پیش';
  }

  @override
  String relTimeHours(String n) {
    return '$n ساعت پیش';
  }

  @override
  String relTimeDays(String n) {
    return '$n روز پیش';
  }

  @override
  String get pollsTitle => 'نظرسنجی‌ها';

  @override
  String get pollsEmpty => 'هنوز نظرسنجی‌ای نیست';

  @override
  String get pollNew => 'نظرسنجی جدید';

  @override
  String get pollTitleField => 'عنوان';

  @override
  String get pollKind => 'نوع';

  @override
  String get pollKindPoll => 'نظرسنجی';

  @override
  String get pollKindQuiz => 'آزمون';

  @override
  String get pollAnonymity => 'ناشناس بودن';

  @override
  String get pollAnonPublic => 'عمومی: نام رأی‌دهندگان دیده می‌شود';

  @override
  String get pollAnonUsers => 'ناشناس برای اعضا: فقط مدیر نام‌ها را می‌بیند';

  @override
  String get pollAnonAll => 'کاملاً ناشناس';

  @override
  String get pollQuestionText => 'متن پرسش';

  @override
  String get pollAddQuestion => 'افزودن پرسش';

  @override
  String get pollRemoveQuestion => 'حذف پرسش';

  @override
  String get pollAddOption => 'افزودن گزینه';

  @override
  String get pollRemoveOption => 'حذف گزینه';

  @override
  String get pollOptionHint => 'گزینه';

  @override
  String get pollMultiple => 'چند پاسخ مجاز است';

  @override
  String get pollPoints => 'امتیاز';

  @override
  String get pollCorrectHint => 'گزینه‌های صحیح را علامت بزنید';

  @override
  String get pollCreate => 'ایجاد';

  @override
  String get pollTemplates => 'الگوها';

  @override
  String get pollNoTemplates => 'الگویی ذخیره نشده';

  @override
  String get pollSaveTemplate => 'ذخیره به‌عنوان الگو';

  @override
  String get pollTemplateName => 'نام الگو';

  @override
  String get pollTemplateSaved => 'الگو ذخیره شد';

  @override
  String get pollSubmit => 'ثبت پاسخ';

  @override
  String get pollChangeAnswer => 'تغییر پاسخ';

  @override
  String get pollSubmitted => 'پاسخ شما ثبت شد';

  @override
  String get pollClose => 'پایان نظرسنجی';

  @override
  String get pollCloseConfirm =>
      'با پایان‌دادن، دیگر پاسخی ثبت نمی‌شود. ادامه می‌دهید؟';

  @override
  String get pollClosedBadge => 'پایان‌یافته';

  @override
  String get pollOpenBadge => 'باز';

  @override
  String get pollResults => 'نتایج';

  @override
  String get pollVoteFirst => 'برای دیدن نتایج ابتدا پاسخ دهید';

  @override
  String get pollVoters => 'رأی‌دهندگان';

  @override
  String get pollVotersHidden => 'نام رأی‌دهندگان نمایش داده نمی‌شود';

  @override
  String get pollScores => 'امتیاز شرکت‌کنندگان';

  @override
  String get pollCorrect => 'پاسخ صحیح';

  @override
  String get pollPrint => 'چاپ';

  @override
  String get pollPrintTitle => 'نتایج آزمون';

  @override
  String get pollPrintDate => 'تاریخ';

  @override
  String get pollLoadFailed => 'بارگذاری نظرسنجی ممکن نشد';

  @override
  String get pollActionFailed => 'انجام کار ممکن نشد';

  @override
  String get pollForbidden => 'اجازهٔ این کار را ندارید';

  @override
  String get pollNoTitle => 'عنوان را بنویسید';

  @override
  String get pollNoQuestion =>
      'هر پرسش به متن نیاز دارد و دست‌کم یک پرسش لازم است';

  @override
  String get pollTooFewOptions => 'هر پرسش دست‌کم دو گزینهٔ پر دارد';

  @override
  String get pollNoCorrect => 'برای هر پرسش آزمون پاسخ صحیح انتخاب کنید';

  @override
  String get pollOpenPoll => 'باز کردن';

  @override
  String get pollNeedAnswer => 'دست‌کم یک گزینه انتخاب کنید';

  @override
  String pollQuestionN(String n) {
    return 'پرسش $n';
  }

  @override
  String pollParticipants(String count) {
    return '$count شرکت‌کننده';
  }

  @override
  String pollMyScore(String score, String max) {
    return 'امتیاز شما: $score از $max';
  }

  @override
  String pollScoreLine(String name, String score, String max) {
    return '$name: $score از $max';
  }

  @override
  String get pinNewLabel => 'رمز امضای جدید (۶ رقم)';

  @override
  String get pinRepeatLabel => 'تکرار رمز امضا';

  @override
  String get pinLoginPassword => 'رمز عبور ورود';

  @override
  String get pinEnterLoginPassword => 'رمز عبور ورود را وارد کنید';

  @override
  String get pinMismatch => 'رمزهای امضا یکسان نیستند';

  @override
  String get pinSave => 'ذخیره رمز امضا';

  @override
  String get pinGateTitle => 'رمز امضای خود را تعیین کنید';

  @override
  String get pinGateSubtitle =>
      'هر امضا را با این رمز ۶ رقمی، روی همه دستگاه‌هایتان تأیید می‌کنید.';

  @override
  String get bioCancelled => 'بررسی اثر انگشت / چهره لغو شد';

  @override
  String get bioDialogTitle => 'استفاده از اثر انگشت / چهره در این دستگاه';

  @override
  String get bioDialogBody =>
      'امضاها را بدون وارد کردن رمز امضا تأیید کنید و اجازه دهید دستگاه‌های دیگرتان از این دستگاه برای تأیید درخواست کنند. برای فعال‌سازی، یک بار رمز امضا را وارد کنید.';

  @override
  String get bioNotNow => 'فعلاً نه';

  @override
  String get bioEnable => 'فعال‌سازی';

  @override
  String get bioEnableOnDevice => 'فعال‌سازی اثر انگشت / چهره در این دستگاه';

  @override
  String get sessionsSignOutTitle => 'خروج این دستگاه؟';

  @override
  String sessionsSignOutBody(String name) {
    return '$name باید دوباره وارد شود.';
  }

  @override
  String get sessionsSignOutAction => 'خروج';

  @override
  String get sessionsLoadFailed => 'بارگذاری دستگاه‌ها ممکن نشد';

  @override
  String get sessionsEmpty => 'دستگاهی وارد نشده است';

  @override
  String get sessionsThisDevice => 'این دستگاه';

  @override
  String get sessionsBiometric => 'زیست‌سنجی';

  @override
  String sessionsActive(String when) {
    return 'آخرین فعالیت: $when';
  }

  @override
  String get sessionsEnableBiometric => 'فعال‌سازی اثر انگشت / چهره';

  @override
  String get sessionsSignOutDevice => 'خروج این دستگاه';

  @override
  String get profileSaved => 'ذخیره شد';

  @override
  String get profilePasswordChanged =>
      'رمز عبور تغییر کرد؛ از دستگاه‌های دیگر خارج شدید';

  @override
  String get profileManager => 'مدیر';

  @override
  String get profileSection => 'پروفایل';

  @override
  String get profileEnterName => 'نام را وارد کنید';

  @override
  String get profileJobTitle => 'سمت';

  @override
  String get profileDepartmentReadonly => 'دپارتمان (تعیین‌شده توسط مدیر)';

  @override
  String get profilePinChangeSubtitle =>
      'رمز ۶ رقمی تأییدکننده امضاهایتان را تغییر دهید';

  @override
  String get profilePinSetSubtitle =>
      'رمز ۶ رقمی تأییدکننده امضاهایتان را تعیین کنید';

  @override
  String get profilePinSaved => 'رمز امضا ذخیره شد';

  @override
  String get profileChangePassword => 'تغییر رمز عبور';

  @override
  String get profileChangePasswordSubtitle =>
      'پس از آن از دستگاه‌های دیگر خارج می‌شوید';

  @override
  String get profileCurrentPassword => 'رمز عبور فعلی';

  @override
  String get profileEnterCurrentPassword => 'رمز عبور فعلی را وارد کنید';

  @override
  String get adminResetTokenTitle => 'رمز بازیابی رمز عبور';

  @override
  String adminResetTokenBody(String email) {
    return 'این کد را به $email بدهید. فقط یک بار نمایش داده می‌شود.';
  }

  @override
  String get adminTokenCopied => 'کد کپی شد';

  @override
  String get adminCodeCopied => 'کد دعوت کپی شد';

  @override
  String get commonCopy => 'کپی';

  @override
  String get adminPermissions => 'دسترسی‌ها';

  @override
  String get adminAlwaysGranted => 'همیشه فعال';

  @override
  String get adminNewInviteTitle => 'کد دعوت جدید';

  @override
  String get adminMaxUses => 'حداکثر تعداد استفاده';

  @override
  String get adminUnlimitedHelper => 'برای نامحدود، خالی بگذارید';

  @override
  String get adminDepartment => 'دپارتمان';

  @override
  String get adminNone => 'بدون دپارتمان';

  @override
  String get adminInvitePermsHeader =>
      'دسترسی افرادی که با این کد وارد می‌شوند';

  @override
  String get commonCreate => 'ایجاد';

  @override
  String get adminLoadFailed => 'بارگذاری اطلاعات مدیریت ممکن نشد';

  @override
  String get adminSignupSection => 'ثبت‌نام';

  @override
  String get adminSignupSubtitle => 'نحوه پیوستن افراد جدید';

  @override
  String get adminDomainSignup => 'ثبت‌نام با ایمیل سازمانی';

  @override
  String adminDomainLabel(String domain) {
    return 'دامنه: $domain';
  }

  @override
  String get adminNeedsEmail => 'نیازمند پیکربندی ایمیل توسط مدیرکل است';

  @override
  String get adminInviteSignup => 'ثبت‌نام با کد دعوت';

  @override
  String get adminInvitesSection => 'کدهای دعوت';

  @override
  String get adminNewCode => 'کد جدید';

  @override
  String get adminNoCodes => 'هنوز کدی وجود ندارد';

  @override
  String get adminPeopleSection => 'افراد';

  @override
  String adminInviteUses(String max, String uses) {
    return '$uses از $max استفاده شده';
  }

  @override
  String get adminCopyCode => 'کپی کد';

  @override
  String get adminDeactivate => 'غیرفعال‌سازی';

  @override
  String get adminInactive => 'غیرفعال';

  @override
  String get adminDeactivated => 'غیرفعال‌شده';

  @override
  String get adminActions => 'عملیات';

  @override
  String get adminReactivate => 'فعال‌سازی مجدد';

  @override
  String get adminIssueResetToken => 'صدور کد بازیابی رمز';

  @override
  String get deptNew => 'دپارتمان جدید';

  @override
  String get deptRename => 'تغییر نام دپارتمان';

  @override
  String get deptName => 'نام';

  @override
  String get deptSection => 'دپارتمان‌ها';

  @override
  String get deptSubtitle => 'فقط مدیر می‌تواند این‌ها را تغییر دهد';

  @override
  String get deptNewShort => 'جدید';

  @override
  String get deptEmpty => 'هنوز دپارتمانی وجود ندارد';

  @override
  String deptMembers(String count) {
    return '$count نفر';
  }

  @override
  String get deptInactiveSuffix => 'غیرفعال';

  @override
  String get deptRenameTooltip => 'تغییر نام';

  @override
  String get letterheadSaved => 'سربرگ ذخیره شد';

  @override
  String get letterheadLogoInvalid =>
      'لوگو باید PNG یا JPEG و کمتر از ۲۰۰ کیلوبایت باشد';

  @override
  String get letterheadCompanyName => 'نام شرکت';

  @override
  String get letterheadTagline => 'زیرعنوان';

  @override
  String get letterheadAddress => 'نشانی';

  @override
  String get letterheadPhone => 'تلفن';

  @override
  String get letterheadEmail => 'ایمیل';

  @override
  String get letterheadWebsite => 'وب‌سایت';

  @override
  String get letterheadFooter => 'نشانی / تلفن (پایین هر صفحه)';

  @override
  String get letterheadTitle => 'سربرگ';

  @override
  String get letterheadHint => 'در بالا و پایین هر نامه چاپ می‌شود.';

  @override
  String get letterheadAddLogo => 'افزودن لوگو';

  @override
  String get letterheadChangeLogo => 'تغییر لوگو';

  @override
  String get letterheadRemoveLogo => 'حذف لوگو';

  @override
  String get letterheadSave => 'ذخیره سربرگ';

  @override
  String get lettersCreateSigners => 'امضاکنندگان';

  @override
  String get lettersCreateViewers => 'بینندگان';

  @override
  String get lettersCreateNoSignerCandidates =>
      'فعلاً کسی برای انتخاب نیست. امضاکننده باید کاربر دیگری با دسترسی امضای نامه (تعیین‌شده توسط مدیر) باشد.';

  @override
  String get lettersCreateNoViewerCandidates =>
      'فعلاً کسی برای انتخاب نیست. بینندگان باید از همکاران دیگر باشند.';

  @override
  String get lettersCreateTitleRequired => 'عنوان الزامی است';

  @override
  String get lettersCreateSignerRequired => 'دست‌کم یک امضاکننده اضافه کنید';

  @override
  String get lettersCreateDraftSaved => 'پیش‌نویس ذخیره شد';

  @override
  String get lettersCreateContent => 'محتوا';

  @override
  String get lettersCreateContentHint =>
      'عنوان در فهرست‌ها دیده می‌شود. متن نامه به‌صورت رمزنگاری‌شده روی سرور ذخیره می‌شود.';

  @override
  String get lettersCreateTitleLabel => 'عنوان';

  @override
  String get lettersCreateOnPaper => 'نوشتن روی کاغذ A4 (پیش‌نمایش و چاپ)';

  @override
  String lettersCreateAutosaved(String time) {
    return 'پیش‌نویس به‌طور خودکار ذخیره شد: $time';
  }

  @override
  String get lettersCreateBodyFormatted => 'متن (قالب‌بندی‌شده)';

  @override
  String get lettersCreateBody => 'متن';

  @override
  String get lettersCreateAttachments => 'پیوست‌ها';

  @override
  String get lettersCreateAttachmentsHint =>
      'PDF یا تصویر، حداکثر ۲۵ مگابایت برای هر فایل. فایل‌ها رمزنگاری‌شده روی سرور ذخیره می‌شوند.';

  @override
  String get lettersCreateRemove => 'حذف';

  @override
  String get lettersCreateAttach => 'افزودن PDF / تصویر (حداکثر ۲۵ مگابایت)';

  @override
  String get lettersCreateNoSigners => 'هنوز امضاکننده‌ای انتخاب نشده';

  @override
  String lettersCreateSignerN(String n) {
    return 'امضاکننده $n';
  }

  @override
  String get lettersCreatePeople => 'افراد';

  @override
  String get lettersCreatePeopleHint =>
      'چه کسانی نامه را امضا می‌کنند و چه کسانی می‌توانند آن را بخوانند.';

  @override
  String get lettersCreateChooseSigners => 'انتخاب امضاکنندگان';

  @override
  String get lettersCreateParallel => 'هم‌زمان';

  @override
  String get lettersCreateSerial => 'به‌ترتیب';

  @override
  String get lettersCreateSerialHelp =>
      'امضاکنندگان یکی‌یکی و از بالا به پایین امضا می‌کنند. برای تغییر ترتیب، بکشید.';

  @override
  String get lettersCreateParallelHelp =>
      'همه امضاکنندگان می‌توانند هم‌زمان امضا کنند.';

  @override
  String get lettersCreateVisibility => 'سطح دسترسی';

  @override
  String get lettersCreatePrivate => 'خصوصی';

  @override
  String get lettersCreatePublic => 'عمومی';

  @override
  String get lettersCreatePublicHelp =>
      'پس از انتشار، همه افراد شرکت می‌توانند آن را بخوانند.';

  @override
  String get lettersCreatePrivateHelp =>
      'فقط ایجادکننده، امضاکنندگان و بینندگان انتخاب‌شده می‌توانند آن را بخوانند.';

  @override
  String get lettersCreateNoViewers => 'بیننده اضافه‌ای نیست';

  @override
  String get lettersCreateChooseViewers => 'انتخاب بینندگان';

  @override
  String get lettersCreateDelivery => 'زمان نمایش';

  @override
  String get lettersCreateDeliveryHint =>
      'چه زمانی نامه برای مخاطبان قابل مشاهده می‌شود.';

  @override
  String get lettersCreateAfterSign => 'پس از امضای همه';

  @override
  String get lettersCreateRightAway => 'بلافاصله';

  @override
  String get lettersCreateNowHelp => 'بینندگان به‌محض ارسال، نامه را می‌بینند.';

  @override
  String get lettersCreateAfterSignHelp =>
      'بینندگان فقط پس از تأیید همه امضاکنندگان نامه را می‌بینند.';

  @override
  String get lettersCreateSaveDraft => 'ذخیره پیش‌نویس';

  @override
  String get lettersCreateWorking => 'در حال انجام...';

  @override
  String get lettersCreateSend => 'ارسال';

  @override
  String get lettersCreateNew => 'نامه جدید';

  @override
  String get lettersCreateNewChained => 'نامه زنجیره‌ای جدید';

  @override
  String get lettersAdminLoadFailed => 'بارگذاری نامه‌ها ممکن نشد';

  @override
  String get lettersAdminEmptyTitle => 'هنوز نامه‌ای نیست';

  @override
  String get lettersAdminEmptyMessage =>
      'عنوان و شرکت‌کنندگان همه نامه‌ها اینجا نمایش داده می‌شود.';

  @override
  String get lettersAdminTitle => 'همه نامه‌ها (مدیر)';

  @override
  String lettersAdminBy(String date, String email) {
    return 'ایجادکننده: $email  -  $date';
  }

  @override
  String get lettersAdminRoleSigner => 'امضاکننده';

  @override
  String get lettersAdminRoleViewer => 'بیننده';

  @override
  String get lettersAdminRelist => 'نمایش مجدد در فهرست';

  @override
  String get lettersAdminUnlist => 'حذف از فهرست';

  @override
  String get notifTooltip => 'اعلان‌ها';

  @override
  String get notifTitle => 'اعلان‌ها';

  @override
  String get notifMarkAllRead => 'خواندن همه';

  @override
  String get notifLoadFailed => 'بارگذاری اعلان‌ها ممکن نشد';

  @override
  String get notifEmptyTitle => 'فعلاً چیزی نیست';

  @override
  String get notifEmptyMessage =>
      'وقتی نامه‌ای نیازمند اقدام شما باشد، اطلاع داده می‌شود.';

  @override
  String get approvalTitle => 'تأیید امضا؟';

  @override
  String get approvalDecisionApprove => 'تصمیم: تأیید';

  @override
  String get approvalDecisionReject => 'تصمیم: رد';

  @override
  String approvalNote(String note) {
    return 'یادداشت: «$note»';
  }

  @override
  String approvalRequestedFrom(String device) {
    return 'درخواست از $device. فقط اگر این درخواست از طرف شما بوده است تأیید کنید.';
  }

  @override
  String get approvalAnotherDevice => 'دستگاه دیگر';

  @override
  String get approvalDecline => 'رد درخواست';

  @override
  String get approvalApprove => 'تأیید';

  @override
  String approvalBioReasonApprove(String title) {
    return 'تأیید امضا: $title';
  }

  @override
  String approvalBioReasonReject(String title) {
    return 'رد امضا: $title';
  }

  @override
  String get approvalBioFailed => 'بررسی اثر انگشت / چهره ناموفق بود';

  @override
  String get paperInk => 'مشکی';

  @override
  String get paperBlue => 'آبی';

  @override
  String get paperRed => 'قرمز';

  @override
  String get paperGreen => 'سبز';

  @override
  String get paperNewNumber => '(جدید)';

  @override
  String get paperHint => 'متن نامه را اینجا بنویسید...';

  @override
  String paperStatus(String chars, String pages, String pt, String words) {
    return '$words کلمه  |  $chars نویسه  |  $pages صفحه A4 با اندازه $pt پونت';
  }

  @override
  String get paperUndo => 'واگرد';

  @override
  String get paperRedo => 'بازگرد';

  @override
  String get paperBold => 'پررنگ';

  @override
  String get paperItalic => 'کج';

  @override
  String get paperUnderline => 'زیرخط';

  @override
  String get paperHeading => 'عنوان';

  @override
  String get paperSubheading => 'زیرعنوان';

  @override
  String get paperBullets => 'فهرست نقطه‌ای';

  @override
  String get paperNumbered => 'فهرست شماره‌دار';

  @override
  String get paperSmaller => 'متن کوچک‌تر';

  @override
  String get paperLarger => 'متن بزرگ‌تر';

  @override
  String get paperTextColor => 'رنگ متن';

  @override
  String get paperAlignStart => 'چین از ابتدا';

  @override
  String get paperAlignCenter => 'وسط‌چین';

  @override
  String get paperAlignEnd => 'چین از انتها';

  @override
  String get paperJustify => 'تراز دوطرفه';

  @override
  String get paperDirAllTooltip => 'جهت کل نامه';

  @override
  String get paperDirAllRtl => 'کل نامه راست‌به‌چپ';

  @override
  String get paperDirAllLtr => 'کل نامه چپ‌به‌راست';

  @override
  String get paperDirAllAuto => 'کل نامه خودکار';

  @override
  String get paperDirParaLtr => 'بند چپ‌به‌راست';

  @override
  String get paperDirParaRtl => 'بند راست‌به‌چپ';

  @override
  String get paperTitle => 'نوشتن روی کاغذ';

  @override
  String get paperDone => 'انجام شد';

  @override
  String get paperTabEdit => 'ویرایش';

  @override
  String get paperTabPreview => 'پیش‌نمایش';

  @override
  String get notifGroupEarlier => 'قدیمی‌تر';

  @override
  String get notifGroupToday => 'امروز';

  @override
  String get notifGroupYesterday => 'دیروز';

  @override
  String get lettersAdminUnlisted => 'خارج از فهرست';

  @override
  String get sessionsUnknownDevice => 'دستگاه ناشناس';

  @override
  String get projectTabGantt => 'گانت';

  @override
  String get secTitle => 'امنیت';

  @override
  String get secTwoFactor => 'ورود دومرحله‌ای';

  @override
  String get secTwoFactorHelp =>
      'با یک برنامه احراز هویت (مثل Google Authenticator) هر ورود با یک کد ۶ رقمی تأیید می‌شود.';

  @override
  String get secOn => 'فعال';

  @override
  String get secOff => 'غیرفعال';

  @override
  String get secRequiredByCompany =>
      'شرکت فعال‌سازی ورود دومرحله‌ای را الزامی کرده است.';

  @override
  String get secEnable => 'فعال‌سازی';

  @override
  String get secDisable => 'غیرفعال‌سازی';

  @override
  String get secDisabled => 'ورود دومرحله‌ای غیرفعال شد';

  @override
  String get secNewCodes => 'کدهای بازیابی جدید';

  @override
  String secCodesLeft(String count) {
    return 'کدهای بازیابی باقی‌مانده: $count';
  }

  @override
  String get secSetupSteps =>
      'کلید زیر را در برنامه احراز هویت وارد کنید (یا پیوند را باز کنید)، سپس کد ۶ رقمی نمایش‌داده‌شده را بنویسید.';

  @override
  String get secSecretKey => 'کلید مخفی';

  @override
  String get secSetupLink => 'پیوند otpauth';

  @override
  String get secAuthCode => 'کد ۶ رقمی برنامه';

  @override
  String get secConfirmEnable => 'تأیید و فعال‌سازی';

  @override
  String get secCodeInvalid => 'کد باید ۶ رقم باشد';

  @override
  String get secCodeRecoveryInvalid => 'کد بازیابی را وارد کنید';

  @override
  String get secCopy => 'کپی';

  @override
  String get secCopied => 'کپی شد';

  @override
  String get secProofMissing => 'رمز عبور و کد را وارد کنید';

  @override
  String get secPassword => 'رمز عبور';

  @override
  String get secRecoveryCode => 'کد بازیابی';

  @override
  String get secUseRecoveryCode => 'استفاده از کد بازیابی';

  @override
  String get secUseAppCode => 'استفاده از کد برنامه';

  @override
  String get secRecoveryTitle => 'کدهای بازیابی';

  @override
  String get secRecoveryWarning =>
      'این ۱۰ کد فقط همین یک بار نمایش داده می‌شوند. هر کد یک بار مصرف است؛ آن‌ها را جای امن نگه دارید.';

  @override
  String get secSavedThem => 'ذخیره کردم';

  @override
  String get secLoadFailed => 'بارگذاری ممکن نشد';

  @override
  String get secNoConnection => 'اتصال به سرور برقرار نشد';

  @override
  String get secLoginCodeTitle => 'تأیید ورود';

  @override
  String get secLoginCodeSubtitle => 'کد ۶ رقمی برنامه احراز هویت را وارد کنید';

  @override
  String get secLoginRecoverySubtitle =>
      'یکی از کدهای بازیابی خود را وارد کنید';

  @override
  String get secContinue => 'ادامه';

  @override
  String get secLoginHistory => 'تاریخچه ورود';

  @override
  String get secHistoryEmpty => 'هنوز ورودی ثبت نشده است';

  @override
  String get secLoginOk => 'ورود موفق';

  @override
  String get secLoginFailed => 'ورود ناموفق';

  @override
  String get secReasonBadPassword => 'رمز عبور اشتباه';

  @override
  String get secReasonBadCode => 'کد اشتباه';

  @override
  String get secReasonLocked => 'حساب موقتاً قفل بود';

  @override
  String get secReasonGuestExpired => 'دسترسی مهمان منقضی شده';

  @override
  String get secCloseOthers => 'بستن سایر نشست‌ها';

  @override
  String get secCloseOthersTitle => 'بستن سایر نشست‌ها؟';

  @override
  String get secCloseOthersBody =>
      'همه دستگاه‌ها به‌جز این دستگاه از حساب خارج می‌شوند.';

  @override
  String get secGuest => 'مهمان';

  @override
  String get secGuests => 'کاربران مهمان';

  @override
  String get secGuestsHelp =>
      'همکاران بیرونی؛ فقط وظایف، پروژه‌ها و گفتگوی مشترک را می‌بینند';

  @override
  String get secGuestsEmpty => 'مهمانی وجود ندارد';

  @override
  String get secGuestNew => 'مهمان جدید';

  @override
  String get secGuestInvite => 'کد دعوت مهمان';

  @override
  String get secGuestInviteHelp =>
      'هر کسی با این کد ثبت‌نام کند، مهمان می‌شود.';

  @override
  String get secGuestInviteCode => 'کد دعوت مهمان';

  @override
  String get secGuestInvalid => 'ایمیل معتبر و رمز حداقل ۸ نویسه لازم است';

  @override
  String get secCreate => 'ایجاد';

  @override
  String get secEmail => 'ایمیل';

  @override
  String get secFullName => 'نام کامل';

  @override
  String get secNoExpiry => 'بدون انقضا';

  @override
  String secExpiresOn(String date) {
    return 'انقضا: $date';
  }

  @override
  String get secSetExpiry => 'تعیین انقضا';

  @override
  String get secClearExpiry => 'حذف انقضا';

  @override
  String get secActive => 'فعال';

  @override
  String get secExpired => 'منقضی';

  @override
  String get secDeactivated => 'غیرفعال شده';

  @override
  String get secDeactivate => 'غیرفعال کردن';

  @override
  String get secReactivate => 'فعال کردن مجدد';

  @override
  String get secGuestNotice =>
      'شما با حساب مهمان وارد شده‌اید و فقط به بخش‌های مجاز دسترسی دارید.';

  @override
  String secGuestNoticeUntil(String date) {
    return 'شما مهمان هستید؛ دسترسی شما تا $date معتبر است.';
  }

  @override
  String get secSetupRequiredNotice =>
      'شرکت ورود دومرحله‌ای را الزامی کرده است؛ آن را از پروفایل > امنیت فعال کنید.';

  @override
  String get secAccess => 'دسترسی‌ها';

  @override
  String secAccessTitle(String name) {
    return 'دسترسی‌های $name';
  }

  @override
  String get secAccessProjects => 'پروژه‌ها';

  @override
  String get secAccessCustomers => 'پرونده‌های مشتری';

  @override
  String get secAccessChats => 'گروه‌های گفتگو';

  @override
  String get secAccessAdd => 'افزودن';

  @override
  String get secAccessEmpty => 'موردی نیست';

  @override
  String get secAccessNothingToAdd => 'موردی برای افزودن نیست';

  @override
  String get secRoleManager => 'مدیر';

  @override
  String get secRoleMember => 'عضو';

  @override
  String get secRoleViewer => 'بیننده';

  @override
  String get secRoleAdmin => 'ادمین';

  @override
  String get gnReadOnly => 'فقط مشاهده: شما اجازه ویرایش این نمودار را ندارید.';

  @override
  String get gnLoadFailed => 'بارگذاری نمودار گانت ممکن نشد';

  @override
  String get gnEmpty => 'هنوز چیزی در برنامه نیست';

  @override
  String get gnEmptyEdit =>
      'یک فاز بسازید یا وظایف برنامه‌ریزی‌نشده را به برنامه اضافه کنید.';

  @override
  String get gnZoomDaily => 'روزانه';

  @override
  String get gnZoomMonthly => 'ماهانه';

  @override
  String get gnZoomQuarterly => 'فصلی';

  @override
  String get gnAddPhase => 'فاز جدید';

  @override
  String gnUnplanned(String count) {
    return 'برنامه‌ریزی‌نشده ($count)';
  }

  @override
  String get gnNoUnplanned => 'همه وظایف در برنامه هستند';

  @override
  String get gnAddToPlan => 'افزودن به برنامه';

  @override
  String get gnPrint => 'چاپ نمودار';

  @override
  String gnPrintTitle(String name) {
    return 'نمودار گانت: $name';
  }

  @override
  String gnProgress(String percent) {
    return 'پیشرفت $percent٪';
  }

  @override
  String get gnActions => 'عملیات';

  @override
  String get gnRename => 'تغییر نام';

  @override
  String get gnSetDates => 'تعیین تاریخ';

  @override
  String get gnStart => 'شروع';

  @override
  String get gnEnd => 'پایان';

  @override
  String get gnDatesOrder => 'پایان نباید قبل از شروع باشد';

  @override
  String get gnPhase => 'فاز';

  @override
  String get gnPhaseTitle => 'عنوان فاز';

  @override
  String get gnNoPhase => 'بدون فاز';

  @override
  String get gnMoveToPhase => 'انتقال به فاز';

  @override
  String get gnMoveUp => 'بالا بردن';

  @override
  String get gnMoveDown => 'پایین بردن';

  @override
  String get gnIndent => 'زیرمجموعه (تورفتگی)';

  @override
  String get gnOutdent => 'خروج از زیرمجموعه';

  @override
  String get gnOpenTask => 'باز کردن وظیفه';

  @override
  String get gnDeactivatePhase => 'غیرفعال کردن فاز';

  @override
  String gnDeactivatePhaseBody(String title) {
    return 'فاز «$title» غیرفعال می‌شود و وظایفش به سطح بالا می‌روند.';
  }

  @override
  String get gnRemoveFromPlan => 'حذف از برنامه';

  @override
  String gnRemoveFromPlanBody(String title) {
    return '«$title» از نمودار حذف می‌شود (خود وظیفه می‌ماند).';
  }

  @override
  String get gnDependencies => 'وابستگی‌ها';

  @override
  String gnDependenciesHelp(String title) {
    return 'پیش‌نیازهای «$title» (باید تمام شوند تا این وظیفه شروع شود):';
  }

  @override
  String get gnNoDependencies => 'پیش‌نیازی ندارد';

  @override
  String get gnAddDependency => 'افزودن پیش‌نیاز';

  @override
  String get gnRemoveDependency => 'حذف وابستگی';

  @override
  String get gnConflict =>
      'تداخل: این وظیفه زودتر از پایان پیش‌نیاز شروع می‌شود';

  @override
  String gnTaskReady(String title) {
    return 'آماده شروع: $title';
  }

  @override
  String get customerPickTitle => 'انتخاب پرونده مشتری';

  @override
  String get customerPickSearch => 'جستجوی نام مشتری';

  @override
  String get customerPickEmpty => 'پرونده‌ای پیدا نشد';

  @override
  String get tasksFilterCustomer => 'پرونده مشتری';

  @override
  String tasksFilterCustomerOf(String name) {
    return 'مشتری: $name';
  }

  @override
  String get chatVoiceDenied => 'دسترسی به میکروفون داده نشده است.';

  @override
  String get chatVoiceSend => 'ارسال';

  @override
  String get chatAudioPlayFailed => 'پخش صدا ممکن نشد.';

  @override
  String get chatEdit => 'ویرایش پیام';

  @override
  String get chatEditSave => 'ذخیره';

  @override
  String get chatSearchInConversation => 'جستجو در گفتگو';

  @override
  String get chatSearchNoResults => 'پیامی پیدا نشد';

  @override
  String get chatToTaskTitle => 'عنوان وظیفه';

  @override
  String get chatToTaskCreate => 'ساخت وظیفه';

  @override
  String get videoJoin => 'ورود به جلسه آنلاین';

  @override
  String get videoTitle => 'جلسه آنلاین';

  @override
  String get videoConnecting => 'در حال اتصال…';

  @override
  String get videoNotConfigured => 'جلسه آنلاین روی این سرور فعال نیست.';

  @override
  String get videoJoinFailed => 'اتصال به جلسه ممکن نشد.';

  @override
  String get videoRetry => 'تلاش دوباره';

  @override
  String get videoMic => 'میکروفون';

  @override
  String get videoCamera => 'دوربین';

  @override
  String get videoShare => 'اشتراک صفحه';

  @override
  String get videoLeave => 'خروج';

  @override
  String videoParticipants(int count) {
    return '$count نفر در جلسه';
  }

  @override
  String get videoYou => 'شما';

  @override
  String get videoExperimental => 'آزمایشی';

  @override
  String get crmLetterLink => 'اتصال نامه';

  @override
  String get crmLetterUnlink => 'قطع اتصال نامه';

  @override
  String get crmLetterPickTitle => 'انتخاب نامه';

  @override
  String get crmLetterLinkFailed =>
      'اتصال نامه ممکن نشد. فقط سازنده نامه یا دبیرخانه می‌تواند آن را وصل کند.';

  @override
  String get crmLetterPickEmpty => 'نامه‌ای برای اتصال نیست';
}
