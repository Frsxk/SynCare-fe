# SynCare design direction

Reading this as: a calm clinical follow-up app for Indonesian CHF patients and nurses, in a native
Material 3 clinical language, dial ENERGY 1 / RHYTHM 1 / MOTION 1.

This direction records the shipped design. It answers the antislop R-37 requirement with the
choices the owner approved on 2026-10-23, not with a new style.

## Identity

A calm clinical follow-up companion for CHF patients and their nurses in Indonesia. The app sits
between a hospital discharge and the next contact. It should feel like a clear printed care sheet:
legible, orderly, and free of performance.

## Personality

Direct, quiet, respectful. It states what the server says and never performs certainty. The only
loud moment is a server-issued red flag, and that moment is unmistakable.

## Palette

- Primary: teal `#006B5F`, from the light Material 3 seed.
- Warning: amber `#FFF3D6` surface with `#4A3600` text for the synthetic-demo notice.
- Risk semantics: green, amber, and red tinted surfaces with dark text.
- Neutrals: `#F5F9F7` scaffold, white cards, muted outline tokens.

Risk text pairs measure 7.5:1 to 8.25:1. The warning pair measures 10.47:1. The primary on white
measures 6.43:1. The palette is limited to the brand teal, the warning amber, semantic risk colors,
and neutrals. No gradient, glow, or glass is part of the system.

## Typography

Platform-native sans: Roboto on Android, SF on iOS. This is deliberate. Clinicians and patients
already read these faces, they render at small sizes without a download, and the app must feel like
part of the phone rather than a branded brochure. Weights and line heights carry the hierarchy:
700 for titles, 600 for controls, 1.4 to 1.5 line height for body copy.

## Layout and components

Single-column mobile layout. Content caps at 720 dp on tablets; the role picker caps at 520 dp.
Cards use 16 dp radius, controls 12 dp, dialogs 20 dp, and status chips a full pill. Touch targets
are at least 48 dp. Cards are outlined, not floated; elevation is reserved for dialogs and
snackbars.

## Identity motif

The amber synthetic-demo banner and the risk-tier chip system recur on every screen. They are the
product's safety signature: each screen states its evidence status and its risk language the same
way. This repeated structure is the motif. It is functional, so it does not need decoration.

## Motion

Loading indicators only. No decorative loops, parallax, or entrance choreography. The waiting
screen may show elapsed time because the approval gate is time-bound, but the motion stays quiet.

## Dials

ENERGY 1 / RHYTHM 1 / MOTION 1.

A clinical tool should be quiet. Uniform rhythm is deliberate for scanability. Motion is limited to
progress. A future visual identity can raise these dials, but it must not add urgency the clinical
content does not carry.

## Theme

Light only. The reasons are clinical legibility in bright environments, consistent semantic risk
colors, and a demo that must look the same on every device. A dark mode requires re-testing every
risk and warning pair before it can ship.
