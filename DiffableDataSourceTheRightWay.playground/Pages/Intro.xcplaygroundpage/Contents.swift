import Combine
import UIKit

// Use an entire data structure as diffable data source item ID
// Diffable data source can detect insert, delete, move & update (delete + insert)

struct Item: Hashable {
  let id: UUID
  var number: Int
}



// Observe a combine data store

class ViewController: UIViewController {
  @Published var items = (0...7).map { Item(id: UUID(), number: $0) }

  var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
  var disposables: Set<AnyCancellable> = []

  override func viewDidLoad() {
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



// Implement a proper item ID (Hashable)
// Diffable data source can still detect insert, delete & move, but not update

typealias ItemID = UUID

struct ItemsState: Equatable {
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
[0, 1, 2, 3, 4, 5, 6, 7].reduce(0, +)
[0, 1, 2, 3, 4, 5, 6, 7].reduce(0) { partialResult, current in
  partialResult + current
}
// 28



// Combine version of reduce(): scan()
[0, 1, 2, 3, 4, 5, 6, 7].publisher
  .scan(0) { partialResult, current in
    partialResult + current
  }
  .sink { print($0) } // 0 1 3 6 10 15 21 28



// Use scan() to produce previous state
[0, 1, 2, 3, 4, 5, 6, 7].publisher
  .scan((nil, nil)) { partialResult, current in
    (partialResult.1, current)
  }
  .map { ($0, $1!) }
  .sink { print($0) } // (nil, 0), (0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7)



// Tell the diffable data source what changed



class ViewController2: UIViewController {
  @Published var itemState = ItemsState(numbers: Array(0...8))

  var dataSource: UICollectionViewDiffableDataSource<Section, ItemID>!
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
        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemID>()
        snapshot.appendSections([.default])
        snapshot.appendItems(currentState.itemIDs, toSection: .default)

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








enum Section {
  case `default`
}
