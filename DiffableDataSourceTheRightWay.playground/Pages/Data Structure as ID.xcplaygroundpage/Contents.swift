import Combine
import PlaygroundSupport
import UIKit

public class DataStructureAsIDVC: UIViewController {
  private enum Section: Hashable {
    case `default`
  }

  private struct Item: Hashable {
    let id = UUID()
    var number: Int

    var image: UIImage? {
      UIImage(systemName: "\(number).circle.fill")
    }
  }

  private lazy var collectionView: UICollectionView = {
    let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
    let layout = UICollectionViewCompositionalLayout.list(using: configuration)

    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    return collectionView
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Section, Item> = {
    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, indexPath, item in
      var content = cell.defaultContentConfiguration()
      content.image = item.image

      cell.contentConfiguration = content

      var buttonConfiguration: UIButton.Configuration = .plain()
      buttonConfiguration.image = UIImage(systemName: "plus")
      let button = UIButton(configuration: buttonConfiguration, primaryAction: UIAction { [weak self] action in
        guard let self = self else { return }
        guard self.items[indexPath.item].number < 50 else { return }
        self.items[indexPath.item].number += 1
      })

      let accessoryConfiguration = UICellAccessory.CustomViewConfiguration(customView: button, placement: .trailing())
      cell.accessories = [.customView(configuration: accessoryConfiguration)]
    }

    return UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
      collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
    }
  }()

  @Published private var items = (0...7).map { Item(number: $0) }

  private var disposables: Set<AnyCancellable> = []

  public override func loadView() {
    view = collectionView
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    $items
      .sink { [weak self] items in
        guard let self = self else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.default])
        snapshot.appendItems(items, toSection: .default)

        self.dataSource.apply(snapshot)
      }
      .store(in: &disposables)
  }
}

PlaygroundPage.current.liveView = DataStructureAsIDVC()
