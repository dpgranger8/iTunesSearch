
import UIKit

class StoreItemContainerViewController: UIViewController, UISearchResultsUpdating {
    
    @IBOutlet var tableContainerView: UIView!
    @IBOutlet var collectionContainerView: UIView!
    
    let searchController = UISearchController()
    let storeItemController = StoreItemController()
    
    var items = [StoreItem]()
    var tableViewDataSource: UITableViewDiffableDataSource<String, StoreItem>!
    var collectionViewDataSource: UICollectionViewDiffableDataSource<String, StoreItem>!
    var itemsSnapshot: NSDiffableDataSourceSnapshot<String, StoreItem> {
        var snapshot = NSDiffableDataSourceSnapshot<String, StoreItem>()
        snapshot.appendSections(["Results"])
        snapshot.appendItems(items)
        return snapshot
    }

    let queryOptions = ["movie", "music", "software", "ebook"]
    
    // keep track of async tasks so they can be cancelled if appropriate.
    var searchTask: Task<Void, Never>? = nil
    var tableViewImageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    var collectionViewImageLoadTasks: [IndexPath: Task<Void, Never>] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.automaticallyShowsSearchResultsController = true
        searchController.searchBar.showsScopeBar = true
        searchController.searchBar.scopeButtonTitles = ["Movies", "Music", "Apps", "Books"]
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let tableViewController = segue.destination as? StoreItemListTableViewController {
            configureTableViewDataSource(tableViewController.tableView)
        } else if let collectionViewController = segue.destination as? StoreItemCollectionViewController {
            configureCollectionViewDataSource(collectionViewController.collectionView)
        }
    }
    
    func configureTableViewDataSource(_ tableView: UITableView) {
        tableViewDataSource = UITableViewDiffableDataSource<String,
           StoreItem>(tableView: tableView, cellProvider: { (tableView,
           indexPath, item) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier:
               "Item", for: indexPath) as! ItemTableViewCell
               
            self.tableViewImageLoadTasks[indexPath]?.cancel()
            self.tableViewImageLoadTasks[indexPath] = Task {
                await cell.configure(for: item, storeItemController: self.storeItemController)
                self.tableViewImageLoadTasks[indexPath] = nil
            }
               
            return cell
        })
    }
    
    func configureCollectionViewDataSource(_ collectionView:
       UICollectionView) {
        collectionViewDataSource =
           UICollectionViewDiffableDataSource<String, StoreItem>(collectionView: collectionView, cellProvider:
       { (collectionView, indexPath, item) -> UICollectionViewCell? in
            let cell =
               collectionView.dequeueReusableCell(withReuseIdentifier:
               "Item", for: indexPath) as! ItemCollectionViewCell2
            self.collectionViewImageLoadTasks[indexPath]?.cancel()
            self.collectionViewImageLoadTasks[indexPath] = Task {
                await cell.configure(for: item, storeItemController: self.storeItemController)
                self.collectionViewImageLoadTasks[indexPath] = nil
            }
            return cell
        })
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(fetchMatchingItems), object: nil)
        perform(#selector(fetchMatchingItems), with: nil, afterDelay: 0.2)
    }
                
    @IBAction func switchContainerView(_ sender: UISegmentedControl) {
        tableContainerView.isHidden.toggle()
        collectionContainerView.isHidden.toggle()
    }
    
    @objc func fetchMatchingItems() {
        
        self.items = []
                
        let searchTerm = searchController.searchBar.text ?? ""
        let mediaType = queryOptions[searchController.searchBar.selectedScopeButtonIndex]
        
        // cancel existing task since we will not use the result
        searchTask?.cancel()
        
        // Cancel any images that are still being fetched and reset the imageTask dictionaries
        collectionViewImageLoadTasks.values.forEach { task in task.cancel()
            collectionViewImageLoadTasks = [:]
        }
        
        tableViewImageLoadTasks.values.forEach { task in task.cancel()
            tableViewImageLoadTasks = [:]
        }
        
        searchTask = Task {
            if !searchTerm.isEmpty {
                
                // set up query dictionary
                let query = [
                    "term": searchTerm,
                    "media": mediaType,
                    "lang": "en_us",
                    "limit": "20"
                ]
                
                // use the item controller to fetch items
                do {
                    // use the item controller to fetch items
                    let items = try await storeItemController.fetchItems(matching: query)
                    if searchTerm == self.searchController.searchBar.text &&
                          mediaType == queryOptions[searchController.searchBar.selectedScopeButtonIndex] {
                        self.items = items
                    }
                } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    // ignore cancellation errors
                } catch {
                    // otherwise, print an error to the console
                    print(error)
                }
                await tableViewDataSource.apply(itemsSnapshot, animatingDifferences: true)
                await collectionViewDataSource.apply(itemsSnapshot, animatingDifferences: true)
            } else {
                let snapshot = NSDiffableDataSourceSnapshot<String, StoreItem>()
                await tableViewDataSource.apply(snapshot, animatingDifferences: true)
                await collectionViewDataSource.apply(snapshot, animatingDifferences: true)
            }
            searchTask = nil
        }
    }
    
}
