class AppStrings {
  const AppStrings._();

  static const appName = 'KISOU';

  // Display / theme
  static const profileCategoryDisplay = '表示設定';
  static const profileCategorySupport = '法務・サポート';
  static const themeSetting = 'テーマ';
  static const themeSystem = 'システム';
  static const themeLight = 'ライト';
  static const themeDark = 'ダーク';

  // Bottom navigation
  static const tabHome = 'ホーム';
  static const tabAnalysis = '分析';
  static const tabProfile = 'メニュー';
  static String selectedTab(String label) => '$label、選択中';

  // Ad slot
  static const adLabel = '広告';

  // Feeling headline (7 levels)
  static const feelingLead = '体感予想';
  static const feelingVeryHot = 'とても暑く感じそうです';
  static const feelingHot = '暑く感じそうです';
  static const feelingWarm = '暖かく感じそうです';
  static const feelingPerfect = 'ちょうど良く感じそうです';
  static const feelingCool = '涼しく感じそうです';
  static const feelingCold = '寒く感じそうです';
  static const feelingVeryCold = 'とても寒く感じそうです';

  // Today weather detail
  static const todayWeatherTitle = '今日の天気';
  static const weatherFeelsLike = '体感';
  static const weatherHumidity = '湿度';
  static const weatherWind = '風速';
  static const weatherPrecipitation = '降水確率';
  static const weatherWbgt = '暑さ指数';

  // Analysis screen
  static const analysisTitle = '分析';
  static const analysisTendencyTitle = 'あなたの体感タイプ';
  static const tendencyColdSensitive = '寒がりタイプ';
  static const tendencyNeutral = 'バランスタイプ';
  static const tendencyHeatSensitive = '暑がりタイプ';
  static const tendencyColdSensitiveDesc = '同じ気温でも寒く感じやすい傾向です';
  static const tendencyNeutralDesc = '気温に対してバランスよく感じる傾向です';
  static const tendencyHeatSensitiveDesc = '同じ気温でも暑く感じやすい傾向です';
  static const analysisDistributionTitle = '体感の記録';
  static const analysisHistoryTitle = '寒いと感じた日';
  static const analysisEmpty = 'まだ記録がありません。\nフィードバックすると分析が表示されます。';
  static const feedbackCountCold = '寒かった';
  static const feedbackCountPerfect = 'ちょうど良い';
  static const feedbackCountHot = '暑かった';
  static const analysisTimelineTitle = '体感の推移';
  // Analysis v2
  static const analysisColdDaysTitle = '寒いと感じた日';
  static const analysisHotDaysTitle = '暑いと感じた日';
  static const analysisTempHigh = '最高';
  static const analysisTempLow = '最低';
  static const analysisLockedMessage = 'フィードバックが5回たまると、くわしい分析が表示されます';
  static const analysisRemainingSuffix = '回';
  static const analysisRemainingPrefix = 'あと';
  static const analysisAverageNotice = '記録が4件以下のため、平均的なデータをもとに予想しています';
  static const analysisEmptyTitle = 'まだ体感データがありません';
  static const analysisEmptyBody = '服装の記録を続けると、あなたの傾向が見えてきます';
  static const analysisDetailedTitle = '記録の詳細';
  static const analysisOpenHint = 'タップして体感分析を見る';
  static const analysisEntryDescription = '記録から自分の傾向を見る';
  static const analysisNoTemperature = '気温記録なし';
  static String analysisCount(int count) => '$count件';
  static String analysisCountAndPercent(int count, int percent) =>
      '$count件  $percent%';
  static String analysisCountSpoken(String label, int count, int percent) =>
      '$label、$count件、$percentパーセント';
  static String analysisDetailedRemaining(int count) => 'くわしい分析まであと$count回です';
  static String analysisTemperatureSummary(String high, String low) =>
      '最高 $high / 最低 $low';
  static String analysisHumiditySpoken(int humidity) => '、湿度$humidityパーセント';

  // Onboarding v2
  static const nicknameMinLength = 'ニックネームは2文字以上で入力してください';
  static const timeApproximateNote = 'おおよその時間で大丈夫です';

