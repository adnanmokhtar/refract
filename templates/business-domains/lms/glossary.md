# LMS — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `lms`:

**Entity / model names**: `Course`, `Module`, `Section`, `Lesson`, `Lecture`, `Quiz`, `Question`, `Choice`, `QuizAttempt`, `Answer`, `Enrollment`, `Progress`, `CompletionRecord`, `Certificate`, `Instructor`, `Student`, `Learner`, `Cohort`, `Assignment`, `Submission`, `Grade`, `Rubric`, `Discussion`, `LessonResource`, `VideoAsset`, `xAPIStatement`, `SCORMPackage`.

**Folder / route names**: `courses/`, `lessons/`, `quizzes/`, `assignments/`, `learn/`, `student/`, `instructor/`, `gradebook/`, `/courses/[slug]/learn`, `/courses/[id]/lesson/[id]`, `/quiz/attempt`.

**Dependencies**: `mux`, `cloudflare-stream`, `vimeo`, `bunny-stream` (video), `tus-js-client` (resumable upload), `xapi-wrapper`, `rustici-engine`, `pipwerks-scorm`, `chevereto`, `videojs`, `plyr`, `hls.js`, `mathjax`, `katex`, `pdf-lib` (certificates), `proctorio`, `respondus`, `examity`.

**Database schema**: tables for `enrollments` + `lessons` + `progress` + `quiz_attempts` is the strongest signal. SCORM/xAPI tables (`scorm_packages`, `cmi_data`, `xapi_statements`) signal corporate/compliance LMS.

**Distinguishing from content/CMS**: CMS = published articles. LMS = structured progression + assessment + completion tracking. The presence of "completion" + "progress" + "grade" is the line.

