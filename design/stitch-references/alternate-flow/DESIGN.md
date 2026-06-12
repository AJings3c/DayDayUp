---
name: DayDayUp
colors:
  surface: '#f7f9ff'
  surface-dim: '#cfdbea'
  surface-bright: '#f7f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#edf4ff'
  surface-container: '#e3efff'
  surface-container-high: '#dde9f9'
  surface-container-highest: '#d7e4f3'
  on-surface: '#111d27'
  on-surface-variant: '#424750'
  inverse-surface: '#26323d'
  inverse-on-surface: '#e8f2ff'
  outline: '#727781'
  outline-variant: '#c2c6d1'
  surface-tint: '#2e6098'
  primary: '#22568e'
  on-primary: '#ffffff'
  primary-container: '#3f6fa8'
  on-primary-container: '#e9f0ff'
  inverse-primary: '#a3c9ff'
  secondary: '#48607d'
  on-secondary: '#ffffff'
  secondary-container: '#c3dcff'
  on-secondary-container: '#48617e'
  tertiary: '#844401'
  on-tertiary: '#ffffff'
  tertiary-container: '#a25b1b'
  on-tertiary-container: '#ffede2'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d3e4ff'
  primary-fixed-dim: '#a3c9ff'
  on-primary-fixed: '#001c38'
  on-primary-fixed-variant: '#0b487f'
  secondary-fixed: '#d1e4ff'
  secondary-fixed-dim: '#afc9ea'
  on-secondary-fixed: '#001d36'
  on-secondary-fixed-variant: '#304865'
  tertiary-fixed: '#ffdcc4'
  tertiary-fixed-dim: '#ffb781'
  on-tertiary-fixed: '#301400'
  on-tertiary-fixed-variant: '#703800'
  background: '#f7f9ff'
  on-background: '#111d27'
  surface-variant: '#d7e4f3'
  surface-mist: '#F6F8FB'
  surface-glass: '#EEF3F8'
  surface-selected: '#E8F0FA'
  success-pine: '#247C5E'
  warning-amber: '#B46919'
  danger-restrained: '#B54848'
  recovered-purple: '#7A5CCF'
  ink-black: '#15202B'
  mist-line: '#D8E0EA'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.01em
  title-sm:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  label-xs:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  metric-xl:
    fontFamily: JetBrains Mono
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.02em
  metric-xl-mobile:
    fontFamily: JetBrains Mono
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system is built upon the "Squirrel’s Granary" metaphor: a philosophy of persistent, disciplined accumulation and meticulous preparation. It targets high-performance learners—specifically those pivoting into AI engineering—who require a tool that functions as a "Learning Command Center."

The visual style is **Corporate / Modern** with a distinct **macOS Native** soul. It prioritizes utility and clarity over decorative flair, utilizing a "Liquid Glass" approach where translucency and depth are functional tools for hierarchy rather than aesthetic extras. The emotional response is one of calm focus, professional reliability, and quiet encouragement. It avoids the gamified anxiety of "streaks" in favor of the sincere satisfaction of a task well-recorded and a winter's worth of knowledge stored.

**Key Principles:**
- **Native Fidelity:** Adheres to Apple’s Human Interface Guidelines (HIG) to feel like a first-party utility.
- **Restrained Chrome:** Color is a surgical tool used to highlight risk and success, not to fill space.
- **Action-Oriented Depth:** Layers are used to bring the "Next Action" to the foreground while tucking historical data into the background.

## Colors

The palette uses a **Restrained Priority** strategy. Most of the interface remains in the "Cold Mist" range (neutrals and whites), allowing functional colors to command immediate attention.

