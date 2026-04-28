# LMS — core flows

The flows every LMS must support. P1 is "without these, learners can't learn." P2 is "they keep coming back." P3 is "competitive value."

## P1 — must-have for v1

### 1. Course authoring → publish

```
Instructor creates course (title, description, price, language)
  → adds modules + lessons (drag-reorder)
  → uploads video / writes text / builds quiz / writes assignment
  → preview as student
  → publish (or save as draft)
  → catalog page goes live
```

Invariants:
- Draft state for the entire course AND per-lesson — instructors edit existing courses without breaking enrolled students mid-flow.
- Published lessons are versioned: existing students see the version they enrolled into (or get an explicit "course updated" prompt). Edit-then-published = re-snapshot.
- Video uploads are async; a lesson with a still-processing video is unpublishable.

### 2. Enrollment (purchase / free / admin grant)

```
Student finds course (search/browse/landing)
  → /courses/[slug] (PDP-equivalent: trailer, syllabus, instructor bio, reviews)
  → "Enroll" / "Buy now" / "Add to cart"
  → checkout (or instant if free)
  → on payment success: Enrollment created (status=active)
  → access granted to /learn/[course-slug]
  → confirmation email + first-lesson nudge
```

Invariants:
- Refund policy clearly disclosed BEFORE purchase.
- Free preview lessons accessible without enrollment.
- Idempotency on enrollment creation (double-click on Enroll, webhook retries).
- Region-priced courses use the buyer's locale price snapshot, NOT the displayed list price.

### 3. Lesson playback

```
Student opens lesson
  → checks enrollment status + completion-prereqs (sequential courses block ahead)
  → for video: signed URL request → player loads → progress events stream
  → for text/HTML: render content
  → for quiz: load shuffled questions (without correct answers!)
  → for assignment: render prompt + upload UI
  → on watch/scroll/quiz-pass/submit: lesson marked complete
  → next lesson auto-suggested
```

Critical invariants:
- Video URLs MUST be signed + short-lived (15-60 min). Direct CDN URLs = piracy.
- Quiz answers (`is_correct`) NEVER sent to client. Submit answers → server grades → respond with score.
- Progress events are idempotent + retry-safe (network drops are common on mobile).
- Last-position resume — student returns, picks up where they left off.

### 4. Progress tracking

```
Heartbeat every 10-30s while playing video:
  POST /progress { enrollment_id, lesson_id, position_seconds, watch_event_id }
  server: upsert progress row, max(watch_seconds, incoming)
  server: if watch_seconds >= threshold AND completion not yet recorded:
       mark complete + emit lesson.completed event

On lesson change:
  emit final progress with last_position
```

Invariants:
- `watch_seconds` is monotonic per attempt — student scrubbing back doesn't undo it.
- Completion threshold is a property of the lesson type (default: 80% video watched).
- Idempotent: replayed events / late-arriving heartbeats don't double-count.

### 5. Quiz attempt + grading

```
Student starts quiz
  → server creates QuizAttempt (status=started, started_at=now, snapshot_of_questions)
  → questions delivered (correct answers stripped; shuffled if configured)
  → student submits answer per question OR submits all at once
  → server grades:
       MCQ: compare choice_ids to is_correct
       numeric: parse + tolerance check
       text: exact match OR regex OR fuzzy (configurable)
       essay/code: queue for instructor review
  → score computed; passed = score >= passing_score
  → response: score + (optionally) explanations
  → if passed AND lesson is "complete on quiz pass": mark lesson complete
```

Critical invariants:
- Time-limit enforced server-side (client clock untrusted). Auto-submit on expiry.
- Max-attempts enforced server-side.
- Correct answers + explanations released per quiz config (after_pass / never / always).
- Question snapshot stored on attempt — if instructor edits questions next week, this attempt's record stays consistent.
- Idempotency on submit (one attempt = one submission; retried POSTs return existing result).

### 6. Assignment submission + grading

```
Student writes / uploads → save as draft → submit
  → submission row created (status=submitted, version=N)
  → instructor notified
  → instructor opens grading interface → reads + applies rubric → grade + feedback
  → student notified
  → if "request revision" → status=returned → student can submit version=N+1
  → final grade recorded in gradebook
```

Invariants:
- Drafts auto-save (every 30s or on blur). Lost work is the #1 student complaint.
- File uploads use resumable + virus-scanned + size-capped.
- Late submissions flagged + late-policy applied automatically (% deduction).
- Plagiarism check optional but commonly required; integrate with Turnitin / Copyleaks; result stored as artifact.