  // Profile v2 (category tree + account linking)
  static const profileCategoryPersonal = '個人情報設定';
  static const profileCategoryAccount = 'アカウント設定';
  static const profileCategoryComfort = '体感設定';
  static const dataReset = '体感データをリセット';
  static const dataResetTitle = '体感データをリセットしますか？';
  static const dataResetConfirm = 'フィードバック履歴と体感の補正を初期状態に戻します。アカウントは削除されません。';
  static const dataResetAction = 'リセットする';
  static const dataResetDone = '体感データをリセットしました';
  static const dataResetFailed = 'データの初期化に失敗しました。';
  static const accountLinkTitle = 'アカウント連携';
  static const linkWithApple = 'Appleと連携';
  static const linkWithGoogle = 'Googleと連携';
  static const linkedWithApple = 'Apple連携済み';
  static const linkedWithGoogle = 'Google連携済み';
  static const anonymousAccount = 'ゲストアカウント';
  static const anonymousAccountHelp = '現在、機種変更時のデータ引き継ぎには対応していません。';
  static const developerOptions = '開発者向け';
  static const linkPrompt = 'アカウントを連携すると、機種変更時もデータを引き継げます';
  static const linkFailed = 'アカウント連携に失敗しました。';
  static const skipForNow = 'あとで';

