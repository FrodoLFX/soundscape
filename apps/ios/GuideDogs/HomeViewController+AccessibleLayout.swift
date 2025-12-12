//
//  HomeViewController+AccessibleLayout.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import UIKit

// MARK: - Base accessible layout

extension HomeViewController {
    
    /// 在 `viewDidLoad()` 中调用，设置首页的基础无障碍布局。
    func setupAccessibleLayout() {
        // 让呼叫面板在首页有一个更舒适的最小高度，避免在大字号时挤压按钮
        calloutPanelContainerHeightConstraint.constant = max(calloutPanelContainerHeightConstraint.constant, 400)
        
        // 增大卡片区与上方搜索区域之间的间距
        cardContainerTopConstraints.forEach { constraint in
            constraint.constant = max(constraint.constant, 20)
        }
        
        // 让搜索框文本支持 Dynamic Type
        if let searchBar = navigationItem.searchController?.searchBar {
            let textField = searchBar.searchTextField
            textField.font = UIFont.preferredFont(forTextStyle: .body)
            textField.adjustsFontForContentSizeCategory = true
        }
        
        // 睡眠按钮：更大的触控区域 + 无障碍标签
        configureSleepButton()
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    private func configureSleepButton() {
        guard let button = sleepButton, let icon = sleepIcon else {
            return
        }
        
        // 使用 Dynamic Type 的标题字体
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title3)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        
        // 使用本地化的无障碍文案（需要在 Localizable.strings 添加相应 key）
        button.accessibilityLabel = GDLocalizedString("sleep_mode.title")
        button.accessibilityHint = GDLocalizedString("sleep_mode.hint")
        button.accessibilityTraits.insert(.button)
        
        // 使用系统 label 颜色，让图标跟随深浅模式和辅助设置
        icon.tintColor = .label
        
        // 在不破坏现有约束的前提下，确保有基本触控尺寸
        let minTouchSize: CGFloat = 60
        let hasExplicitSizeConstraint = button.constraints.contains {
            $0.firstAttribute == .height || $0.firstAttribute == .width
        }
        
        if !hasExplicitSizeConstraint {
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(greaterThanOrEqualToConstant: minTouchSize),
                button.widthAnchor.constraint(greaterThanOrEqualToConstant: minTouchSize)
            ])
        }
    }
    
    /// 在布局结束后适当调高 banner 区域的高度，避免内容过于拥挤。
    func applyAccessibleSpacing() {
        if !largeBannerContainerView.subviews.isEmpty {
            largeBannerContainerHeightConstraint.constant = max(largeBannerContainerHeightConstraint.constant, 80)
        }
        
        if !smallBannerContainerView.subviews.isEmpty {
            smallBannerContainerHeightConstraint.constant = max(smallBannerContainerHeightConstraint.constant, 60)
        }
    }
}

// MARK: - VoiceOver 优化

extension HomeViewController {
    
    @objc func voiceOverStatusChanged() {
        if UIAccessibility.isVoiceOverRunning {
            applyVoiceOverOptimizations()
        } else {
            removeVoiceOverOptimizations()
        }
    }
    
    /// VoiceOver 开启时，对首页整体做进一步的间距和朗读顺序优化。
    func applyVoiceOverOptimizations() {
        // 再稍微增加一点卡片上缘间距 & 呼叫面板高度，让区域更清晰
        cardContainerTopConstraints.forEach { $0.constant = max($0.constant, 24) }
        calloutPanelContainerHeightConstraint.constant = max(calloutPanelContainerHeightConstraint.constant, 420)
        
        // 确保搜索条对 VoiceOver 可见
        navigationItem.searchController?.searchBar.accessibilityElementsHidden = false
        
        // 定义首页主要区域的朗读顺序：
        // 1. 搜索条
        // 2. 大 banner
        // 3. 小 banner
        // 4. 呼叫按钮面板（tag = 1000）
        // 5. 卡片容器（tag = 2000）
        // 6. 睡眠按钮
        var orderedElements: [Any] = []
        
        if let searchBar = navigationItem.searchController?.searchBar {
            orderedElements.append(searchBar)
        }
        
        orderedElements.append(largeBannerContainerView as Any)
        orderedElements.append(smallBannerContainerView as Any)
        
        if let calloutContainer = view.viewWithTag(1000) {
            orderedElements.append(calloutContainer)
        }
        
        if let cardContainer = view.viewWithTag(2000) {
            orderedElements.append(cardContainer)
        }
        
        if let sleep = sleepButton {
            orderedElements.append(sleep)
        }
        
        view.accessibilityElements = orderedElements
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    /// VoiceOver 关闭后，回到基础可访问布局。
    func removeVoiceOverOptimizations() {
        // 清除自定义朗读顺序
        view.accessibilityElements = nil
        
        // 恢复为基础的无障碍布局（间距、panel 高度等）
        setupAccessibleLayout()
    }
}

// MARK: - Container 无障碍分组

extension HomeViewController {
    
    /// 对首页几个大容器做统一的分组和说明。
    func configureAccessibleContainers() {
        // 呼叫按钮容器（在 storyboard 里给容器 view 设置 tag = 1000）
        if let calloutContainer = view.viewWithTag(1000) {
            calloutContainer.accessibilityLabel = GDLocalizedString("callouts.panel.container.label")
            calloutContainer.accessibilityHint = GDLocalizedString("callouts.panel.container.hint")
            calloutContainer.shouldGroupAccessibilityChildren = true
        }
        
        // 卡片容器（在 storyboard 里给容器 view 设置 tag = 2000）
        if let cardContainer = view.viewWithTag(2000) {
            cardContainer.accessibilityLabel = GDLocalizedString("home.card.container.label")
            cardContainer.accessibilityHint = GDLocalizedString("home.card.container.hint")
            cardContainer.shouldGroupAccessibilityChildren = true
        }
        
        // banner 容器作为一个整体朗读
        largeBannerContainerView.shouldGroupAccessibilityChildren = true
        smallBannerContainerView.shouldGroupAccessibilityChildren = true
        
        // 搜索区域给一个合理的最小高度
        searchContainerHeightConstraint.constant = max(searchContainerHeightConstraint.constant, 60)
    }
}

