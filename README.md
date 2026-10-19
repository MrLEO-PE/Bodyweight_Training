# Bodyweight Builder

A home training app for PE students. Students build bodyweight workouts from 20 movements, each with 4 levels. They follow a timer, log their reps and holds, and see their progress over time. Teachers manage classes, set a weekly goal, follow each student's progression and download results as Excel files.

The whole app is one file, [index.html](index.html). Data is stored in Supabase.

## What students get

- **Workout builder:** 8 to 12 exercises (a teacher's challenge workout can have as few as 4) across Legs, Upper body, Core, Cardio and Balance, with 30, 40 or 45 s work, rest time and 1 to 3 rounds.
- **Timer:** full-screen with beeps. Students cannot skip anything (warm-up, exercises, rests, heart rate, cool-down), so every exercise gets a score. Only the **TEACHER** account can skip any step, in workouts done alone (not in a live session, where everyone stays in step).
- **Last score straight away:** the last exercise has no rest, so a 20-second "Write your last score" screen follows it (the same + and − box as the rests).
- **Forgot your PIN:** on the PIN screen, **I forgot my PIN: ask my teacher** sends a request (one waiting request per student). The teacher sees **PIN requests** at the top of the Classes page, and the TEACHER account of that class sees its own class's requests. **Accept** clears the PIN so the student creates a new one like the first time (results kept); **Decline** keeps it.
- **Points:** each rep is 1 point and each second held is half a point, times the level (Level 1 x1, Level 2 x1.5, Level 3 x2, Level 4 x2.5), so choosing a harder level pays off.
- **Leaderboards:** challenge workout (best try counts), this week, and **most improved** (this week compared with last week), plus a **form cup** ranking the forms of the year group by points per student.
- **Rank titles:** Rookie, Athlete (1,000 points), Pro (4,000) and Legend (10,000), with a progress bar to the next rank.
- **Badges:** 12 to collect (first workout, streaks, level up, all-rounder, early bird, record breaker...). New badges, level-ups, ranks and personal bests are celebrated with confetti.
- **Weekly recap** of last week, **star of the week** chosen by the teacher, **Surprise me** and **Quick 8-minute** workouts at the student's own levels, and a **voice coach** in the timer (can be turned off).
- **Tutorial:** 17 steps with screenshots (images in [tutorial/](tutorial/)), from joining the class to the heart-rate check, live challenges and points. It opens from the first screen and from the student's More menu.
- **Timer details:** full-screen with beeps, a "switch sides" signal on one-sided exercises, and score logging during rest. The screen stays awake.
- **Progress:** a weekly goal set by the teacher, a streak of weeks with the goal reached, a chart of average level over time, personal bests, and a table of their current level for each movement.
- **Challenge:** a movement is marked **Ready for Level N** when:
  - holds: the student held the full time in every round in their last two workouts at that level
  - reps: the student has done that level at least twice, matched or beat their best reps per minute, and rated the workout 7/10 or easier

  "Repeat with level-ups" rebuilds the last workout with those movements moved up one level.
- **Two tabs:** **Today** (this week, the challenge, one main button, and a **More** menu with the other ways to train) and **Me and my class** (rank, levels, badges, fitness checks, leaderboards, form cup, class challenges). The last tab is remembered.
- **Clear stages in the timer:** a strip at the top shows the four stages: **1. Warm-up**, **2. the challenge of the day** (shown with its name, for example "Core & legs week"), **3. Heart rate** and **4. Cool-down**, with the current one highlighted. The first screen says "Warm-up first" (or names the challenge and its first exercise when the warm-up is off). The warm-up is 4 moves and the cool-down 3 stretches, 30 seconds each. Students cannot skip them; only TEACHER can.
- **Are you ready? 10 to 1, GO!:** before the first exercise (after the warm-up, or as the first screen when there is none) the voice coach shouts "Are you ready?" in a loud, high, sporty voice, counts from 10 to 1, then screams "GO!" followed by the exercise name. It lasts 12 seconds and is part of the shared clock in live sessions. The voice can be turned off with the Voice button.
- **Install as an app:** add the app to the home screen (iPhone, Android or computer) so it opens full screen. Once opened online, it also starts without a connection. Workouts done offline upload later.
- **Offline:** if the connection drops, the workout is saved on the device and uploads later with its original date.
- **Stay logged in:** students can stay logged in on their own device for 30 days.
- **Exercise list:** one page with all 20 movements and their 4 levels (80 exercises), printable, open to anyone from the home page.
- **How to guides:** every movement has a guide with the steps for all 4 levels, a safety point and a demo video link. It opens from the builder and from the timer, which pauses while the guide is open.
- **Challenge workout:** the workout set by the teacher appears at the top of the student's page with its due date. "See the workout" opens a fixed programme to follow in order: exercises with a fixed level are shown as set, and for exercises where the teacher allowed it the student picks their own level (1 to 4) before starting.
- **Class challenges:** shared team goals with a progress bar and no individual rankings.
- **This week line and first visit:** the Today tab starts with "This week: 2 of 3 workouts · challenge due tomorrow". The first time a student logs in, three short cards explain the challenge, the timer and the points. The Quick 8-minute workout becomes the main button when no challenge is waiting.
- **Join from a link or QR code:** the class sheet's link opens the app with the form and class code already filled in. The student only chooses their name and a PIN.
- **Heart rate in every workout:** after the last exercise and before the cool-down, the timer turns red: 10 seconds to stop and find the pulse (two fingers on the wrist or neck), a 30-second count, then **20 seconds to type the beats counted** (the app doubles it into bpm), with beeps and the voice coach. In a live session everyone waits on the red screen with their fingers on their pulse, and the teacher presses **Start the 30-second count for everyone**: the count starts 3 seconds later on every screen, then everyone writes their beats and the cool-down follows together (if the teacher never presses it, it starts by itself after 3 minutes). If a student does not write the beats in time, the app asks right after the workout. The bpm shows in the workout table, the challenge results and the Excel exports.
- **Due dates:** the challenge card says "due tomorrow", "due today" or "overdue since…".
- **Live sessions:** when the teacher starts the challenge with the class, an alert appears on the student's page. They tap **I'm ready**, or **Not now**. The workout starts on every screen at the same moment, with no pause, and students who arrive late can **Join now** in step with the class. Optional alerts can be turned on from the Today tab; they show when the app is open in the background.
- **Fitness checks:** five tests (squats and push-ups in 1 minute, plank and wall sit holds, jumping jacks in 1 minute), each with a guided timer. Students see their change since their first check.

## What teachers get

- Classes or forms (such as 10C) with a join code, a weekly goal (1 to 7 workouts) and a **year group** (such as Year 10). The year group fills itself in from names like 10C, Y10 or Year 10. Classes are listed by year group, for teachers and students.
- **Import students from a file:** Excel (.xlsx, .xls), LibreOffice (.ods), CSV, or Google Sheets downloaded as .xlsx.
  - It finds the name, form/class and year columns, in English or French headings, and handles one sheet per class.
  - It also recognises a form column from its values (10C, 10-C, 10/2), whatever the heading.
  - It can create new classes with a join code, and names already in a class are skipped.
  - Students already in another class are moved instead of duplicated. For example, a file with a form column splits a 170-student "Year 10" class into 10A, 10B, 10C… Their PIN, workouts and fitness checks go with them.
  - The import page lists **files already imported** (name, date, number of students, classes), each with a ✕ to delete an old version. A student who is in a newer file belongs to the newer file, so deleting an old file removes only the students who are not in a newer one. Their past workouts are kept without a name.
  - "Start fresh" deletes all existing classes, students and workouts first (you must type DELETE), so you can replace a previous import with a new file.
  - It warns before creating a class of more than 60 students, since students pick their name from that class's list.
  - The file is read on the teacher's device: only names and classes are saved.
- **TEACHER account in every class:** the list of names ends with TEACHER, in every class. The teacher chooses it, types the teacher PIN, and gets the same menu as a student. TEACHER takes part like a student: workouts are saved, and once it has done one it appears in that class's leaderboards and results, tagged Teacher. It is not counted in the class size and does not hold up a live session's start.
- **Live challenge from TEACHER, several forms together:** the TEACHER menu has **Start a live challenge**. Tick the forms that take part (for example 8B and 8C), choose everyone, boys or girls, and open the session. Students of all those forms get the alert; the waiting list shows each name with its form; it starts when all are ready or on **Start now**. The workout is the challenge of your own form (or the first ticked form that has one), and each student's result counts for their own form's challenge.
- **Live challenge leaderboard:** after saving, everyone who took part (all the forms together, TEACHER included) sees one leaderboard for that live challenge, which updates itself as others save. Students can open it again from Today for 12 hours; the teacher page shows it at the end of a live session too.
- **After a crash or reload during a live session:** a student who had tapped I'm ready is put back in the timer automatically (others see Join now), in step with the class. The teacher page and the TEACHER account show **A live session is running: Rejoin the timer** and **See the results** for 3 hours. A TEACHER save or a finished timer no longer closes the session for others, so a student who crashed can still rejoin. If an error happens while the timer is up, a **Reload and rejoin** bar appears instead of a dead screen.
- **Reset PINs:** reset one student, tick several, or reset every PIN of a class. Each student creates a new PIN at their next login, like the first time. Workouts and results are kept.
- **Move a student** to another class from the class page, for example when they change form. Their PIN and history go with them.
- Or paste a class list to add students. Students create their own 4-digit PIN at first login, and you can reset it.
- A table per student: workouts this week, streak, average level, movements ready to level up. Click a name to see that student's full progress page.
- **Challenge workout:** build it with the same builder from the exercise list, add a message and a due date, and give it to a whole year group or chosen forms at once. For each exercise, either fix the level for everyone or tick "Students choose their own level". See who has done it and who has not.
- **Boys only or girls only:** students always stay in their form. When a challenge is set, **For** can be Everyone, Boys only or Girls only. A form can have an everyone challenge and a boys-only one at the same time: each student sees the one that fits, and the class page shows a panel for each, counting only the students it is for. Live sessions can also be opened for the boys or the girls of a form. This uses the gender saved for each student.
- **Getting started, My classes, class sheet, teacher guide:** a checklist on the teacher page (import students, set a challenge, give out the class code, try a live session) that hides when done; **☆ Mine** to put your forms first (saved on your device); a printable **class sheet** with the class code, a QR code and three login steps; and a **How it works (teachers)** page that can be printed for a staff meeting.
- **Presentation page:** [presentation.html](presentation.html) presents the app to colleagues and school leadership, with screenshots of every student step and the main teacher screens.
- **Teacher tutorial:** a full guide for colleagues inside the teacher page (button **Teacher tutorial** on the Classes page): 17 steps with screenshots in 6 topics (getting started, students, challenges, live challenges, results, settings and good habits), with buttons to jump to a topic and a Print button. Screenshots are in [tutorial/teacher/](tutorial/teacher/).
- **Train together (live):** on the class page, start the challenge workout with the whole class at the same time, for example during a video call. The teacher uses their own teacher page and never logs into students' accounts. Each student taps **I'm ready** on their own page, and the page shows who is ready. The workout starts for everyone when the whole class is ready, or when you press **Start now**. Your own timer runs in step with theirs (nothing is saved for you), and each student saves their own score as usual. Only students with the app open get the alert, so ask them to open it first.
- **Deadline:** once the due date has passed, the class page shows how many did it on time, late, or missed it. Late tries are tagged **Late** in the results, and the results board can show only students who did it on time, late, not done or missed.
- **Class challenges:** count workouts, reps or minutes between two dates, for example "Year 10: 1,000 workouts this half-term".
  - Choose whole year groups (forms added later join automatically), single forms, or both.
  - The card shows each form's part of the total, and students see their own form highlighted.
- **Backup:** download everything (classes, students, workouts, fitness checks, challenges; no PINs) as an Excel file or a complete JSON file. The teacher page reminds you when the last backup is over a month old.
- **New school year:** one guided page that downloads a backup, moves every class up a year (10C becomes 11C), removes the classes that leave and, if you choose, clears workouts and fitness checks. Students who stay keep their PIN and class code.
- **Saved challenges:** a shared library of challenge workouts for the whole PE department (button on the Classes page). When you set a challenge, "Keep it in Saved challenges" is ticked: it is saved with its title, message, exercises and timings (saving again with the same title updates it). To only save, tick no form. **Use** opens one ready to give to any forms, with the due date and levels still editable; ✕ deletes it. Previous challenges on a class page also have a **Save** button.
- **Previous challenge workouts** stay on each class page with their results, and can be used again.
- **Copy names:** one click copies the names of students who have not done the challenge (class page) or nothing in the chosen period (results board).
- **Star of the week** per class, with a message, shown at the top of every student's page.
- **Check flags:** scores that look too high (for example 90 reps in 40 seconds) are marked "Check" in the teacher tables, with the reason.
- **Gender:** optional Male/Female per student, imported from a Gender/Sex column (M/F, Male/Female, Boy/Girl, Garçon/Fille) or set on the class page, which shows the male/female count.
- **Results board:** one page with every student, filtered by year group, class, gender, period (this week, last 4 weeks, challenge workout, all time) and name, or showing only those who have done nothing. It has a by-class summary, links to each student's page, and downloads to Excel.
- **Challenge results by student:** on each class page, a table ranks every student by points, shows who has not done the challenge, and gives the level and score of each exercise. It is also a sheet in the Excel export.
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
