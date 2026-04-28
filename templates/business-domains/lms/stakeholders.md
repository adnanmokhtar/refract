# LMS — stakeholders

Different LMS shapes = different primary stakeholders. A self-paced consumer LMS (Udemy) optimizes for instructors + buyers. A corporate LMS optimizes for L&D + employees + compliance. A school LMS optimizes for teachers + students + administrators. Build for your shape.

## Learner / Student

The reason content exists. Without completion, nothing else matters (for outcome-based metrics).

**Workflows (varies by motivation):**
- Discovery (search, recommended, paid for them by employer/school).
- Enroll (purchase, claim, assigned).
- Schedule learning (self-paced, cohort, mandatory).
- Consume (video, text, quiz, assignment).
- Demonstrate (assessment, certificate, transcript).
- Apply (jobs, school credit, internal recognition).

**Pain points the system must solve:**
- "Where did I leave off?" — resume position, last lesson played.
- "How much is left?" — progress bar accuracy.
- "Am I getting this?" — formative assessments + immediate feedback.
- "Will this count for [job/credit]?" — clear about credentials.
- "Why won't this video play?" — robust playback + offline option for mobile.
- "I lost my answers" — autosave, draft persistence.
- "How do I get help?" — Q&A presence + instructor responsiveness signal.

**Sub-types:**

### Self-motivated consumer learner
- Cares about: cost, instructor reputation, mobile experience, certificate marketability.
- Pain: forgets to come back; drops off after lesson 3.

### Mandatory corporate learner
- Cares about: minimum-effort completion, deadline tracking, hating the experience as little as possible.
- Pain: training seen as bureaucracy; high "click skip" temptation; loathes slow players.

### School student (K-12 / higher ed)
- Cares about: grade, deadline, peer comparison, instructor approval.
- Pain: assignment system bugs become school-wide drama; gradebook mistakes are emotional.

**KPIs:**
- Completion rate.
- Time-to-first-lesson (post-enrollment activation).
- Lesson drop-off (where do they quit?).
- NPS / CSAT.
- Repeat enrollment (consumer LMS).
- Pass rate (assessment-driven).

## Instructor / Teacher / Course Author

The supply side in a marketplace LMS; the staff side in a school/corporate LMS.

### Independent instructor (Udemy/Skillshare-style)
- Cares about: reach (catalog visibility), revenue (commission rate, payout cadence), tooling (recording, quiz building, captioning), feedback (analytics, reviews).
- Pain points: opaque ranking algorithm, slow review of edits, complex tax forms, copyright disputes.
- Permissions: own courses + students + earnings.

### School / university instructor
- Cares about: gradebook reliability, accessibility tooling, integration with SIS/LMS, plagiarism check, large-class management (300-student lectures).
- Pain points: tool fragmentation (LMS + Zoom + Turnitin + gradebook + email), accommodations for disabilities, late-policy automation.
- Permissions: their courses + their students.

### Corporate L&D / training designer
- Cares about: SCORM/xAPI export, manager-reportable progress, completion certificates that feed into HR systems, assessment validity.
- Pain points: SCORM authoring tooling, integration with HRIS, content updates without disrupting in-progress trainings.
- Permissions: org's catalog, all employee records.

### Content team (if marketplace operator employs content creators)
- Cares about: production calendar, SME (subject-matter expert) coordination, equipment + studio scheduling.
- Permissions: pre-publish access to courses they're producing.

**Universal instructor pain:**
- Re-recording a video lesson (one mispronounced name) shouldn't break student progress. Versioning + selective re-attempt.
- Refunds against a good course feel personal — show context.
- Q&A volume scaling at high enrollment — tooling for batch reply, FAQ promotion.

**KPIs:**
- Course publication rate.
- Average rating.
- Completion rate of their courses.
- Earnings (consumer/marketplace LMS).
- Q&A response time.
- Student satisfaction.

## Operator / Platform admin

### Founder / CEO
- Wants: GMV / ARR, active learners, completion rates, marquee instructor wins, retention.

### Content / curation team
- Wants: publish queue, featured-course promotion, category gardening, low-quality course pruning.

