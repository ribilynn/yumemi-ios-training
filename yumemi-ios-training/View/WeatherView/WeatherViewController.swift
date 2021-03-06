import Combine
import UIKit
import SnapKit
import YumemiWeather

protocol WeatherViewModelProtocol {
    var area: Area { get }
    var isLoading: CurrentValueSubject<Bool, Never> { get }
    var weather: CurrentValueSubject<Weather?, Never> { get }
    var error: PassthroughSubject<Error, Never> { get }
    func requestWeather(date: Date)
}

final class WeatherViewController: UIViewController {
    
    /// A LayoutGuide contains the imageView and two temperature labels.
    let infoContainerLayoutGuide = UILayoutGuide()
    let weatherIconView = WeatherIconView()
    let minTemperatureLabel = UILabel()
    let maxTemperatureLabel = UILabel()
    
    let closeButton = UIButton(type: .system)
    let reloadButton = UIButton(type: .system)
    
    let dateLabel = UILabel()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
    
    let activityView = UIActivityIndicatorView()
    
    private var viewModel: WeatherViewModelProtocol
    private var cancellables: [AnyCancellable] = []
    
    init(weatherViewModel: WeatherViewModelProtocol) {
        self.viewModel = weatherViewModel
        super.init(nibName: nil, bundle: nil)
        subscribe()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        addSubviewsAndConstraints()
        setViewsProperties()
    }
    
    private func subscribe() {
        viewModel.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.setLoadingState(isLoading: $0)
            }
            .store(in: &cancellables)
        
        viewModel.weather
            .receive(on: DispatchQueue.main)
            .sink { [weak self] weather in
                if let weather = weather {
                    self?.showWeather(weather)
                }
            }
            .store(in: &cancellables)
        
        viewModel.error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.presentError(error, showErrorDetail: false)
            }
            .store(in: &cancellables)
        
        NotificationCenter.Publisher(
            center: .default,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.viewModel.requestWeather(date: Date())
            }
            .store(in: &cancellables)
    }
    
    private func addSubviewsAndConstraints() {
        view.addSubview(weatherIconView)
        weatherIconView.snp.makeConstraints { make in
            make.width.equalToSuperview().dividedBy(2)
            make.height.equalTo(weatherIconView.snp.width)
        }
        
        view.addSubview(minTemperatureLabel)
        minTemperatureLabel.snp.makeConstraints { make in
            make.top.equalTo(weatherIconView.snp.bottom)
            make.leading.equalTo(weatherIconView)
            make.width.equalTo(weatherIconView).dividedBy(2)
        }
        
        view.addSubview(maxTemperatureLabel)
        maxTemperatureLabel.snp.makeConstraints { make in
            make.top.equalTo(weatherIconView.snp.bottom)
            make.trailing.equalTo(weatherIconView)
            make.width.equalTo(weatherIconView).dividedBy(2)
        }
        
        view.addLayoutGuide(infoContainerLayoutGuide)
        infoContainerLayoutGuide.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(weatherIconView)
            make.bottom.equalTo(minTemperatureLabel)
            make.center.equalToSuperview()
        }
        
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(minTemperatureLabel.snp.bottom).offset(80)
            make.centerX.equalTo(minTemperatureLabel)
        }
        
        view.addSubview(reloadButton)
        reloadButton.snp.makeConstraints { make in
            make.top.equalTo(maxTemperatureLabel.snp.bottom).offset(80)
            make.centerX.equalTo(maxTemperatureLabel)
        }
        
        view.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(infoContainerLayoutGuide.snp.top).offset(-40)
        }
        
        view.addSubview(activityView)
        activityView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(infoContainerLayoutGuide.snp.bottom)
            make.bottom.equalTo(closeButton.snp.top)
        }
    }
    
    private func setViewsProperties() {
        view.backgroundColor = .systemBackground
        navigationItem.title = viewModel.area.rawValue
        
        minTemperatureLabel.text = "--"
        minTemperatureLabel.textColor = .systemBlue
        minTemperatureLabel.textAlignment = .center
        minTemperatureLabel.font = .preferredFont(forTextStyle: .title1)
        maxTemperatureLabel.text = "--"
        maxTemperatureLabel.textColor = .systemRed
        maxTemperatureLabel.textAlignment = .center
        maxTemperatureLabel.font = .preferredFont(forTextStyle: .title1)
        
        dateLabel.text = "--"
        dateLabel.textAlignment = .center
        
        closeButton.setTitle(NSLocalizedString("Close", comment: ""), for: .normal)
        closeButton.addAction(
            UIAction(handler: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }),
            for: .touchUpInside
        )
        reloadButton.setTitle(NSLocalizedString("Reload", comment: ""), for: .normal)
        reloadButton.addAction(
            UIAction(handler: { [weak self] _ in
                self?.viewModel.requestWeather(date: Date())
            }),
            for: .touchUpInside
        )
    }
    
    private func setLoadingState(isLoading: Bool) {
        if isLoading {
            activityView.startAnimating()
            reloadButton.isEnabled = false
        } else {
            activityView.stopAnimating()
            reloadButton.isEnabled = true
        }
    }
    
    private func showWeather(_ weather: Weather) {
        minTemperatureLabel.text = String(weather.minTemperature)
        maxTemperatureLabel.text = String(weather.maxTemperature)
        weatherIconView.setIcon(with: weather.name)
        dateLabel.text = dateFormatter.string(from: weather.date)
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
}
