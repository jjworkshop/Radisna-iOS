//
//  ScrollFriendlyButton.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/26.
//

import UIKit
import AlamofireImage

class ScrollFriendlyButton: UIButton {
    let stationId: String
    let imageUrl: String
    private let logoImageView = UIImageView()
    var onTap: ((String) -> Void)?
    private var isDragging = false

    init(stationId: String, imageUrl: String) {
        self.stationId = stationId
        self.imageUrl = imageUrl
        super.init(frame: .zero)
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.contentMode = .scaleAspectFit
        addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: self.topAnchor, constant: 4),
            logoImageView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -4),
            logoImageView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 4),
            logoImageView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -4)
        ])
        if let url = URL(string: imageUrl) {
            logoImageView.af.setImage(withURL: url)
        }
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    @objc private func buttonTapped() {
        onTap?(stationId)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        isDragging = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        isDragging = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if !isDragging {
            // 以下不要（実機で確認済み 2025/6/5）
            // buttonTapped()
        }
    }
}
