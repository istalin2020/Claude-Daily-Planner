# Daily Planner — iOS App

A beautifully designed, full-featured daily planning iOS app built with **SwiftUI**.

## Features

### 📅 Smart Date Navigation
- Horizontal scrollable date bar at the top (scroll left/right by month)
- Month/Year picker popup
- Visual indicator dots on days with saved data
- Always defaults to **today** on launch
- "Today" quick-access button in the header

### 📋 13 Dedicated Sections
Each section has its own tab with pop-up input dialogs:

| Tab | Description |
|-----|-------------|
| 📊 Overview | All-in-one summary of your entire day |
| ⭐ Top Priorities | Your most important tasks (max focus) |
| 📞 Calls & Emails | Track calls and emails to make |
| ✅ Personal To-Do | General personal task list |
| 💪 Health & Fitness | Log workouts, steps, and minutes |
| 💧 Water Tracker | Visual glass tracker with daily goal |
| 🍽️ Food Tracker | Breakfast, Lunch, Dinner & Snacks |
| 🗓️ Daily Schedule | Time-block planning (hour by hour) |
| 🕐 Appointments | Timed appointments with location & notes |
| 📝 Notes | Free-form daily notes with writing prompts |
| 🌙 Notes Tomorrow | Plan and prepare for the next day |
| 💰 Expenses | Track spending, savings & future fund |
| ❤️ Rate Your Day | Rate productivity, mood & health (1–5 stars) |

### 🔄 Task Rollover
- On launch, if yesterday had incomplete tasks, a prompt appears
- Choose to **roll them over** to today with an orange "Rolled" badge
- Or keep them in yesterday's log as-is

### 📊 Overview Dashboard
Shows a live summary of every section:
- Task completion ring (percentage)
- Quick stat cards (priorities, water, spending)
- Mini previews of every section with tap-to-navigate

### 💾 Data Persistence
- All data saved locally via **UserDefaults** (JSON encoded)
- Past days are always accessible — scroll back in the date bar
- Each day's data is independent and preserved indefinitely

## Requirements

- **Xcode 15+**
- **iOS 17.0+**
- Swift 5.9+

## How to Open

1. Clone this repository
2. Open `DailyPlanner.xcodeproj` in Xcode
3. Select your iPhone or Simulator target
4. Press `Cmd+R` to build and run

## Architecture

```
DailyPlanner/
├── DailyPlannerApp.swift         # App entry point
├── Models/
│   └── PlannerModels.swift       # All data models
├── ViewModels/
│   └── PlannerViewModel.swift    # State management & persistence
└── Views/
    ├── ContentView.swift         # Main layout (header + tabs)
    ├── OverviewView.swift        # Dashboard summary
    ├── TopPrioritiesView.swift
    ├── CallsEmailsView.swift
    ├── PersonalTodoView.swift
    ├── HealthFitnessView.swift
    ├── WaterTrackerView.swift
    ├── FoodTrackerView.swift
    ├── DailyScheduleView.swift
    ├── AppointmentsView.swift
    ├── NotesView.swift
    ├── NotesForTomorrowView.swift
    ├── ExpenseTrackerView.swift
    ├── RateYourDayView.swift
    └── Components/
        ├── DateScrollerView.swift  # Horizontal date picker
        └── SharedComponents.swift  # Reusable UI components
```

## Design Highlights

- Each section has a unique **colour theme** for instant visual recognition
- **Smooth animations** on task completion, water tracking, and section switching
- **Card-based layout** with subtle shadows throughout
- **Emoji-based day rating** feedback (😔 to 🌟)
- Hydration tips, writing prompts, and tomorrow planning prompts built in
- Fully accessible colour contrasts

---

Built with ❤️ using SwiftUI • Designed for daily productivity
