---
name: Mess Management System
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#444653'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#757684'
  outline-variant: '#c4c5d5'
  surface-tint: '#3755c3'
  primary: '#00288e'
  on-primary: '#ffffff'
  primary-container: '#1e40af'
  on-primary-container: '#a8b8ff'
  inverse-primary: '#b8c4ff'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#6cf8bb'
  on-secondary-container: '#00714d'
  tertiary: '#4c2e00'
  on-tertiary: '#ffffff'
  tertiary-container: '#6b4200'
  on-tertiary-container: '#ffa929'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dde1ff'
  primary-fixed-dim: '#b8c4ff'
  on-primary-fixed: '#001453'
  on-primary-fixed-variant: '#173bab'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  xs: 0.25rem
  sm: 0.5rem
  md: 1rem
  lg: 1.5rem
  xl: 2.5rem
  container-max: 1280px
  gutter: 1.5rem
  margin-mobile: 1rem
---

## Brand & Style

The design system is anchored in the principles of **Corporate Modernism**, prioritizing clarity, utility, and institutional trust. Since "Mess Management" involves shared finances, food logistics, and community living, the interface must feel objective and reliable.

The brand personality is "The Efficient Steward"—organized, transparent, and dependable. The aesthetic leverages a functional minimalist approach, using generous whitespace to de-clutter dense financial ledgers and meal schedules. By focusing on a structured information hierarchy and a calm professional palette, the design system transforms complex group accounting into an effortless, scannable experience.

## Colors

The color strategy uses a high-contrast functional approach to guide user behavior and communicate status instantly.

*   **Trust Blue (#1E40AF):** Applied to primary actions, navigation headers, and administrative identifiers. It establishes the "source of truth."
*   **Success Green (#10B981):** Reserved strictly for positive financial delta, completed payments, and "Paid" status indicators.
*   **Alert Orange (#F59E0B):** Used for attention-requiring items like pending payments, low balance warnings, or unconfirmed meal tallies.
*   **Neutrals:** A range of Slate grays (#F8FAFC to #0F172A) provides the structural framework, ensuring that the primary and semantic colors stand out against a clean background.

## Typography

The design system utilizes **Inter** exclusively to leverage its exceptional legibility in data-heavy environments. The typographic scale is optimized for numerical clarity, using tabular lining figures where possible to ensure that expense columns align perfectly.

Headlines use a tighter letter-spacing and heavier weights to provide strong visual anchors. Body text is set with generous line-height to maintain readability during long sessions of auditing expenses. Labels are frequently used in uppercase with medium weights to distinguish metadata from primary content.

## Layout & Spacing

This design system employs a **12-column fixed grid** for desktop environments to maintain tight control over financial data presentation, transitioning to a single-column fluid layout for mobile devices.

The spacing rhythm is based on a 4px baseline grid. 
*   **Desktop:** 1.5rem (24px) gutters and margins to give "breathing room" to complex tables.
*   **Mobile:** 1rem (16px) side margins to maximize screen real estate for transaction lists.
*   **Vertical Spacing:** Elements are grouped using proximity; related items (like an avatar and a name) use `sm` spacing, while distinct sections use `xl` spacing.

## Elevation & Depth

To maintain a clean and professional look, depth is achieved through **Ambient Shadows** and subtle tonal shifts rather than heavy borders.

*   **Level 0 (Base):** The main background uses a soft off-white (#F8FAFC).
*   **Level 1 (Cards):** All primary content containers (Expense Cards, User Profiles) use a pure white surface with a very soft, diffused shadow (0px 4px 12px rgba(30, 64, 175, 0.05)). This subtle blue tint in the shadow reinforces the brand color without being overt.
*   **Level 2 (Interactive):** Hover states for buttons or active cards use a slightly more pronounced shadow to indicate lift.
*   **Level 3 (Overlays):** Modals and dropdowns use a sharp, high-contrast shadow to separate them from the workspace.

## Shapes

The design system uses a **Soft (1)** roundedness profile. This balance provides a modern feel while retaining the structure necessary for a financial tool.

*   **Components (Inputs, Buttons):** 0.25rem (4px) corner radius for a precise, geometric look.
*   **Containers (Cards, Modals):** 0.5rem (8px) corner radius to soften the layout and make it feel approachable.
*   **Avatars:** Always circular (100% radius) to contrast with the predominantly rectangular layout, making individual users easy to spot in lists.

## Components

### Expense Cards
Cards are the primary data container. They feature a three-section layout: a left-aligned icon/avatar indicating the category, a central section for the title and date, and a right-aligned bold numerical value.

### Status Badges
*   **Paid:** Success Green background (10% opacity) with dark green text.
*   **Pending:** Alert Orange background (10% opacity) with dark orange text.
*   **Admin:** Trust Blue background (solid) with white text to indicate authority.

### Buttons
*   **Primary:** Solid Trust Blue with white text.
*   **Secondary:** Ghost style with Trust Blue borders and text.
*   **Success:** Solid Success Green for "Settle Up" or "Confirm Payment" actions.

### User Avatars
Avatars include a high-quality image with a 2px white border and a soft shadow. If no image is present, use a Trust Blue background with Inter-bold initials.

### Inputs
Input fields use a subtle 1px border (#E2E8F0) that thickens and changes to Trust Blue on focus. Labels are always positioned above the input for maximum clarity.

### Financial Summary Chips
Small, rounded-pill components used at the top of pages to show "Total Spent," "Your Share," and "Balance" using the semantic color palette.