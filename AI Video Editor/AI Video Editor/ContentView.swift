//
//  ContentView.swift
//  AI Video Editor
//
//  Created by Abdur-Rahman Rana on 2025-09-01.
//

import SwiftUI

struct ContentView: View {
    var result: Int32 { divide_by_two(40) }   // add_one is from Rust

    var body: some View {
        Text("Result from Rust: \(result)")
            .padding()
    }
}

#Preview {
    ContentView()
}
