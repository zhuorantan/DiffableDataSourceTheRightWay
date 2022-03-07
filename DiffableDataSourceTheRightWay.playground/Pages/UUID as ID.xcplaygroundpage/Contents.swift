import Combine
import PlaygroundSupport
import UIKit

public class UUIDAsIDVC: UIViewController {
  private enum Section: Hashable {
    case `default`
  }

  private typealias Item = UUID

  private struct ItemsState {
    private(set) var itemIDs: [UUID]
    private var idItemMap: [UUID: Int]

    init(max: Int) {
      let items = (0...max).map { (id: UUID(), number: $0) }

      self.itemIDs = items.map(\.id)
      self.idItemMap = Dictionary(uniqueKeysWithValues: items)
    }

    subscript(id: UUID) -> Int {
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

  private lazy var dataSource: UICollectionViewDiffableDataSource<Section, Item> = {
    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, (id: Item, number: Int)> { cell, _, item in
      var content = cell.defaultContentConfiguration()
      content.image = UIImage(systemName: "\(item.number).circle.fill")

      cell.contentConfiguration = content

      var buttonConfiguration: UIButton.Configuration = .plain()
      buttonConfiguration.image = UIImage(systemName: "plus")
      let button = UIButton(configuration: buttonConfiguration, primaryAction: UIAction { [weak self] action in
        guard let self = self else { return }
        guard self.itemsState[item.id] < 50 else { return }
        self.itemsState[item.id] += 1
      })

      let accessoryConfiguration = UICellAccessory.CustomViewConfiguration(customView: button, placement: .trailing())
      cell.accessories = [.customView(configuration: accessoryConfiguration)]
    }

    return UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, itemID in
      guard let self = self else { return nil }
      return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: (itemID, self.itemsState[itemID]))
    }
  }()

  @Published private var itemsState = ItemsState(max: 7)

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
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
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