  static const loginDescription = '今日、どのくらいの厚さで着ればいい？\nKISOUが教えます';
  static const startupFailedTitle = 'KISOUを始められませんでした';
  static const startupOfflineBody = '接続を確認して、もう一度お試しください。';
  static const startupTimeoutBody = 'サーバーへの接続に時間がかかっています。';
  static const startupFailedBody = '一時的な問題が発生しました。もう一度お試しください。';
  static const appleLogin = 'Appleでログイン';
  static const googleLogin = 'Googleでログイン';
  static const developmentExistingLogin = '開発ログイン（既存）';
  static const developmentNewLogin = '開発ログイン（新規）';
  static const loginFailed = 'ログインに失敗しました。もう一度お試しください。';
  static const onboarding = 'オンボーディング';
  static const home = 'KISOU ホーム';
  static const settings = '設定';
  static const logout = 'ログアウト';
  static const retry = '再試行';
  static const dataFetchFailed = 'データの取得に失敗しました。';
  static const locationNotConfigured = '位置情報が設定されていません。設定から変更できます。';
  static const offlineError = 'インターネットに接続されていません';
  static const timeoutError = 'サーバーに接続できませんでした';
  static const sessionExpired = 'セッションが切れました。再度ログインしてください。';
  static const locationMissing = '位置情報が設定されていません';
  static const openSettings = '設定を開く';
  static const todayClothing = '今日の服装はこちら';
  static const recommendationSection = 'おすすめ';
  static const weatherComparisonSection = '天気の比較';
  static const bestRecommendation = 'おすすめ';
  static const warmerOption = '少し暖かめ';
  static const lighterOption = '少し軽め';
  static const recShowMore = '他の服装を見る';
  static const recShowLess = '閉じる';
  static const today = '今日';
  static const yesterday = '昨日';
  static const twoDaysAgo = '一昨日';
  static const noOuter = 'アウターなし';
  static const unknownClothing = '不明な服装';
  static const next = '次へ';
  static const back = '戻る';
  static const saveFailed = '設定の保存に失敗しました。もう一度お試しください。';
  static const onboardingComplete = '設定が完了しました';
  static const ok = 'OK';
  static const nicknamePrompt = 'なんとお呼びすればよいですか？';
  static const nicknameHelp = 'ホーム画面の呼びかけに使います。';
  static const nicknameHint = '2〜10文字';
  static const genderPrompt = '服装のおすすめに使う情報を教えてください';
  static const genderHelp = '回答はおすすめの調整にのみ使用し、他のユーザーには公開されません。';
  static const male = '男性';
  static const female = '女性';
  static const unspecified = '回答しない';
  static const sensitivityPrompt = '体感に合わせて教えてください';
  static const coldQuestion = '寒がりですか？';
  static const heatQuestion = '暑がりですか？';
  static const coldHigh = '寒がり';
  static const normal = '普通';
  static const coldLow = '寒くない';
  static const heatHigh = '暑がり';
  static const heatLow = '暑くない';
  static const locationPrompt = '天気を表示する地域を設定します';
  static const locationHelp = '現在地は天気の取得にのみ使用し、他のユーザーには公開されません。';
  static const allowLocation = '現在地から設定';
  static const retryLocation = 'もう一度試す';
  static const manualLocation = '地域を選んで設定';
  static const selectRegion = '地域を選択';
  static const locationDenied = '現在地を使うには位置情報の許可が必要です。';
  static const locationDeniedForever = '端末の設定で位置情報を許可してください。';
  static const locationDisabled = '位置情報サービスがオフです。';
  static const locationOutsideJapan = 'KISOUは現在、日本国内の天気に対応しています。日本の地域を選んでください。';
  static const locationUnavailable = '現在地を確認できませんでした。日本の地域を選んでください。';
  static const openDeviceSettings = '端末の設定を開く';
  static const finishOnboarding = 'この設定で始める';
  static const currentLocation = '現在地';
  static const timePrompt = '外出・帰宅時間を設定してください';
  static const departureTime = '外出時間';
  static const returnTime = '帰宅時間';
  static const setTime = '設定する';
  static const skip = 'スキップ';
  static const changeLater = 'あとで設定から変更できます';
  static const feedbackPrompt = '今日はどうでしたか？';
  static const feedbackButton = 'フィードバックする';
  static const feedbackDone = 'フィードバック済み ✓';
  static const feedbackChange = '変更する';
  static const feedbackWhenTitle = 'いつ外にいましたか？';
  static const feedbackClothingTitle = '何を着ていましたか？';
  static const feedbackFeelingTitle = 'どう感じましたか？';
  static const feedbackClothingHelp = '着ていたものを選んでください';
  static const feedbackUseRecommendation = 'おすすめと同じ服装を選ぶ';
  static const feedbackSave = '記録する';
  static const feedbackUpdateSave = '変更を保存';
  static const feedbackDateLabel = '日付';
  static const feedbackDateToday = '今日';
  static const feedbackDateYesterday = '昨日';
  static const feedbackDateSelectTitle = '日付を選択';
  static const feedbackDateSelectHelp = '過去7日間まで選択できます';
  static const feedbackRecorded = '記録あり';
  static const feedbackEditingSaved = '保存済みの記録を編集中';
  static const feedbackNotRecorded = 'この日の記録はまだありません';
  static const feedbackDiscardTitle = '入力内容を破棄して日付を変更しますか？';
  static const feedbackChangeDate = '日付を変更';
  static const feedbackRecentLoading = '最近の記録を読み込んでいます';
  static const feedbackRecentFailed = '記録を読み込めませんでした';
  static const feedbackTimeSlotsTitle = '外出時間帯';
  static const feedbackRequired = '必須';
  static const feedbackTimeSlotsHelp = '外出していた時間帯をすべて選んでください';
  static const feedbackTimeSlotsRequired = '外出時間帯を1つ以上選択してください';
  static const slotEarlyMorning = '早朝';
  static const slotMorning = '午前';
  static const slotAfternoon = '午後';
  static const slotEvening = '夕方';
  static const slotNight = '夜';
  static const slotLateNight = '深夜';
  static const feedbackTops = 'トップス';
  static const feedbackBottoms = 'ボトムス';
  static const feedbackOuter = 'アウター';
  static const feedbackCold = '寒かった';
  static const feedbackPerfect = 'ちょうどよかった';
  static const feedbackHot = '暑かった';
  static const feedbackApplied = '反映しました！';
  static const feedbackSubmitFailed = '送信に失敗しました。もう一度お試しください。';
  static const nicknameSetting = 'ニックネーム';
  static const genderSetting = '性別';
  static const sensitivitySetting = '体感の傾向';
  static const timeSetting = '外出・帰宅時間';
  static const locationSetting = '地域';
  static const privacyPolicy = 'プライバシーポリシー';
  static const aboutKisou = 'KISOUについて';
  static const aboutDescription = 'KISOUは、天気とあなたの体感記録から、その日に合う服装を提案するアプリです。';
  static const versionLabel = 'バージョン';
  static const openSourceLicenses = 'オープンソースライセンス';
  static const weatherDataSources = '気象データの出典';
  static const openMeteoAttribution = 'Open-Meteo（CC BY 4.0）';
  static const environmentMinistryWbgtAttribution = '環境省 熱中症予防情報サイト（暑さ指数）';
  static const openMeteoDataAttribution = '天気データ: Open‑Meteo';
  static const openMeteoLicense = 'CC BY 4.0';
  static const environmentMinistryWbgtDataAttribution = '暑さ指数: 環境省';
  static const weatherDataModified = '編集・加工あり';
  static const openMeteoDataAttributionSemantics = '天気データの出典、Open-Meteo。外部リンク';
  static const openMeteoLicenseSemantics =
      'ライセンス、Creative Commons Attribution 4.0。外部リンク';
  static const environmentMinistryWbgtDataAttributionSemantics =
      '暑さ指数の出典、環境省熱中症予防情報サイト。外部リンク';
  static const weatherDataModifiedSemantics = '気象データは編集・加工されています';
  static const externalLinkOpenFailed = 'リンクを開けませんでした。';
  static const accountDelete = 'アカウント削除';
  static const accountDeleteTitle = 'アカウントを削除しますか？';
  static const onboardingAccountDelete = 'アカウント削除';
  static const onboardingAccountDeleteConfirm =
      '設定途中のゲストアカウントと端末内データを削除します。元に戻せません。';
  static const editNickname = 'ニックネームを変更';
  static const save = '保存';
  static const cancel = 'キャンセル';
  static const yes = 'はい';
  static const no = 'いいえ';
  static const logoutConfirm = 'ログアウトしますか？';
  static const logoutConfirmBody = 'この端末でKISOUからログアウトします。記録は削除されません。';
  static const logoutAction = 'ログアウト';
  static const logoutFailed = 'ログアウトできませんでした。もう一度お試しください。';
  static const sensitivityResetConfirm = '感度を変更すると補正値がリセットされます。よろしいですか？';
  static const accountDeleteConfirm = 'すべての記録と設定が完全に削除され、元に戻せません。';
  static const deleteAction = '削除する';
  static const deleteFailed = '削除に失敗しました。もう一度お試しください。';
  static const accountDeleteLocalCleanupFailed =
      'アカウントは削除されましたが、端末内データを消去できませんでした。'
      'KISOUをアンインストールしてから再インストールしてください。';
  static const accountDeleteLocalCleanupTitle = '端末内データを消去できませんでした';
  static const accountDeleteLocalCleanupRetry = '端末データの消去を再試行';
  static const accountDeletionCredentials = '削除用情報';
  static const accountDeletionCredentialsDescription = 'アプリを使えないときのアカウント削除';
  static const accountDeletionCredentialsIntroTitle = '削除用コードを発行しますか？';
  static const accountDeletionCredentialsIntroBody =
      'サポートIDと削除用コードを安全な場所に保存すると、'
      'この端末を使えない場合もWebからアカウントを削除できます。';
  static const accountDeletionCredentialsOpen = '発行画面を開く';
  static const accountDeletionCredentialsLater = 'あとで';
  static const accountDeletionSupportId = 'サポートID';
  static const accountDeletionRecoveryCode = 'アカウント削除用コード';
  static const accountDeletionNotIssued = 'まだ発行されていません';
  static const accountDeletionLocalCodeMissing =
      'この端末にコードがありません。新しいコードに置き換えてください。';
  static const accountDeletionCodeHidden = 'コードは非表示です';
  static const accountDeletionShowCode = 'コードを表示';
  static const accountDeletionHideCode = 'コードを隠す';
  static const accountDeletionCopySupportId = 'サポートIDをコピー';
  static const accountDeletionCopyCode = '削除用コードをコピー';
  static const accountDeletionSupportIdCopied = 'サポートIDをコピーしました';
  static const accountDeletionCodeCopied = '削除用コードをコピーしました。60秒後にクリップボードから消去します';
  static const accountDeletionCopyFailed = 'コピーできませんでした。';
  static const accountDeletionIssue = '削除用コードを発行';
  static const accountDeletionReplace = '新しいコードに置き換える';
  static const accountDeletionReplaceTitle = '削除用コードを置き換えますか？';
  static const accountDeletionReplaceBody =
      '以前に保存した削除用コードはすぐに使えなくなります。'
      '新しいコードを改めて安全な場所に保存してください。';
  static const accountDeletionIssueTitle = '削除用コードを発行しますか？';
  static const accountDeletionIssueBody =
      'サポートIDと削除用コードの両方を知っている人は、'
      'Webからこのアカウントを完全に削除できます。';
  static const accountDeletionIssueDone = '削除用コードを発行しました。安全な場所に保存してください';
  static const accountDeletionReplaceDone = '削除用コードを置き換えました。以前のコードは使えません';
  static const accountDeletionOperationFailed =
      '削除用情報を更新できませんでした。通信状態を確認してもう一度お試しください。';
  static const accountDeletionLoadFailed = '削除用情報を読み込めませんでした。';
  static const accountDeletionLocalStoreUnavailable =
      '端末の削除用コードを読み出せません。まず再読み込みをお試しください。'
      '改善しない場合は、端末のコードだけを破棄して新しいコードに置き換えられます。';
  static const accountDeletionDiscardLocal = '端末のコードを破棄';
  static const accountDeletionDiscardLocalTitle = '端末のコードを破棄しますか？';
  static const accountDeletionDiscardLocalBody =
      '端末に残っている削除用コードを復元できなくなります。'
      'サーバーのアカウントは削除されません。続行後、新しいコードに置き換えてください。';
  static const accountDeletionDiscardLocalDone =
      '端末のコードを破棄しました。新しいコードに置き換えてください。';
  static const accountDeletionRetry = '再読み込み';
  static const accountDeletionBackupWarningTitle = '必ず別の安全な場所に保存してください';
  static const accountDeletionBackupWarningBody =
      'アプリの再インストール、端末の紛失・故障、機種変更では、'
      'この端末内のコードを失うことがあります。パスワード管理アプリなどに'
      'サポートIDと削除用コードを保存してください。メールや他人との共有は避けてください。';
  static const accountDeletionPermissionWarning =
      'このコードはログインやデータの閲覧には使えませんが、'
      'サポートIDと一緒に持つ人はアカウントを完全に削除できます。';
  static const accountDeletionBackupConfirmed = '安全な場所に保存済み';
  static const accountDeletionBackupUnconfirmed = 'バックアップ未確認';
  static const accountDeletionMarkBackupConfirmed = '安全な場所に保存しました';
  static const accountDeletionBackupConfirmedDone = '保存済みとして記録しました';
  static const accountDeletionRevealFailed =
      'この端末の削除用コードを読み出せません。新しいコードに置き換えてください。';
  static const accountDeletionRefreshHint =
      'コピーしただけでは保存済みになりません。別の安全な場所に保存してから確認してください。';
  static const currentLocationOption = '現在地を使用';
  static const manualLocationOption = '手動で選択';
  static const openLocationServices = '位置情報サービスを開く';
  static const openAppSettings = 'アプリの設定を開く';
  static const useCurrentLocationFailed = '現在地を取得できませんでした。手動で選択してください。';
  static const updateFailed = '更新に失敗しました。もう一度お試しください。';
  static const privacyPolicyOpenFailed = 'プライバシーポリシーを開けませんでした。';
  static const notSet = '未設定';
  static const timeRangeInvalid = '外出時間は帰宅時間より前に設定してください。';

