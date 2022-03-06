import UIKit

public class IntroVC: UIViewController {
  private enum Section: Hashable {
    case `default`
  }

  private enum Item: Hashable, CaseIterable {
    case dataStructureAsID
    case uuidAsID

    var title: String {
      switch self {
      case .dataStructureAsID: return "Use the entire data structure as ID"
      case .uuidAsID: return "Use UUID as ID"
      }
    }
  }

  private lazy var collectionView: UICollectionView = {
    let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
    let layout = UICollectionViewCompositionalLayout.list(using: configuration)

    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.delegate = self
    return collectionView
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Section, Item> = {
    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
      var content = cell.defaultContentConfiguration()
      content.text = item.title

      cell.contentConfiguration = content
      cell.accessories = [.disclosureIndicator()]
    }

    return UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
      collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
    }
  }()

  public override func loadView() {
    view = collectionView
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
    snapshot.appendSections([.default])
    snapshot.appendItems(Item.allCases, toSection: .default)

    dataSource.apply(snapshot)
  }

  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first {
      collectionView.deselectItem(at: selectedIndexPath, animated: true)
    }
  }
}

extension IntroVC: UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let item = Item.allCases[indexPath.item]
    switch item {
    case .dataStructureAsID:
      navigationController!.pushViewController(DataStructureAsIDVC(), animated: true)

    case .uuidAsID:
      navigationController!.pushViewController(UUIDAsIDVC(), animated: true)
    }
  }
}
