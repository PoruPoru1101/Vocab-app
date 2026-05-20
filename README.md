# 英単語学習アプリ (Vocab App)

英単語と意味を登録し、ランダム出題のクイズで学習できる Flutter Web アプリ。
エビングハウスの忘却曲線をベースにした復習機能で、忘れたタイミングで自動的に復習できます。

## 🌐 公開先

https://vocab-app-e7e88.web.app

PC のブラウザ、スマホの Safari / Chrome、どちらからでもアクセス可能。
ホーム画面に追加すれば PWA としてアプリのように使えます。

## ✨ 主な機能

- **単語登録**: 英単語と意味を品詞別 (動詞・名詞・形容詞・副詞・前置詞・接続詞) に登録
- **クイズ**: 単語→意味 / 意味→単語 / ランダムの 3 モード
- **復習モード (忘却曲線)**: 忘れた頃に自動で復習対象として出題
  - 正解で復習間隔が伸びる (1日 → 3日 → 7日 → 14日 → 30日 → 60日)
  - 不正解で間隔がリセット
- **学習カレンダー**: 単語を追加した日をカレンダー上で確認、日別の単語一覧表示
- **クイズ結果の振り返り**: 正解・不正解の単語を出題方向付きで一覧表示
- **クラウド同期**: Google アカウントでサインインすれば PC とスマホでデータ共有
- **ゲストモード**: ログインせずに匿名でも使える (端末ごとの保存)

## 🛠 使用技術

| カテゴリ | 技術 |
|---|---|
| フレームワーク | Flutter Web (Dart) |
| 認証 | Firebase Authentication (Google / 匿名) |
| データベース | Cloud Firestore (リアルタイム同期) |
| ホスティング | Firebase Hosting |
| カレンダー UI | table_calendar |

## 🚀 ローカルで起動

前提: Flutter SDK インストール済み

```bash
flutter pub get
flutter run -d chrome
```

## 🏗 ビルド & デプロイ

```bash
flutter build web --release
firebase deploy --only hosting
```

## 📂 主要なフォルダ構成

```
lib/
├── main.dart                      # エントリーポイント、認証ゲート
├── firebase_options.dart          # Firebase 設定 (Web)
├── models/
│   ├── word.dart                  # 単語モデル + 品詞 enum
│   └── quiz.dart                  # クイズモード / 結果モデル
├── services/
│   ├── auth_service.dart          # Google / 匿名サインイン
│   └── word_repository.dart       # Firestore CRUD + 復習スケジュール
├── screens/
│   ├── sign_in_screen.dart        # サインイン画面
│   ├── home_screen.dart           # ホーム画面
│   ├── word_list_screen.dart      # 単語一覧 / 追加 / 編集
│   ├── quiz_setup_screen.dart     # クイズ設定 (モード・出題数)
│   ├── quiz_screen.dart           # 出題中の画面
│   ├── quiz_result_screen.dart    # クイズ終了後の結果画面
│   └── calendar_screen.dart       # 学習カレンダー
└── widgets/
    └── meaning_display.dart       # 品詞ラベル付き意味表示ウィジェット
```
