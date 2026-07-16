class AppStrings {
  const AppStrings._();

  static const appName = 'KISOU';

  // Display / theme
  static const profileCategoryDisplay = '表示設定';
  static const themeSetting = 'テーマ';
  static const themeSystem = 'システム';
  static const themeLight = 'ライト';
  static const themeDark = 'ダーク';

  // Bottom navigation
  static const tabHome = 'ホーム';
  static const tabAnalysis = '分析';
  static const tabProfile = 'メニュー';

  // Ad slot
  static const adLabel = '広告';

  // Feeling headline (7 levels)
  static const feelingLead = '今日のあなたは';
  static const feelingVeryHot = 'とても暑く感じるでしょう';
  static const feelingHot = '暑く感じるでしょう';
  static const feelingWarm = '暖かく感じるでしょう';
  static const feelingPerfect = 'ちょうど良く感じるでしょう';
  static const feelingCool = '涼しく感じるでしょう';
  static const feelingCold = '寒く感じるでしょう';
  static const feelingVeryCold = 'とても寒く感じるでしょう';

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

  // Onboarding v2
  static const nicknameMinLength = 'ニックネームは2文字以上で入力してください';
  static const timeApproximateNote = 'おおよその時間で大丈夫です';

  // Profile v2 (category tree + account linking)
  static const profileCategoryPersonal = '個人情報設定';
  static const profileCategoryAccount = 'アカウント設定';
  static const profileCategoryComfort = '体感設定';
  static const dataReset = 'データを初期化';
  static const dataResetConfirm = '体感データを初期化しますか？補正値とフィードバック記録がリセットされます。';
  static const dataResetDone = 'データを初期化しました';
  static const dataResetFailed = 'データの初期化に失敗しました。';
  static const accountLinkTitle = 'アカウント連携';
  static const linkWithApple = 'Appleと連携';
  static const linkWithGoogle = 'Googleと連携';
  static const linkedWithApple = 'Apple連携済み';
  static const linkedWithGoogle = 'Google連携済み';
  static const anonymousAccount = 'ゲスト（未連携）';
  static const linkPrompt = 'アカウントを連携すると、機種変更時もデータを引き継げます';
  static const linkFailed = 'アカウント連携に失敗しました。';
  static const skipForNow = 'あとで';

  static const loginDescription = '今日、どのくらいの厚さで着ればいい？\nKISOUが教えます';
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
  static const todayClothing = '今日の服装は';
  static const recommendationSection = 'おすすめ';
  static const weatherComparisonSection = '天気の比較';
  static const bestRecommendation = 'おすすめ';
  static const warmerOption = '少し暖かめ';
  static const lighterOption = '少し軽め';
  static const recShowMore = 'もっと見る';
  static const recShowLess = '閉じる';
  static const today = '今日';
  static const yesterday = '昨日';
  static const twoDaysAgo = '一昨日';
  static const noOuter = 'なし';
  static const next = '次へ';
  static const back = '戻る';
  static const saveFailed = '設定の保存に失敗しました。もう一度お試しください。';
  static const onboardingComplete = '設定完了！今日のおすすめを確認しましょう';
  static const ok = 'OK';
  static const nicknamePrompt = 'KISOUで使う名前を教えてください';
  static const nicknameHint = '10文字以内';
  static const genderPrompt = '性別を選んでください';
  static const male = '男性';
  static const female = '女性';
  static const unspecified = '選択しない';
  static const sensitivityPrompt = '体感に合わせて教えてください';
  static const coldQuestion = '寒がりですか？';
  static const heatQuestion = '暑がりですか？';
  static const coldHigh = '寒がり';
  static const normal = '普通';
  static const coldLow = '寒くない';
  static const heatHigh = '暑がり';
  static const heatLow = '暑くない';
  static const locationPrompt = '正確な天気情報のために位置情報を使用します';
  static const allowLocation = '位置情報を許可する';
  static const manualLocation = '手動で地域を選ぶ';
  static const selectRegion = '地域を選んでください';
  static const locationDenied = '位置情報を取得できませんでした。地域を選んでください。';
  static const locationDisabled = '位置情報サービスがオフです。地域を選んでください。';
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
  static const feedbackClothingTitle = '今日の服装は？';
  static const feedbackFeelingTitle = '今日の体感は？';
  static const feedbackTops = 'トップス';
  static const feedbackBottoms = 'ボトムス';
  static const feedbackOuter = 'アウター';
  static const feedbackCold = '寒かった';
  static const feedbackPerfect = 'ちょうどよかった';
  static const feedbackHot = '暑かった';
  static const feedbackApplied = '反映しました！';
  static const feedbackSubmitFailed = '送信に失敗しました。もう一度お試しください。';
  static const nicknameSetting = 'ニックネーム変更';
  static const genderSetting = '性別変更';
  static const sensitivitySetting = '寒がり・暑がり設定';
  static const timeSetting = '外出・帰宅時間';
  static const locationSetting = '位置情報変更';
  static const privacyPolicy = 'プライバシーポリシー';
  static const accountDelete = 'アカウント削除';
  static const editNickname = 'ニックネームを変更';
  static const save = '保存';
  static const cancel = 'キャンセル';
  static const yes = 'はい';
  static const no = 'いいえ';
  static const logoutConfirm = 'ログアウトしますか？';
  static const sensitivityResetConfirm = '感度を変更すると補正値がリセットされます。よろしいですか？';
  static const accountDeleteConfirm = 'アカウントを削除すると、すべてのデータが失われます。この操作は取り消せません。';
  static const deleteAction = '削除する';
  static const deleteFailed = '削除に失敗しました。もう一度お試しください。';
  static const currentLocationOption = '現在地を使用';
  static const manualLocationOption = '手動で選択';
  static const useCurrentLocationFailed = '現在地を取得できませんでした。手動で選択してください。';
  static const updateFailed = '更新に失敗しました。もう一度お試しください。';
  static const privacyPolicyOpenFailed = 'プライバシーポリシーを開けませんでした。';
  static const notSet = '未設定';
  static const timeRangeInvalid = '外出時間は帰宅時間より前に設定してください。';

  /// 스플래시에서 서버 응답이 늦어질 때 노출. 뒤에 애니메이션 점이 붙는다.
  static const splashLoading = '今日のおすすめを考えています';

  // 予報 tab
  static const tabForecast = '予報';
  static const forecastTitle = '服装予報';
  static const forecastTomorrowLabel = '明日';
  static const forecastSameAsToday = '今日と同じくらいです';
  static const forecastNudgeTitle = '今日はどうでしたか？';
  static const forecastNudgeBody = '記録すると明日の予報が賢くなります';
  static const forecastNudgeAction = '記録する';
  static const forecastNudgeDone = '記録済み ✓';
  static const forecastOutlookTitle = '日付で予想する';
  static const forecastOutlookDateLabel = '日付';
  static const forecastOutlookPlaceLabel = '場所';
  static const forecastOutlookSubmit = '予想する';
  static const forecastOutlookTempHigh = '最高';
  static const forecastOutlookTempLow = '最低';
  static const forecastOutlookFailed = '予想できませんでした。もう一度お試しください。';

  static String forecastComparedToToday(int degrees) {
    final direction = degrees > 0 ? '暖かく' : '涼しく';
    return '明日は今日より${degrees.abs()}°$directionなります';
  }

  static String forecastClimateSource(int years) => '過去$years年の気象データによる予想です';

  static String forecastClimateRange(String low, String high) =>
      '例年 $low°〜$high°';
  static const sensitivitySeparator = ' / ';
  static const timeRangeSeparator = ' 〜 ';

  // Interpolated copy (kept here so all user-facing Japanese lives in one place).
  static const sameAsYesterday = '昨日と同じ';

  static String comparedToYesterday(int degrees) => '昨日より$degrees°';

  static String feelingLeadNamed(String name) => '今日の$nameさんは';

  static String greetingWithNickname(String nickname) =>
      '$nicknameさん、$todayClothing';
}
