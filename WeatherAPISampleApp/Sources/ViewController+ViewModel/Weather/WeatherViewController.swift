//
//  WeatherViewController.swift
//  WeatherAPISampleApp
//
//  Created by 前澤健一 on 2021/08/23.
//

import RxSwift
import RxCocoa

final class WeatherViewController: UIViewController {

    // MARK: - Properties
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var toSearchHistoryButton: UIButton!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var indicator: UIActivityIndicatorView! {
        didSet {
            indicator.hidesWhenStopped = true
        }
    }
    private let closeButton = UIBarButtonItem(systemItem: .close)
    private let viewModel = WeatherViewModel()
    private let disposeBag = DisposeBag()
    
    // インスタンス化
    static func configure() -> Self {
        let viewController = UIStoryboard(name: Self.className, bundle: nil)
            .instantiateViewController(identifier: Self.className) as! Self
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        bind()
    }
    
    private func setupView() {
        self.navigationItem.title = "Weather Sample App"
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 35))
        toolbar.setItems([closeButton], animated: true)
        searchBar.searchTextField.inputAccessoryView = toolbar
        tableView.register(UINib(nibName: WeatherSummaryCell.className, bundle: nil), forCellReuseIdentifier: WeatherSummaryCell.className)
        tableView.register(UINib(nibName: ForecastWeatherCell.className, bundle: nil), forCellReuseIdentifier: ForecastWeatherCell.className)
        tableView.tableFooterView = UIView(frame: .zero)
        navigationItem.backButtonTitle = ""
    }
    
    // ViewModelとデータバインド
    private func bind() {
        searchBar.rx.text.orEmpty.asObservable()
            .bind(to: viewModel.input.searchBarText)
            .disposed(by: disposeBag)
        
        searchBar.rx.searchButtonClicked.asObservable()
            .bind(to: viewModel.input.searchButtonClicked)
            .disposed(by: disposeBag)

        toSearchHistoryButton.rx.tap.asSignal()
            .emit(onNext: { [weak self] in
                let searchHistoryVC = SearchHistoryViewController.configure(with: SearchHistoryViewModel(currentSearchBarText: self?.searchBar.text ?? ""))
                searchHistoryVC.delegate = self
                self?.navigationController?.pushViewController(searchHistoryVC, animated: false)
            })
            .disposed(by: disposeBag)
        
        viewModel.output.weather
            .drive(tableView.rx.items) { tableView, row, element in
                switch element {
                case .current(let current):
                    let cell = tableView.dequeueReusableCell(withIdentifier: WeatherSummaryCell.className, for: [0, row]) as! WeatherSummaryCell
                    cell.configure(with: current)
                    return cell
                case .forecast(let forecast):
                    let cell = tableView.dequeueReusableCell(withIdentifier: ForecastWeatherCell.className, for: [0, row]) as! ForecastWeatherCell
                    cell.configure(with: forecast)
                    return cell
                }
            }
            .disposed(by: disposeBag)
        
        viewModel.output.isLoading
            .drive(onNext: { [weak self] isLoading in
                if isLoading {
                    UIView.animate(withDuration: 0.3) {
                        self?.indicator.startAnimating()
                        self?.tableView.alpha = 0.5
                    }
                } else {
                    UIView.animate(withDuration: 0.3) {
                        self?.indicator.stopAnimating()
                        self?.tableView.alpha = 1
                    }
                }
            })
            .disposed(by: disposeBag)
        
        viewModel.output.showErrorAlert
            .drive(onNext: { [weak self] message in
                let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alertController, animated: true)
            })
            .disposed(by: disposeBag)
        
        closeButton.rx.tap.asObservable()
            .subscribe(onNext: { [weak self] in
                self?.searchBar.searchTextField.endEditing(true)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - SearchHistoryViewControllerDelegate
extension WeatherViewController: SearchHistoryViewControllerDelegate {
    func searchHistoryViewControllerDidSelect(_ searchWord: String) {
        searchBar.text = searchWord
        viewModel.input.searchBarText.accept(searchWord)
        viewModel.input.searchButtonClicked.accept(())
    }
}
