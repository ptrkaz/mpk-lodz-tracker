---
name: Łódź Urban Transit System
colors:
  surface: '#f9f9f9'
  surface-dim: '#dadada'
  surface-bright: '#f9f9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f3f3f3'
  surface-container: '#eeeeee'
  surface-container-high: '#e8e8e8'
  surface-container-highest: '#e2e2e2'
  on-surface: '#1a1c1c'
  on-surface-variant: '#4c4546'
  inverse-surface: '#2f3131'
  inverse-on-surface: '#f1f1f1'
  outline: '#7e7576'
  outline-variant: '#cfc4c5'
  surface-tint: '#5e5e5e'
  primary: '#000000'
  on-primary: '#ffffff'
  primary-container: '#1b1b1b'
  on-primary-container: '#848484'
  inverse-primary: '#c6c6c6'
  secondary: '#00658d'
  on-secondary: '#ffffff'
  secondary-container: '#2fbcff'
  on-secondary-container: '#004867'
  tertiary: '#000000'
  on-tertiary: '#ffffff'
  tertiary-container: '#3e0021'
  on-tertiary-container: '#f81a95'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#e2e2e2'
  primary-fixed-dim: '#c6c6c6'
  on-primary-fixed: '#1b1b1b'
  on-primary-fixed-variant: '#474747'
  secondary-fixed: '#c6e7ff'
  secondary-fixed-dim: '#83cfff'
  on-secondary-fixed: '#001e2e'
  on-secondary-fixed-variant: '#004c6c'
  tertiary-fixed: '#ffd9e4'
  tertiary-fixed-dim: '#ffb0cc'
  on-tertiary-fixed: '#3e0021'
  on-tertiary-fixed-variant: '#8d0051'
  background: '#f9f9f9'
  on-background: '#1a1c1c'
  surface-variant: '#e2e2e2'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  title-sm:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-bold:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  mono-num:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  edge-margin: 16px
  stack-gap: 12px
---

## Brand & Style

The design system is rooted in high-utility Modernism, prioritizing cognitive ease for commuters. It balances the vibrant, CMYK-inspired palette of the City of Łódź with a sophisticated, white-label aesthetic. The brand personality is efficient, reliable, and invisible—letting data take center stage.

By utilizing a "Corporate Modern" approach, the UI avoids the clutter of illustrative elements in favor of rigorous alignment and systematic clarity. The emotional response is one of calm confidence; users should feel that the information is accurate and the interface is an extension of the city's physical infrastructure.

## Colors

The palette is anchored in a high-contrast Neutral base to ensure maximum legibility under varying outdoor lighting conditions. 

- **Primary & Neutrals:** The UI is dominated by pure white (#FFFFFF), off-whites (#F8F9FA), and deep charcoal (#1A1A1A). This creates a "Paper-white" effect that feels professional and clean.
- **Accents (Łódź CMYK):** These are used sparingly as functional signifiers rather than decorative elements. 
- **Functional Mapping:** To ensure rapid identification, **Buses** are mapped to Magenta and **Trams** are mapped to Yellow. Cyan is reserved for interactive states, primary actions, and user-location indicators.
- **Semantic Colors:** Success, Error, and Warning states follow standard UX patterns but are tuned to match the vibrance of the brand palette.

## Typography

This design system utilizes **Inter** exclusively to leverage its exceptional legibility in digital interfaces. 

- **Numerical Clarity:** Since transit apps are time-heavy, use tabular figures (`tnum`) for countdowns and platform numbers to prevent visual jittering during live updates.
- **Hierarchy:** Use font weight (SemiBold/Bold) rather than size increases to denote importance, keeping the UI compact.
- **Micro-copy:** Labels for "Minutes until arrival" should use the `label-bold` style for immediate recognition at a glance.

## Layout & Spacing

The layout follows an **8px grid system** to ensure mathematical harmony across all screen sizes. 

- **Container Strategy:** Use a fluid grid with fixed 16px side margins. 
- **Density:** Transit users require a lot of information in a small space. Use "Compact" vertical spacing (12px) for list items in the schedule view, but "Comfortable" spacing (24px) for the search and landing states.
- **Touch Targets:** All interactive elements must maintain a minimum 44x44pt area, even if the visual asset is smaller.

## Elevation & Depth

To maintain a modern aesthetic, this design system rejects heavy borders and instead uses **Ambient Shadows** and **Tonal Layering**.

- **Level 0 (Base):** The primary background color (White).
- **Level 1 (Cards):** Subtle elevation using a 0px 4px 20px shadow with 5% opacity black. No border.
- **Level 2 (Floating/Modals):** A more pronounced 0px 8px 32px shadow with 10% opacity black.
- **Separation:** Use 1px light gray dividers (#EEEEEE) only when absolutely necessary to separate dense list data; otherwise, prefer white space to define boundaries.

## Shapes

The design system employs a "Rounded" geometry to soften the technical nature of the data. 

- **Standard Radius:** 8px (0.5rem) for cards and primary buttons.
- **Large Radius:** 16px (1rem) for bottom sheets and main container wraps.
- **Interactive Elements:** Use pill-shapes (full rounding) for status chips and tags to distinguish them from structural cards.
- **Iconography:** Icons should feature a 2px stroke with slightly rounded joins to match the UI's radius.

## Components

- **Buttons:** Primary buttons use a solid Cyan or Black fill with white text. Secondary buttons are ghost-style with a subtle gray fill on hover.
- **Transit Chips:** Small, pill-shaped indicators. Tram chips have a Yellow background with Black text. Bus chips have a Magenta background with White text.
- **Search Bar:** A Level 1 elevated surface with a subtle inner 1px border (#E0E0E0) and a soft drop shadow.
- **Route Cards:** Use a vertical "line and dot" metaphor to visualize stops. The line color should match the transit mode (Yellow for Trams).
- **Live Indicators:** A small pulsating dot (Cyan) indicates real-time GPS tracking.
- **Bottom Sheets:** Used for stop details. These should have a "drag handle" and use a 24px corner radius on the top edges.
- **Inputs:** Clean, underlines or subtle boxes. Focus states are indicated by a 2px Cyan glow/shadow rather than a thick border.