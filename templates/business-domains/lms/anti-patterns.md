# LMS — domain-specific anti-patterns

These are the LMS-specific traps. Generic web-app issues don't appear here unless they manifest distinctly in education contexts.

## Video + content delivery

- **Unsigned video URLs.** CDN URL pasted in <video> tag → straight-to-piracy via dev tools. ALWAYS use signed URLs with short TTL (15-60 min). Re-sign on player heartbeat.
- **DRM mistaken for piracy prevention.** DRM raises the bar but doesn't stop screen recording. Decide: DRM (Widevine/FairPlay/PlayReady) only if you're paying for licensed content. For instructor-created content, signed URLs + watermarking is usually enough.
- **Watermarking with non-personalized text.** A static "Property of Acme U" doesn't deter; recipient ID overlaid (faintly, via canvas) does.
- **Direct-to-S3 storage of original videos.** No transcoding pipeline → browsers can't play 4K MOV; mobile struggles. Use a video provider (Mux, Cloudflare Stream, Vimeo) that handles HLS/DASH + adaptive bitrate.
- **Single video URL for all qualities.** Playback fails on slow networks. ABR (adaptive bitrate) via HLS/DASH; player picks dynamically.
- **No transcript / captions.** ADA / EAA exposure + 60% of mobile views are muted. Auto-generate at upload + allow human edit.
- **Captions stored as static .vtt with no edit tooling.** Instructors can't fix typos in their own names. Inline editor required.

## Quizzes + assessments

