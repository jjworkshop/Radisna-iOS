//
//  BlinkText.swift
//  RadioSnapWatch Watch App
//
//  Created by Mitsuhiro Shirai on 2025/06/13.
//

import SwiftUI
import Combine

struct BlinkText: View {
    let text: String
    let font: Font
    let speed: Double // ミリ秒単位
    let isBlinking: Bool

    @State private var isVisible = true
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(text)
            .font(font)
            .opacity(isBlinking ? (isVisible ? 1 : 0) : 1)
            .animation(.easeInOut(duration: speed / 2000.0), value: isVisible)
            .onAppear {
                updateTimer()
            }
            .onChange(of: isBlinking) { _ in
                updateTimer()
            }
            .onChange(of: speed) { _ in
                updateTimer()
            }
            .onReceive(timer) { _ in
                if isBlinking {
                    isVisible.toggle()
                }
            }
    }

    private func updateTimer() {
        timer = Timer.publish(every: speed / 1000.0, on: .main, in: .common).autoconnect()
    }
}