### 7. Course completion + certificate

```
Last required lesson marked complete
  → check all completion-required items completed
  → check passing scores on required quizzes
  → enrollment.status = completed; completed_at=now
  → if certificate template configured:
       generate PDF (template + student name + course + date + serial + signature)
       store + return verification URL
       email to student
```

Invariants:
- Certificate serial number is unique + verifiable via public URL (`/verify/cert/[serial]`).
- Certificate generation is idempotent — re-issuing returns the existing one.
- Revocation flow exists (plagiarism finding, fraud) with audit log.

## P2 — keep learners coming back

### 8. Discussions / Q&A
- Per-lesson discussion thread.
- Per-course general forum.
- Instructor + TA can answer; community can up-vote.
- Email digest of new replies on threads student participated in.

### 9. Notes + bookmarks
- Student takes timestamped notes on video (clickable to seek).
- Bookmarks lessons.
- Notes searchable across enrolled courses.

### 10. Reviews
- Post-completion (or after watching X%) review prompt.
- 5-star + free-text.
- Instructor can respond.
- Affects course ranking + conversion.

### 11. Refund flow
- Window: 7-30 days OR <X% completion (whichever first).
- One-click student-initiated.
- Auto-revoke access on refund.
- Edge case: certificate already issued → revoke + log.

### 12. Instructor analytics
- Enrolled / active / completed counts.
- Average watch time per lesson.
- Drop-off lessons (where students abandon).
- Quiz score distribution.
- Average rating + review feed.
- Earnings (revenue split if marketplace LMS).

### 13. Email / push notifications
- Welcome on enroll.
- "Resume your course" after 3-7 days inactive.
- New lesson published in enrolled course.
- Reply on student's question.
- Certificate ready.
- Re-enrollment for upgrade course.

## P3 — depth + scale

### 14. Cohort / live sessions
- Scheduled course with cohort dates.
- Live session (Zoom / Meet / built-in WebRTC).
- Recording uploaded to course library.
- Cohort discussion (separate from self-paced general).
- Cohort-specific assignments + due dates.

### 15. Drip / scheduled release
- Lesson unlocks N days after enrollment.
- Or unlocks on cohort-relative date.
- Avoids student burning through content + churning.

### 16. Prerequisites + learning paths
- Course requires Course X completion.
- Multi-course paths (specialization, micro-credential).
- Bundle pricing.

### 17. Advanced quiz types
- Drag-drop matching.
- Code execution (JS / Python sandbox).
- Math input (LaTeX / equation editor).
- Audio / video response.
- Adaptive (next question based on prior answer).

### 18. Live proctoring + secure browser
- Webcam + screen + tab-lock during high-stakes exams.
- Provider integration (Proctorio / Respondus / Examity).
- Required for accredited programs.

### 19. SCORM / xAPI
- Upload SCORM package as a lesson; player tracks completion + score back to LMS.
- Emit xAPI statements to external LRS.
- Required for corporate compliance training.

### 20. Group / org enrollment + LTI
- Companies buy seats, assign to employees.
- Org admin dashboard with progress per learner.
- LTI 1.3 integration with school LMSs (course launches from Canvas/Moodle/Blackboard).

### 21. Localization
- Subtitles + captions per video (auto + human).
- Translated UI + content.
- Right-to-left support (Arabic, Hebrew).
- Per-region pricing.

### 22. Accessibility
- Keyboard navigation throughout.
- Screen-reader friendly player + content.
- Captions required for video (WCAG 2.2 AA).
- Transcripts available.

## Idempotency-critical endpoints

- `POST /enrollments` — webhook retries + double-click on Enroll.
- `POST /quiz-attempts/:id/submit` — submit retried = same result.
- `POST /progress` — heartbeats overlap.
- `POST /assignments/:id/submit` — re-submit must be deliberate (different version).
- `POST /certificates/issue` — re-issue returns existing record.

## Webhooks to produce

- `enrollment.created`, `enrollment.completed`, `enrollment.cancelled`.
- `lesson.completed`, `course.completed`.
- `quiz.attempted`, `quiz.passed`, `quiz.failed`.
- `assignment.submitted`, `assignment.graded`.
- `certificate.issued`, `certificate.revoked`.
- `discussion.new_reply` (for notification).

## Webhooks to consume

- Video provider: `video.processed`, `video.errored`.
- Payment provider: charge / refund / chargeback.
- Plagiarism provider: `report.ready`.
- Proctoring provider: `session.flagged`.
- Email provider: bounces / unsubs (suppression list).
