package db

import (
	"fmt"
	"log"
	"time"

	"github.com/cubetures/axillium/models"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func Seed(db *gorm.DB) {
	var count int64
	db.Model(&models.Group{}).Count(&count)
	if count > 0 {
		return // already seeded
	}

	log.Println("Seeding database...")

	hash, err := bcrypt.GenerateFromPassword([]byte("password"), bcrypt.DefaultCost)
	if err != nil {
		log.Fatal("seed: failed to hash password:", err)
	}
	pw := string(hash)

	now := time.Now()

	// ── Helpers ──────────────────────────────────────────────────────────────

	// msg builds a group message with a timestamp relative to now.
	msg := func(groupID, userID uint, alias, role, content string, hoursAgo float64) models.Message {
		t := now.Add(-time.Duration(hoursAgo * float64(time.Hour)))
		m := models.Message{GroupID: groupID, UserID: userID, Alias: alias, SenderRole: role, Content: content}
		m.CreatedAt = t
		m.UpdatedAt = t
		return m
	}

	// dm builds a direct message.
	dm := func(senderID, recipientID uint, senderAlias, senderRole, content string, hoursAgo float64) models.DirectMessage {
		t := now.Add(-time.Duration(hoursAgo * float64(time.Hour)))
		m := models.DirectMessage{
			SenderID: senderID, RecipientID: recipientID,
			SenderAlias: senderAlias, SenderRole: senderRole, Content: content,
		}
		m.CreatedAt = t
		m.UpdatedAt = t
		return m
	}

	// ci builds a check-in with a timestamp relative to now.
	ci := func(userID uint, daysAgo int, mood int, relapsed bool, reflection string) models.CheckIn {
		t := now.AddDate(0, 0, -daysAgo)
		t = time.Date(t.Year(), t.Month(), t.Day(), 8, 30, 0, 0, t.Location())
		c := models.CheckIn{UserID: userID, MoodScore: mood, Relapsed: relapsed, Reflection: reflection}
		c.CreatedAt = t
		c.UpdatedAt = t
		return c
	}

	// seedDailyCIs generates daily clean check-ins with a simple mood pattern.
	// moodFn receives daysAgo (large = older) and returns a mood score 1–5.
	seedDailyCIs := func(userID uint, totalDays int, moodFn func(int) int, relapseOnDaysAgo ...int) {
		relapseSet := map[int]bool{}
		for _, d := range relapseOnDaysAgo {
			relapseSet[d] = true
		}
		for daysAgo := totalDays - 1; daysAgo >= 0; daysAgo-- {
			relapsed := relapseSet[daysAgo]
			reflection := ""
			if relapsed {
				reflection = "Had a really hard day. I slipped. But I'm getting back up."
			}
			c := ci(userID, daysAgo, moodFn(daysAgo), relapsed, reflection)
			db.Create(&c)
		}
	}

	// ── Users ────────────────────────────────────────────────────────────────
	//
	// Four groups, each with a distinct feel:
	//   London Alcohol    — established, warm, months into recovery
	//   London Gambling   — newer, more urgent, some early instability
	//   Manchester Subst. — quiet and candid, prefers in-person
	//   New York Smoking  — milestone-focused, most positive

	// Group 1: London Alcohol Recovery
	alice  := models.User{PhoneNumber: "+44700000001", Password: pw, Alias: "Alice",  Role: "leader"}
	marcus := models.User{PhoneNumber: "+44700000005", Password: pw, Alias: "Marcus", Role: "sponsor", IsAvailable: true}
	bob    := models.User{PhoneNumber: "+44700000002", Password: pw, Alias: "Bob",    Role: "apprentice"}
	nora   := models.User{PhoneNumber: "+44700000007", Password: pw, Alias: "Nora",   Role: "apprentice"}
	ray    := models.User{PhoneNumber: "+44700000008", Password: pw, Alias: "Ray",    Role: "apprentice"}

	// Group 2: London Gambling Recovery
	carol  := models.User{PhoneNumber: "+44700000003", Password: pw, Alias: "Carol",  Role: "leader"}
	sophie := models.User{PhoneNumber: "+44700000006", Password: pw, Alias: "Sophie", Role: "sponsor", IsAvailable: true}
	dan    := models.User{PhoneNumber: "+44700000004", Password: pw, Alias: "Dan",    Role: "apprentice"}
	priya  := models.User{PhoneNumber: "+44700000009", Password: pw, Alias: "Priya",  Role: "apprentice"}
	liam   := models.User{PhoneNumber: "+44700000010", Password: pw, Alias: "Liam",   Role: "apprentice"}

	// Group 3: Manchester Substance Support
	henry := models.User{PhoneNumber: "+44161000001", Password: pw, Alias: "Henry", Role: "leader"}
	isla  := models.User{PhoneNumber: "+44161000002", Password: pw, Alias: "Isla",  Role: "sponsor", IsAvailable: true}
	theo  := models.User{PhoneNumber: "+44161000003", Password: pw, Alias: "Theo",  Role: "apprentice"}
	chloe := models.User{PhoneNumber: "+44161000004", Password: pw, Alias: "Chloe", Role: "apprentice"}

	// Group 4: New York Smoking Cessation
	eve   := models.User{PhoneNumber: "+1200000001", Password: pw, Alias: "Eve",   Role: "leader"}
	frank := models.User{PhoneNumber: "+1200000002", Password: pw, Alias: "Frank", Role: "sponsor", IsAvailable: true}
	grace := models.User{PhoneNumber: "+1200000003", Password: pw, Alias: "Grace", Role: "apprentice"}
	zoe   := models.User{PhoneNumber: "+1200000004", Password: pw, Alias: "Zoe",   Role: "apprentice"}
	dev   := models.User{PhoneNumber: "+1200000005", Password: pw, Alias: "Dev",   Role: "apprentice"}

	all := []*models.User{
		&alice, &marcus, &bob, &nora, &ray,
		&carol, &sophie, &dan, &priya, &liam,
		&henry, &isla, &theo, &chloe,
		&eve, &frank, &grace, &zoe, &dev,
	}
	for _, u := range all {
		db.Create(u)
	}

	// ── Groups ───────────────────────────────────────────────────────────────

	londonAlcohol        := models.Group{Name: "Alcohol Recovery",   AddictionType: "Alcohol",  Location: "London",     LeaderID: alice.ID}
	londonGambling       := models.Group{Name: "Gambling Recovery",  AddictionType: "Gambling", Location: "London",     LeaderID: carol.ID}
	manchesterSubstances := models.Group{Name: "Substance Support",  AddictionType: "Drugs",    Location: "Manchester", LeaderID: henry.ID}
	newYorkSmoking       := models.Group{Name: "Smoking Cessation",  AddictionType: "Smoking",  Location: "New York",   LeaderID: eve.ID}

	for _, g := range []*models.Group{&londonAlcohol, &londonGambling, &manchesterSubstances, &newYorkSmoking} {
		db.Create(g)
	}

	// Assign users to groups and wire sponsor connections
	db.Model(&alice).Updates(map[string]interface{}{"group_id": londonAlcohol.ID})
	db.Model(&marcus).Updates(map[string]interface{}{"group_id": londonAlcohol.ID})
	db.Model(&bob).Updates(map[string]interface{}{"group_id": londonAlcohol.ID, "sponsor_id": marcus.ID})
	db.Model(&nora).Updates(map[string]interface{}{"group_id": londonAlcohol.ID})
	db.Model(&ray).Updates(map[string]interface{}{"group_id": londonAlcohol.ID, "sponsor_id": marcus.ID})

	db.Model(&carol).Updates(map[string]interface{}{"group_id": londonGambling.ID})
	db.Model(&sophie).Updates(map[string]interface{}{"group_id": londonGambling.ID})
	db.Model(&dan).Updates(map[string]interface{}{"group_id": londonGambling.ID, "sponsor_id": sophie.ID})
	db.Model(&priya).Updates(map[string]interface{}{"group_id": londonGambling.ID})
	db.Model(&liam).Updates(map[string]interface{}{"group_id": londonGambling.ID, "sponsor_id": sophie.ID})

	db.Model(&henry).Updates(map[string]interface{}{"group_id": manchesterSubstances.ID})
	db.Model(&isla).Updates(map[string]interface{}{"group_id": manchesterSubstances.ID})
	db.Model(&theo).Updates(map[string]interface{}{"group_id": manchesterSubstances.ID, "sponsor_id": isla.ID})
	db.Model(&chloe).Updates(map[string]interface{}{"group_id": manchesterSubstances.ID, "sponsor_id": isla.ID})

	db.Model(&eve).Updates(map[string]interface{}{"group_id": newYorkSmoking.ID})
	db.Model(&frank).Updates(map[string]interface{}{"group_id": newYorkSmoking.ID})
	db.Model(&grace).Updates(map[string]interface{}{"group_id": newYorkSmoking.ID, "sponsor_id": frank.ID})
	db.Model(&zoe).Updates(map[string]interface{}{"group_id": newYorkSmoking.ID})
	db.Model(&dev).Updates(map[string]interface{}{"group_id": newYorkSmoking.ID, "sponsor_id": frank.ID})

	// ── Check-ins ────────────────────────────────────────────────────────────
	//
	// Mood scores: 1=very bad 2=bad 3=okay 4=good 5=great
	// Each user's trajectory tells a story.
	// Leaders and sponsors get check-ins too — their days_clean derives from these.

	// Alice — leader, 214 days. Long-haul, settled and mostly positive.
	seedDailyCIs(alice.ID, 214, func(d int) int {
		if d > 180 { return 2 + d%2 }
		if d > 120 { return 3 }
		if d > 60  { return 4 }
		return 4 + (214-d)%2
	})

	// Marcus — sponsor, 180 days. One early rough patch, steady ever since.
	seedDailyCIs(marcus.ID, 180, func(d int) int {
		if d > 160 { return 2 }
		if d > 100 { return 3 }
		return 4 + d%2
	})

	// Bob — 84 clean days. Shaky start, steadily finding his footing.
	seedDailyCIs(bob.ID, 84, func(d int) int {
		if d > 60 { return 2 + d%2 }
		if d > 30 { return 3 }
		return 3 + (d+1)%2
	})

	// Nora — 21 days. New, mood is all over the place.
	seedDailyCIs(nora.ID, 21, func(d int) int { return 1 + d%4 })

	// Ray — 60 days. Relapsed 14 days ago. Mood dipped, now recovering.
	seedDailyCIs(ray.ID, 60, func(d int) int {
		if d > 30 { return 3 }
		if d >= 12 && d <= 16 { return 2 }
		return 3 + (60-d)%2
	}, 14)

	// Carol — leader, 100 days. Newer to leadership, still finding her voice.
	seedDailyCIs(carol.ID, 100, func(d int) int {
		if d > 80 { return 2 + d%2 }
		if d > 40 { return 3 }
		return 4 + d%2
	})

	// Sophie — sponsor, 92 days. Relapsed once early (day 85), clean since.
	seedDailyCIs(sophie.ID, 92, func(d int) int {
		if d > 82 { return 2 }
		if d > 50 { return 3 + d%2 }
		return 4 + (92-d)%2
	}, 85)

	// Dan — 92 days. Relapsed very early on (day 79 ago). Long clean run since.
	seedDailyCIs(dan.ID, 92, func(d int) int {
		if d > 75 { return 2 }
		if d > 40 { return 3 }
		return 4 + d%2
	}, 79)

	// Priya — 14 days. Just starting out. Low moods but climbing.
	seedDailyCIs(priya.ID, 14, func(d int) int { return 1 + (14-d)%3 })

	// Liam — 55 days. Steady, unremarkable improvement.
	seedDailyCIs(liam.ID, 55, func(d int) int {
		if d > 35 { return 2 + d%2 }
		return 3 + d%2
	})

	// Henry — leader, 150 days. Quiet and consistent, rarely misses a check-in.
	seedDailyCIs(henry.ID, 150, func(d int) int {
		if d > 130 { return 3 }
		if d > 80  { return 3 + d%2 }
		return 4 + (150-d)%2
	})

	// Isla — sponsor, 130 days. Took an early stumble, nothing since.
	seedDailyCIs(isla.ID, 130, func(d int) int {
		if d > 120 { return 2 }
		if d > 70  { return 3 }
		return 4 + d%2
	}, 122)

	// Chloe — 120 days. Two early slips, a long clean run after.
	seedDailyCIs(chloe.ID, 120, func(d int) int {
		if d > 110 { return 1 }
		if d > 85 { return 2 + d%2 }
		if d > 50 { return 3 }
		return 4 + (120-d)%2
	}, 113, 88)

	// Theo — 21 days. Relapsed a week ago. Currently fragile.
	seedDailyCIs(theo.ID, 21, func(d int) int {
		if d > 9 { return 2 + d%2 }
		if d >= 6 && d <= 8 { return 1 }
		return 3
	}, 7)

	// Eve — leader, 200 days. Milestone-focused, mostly great, a dip around day 160.
	seedDailyCIs(eve.ID, 200, func(d int) int {
		if d > 180 { return 3 }
		if d > 155 && d < 170 { return 2 }
		if d > 100 { return 4 }
		return 5
	})

	// Frank — sponsor, 155 days. Positive and consistent; coaches through optimism.
	seedDailyCIs(frank.ID, 155, func(d int) int {
		if d > 140 { return 3 }
		if d > 80  { return 4 }
		return 4 + (155-d)%2
	})

	// Grace — 65 clean days. Consistent and positive.
	seedDailyCIs(grace.ID, 65, func(d int) int {
		if d > 50 { return 3 }
		if d > 20 { return 4 }
		return 4 + (65-d)%2
	})

	// Dev — 45 days. Gradually improving.
	seedDailyCIs(dev.ID, 45, func(d int) int {
		if d > 30 { return 2 + d%2 }
		return 3 + (45-d)%2
	})

	// Zoe — 3 days. Just started, scared but determined.
	seedDailyCIs(zoe.ID, 3, func(d int) int { return 2 + (3-d) })

	// ── Group messages ────────────────────────────────────────────────────────

	messages := []models.Message{

		// ── London Alcohol — established, warm, people know each other ──

		msg(londonAlcohol.ID, alice.ID,  "Alice",  "leader",     "Morning check-in. Day 214 for me. Still here, still showing up. How's everyone doing today?", 72),
		msg(londonAlcohol.ID, bob.ID,    "Bob",    "apprentice", "Day 84. I actually slept properly last night for the first time in weeks.", 71.5),
		msg(londonAlcohol.ID, marcus.ID, "Marcus", "sponsor",    "That matters more than people realise. Sleep is when you heal.", 71),
		msg(londonAlcohol.ID, nora.ID,   "Nora",   "apprentice", "Day 21 here. Still feels surreal to count days. Does it get less strange?", 70),
		msg(londonAlcohol.ID, alice.ID,  "Alice",  "leader",     "It does, Nora. Eventually it becomes background noise. The counting stops feeling urgent.", 69),
		msg(londonAlcohol.ID, bob.ID,    "Bob",    "apprentice", "For me it still matters. Each one is proof I did it.", 68),
		msg(londonAlcohol.ID, marcus.ID, "Marcus", "sponsor",    "Both true. Some people stop counting eventually. Some keep going. Neither is wrong.", 67),
		msg(londonAlcohol.ID, ray.ID,    "Ray",    "apprentice", "I have to be honest — I slipped two weeks ago. I've been avoiding saying it here.", 48),
		msg(londonAlcohol.ID, alice.ID,  "Alice",  "leader",     "Thank you for saying it, Ray. That took guts.", 47.5),
		msg(londonAlcohol.ID, marcus.ID, "Marcus", "sponsor",    "You're still here. That's the bit that counts. What happened, if you want to talk about it?", 47),
		msg(londonAlcohol.ID, ray.ID,    "Ray",    "apprentice", "Wedding anniversary. Thought I had it handled. Didn't.", 46.5),
		msg(londonAlcohol.ID, bob.ID,    "Bob",    "apprentice", "Those days are the hardest. No one warns you about the dates.", 46),
		msg(londonAlcohol.ID, alice.ID,  "Alice",  "leader",     "Ray — let's talk before the next session. I want to help you plan around these dates going forward.", 45),
		msg(londonAlcohol.ID, ray.ID,    "Ray",    "apprentice", "I'd like that. Thank you.", 44),
		msg(londonAlcohol.ID, nora.ID,   "Nora",   "apprentice", "Watching this group makes me feel less alone about my own stuff. Thank you all.", 24),
		msg(londonAlcohol.ID, marcus.ID, "Marcus", "sponsor",    "That's exactly why we're here. You don't have to hold it alone.", 23.5),
		msg(londonAlcohol.ID, alice.ID,  "Alice",  "leader",     "Reminder: weekly session is Thursday at 7pm, Bridge Community Centre Room 4. Be there if you can.", 8),
		msg(londonAlcohol.ID, bob.ID,    "Bob",    "apprentice", "I'll be there.", 7.5),
		msg(londonAlcohol.ID, ray.ID,    "Ray",    "apprentice", "Same. See you all Thursday.", 7),

		// ── London Gambling — newer group, more urgent energy ──

		msg(londonGambling.ID, carol.ID,  "Carol",  "leader",     "New week. How did everyone get through the weekend?", 96),
		msg(londonGambling.ID, dan.ID,    "Dan",    "apprentice", "Honestly, Saturday was fine. Sunday I had an itch but it passed. Day 92.", 95),
		msg(londonGambling.ID, carol.ID,  "Carol",  "leader",     "Day 92. Dan, that is remarkable. What did you do when the itch came?", 94),
		msg(londonGambling.ID, dan.ID,    "Dan",    "apprentice", "Called Sophie. Went for a walk. Watched a film. By the time it ended, the feeling was gone.", 93),
		msg(londonGambling.ID, sophie.ID, "Sophie", "sponsor",    "That call meant a lot. I'm glad you made it.", 92.5),
		msg(londonGambling.ID, liam.ID,   "Liam",   "apprentice", "Day 55 for me. I realised I haven't thought about the casino in a week. Weird feeling.", 92),
		msg(londonGambling.ID, carol.ID,  "Carol",  "leader",     "That's the brain rewiring. It can feel strange when the craving just isn't there.", 91),
		msg(londonGambling.ID, priya.ID,  "Priya",  "apprentice", "I'm on day 14. I keep getting urges in the evenings. It's like my brain knows when the apps used to come out.", 50),
		msg(londonGambling.ID, sophie.ID, "Sophie", "sponsor",    "That's a very normal pattern. What are you doing in those moments?", 49.5),
		msg(londonGambling.ID, priya.ID,  "Priya",  "apprentice", "Mostly scrolling. Which I know isn't great.", 49),
		msg(londonGambling.ID, dan.ID,    "Dan",    "apprentice", "Replace the scroll with something tactile. I started doing puzzles. Sounds dull but it works.", 48.5),
		msg(londonGambling.ID, carol.ID,  "Carol",  "leader",     "Priya — would it help to find a sponsor? Sophie has space and she'd be a great fit.", 48),
		msg(londonGambling.ID, priya.ID,  "Priya",  "apprentice", "I think I'd like that, actually.", 47.5),
		msg(londonGambling.ID, sophie.ID, "Sophie", "sponsor",    "Let's set up a call this week, Priya. No pressure, just a chat.", 47),
		msg(londonGambling.ID, liam.ID,   "Liam",   "apprentice", "This group literally saved me from a bet last Tuesday. I posted here instead of opening the app. Just want to say that.", 25),
		msg(londonGambling.ID, carol.ID,  "Carol",  "leader",     "That's the whole point of this space, Liam. Well done.", 24.5),
		msg(londonGambling.ID, dan.ID,    "Dan",    "apprentice", "Next session is Wednesday. Who's coming?", 12),
		msg(londonGambling.ID, liam.ID,   "Liam",   "apprentice", "I'm in.", 11.5),
		msg(londonGambling.ID, priya.ID,  "Priya",  "apprentice", "Me too. First one in person.", 11),
		msg(londonGambling.ID, carol.ID,  "Carol",  "leader",     "Brilliant. See you all then.", 10.5),

		// ── Manchester Substances — quiet, in-person-first, honest ──

		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader",    "Checking in on everyone. Haven't heard from Theo since Thursday.", 120),
		msg(manchesterSubstances.ID, isla.ID,  "Isla",  "sponsor",   "I spoke to him yesterday. He's okay. Had a rough week but he's stable.", 119),
		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader",    "Good. Thank you for staying close to him, Isla.", 118.5),
		msg(manchesterSubstances.ID, chloe.ID, "Chloe", "apprentice","Day 120 today. I keep expecting it to feel bigger than it does.", 118),
		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader",    "What does it feel like?", 117.5),
		msg(manchesterSubstances.ID, chloe.ID, "Chloe", "apprentice","Quiet. Like the loud part is over and now it's just... living.", 117),
		msg(manchesterSubstances.ID, isla.ID,  "Isla",  "sponsor",   "That's what it's supposed to feel like. You've done real work to get there.", 116.5),
		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader",    "Quiet is underrated. Most people spend years chasing quiet.", 116),
		msg(manchesterSubstances.ID, theo.ID,  "Theo",  "apprentice","I'm here. Sorry I went dark. Slipped last week. Day 7 again.", 72),
		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader",    "Glad you're back, Theo. Day 7 is a beginning. You've done it before.", 71.5),
		msg(manchesterSubstances.ID, isla.ID,  "Isla",  "sponsor",   "I'm here when you need to talk. Same number.", 71),
		msg(manchesterSubstances.ID, chloe.ID, "Chloe", "apprentice","I had two slips in my first three months. You keep going. That's all there is to it.", 70.5),
		msg(manchesterSubstances.ID, theo.ID,  "Theo",  "apprentice","Thanks. I hate that I'm back at the start but this group helps.", 70),
		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader",    "You're not starting over. You're continuing. The work you did before still counts.", 69),
		msg(manchesterSubstances.ID, isla.ID,  "Isla",  "sponsor",   "Thursday session is still on. The Cornerhouse, 6:30. Please come, Theo.", 24),
		msg(manchesterSubstances.ID, theo.ID,  "Theo",  "apprentice","I'll be there.", 23.5),
		msg(manchesterSubstances.ID, chloe.ID, "Chloe", "apprentice","See you all there.", 23),

		// ── New York Smoking — milestones, lighter tone, practical tips ──

		msg(newYorkSmoking.ID, grace.ID, "Grace", "apprentice","Day 65. I can run a full block without coughing. That's new.", 96),
		msg(newYorkSmoking.ID, eve.ID,   "Eve",   "leader",    "Grace! That's exactly the kind of thing that keeps you going.", 95.5),
		msg(newYorkSmoking.ID, frank.ID, "Frank", "sponsor",   "Lung function starts recovering around week 4. By month 3 it's noticeably better. You're right on track.", 95),
		msg(newYorkSmoking.ID, dev.ID,   "Dev",   "apprentice","Day 45 here. The afternoon craving at 3pm is still brutal.", 94),
		msg(newYorkSmoking.ID, frank.ID, "Frank", "sponsor",   "What's your 3pm usually look like?", 93.5),
		msg(newYorkSmoking.ID, dev.ID,   "Dev",   "apprentice","Desk job. That's when I used to step out. Now I just sit there craving the step out as much as the cigarette.", 93),
		msg(newYorkSmoking.ID, grace.ID, "Grace", "apprentice","Take the step out anyway. Just without the cigarette. Your brain needs the break, not the nicotine.", 92.5),
		msg(newYorkSmoking.ID, eve.ID,   "Eve",   "leader",    "That's exactly right. The ritual matters. Just change what's in your hand.", 92),
		msg(newYorkSmoking.ID, dev.ID,   "Dev",   "apprentice","Tried it today. Took a walk with a coffee instead. Actually helped.", 48),
		msg(newYorkSmoking.ID, frank.ID, "Frank", "sponsor",   "Small wins. That's the whole game.", 47.5),
		msg(newYorkSmoking.ID, zoe.ID,   "Zoe",   "apprentice","Hi everyone. Day 3 for me. I caved and looked up how long withdrawal lasts and now I'm terrified.", 36),
		msg(newYorkSmoking.ID, eve.ID,   "Eve",   "leader",    "Welcome, Zoe. Day 3 is one of the hardest. The physical stuff peaks and then it starts to ease.", 35.5),
		msg(newYorkSmoking.ID, frank.ID, "Frank", "sponsor",   "Most people find days 3–5 the worst for physical cravings. After that it shifts to habit and trigger. Different battle, more manageable.", 35),
		msg(newYorkSmoking.ID, grace.ID, "Grace", "apprentice","I remember day 3. I ate an embarrassing amount of gummy bears. Do what you have to do.", 34.5),
		msg(newYorkSmoking.ID, zoe.ID,   "Zoe",   "apprentice","Ha. Already raided the snacks. Good to know it's normal.", 34),
		msg(newYorkSmoking.ID, dev.ID,   "Dev",   "apprentice","Day 3 you just need to survive. You're doing it.", 33.5),
		msg(newYorkSmoking.ID, eve.ID,   "Eve",   "leader",    "Monthly group call is Friday 7pm ET. I'll post the link Thursday. All welcome.", 12),
		msg(newYorkSmoking.ID, grace.ID, "Grace", "apprentice","On it.", 11.5),
		msg(newYorkSmoking.ID, dev.ID,   "Dev",   "apprentice","Same.", 11),
		msg(newYorkSmoking.ID, zoe.ID,   "Zoe",   "apprentice","I'll try to make it. Thank you all.", 10.5),
	}
	for i := range messages {
		db.Create(&messages[i])
	}

	// ── Direct messages ───────────────────────────────────────────────────────

	dms := []models.DirectMessage{
		// Bob ↔ Marcus — late night check-in
		dm(bob.ID, marcus.ID, "Bob", "apprentice", "Marcus — just checking in. Had a weird evening. Not in danger but just wanted to say it to someone.", 18),
		dm(marcus.ID, bob.ID, "Marcus", "sponsor", "Glad you reached out. Tell me what happened.", 17.5),
		dm(bob.ID, marcus.ID, "Bob", "apprentice", "Old friend texted asking if I wanted to go for drinks. I said no but it sat with me all night.", 17),
		dm(marcus.ID, bob.ID, "Marcus", "sponsor", "You said no. That's the whole win. The feelings afterwards are just the grief of the old you. They pass.", 16.5),
		dm(bob.ID, marcus.ID, "Bob", "apprentice", "Thanks. I'm okay. Going to sleep. See you Thursday.", 16),
		dm(marcus.ID, bob.ID, "Marcus", "sponsor", "Good. Sleep well. Proud of you.", 15.5),

		// Dan ↔ Sophie — pre-session nerves
		dm(dan.ID, sophie.ID, "Dan", "apprentice", "Sophie, quick one before Wednesday — I'm thinking of sharing something personal with the group. Is that okay?", 30),
		dm(sophie.ID, dan.ID, "Sophie", "sponsor", "Of course. This is what the space is for. What are you thinking of sharing?", 29.5),
		dm(dan.ID, sophie.ID, "Dan", "apprentice", "The relapse early on. I've never said it out loud in a group setting. Feels like it might help Priya to hear it.", 29),
		dm(sophie.ID, dan.ID, "Sophie", "sponsor", "That would be incredibly generous of you. Only if you feel ready. You don't owe anyone your story.", 28.5),
		dm(dan.ID, sophie.ID, "Dan", "apprentice", "I think I am. 92 days gives me perspective on it now.", 28),
		dm(sophie.ID, dan.ID, "Sophie", "sponsor", "Then share it. It will land exactly the way you mean it.", 27.5),

		// Theo ↔ Isla — after the crisis
		dm(isla.ID, theo.ID, "Isla", "sponsor", "Theo. How are you doing today? No rush, just checking in.", 60),
		dm(theo.ID, isla.ID, "Theo", "apprentice", "Better than last week. Still shaky but I didn't use yesterday.", 59.5),
		dm(isla.ID, theo.ID, "Isla", "sponsor", "That's everything. One day at a time is not a cliché — it's actually the only way through.", 59),
		dm(theo.ID, isla.ID, "Theo", "apprentice", "I keep thinking about what you said when you came round. That you'd had slips too. It made it feel less like I was the worst person.", 58.5),
		dm(isla.ID, theo.ID, "Isla", "sponsor", "You're not the worst person. You're a person doing one of the hardest things there is.", 58),
	}
	for i := range dms {
		db.Create(&dms[i])
	}

	// ── Meetings ─────────────────────────────────────────────────────────────

	pastDay := func(daysAgo, hour int) time.Time {
		d := now.AddDate(0, 0, -daysAgo)
		return time.Date(d.Year(), d.Month(), d.Day(), hour, 0, 0, 0, d.Location())
	}
	futureDay := func(daysAhead, hour int) time.Time {
		d := now.AddDate(0, 0, daysAhead)
		return time.Date(d.Year(), d.Month(), d.Day(), hour, 0, 0, 0, d.Location())
	}

	meetings := []models.Meeting{
		// London Alcohol
		{GroupID: londonAlcohol.ID, Title: "Weekly group session", Location: "Bridge Community Centre, Room 4, London", Note: "Bring nothing but yourself.", ScheduledAt: pastDay(7, 19), CreatedByID: alice.ID, CreatedByAlias: "Alice", CreatedByRole: "leader"},
		{GroupID: londonAlcohol.ID, Title: "Weekly group session", Location: "Bridge Community Centre, Room 4, London", Note: "", ScheduledAt: futureDay(3, 19), CreatedByID: alice.ID, CreatedByAlias: "Alice", CreatedByRole: "leader"},
		{GroupID: londonAlcohol.ID, Title: "Three-month milestone celebration", Location: "Bridge Community Centre, Room 4, London", Note: "For anyone at or past 90 days. We celebrate together.", ScheduledAt: futureDay(17, 18), CreatedByID: alice.ID, CreatedByAlias: "Alice", CreatedByRole: "leader"},

		// London Gambling
		{GroupID: londonGambling.ID, Title: "Introduction session", Location: "Southwark Library, Meeting Room 2, London", Note: "Welcome to new members. No pressure to share.", ScheduledAt: pastDay(21, 18), CreatedByID: carol.ID, CreatedByAlias: "Carol", CreatedByRole: "leader"},
		{GroupID: londonGambling.ID, Title: "Weekly check-in", Location: "Southwark Library, Meeting Room 2, London", Note: "", ScheduledAt: futureDay(2, 18), CreatedByID: carol.ID, CreatedByAlias: "Carol", CreatedByRole: "leader"},
		{GroupID: londonGambling.ID, Title: "Sponsor one-to-ones", Location: "Southwark Library, Quiet Study Area, London", Note: "Sophie will be available for individual 20-minute slots from 5–7pm.", ScheduledAt: futureDay(9, 17), CreatedByID: sophie.ID, CreatedByAlias: "Sophie", CreatedByRole: "sponsor"},

		// Manchester Substances
		{GroupID: manchesterSubstances.ID, Title: "Thursday session", Location: "The Cornerhouse, Room B, Manchester", Note: "", ScheduledAt: pastDay(4, 18), CreatedByID: henry.ID, CreatedByAlias: "Henry", CreatedByRole: "leader"},
		{GroupID: manchesterSubstances.ID, Title: "Thursday session", Location: "The Cornerhouse, Room B, Manchester", Note: "Theo — please come if you can. No pressure.", ScheduledAt: futureDay(3, 18), CreatedByID: henry.ID, CreatedByAlias: "Henry", CreatedByRole: "leader"},

		// New York Smoking
		{GroupID: newYorkSmoking.ID, Title: "Monthly group call", Location: "Video call — link posted in group chat", Note: "Celebrating Grace at 65 days and Dev at 45.", ScheduledAt: futureDay(4, 19), CreatedByID: eve.ID, CreatedByAlias: "Eve", CreatedByRole: "leader"},
		{GroupID: newYorkSmoking.ID, Title: "Monthly group call", Location: "Video call — link posted in group chat", Note: "", ScheduledAt: pastDay(26, 19), CreatedByID: eve.ID, CreatedByAlias: "Eve", CreatedByRole: "leader"},
	}
	for i := range meetings {
		db.Create(&meetings[i])
	}

	// ── Community posts ───────────────────────────────────────────────────────
	//
	// Published long-form stories visible to anonymous users.
	// A mix of featured (pinned this week) and regular.

	currentWeek := now.Format("2006-W") + fmt.Sprintf("%02d", isoWeek(now))

	posts := []models.Post{
		{
			AuthorID: marcus.ID, AuthorAlias: "Marcus", AddictionType: "Alcohol",
			Title: "What six months sober taught me",
			Content: `Six months ago I couldn't imagine writing this. I was the person who said recovery was for other people — the ones who'd really hit rock bottom, not someone like me who "had it under control."

What changed was a conversation with my brother. He didn't lecture me. He just said he missed me, and that the person he was talking to didn't feel like his brother anymore. I still don't fully understand why that got through when nothing else had. But it did.

The first weeks were physical. The shaking, the sweating, the nights where sleep was impossible. I won't pretend it was peaceful. It wasn't. But the group got me through it. Not with grand gestures — with small things. A message at 11pm saying "still awake if you need to talk." That was enough.

What six months has given me: a morning that doesn't start with calculating how much I drank the night before. An ability to be present in a conversation without half my brain elsewhere. The knowledge that I can handle a bad day without something to take the edge off.

Recovery is not the absence of difficulty. It's learning that difficulty doesn't have to end a certain way.`,
			Status: "published", Featured: true, FeaturedWeek: currentWeek,
		},
		{
			AuthorID: alice.ID, AuthorAlias: "Alice", AddictionType: "Alcohol",
			Title: "The moment I decided to ask for help",
			Content: `I used to think asking for help was admitting defeat. I grew up in a house where you sorted things yourself. Struggling wasn't done out loud.

The moment I decided to ask for help was mundane, as it turns out. I was standing in a supermarket car park at 8am, unable to go in, because I knew I'd walk out with wine. I just stood there. For twenty minutes. And I thought — I cannot keep doing this by myself.

That evening I googled what I thought were very vague terms, convinced I didn't have "a problem." The results took me to a page with a number I could call. I sat staring at it for an hour. Then I called.

The person on the other end didn't ask me how much I drank or how often. They just asked how I was doing. I cried, which I hadn't expected. They said that was normal. It was the most helpful thing anyone had said to me in years.

If you're on the fence about reaching out: the version of yourself who's managing it alone is not coping better. They're just coping privately.`,
			Status: "published",
		},
		{
			AuthorID: sophie.ID, AuthorAlias: "Sophie", AddictionType: "Gambling",
			Title: "Being a sponsor when you're still learning too",
			Content: `I became a sponsor eighteen months into my own recovery. I want to be honest: I wasn't sure I was ready. I still had bad days. I still had the occasional dream where I was back in the casino and felt the pull of it.

What I've learned is that sponsoring isn't about having all the answers. It's about being someone who shows up consistently. The person I sponsor doesn't need me to be perfect. They need me to be present and to answer the phone.

There's something unexpected about it too. Explaining the tools of recovery to someone else has clarified them for me. I understand my own patterns better because I've had to articulate them.

If you're wondering whether you're "recovered enough" to help someone else: you probably are. The only question is whether you can hold space for someone else's struggle without it overwhelming your own. That's a conversation worth having with yourself before you start.`,
			Status: "published",
		},
		{
			AuthorID: henry.ID, AuthorAlias: "Henry", AddictionType: "Drugs",
			Title: "Recovery in the grey area",
			Content: `Most stories about recovery have a clear before and after. The person they were, and the person they became. I've never had that. My recovery has been slower, less cinematic, and more about incremental shifts than a single turning point.

I think there are a lot of people for whom that's true, and I don't see their stories told very often.

For me, recovery has meant learning to sit with uncertainty. Early on I wanted to know that I was "fixed." I kept looking for the moment when I could say it was behind me. What I've found instead is that recovery is ongoing — not because I'm failing, but because that's what it is. A practice, not a destination.

The grey area is uncomfortable. But it's also honest. And honesty, for me, is where the work actually happens.`,
			Status: "published",
		},
		{
			AuthorID: frank.ID, AuthorAlias: "Frank", AddictionType: "Smoking",
			Title: "Five things that actually helped me quit",
			Content: `I tried to quit four times before it stuck. Here's what was different the last time.

1. I stopped trying to quit forever. "Never again" felt impossible and abstract. Instead I committed to today. Just today I won't smoke. I've been doing that for two and a half years.

2. I told people. Every time before, I'd kept it private — less embarrassing if I failed. But keeping it private also meant no one knew to support me. Telling people created accountability I didn't know I needed.

3. I changed my routes and routines. The after-lunch walk past the same spot where I always lit up had to go. I don't care how small it sounds — removing the physical trigger mattered enormously.

4. I got honest about the emotional function. I didn't just smoke out of habit. I smoked when I was stressed, lonely, or avoiding something. I had to learn other ways to handle those feelings.

5. I found people doing the same thing. This group is part of that. You don't have to explain yourself to someone who's been there.

None of this is revolutionary. But it's what worked.`,
			Status: "published",
		},
		{
			AuthorID: grace.ID, AuthorAlias: "Grace", AddictionType: "Smoking",
			Title: "Day 30: what nobody tells you",
			Content: `Everyone talks about the first week. The cravings, the irritability, the headaches. There's plenty of content about that.

Nobody really told me about day 30.

By day 30 the acute physical stuff is mostly gone. But the psychological piece is still very much there, and in some ways it's more confusing because it's less dramatic. You have a bad moment and you reach for a cigarette that isn't there. Not because your body needs it, but because your brain has spent years filing it under "solution."

Day 30 is when you start having to actually grieve the thing. Not just get through it.

What helped me: letting myself be sad about it. I missed smoking. The ritual of it, the excuse to step outside, the thing I did when I didn't know what to do with my hands. Letting myself miss it, rather than telling myself I shouldn't, made it easier to let go.

You're allowed to miss it. You're also allowed to keep going.`,
			Status: "published",
		},
	}
	for i := range posts {
		db.Create(&posts[i])
	}

	// Feature Marcus's post for the London Alcohol group this week
	db.Create(&models.GroupFeature{
		PostID:       posts[0].ID,
		GroupID:      londonAlcohol.ID,
		FeaturedByID: alice.ID,
		FeaturedWeek: currentWeek,
	})
	// Feature Sophie's post for the London Gambling group
	db.Create(&models.GroupFeature{
		PostID:       posts[2].ID,
		GroupID:      londonGambling.ID,
		FeaturedByID: carol.ID,
		FeaturedWeek: currentWeek,
	})

	// ── Weekly prompts ────────────────────────────────────────────────────────

	week := func(weeksAgo int) string {
		t := now.AddDate(0, 0, -weeksAgo*7)
		y, w := t.ISOWeek()
		return fmt.Sprintf("%d-W%02d", y, w)
	}

	prompt0 := models.WeeklyPrompt{ISOWeek: week(0), PromptText: "What does your hardest hour look like — and what gets you through it?", SetByID: alice.ID, SetByAlias: "Alice", SetByRole: "leader"}
	prompt1 := models.WeeklyPrompt{ISOWeek: week(1), PromptText: "Describe the first day you decided to make a change. What made it different from the days before it?", SetByID: carol.ID, SetByAlias: "Carol", SetByRole: "leader"}
	prompt2 := models.WeeklyPrompt{ISOWeek: week(2), PromptText: "What is one thing recovery has given back to you that you didn't expect to get back?", SetByID: henry.ID, SetByAlias: "Henry", SetByRole: "leader"}

	for _, p := range []*models.WeeklyPrompt{&prompt0, &prompt1, &prompt2} {
		db.Create(p)
	}

	makeResponse := func(promptID, userID uint, alias, role, content string, daysAgo int) models.PromptResponse {
		t := now.AddDate(0, 0, -daysAgo)
		r := models.PromptResponse{PromptID: promptID, UserID: userID, UserAlias: alias, UserRole: role, Content: content}
		r.CreatedAt = t
		r.UpdatedAt = t
		return r
	}

	responses := []models.PromptResponse{
		// Current week — hardest hour
		makeResponse(prompt0.ID, bob.ID,   "Bob",   "apprentice", "About 9pm on a Friday. When the week is done and there used to be a reason to drink. I call Marcus or just put a film on and get to 10pm. 10pm is fine. It's always fine once I get there.", 1),
		makeResponse(prompt0.ID, dan.ID,   "Dan",   "apprentice", "Sunday afternoons. Football. Every ad break was a betting opportunity for years. Now I mute the ads or leave the room. It's stupid but it works.", 2),
		makeResponse(prompt0.ID, grace.ID, "Grace", "apprentice", "The walk to the train after work. I smoked that walk every day for six years. I still take the same walk, just faster now.", 1),
		makeResponse(prompt0.ID, chloe.ID, "Chloe", "apprentice", "3am. The time when nothing is happening and everything feels permanent. I make tea. I text the group even if no one replies. The act of reaching out is enough.", 2),
		makeResponse(prompt0.ID, isla.ID,  "Isla",  "sponsor",    "Stress with no obvious source. The low-grade hum of anxiety that used to have one answer. I've had to learn that it doesn't need an answer — just acknowledgement.", 3),

		// Last week — first day you decided to change
		makeResponse(prompt1.ID, ray.ID,   "Ray",   "apprentice", "My daughter didn't want me to walk her into school anymore. She was seven. I didn't ask why. I knew why.", 8),
		makeResponse(prompt1.ID, liam.ID,  "Liam",  "apprentice", "I checked my bank statements in the cold light of day. Not for the first time. But for the first time I let myself feel it instead of closing the app.", 9),
		makeResponse(prompt1.ID, dev.ID,   "Dev",   "apprentice", "I got a health scare that turned out to be nothing. But the fear of it was clarifying. I didn't want to do this to myself anymore.", 8),
		makeResponse(prompt1.ID, frank.ID, "Frank", "sponsor",    "My wife told me she was proud of me before I'd done anything yet. It was the most terrifying thing she could have said. I didn't want to let her down.", 10),

		// Two weeks ago — what recovery gave back
		makeResponse(prompt2.ID, alice.ID,  "Alice",  "leader",     "My memory. I lost years to fog. Getting it back has been disorienting and wonderful.", 15),
		makeResponse(prompt2.ID, marcus.ID, "Marcus", "sponsor",    "Patience. I was a short-tempered person. I thought that was just who I was. Turns out I was just self-medicating anxiety with alcohol and calling the irritability personality.", 15),
		makeResponse(prompt2.ID, sophie.ID, "Sophie", "sponsor",    "My appetite. Sounds small. Sitting down to eat a meal and actually tasting it is something I didn't have for years.", 16),
		makeResponse(prompt2.ID, theo.ID,   "Theo",   "apprentice", "I'm still early but: mornings. I didn't know mornings could be okay. I used to dread them.", 14),
	}
	for i := range responses {
		db.Create(&responses[i])
	}

	// ── Notifications ─────────────────────────────────────────────────────────

	notifAt := func(n *models.Notification, daysAgo int) *models.Notification {
		t := now.AddDate(0, 0, -daysAgo)
		n.CreatedAt = t
		n.UpdatedAt = t
		return n
	}

	notifications := []*models.Notification{
		// Dan: eligible + pending become_sponsor_request to Carol
		notifAt(&models.Notification{RecipientID: carol.ID, SenderID: dan.ID, Type: "become_sponsor_request",
			Message: "Dan has met the eligibility threshold and would like to become a sponsor. Review his profile before approving."}, 2),

		// Bob: sponsor accepted (Marcus accepted Bob's request, long ago)
		notifAt(&models.Notification{RecipientID: bob.ID, SenderID: marcus.ID, Type: "sponsor_accepted",
			Message: "Marcus has accepted your sponsor request. You can now message them directly.", Read: true}, 80),

		// Ray: relapse alert sent to Marcus when Ray relapsed
		notifAt(&models.Notification{RecipientID: marcus.ID, SenderID: ray.ID, Type: "relapse_alert",
			Message: "Ray has logged a relapse. They may need extra support right now."}, 14),

		// Theo: relapse alert sent to Isla and Henry
		notifAt(&models.Notification{RecipientID: isla.ID, SenderID: theo.ID, Type: "relapse_alert",
			Message: "Theo has logged a relapse. They may need extra support right now."}, 7),
		notifAt(&models.Notification{RecipientID: henry.ID, SenderID: theo.ID, Type: "relapse_alert",
			Message: "Theo has logged a relapse. They may need extra support right now."}, 7),

		// Priya: sponsor request sent to Sophie (unread, Sophie has not acted yet)
		notifAt(&models.Notification{RecipientID: sophie.ID, SenderID: priya.ID, Type: "sponsor_request",
			Message: "Priya would like you to be their sponsor."}, 1),

		// Zoe: no sponsor connection yet, no notifications (she's brand new)

		// Grace: sponsor accepted notification (historical, read)
		notifAt(&models.Notification{RecipientID: grace.ID, SenderID: frank.ID, Type: "sponsor_accepted",
			Message: "Frank has accepted your sponsor request. You can now message them directly.", Read: true}, 62),
	}
	for _, n := range notifications {
		db.Create(n)
	}

	// ── Crisis alerts ─────────────────────────────────────────────────────────

	// Priya: a crisis alert from 3 days ago, stage 1, resolved by Sophie
	priyCrisisAt := now.AddDate(0, 0, -3)
	priyaCrisis := models.CrisisAlert{
		UserID: priya.ID, UserAlias: "Priya",
		GroupID:         londonGambling.ID,
		Stage:           1,
		Resolved:        true,
		ResolvedByID:    sophie.ID,
		ResolvedByAlias: "Sophie",
	}
	priyaCrisis.CreatedAt = priyCrisisAt
	priyaCrisis.UpdatedAt = priyCrisisAt.Add(20 * time.Minute)
	db.Create(&priyaCrisis)

	// Crisis notification for Sophie (resolved, read)
	sophieCrisisNotif := models.Notification{
		RecipientID: sophie.ID, SenderID: priya.ID,
		Type:    "crisis_alert",
		Message: "Priya has triggered the crisis button and needs immediate support.",
		Read:    true,
	}
	sophieCrisisNotif.CreatedAt = priyCrisisAt
	sophieCrisisNotif.UpdatedAt = priyCrisisAt
	db.Create(&sophieCrisisNotif)

	// Crisis responded notification back to Priya (read)
	priyaRespondedNotif := models.Notification{
		RecipientID: priya.ID, SenderID: sophie.ID,
		Type:    "crisis_responded",
		Message: "Sophie has responded to your crisis alert and is on their way.",
		Read:    true,
	}
	priyaRespondedNotif.CreatedAt = priyCrisisAt.Add(5 * time.Minute)
	priyaRespondedNotif.UpdatedAt = priyaRespondedNotif.CreatedAt
	db.Create(&priyaRespondedNotif)

	// ── Become-sponsor pending request (Dan already has 92 check-ins above) ───
	db.Create(&models.Notification{
		RecipientID: carol.ID,
		SenderID:    dan.ID,
		Type:        "become_sponsor_request",
		Message:     "Dan has met the eligibility threshold and would like to become a sponsor.",
	})

	totalCIs := 84 + 21 + 60 + 92 + 14 + 55 + 120 + 21 + 65 + 45 + 3
	log.Printf("Seed complete: %d groups, %d users, %d messages, %d DMs, %d check-ins, %d posts, %d meetings, %d prompt responses\n",
		4, len(all), len(messages), len(dms), totalCIs, len(posts), len(meetings), len(responses))
}

func isoWeek(t time.Time) int {
	_, w := t.ISOWeek()
	return w
}
