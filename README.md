# 「らじすな」 for iOS with Watch 

「らじすな（Radio Snap）」は、インターネットラジオの番組データをダウンロードして再生するアプリです。  
取得できるのは、過去1週間分の、現在位置で聴取可能なradikoの配信データです。  
未来の番組データは予約データとして登録できます。

### ■ 最終動作確認環境

XCODE: Version 26.0.1  
CocoaPods: 1.16.2

### ■ 前準備

このアプリは、サーバのAPIと連携して稼働します。  
アプリを動かすには、自前のサーバに必要なAPIやデータを配置する必要があります。  
サーバに必要なAPIは、[こちらから取得](https://github.com/jjworkshop/RadikoAPI/tree/master)して下さい。

### ■ ライブラリの展開

リポジトリからローカルにcloneしたら、以下のコマンドでライブラリを展開し、プロジェクトファイル（RadioSnap.xcworkspace）を作成します。

> pod install

### ■ ライブラリのコード修正

いくつかライブラリを修正する必要があります。（初期の状態ではエラーとなるため）

**RxCollectionViewReactiveArrayDataSource.swift**  
の「class RxCollectionViewReactiveArrayDataSourceSequenceWrapper」  
にある「override init」のブロックをコメントにする

**RxTableViewReactiveArrayDataSource.swift**  
の「class RxTableViewReactiveArrayDataSourceSequenceWrapper」  
にある「override init」のブロックをコメントにする

**WKNavigationDelegateEvents+Rx.swift**  
の「fileprivate extension Selector」にある「decidePolicyNavigationResponse」と「decidePolicyNavigationAction」がエラーとなるので以下に変更  
↓
```
    static let decidePolicyNavigationResponse: Selector =
    #selector(WKNavigationDelegate.webView(_:decidePolicyFor:decisionHandler:) as (WKNavigationDelegate) -> ((WKWebView, WKNavigationResponse, @escaping (WKNavigationResponsePolicy) -> Void) -> Void)?)
```

```
    static let decidePolicyNavigationAction: Selector =
    #selector(WKNavigationDelegate.webView(_:decidePolicyFor:decisionHandler:) as (WKNavigationDelegate) -> ((WKWebView, WKNavigationAction, @escaping(WKNavigationActionPolicy) -> Void) -> Void)?)
```

**MKMapView+Rx.swift**  
「public var didAddAnnotationViews」がエラーとなるので以下に変更  
↓
```
	methodInvokedWithParam1(#selector(
		(MKMapViewDelegate.mapView(_:didAdd:))
		as (MKMapViewDelegate) -> ((MKMapView, [MKAnnotationView]) -> Void)?)))
```

「public var didAddRenderers」がエラーとなるので以下に変更  
↓
```
	methodInvokedWithParam1(#selector(
		MKMapViewDelegate.mapView(_:didAdd:)!
		as (MKMapViewDelegate) -> (MKMapView, [MKOverlayRenderer]) -> Void))
```

### ■ ソースコードの修正

前準備にて設定したAPIのパスをソースコードで指定します。  

**AppCommon.swift**  
以下の２行をAPIのあるサーバーに合わせて値を変更して下さい。

<pre>
static public let domain = "https://hogehoge.com"  
static public let API_PATH = "\(domain)/API/"
</pre>






