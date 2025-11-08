//
//  PlaylistSortPopup.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/02.
//

import UIKit
import FFPopup

class PlaylistSortPopup {

    private var popup: FFPopup?
    private static var retainedInstance: PlaylistSortPopup?

    static func show(from viewController: UIViewController, selectedIndex: Int, onSelect: @escaping (Int, String) -> Void) {
        let instance = PlaylistSortPopup()
        retainedInstance = instance // 強参照で保持

        instance.present(from: viewController, selectedIndex: selectedIndex) { index, patan in
            onSelect(index, patan)
            instance.popup?.dismiss(animated: true)
            retainedInstance = nil // 解放
        }
    }

    private func present(from viewController: UIViewController, selectedIndex: Int, onSelect: @escaping (Int, String) -> Void) {
        let weekdays = ["時間昇順", "時間降順",
                        "タイトル別 + 時間昇順", "タイトル別 + 時間降順",
                        "放送局別 + 時間昇順", "放送局別 + 時間降順"]

        let containerView = UIView()
        containerView.backgroundColor = UIColor.asset(named: AppCom.rgb_popup_bg)
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "番組の並び順を変更"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 24)
        ])

        var lastButton: UIButton? = nil

        for (index, day) in weekdays.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.translatesAutoresizingMaskIntoConstraints = false

            if index == selectedIndex {
                let attributed = NSMutableAttributedString(string: "✔︎ \(day)")
                attributed.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), range: NSRange(location: 0, length: attributed.length))
                button.setAttributedTitle(attributed, for: .normal)
                button.setTitleColor(viewController.view.tintColor, for: .normal)
            } else {
                button.setTitle(day, for: .normal)
                button.setTitleColor(.systemGreen, for: .normal)
            }

            containerView.addSubview(button)

            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                button.heightAnchor.constraint(equalToConstant: 44),
                button.topAnchor.constraint(equalTo: lastButton?.bottomAnchor ?? titleLabel.bottomAnchor, constant: 8)
            ])

            button.addAction(UIAction { _ in
                onSelect(index, day)
            }, for: .touchUpInside)

            lastButton = button
        }

        if let last = lastButton {
            last.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16).isActive = true
        }

        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: 280)
        ])

        popup = FFPopup(
            contentView: containerView,
            showType: .slideInFromRight,
            dismissType: .slideOutToLeft,
            maskType: .dimmed,
            dismissOnBackgroundTouch: true,
            dismissOnContentTouch: false
        )

        let layout = FFPopupLayout(horizontal: .center, vertical: .center)
        popup?.show(layout: layout)
    }
}

