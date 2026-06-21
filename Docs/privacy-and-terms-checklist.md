# Privacy, Terms, and License Checklist

> This document is an engineering compliance checklist, not legal advice.
> Before public release, paid distribution, user-data collection, or production operation, confirm the final position with a qualified professional.


## Current Risk Level

Medium to high before App Store release. MindVault stores personal notes, metadata, AI eligibility flags, embeddings, subscription state, and future Team/cloud concepts.

## Required Before Public App Release

- Publish a Privacy Policy explaining local-first storage, on-device AI, subscription state, import/export, and any future cloud sync.
- Publish support and terms links for App Store review.
- Clarify repository license or all-rights-reserved status.
- Ensure App Store privacy labels match implementation.
- Keep cloud sync and Team features out of scope until data handling, administrator access, deletion, export, and sharing rules are designed.

## AI Controls

- Keep the promise that note content is not sent to external AI services unless the user explicitly opts into a future cloud feature.
- Preserve the AI-ineligible note flag across import/export.
- Avoid logging note bodies, embeddings, prompts, or private note titles into diagnostics.

## Billing Controls

- Present Free / Pro / Team limits without implying unavailable cloud features are currently provided.
- Document subscription restore, cancellation, and plan limits.

## Checklist

- [ ] License position documented.
- [ ] Privacy Policy drafted.
- [ ] Terms / EULA path drafted.
- [ ] Support URL drafted.
- [ ] App Store privacy label mapped.
- [ ] Cloud/Team features gated behind separate legal review.
