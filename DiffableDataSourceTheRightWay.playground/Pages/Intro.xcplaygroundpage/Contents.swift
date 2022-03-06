import Combine
import UIKit

// Use an entire data structure as diffable data source item ID

struct Item: Hashable {
  let id: UUID
  var number: Int
}

// Observe a combine data store

class ViewController: UIViewController {
  @Published var items = (0...8).map { Item(id: UUID(), number: $0) }

  var dataSource: UICollectionViewDiffableDataSource<Int, Item>!
  var disposables: Set<AnyCancellable> = []

  override func viewDidLoad() {
    super.viewDidLoad()

    $items
      .sink { [weak self] items in
        guard let self = self else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        snapshot.appendItems(items, toSection: 0)

        self.dataSource.apply(snapshot)
      }
      .store(in: &disposables)
  }
}

// Implement a proper item ID

typealias ItemID = UUID

struct ItemsState {
  var itemIDs: [ItemID]
  private var idItemMap: [ItemID: Int]

  init(numbers: [Int]) {
    let items = numbers.map { (id: UUID(), number: $0) }
    self.itemIDs = items.map(\.id)
    self.idItemMap = Dictionary(uniqueKeysWithValues: items)
  }

  subscript(id: ItemID) -> Int {
    get { idItemMap[id]! }
    set { idItemMap[id] = newValue }
  }
}

// Get previous state in the data flow

// Collection reduce()
[0, 1, 2, 3, 4, 5, 6, 7, 8].reduce(0, +)
[0, 1, 2, 3, 4, 5, 6, 7, 8].reduce(0) { partialResult, current in
  partialResult + current
}

// Combine version of reduce(): scan()
[0, 1, 2, 3, 4, 5, 6, 7, 8].publisher
  .scan(0) { partialResult, current in
    partialResult + current
  }
  .sink { print($0) }

// User scan() to produce previous state
[0, 1, 2, 3, 4, 5, 6, 7, 8].publisher
  .scan((nil, nil)) { partialResult, current in
    (partialResult.1, current)
  }
  .map { ($0, $1!) }
  .sink { print($0) }

// Tell the diffable data source what changed

class ViewController2: UIViewController {
  @Published var itemState = ItemsState(numbers: Array(0...8))

  var dataSource: UICollectionViewDiffableDataSource<Int, ItemID>!
  var disposables: Set<AnyCancellable> = []

  override func viewDidLoad() {
    super.viewDidLoad()

    $itemState
      .scan((nil, nil)) { partialResult, current in
        (partialResult.1, current)
      }
      .map { ($0, $1!) }
      .sink { [weak self] previousState, currentState in
        guard let self = self else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Int, ItemID>()
        snapshot.appendSections([0])
        snapshot.appendItems(currentState.itemIDs, toSection: 0)

        // previousState would be nil only for the first emit
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
