# JuniorGlobe App Review Follow-up

## Recommended App Store Connect changes

### Fastest path for the current rejected build

- Set `Age Assurance` to `None`.
- If you want the lowest review risk for version `1.0 (2)`, also set `Parental Controls` to `None`.

Use this if you do not want to submit a new binary just for the parent-control flow.

### Stronger path with a new binary

- Set `Age Assurance` to `None`.
- Keep `Parental Controls` only if you resubmit a new build that includes the strengthened `Parent Lock` flow.

The updated app now requires `Parent Lock` before:

- viewing or buying subscription plans
- restoring App Store purchases
- opening the `Parent Weekly Report`
- opening parent support email and external legal/privacy links

The unlock flow first tries iOS device-owner authentication and falls back to the in-app parent math challenge only when device authentication is unavailable.

## Reply Template: Metadata Only

```text
Hello App Review Team,

Thank you for the review.

We updated the Age Rating metadata in App Store Connect to match the current app behavior. The app does not provide in-app age assurance, and we updated the In-App Controls selections accordingly.

Please continue the review when convenient.

Best regards,
JuniorGlobe Developer
```

## Reply Template: New Build With Parent Lock

```text
Hello App Review Team,

Thank you for the review.

We updated JuniorGlobe to make the parent control easier to find and to apply it consistently across parent-only actions.

How to locate it in the new build:
1. Open JuniorGlobe.
2. Tap the Settings icon in the top-right corner.
3. In the Subscription section, open Parent Lock.

Parent Lock is now required before:
- viewing or purchasing subscription plans
- restoring purchases
- opening the Parent Weekly Report
- opening parent support email or external legal/privacy links

The app first attempts iOS device-owner authentication. If device authentication is unavailable, the app falls back to the in-app parent math challenge.

We also updated Age Rating metadata so Age Assurance is set to None.

Please let us know if any additional information is needed.

Best regards,
JuniorGlobe Developer
```

## Review Notes Suggestion

```text
Parent control location:
Settings (top-right gear) > Subscription > Parent Lock

Protected actions:
- subscription plans and purchase buttons
- Restore Purchases
- Parent Weekly Report
- parent support email and external legal/privacy links
```
