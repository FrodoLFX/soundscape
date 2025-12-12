//
//  EmptyMarkerOrRoutesList.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Licensed under the MIT License.
//

import SwiftUI

struct EmptyMarkerOrRoutesView: View {
    enum DisplayStyle {
        case markers
        case routes
    }

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 64.0

    let style: DisplayStyle

    init(_ style: DisplayStyle = .markers) {
        self.style = style
    }

    var localizedTitle: String {
        if style == .markers {
            return GDLocalizedString("markers.no_markers.title")
        } else {
            return GDLocalizedString("routes.no_routes.title")
        }
    }

    var localizedP1: String {
        if style == .markers {
            return GDLocalizedString("markers.no_markers.hint.1")
        } else {
            return GDLocalizedString("routes.no_routes.hint.1")
        }
    }

    var localizedP2: String {
        if style == .markers {
            return GDLocalizedString("markers.no_markers.hint.2")
        } else {
            return GDLocalizedString("routes.no_routes.hint.2")
        }
    }

    /// 让 VoiceOver 一次性朗读完整信息（标题 + 两段提示）
    private var accessibilitySummary: String {
        // 用句号分隔，避免 VoiceOver 连读成一坨
        "\(localizedTitle). \(localizedP1) \(localizedP2)"
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center) {
                Spacer()

                if style == .markers {
                    Image("marker.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.primaryForeground)
                        .frame(width: iconSize, height: iconSize)
                } else {
                    Image("route.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.primaryForeground)
                        .frame(width: iconSize, height: iconSize)
                }

                Spacer()
            }
            .accessibilityHidden(true)

            Text(localizedTitle)
                .multilineTextAlignment(.center)
                .font(.title)
                .lineLimit(nil)
                .foregroundColor(.primaryForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding([.top, .bottom], 16.0)

            Text(localizedP1)
                .multilineTextAlignment(.center)
                .font(.body)
                .lineLimit(nil)
                .foregroundColor(.primaryForeground)
                .padding([.bottom])

            Text(localizedP2)
                .multilineTextAlignment(.center)
                .font(.body)
                .lineLimit(nil)
                .foregroundColor(.primaryForeground)
        }
        .padding([.leading, .trailing], 32.0)
        .padding([.top, .bottom], 64.0)
        // 把子元素合并成一个可访问性元素（一次性读完）
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
        // 让它在 VoiceOver rotor 的“标题”里也可定位（虽然内容包含正文，但更利于快速导航）
        .accessibilityAddTraits([.isHeader])
    }
}

struct EmptyMarkerOrRoutesList_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EmptyMarkerOrRoutesView(.markers)
                .background(Color.quaternaryBackground)
            EmptyMarkerOrRoutesView(.routes)
                .background(Color.quaternaryBackground)
        }
    }
}

