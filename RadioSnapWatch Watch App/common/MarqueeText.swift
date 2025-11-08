//
//  MarqueeText.swift
//  RadioSnapWatch Watch App
//
//  Created by Mitsuhiro Shirai on 2025/06/12.
//

import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let speed: Double

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let containerW = geo.size.width

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let offset = CGFloat(time * speed).truncatingRemainder(dividingBy: textWidth + containerW)

                HStack {
                    Text(text)
                        .font(font)
                        .background(
                            GeometryReader { textGeo in
                                Color.clear
                                    .onAppear {
                                        textWidth = textGeo.size.width
                                        containerWidth = containerW
                                    }
                            }
                        )
                        .offset(x: containerW - offset)
                    Spacer()
                }
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.05),
                            .init(color: .black, location: 0.95),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .clipped()
        .frame(height: UIFont.preferredFont(forTextStyle: .headline).lineHeight)
    }
}
