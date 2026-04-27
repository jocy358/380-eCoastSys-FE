//
//  ContentView.swift
//  eCoastSys
//
//  Created by Miguel O on 4/27/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            ChartsView()
                .tabItem {
                    Label("Charts", systemImage: "chart.xyaxis.line")
                }
            SpeciesView()
                .tabItem {
                    Label("Species", systemImage: "fish")
                }
        }
    }
}

#Preview {
    ContentView()
}
