<div align="center">

# 🚌 UniRide Client
### Driver Management Companion — Flutter App

**UniRide Client** is the official driver-side application for the [UniRide](https://github.com/lynx7843/UniRide) ecosystem.  
Built with **Flutter**, it empowers university shuttle drivers to manage their shifts, view assigned routes, and broadcast live location data to the student network.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green)](https://flutter.dev)

</div>

---

## 📖 About

While the student app focuses on tracking, **UniRide Client** is the operational backbone for drivers on the road. Designed for minimal distraction and high reliability, this app allows drivers to log into their assigned vehicles, start their shifts, and ensure that real-time tracking data is actively syncing with the university network. 

---

## ✨ Features

### 📍 Route & Shift Management
- View daily assigned routes and schedules
- Start and end shifts with a single tap
- Clear, distraction-free UI optimized for use while mounted on a dashboard

### 📡 Live Location Broadcasting
- Integrates with the backend to sync driver status
- Background location services to ensure continuous bus tracking for students
- Status indicators for GPS signal strength and server connection

### 👥 Capacity & Incident Reporting
- Quick-tap capacity updates (e.g., Bus Full / Seats Available)
- Easy reporting for delays, traffic, or emergency route deviations
- Direct communication link with the campus transport dispatch

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart |
| Maps/Routing | Stadia Map / OpenStreetMap |
| Backend | AWS |
| Core Packages | `geolocator` (Background GPS), `flutter_background_service` |

> The backend and admin dashboards are maintained in the main [UniRide repository](https://github.com/lynx7843/UniRide).

---

## 🚀 Getting Started

### Installation

```bash
# 1. Clone this repository
git clone https://github.com/lynx7843/UniRide_client.git
cd UniRide-client

# 2. Install dependencies
flutter pub get

# 3. Configure the backend URL

# 4. Run the app (requires physical device for accurate GPS testing)
flutter run
```

---

## 🎯 Target Users

- **Shuttle Drivers** — To manage routes, broadcast locations, and report capacities.
- **Transport Administrators** — To monitor driver activity and fleet health via the connected web dashboard.


<br>

<div align="center">
  Part of the <strong>UniRide</strong> ecosystem.
</div>