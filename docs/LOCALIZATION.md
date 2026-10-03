# Localization workflow

Apple String Catalog infrastructure is used for UI text, room/checklist guidance and report text. `L` resolves the active language through the main bundle and falls back to the English source string. The source language is `en-GB`.

Priority locales: `en-GB`, `en-US`, `es`, `fr`, `de`, `it`, `pt`, `nl`, `pl`, `ro`, `ar`, `hi`, `zh-Hans`, `zh-Hant`, `ja`, `ko`. Only English UK is published in this build; other languages fall back to English. Native SwiftUI containers follow layout direction. Strings are not used as legal decision rules.

1. Run `python3 scripts/localization.py` after changing source copy.
2. Produce translation drafts outside `LeaveWell/Resources`. Translation providers may be added to this draft stage; no automatic translator is wired to publish.
3. Store each translation with `source`, `translation`, `locale`, `status`, `reviewed`, `version`, and `requiresSpecialistReview`.
4. A human reviewer checks UI copy. Legal/privacy/regulatory/jurisdiction-specific wording also requires `specialistReviewed: true`.
5. Publish approved records with `python3 scripts/localization.py --publish translations/reviewed.json`.
6. Run `python3 scripts/localization.py --check` and review in Xcode. Human review must cover plurals, long strings, permission prompts, VoiceOver and RTL; the script does not replace this review.

Example review record (illustrative, not proof of approval):

```json
{
  "source": "Continue",
  "translation": "Continuar",
  "locale": "es",
  "status": "reviewed",
  "reviewed": true,
  "version": 1,
  "requiresSpecialistReview": false
}
```

Increase the source version and require re-review when wording changes. Keep version/status/reviewer records in the translation workspace; the bundled catalog contains only the approved values. The script refuses unknown locales, unknown sources, draft/unreviewed records and source-version mismatches. Do not claim all languages are supported until reviewed translations and runtime QA have actually shipped.
