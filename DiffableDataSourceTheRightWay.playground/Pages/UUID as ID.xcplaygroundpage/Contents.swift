import Combine
import PlaygroundSupport
import UIKit

public class UUIDAsIDVC: UIViewController {
  private enum Section: Hashable {
    case `default`
  }

  private struct Item: Equatable, Identifiable {
    let id = UUID()
    var number: Int

    var image: UIImage? {
      UIImage(systemName: "\(number).circle.fill")
    }
  }

  private struct ItemsState {
    private(set) var itemIDs: [Item.ID]
    private var idItemMap: [Item.ID: Item]

    init(items: [Item]) {
      self.itemIDs = items.map(\.id)
      self.idItemMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    subscript(id: Item.ID) -> Item {
      get { idItemMap[id]! }
      set { idItemMap[id] = newValue }
    }
  }

  private lazy var collectionView: UICollectionView = {
    let configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
    let layout = UICollectionViewCompositionalLayout.list(using: configuration)

    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    return collectionView
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Section, Item.ID> = {
    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
      var content = cell.defaultContentConfiguration()
      content.image = item.image

      cell.contentConfiguration = content

      var buttonConfiguration: UIButton.Configuration = .plain()
      buttonConfiguration.image = UIImage(systemName: "plus")
      let button = UIButton(configuration: buttonConfiguration, primaryAction: UIAction { [weak self] action in
        guard let self = self else { return }
        guard self.itemsState[item.id].number <= 50 else { return }
        self.itemsState[item.id].number += 1
      })

      let accessoryConfiguration = UICellAccessory.CustomViewConfiguration(customView: button, placement: .trailing())
      cell.accessories = [.customView(configuration: accessoryConfiguration)]
    }

    return UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, itemID in
      guard let self = self else { return nil }
      return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: self.itemsState[itemID])
    }
  }()

  @Published private var itemsState = ItemsState(items: (0...10).map { Item(number: $0) })

  private var disposables: Set<AnyCancellable> = []

  public override func loadView() {
    view = collectionView
  }

  public override func viewDidLoad() {
    super.viewDidLoad()

    $itemsState
      .receive(on: DispatchQueue.global())
      .scan((nil, nil), { partialResult, data in
        (partialResult.1, data)
      })
      .map { ($0, $1!) }
      .receive(on: DispatchQueue.main)
      .sink { [weak self] previousState, currentState in
        guard let self = self else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item.ID>()
        snapshot.appendSections([.default])
        snapshot.appendItems(currentState.itemIDs, toSection: .default)

        if let previousState = previousState {
          let updatedItemIDs = currentState.itemIDs.filter {
            currentState[$0] != previousState[$0]
          }
          snapshot.reconfigureItems(updatedItemIDs)
        }

        self.dataSource.apply(snapshot)
      }
      .store(in: &disposables)
  }
}

PlaygroundPage.current.liveView = UUIDAsIDVC()