- **Primary (Perception Blue):** Reserved for interactive elements, primary buttons, and active focus states.
- **Secondary (Midnight Blue):** Used for high-weight metrics and critical data points where visual gravity is required.
- **Tertiary (Squirrel Copper):** A warm accent used sparingly for brand moments, rewards, and the "Squirrel" mascot to inject a human touch into the technical environment.
- **Status System:** Follows a specific semantic hierarchy:
    - **Danger (#B54848):** Highest priority. Overdue or high-risk items.
    - **Recovered (#7A5CCF):** A unique state for tasks completed after their deadline, acknowledging persistence over perfection.
    - **Success (#247C5E):** Healthy rhythm and on-time completion.
    - **Warning (#B46919):** Approaching deadlines.

## Typography

The typography system mirrors the macOS environment, optimized for readability and data density. 

- **SF Pro Substitute:** In this design system, **Inter** is utilized for its exceptional legibility and neutral, systematic tone that matches the SF Pro aesthetic.
- **Metric reserved:** **JetBrains Mono** is used exclusively for timers, scores, and completion rates to ensure numerical alignment in dashboards and rhythmic consistency.
- **Scale:**
    - **Display/Headline:** For page titles and large dashboard headers. Use `700` weight for maximum emphasis.
    - **Title:** The standard size for task names and list items (17px), providing a native macOS "feel."
    - **Body:** Set at 14px for descriptions and notes, following a strict 65-75 character width rule for optimal focus.
    - **Metrics:** High-contrast monospaced levels for the learning "Execution Score" and countdowns.

## Layout & Spacing

The system employs a **Fixed Grid** model for the desktop dashboard to maintain the "Command Center" feel, transitioning to a fluid layout for mobile.

- **Grid:** A 12-column grid is used for the desktop dashboard with 16px gutters. Modules (Task List, Radar Chart, Timer) should span 4, 6, or 12 columns.
- **Rhythm:** A 4px/8px baseline rhythm governs all internal spacing.
- **Responsive Behavior:**
    - **Desktop (1024px+):** Three-pane layout (Sidebar | Main Task List | Detail/Metric Inspector).
    - **Tablet (768px - 1023px):** Sidebar collapses into a hamburger or bottom bar; Detail Inspector becomes an overlay.
    - **Mobile (<768px):** Single column flow. Margins reduce to 16px. Typography scales down (Metrics specifically).

## Elevation & Depth

Depth is conveyed through **Liquid Glass** and **Tonal Layering** rather than traditional drop shadows.

- **Base Layer:** The "Pure White Workbench" (#FFFFFF) serves as the primary canvas for content creation.
- **Surface Layer:** "Cold Mist" (#F6F8FB) panels distinguish different functional blocks on the dashboard.
- **Glass Layer:** Sidebars and toolbars use the "Surface Glass" (#EEF3F8) with a background blur (15px to 25px) to provide a sense of place and native macOS translucency.
- **Functional Shadows:** Only used for "floating" elements like context menus, popovers, or active task cards during a drag-and-drop. Use a very soft, diffused shadow: `0 4px 12px rgba(21, 32, 43, 0.08)`.
- **Focus States:** High-visibility "Perception Blue" focus rings (2px offset) for accessibility.

## Shapes

The shape language is **Rounded**, balancing professional structure with the approachability of the "Squirrel" brand.

- **Standard (md - 8px):** The default for buttons, task containers, and input fields.
- **Small (sm - 6px):** Used for nested elements like internal tags or small status indicators.
- **Large (lg - 12px):** Used for the primary dashboard modules and background cards to create a softer, more contained environment.
- **Pill (999px):** Exclusively for "Score Chips" and "Status Tags" to make them feel like distinct, touchable objects.

## Components

- **Buttons:** 
    - *Primary:* Perception Blue fill with white text; 8px radius. 
    - *Secondary:* Cold Mist fill with Ink Black text. No border.
- **Task Rows:** 
    - Use "Surface Selected" (#E8F0FA) for the active task. 
    - Indicators for status (Green/Red/Purple) should appear as a 4px vertical bar on the left edge or a pill tag on the right.
- **Score Chips:** Utilize Midnight Blue background with monospaced text to emphasize the "High-weight" nature of the execution score.
- **Input Fields:** 1px "Mist Line" border. On focus, the border transitions to Perception Blue with a soft outer glow.
- **Radar Chart:** Should be rendered with low-opacity fills of Perception Blue, with axes in Mist Line.
- **The "Squirrel" Mascot:** Appears in "Empty States" or as a small animated mark next to the "Start Training" button. 
- **Feedback Toast:** When a task is completed, a non-intrusive toast appears: *"Task complete, time to eat!"* accompanied by the Squirrel Copper accent color.