  /// 스플래시에서 서버 응답이 늦어질 때 노출. 뒤에 애니메이션 점이 붙는다.
  static const splashLoading = 'データを読み込んでいます';

  // 予報 tab
  static const tabForecast = '予報';
  static const forecastTomorrowSection = '明日の予報';
  static const forecastUpcomingSection = '今後3日間';
  static const forecastLoading = '予報を読み込んでいます';
  static const forecastOffline = 'インターネット接続を確認してください';
  static const forecastTimeout = '予報の取得に時間がかかっています';
  static const forecastFailed = '予報を読み込めませんでした';
  static const forecastTomorrowLabel = '明日';
  static const forecastSameAsToday = '今日と同じくらいです';
  static const forecastNudgeTitle = '今日はどうでしたか？';
  static const forecastNudgeBody = '記録すると明日の予報が賢くなります';
  static const forecastNudgeAction = '記録する';
  static const forecastNudgeDone = '記録済み';
  static const forecastNudgeEdit = '記録を編集';
  static const feedbackUpdated = '記録を更新しました';
  static const forecastOutlookTitle = '日付で予想する';
  static const forecastOutlookEntry = '日付で予想';
  static const forecastOutlookIntro = '旅行や予定の日を選ぶと、その日の気温とおすすめの服装をKISOUが予想します。';
  static const forecastOutlookQuotaEmpty = '今日の予想回数を使い切りました';
  static const forecastOutlookAdNote = '広告を見ると1回追加できます（準備中）';