### Trust + safety
- Wants: copyright takedown queue, plagiarism flags, harassment reports, refund-fraud detection.

### Customer support
- Wants: enrollment lookup, refund button, course-issue triage, instructor-issue routing.

### Marketing
- Wants: catalog SEO, conversion funnel, abandoned-cart recovery, instructor partnership program.

### Engineering / IT
- Wants: video-pipeline health, payment health, search index freshness, audit logs.

### Compliance officer
- Wants: FERPA-DPA management, COPPA flow audits, accessibility scan results, tax remittance reports.

## Institutional admin (B2B / school LMS)

### School / district admin
- Wants: roster sync (SIS integration), term/semester management, gradebook policy enforcement, accreditation reporting.
- Permissions: institution-wide read; enrollment + course write.

### Corporate L&D admin
- Wants: assignment of mandatory courses, deadline + reminder cadence, dashboard of completion-by-team, audit-ready compliance reports.
- Permissions: org-wide.

### IT / SSO admin
- Wants: SAML / OIDC config, JIT provisioning, role mapping, audit log of user-management actions.

**Pain points:**
- Roster sync is brittle — students added late, withdrawn but still in roster, etc.
- LTI integration with parent LMS (Canvas, Moodle) — flaky standards.
- Reporting demands compliance-grade exports; can't be "good enough."

## Parents / guardians (K-12 LMS)

- Want: child's progress visibility, communication from teachers, assignment due dates.
- Don't want: marketing emails, data-mining of child.
- Permissions: scoped to their child(ren), often time-limited.
- COPPA / FERPA requires explicit parental consent flows.

## Recruiters / employers (consumer LMS post-completion)

- Want: certificate verification (1-click), skill demonstration, badging.
- Some platforms expose API for HR/ATS integration (Coursera for Business, LinkedIn Learning).

## Accreditation bodies (institutional LMS)

- Want: outcome reporting, learning-objective coverage proof, assessment validity, retention reports.
- Episodic users (audits, periodic reviews).
- Permissions: time-bounded read.

## Payment + tax providers

(Same as ecommerce — see `ecommerce/stakeholders.md`.)

## Video / CDN providers (Mux, Cloudflare Stream, Vimeo)

- Their reliability = your platform's reliability during peak (e.g. exam week, course drop).
- Pain: slow ingestion at peak; encoding queue backed up.
- Cost dynamics: storage + bandwidth scale with usage.

## AI / grading provider (if used)

- Plagiarism (Turnitin, Copyleaks).
- Auto-grade essay (varies; quality + bias issues).
- AI tutor (early-stage; trust calibration matters).

## Stakeholder-driven feature priorities

| If complaint is from... | Then priority is... |
|---|---|
| Learners abandoning at lesson 3 | Engagement: progress feedback, gamification, nudges |
| Instructors swamped with Q&A | Q&A tooling: bulk reply, FAQ promotion, TA roles |
| Institutional admins denied procurement | FERPA DPA, SSO, accessibility statement, security review |
| Compliance officer doing manual reports | Automated reporting + scheduled exports |
| Parents complaining about kids' data use | COPPA flow, restricted-purpose processing |
| Engineering paged at video issues | Multi-CDN, fallback, monitoring |
| Recruiters can't verify certificates | Public verification page + signed PDFs |
| Refund volume from bad courses | Course quality bar + early-refund analytics |

## Anti-pattern: "students = users"

Treating learners as generic users misses: enrollment scope, FERPA protections, parent/guardian context (under-13), accommodation needs, time zone for cohort, language preference, accessibility settings. Build a Learner profile, not just a User.

## Anti-pattern: "instructor pays nothing"

In a marketplace LMS, lavishing student experience while neglecting instructor tooling = supply collapse. Top instructors leave; quality drops; students leave. Symmetry of investment.

## Anti-pattern: "school-as-customer = student-as-product"

Selling B2B to schools doesn't relieve student-data obligations. Schools delegate consent, but the LMS is still bound by FERPA + COPPA + GDPR-K. Don't repurpose student data for marketing the platform.
