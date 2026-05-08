📱 A project built with SwiftUI.

## Description: 
eCoastSys is an iOS app which visualizes real-world coastal/ocean data for the Monterey Bay (temperature, pollution, marine life sightings, tides) in real time. This repository contains the SwiftUI frontend which connects to the eCoastSys Vapor backend.

## App Evaluation
    Category: Environmental / Utility
    Mobile: Mobile exclusive
    Story: eCoastSys gives beachgoers, researchers, and outdoor enthusiasts a real-time window into Monterey Bay's coastal health — from water temperature anomalies to marine species sightings.
    Market: Outdoorsy people, researchers who might want to quickly see what coastal conditions are like
    Habit: Occasional use, mostly relevant when planning a visit to the beach or coast
    Scope: The app is pretty centralized to the Monterey Bay, but will hopefully have a decent scope when it comes to the information displayed about the local environment

Three App views: 
1. Interactable Map View which shows water quality and height levels throughout the coast.
2. Chart View time-series for temperature and tides. Red dots mark anomalies.
3. Species View Filterable list of marine life sightings from GBIF, with weekly trends.

Nav flow:
Users will open the app to the map view, with a navigation bar at the top of the screen allowing them to switch between this map, the charts view, and the species view.

## Wireframe and Screen Mockup
![coastal_swift_vapor_architecture](https://github.com/user-attachments/assets/34f71cdd-27ec-40cd-bea7-d470206ffc31)

## Live Demo
[Watch Demo Video](https://www.loom.com/share/1b80ee5d815b40b39dc546f3802e5e05)

---

## Unit 9 — Milestone 3

### Sprint 3 Progress (Completed)

- [x] Create iOS Xcode project with tab bar
- [x] Implement CoastalAPIClient networking layer
- [x] Build Species view with real GBIF data and search
- [x] Build Map view with MapKit station pins
- [x] Build Charts view with Swift Charts temperature data
- [x] End-to-end test on physical device

### Build Progress

> Sprint 3 demo — Full iOS app with Map, Charts, and Species views connected to live backend

[Watch Demo Video](https://www.loom.com/share/1b80ee5d815b40b39dc546f3802e5e05)

### GitHub Project Board
[eCoastSys Sprint Board](https://github.com/users/jocy358/projects/1)

### Sprints

**Sprint 3 — iOS Views** ✅
- Tab bar with Map, Charts, Species views
- CoastalAPIClient connecting to live Railway backend
- Species view loading real GBIF marine sightings from Monterey Bay with group filters
- Map view with MapKit station pins colour-coded by water quality
- Charts view with Swift Charts temperature time-series and anomaly highlighting

---

## Getting Started

### Requirements
- Xcode 15+
- iOS 16+

### Backend
The backend is deployed on Railway — no local setup needed. The app connects to:
https://railway.com/project/bd6e6e48-4c61-4b7f-a36c-67c21a087bb5?environmentId=da255ce8-a792-4e2d-888c-4a4e423ddcf7

### Running the App
1. Open `eCoastSys/eCoastSys.xcodeproj` in Xcode
2. Select your simulator or device
3. Hit Play