  static String forecastOutlookQuota(int remaining) => '今日はあと$remaining回予想できます';
  static const forecastOutlookDateLabel = '日付';
  static const forecastOutlookPlaceLabel = '場所';
  static const forecastOutlookSubmit = '予想する';
  static const forecastOutlookTempHigh = '最高';
  static const forecastOutlookTempLow = '最低';
  static const forecastOutlookFailed = '予想できませんでした。もう一度お試しください。';
  static const forecastOutlookLoading = '予想結果を読み込んでいます';
  static const forecastOutlookEmptyTitle = '旅行の日付と場所を選びましょう';
  static const forecastOutlookEmptyBody = 'その日の気温とおすすめの服装を予想します';
  static const forecastOutlookScreenshotNotice = '画面イメージ・説明用データ';
  static const forecastOutlookScreenshotSource =
      'この画面は説明用です。実際の予想では、以下の気象データを使用します。';
  static const tryAgain = 'もう一度試す';

  static String forecastComparedToToday(int degrees) {
    final direction = degrees > 0 ? '暖かく' : '涼しく';
    return '明日は今日より${degrees.abs()}°$directionなります';
  }

  static String forecastClimateSource(int years) => '過去$years年の気象データによる予想です';

  static String forecastClimateRange(String low, String high) =>
      '例年 $low°〜$high°';

