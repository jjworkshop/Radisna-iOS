//
//  SelectFilePopup.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/09.
//

import UIKit
import FFPopup

class SelectFilePopup: NSObject, UITableViewDelegate, UITableViewDataSource {

    private var popup: FFPopup?
    private static var retainedInstance: SelectFilePopup?
    private var jsonFiles: [String] = []
    private var onSelect: ((String) -> Void)?

    static func show(from viewController: UIViewController, onSelect: @escaping (String) -> Void) {
        let instance = SelectFilePopup()
        retainedInstance = instance
        instance.onSelect = onSelect
        instance.present(from: viewController)
    }

    private func present(from viewController: UIViewController) {
        jsonFiles = fetchJSONFileNames()

        let containerView = UIView()
        containerView.backgroundColor = UIColor.asset(named: AppCom.rgb_popup_bg)
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "復元ファイルを選択"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        let tableView = UITableView()
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.backgroundColor = UIColor.asset(named: AppCom.rgb_popup_bg)
        containerView.addSubview(tableView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 24),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            containerView.widthAnchor.constraint(equalToConstant: 280),
            containerView.heightAnchor.constraint(equalToConstant: 300)
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

    private func fetchJSONFileNames() -> [String] {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.creationDateKey], options: [])
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            let sortedFiles = jsonFiles.sorted {
                let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            return sortedFiles.map { $0.lastPathComponent }

        } catch {
            Com.XLOG("Error reading contents of documents directory: \(error)")
            return []
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return jsonFiles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = jsonFiles[indexPath.row]
        cell.textLabel?.textColor = UIColor.systemGreen
        cell.backgroundColor = UIColor.asset(named: AppCom.rgb_popup_bg) // 背景色を設定
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedFile = jsonFiles[indexPath.row]
        onSelect?(selectedFile)
        popup?.dismiss(animated: true)
        SelectFilePopup.retainedInstance = nil
    }
}