**Distinguishing from cohort-based learning platform**: cohort-based has live sessions + scheduled cadence + Zoom/meet integration; self-paced LMS doesn't. They share entities but UX/flow differs.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Course` | the unit of enrollment | `id, title, slug, description, instructor_id, price, currency, status, language, level (beginner/inter/advanced), thumbnail, duration_minutes, requires_prereq[]` | draft → published → archived |
| `Module` / `Section` | grouping of lessons | `id, course_id, title, order, unlock_rule (sequential/free)` | follows course |
| `Lesson` | single learning unit | `id, module_id, title, type (video/text/quiz/assignment/file/live), order, duration, content_ref, is_preview` | published immediately or scheduled |
| `VideoAsset` | the actual media | `id, provider (mux/cloudflare/vimeo), provider_asset_id, hls_url, duration, captions[], thumbnails[], drm_enabled` | uploading → processing → ready → errored |
| `Enrollment` | student-course pairing | `id, student_id, course_id, status (active/completed/cancelled/expired), enrolled_at, completed_at, expires_at, source (purchase/cohort/admin)` | active → completed (or expired/cancelled) |
| `Progress` | per-student per-lesson | `enrollment_id, lesson_id, status (not_started/in_progress/completed), watch_seconds, last_position, completed_at` | tracked event-by-event |
| `Quiz` | assessment | `id, lesson_id, passing_score, max_attempts, time_limit_seconds, shuffle_questions, show_answers (after_pass/never/always)` | published with parent lesson |
| `Question` | one quiz question | `id, quiz_id, type (mcq/multi/text/numeric/match/code), prompt, points, order, explanation` | versioned (changes don't affect past attempts) |
| `Choice` / `Option` | answer option | `id, question_id, text, is_correct, order` | server-only `is_correct` (NEVER ship to client) |
| `QuizAttempt` | one student's try | `id, enrollment_id, quiz_id, score, max_score, passed, started_at, submitted_at, time_taken_seconds, answers[], snapshot_of_questions[]` | started → submitted → graded |
| `Answer` | student's response per question | `attempt_id, question_id, choice_ids[], text_answer, points_earned, graded_by (auto/instructor)` | immutable post-submit |
| `Assignment` | open-ended deliverable | `id, lesson_id, title, prompt, max_points, due_at, allow_resubmit, late_policy, rubric_id` | published with parent |
| `Submission` | student's assignment work | `id, assignment_id, student_id, files[], text, submitted_at, status (draft/submitted/graded/returned), grade, feedback, version` | draft → submitted → (returned for revision OR graded) |
| `Rubric` | grading criteria | `id, criteria[{name, levels[{label, points, descriptor}]}]` | versioned |
| `Grade` / `Gradebook entry` | one student-assessment grade | `student_id, course_id, item_id, item_type, points, max_points, weight, recorded_at` | append-only ledger |
| `Certificate` | completion artifact | `id, enrollment_id, serial_number, issued_at, signed_pdf_url, verification_url, revoked` | issued → (revoked optional) |
| `Cohort` / `Class` | scheduled batch | `id, course_id, start_at, end_at, schedule, instructor_id, max_seats, enrollment[]` | upcoming → in_progress → completed |
| `Discussion` | per-course or per-lesson | `id, lesson_id?, course_id?, parent_id?, author_id, body, status (visible/hidden/flagged)` | active → archived |
| `Instructor` | course author/teacher | `id, user_id, bio, avatar, expertise[], rating, courses[], payout_method` | active → suspended |
| `Student` / `Learner` | the user enrolled | `id, user_id, name, language_pref, time_zone` | per profile |
| `xAPIStatement` | learning event log (LRS) | `actor, verb, object, result, context, timestamp` | append-only |
| `SCORMPackage` | corporate-LMS content unit | `id, course_id, manifest, files[], schema_version (1.2/2004)` | uploaded → ready |

## Status state machines

**Enrollment:**
```
active → completed
   ↓        ↓
expired  refunded
   ↓
cancelled
```

**QuizAttempt:**
```
started → in_progress → submitted → graded
              ↓             ↓
          abandoned    auto_submitted (timer expired)
```

**Submission:**
```
draft → submitted → graded → returned (revision requested)
                 ↓                ↓
              late_submitted   resubmitted (next version)
```

**Course publish:**
```
draft → review → published → unpublished → archived
```

**Certificate:**
```
issued → (revoked) — revoked is exceptional, e.g. plagiarism finding
```

## Vocabulary distinctions (don't conflate)

- **Course** vs **Cohort** vs **Class** — Course is the curriculum (template). Cohort/Class is one scheduled run with specific students + dates. Self-paced has no cohort.
- **Enrollment** vs **Purchase** — Purchase is the transaction. Enrollment is access grant. Some platforms gift / scholarship / admin-grant without a purchase.
- **Progress** vs **Completion** vs **Mastery** — Progress = % through the material. Completion = all lessons marked complete. Mastery = passing score on assessments. A learner can be 100% progress but not pass quizzes (incomplete).
- **Lesson "completion" rules** — Video: watched ≥X% (commonly 80%+) OR ended event. Text: scrolled to bottom OR explicit mark-complete. Quiz: passed (or attempted, depending). DEFINE PER PLATFORM; inconsistency confuses.
- **Score** vs **Grade** vs **Points** — Score is raw (`8/10`). Grade is letter/level (`A`, `Pass`). Points is weighted in gradebook.
- **Auto-graded** vs **Manually graded** — MCQ/numeric is auto. Essay/code/short-text needs instructor or AI assist.
- **Pre-test** vs **Post-test** vs **Final** — Different invariants on retakes + visibility.
- **xAPI** vs **SCORM** vs **cmi5** — SCORM 1.2/2004 is the legacy corporate-LMS standard (single-page packages). xAPI (Tin Can) is the modern statement-based protocol. cmi5 is xAPI's "SCORM successor" profile. If your domain is corporate compliance training, you must support at least SCORM.
- **LMS** vs **LXP** (Learning Experience Platform) — LMS is structured + admin-driven. LXP is discovery + recommendation + social, learner-driven. Many products blur both.
- **Instructor-of-record** vs **Course author** — for accreditation, the instructor-of-record is the legal owner; for content, the author may be a co-creator. Schools care about this distinction.

## Multi-tenancy variants

- **Single-tenant LMS**: one school. Shared catalog.
- **Multi-tenant SaaS LMS** (e.g. Teachable / Thinkific clones): each school is a tenant, branded subdomain, separate catalog + students + reports.
- **Marketplace LMS** (Udemy / Skillshare): one operator, many instructors selling courses to one shared student base. Borrows from `marketplace/` (revenue split, payouts).
- **Corporate LMS**: one tenant per company, employees-as-students, mandatory training assignments, compliance reporting.
- **Higher-ed LMS** (Canvas / Moodle): institution-tenant, terms/semesters, official transcripts, accreditation.
