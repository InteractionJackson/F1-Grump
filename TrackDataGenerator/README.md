# F1 Track Data Generator

This tool automatically generates perfect track outlines for all F1 circuits by collecting telemetry data from F1 24/F1 23.

## 🎯 Purpose

Instead of users having to record tracks manually, this pre-generates all track data so the F1 Grump app works instantly with perfect track layouts for all circuits.

## 🚀 Usage

### Step 1: Collect Telemetry Data

1. **Enable UDP Telemetry in F1 24:**
   - Settings → Telemetry Settings
   - UDP Telemetry: ON
   - UDP IP: 127.0.0.1
   - UDP Port: 20777
   - UDP Send Rate: 60Hz
   - UDP Format: 2021

2. **Start Data Collection:**
   ```bash
   cd TrackDataGenerator
   swift run TrackDataGenerator --collect
   ```

3. **Drive All Tracks:**
   - Go to Time Trial mode
   - For each F1 circuit, drive 2-3 clean laps
   - The tool will automatically detect track changes
   - Raw telemetry data is saved to `TrackData/`

### Step 2: Generate Track Outlines

```bash
swift run TrackDataGenerator --generate
```

This processes all collected raw data and creates clean track outlines.

### Step 3: Export for App

```bash
swift run TrackDataGenerator --export
```

This creates:
- `PrebuiltTrackData.swift` - Swift file to embed in F1 Grump app
- `all_tracks.json` - JSON data for runtime loading

## 📊 F1 2024 Tracks to Collect

The tool will automatically collect data for all F1 circuits:

**Main Calendar (24 tracks):**
- 🇧🇭 Bahrain (Sakhir)
- 🇸🇦 Saudi Arabia (Jeddah)
- 🇦🇺 Australia (Melbourne)
- 🇯🇵 Japan (Suzuka)
- 🇨🇳 China (Shanghai)
- 🇺🇸 Miami
- 🇮🇹 Emilia Romagna (Imola)
- 🇲🇨 Monaco
- 🇪🇸 Spain (Barcelona)
- 🇨🇦 Canada (Montreal)
- 🇦🇹 Austria (Red Bull Ring)
- 🇬🇧 Great Britain (Silverstone)
- 🇭🇺 Hungary (Hungaroring)
- 🇧🇪 Belgium (Spa)
- 🇳🇱 Netherlands (Zandvoort)
- 🇮🇹 Italy (Monza)
- 🇸🇬 Singapore
- 🇺🇸 United States (COTA)
- 🇲🇽 Mexico
- 🇧🇷 Brazil (Interlagos)
- 🇺🇸 Las Vegas
- 🇶🇦 Qatar (Lusail)
- 🇦🇪 Abu Dhabi (Yas Marina)

**Legacy/Additional:**
- Portugal (Portimao)
- Turkey (Istanbul Park)
- Various short circuits

## 🔧 How It Works

1. **Telemetry Collection:**
   - Listens for F1 UDP telemetry packets
   - Extracts world position (X, Z) coordinates for all cars
   - Automatically detects track changes via session packets
   - Stores raw position data per track

2. **Outline Generation:**
   - Processes thousands of position points per track
   - Removes statistical outliers
   - Samples points to create ~80 point outline
   - Sorts points by angle from center (creates track shape)
   - Calculates bounds and aspect ratios

3. **App Integration:**
   - Generates Swift code with embedded track data
   - Creates normalized coordinate system (0-1 range)
   - Preserves original world bounds for car position mapping

## 📁 Output Structure

```
TrackData/
├── Bahrain_raw.json           # Raw telemetry points
├── Bahrain_outline.json       # Processed track outline
├── Silverstone_raw.json
├── Silverstone_outline.json
├── ...
└── all_tracks.json           # All tracks combined

../F1 Grump/Sources/
└── PrebuiltTrackData.swift   # Generated Swift code
```

## 🎮 Integration with F1 Grump

Once generated, the track data is embedded directly into the F1 Grump app:

```swift
// Instant track loading - no user recording needed!
if let prebuiltTrack = PrebuiltTrackData.tracks[trackName] {
    trackOutlinePoints = prebuiltTrack.points
    isTrackLearned = true
}
```

## ✨ Benefits

- **Zero Setup:** Users get perfect tracks instantly
- **Professional Quality:** Clean, accurate track outlines
- **Complete Coverage:** All F1 circuits included
- **Consistent Experience:** Same quality across all tracks
- **No App Freezing:** No real-time learning needed
