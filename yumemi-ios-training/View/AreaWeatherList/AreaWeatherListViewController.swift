import Combine
import Foundation
import UIKit
import YumemiWeather

protocol AreaWeatherListViewModelProtocol {
    var isLoading: CurrentValueSubject<Bool, Never> { get }
    var areaWeathers: CurrentValueSubject<[AreaWeather], Never> { get }
    var error: PassthroughSubject<Error, Never> { get }
    func requestAreaWeather(areas: [Area], date: Date)
}

final class AreaWeatherListViewController: UITableViewController {
    
    // An message underneath the tableview to notify user to pull down to refresh
    let emptyDataMessageLabel = UILabel()
    
    private var viewModel: AreaWeatherListViewModelProtocol
    private var cancellables: [AnyCancellable] = []
    
    private var areaWeathers: [AreaWeather] = [] {
        didSet {
            emptyDataMessageLabel.isHidden = !areaWeathers.isEmpty
            tableView.reloadData()
        }
    }
    
    init(viewModel: AreaWeatherListViewModelProtocol) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
        subscribe()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        navigationItem.title = NSLocalizedString("Weathers", comment: "")
        configureTableview()
        configureRefreshControl()
        viewModel.requestAreaWeather(areas: Area.allCases, date: Date())
    }
    
    private func configureTableview() {
        tableView.register(AreaWeatherListCell.self, forCellReuseIdentifier: AreaWeatherListCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        
        emptyDataMessageLabel.text = NSLocalizedString("There is nothing. \nPull down to refresh!", comment: "")
        emptyDataMessageLabel.textColor = .secondaryLabel
        emptyDataMessageLabel.numberOfLines = 0
        emptyDataMessageLabel.textAlignment = .center
        tableView.backgroundView = emptyDataMessageLabel
    }
    
    func configureRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(requestWeather), for: .valueChanged)
    }
    
    private func subscribe() {
        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.setLoadingState(isLoading: $0)
            }
            .store(in: &cancellables)
        
        viewModel.areaWeathers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] areaWeathers in
                self?.areaWeathers = areaWeathers
            }
            .store(in: &cancellables)
        
        viewModel.error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.presentError(error, showErrorDetail: false)
            }
            .store(in: &cancellables)
    }
    
    @objc private func requestWeather() {
        viewModel.requestAreaWeather(areas: Area.allCases, date: Date())
    }
    
    private func setLoadingState(isLoading: Bool) {
        if isLoading {
            refreshControl?.beginRefreshing()
        } else {
            refreshControl?.endRefreshing()
        }
    }
    
    private func presentError(_ error: Error, showErrorDetail: Bool) {
        let errorMessage = showErrorDetail ? error.localizedDescription: NSLocalizedString("An error occurred.", comment: "")
        let alertController = UIAlertController(
            title: NSLocalizedString("Oops!", comment: "The title for errors."),
            message: errorMessage,
            preferredStyle: .alert
        )
        alertController.addAction(
            UIAlertAction(
                title: NSLocalizedString("OK", comment: ""),
                style: .default,
                handler: nil
            )
        )
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - UITableView DataSource and Delegate
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        areaWeathers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AreaWeatherListCell.identifier) as? AreaWeatherListCell else {
            return .init()
        }
        let areaWeather = areaWeathers[indexPath.row]
        cell.configure(areaWeather: areaWeather)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let areaWeather = areaWeathers[indexPath.row]
        let weatherViewModel = WeatherViewModel(area: areaWeather.area, weather: areaWeather.info)
        let weatherViewController = WeatherViewController(weatherViewModel: weatherViewModel)
        show(weatherViewController, sender: nil)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
