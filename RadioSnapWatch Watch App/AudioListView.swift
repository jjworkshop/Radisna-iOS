//
//  AudioListView.swift
//  RadioSnapWatch Watch App
//
//  Created by Mitsuhiro Shirai on 2025/06/11.
//

import SwiftUI

struct AudioListView: View {
    @ObservedObject var sessionManager: WatchSessionManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        List {
            ForEach(Array(sessionManager.programList.enumerated()), id: \.element.uuid) { index, program in
                Button(action: {
                    sessionManager.currentIndex = index
                    sessionManager.sendPlayCommand(uuid: program.uuid)
                    sessionManager.requestCurrentAndList()  // 状態をもらうため
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(program.title)
                        .foregroundColor(
                            program.uuid == getCurrentUuid()
                            ? .green
                            : (program.played ? .gray : .primary)
                        )
                }
            }
        }
        .navigationTitle("番組一覧")
    }
    
    // 現在選択中のUUID
    private func getCurrentUuid() -> String? {
        if let index = sessionManager.currentIndex {
            if index >= 0 && index < sessionManager.programList.count {
                return sessionManager.programList[index].uuid
            }
        }
        return nil
    }
}
