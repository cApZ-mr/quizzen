//
//  GIFView.swift
//  IOS - Quizzen
//
//  Created by Malte Rein on 30.06.26.
//

import Foundation
import SwiftUI
import WebKit

struct GIFView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        
        if let url = Bundle.main.url(forResource: gifName, withExtension: "gif") {
            if let data = try? Data(contentsOf: url) {
                webView.load(data, mimeType: "image/gif", characterEncodingName: "UTF-8", baseURL: url.deletingLastPathComponent())
            }
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
