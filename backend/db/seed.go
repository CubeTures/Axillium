package db

import (
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

	// ── Users ────────────────────────────────────────────────────────────────
	// Roles: leaders run their group, sponsors guide apprentices, apprentices are in recovery.

	alice := models.User{PhoneNumber: "+44700000001", Password: pw, Alias: "Alice", Role: "leader"}
	bob := models.User{PhoneNumber: "+44700000002", Password: pw, Alias: "Bob", Role: "apprentice"}
	marcus := models.User{PhoneNumber: "+44700000005", Password: pw, Alias: "Marcus", Role: "sponsor", IsAvailable: true}

	carol := models.User{PhoneNumber: "+44700000003", Password: pw, Alias: "Carol", Role: "leader"}
	dan := models.User{PhoneNumber: "+44700000004", Password: pw, Alias: "Dan", Role: "apprentice"}
	sophie := models.User{PhoneNumber: "+44700000006", Password: pw, Alias: "Sophie", Role: "sponsor", IsAvailable: true}

	eve := models.User{PhoneNumber: "+1200000001", Password: pw, Alias: "Eve", Role: "leader"}
	frank := models.User{PhoneNumber: "+1200000002", Password: pw, Alias: "Frank", Role: "sponsor", IsAvailable: true}
	grace := models.User{PhoneNumber: "+1200000003", Password: pw, Alias: "Grace", Role: "apprentice"}

	henry := models.User{PhoneNumber: "+44161000001", Password: pw, Alias: "Henry", Role: "leader"}
	isla := models.User{PhoneNumber: "+44161000002", Password: pw, Alias: "Isla", Role: "sponsor", IsAvailable: true}

	for _, u := range []*models.User{&alice, &bob, &marcus, &carol, &dan, &sophie, &eve, &frank, &grace, &henry, &isla} {
		db.Create(u)
	}

	// ── Groups ───────────────────────────────────────────────────────────────

	londonAlcohol := models.Group{
		Name:          "Alcohol Recovery",
		AddictionType: "Alcohol",
		Location:      "London",
		LeaderID:      alice.ID,
	}
	londonGambling := models.Group{
		Name:          "Gambling Recovery",
		AddictionType: "Gambling",
		Location:      "London",
		LeaderID:      carol.ID,
	}
	manchesterSubstances := models.Group{
		Name:          "Substance Support",
		AddictionType: "Substances",
		Location:      "Manchester",
		LeaderID:      henry.ID,
	}
	newYorkSmoking := models.Group{
		Name:          "Smoking Cessation",
		AddictionType: "Smoking",
		Location:      "New York",
		LeaderID:      eve.ID,
	}

	for _, g := range []*models.Group{&londonAlcohol, &londonGambling, &manchesterSubstances, &newYorkSmoking} {
		db.Create(g)
	}

	// Assign users to groups
	db.Model(&alice).Update("group_id", londonAlcohol.ID)
	db.Model(&bob).Update("group_id", londonAlcohol.ID)
	db.Model(&marcus).Update("group_id", londonAlcohol.ID)
	db.Model(&carol).Update("group_id", londonGambling.ID)
	db.Model(&dan).Update("group_id", londonGambling.ID)
	db.Model(&sophie).Update("group_id", londonGambling.ID)
	db.Model(&eve).Update("group_id", newYorkSmoking.ID)
	db.Model(&frank).Update("group_id", newYorkSmoking.ID)
	db.Model(&grace).Update("group_id", newYorkSmoking.ID)
	db.Model(&henry).Update("group_id", manchesterSubstances.ID)
	db.Model(&isla).Update("group_id", manchesterSubstances.ID)

	// ── Messages ─────────────────────────────────────────────────────────────

	now := time.Now()
	msg := func(groupID, userID uint, alias, role, content string, minsAgo int) models.Message {
		t := now.Add(-time.Duration(minsAgo) * time.Minute)
		m := models.Message{GroupID: groupID, UserID: userID, Alias: alias, SenderRole: role, Content: content}
		m.CreatedAt = t
		return m
	}

	messages := []models.Message{
		// London — Alcohol Recovery
		msg(londonAlcohol.ID, alice.ID, "Alice", "leader", "Good morning everyone. Day 47 for me today. How is everyone doing?", 180),
		msg(londonAlcohol.ID, bob.ID, "Bob", "apprentice", "Day 12 here. Had a rough night but I made it through.", 175),
		msg(londonAlcohol.ID, alice.ID, "Alice", "leader", "12 days is real progress, Bob. What got you through it?", 170),
		msg(londonAlcohol.ID, bob.ID, "Bob", "apprentice", "Called my sponsor around 10pm. Just talking helped.", 165),
		msg(londonAlcohol.ID, marcus.ID, "Marcus", "sponsor", "That's exactly what the line is there for. Proud of you, Bob.", 160),
		msg(londonAlcohol.ID, marcus.ID, "Marcus", "sponsor", "I'm around most evenings if anyone needs to talk. Don't hesitate.", 155),
		msg(londonAlcohol.ID, bob.ID, "Bob", "apprentice", "Good to know I'm not alone in this. Thank you all.", 150),
		msg(londonAlcohol.ID, alice.ID, "Alice", "leader", "You never are. Check in tonight if it gets hard again.", 90),

		// London — Gambling Recovery
		msg(londonGambling.ID, carol.ID, "Carol", "leader", "Welcome to the group. This is a safe space — no judgement here.", 240),
		msg(londonGambling.ID, dan.ID, "Dan", "apprentice", "Walked past the betting shop yesterday. Harder than I expected.", 230),
		msg(londonGambling.ID, carol.ID, "Carol", "leader", "Did you go in?", 225),
		msg(londonGambling.ID, dan.ID, "Dan", "apprentice", "No. Took the long route home instead. Small win.", 220),
		msg(londonGambling.ID, sophie.ID, "Sophie", "sponsor", "That is not a small win. That is exactly the work.", 215),
		msg(londonGambling.ID, sophie.ID, "Sophie", "sponsor", "Removing temptation from your route is a real strategy. Keep doing it.", 210),
		msg(londonGambling.ID, dan.ID, "Dan", "apprentice", "I deleted the apps last night. If I can walk past, I can do this too.", 120),
		msg(londonGambling.ID, carol.ID, "Carol", "leader", "Dan, that took courage. Keep them gone.", 115),
		msg(londonGambling.ID, dan.ID, "Dan", "apprentice", "We're doing this together. Check in tomorrow.", 60),

		// Manchester — Substance Support
		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader", "Evening all. How did everyone get on this week?", 300),
		msg(manchesterSubstances.ID, isla.ID, "Isla", "sponsor", "My week was tough but I stayed present. Small things helped — tea, walks, texting this group.", 295),
		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader", "Those small anchors matter more than people realise.", 290),
		msg(manchesterSubstances.ID, isla.ID, "Isla", "sponsor", "My sister noticed I seemed more present. That meant a lot.", 280),
		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader", "Hold onto that. Those moments are what recovery looks like from the outside.", 270),
		msg(manchesterSubstances.ID, isla.ID, "Isla", "sponsor", "Had a moment on Thursday where I nearly called my old contact. Didn't though.", 200),
		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader", "What stopped you?", 195),
		msg(manchesterSubstances.ID, isla.ID, "Isla", "sponsor", "Thought about what I'd have to tell you all on Friday. Didn't want to.", 190),
		msg(manchesterSubstances.ID, henry.ID, "Henry", "leader", "That's accountability working. That's why we're here.", 180),

		// New York — Smoking Cessation
		msg(newYorkSmoking.ID, eve.ID, "Eve", "leader", "Two weeks smoke free as of today. 🎉", 400),
		msg(newYorkSmoking.ID, frank.ID, "Frank", "sponsor", "That's massive, Eve. How are the cravings?", 395),
		msg(newYorkSmoking.ID, eve.ID, "Eve", "leader", "Still there in the morning and after meals. Using the patches and it's helping.", 390),
		msg(newYorkSmoking.ID, grace.ID, "Grace", "apprentice", "The after-meal ones are brutal. I started going for a short walk right after eating.", 385),
		msg(newYorkSmoking.ID, frank.ID, "Frank", "sponsor", "I do the same. Breaks the routine that your brain expects.", 380),
		msg(newYorkSmoking.ID, eve.ID, "Eve", "leader", "That's a good idea. I'll try it tomorrow.", 370),
		msg(newYorkSmoking.ID, grace.ID, "Grace", "apprentice", "Day 31 for me today. Thought I'd mention it since Eve started the positivity off.", 100),
		msg(newYorkSmoking.ID, eve.ID, "Eve", "leader", "Grace!! 31 days! You didn't tell us!", 95),
		msg(newYorkSmoking.ID, grace.ID, "Grace", "apprentice", "Didn't want to jinx it. But here we are.", 90),
		msg(newYorkSmoking.ID, frank.ID, "Frank", "sponsor", "Celebrating both of you. This group keeps me going.", 85),
	}

	for i := range messages {
		db.Create(&messages[i])
	}

	// ── Become-sponsor eligibility check-ins ─────────────────────────────────
	// Bob: 95 clean check-ins → eligible, no pending request (button shows on profile)
	for i := 95; i >= 1; i-- {
		t := now.AddDate(0, 0, -i)
		ci := models.CheckIn{
			UserID:     bob.ID,
			MoodScore:  (i%3 + 3),
			Relapsed:   false,
			Reflection: "Staying the course.",
		}
		ci.CreatedAt = t
		ci.UpdatedAt = t
		db.Create(&ci)
	}

	// Dan: 92 clean check-ins + a pending request sent to Carol (awaiting approval)
	for i := 92; i >= 1; i-- {
		t := now.AddDate(0, 0, -i)
		ci := models.CheckIn{
			UserID:     dan.ID,
			MoodScore:  (i%3 + 3),
			Relapsed:   false,
			Reflection: "One day at a time.",
		}
		ci.CreatedAt = t
		ci.UpdatedAt = t
		db.Create(&ci)
	}
	db.Create(&models.Notification{
		RecipientID: carol.ID,
		SenderID:    dan.ID,
		Type:        "become_sponsor_request",
		Message:     "Dan has met the eligibility threshold and would like to become a sponsor.",
	})

	// Grace: 91 clean check-ins → eligible, no pending request
	for i := 91; i >= 1; i-- {
		t := now.AddDate(0, 0, -i)
		ci := models.CheckIn{
			UserID:     grace.ID,
			MoodScore:  (i%3 + 3),
			Relapsed:   false,
			Reflection: "Getting there.",
		}
		ci.CreatedAt = t
		ci.UpdatedAt = t
		db.Create(&ci)
	}

	log.Printf("Seed complete: %d groups, %d users, %d messages, %d eligibility check-ins\n",
		4, 11, len(messages), 95+92+91)
}