  // 날짜 예상 결과의 근거 템플릿 (리뷰 15) — 어떤 데이터로 어떻게
  // 예상했는지를 명시해 신뢰를 얻는다.
  static const forecastExplainForecastMode = '気象機関の予報データにもとづく予想です。';

  static String forecastExplainClimatology({
    required int years,
    required int sampleDays,
    required String low,
    required String high,
  }) =>
      '過去$years年・同時期$sampleDays日分の気象データを分析。'
      '例年この時期は $low°〜$high° です。';

  /// 사용자 개인 보정을 반영한 체감 예상 문구. `feeling` 은 API 코드.
  static String forecastFeelingLine(String feeling) {
    final sentence = switch (feeling) {
      'VERY_HOT' => feelingVeryHot,
      'HOT' => feelingHot,
      'WARM' => feelingWarm,
      'COOL' => feelingCool,
      'COLD' => feelingCold,
      'VERY_COLD' => feelingVeryCold,
      _ => feelingPerfect,
    };
    return 'この日のあなたは、$sentence';
  }

  static const sensitivitySeparator = ' / ';
  static const timeRangeSeparator = ' 〜 ';

  // Interpolated copy (kept here so all user-facing Japanese lives in one place).
  static const sameAsYesterday = '昨日と同じ';

  static String comparedToYesterday(int degrees) => '昨日より$degrees°';

  static String greetingWithNickname(String nickname) =>
      '$nicknameさん、$todayClothing';

  static String feedbackClothingForDate(String date) => '$dateの服装は？';
}
