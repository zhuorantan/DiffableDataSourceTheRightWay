import Combine
import PlaygroundSupport
import UIKit

public class HierachicalVC: UIViewController {
  private enum Section: String, Hashable, CaseIterable {
    case circle
    case square

    var title: String {
      switch self {
      case .circle: return "Circle"
      case .square: return "Square"
      }
    }
  }

  private enum Item: Hashable {
    case header(Section)
    case row(id: UUID, section: Section)
  }

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
    var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
    configuration.headerMode = .firstItemInSection
    let layout = UICollectionViewCompositionalLayout.list(using: configuration)

    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    return collectionView
  }()

  private lazy var dataSource: UICollectionViewDiffableDataSource<Section, Item> = {
    let headerRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, _, title in
      var content = UIListContentConfiguration.prominentInsetGroupedHeader()
      content.text = title

      cell.contentConfiguration = content

      let headerDisclosureOption = UICellAccessory.OutlineDisclosureOptions(style: .header)
      cell.accessories = [.outlineDisclosure(options: headerDisclosureOption)]
    }

    let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, (id: UUID, number: Int, section: Section)> { cell, _, item in
      var content = cell.defaultContentConfiguration()
      content.image = UIImage(systemName: "\(item.number).\(item.section.rawValue).fill")

      cell.contentConfiguration = content

      let stepper = UIStepper(frame: .zero, primaryAction: UIAction { [weak self] action in
        guard let self = self else { return }
        let stepper = action.sender as! UIStepper
        self.itemsState[item.id] = Int(stepper.value)
      })
      stepper.value = Double(item.number)
      stepper.minimumValue = 0
      stepper.maximumValue = 50

      let stepperConfiguration = UICellAccessory.CustomViewConfiguration(customView: stepper, placement: .trailing())
      cell.accessories = [.customView(configuration: stepperConfiguration)]
    }

    return UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, itemID in
      guard let self = self else { return nil }

      switch itemID {
      case .header(let section):
        return collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: section.title)

      case .row(let id, let section):
        return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: (id, self.itemsState[id], section))
      }
    }
  }()

  @Published private var itemsState = ItemsState(max: 10)

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

        if previousState == nil {
          var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
          snapshot.appendSections(Section.allCases)
          self.dataSource.applySnapshotUsingReloadData(snapshot)
        }

        for section in Section.allCases {
          let items: [Item] = currentState.itemIDs.map { .row(id: $0, section: section) }

          var sectionSnapshot = self.dataSource.snapshot(for: section)
          if sectionSnapshot.contains(.header(section)) {
            var childSectionSnapshot = sectionSnapshot.snapshot(of: .header(section))
            childSectionSnapshot.applyRootItemsDiff(to: items)

            sectionSnapshot.replace(childrenOf: .header(section), using: childSectionSnapshot)
          } else {
            sectionSnapshot.append([.header(section)])
            sectionSnapshot.append(items, to: .header(section))
            sectionSnapshot.expand([.header(section)])
          }

          self.dataSource.apply(sectionSnapshot, to: section)
        }

        if let previousState = previousState {
          var snapshot = self.dataSource.snapshot()

          let updatedItemIDs: [Item] = snapshot.itemIdentifiers
            .compactMap { itemID -> (id: UUID, section: Section)? in
              switch itemID {
              case .header: return nil
              case .row(let id, let section): return (id, section)
              }
            }
            .filter {
              currentState[$0.id] != previousState[$0.id]
            }
            .map {
              .row(id: $0.id, section: $0.section)
            }
          snapshot.reconfigureItems(updatedItemIDs)

          self.dataSource.apply(snapshot)
        }
      }
      .store(in: &disposables)
  }
}

extension NSDiffableDataSourceSectionSnapshot {
  mutating func applyRootItemsDiff(to itemIdentifiers: [ItemIdentifierType]) {
    let difference = itemIdentifiers.difference(from: rootItems)

    let removedItems: [ItemIdentifierType] = difference.removals.compactMap {
      guard case .remove(_, let item, _) = $0 else {
        return nil
      }
      return item
    }
    delete(removedItems)

    for change in difference.insertions {
      guard case .insert(let offset, let item, _) = change else { continue }

      guard !rootItems.isEmpty else {
        append([item])
        continue
      }
      guard offset > 0 else {
        insert([item], before: rootItems[0])
        continue
      }

      insert([item], after: rootItems[offset - 1])
    }
  }
}

PlaygroundPage.current.liveView = HierachicalVC()
