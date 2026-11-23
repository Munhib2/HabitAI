# HabitAI

AI-Powered Habit & Productivity Coach — iOS app with Node.js backend.

## Project Structure

```
HabitAI/
├── backend/                      # Node.js/Express API
│   ├── src/
│   │   ├── index.js              # Entry point
│   │   ├── routes/
│   │   │   ├── auth.js           # Apple Sign In
│   │   │   ├── habits.js         # Habit CRUD
│   │   │   ├── checkins.js       # Daily check-ins
│   │   │   ├── voice.js          # Voice transcription
│   │   │   ├── coaching.js       # Claude AI coaching
│   │   │   ├── stats.js          # Streaks & analytics
│   │   │   ├── subscriptions.js  # StoreKit verification
│   │   │   └── notifications.js  # APNs push notifications
│   │   ├── middleware/
│   │   │   └── auth.js           # JWT auth middleware
│   │   └── services/
│   │       ├── supabase.js       # DB client
│   │       └── cronService.js    # Scheduled jobs
│   ├── database/
│   │   └── migrations/
│   │       └── 001_initial_schema.sql
│   ├── .env.example              # Environment variables template
│   ├── railway.toml              # Railway deployment
│   └── fly.toml                  # Fly.io deployment (alternative)
│
└── iOS/
    ├── HabitAI/
    │   ├── HabitAIApp.swift      # App entry point
    │   ├── Models/
    │   │   └── Models.swift      # All data models
    │   ├── Services/
    │   │   └── APIClient.swift   # Backend API calls
    │   ├── ViewModels/
    │   │   ├── AuthViewModel.swift
    │   │   └── ViewModels.swift  # Today, Progress, Coach, Habits VMs
    │   ├── Views/
    │   │   ├── ContentView.swift
    │   │   ├── Onboarding/
    │   │   │   └── OnboardingView.swift
    │   │   ├── Today/
    │   │   │   ├── TodayView.swift
    │   │   │   ├── AddHabitView.swift
    │   │   │   └── VoiceCheckinView.swift
    │   │   ├── Progress/
    │   │   │   └── ProgressView.swift
    │   │   ├── Coach/
    │   │   │   └── CoachView.swift
    │   │   └── Settings/
    │   │       ├── SettingsView.swift
    │   │       └── PaywallView.swift
    │   └── Utilities/
    │       └── Extensions.swift
    └── HabitAIWidget/
        └── HabitAIWidget.swift   # Home screen widget
```

## Setup Instructions

### Backend

1. Copy `.env.example` to `.env` and fill in your credentials
2. `cd backend && npm install`
3. Run the SQL migration in your Supabase dashboard
4. `npm run dev` to start locally

### iOS

1. Open `iOS/HabitAI.xcodeproj` in Xcode
2. Update the bundle ID to match your Apple Developer account
3. Update `APIClient.swift` line with your deployed backend URL
4. Update all `com.yourname.habitai` references to your bundle ID
5. Add `Sign in with Apple` capability in Xcode
6. Add `Push Notifications` capability
7. Set up App Group `group.com.yourname.habitai` for the widget

## Deployment

### Backend → Railway
1. Connect your GitHub repo to Railway
2. Add all environment variables from `.env.example`
3. Deploy — Railway auto-detects Node.js

### iOS → App Store
1. Archive in Xcode → Product → Archive
2. Upload to App Store Connect
3. Submit for review
