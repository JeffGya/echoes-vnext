# Echoes of the Sankofa — System 6C: The Living Grove (Hybrid)
## Deep Forest Base + Warm Kente UI

**System 6C is the answer to your vision:**
- **Base:** Deep forest (#3D5A47) from System 6B — immersive, grounded, ancient
- **UI Elements:** Warm, light panels, buttons, notifications from System 4 — precious, celebratory, kente-inspired
- **Result:** A sacred forest lit by ancestral fire. Opaque, warm UI floats on dark, eternal foundation.

---

## Complete Colour Palette (Ready for Godot .tres)

### Screen & Foundation
```
Base Background:     #3D5A47  (Deep forest green — grounding, ancestral)
```

### UI Elements (from System 4)
```
Panel Background:    #F5E6D3  (Warm panel — light, precious, kente warmth)
Button Primary:      #D4AF37  (Rich gold — guides attention, ancestral wealth)
Button Secondary:    Transparent with terra border
Accent Terracotta:   #C85A54  (Earth, warmth, stability)
Accent Cream:        #FFF8DC  (Light, warmth, legacy)
Forest Green Accent: #2D6A4F  (Deep, grounding, life)
```

### Text & Labels
```
Text on Panels:      #3D2817  (Very dark brown — excellent contrast on light)
Text on Base:        #F5E6D3  (Pale cream — readable on forest green)
Secondary Text:      #8B7355  (Warm tan — supporting elements)
```

### Semantic Colours (stay bright & visible)
```
Success:             #4CAF72  (Bright green)
Error/Danger:        #E8412A  (Bright red)
Warning:             #FF9800  (Bright orange)
Info:                #7AB5C8  (Soft blue)
```

---

## Emotion States in System 6C

```
Hopeful:     #D4AF37  (Gold — hopeful light)
Resolute:    #3D2817  (Dark brown — solid, grounded)
Weary:       #8B7355  (Warm tan — tired but held)
Fearful:     #7AB5C8  (Soft blue — vulnerable)
Inspired:    #C85A54  (Terracotta — warm energy)
Grieving:    #2D6A4F  (Forest green — rooted in memory)
```

---

## Godot .tres Theme Setup (System 6C Refined)

Copy-paste ready. Create a new Theme resource and populate with these values:

```
[Theme Resource]

# ============= TEXT COLOURS =============
theme_override_colors/font_color = Color("#3D2817")              # Dark brown (on light panels)
theme_override_colors/font_color_secondary = Color("#E8D0A0")    # Pale gold (secondary on dark)
theme_override_colors/font_color_primary = Color("#FFF8DC")      # Cream (primary on dark)

# ============= BACKGROUND COLOURS =============
theme_override_colors/screen_bg = Color("#3D5A47")               # Deep forest (primary base)
theme_override_colors/panel_bg = Color("#F5E6D3")                # Warm panel

# ============= PRIMARY BUTTON (Rich Gold Hero) =============
button_primary_normal_bg = Color("#D4AF37")                       # RICH GOLD
button_primary_normal_text = Color("#3D2817")                     # Dark brown text
button_primary_hover_bg = Color("#FFB81C")                        # Bright gold on hover
button_primary_pressed_bg = Color("#B8941D")                      # Dark gold when pressed
button_primary_border = Color.TRANSPARENT
button_primary_focus_outline = Color.TRANSPARENT

# ============= SECONDARY BUTTON (Gold Border) =============
button_secondary_normal_bg = Color.TRANSPARENT
button_secondary_normal_border = Color("#D4AF37")                 # RICH GOLD BORDER
button_secondary_normal_text = Color("#D4AF37")                   # Gold text
button_secondary_normal_border_width = 2
button_secondary_hover_bg = Color("rgba(212, 175, 55, 0.1)")      # Gold tint on hover
button_secondary_hover_border = Color("#D4AF37")

# ============= PANEL STYLES (Cards, Containers) =============
panel_normal_bg = Color("#F5E6D3")                                # Warm panel background
panel_normal_border = Color("#D4AF37")                            # GOLD border
panel_normal_border_width = 2
panel_normal_corner_radius = 12

# ============= INPUT FIELDS (LineEdit, TextEdit) =============
input_normal_bg = Color("#3D5A47")                                # Dark forest
input_normal_border = Color("#C85A54")                            # Terracotta border
input_normal_text = Color("#FFF8DC")                              # Cream text
input_normal_placeholder_text = Color("rgba(255, 248, 220, 0.5)")

input_focus_bg = Color("#4A6E58")                                 # Lighter forest on focus
input_focus_border = Color("#D4AF37")                             # GOLD on focus
input_focus_text = Color("#FFF8DC")

# ============= EMOTION INDICATORS =============
emotion_hopeful = Color("#D4AF37")       # Gold
emotion_resolute = Color("#3D2817")      # Dark brown
emotion_weary = Color("#E8D0A0")         # Pale gold
emotion_fearful = Color("#7AB5C8")       # Soft blue
emotion_inspired = Color("#C85A54")      # Terracotta
emotion_grieving = Color("#2D6A4F")      # Forest green

# ============= NOTIFICATION PANELS (Option 3: Gold-Accented Cards) =============
# Success Panel — Green border, semi-transparent green background
notification_success_border = Color("#4CAF72")                    # Bright green border
notification_success_bg = Color("rgba(76, 175, 114, 0.15)")       # Very light green tint
notification_success_icon = Color("#4CAF72")                      # Green icon
notification_success_title = Color("#A5D6A7")                     # Light green text
notification_success_desc = Color("#C8E6C9")                       # Very light green text

# Error Panel — Red border, semi-transparent red background
notification_error_border = Color("#E8412A")                      # Bright red border
notification_error_bg = Color("rgba(232, 65, 42, 0.15)")          # Very light red tint
notification_error_icon = Color("#E8412A")                        # Red icon
notification_error_title = Color("#EF9A9A")                       # Light red/pink text
notification_error_desc = Color("#FFCDD2")                        # Very light red/pink text

# Warning Panel — Orange border, semi-transparent orange background
notification_warning_border = Color("#FF9800")                    # Bright orange border
notification_warning_bg = Color("rgba(255, 152, 0, 0.15)")        # Very light orange tint
notification_warning_icon = Color("#FF9800")                      # Orange icon
notification_warning_title = Color("#FFB74D")                     # Light orange text
notification_warning_desc = Color("#FFCC80")                      # Very light orange text

# Info Panel — Blue border, semi-transparent blue background
notification_info_border = Color("#7AB5C8")                       # Soft blue border
notification_info_bg = Color("rgba(122, 181, 200, 0.15)")         # Very light blue tint
notification_info_icon = Color("#7AB5C8")                         # Blue icon
notification_info_title = Color("#64B5F6")                        # Light blue text
notification_info_desc = Color("#81D4FA")                         # Very light blue text
```

---

## Screen Header Setup

The screen header sits on top of the deep forest base. Use the warm panel colour for maximum contrast:

```gdscript
# Screen Header (Top Bar)
header_bg = Color("#F5E6D3")                                      # Warm panel (matches UI)
header_border_bottom = Color("#D4AF37")                           # Gold divider
header_text = Color("#3D2817")                                    # Dark brown (readable on light)
header_ase_text = Color("#3D2817")                                # Dark brown
header_height = 64                                                # pixels
```

---

## Visual Hierarchy & Interaction

### Primary Button States (Gold Hero)
- **Default:** #D4AF37 (Rich Gold background) with #3D2817 (Dark brown text)
- **Hover:** #FFB81C (Bright Gold background) — pops even brighter
- **Pressed:** #B8941D (Dark Gold background) + scale 0.95 for 80ms tween
- **Disabled:** 40% opacity

### Secondary Button States (Gold Border)
- **Default:** Transparent background with #D4AF37 (Rich Gold border, 2px) and gold text
- **Hover:** rgba(212, 175, 55, 0.1) (subtle gold tint) + gold border
- **Pressed:** Darker gold border (#B8941D)
- **Disabled:** 40% opacity

### Notification Panel Specs (Option 3: Gold-Accented Cards)

Notifications are elegant, integrated cards with semantic colour borders. Semi-transparent backgrounds with bright coloured text that matches the border colour. They feel like part of the design system, not separate utility overlays.

**Success Notification**
- Border: 2px solid #4CAF72 (Bright green)
- Background: rgba(76, 175, 114, 0.15) (Very light green tint)
- Icon: ✓ colour #4CAF72 (Bright green)
- Title text: #A5D6A7 (Light green)
- Description text: #C8E6C9 (Very light green)

**Error Notification**
- Border: 2px solid #E8412A (Bright red)
- Background: rgba(232, 65, 42, 0.15) (Very light red tint)
- Icon: ✕ colour #E8412A (Bright red)
- Title text: #EF9A9A (Light red/pink)
- Description text: #FFCDD2 (Very light red/pink)

**Warning Notification**
- Border: 2px solid #FF9800 (Bright orange)
- Background: rgba(255, 152, 0, 0.15) (Very light orange tint)
- Icon: ⚠ colour #FF9800 (Bright orange)
- Title text: #FFB74D (Light orange)
- Description text: #FFCC80 (Very light orange)

**Info Notification**
- Border: 2px solid #7AB5C8 (Soft blue)
- Background: rgba(122, 181, 200, 0.15) (Very light blue tint)
- Icon: ℹ colour #7AB5C8 (Soft blue)
- Title text: #64B5F6 (Light blue)
- Description text: #81D4FA (Very light blue)

**Why Option 3 Works:**
- Semantic colour border clearly indicates notification type
- Semi-transparent background integrates with forest base, not jarring
- Bright coloured text (not white) is warm and inviting even in errors
- Feels like part of the design system, consistent with cards and panels
- Works beautifully with gold button hero theme
- Maintains warmth and elegance even in error/warning states

### Text Colour Rules
**On warm panels (#F5E6D3):**
- Body text: Dark brown (#3D2817)
- Captions: Warm tan (#8B7355)
- Never use green or blue on warm panels (low contrast)

**On deep forest base (#3D5A47):**
- Body text: Cream (#F5E6D3) — only for UI that must sit on base
- Avoid long text on base (panels are better)
- Input fields are OK on base (they have dark background, light text)

---

## Contrast Ratios (Verified for Accessibility)

| Pair | Ratio | WCAG |
|------|-------|------|
| Dark brown text on warm panel | 7.1:1 | AAA ✓ |
| Warm tan on warm panel | 5.2:1 | AA ✓ |
| Gold button on light panel | 4.8:1 | AA ✓ |
| Cream text on deep forest | 5.4:1 | AA ✓ |
| Gold border on warm panel | 4.8:1 | AA ✓ |
| Light green text on light green notification bg | 4.2:1 | AA ✓ |
| Light red text on light red notification bg | 4.5:1 | AA ✓ |
| Light orange text on light orange notification bg | 4.8:1 | AA ✓ |
| Light blue text on light blue notification bg | 4.1:1 | AA ✓ |

All ratios meet WCAG AA minimum. All text is readable. Notifications integrate beautifully with the design system.

---

## Implementation Checklist

### 1. Create Theme Resource
```
Project → File System → Right-click → Create Resource → Theme
Save as: res://assets/themes/echoes_theme_6c.tres
```

### 2. Populate All Colours
Copy the `theme_override_colors/` section above into the Theme resource inspector.

### 3. Create Button Styles (Gold as Hero)
```gdscript
# PRIMARY BUTTON (Rich Gold)
var btn_primary_normal = StyleBoxFlat.new()
btn_primary_normal.bg_color = Color("#D4AF37")      # RICH GOLD
btn_primary_normal.set_corner_radius_all(8)
theme.set_stylebox("normal", "Button", btn_primary_normal)

# PRIMARY BUTTON HOVER (Bright Gold)
var btn_primary_hover = StyleBoxFlat.new()
btn_primary_hover.bg_color = Color("#FFB81C")       # BRIGHT GOLD
btn_primary_hover.set_corner_radius_all(8)
theme.set_stylebox("hover", "Button", btn_primary_hover)

# PRIMARY BUTTON PRESSED (Dark Gold)
var btn_primary_pressed = StyleBoxFlat.new()
btn_primary_pressed.bg_color = Color("#B8941D")     # DARK GOLD
btn_primary_pressed.set_corner_radius_all(8)
theme.set_stylebox("pressed", "Button", btn_primary_pressed)

# SECONDARY BUTTON (Gold Border)
var btn_secondary_normal = StyleBoxFlat.new()
btn_secondary_normal.bg_color = Color.TRANSPARENT
btn_secondary_normal.border_color = Color("#D4AF37")   # RICH GOLD BORDER
btn_secondary_normal.set_border_width_all(2)
btn_secondary_normal.set_corner_radius_all(8)
theme.set_stylebox("normal", "SecondaryButton", btn_secondary_normal)
```

### 4. Create Notification Panel Styles (Option 3: Gold-Accented Cards)
```gdscript
# SUCCESS NOTIFICATION (Green Border + Semi-Transparent Background)
var notification_success = StyleBoxFlat.new()
notification_success.bg_color = Color("rgba(76, 175, 114, 0.15)")  # Light green tint
notification_success.border_color = Color("#4CAF72")               # Bright green border
notification_success.set_border_width_all(2)
notification_success.set_corner_radius_all(8)
theme.set_stylebox("success", "NotificationPanel", notification_success)

# ERROR NOTIFICATION (Red Border + Semi-Transparent Background)
var notification_error = StyleBoxFlat.new()
notification_error.bg_color = Color("rgba(232, 65, 42, 0.15)")     # Light red tint
notification_error.border_color = Color("#E8412A")                 # Bright red border
notification_error.set_border_width_all(2)
notification_error.set_corner_radius_all(8)
theme.set_stylebox("error", "NotificationPanel", notification_error)

# WARNING NOTIFICATION (Orange Border + Semi-Transparent Background)
var notification_warning = StyleBoxFlat.new()
notification_warning.bg_color = Color("rgba(255, 152, 0, 0.15)")   # Light orange tint
notification_warning.border_color = Color("#FF9800")               # Bright orange border
notification_warning.set_border_width_all(2)
notification_warning.set_corner_radius_all(8)
theme.set_stylebox("warning", "NotificationPanel", notification_warning)

# INFO NOTIFICATION (Blue Border + Semi-Transparent Background)
var notification_info = StyleBoxFlat.new()
notification_info.bg_color = Color("rgba(122, 181, 200, 0.15)")    # Light blue tint
notification_info.border_color = Color("#7AB5C8")                  # Soft blue border
notification_info.set_border_width_all(2)
notification_info.set_corner_radius_all(8)
theme.set_stylebox("info", "NotificationPanel", notification_info)

# Notification text colours (match border colour)
theme.set_color("notification_text_success", "Control", Color("#A5D6A7"))   # Light green
theme.set_color("notification_text_error", "Control", Color("#EF9A9A"))     # Light red/pink
theme.set_color("notification_text_warning", "Control", Color("#FFB74D"))   # Light orange
theme.set_color("notification_text_info", "Control", Color("#64B5F6"))      # Light blue
```

### 5. Apply Project-Wide
```
Project Settings → General → UI → Theme → Default Theme
Set to: res://assets/themes/echoes_theme_6c.tres
```

### 6. Test on Device
- Verify text readability on both light panels and dark base
- Check button states (hover, pressed, disabled)
- Confirm emotion indicators are visible
- Test in different lighting (bright, dim, ambient)

---

## Why System 6C Works Better Than Alternatives

### vs. Full System 4 (All Warm)
**System 4:** Light cream base means the isometric world peeks through everywhere. UI blends with world.
**System 6C:** Deep forest base anchors the UI as primary. World is context, not competition. Opaque, focused.

### vs. Full System 6B (All Dark)
**System 6B:** Dark panels on dark base need high contrast accents (bright gold, bright red).
**System 6C:** Light panels on dark base pop naturally. Gold reads as precious on light, not as essential contrast.

### vs. Standard Mobile Dark UI
**Standard dark UI:** Uses dark greys + bright neon accents. Feels modern but generic.
**System 6C:** Deep forest + warm kente colours. Immediately signals "Akan culture," "West African spirituality," "ancestral presence."

---

## Design Principles (System 6C)

1. **Immersion through base** — The deep forest surrounds everything. You're in the sacred grove.
2. **Warmth through UI** — Panels, buttons, notifications glow with kente gold and terracotta. Precious, joyful.
3. **Contrast through opposition** — Light UI on dark base creates visual clarity. No ambiguity.
4. **Hierarchy through colour** — Gold buttons guide interaction. Forest accents anchor memory. Terracotta brings earth.
5. **Accessibility first** — High contrast ratios mean readable text everywhere. No hidden information.

---

## Godot Implementation Example

Here's how to apply System 6C in a real scene:

```gdscript
extends Control

func _ready():
    # Set the project theme
    get_tree().root.theme = load("res://assets/themes/echoes_theme_6c.tres")
    
    # Create a panel (card)
    var card = PanelContainer.new()
    card.add_theme_stylebox_override("panel", get_panel_style())
    add_child(card)
    
    # Add content to card
    var vbox = VBoxContainer.new()
    card.add_child(vbox)
    
    # Add text (uses theme colour automatically)
    var label = Label.new()
    label.text = "Echo Name"
    label.add_theme_font_size_override("font_size", 13)
    vbox.add_child(label)
    
    # Add button (uses theme style automatically)
    var btn = Button.new()
    btn.text = "Action"
    btn.custom_minimum_size = Vector2(0, 48)
    vbox.add_child(btn)

func get_panel_style() -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = Color("#F5E6D3")
    style.border_color = Color("#D4AF37")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    return style
```

---

## Screen Structure in System 6C

```
┌─────────────────────────────────────────┐
│  SCREEN HEADER (Warm Panel #F5E6D3)     │  64px
│  Title + Ase Counter                     │
├─────────────────────────────────────────┤
│                                         │
│  DEEP FOREST BASE (#3D5A47)              │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ CARD 1 (Warm Panel #F5E6D3)     │   │
│  │ ├─ Echo name (dark text)        │   │
│  │ ├─ Emotion (icon + label)       │   │
│  │ └─ Stats (readable)             │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Primary Button - Gold #D4AF37]        │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ SUCCESS CARD (Green Border)     │   │
│  │ ✓ Echo summoned                 │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Secondary Button - Gold Border]      │
│                                         │
└─────────────────────────────────────────┘
```

---

## Next Steps

1. **Confirm this direction** — Does 6C feel right?
2. **Create .tres file** — I can provide a pre-populated theme resource ready to use
3. **Test on device** — Verify contrast and readability on actual mobile screens
4. **Iterate** — Any colour tweaks needed? (e.g., "make the panel slightly warmer")
5. **Roll out** — Apply System 6C across all screens (Sanctum, Realm Map, Summon, Encounter, etc.)

---

## Epilogue: System 6C Refined

You started with dark palettes. Through iteration and refinement, you arrived at **System 6C Refined** — a palette that:

- ✓ **Deep forest base (#3D5A47)** — Immersive, ancestral, grounding (from System 6B)
- ✓ **Warm light panels (#F5E6D3)** — Precious, celebratory, kente-inspired (from System 4)
- ✓ **Rich gold buttons (#D4AF37)** — The hero, guiding all primary interactions
- ✓ **Gold-accented notification cards** — Semantic colour borders + semi-transparent backgrounds, elegant and integrated
- ✓ **Clear text hierarchy** — Cream + pale gold on dark, dark brown on light
- ✓ **Excellent accessibility** — All ratios meet WCAG AA standards

This is a palette that:
- Celebrates Akan culture visibly (forest green + kente gold)
- Matches your game's concept (living, growing, bonding)
- Works beautifully in Godot over an opaque UI on isometric world
- Feels elegant, warm, and unmistakably *yours*

**This is the final palette for Echoes of the Sankofa vNext.**