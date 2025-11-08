//
//  CustomPresentationController.swift
//  RadioSnap
//
//  Created by Mitsuhiro Shirai on 2025/06/02.
//

import UIKit

// 縦380px サイズの ViewController 用の Presentation Controller
class CustomPresentationController: UIPresentationController {
    private var dimmingView: UIView!

    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        setupDimmingView()
    }

    private func setupDimmingView() {
        dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.5) // 半透明の黒
        dimmingView.alpha = 0.0

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dimmingViewTapped))
        dimmingView.addGestureRecognizer(tapGesture)
    }

    @objc private func dimmingViewTapped() {
        presentedViewController.dismiss(animated: true, completion: nil)
    }

    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }

        dimmingView.frame = containerView.bounds
        containerView.insertSubview(dimmingView, at: 0)

        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                self.dimmingView.alpha = 1.0
            })
        } else {
            dimmingView.alpha = 1.0
        }

        presentedView?.layer.cornerRadius = 16
        presentedView?.layer.masksToBounds = true
    }

    override func dismissalTransitionWillBegin() {
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in
                self.dimmingView.alpha = 0.0
            })
        } else {
            dimmingView.alpha = 0.0
        }
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        dimmingView.frame = containerView?.bounds ?? .zero
        presentedView?.frame = frameOfPresentedViewInContainerView
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        let height = 380.0  // containerView.bounds.height / 3
        return CGRect(x: 0,
                      y: containerView.bounds.height - height,
                      width: containerView.bounds.width,
                      height: height)
    }
}

class CustomTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        return CustomPresentationController(presentedViewController: presented, presenting: presenting)
    }
}
