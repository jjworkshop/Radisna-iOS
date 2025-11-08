//
//  SimplePopup.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/05/16.
//

import UIKit
import FFPopup

// UIAlertController を使わない、シンプルなAlert表示
// 利用ライブラリ：FFPopup

/* 使用方法の例（キャンセルは省略可能）
 
 SimplePopup.showAlert(
     on: self.view,
     title: "確認",
     message: "この操作を実行しますか？",
     showCheckbox: true,
     checkboxLabel: "今後表示しない",
     confirmTitle: "実行",
     cancelTitle: "キャンセル",
     onConfirm: { isChecked in
         print("チェック状態: \(isChecked)")
     },
     onCancel: {
         print("キャンセルされました")
     }
 )
 
*/

class SimplePopup {

    static func showAlert(
        on view: UIView,
        title: String,
        message: String,
        showCheckbox: Bool = false,
        checkboxLabel: String = "同意する",
        confirmTitle: String = "OK",
        cancelTitle: String? = nil,
        onConfirm: ((_ isChecked: Bool) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        var popup: FFPopup?

        let contentView = createContentView(
            title: title,
            message: message,
            showCheckbox: showCheckbox,
            checkboxLabel: checkboxLabel,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            onConfirm: { isChecked in
                onConfirm?(isChecked)
                popup?.dismiss(animated: true)
            },
            onCancel: {
                onCancel?()
                popup?.dismiss(animated: true)
            }
        )

        popup = FFPopup(
            contentView: contentView,
            showType: .slideInFromRight,      // 右から表示
            dismissType: .slideOutToLeft,     // 左に消える
            maskType: .dimmed,
            dismissOnBackgroundTouch: true,
            dismissOnContentTouch: false
        )

        popup?.show(layout: FFPopupLayout(horizontal: .center, vertical: .center))
    }

    private static func createContentView(
        title: String,
        message: String,
        showCheckbox: Bool,
        checkboxLabel: String,
        confirmTitle: String,
        cancelTitle: String?,
        onConfirm: @escaping (_ isChecked: Bool) -> Void,
        onCancel: @escaping () -> Void
    ) -> UIView {
        let width: CGFloat = 280
        let padding: CGFloat = 16

        let container = UIView()
        container.backgroundColor = .systemBackground // ダークモード対応
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label // ダークモード対応

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left
        messageLabel.textColor = .label // ダークモード対応

        var isChecked = false
        var checkboxStack: UIStackView?

        if showCheckbox {
            let checkboxButton = UIButton(type: .system)
            checkboxButton.setTitle("□", for: .normal)
            checkboxButton.titleLabel?.font = .systemFont(ofSize: 26) // 大きめフォント
            checkboxButton.contentVerticalAlignment = .center
            checkboxButton.translatesAutoresizingMaskIntoConstraints = false
            checkboxButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
            checkboxButton.heightAnchor.constraint(equalToConstant: 28).isActive = true

            let checkboxTextLabel = UILabel()
            checkboxTextLabel.text = checkboxLabel
            checkboxTextLabel.font = .systemFont(ofSize: 15)
            checkboxTextLabel.textColor = .label
            checkboxTextLabel.translatesAutoresizingMaskIntoConstraints = false
            checkboxTextLabel.heightAnchor.constraint(equalToConstant: 28).isActive = true // ★ 高さを揃える

            checkboxButton.addAction(UIAction { _ in
                isChecked.toggle()
                let symbol = isChecked ? "☑︎" : "□"
                checkboxButton.setTitle(symbol, for: .normal)
            }, for: .touchUpInside)

            checkboxStack = UIStackView(arrangedSubviews: [checkboxButton, checkboxTextLabel])
            checkboxStack?.axis = .horizontal
            checkboxStack?.spacing = 2
            checkboxStack?.alignment = .center // ★ 中央揃え

        }


        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle(confirmTitle, for: .normal)
        confirmButton.addAction(UIAction { _ in
            onConfirm(isChecked)
        }, for: .touchUpInside)

        var views: [UIView] = [titleLabel, messageLabel]
        if let checkboxStack = checkboxStack {
            views.append(checkboxStack)
        }
        views.append(confirmButton)

        if let cancelTitle = cancelTitle {
            let cancelButton = UIButton(type: .system)
            cancelButton.setTitle(cancelTitle, for: .normal)
            cancelButton.addAction(UIAction { _ in
                onCancel()
            }, for: .touchUpInside)
            views.append(cancelButton)
        }

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            container.widthAnchor.constraint(equalToConstant: width),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])

        return container
    }
}


