//
//  DataModel.swift
//  SurfTideX
//
//  Created by Mitsuhiro Shirai on 2025/05/12.
//

/*
    CoreDataのクラス自動生成方法
    各Entityのプロパティで「CodeGen: Manual/None」を選択する
    メニューより Editor > Create NSManagedObject Subclass...を選択
    自動生成コードは、パスの選択もGroup指定も「EntitiesAutoGen」へ出力（こちらは処理の都度変更されるので直接ソースは変更しない）
    ↑
    ◆◆ これを間違えると予定外のパスに自動生成コードが出力されるので要注意
    個別のDB処理は「EntitiesExtension」にコードを書く
 
    
    参照（コードの手動生成方法）: https://capibara1969.com/3195/#toc4
*/


import Foundation

/// 現在地情報（DBには保存しない）
class Region {
    /// 都道府県コード（'1','2' ... '47'）
    var pcd: String
    /// 名称
    var name: String
    /// 座標
    var latLon: LatLon

    init(pcd: String, name: String, latLon: LatLon) {
        self.pcd = pcd
        self.name = name
        self.latLon = latLon
    }
}

/// 放送局アイテム（DBには保存しない）
class StationItem {
    /// 放送局ID
    var id: String
    /// 名称
    var name: String
    /// ロゴイメージURL（png）
    var logoImgUrl: String
    /// ホームページ
    var url: String

    init(id: String, name: String, logoImgUrl: String, url: String) {
        self.id = id
        self.name = name
        self.logoImgUrl = logoImgUrl
        self.url = url
    }
}

/// タイムテーブルアイテム（キャッシュ扱いで、stationId毎に本日の取得データ１件のみ）
class TimeTableItem {
    /// 放送局ID 例：TBS       PrimaryKey
    var stationId: String
    /// 本日日付（YYYYMMDD） 例: 20240220
    var todayStr: String
    /// getTimeTable.py のリザルト（result=0 の場合のみ）
    var jsonStr: String

    init(stationId: String, todayStr: String, jsonStr: String) {
        self.stationId = stationId
        self.todayStr = todayStr
        self.jsonStr = jsonStr
    }
}

/// ダウンロード予約アイテム
class BookingItem: Codable {
    /// プライマリーキー
    var uuid: String
    /// データシーケンス
    var seqNo: Int
    /// 放送局ID 例：TBS
    var stationId: String
    /// 番組開始日時（YYYYMMDDHHMMSS）
    var startDt: String
    /// 番組終了日時
    var endDt: String
    /// 番組タイトル
    var title: String
    /// 放送日　　例: 2月10日（月）
    var bcDate: String
    /// 放送時間　例: 5時0分 〜 6時30分
    var bcTime: String
    /// 番組URL　例: https://www.tbsradio.jp/ohayou/
    var url: String
    /// パーソナリティ　例: 片桐千晶
    var pfm: String
    /// 番組バナー　例: https://program-static.cf.radiko.jp/xwef05ul1o.jpg
    var imgUrl: String
    /// 状態（0=未指定、1=ダウンロード済、2=ダウンロードキャンセル
    ///       7=ダウンロード予約、8=ダウンロード中、9=ダウンロードエラー、テンポラリとして -1 は削除依頼[DBには残らない]）
    var status: Int

    init(uuid: String, seqNo: Int, stationId: String, startDt: String, endDt: String,
         title: String, bcDate: String, bcTime: String, url: String,
         pfm: String, imgUrl: String, status: Int) {
        self.uuid = uuid
        self.seqNo = seqNo
        self.stationId = stationId
        self.startDt = startDt
        self.endDt = endDt
        self.title = title
        self.bcDate = bcDate
        self.bcTime = bcTime
        self.url = url
        self.pfm = pfm
        self.imgUrl = imgUrl
        self.status = status
    }

    func copy() -> BookingItem {
        return BookingItem(uuid: uuid, seqNo: seqNo, stationId: stationId, startDt: startDt, endDt: endDt,
                           title: title, bcDate: bcDate, bcTime: bcTime, url: url,
                           pfm: pfm, imgUrl: imgUrl, status: status)
    }
}
extension BookingItem {
    static func from(booking: Booking) -> BookingItem? {
        return BookingItem(
            uuid: booking.uuid ?? "",
            seqNo: Int(booking.seqNo),
            stationId: booking.stationId ?? "",
            startDt: booking.startDt ?? "",
            endDt: booking.endDt ?? "",
            title: booking.title ?? "",
            bcDate: booking.bcDate ?? "",
            bcTime: booking.bcTime ?? "",
            url: booking.url ?? "",
            pfm: booking.pfm ?? "",
            imgUrl: booking.imgUrl ?? "",
            status: Int(booking.status)
        )
    }
}

/// ダウンロードファイルアイテム
class DownloadItem {
    /// uuid: プライマリーキー
    var uuid: String
    /// stationId: 放送局ID 例：TBS
    var stationId: String
    /// stationName: 放送局名 例：TBSラジオ
    var stationName: String
    /// startDt: 番組開始日時（YYYYMMDDHHMMSS）
    var startDt: String
    /// title: 番組タイトル
    var title: String
    /// bcDate: 放送日　　例: 2月10日（月）
    var bcDate: String
    /// bcTime: 放送時間　例: 5時0分 〜 6時30分
    var bcTime: String
    /// pfm: パーソナリティ　例: 片桐千晶
    var pfm: String
    /// imgUrl: 番組バナー　例: https://program-static.cf.radiko.jp/xwef05ul1o.jpg
    var imgUrl: String
    /// playbackSec: 再生秒
    var playbackSec: Int
    /// duration: 番組の長さ（秒）
    var duration: Int
    /// played: 再生済
    var played: Bool
    /// copied: メディアストアにコピー済
    var copied: Bool

    init(uuid: String, stationId: String, stationName: String, startDt: String,
         title: String, bcDate: String, bcTime: String, pfm: String, imgUrl: String,
         playbackSec: Int = 0, duration: Int = 0, played: Bool = false, copied: Bool = false) {
        self.uuid = uuid
        self.stationId = stationId
        self.stationName = stationName
        self.startDt = startDt
        self.title = title
        self.bcDate = bcDate
        self.bcTime = bcTime
        self.pfm = pfm
        self.imgUrl = imgUrl
        self.playbackSec = playbackSec
        self.duration = duration
        self.played = played
        self.copied = copied
    }
}

extension DownloadItem {
    static func from(download: Download) -> DownloadItem {
        return DownloadItem(
            uuid: download.uuid ?? "",
            stationId: download.stationId ?? "",
            stationName: download.stationName ?? "",
            startDt: download.startDt ?? "",
            title: download.title ?? "",
            bcDate: download.bcDate ?? "",
            bcTime: download.bcTime ?? "",
            pfm: download.pfm ?? "",
            imgUrl: download.imgUrl ?? "",
            playbackSec: Int(download.playbackSec),
            duration: Int(download.duration),
            played: download.played,
            copied: download.copied
        )
    }
}