- **Correct answers (`is_correct: true`) shipped to client.** Devtools → cheat. Strip server-side; clients receive only the option text + ID.
- **Quiz state in client localStorage.** Clear cache = unlimited attempts. Server-side QuizAttempt with state.
- **Time limit enforced client-side.** JS timer trivially manipulated. Server validates `(now - started_at) <= time_limit`.
- **Quiz questions edited after attempts started.** Old attempts now reference deleted questions. Snapshot question + choices INTO the QuizAttempt at start.
- **Auto-submit on timer not enforced.** Browser tab closed at 4:59; reopens at 5:00; can finish at leisure. Server-side auto-submit cron OR validation on submit (reject if past deadline + auto-grade what's there).
- **Numeric answer comparison without tolerance.** `3.14159` vs `3.14` mark wrong. Define tolerance per question.
- **Text-answer comparison case-sensitive.** "Newton" vs "newton". Trim + lowercase + Unicode-normalize before compare.
- **Code-execution quiz running on client.** Sandboxed iframe leaked; performance abused. Server-side execution in container with limits.
- **Instructor's "correct" answer wrong.** Quiz-creator typo → entire cohort marked wrong. Allow batch-regrade with audit.
- **Pass/fail logic recomputed each request.** Race conditions on "did I just pass?". Compute once at submit; store; serve from store.
- **Question banks pulling without seed.** Random question selection on retry shows different questions each time = unfair to repeated-attempters. Seed by attempt_id; each attempt is a stable random subset.

## Progress tracking

- **Progress as boolean per lesson.** Lost nuance: "I'm 60% through this 2-hour video." Track watch_seconds + last_position + completed_at separately.
- **Watch-time accepts client-claimed values.** Bot POSTs `watch_seconds: 7200` instantly; certificate auto-issued; refund issued; profit. Server-side verification: real-time max growth rate, interaction signals, anti-tampering token.
- **Progress not idempotent.** Heartbeats during retry double-count. Each event has a client-generated UUID; server upserts on (enrollment, lesson, event_id).
- **Last-position not saved on tab close.** Student returns, starts from 0. Save on every heartbeat AND on `pagehide` / `visibilitychange`.
- **Progress reset on instructor edit.** Tweaking a typo in transcript shouldn't void all student progress. Edits are non-breaking by default; only re-record forces version bump.
- **Course "completion" computed by lesson count, not lesson weight.** A 5-min intro lesson worth same as 90-min capstone. Allow weighted completion.
- **Progress events through unauthenticated endpoint.** Anyone POSTs progress for any user. Auth + ownership check on every event.

## Enrollment + access

- **Course access by URL guessing.** `/learn/course-1/lesson-5` accessible without enrollment check. Always check enrollment + course-access on every lesson load.
- **Free preview lessons mistakenly accessible past their preview flag.** Toggle `is_preview` not respected after instructor flips off. Cache-bust on edit.
- **Enrollment expiry not enforced.** Student keeps watching after subscription lapses. Check expiry on every player load + signed URL request.
- **Refunded students retain access.** Refund hits, but enrollment status not updated. Atomic refund flow updates both.
- **Lifetime access promised then revoked silently.** Customer-rights complaint. Document precisely what "lifetime" means (lifetime of platform? Of course on platform?).
- **Bulk enrollments without audit.** Admin enrolled 500 students; one was wrong; can't tell who/when. Audit log per enrollment action.
- **Self-unenroll deletes progress.** Re-enrolling later, all progress gone. Soft-delete enrollments; preserve progress; restore on re-enroll.

## Assignments + grading

- **Submission overwrites without versioning.** Resubmission destroys earlier work + earlier feedback. Immutable submissions per version.
- **Drafts saved client-side only.** Browser crash = lost work; biggest student rage. Server-side autosave every 30s.
- **File upload size limit only client-side.** Bypass with a script. Server enforces; reject early with clear message.
- **File upload without virus scan.** Instructor opens .docx with macro-bomb. Scan in pipeline; quarantine; safe URL only.
- **Plagiarism check results show source-student work to others.** Sample text from another student's submission visible in feedback. Sanitize.
- **Grade entered as text.** "B+" vs "B +" vs "85%" — gradebook math breaks. Numeric points + display formatter.
- **Late penalty applied at submit time.** Future grading reveals late penalty was wrong (rules changed). Apply at grade time using policy snapshot.
- **Re-grade overwrites without history.** Student appeals; instructor re-grades; original gone. Audit trail of every grade change.
- **Bulk-grade rubric without student-level differentiation.** Looks efficient; misses nuance; students complain "you didn't read mine."
- **Submission notification to instructor missing for offline submission methods.** Submitted via email but never showed in queue. Single submission API; nothing else accepted.

## Certificates

- **Certificate ID = sequential integer.** `cert/1234` reveals total issuance; trivial guessing of others. Use UUID or signed serial.
- **Verification page checks DB only at issuance.** Certificate revoked, page still says "valid." Real-time check on every verify request.
- **PDF certificate signed once + cached.** Revoke flow misses cached version. Signed PDF includes verification URL; PDF + URL must agree.
- **Certificate template hardcoded.** Multi-tenant LMS needs per-school template; multi-language localization.
- **Certificate issued before completion verified.** "Completed = lesson_count == X" but quiz wasn't passed → invalid certificate.
- **Re-issuance creates duplicate certificates.** Same student, two valid certificates for same course. Idempotent; first wins.
- **No revocation flow.** Plagiarism finding 6 months later — certificate stands. Revocation + audit + verification page reflects.

## Discussions + Q&A

- **Public discussion exposes student PII.** Names, emails leak. Default to anonymous-display option.
- **Spam moderation absent.** Course Q&A floods with crypto spam; instructor stops engaging.
- **No rate limit on posts.** Bots flood. Per-user rate limits + new-account dampening.
- **Reports go to nobody.** Flag button exists, queue doesn't. Configure routing + SLA.
- **Instructor unable to pin / FAQ-promote.** Same question 50 times. Promotion + auto-suggest similar.

## Refunds

- **Refund processed but content already downloaded.** Pre-signed download URLs continue to work after refund. Short TTL + re-check on use.
- **Refund window measured from purchase, not from access start.** Gift purchase claimed 60 days later, can't refund. Define semantics; honor in flow.
- **No refund-eligibility logic.** Customer requests refund 6 months in, fully completed; auto-issued; chargebacks for fraud. Define eligibility (window + completion threshold) + enforce + show in policy.
- **Operator-issued refund without gradebook update.** Records show student "took" the course but didn't pay. Reconciliation broken.

## Subscription / drip

- **Drip schedule based on calendar date, not enrollment date.** Cohort-based behavior on self-paced course; new enrollees see content already released. Pick the model + stick.
- **Drip release not idempotent.** Cron runs twice → student gets duplicate notification + one lesson appears twice in nav.
- **Subscription cancel revokes access immediately.** Customer paid for the month, expects month. Cancel = no renewal; access until period end.
- **Renewal failure cuts access mid-quiz.** Mid-attempt access yanked. Grace period or session-bound access until safe boundary.

## Instructor side

- **Course version not tracked.** Instructor edits, students mid-course see new content; complain "this isn't what I signed up for." Snapshot per enrollment OR notification flow.
- **Course deletion cascades to enrollments.** Instructor unpublishes → students lose access mid-course. Soft-archive; running enrollments grandfathered.
- **Earnings dashboard in operator timezone, not instructor's.** "Today" mismatched. Compute in instructor's TZ.
- **Tax-form data collected at first sale, never updated.** Address change unreflected on year-end. Re-collect periodically + on threshold.

## Multi-tenant / B2B specific

- **Tenant boundary leaks in search index.** Course catalog cross-tenant. Tenant filter on every search query.
- **Roster sync overwrites grade comments.** SIS push wipes instructor remarks. Sync only authoritative fields; respect manual.
- **SCORM player breaks completion sync.** SCORM CMI data not posting back to LMS. Test with Rustici cloud or similar.
- **xAPI statements double-emitted.** LRS shows duplicates → reports inflated. Idempotency on statement_id.
- **LTI launch session not validated.** Anyone with launch URL accesses. Validate signature + nonce + replay protection.

## Accessibility

- **Quiz drag-drop not keyboard-operable.** Screen-reader users fail; ADA complaint. Use accessible drag-drop primitives.
- **Math via images.** Screen reader reads "image". Use MathML or LaTeX with rendered + announced equation.
- **Captions auto-generated, never reviewed.** Bad captions worse than no captions for accessibility (false impression). Human review for polished courses.
- **Color-only state indicators.** Red = wrong, green = right; colorblind users miss.
- **Keyboard focus traps in player.** Cannot Escape; assistive-tech users stuck.
- **Modal pop-ups without focus management.** Focus on dismiss returns to top of page; lost context.

## Operational

- **Video provider migration silent on links.** Migrating from Vimeo to Mux; old course content references break. Indirection: store provider-agnostic asset_id; resolve at playback.
- **Search index lags published-state changes.** Just-published course not findable for 30 minutes. Index hooks on publish event.
- **Email-template hardcoded English.** Spanish learner gets English notifications. Tenant + user locale.
- **Backup of "user data" omits course content.** DR scenario: courses gone; refund-everyone catastrophe.
- **Cron jobs running per-node in cluster (drip release, certificate issuance).** Race → duplicates. Leader-elected scheduler.
- **No archival of old quiz attempts.** `quiz_attempts` at 100M rows; queries slow. Hot table for 90 days; archive older.

## Trust + UX

- **No "ratings change over time" decay.** New course with 5 ratings + 4.9 stars ranks above 5-year course with 5,000 ratings + 4.7. Volume + recency weighting.
- **Reviews shown without verification of completion.** Trolls / refund-rage reviews from students who watched lesson 1. Verified-purchase only or surfaced separately.
- **Course sale price as "anchor"-style fake-original-price.** "Was $200, now $20!" — deceptive pricing law violations (FTC, CMA, EU).
- **Hidden cost on certificate.** Course is free, certificate is $20 — undisclosed at enrollment. Disclose at landing.
- **Auto-renew without clear renewal disclosure.** State subscription law violations (US: California ARL, NY).
