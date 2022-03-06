import PlaygroundSupport
import UIKit

let introVC = IntroVC()
let navigationController = UINavigationController(rootViewController: introVC)
navigationController.view.frame = CGRect(origin: .zero, size: CGSize(width: 375, height: 812))

PlaygroundPage.current.liveView = navigationController
