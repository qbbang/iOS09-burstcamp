//
//  DefaultProfileImageView.swift
//  Eoljuga
//
//  Created by neuli on 2022/11/18.
//

import UIKit

final class DefaultProfileImageView: UIImageView {

    let imageSize: Int

    init(imageSize: Int) {
        // TODO: bounds로 width, height 설정이 안됩니다.ㅠ
        self.imageSize = imageSize
        super.init(frame: .zero)
        layer.cornerRadius = imageSize.cgFloat / 2
        clipsToBounds = true
        image = UIImage(systemName: "person.fill")
        contentMode = .scaleAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
