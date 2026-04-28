# LMS — feature checklist

What every LMS v1 should have. Most miss the same 5-10 items and lose retention because of it.

## Learner-facing

### Discovery
- [ ] Course catalog with filter (category, level, language, price, duration).
- [ ] Course landing page (PDP): trailer / preview lesson, syllabus, instructor bio, reviews, FAQs.
- [ ] Free preview lessons (1-3 lessons accessible without enrollment).
- [ ] Search with autocomplete.
- [ ] Wishlist / save for later.
- [ ] Recommended courses (post-completion + in-catalog).

### Enrollment
- [ ] Free + paid enrollment paths.
- [ ] Coupon / discount code support.
- [ ] Bundle / multi-course purchase.
- [ ] Gift purchase (give to email).
- [ ] Receipt with course title for reimbursement.

### Learning experience
- [ ] Course player with sidebar nav (modules + lessons + completion checks).
- [ ] Resume from last position automatically.
- [ ] Adjustable playback speed (0.75x - 2x).
- [ ] Captions on/off + multi-language captions.
- [ ] Picture-in-picture / mini-player.
- [ ] Note-taking with timestamps.
- [ ] Bookmark lesson.
- [ ] Download lesson resources (PDF, code, slides).
- [ ] Mobile responsive — many learners on phone.
- [ ] Offline mode (mobile app feature).

### Assessments
- [ ] Quiz attempt UI with timer (when applicable).
- [ ] Quiz review post-submit (correct/incorrect + explanations per quiz config).
- [ ] Assignment submission with file upload + rich text.
- [ ] Auto-save drafts.
- [ ] View grade + feedback per submission.
- [ ] Submission history (all versions for re-submitted assignments).
- [ ] Gradebook view (all grades for the course).

### Discussion + community
- [ ] Per-lesson Q&A.
- [ ] Up-vote / mark helpful.
- [ ] @mention + tag.
- [ ] Notification on reply to my thread.

### Account
- [ ] Sign up / sign in / SSO (Google, Apple, LinkedIn min).
- [ ] My Courses dashboard with progress + last-played.
- [ ] Achievement / badge feed.
- [ ] Certificate library.
- [ ] Email + notification preferences.
- [ ] Account deletion (GDPR).
- [ ] Time zone setting (cohort scheduling).

## Instructor-facing

### Course authoring
- [ ] Course CRUD with title, description, thumbnail, intro video, syllabus.
- [ ] Module + lesson nesting with drag-reorder.
- [ ] Lesson types: video, text/HTML, file, quiz, assignment, embed (codepen / figma / etc.), live session.
- [ ] Resumable + chunked video upload (large files, mobile uploads, network drops).
- [ ] Captions: upload manual + auto-generate (provider integration).
- [ ] Quiz builder: MCQ, multi-select, true/false, short text, numeric, matching.
- [ ] Question bank (reuse questions across courses).
- [ ] Assignment builder with rubric.
- [ ] Preview as student.
- [ ] Save draft / publish / unpublish per lesson + course.
- [ ] Bulk actions (publish all, delete, reorder).
- [ ] Course settings: prereqs, completion criteria, certificate template, drip schedule.

### Student management
- [ ] Roster: enrolled list with progress + last-active.
- [ ] Manual enrollment (add student by email).
- [ ] Bulk enrollment (CSV).
- [ ] Cohort management (create, schedule, assign students).
- [ ] Student detail: all activity, grades, time-on-course.
- [ ] Message student / cohort.
- [ ] Refund / unenroll with reason.

### Grading
- [ ] Pending submissions inbox.
- [ ] Side-by-side: prompt + student work + rubric + feedback.
- [ ] Annotate file uploads (PDF/image markup).
- [ ] Send back for revision (request resubmit).
- [ ] Bulk-grade similar submissions.
- [ ] AI grading assist (suggest grade + feedback).
- [ ] Plagiarism check integration.

