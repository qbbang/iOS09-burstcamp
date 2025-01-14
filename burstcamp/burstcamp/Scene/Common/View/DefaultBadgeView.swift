//
//  DefaultBadgeView.swift
//  Eoljuga
//
//  Created by neuli on 2022/11/19.
//

import UIKit

final class DefaultBadgeView: UIView {

    // MARK: - Properties

    private lazy var domainLabel = DefaultBadgeLabel(
        textColor: Domain.iOS.color
    )

    private lazy var numberLabel = DefaultBadgeLabel(
        textColor: .main
    )

    private lazy var camperIDLabel = DefaultBadgeLabel(
        textColor: .systemGray2
    )

    // MARK: - Initializer

    init() {
        super.init(frame: .zero)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Methods

    private func configureUI() {
        let badgeStackView = UIStackView(
            arrangedSubviews: [domainLabel, numberLabel, camperIDLabel]
        ).then {
            $0.axis = .horizontal
            $0.distribution = .equalSpacing
            $0.alignment = .fill
            $0.spacing = Constant.space4.cgFloat
        }
        addSubview(badgeStackView)
        badgeStackView.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
        }
    }
}

extension DefaultBadgeView {
    func updateView(feed: Feed) {
        domainLabel.updateView(text: feed.camperDomain)
        let number = "\(feed.camperNumber)기"
        numberLabel.updateView(text: number)
        camperIDLabel.updateView(text: feed.camperID)
    }
}
