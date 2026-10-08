# Bodyweight Builder

A home training app for PE students. Students build bodyweight workouts from 20 movements, each with 4 levels. They follow a timer, log their reps and holds, and see their progress over time. Teachers manage classes, set a weekly goal, follow each student's progression and download results as Excel files.

The whole app is one file, [index.html](index.html). Data is stored in Supabase.

## What students get

- **Workout builder:** 8 to 12 exercises across Legs, Upper body, Core, Cardio and Balance, with 30, 40 or 45 s work, rest time and 1 to 3 rounds.
- **Timer:** full-screen with beeps, a "switch sides" signal on one-sided exercises, and score logging during rest. The screen stays awake.
- **Progress:** a weekly goal set by the teacher, a streak of weeks with the goal reached, a chart of average level over time, personal bests, and a table of their current level for each movement.
- **Challenge:** a movement is marked **Ready for Level N** when:
  - holds: the student held the full time in every round in their last two workouts at that level
  - reps: the student has done that level at least twice, matched or beat their best reps per minute, and rated the workout 7/10 or easier

  "Repeat with level-ups" rebuilds the last workout with those movements moved up one level.
- **Offline:** if the connection drops, the workout is saved on the device and uploads later with its original date.
- **Stay logged in:** students can stay logged in on their own device for 30 days.
- **Exercise list:** one page with all 20 movements and their 4 levels (80 exercises), printable, open to anyone from the home page.
- **How to guides:** every movement has a guide with the steps for all 4 levels, a safety point and a demo video link. It opens from the builder and from the timer, which pauses while the guide is open.
- **Workout of the week:** the workout set by the teacher appears at the top of the student's page. Students do it as set or at their own levels.
- **Class challenges:** shared team goals with a progress bar and no individual rankings.
- **Fitness checks:** five tests (squats and push-ups in 1 minute, plank and wall sit holds, jumping jacks in 1 minute), each with a guided timer. Students see their change since their first check.

## What teachers get

- Classes or forms (such as 10C) with a join code, a weekly goal (1 to 7 workouts) and a **year group** (such as Year 10). The year group fills itself in from names like 10C, Y10 or Year 10. Classes are listed by year group, for teachers and students.
- **Import students from a file:** Excel (.xlsx, .xls), LibreOffice (.ods), CSV, or Google Sheets downloaded as .xlsx.
  - It finds the name, form/class and year columns, in English or French headings, and handles one sheet per class.
  - It also recognises a form column from its values (10C, 10-C, 10/2), whatever the heading.
  - It can create new classes with a join code, and names already in a class are skipped.
  - Students already in another class are moved instead of duplicated. For example, a file with a form column splits a 170-student "Year 10" class into 10A, 10B, 10C… Their PIN, workouts and fitness checks go with them.
  - "Start fresh" deletes all existing classes, students and workouts first (you must type DELETE), so you can replace a previous import with a new file.
  - It warns before creating a class of more than 60 students, since students pick their name from that class's list.
  - The file is read on the teacher's device: only names and classes are saved.
- **Move a student** to another class from the class page, for example when they change form. Their PIN and history go with them.
- Or paste a class list to add students. Students create their own 4-digit PIN at first login, and you can reset it.
- A table per student: workouts this week, streak, average level, movements ready to level up. Click a name to see that student's full progress page.
- **Workout of the week** per class: build it with the same builder, add a message, and see how many students have done it.
- **Class challenges:** count workouts, reps or minutes between two dates, for example "Year 10: 1,000 workouts this half-term".
  - Choose whole year groups (forms added later join automatically), single forms, or both.
  - The card shows each form's part of the total, and students see their own form highlighted.
- **Fitness checks:** open a check for a class with a name such as "Start of Term 1" and close it when done. The class page shows each student's first and latest results and the change.
- **Demo videos:** paste your own video link for any of the 80 exercises. Without one, students get a YouTube search.
- Excel export per class (Students, Progress, Fitness checks, Workouts, Exercise log) or one file for all classes

## Setup

1. Create a free project at [supabase.com](https://supabase.com).
2. Open **SQL Editor**, paste all of [supabase/setup.sql](supabase/setup.sql) and run it. You can run it again safely, and it upgrades tables created by earlier versions of the app. **Run it again after every app update.**
3. In **Project Settings > API**, copy the Project URL and the `anon` public key into `CONFIG` at the top of the script in `index.html`.
4. Host `index.html` anywhere static, for example GitHub Pages (Settings > Pages > deploy from `main`), Netlify or the school website.
5. Log in as teacher with the PIN **`change-me-now`**, then change it straight away under **Change teacher PIN**. Use at least 6 characters and share it only with PE staff.

If `CONFIG` is left empty, the app runs in **demo mode**: data stays in that browser and the teacher PIN is `0000`.

## Security

- The `anon` key in `index.html` is public by design. Row level security is on and there are no table policies, so the browser can only call the `bw_*` database functions.
- Those functions check the class code, the PIN or a login token on the server. Students can only read and add their own workouts. Teacher actions need a teacher token, which lasts 12 hours.
- PINs are stored as bcrypt hashes. 5 wrong student PINs lock that student for 10 minutes. 10 wrong teacher PINs lock teacher login for 15 minutes.
- Choose class codes that are hard to guess. Anyone with the code can see the class list and set a PIN for a student who has not set one yet. If that happens, reset the PIN from the class page.
- The data includes student names and activity, so check that this storage meets your school's data protection policy (for example GDPR).
