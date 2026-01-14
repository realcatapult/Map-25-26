# Flutter Login & Home App Documentation

## Project Overview
This is a Flutter application with Firebase Authentication, featuring a login/registration system and a home page with calendar and announcements functionality.

---

## Project Structure

```
lib/
├── main.dart                 # App entry point with Firebase initialization
├── firebase_options.dart     # Firebase configuration (auto-generated)
├── Pages/
│   ├── auth_page.dart       # Toggles between login and register pages
│   ├── login_page.dart      # Email login page
│   ├── register_page.dart   # Email registration page
│   └── home_page.dart       # Main home page with calendar and announcements
├── services/
│   └── auth_service.dart    # Firebase authentication service
└── components/
    ├── my_button.dart       # Custom button component
    ├── my_textfield.dart    # Custom text field component
    └── square_tile.dart     # Social login tile component
```

---

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  firebase_core: ^3.8.1        # Firebase core functionality
  firebase_auth: ^5.3.3        # Firebase authentication
  table_calendar: ^3.1.2       # Calendar widget
```

---

## Features & Components

### 1. Authentication System

#### **AuthService** (`lib/services/auth_service.dart`)
Handles all Firebase authentication operations.

**Methods:**
- `signInWithEmailPassword(String email, String password)` - Signs in existing users
- `signUpWithEmailPassword(String email, String password)` - Registers new users
- `signOut()` - Signs out current user

**Error Handling:**
- Catches Firebase exceptions and returns user-friendly error messages
- Errors are displayed via SnackBar notifications

#### **Login Page** (`lib/Pages/login_page.dart`)
- Email and password input fields
- Sign-in button that authenticates with Firebase
- Link to navigate to registration page
- Error handling with SnackBar messages
- Social login placeholders (Google, Apple)

#### **Register Page** (`lib/Pages/register_page.dart`)
- Email, password, and confirm password fields
- Password matching validation
- Sign-up button that creates new Firebase accounts
- Link to navigate back to login page
- Error handling with SnackBar messages

#### **Auth Page** (`lib/Pages/auth_page.dart`)
- Wrapper component that toggles between login and register pages
- Manages navigation state between the two screens

---

### 2. Home Page (`lib/Pages/home_page.dart`)

The main screen after successful authentication, featuring:

#### **Calendar Section** (Top Half)
- Interactive calendar showing current month
- Today's date highlighted in grey
- Selected date highlighted in black
- Blue dot markers indicate days with events
- Event display box below calendar showing:
  - Selected date
  - Events scheduled for that day
  - "No events scheduled" message for empty days

**Demo Event:**
- Today's date has: "Practice at 6:30PM - 9PM, GYM"

#### **Announcements Section** (Bottom Half)
- Displays team announcements from coaches/captains
- Shows announcement title, sender, and timestamp
- Scrollable list view

**Demo Announcements:**
1. "Practice Tomorrow" - Coach, 2 hours ago
2. "Game Schedule Posted" - Captain, 5 hours ago
3. "Team Meeting Friday" - Coach, 1 day ago

#### **Bottom Navigation Bar**
Five navigation icons (Instagram-style):
1. **Home** - Home icon
2. **Chat** - Chat bubble icon
3. **Calendar** - Calendar icon
4. **Search** - Search icon
5. **Settings** - Settings gear icon

**Features:**
- Logout button in app bar
- Consistent grey background design matching login page
- White card containers for calendar and announcements
- Responsive layout with proper spacing

---

### 3. Reusable Components

#### **MyTextField** (`lib/components/my_textfield.dart`)
Custom text input field with consistent styling.

**Properties:**
- `controller` - TextEditingController for managing input
- `hintText` - Placeholder text
- `obscureText` - Boolean for password fields
- Grey background with white border
- Auto-suggestions enabled for non-password fields

#### **MyButton** (`lib/components/my_button.dart`)
Custom button with app styling.

**Properties:**
- `onTap` - Callback function for button press
- Black background with white text
- Rounded corners (8px border radius)

#### **SquareTile** (`lib/components/square_tile.dart`)
Social login button component.

**Properties:**
- `imagePath` - Path to social provider logo

---

## Firebase Configuration

### Initialization (`lib/main.dart`)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

### Auth State Management
The app uses `StreamBuilder` to listen to Firebase auth state changes:
- **Logged in** → Shows HomePage
- **Logged out** → Shows AuthPage (login/register)
- **Loading** → Shows CircularProgressIndicator

---

## Color Scheme & Design

**Consistent Design Elements:**
- **Background:** `Colors.grey[300]`
- **Cards/Containers:** White (`Colors.white`)
- **App Bar:** `Colors.grey[900]` with white text
- **Primary Action:** Black buttons with white text
- **Selected Items:** Black highlights
- **Today Marker:** Grey circle
- **Event Markers:** Blue dots
- **Text Colors:** Grey shades for secondary text

**Border Radius:** 8px for all containers and buttons

---

## How to Add Events

To add events to the calendar, modify the `initState()` method in `home_page.dart`:

```dart
@override
void initState() {
  super.initState();
  _selectedDay = _focusedDay;

  // Add events for specific dates
  final today = DateTime.utc(
    _focusedDay.year,
    _focusedDay.month,
    _focusedDay.day,
  );
  _events[today] = ['Practice at 6:30PM - 9PM, GYM'];
  
  // Add more events
  final tomorrow = today.add(Duration(days: 1));
  _events[tomorrow] = ['Game Day - 3PM', 'Team Dinner - 7PM'];
}
```

---

## Authentication Flow

1. User opens app
2. `main.dart` checks Firebase auth state
3. **If not authenticated:**
   - Show AuthPage (defaults to LoginPage)
   - User can toggle to RegisterPage
   - User enters credentials
   - Firebase validates and creates/authenticates user
4. **If authenticated:**
   - Show HomePage with calendar and announcements
   - User can logout via app bar button
5. On logout, automatically returns to LoginPage

---

## Performance Notes

### Text Input Optimization
The text fields include:
- `enableSuggestions` - Optimized based on field type
- `autocorrect` - Disabled for password fields

**Note:** Some text input delay is normal in debug mode. For better performance:
- Run in release mode: `flutter run --release`
- Test on physical devices rather than emulators
- Ensure adequate emulator resources (RAM/CPU)

---

## Future Enhancements

Potential features to implement:
- [ ] Connect announcements to Firebase Firestore
- [ ] Implement actual chat functionality
- [ ] Add calendar event creation/editing
- [ ] Implement search functionality
- [ ] Add user settings page
- [ ] Add profile pictures
- [ ] Push notifications for new announcements
- [ ] Social authentication (Google, Apple)

---

## File Summary

| File | Purpose | Key Features |
|------|---------|--------------|
| `main.dart` | App entry point | Firebase init, auth state management |
| `auth_service.dart` | Authentication logic | Sign in, sign up, sign out methods |
| `login_page.dart` | Login UI | Email/password login form |
| `register_page.dart` | Registration UI | Email/password signup with validation |
| `auth_page.dart` | Auth navigation | Toggles between login/register |
| `home_page.dart` | Main app screen | Calendar, events, announcements, nav bar |
| `my_textfield.dart` | Text input component | Styled text fields |
| `my_button.dart` | Button component | Styled action buttons |

---

## Setup Instructions

1. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

2. **Firebase Setup:**
   - Ensure `google-services.json` (Android) is in `android/app/`
   - Ensure `GoogleService-Info.plist` (iOS) is in `ios/Runner/`
   - Firebase config is in `firebase_options.dart`

3. **Run the App:**
   ```bash
   flutter run
   ```

4. **Build for Release:**
   ```bash
   flutter build apk          # Android
   flutter build ios          # iOS
   ```

---

**Last Updated:** January 13, 2026
**Flutter Version:** Compatible with Flutter 3.10+
**Firebase:** Using FlutterFire packages