### Analytics
- [ ] Enrollment trend.
- [ ] Active learners over time.
- [ ] Lesson drop-off chart.
- [ ] Average watch % per lesson.
- [ ] Quiz score distribution.
- [ ] Time-to-complete distribution.
- [ ] Reviews + ratings.
- [ ] Earnings (if monetized).

### Communication
- [ ] Announcements (course-wide post).
- [ ] Email students (single, segment, all).
- [ ] Reply to Q&A.
- [ ] Live session scheduling (with calendar invite).

## Operator / admin (multi-tenant or marketplace LMS)

### Platform admin
- [ ] User management (students, instructors, admins).
- [ ] Course moderation queue (review before publish).
- [ ] Featured courses + curation.
- [ ] Categories + tags management.
- [ ] Site settings (branding, domain, locale, currency).
- [ ] Email templates + branding.

### Org / corporate admin (B2B LMS)
- [ ] Seat assignment (assign learners to required courses).
- [ ] Mandatory training + due dates.
- [ ] Reminder cadence config.
- [ ] Compliance report (who has completed what by when).
- [ ] SCORM / xAPI consumption.
- [ ] SSO (SAML, Okta, Azure AD).

### Reports
- [ ] Revenue (gross, net, refunds, by course/instructor/region).
- [ ] Active vs total learners.
- [ ] Completion rate per course.
- [ ] At-risk learners (enrolled but inactive >N days).
- [ ] Top courses by completion / rating / revenue.
- [ ] Tax invoice exports.

### Marketing
- [ ] Coupon CRUD with conditions.
- [ ] Affiliate tracking (referral links + commission).
- [ ] Email campaign integration (Mailchimp/Klaviyo/SES).
- [ ] Abandoned cart for paid courses.
- [ ] SEO: per-course meta + structured data (`Course` schema).

## Trust + compliance

- [ ] HTTPS site-wide.
- [ ] Privacy + terms + refund policy pages.
- [ ] Cookie consent.
- [ ] FERPA-mode for institutions (student record protections).
- [ ] COPPA-mode if under-13 (parental consent flow).
- [ ] GDPR data export + delete.
- [ ] Accessibility statement + WCAG 2.2 AA compliance.
- [ ] Captions on all videos (legal in many jurisdictions for accessibility).
- [ ] Refund processing through original payment.
- [ ] DMCA takedown procedure for content claims.

## Operational

- [ ] Video CDN with signed URLs + DRM optional.
- [ ] Webhook handler idempotency (payment + video processing).
- [ ] Backup of user data + course content.
- [ ] DR plan for video provider outage (multi-CDN ideal).
- [ ] Status page (peak exam time = peak load).

## Things v1s commonly miss

- Resume from last position — sounds trivial, students rage when missing.
- Auto-save on assignment drafts — students lose work then quit.
- Captions — accessibility AND watch-without-sound preference (60%+ of mobile views are muted).
- Quiz answers leaking to client — first-day vulnerability; security audit catches.
- Certificate verification URL — recruiters need to check authenticity.
- Drop-off analytics for instructors — without this, instructors can't improve.
- Refund self-service — operators drown in refund tickets without it.
- "Course updated" prompt — students mid-course confused when content shifts.
- Video processing time UX — instructors wonder if upload broke; show progress + "ready when processed."
- Mobile experience — many learners on phones; desktop-first is a churn driver.
- Time zone in cohorts — "starts at 9am" without TZ = global confusion.
- Plagiarism on essay assignments — without it, accreditation impossible.
- Watch-time fraud — bot inflates progress for refund-then-keep-cert scam; require interaction signals.

## Things often over-built in v1

- Adaptive learning algorithms (start with linear progression).
- Native mobile apps (PWA / responsive is enough until proven).
- Live video built-in (use Zoom / Meet integration first).
- Gamification (badges + points come AFTER core works).
- AI tutor / chatbot (no MOOC has cracked this; defer).
- Marketplace features (reviews + revenue split) — only if you're going marketplace, not single-school.
- Multi-language content (UI i18n is fine; translating courses is a major commitment).
- Advanced proctoring (only needed for accredited / high-stakes).
