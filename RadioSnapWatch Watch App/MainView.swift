//
//  MainView.swift
//  RadioSnapWatch Watch App
//
//  Created by Mitsuhiro Shirai on 2025/06/11.
//

import SwiftUI
import Combine

struct MainView: View {
    @StateObject private var sessionManager = WatchSessionManager()
    @State private var isPlaying = false
    @State private var timerCancellable: Cancellable?
    @State private var isPlayButtonDisabled = false

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                BlinkText(
                    text: sessionManager.currentProgramTitle.isEmpty ? "番組未選択" : sessionManager.currentProgramTitle,
                    font: .headline,
                    speed: 1000, // ミリsec
                    isBlinking: sessionManager.currentProgramTitle.isEmpty
                )
                .foregroundColor(.green)

                if let error = sessionManager.errorMessage {
                    Text(displayErrorMessage(error))
                        .foregroundColor(error.hasPrefix("M:") ? .green : .red)
                        .font(.caption)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        sessionManager.sendSeekCommand(offset: -10)
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                    }
                    .disabled(areControlButtonsDisabled)

                    Button(action: {
                        isPlayButtonDisabled = true // レスポンスを受信したらフラグを落とす
                        sessionManager.sendPlayCommand()
                        sessionManager.requestCurrentAndList()
                    }) {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .foregroundColor(isPlaying ? .red : .green)
                            .font(.title2)
                    }
                    .disabled(areControlButtonsDisabled)

                    Button(action: {
                        sessionManager.sendSeekCommand(offset: 10)
                    }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                    }
                    .disabled(areControlButtonsDisabled)
                }

                NavigationLink(destination: AudioListView(sessionManager: sessionManager)) {
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.body)
                        Text("番組を選択")
                            .font(.body)
                    }
                }
                .disabled(!sessionManager.isSessionActivated || isPlayButtonDisabled)
            }
            .padding()
            .onReceive(sessionManager.$isSessionActivated) { activated in
                if activated {
                    // Sessionのアクティブを待ってリクエスト
                    sessionManager.requestCurrentAndList()
                }
            }
            .onReceive(sessionManager.$isPlaying) { isPlaying in
                self.isPlaying = isPlaying
            }
            .onAppear {
                timerCancellable = Timer.publish(every: 5.0, on: .main, in: .common)
                    .autoconnect()
                    .sink { _ in
                        // 5秒間隔で更新リクエスト
                        sessionManager.requestCurrentAndList()
                    }
            }
            .onDisappear {
                timerCancellable?.cancel()
                timerCancellable = nil
            }
            .onChange(of: sessionManager.didReceiveCurrentAndList) { newValue in
                if newValue {
                    // requestCurrentAndList のレスポンス受信時通知
                    isPlayButtonDisabled = false
                    sessionManager.didReceiveCurrentAndList = false
                }
            }
        }
    }
    
    // ボタン無効の判定
    private var areControlButtonsDisabled: Bool {
        !sessionManager.isSessionActivated ||
        isPlayButtonDisabled ||
        sessionManager.currentProgramTitle.isEmpty
    }
    
    private func displayErrorMessage(_ message: String) -> String {
        if message.hasPrefix("M:") {
            return String(message.dropFirst(2))
        }
        return message
    }
}
